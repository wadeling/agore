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
	token string
	inbox chan inbound
	mu    sync.Mutex
	conns map[string]*conn
	// Keyed by member id, not by client: a client running two coding agents stands on the
	// plaza as two people over the one socket.
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
	h.attach(c)
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
		case "presence", "leave":
			member, owned := protocol.MemberOf(c.clientID, frame.MemberID)
			if !owned {
				continue
			}
			frame.ClientID = c.clientID
			frame.MemberID = member
			// A dropped presence frame is replaced by the next one; a dropped leave
			// would strand a person on the plaza for good.
			h.push(inbound{priority: frame.Type == "leave", from: c.clientID, frame: frame})
		default:
			// ignore unknown types so old clients do not get kicked
		}
	}
}

// A client introduces its own people through presence frames the moment it is welcomed,
// so attaching only hands back the plaza as it stands. Seeding a person from the hello
// would put a nameless extra on stage for every client that runs two agents.
func (h *Hub) attach(c *conn) {
	h.mu.Lock()
	if old, ok := h.conns[c.clientID]; ok {
		old.replaced = true
		_ = old.ws.Close(websocket.StatusGoingAway, "replaced")
	}
	h.conns[c.clientID] = c
	snapshot := h.snapshotLocked()
	h.mu.Unlock()
	_ = c.write(protocol.Welcome(c.clientID, snapshot))
}

func (h *Hub) detach(c *conn) {
	h.mu.Lock()
	current, ok := h.conns[c.clientID]
	if !ok || current != c {
		h.mu.Unlock()
		return
	}
	delete(h.conns, c.clientID)
	gone := make([]string, 0, 2)
	for id, p := range h.roster {
		if p.ClientID == c.clientID {
			delete(h.roster, id)
			gone = append(gone, id)
		}
	}
	h.mu.Unlock()
	if c.replaced {
		return
	}
	log.Printf("event=leave client=%s members=%d", c.clientID, len(gone))
	for _, id := range gone {
		h.push(inbound{priority: true, from: c.clientID, frame: protocol.Leave(c.clientID, id)})
	}
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
	member := msg.frame.MemberID
	if member == "" {
		member = msg.from
	}
	switch msg.frame.Type {
	case "presence":
		prev := h.roster[member]
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
			MemberID:    member,
			DisplayName: name,
			Kind:        kind,
			Project:     msg.frame.Project,
			TS:          protocol.Now(),
		}
		h.roster[member] = p
		log.Printf("event=presence member=%s kind=%s project=%s", member, p.Kind, p.Project)
		h.broadcastLocked(protocol.PresenceFrame(p))
	case "leave":
		delete(h.roster, member)
		h.broadcastLocked(protocol.Leave(msg.from, member))
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

// Count is connections, Members is people: a client running two coding agents is one of
// the former and two of the latter.
func (h *Hub) Count() int {
	h.mu.Lock()
	defer h.mu.Unlock()
	return len(h.conns)
}

func (h *Hub) Members() int {
	h.mu.Lock()
	defer h.mu.Unlock()
	return len(h.roster)
}
