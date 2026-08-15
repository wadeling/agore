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
	if got.Type != "welcome" || got.ClientID != "c1" || len(got.Snapshot) != 1 {
		t.Fatalf("wanted welcome with self, got %+v", got)
	}
}
