package protocol

import "testing"

func TestRoundTripHello(t *testing.T) {
	raw, err := Envelope{
		Type:        "hello",
		ClientID:    "c1",
		SessionID:   "s1",
		DisplayName: "lingximo",
		Token:       "secret",
	}.Encode()
	if err != nil {
		t.Fatal(err)
	}
	got, err := Decode(raw)
	if err != nil {
		t.Fatal(err)
	}
	if got.Type != "hello" || got.ClientID != "c1" || got.Token != "secret" || got.V != Version {
		t.Fatalf("unexpected decode: %+v", got)
	}
}
