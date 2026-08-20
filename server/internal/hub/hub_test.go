package hub

import (
	"context"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/coder/websocket"
	"github.com/wadeling/agore/server/internal/protocol"
)

func TestRejectsBadToken(t *testing.T) {
	h := New("secret")
	srv := httptest.NewServer(h)
	t.Cleanup(srv.Close)

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	ws, _, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(srv.URL, "http"), nil)
	if err != nil {
		t.Fatal(err)
	}
	hello, err := protocol.Envelope{
		Type: "hello", ClientID: "c1", SessionID: "s1", DisplayName: "x", Token: "nope",
	}.Encode()
	if err != nil {
		t.Fatal(err)
	}
	if err := ws.Write(ctx, websocket.MessageText, hello); err != nil {
		t.Fatal(err)
	}
	_, data, err := ws.Read(ctx)
	if err != nil {
		t.Fatal(err)
	}
	got, err := protocol.Decode(data)
	if err != nil {
		t.Fatal(err)
	}
	if got.Type != "error" || got.Code != "unauthorized" {
		t.Fatalf("wanted unauthorized, got %+v", got)
	}
}

func TestWelcomeSnapshot(t *testing.T) {
	h := New("secret")
	srv := httptest.NewServer(h)
	t.Cleanup(srv.Close)

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	ws, _, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(srv.URL, "http"), nil)
	if err != nil {
		t.Fatal(err)
	}
	hello, _ := protocol.Envelope{
		Type: "hello", ClientID: "c1", SessionID: "s1", DisplayName: "lingximo", Token: "secret",
	}.Encode()
	if err := ws.Write(ctx, websocket.MessageText, hello); err != nil {
		t.Fatal(err)
	}
	_, data, err := ws.Read(ctx)
	if err != nil {
		t.Fatal(err)
	}
	got, err := protocol.Decode(data)
	if err != nil {
		t.Fatal(err)
	}
	// The plaza is empty until this client says who its people are.
	if got.Type != "welcome" || got.ClientID != "c1" || len(got.Snapshot) != 0 {
		t.Fatalf("wanted an empty welcome, got %+v", got)
	}
}

// One socket, one person per coding agent.
func TestClientHoldsOneMemberPerAgent(t *testing.T) {
	h := New("secret")
	srv := httptest.NewServer(h)
	t.Cleanup(srv.Close)

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	ws := dial(ctx, t, srv.URL, "c1")

	for _, member := range []string{"c1:cursor", "c1:opencode"} {
		send(ctx, t, ws, protocol.Envelope{
			Type: "presence", MemberID: member, DisplayName: member, Kind: "running",
		})
		if got := read(ctx, t, ws); got.Type != "presence" || got.MemberID != member || got.ClientID != "c1" {
			t.Fatalf("wanted presence for %s, got %+v", member, got)
		}
	}
	if n := h.Members(); n != 2 {
		t.Fatalf("wanted 2 people on the plaza, got %d", n)
	}

	// Taking one agent's person off the plaza leaves the other standing.
	send(ctx, t, ws, protocol.Envelope{Type: "leave", MemberID: "c1:cursor"})
	if got := read(ctx, t, ws); got.Type != "leave" || got.MemberID != "c1:cursor" {
		t.Fatalf("wanted a leave for c1:cursor, got %+v", got)
	}
	if n := h.Members(); n != 1 {
		t.Fatalf("wanted 1 person left, got %d", n)
	}
}

// A member id has to be prefixed with the id of the client that sends it, or one client
// could rename or evict another's people.
func TestRejectsMembersOwnedByAnotherClient(t *testing.T) {
	h := New("secret")
	srv := httptest.NewServer(h)
	t.Cleanup(srv.Close)

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	victim := dial(ctx, t, srv.URL, "c1")
	send(ctx, t, victim, protocol.Envelope{
		Type: "presence", MemberID: "c1:cursor", DisplayName: "wade · cursor", Kind: "reading",
	})
	read(ctx, t, victim)

	attacker := dial(ctx, t, srv.URL, "c2")
	send(ctx, t, attacker, protocol.Envelope{Type: "leave", MemberID: "c1:cursor"})
	send(ctx, t, attacker, protocol.Envelope{
		Type: "presence", MemberID: "c2:cursor", DisplayName: "c2", Kind: "running",
	})
	// Only the attacker's own person comes back, so the spoofed leave was dropped.
	if got := read(ctx, t, attacker); got.MemberID != "c2:cursor" {
		t.Fatalf("wanted c2's own presence, got %+v", got)
	}
	if n := h.Members(); n != 2 {
		t.Fatalf("wanted both people standing, got %d", n)
	}
}

// A client that predates member ids stands on the plaza as a single person.
func TestFallsBackToClientIdAsMember(t *testing.T) {
	h := New("secret")
	srv := httptest.NewServer(h)
	t.Cleanup(srv.Close)

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	ws := dial(ctx, t, srv.URL, "old")
	send(ctx, t, ws, protocol.Envelope{Type: "presence", DisplayName: "old", Kind: "reading"})
	got := read(ctx, t, ws)
	if got.MemberID != "old" || got.ClientID != "old" {
		t.Fatalf("wanted the client id used as the member, got %+v", got)
	}
}

func dial(ctx context.Context, t *testing.T, url, clientID string) *websocket.Conn {
	t.Helper()
	ws, _, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(url, "http"), nil)
	if err != nil {
		t.Fatal(err)
	}
	send(ctx, t, ws, protocol.Envelope{
		Type: "hello", ClientID: clientID, SessionID: "s1", DisplayName: clientID, Token: "secret",
	})
	if welcome := read(ctx, t, ws); welcome.Type != "welcome" {
		t.Fatalf("wanted welcome, got %+v", welcome)
	}
	return ws
}

func send(ctx context.Context, t *testing.T, ws *websocket.Conn, frame protocol.Envelope) {
	t.Helper()
	data, err := frame.Encode()
	if err != nil {
		t.Fatal(err)
	}
	if err := ws.Write(ctx, websocket.MessageText, data); err != nil {
		t.Fatal(err)
	}
}

func read(ctx context.Context, t *testing.T, ws *websocket.Conn) protocol.Envelope {
	t.Helper()
	_, data, err := ws.Read(ctx)
	if err != nil {
		t.Fatal(err)
	}
	frame, err := protocol.Decode(data)
	if err != nil {
		t.Fatal(err)
	}
	return frame
}
