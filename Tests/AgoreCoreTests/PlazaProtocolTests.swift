import XCTest
@testable import AgoreCore

final class PlazaProtocolTests: XCTestCase {
    func testHelloRoundTrip() throws {
        let identity = ClientIdentity(clientId: "c1", sessionId: "s1")
        let data = try PlazaEnvelope.hello(identity: identity, displayName: "lingximo", token: "secret").encoded()
        let got = try PlazaEnvelope.decode(data)
        XCTAssertEqual(got.type, "hello")
        XCTAssertEqual(got.client_id, "c1")
        XCTAssertEqual(got.session_id, "s1")
        XCTAssertEqual(got.display_name, "lingximo")
        XCTAssertEqual(got.token, "secret")
        XCTAssertEqual(got.v, AgoreConstants.plazaProtocolVersion)
    }

    func testPresenceNamesBothClientAndMember() throws {
        let member = PlazaMember(
            id: PlazaMember.id(client: "c1", provider: .opencode),
            displayName: "wade",
            kind: .running,
            project: "agore",
            provider: AgoreConstants.providerOpencode,
            isLocal: true
        )
        let got = try PlazaEnvelope.decode(try PlazaEnvelope.presence(member, from: "c1").encoded())
        XCTAssertEqual(got.client_id, "c1")
        XCTAssertEqual(got.member_id, "c1:opencode")
        // Only the nickname travels; which agent it belongs to rides in the member id.
        XCTAssertEqual(got.display_name, "wade")
        XCTAssertEqual(got.kind, "running")
    }

    func testMemberIdentifiesThePersonAndClientIdentifiesTheOwner() {
        let dto = PlazaPresenceDTO(
            client_id: "remote",
            member_id: "remote:cursor",
            display_name: "stoa",
            kind: "reading",
            project: "agore",
            ts: 1_710_000_000
        )
        XCTAssertEqual(dto.asMember(localId: "local").id, "remote:cursor")
        XCTAssertFalse(dto.asMember(localId: "local").isLocal)
        // A peer's agent is read back out of its member id, so its name reads the same as
        // one of ours.
        XCTAssertEqual(dto.asMember(localId: "local").agent, .cursor)
        XCTAssertEqual(dto.asMember(localId: "local").label, "stoa-cs")
        // Two agents on one remote Mac are two people, and both are that Mac's.
        XCTAssertTrue(dto.asMember(localId: "remote").isLocal)
    }

    func testNameUnderAPersonIsTaggedAndCutToFit() {
        let short = PlazaMember(id: "c1:opencode", displayName: "wade", kind: .idle, provider: "opencode")
        XCTAssertEqual(short.label, "wade-oc")
        XCTAssertEqual(short.fullLabel, "wade-opencode")

        let long = PlazaMember(id: "c1:cursor", displayName: "wadelingsbigmac", kind: .idle, provider: "cursor")
        XCTAssertEqual(long.label, "wadelingsb…-cs")
        XCTAssertEqual(long.fullLabel, "wadelingsbigmac-cursor")
        // The actor is handed both, the short name to wear and the full one for a hover.
        XCTAssertEqual(long.asSession().displayName, "wadelingsb…-cs")
        XCTAssertEqual(long.asSession().fullName, "wadelingsbigmac-cursor")

        // A client from before per-agent members has no agent to tag it with.
        let old = PlazaMember(id: "c1", displayName: "stoa", kind: .idle)
        XCTAssertEqual(old.label, "stoa")
        XCTAssertEqual(old.fullLabel, "stoa")
    }

    func testPlazaPeriodByHour() {
        XCTAssertEqual(PlazaPeriod.at(hour: 3), .night)
        XCTAssertEqual(PlazaPeriod.at(hour: 7), .dusk)
        XCTAssertEqual(PlazaPeriod.at(hour: 12), .day)
        XCTAssertEqual(PlazaPeriod.at(hour: 18), .dusk)
        XCTAssertEqual(PlazaPeriod.at(hour: 22), .night)
    }

    /// A client from before per-agent members sends no member id and stands as one person.
    func testPresenceDTOMapsKind() {
        let dto = PlazaPresenceDTO(
            client_id: "remote",
            display_name: "stoa",
            kind: "writing",
            project: "agore",
            ts: 1_710_000_000
        )
        let member = dto.asMember(localId: "local")
        XCTAssertEqual(member.id, "remote")
        XCTAssertEqual(member.kind, .writing)
        XCTAssertFalse(member.isLocal)
        XCTAssertEqual(member.asSession().source, .plaza)
    }
}
