import XCTest
@testable import AgoreCore

final class CloudDriftTests: XCTestCase {
    func testStripCrossingIsAboutHalfAnHour() {
        let width = 360
        let speed = CloudDrift.pixelsPerSecond(size: 3, worldWidth: width, isStrip: true)
        XCTAssertEqual(Double(width) / speed, 30 * 60, accuracy: 3 * 60)
    }

    func testCourtyardCrossingIsAFewMinutes() {
        let width = 240
        let speed = CloudDrift.pixelsPerSecond(size: 7, worldWidth: width, isStrip: false)
        XCTAssertEqual(Double(width) / speed, 4 * 60, accuracy: 30)
    }

    func testFatCloudsTakeLonger() {
        let small = CloudDrift.pixelsPerSecond(size: 2, worldWidth: 360, isStrip: true)
        let fat = CloudDrift.pixelsPerSecond(size: 9, worldWidth: 360, isStrip: true)
        XCTAssertGreaterThan(small, fat)
    }

    func testSpeedDoesNotDependOnWindowScale() {
        let speed = CloudDrift.pixelsPerSecond(size: 5, worldWidth: 240, isStrip: false)
        let after = CloudDrift.drifted(
            origin: 200,
            elapsed: 30,
            pixelsPerSecond: speed,
            spriteWidth: 32,
            worldWidth: 240,
            scale: 3
        )
        let zoomed = CloudDrift.drifted(
            origin: 200,
            elapsed: 30,
            pixelsPerSecond: speed,
            spriteWidth: 32,
            worldWidth: 240,
            scale: 6
        )
        XCTAssertEqual(after, zoomed, accuracy: 1)
    }

    /// The whole point of driving position from the clock: a window macOS throttled
    /// to one frame a second is a minute of drift behind after a minute, not thirty
    /// times less of it.
    func testAStarvedWindowEndsUpWhereASmoothOneDoes() {
        let speed = CloudDrift.pixelsPerSecond(size: 5, worldWidth: 240, isStrip: false)
        func sample(every step: TimeInterval, seconds: TimeInterval) -> Double {
            var x = 200.0
            var elapsed: TimeInterval = 0
            while elapsed < seconds {
                elapsed = min(seconds, elapsed + step)
                x = CloudDrift.drifted(
                    origin: 200,
                    elapsed: elapsed,
                    pixelsPerSecond: speed,
                    spriteWidth: 32,
                    worldWidth: 240,
                    scale: 3
                )
            }
            return x
        }
        let smooth = sample(every: 1.0 / 60.0, seconds: 60)
        let starved = sample(every: 1.75, seconds: 60)
        XCTAssertEqual(smooth, starved, accuracy: 0.0001)
        XCTAssertLessThan(smooth, 200)
    }

    func testDriftMovesRightToLeft() {
        let speed = CloudDrift.pixelsPerSecond(size: 5, worldWidth: 240, isStrip: false)
        let first = CloudDrift.drifted(
            origin: 200,
            elapsed: 10,
            pixelsPerSecond: speed,
            spriteWidth: 32,
            worldWidth: 240,
            scale: 3
        )
        let later = CloudDrift.drifted(
            origin: 200,
            elapsed: 40,
            pixelsPerSecond: speed,
            spriteWidth: 32,
            worldWidth: 240,
            scale: 3
        )
        XCTAssertLessThan(later, first)
    }

    func testACloudOffTheLeftEdgeComesBackFromTheRight() {
        let wrapped = CloudDrift.wrapped(-17, spriteWidth: 32, worldWidth: 240)
        XCTAssertEqual(wrapped, 240 + 15, accuracy: 0.0001)
    }

    func testWholeLapsWrapTheSameAsOne() {
        let lap = 240.0 + 32.0
        let once = CloudDrift.wrapped(-17, spriteWidth: 32, worldWidth: 240)
        let thrice = CloudDrift.wrapped(-17 - 3 * lap, spriteWidth: 32, worldWidth: 240)
        XCTAssertEqual(once, thrice, accuracy: 0.0001)
    }

    func testACloudStillOnStageDoesNotWrap() {
        XCTAssertEqual(CloudDrift.wrapped(54, spriteWidth: 32, worldWidth: 240), 54, accuracy: 0.0001)
    }

    func testSnapLandsOnAViewPixel() {
        XCTAssertEqual(CloudDrift.snapped(148.4, scale: 3), 148 + 1.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(CloudDrift.snapped(10.24, scale: 2), 10.0, accuracy: 0.0001)
        XCTAssertEqual(CloudDrift.snapped(10.26, scale: 2), 10.5, accuracy: 0.0001)
    }

    func testBirdCrossesInAFewSeconds() {
        XCTAssertEqual(CloudDrift.birdFlightSeconds(worldWidth: 240), 6.5, accuracy: 0.05)
        XCTAssertEqual(
            240.0 / CloudDrift.birdPixelsPerSecond(worldWidth: 240),
            6.5,
            accuracy: 0.05
        )
    }
}
