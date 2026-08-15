package hub

import (
	"context"
	"crypto/subtle"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/coder/websocket"
	"github.com/wadeling/agore/server/internal/protocol"
)

const (
	inboxSize   = 256
	readTimeout = 45 * time.Second
	helloWait   = 10 * time.Second
	writeWait   = 5 * time.Second
)

type inbound struct {
	priority bool
	from     string
	frame    protocol.Envelope
}

type conn struct {
	clientID  string
	sessionID string
	ws        *websocket.Conn
	replaced  bool
	writeMu   sync.Mutex
}

type Hub struct {
	token  string
	inbox  chan inbound
	mu     sync.Mutex
	conns  map[string]*conn
	roster map[string]protocol.Presence
}

func New(token string) *Hub {
	h := &Hub{
		token:  token,
		inbox:  make(chan inbound, inboxSize),
		conns:  make(map[string]*conn),
		roster: make(map[string]protocol.Presence),
	}
	go h.drain()
	return h
}

func (h *Hub) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	ws, err := websocket.Accept(w, r, &websocket.AcceptOptions{
		InsecureSkipVerify: true,
	})
	if err != nil {
		return
	}
	h.handle(ws)
}

func (h *Hub) handle(ws *websocket.Conn) {
	ctx, cancel := context.WithTimeout(context.Background(), helloWait)
	typ, data, err := ws.Read(ctx)
	cancel()
	if err != nil || typ != websocket.MessageText {
		_ = ws.Close(websocket.StatusPolicyViolation, "hello required")
		return
	}
	hello, err := protocol.Decode(data)
	if err != nil || hello.Type != "hello" || hello.ClientID == "" || hello.SessionID == "" {
		h.write(ws, protocol.Error("bad_hello"))
		_ = ws.Close(websocket.StatusPolicyViolation, "bad_hello")
		return
	}
	if !h.tokenOK(hello.Token) {
		h.write(ws, protocol.Error("unauthorized"))
		_ = ws.Close(websocket.StatusPolicyViolation, "unauthorized")
		log.Printf("event=hello client=%s result=unauthorized", hello.ClientID)
		return
	}

	c := &conn{clientID: hello.ClientID, sessionID: hello.SessionID, ws: ws}
	h.attach(c, hello)
	log.Printf("event=hello client=%s result=ok", hello.ClientID)

	for {
		ctx, cancel := context.WithTimeout(context.Background(), readTimeout)
		typ, data, err := ws.Read(ctx)
		cancel()
		if err != nil {
			h.detach(c)
			return
		}
		if typ != websocket.MessageText {
			continue
		}
		frame, err := protocol.Decode(data)
		if err != nil {
			continue
		}
		switch frame.Type {
		case "ping":
			_ = c.write(protocol.Pong())
		case "presence", "nick":
			frame.ClientID = c.clientID
			h.push(inbound{from: c.clientID, frame: frame})
		default:
			// ignore unknown types so old clients do not get kicked
		}
	}
}

func (h *Hub) attach(c *conn, hello protocol.Envelope) {
	h.mu.Lock()
	if old, ok := h.conns[c.clientID]; ok {
		old.replaced = true
		_ = old.ws.Close(websocket.StatusGoingAway, "replaced")
	}
	h.conns[c.clientID] = c
	name := hello.DisplayName
	if name == "" {
		name = "agent"
	}
	kind := "waiting"
	project := ""
	if existing, ok := h.roster[c.clientID]; ok {
		existing.DisplayName = name
		if existing.Kind != "" {
			kind = existing.Kind
		}
		project = existing.Project
		h.roster[c.clientID] = existing
	} else {
		h.roster[c.clientID] = protocol.Presence{
			ClientID:    c.clientID,
			DisplayName: name,
			Kind:        kind,
			TS:          protocol.Now(),
		}
	}
	snapshot := h.snapshotLocked()
	h.mu.Unlock()
	_ = c.write(protocol.Welcome(c.clientID, snapshot))
	h.push(inbound{
		priority: true,
		from:     c.clientID,
		frame: protocol.Envelope{
			Type:        "presence",
			ClientID:    c.clientID,
			DisplayName: name,
			Kind:        kind,
			Project:     project,
		},
	})
}

