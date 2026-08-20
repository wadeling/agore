import XCTest
@testable import AgoreCore

final class PanelOpacityTests: XCTestCase {
    private var previous: Any?

    override func setUp() {
        previous = UserDefaults.standard.object(forKey: AgoreConstants.panelOpacityKey)
        UserDefaults.standard.removeObject(forKey: AgoreConstants.panelOpacityKey)
    }

    override func tearDown() {
        if let previous {
            UserDefaults.standard.set(previous, forKey: AgoreConstants.panelOpacityKey)
        } else {
            UserDefaults.standard.removeObject(forKey: AgoreConstants.panelOpacityKey)
        }
    }

    func testDefaultIsEightyPercent() {
        XCTAssertEqual(PanelOpacity.current, 0.8)
        XCTAssertEqual(PanelOpacity.percentLabel(for: PanelOpacity.current), "80%")
    }

    func testClampKeepsTheStripVisible() {
        XCTAssertEqual(PanelOpacity.clamped(0), 0.2)
        XCTAssertEqual(PanelOpacity.clamped(-1), 0.2)
        XCTAssertEqual(PanelOpacity.clamped(1.4), 1.0)
        XCTAssertEqual(PanelOpacity.clamped(0.55), 0.55)
    }

    func testPersistsAndSurvivesAReread() {
        PanelOpacity.current = 0.45
        XCTAssertEqual(PanelOpacity.current, 0.45)
        XCTAssertEqual(PanelOpacity.percentLabel(for: 0.45), "45%")
    }

    func testOneHundredPercentIsASolidCard() {
        let visuals = PanelOpacity.visuals(for: 1)
        XCTAssertEqual(visuals.fillAlpha, 1)
        XCTAssertEqual(visuals.groundAlpha, 1)
        XCTAssertEqual(visuals.barAlpha, 1)
    }

    func testDefaultKeepsTheDesignedTranslucency() {
        let visuals = PanelOpacity.visuals(for: 0.8)
        XCTAssertEqual(visuals.fillAlpha, 0)
        XCTAssertEqual(visuals.groundAlpha, Double(AgoreConstants.groundOpacity), accuracy: 0.0001)
        XCTAssertEqual(visuals.barAlpha, PanelOpacity.designedBarAlpha, accuracy: 0.0001)
    }
}
