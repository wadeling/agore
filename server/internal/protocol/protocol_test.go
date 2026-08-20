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

func TestMemberOwnership(t *testing.T) {
	cases := []struct {
		client string
		member string
		want   string
		owned  bool
	}{
		{"c1", "", "c1", true},
		{"c1", "c1", "c1", true},
		{"c1", "c1:cursor", "c1:cursor", true},
		{"c1", "c1:opencode", "c1:opencode", true},
		{"c1", "c2:cursor", "c2:cursor", false},
		{"c1", "c2", "c2", false},
		// A client id that merely starts the same is a different client.
		{"c1", "c10:cursor", "c10:cursor", false},
	}
	for _, tc := range cases {
		got, owned := MemberOf(tc.client, tc.member)
		if got != tc.want || owned != tc.owned {
			t.Fatalf("MemberOf(%q, %q) = %q, %v; wanted %q, %v",
				tc.client, tc.member, got, owned, tc.want, tc.owned)
		}
	}
}
