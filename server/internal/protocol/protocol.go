package protocol

import (
	"encoding/json"
	"strings"
	"time"
)

// Version 2 added member_id: one client owns a person per coding agent it runs.
const Version = 2

type Envelope struct {
	V           int        `json:"v"`
	Type        string     `json:"type"`
	TS          int64      `json:"ts"`
	ClientID    string     `json:"client_id,omitempty"`
	MemberID    string     `json:"member_id,omitempty"`
	SessionID   string     `json:"session_id,omitempty"`
	DisplayName string     `json:"display_name,omitempty"`
	Token       string     `json:"token,omitempty"`
	Kind        string     `json:"kind,omitempty"`
	Project     string     `json:"project,omitempty"`
	Snapshot    []Presence `json:"snapshot,omitempty"`
	Code        string     `json:"code,omitempty"`
}

type Presence struct {
	ClientID    string `json:"client_id"`
	MemberID    string `json:"member_id"`
	DisplayName string `json:"display_name"`
	Kind        string `json:"kind"`
	Project     string `json:"project"`
	TS          int64  `json:"ts"`
}

func Now() int64 { return time.Now().Unix() }

func Decode(data []byte) (Envelope, error) {
	var env Envelope
	err := json.Unmarshal(data, &env)
	return env, err
}

func (e Envelope) Encode() ([]byte, error) {
	if e.V == 0 {
		e.V = Version
	}
	if e.TS == 0 {
		e.TS = Now()
	}
	return json.Marshal(e)
}

func Error(code string) Envelope {
	return Envelope{V: Version, Type: "error", TS: Now(), Code: code}
}

func Welcome(clientID string, snapshot []Presence) Envelope {
	return Envelope{V: Version, Type: "welcome", TS: Now(), ClientID: clientID, Snapshot: snapshot}
}

func PresenceFrame(p Presence) Envelope {
	return Envelope{
		V:           Version,
		Type:        "presence",
		TS:          p.TS,
		ClientID:    p.ClientID,
		MemberID:    p.MemberID,
		DisplayName: p.DisplayName,
		Kind:        p.Kind,
		Project:     p.Project,
	}
}

func Leave(clientID, memberID string) Envelope {
	return Envelope{V: Version, Type: "leave", TS: Now(), ClientID: clientID, MemberID: memberID}
}

// MemberOf reports which person a frame is about, and whether the connection that sent it
// is allowed to speak for them. A client owns the member named after itself and any member
// prefixed with its own id, and nothing else — otherwise one client could rename or evict
// another's people.
func MemberOf(clientID, memberID string) (string, bool) {
	if memberID == "" || memberID == clientID {
		return clientID, true
	}
	return memberID, strings.HasPrefix(memberID, clientID+":")
}

func Pong() Envelope {
	return Envelope{V: Version, Type: "pong", TS: Now()}
}
