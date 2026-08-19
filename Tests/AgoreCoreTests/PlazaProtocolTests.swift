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
        XCTAssertEqual(got.v, 1)
    }

    func testPlazaPeriodByHour() {
        XCTAssertEqual(PlazaPeriod.at(hour: 3), .night)
        XCTAssertEqual(PlazaPeriod.at(hour: 7), .dusk)
        XCTAssertEqual(PlazaPeriod.at(hour: 12), .day)
        XCTAssertEqual(PlazaPeriod.at(hour: 18), .dusk)
        XCTAssertEqual(PlazaPeriod.at(hour: 22), .night)
    }

    func testPresenceDTOMapsKind() {
        let dto = PlazaPresenceDTO(
            client_id: "remote",
            display_name: "stoa",
            kind: "writing",
            project: "agore",
            ts: 1_710_000_000
        )
        let member = dto.asMember(localId: "local")
        XCTAssertEqual(member.kind, .writing)
        XCTAssertFalse(member.isLocal)
        XCTAssertEqual(member.asSession().source, .plaza)
    }
}