func (h *Hub) detach(c *conn) {
	h.mu.Lock()
	current, ok := h.conns[c.clientID]
	if !ok || current != c {
		h.mu.Unlock()
		return
	}
	delete(h.conns, c.clientID)
	delete(h.roster, c.clientID)
	h.mu.Unlock()
	if c.replaced {
		return
	}
	log.Printf("event=leave client=%s", c.clientID)
	h.push(inbound{priority: true, from: c.clientID, frame: protocol.Leave(c.clientID)})
}

func (h *Hub) push(msg inbound) {
	if msg.priority {
		h.inbox <- msg
		return
	}
	select {
	case h.inbox <- msg:
	default:
		// Presence is expendable when the plaza is busy; hello/leave never take this path.
	}
}

func (h *Hub) drain() {
	for msg := range h.inbox {
		h.apply(msg)
	}
}

func (h *Hub) apply(msg inbound) {
	h.mu.Lock()
	defer h.mu.Unlock()
	switch msg.frame.Type {
	case "presence":
		prev := h.roster[msg.from]
		name := msg.frame.DisplayName
		if name == "" {
			name = prev.DisplayName
		}
		if name == "" {
			name = "agent"
		}
		kind := msg.frame.Kind
		if kind == "" {
			kind = "thinking"
		}
		p := protocol.Presence{
			ClientID:    msg.from,
			DisplayName: name,
			Kind:        kind,
			Project:     msg.frame.Project,
			TS:          protocol.Now(),
		}
		h.roster[msg.from] = p
		log.Printf("event=presence client=%s kind=%s project=%s", msg.from, p.Kind, p.Project)
		h.broadcastLocked(protocol.PresenceFrame(p))
	case "nick":
		prev, ok := h.roster[msg.from]
		if !ok {
			return
		}
		if msg.frame.DisplayName != "" {
			prev.DisplayName = msg.frame.DisplayName
		}
		prev.TS = protocol.Now()
		h.roster[msg.from] = prev
		log.Printf("event=nick client=%s", msg.from)
		h.broadcastLocked(protocol.PresenceFrame(prev))
	case "leave":
		delete(h.roster, msg.from)
		h.broadcastLocked(protocol.Leave(msg.from))
	}
}

func (h *Hub) broadcastLocked(frame protocol.Envelope) {
	for id, c := range h.conns {
		if err := c.write(frame); err != nil {
			c.replaced = true
			_ = c.ws.Close(websocket.StatusGoingAway, "write failed")
			delete(h.conns, id)
		}
	}
}

func (c *conn) write(frame protocol.Envelope) error {
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	return writeWS(c.ws, frame)
}

func (h *Hub) write(ws *websocket.Conn, frame protocol.Envelope) {
	_ = writeWS(ws, frame)
}

func writeWS(ws *websocket.Conn, frame protocol.Envelope) error {
	data, err := frame.Encode()
	if err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(context.Background(), writeWait)
	defer cancel()
	return ws.Write(ctx, websocket.MessageText, data)
}

func (h *Hub) snapshotLocked() []protocol.Presence {
	out := make([]protocol.Presence, 0, len(h.roster))
	for _, p := range h.roster {
		out = append(out, p)
	}
	return out
}

func (h *Hub) tokenOK(got string) bool {
	if len(got) != len(h.token) {
		// Still compare to keep the failure path from being a cheap length oracle.
		subtle.ConstantTimeCompare([]byte(h.token), []byte(h.token))
		return false
	}
	return subtle.ConstantTimeCompare([]byte(got), []byte(h.token)) == 1
}

func (h *Hub) Count() int {
	h.mu.Lock()
	defer h.mu.Unlock()
	return len(h.conns)
}
