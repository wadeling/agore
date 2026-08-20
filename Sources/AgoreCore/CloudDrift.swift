import Foundation

/// Pixel-art motion for the seaside sky.
///
/// Two constraints pull against each other here. A nearest-neighbour sprite
/// parked between two view pixels shimmers, so a position has to land on the
/// view's grid. And macOS hands a window whatever frame rate it likes — a
/// courtyard sitting behind another app can drop to one frame every second or
/// two — so anything that added up frame deltas would advance a thirtieth of a
/// second per frame and read as frozen while the clock ran on. Position is
/// therefore a function of elapsed time, and the frame rate only decides how
/// finely that motion is sampled.
public enum CloudDrift {
    /// How long a strip cloud takes to cross the sky, right to left.
    public static let stripCrossing: TimeInterval = 30 * 60

    /// The courtyard sky is a third the width and much more of the picture, so
    /// its clouds cross in minutes rather than half an hour.
    public static let courtyardCrossing: TimeInterval = 4 * 60

    /// Size 2 finishes a little early, size 9 a little late, so a row of clouds
    /// does not travel as a formation.
    public static func crossingSkew(size: Int) -> Double {
        let t = Double(min(9, max(2, size)) - 2) / 7.0
        return 0.92 + t * 0.16
    }

    /// Seconds for a cloud of `size` to travel from one edge to the other.
    public static func crossing(size: Int, isStrip: Bool) -> TimeInterval {
        (isStrip ? stripCrossing : courtyardCrossing) * crossingSkew(size: size)
    }

    /// World pixels a second, so a resized window changes how sharp the drift
    /// looks and not how fast the weather moves.
    public static func pixelsPerSecond(size: Int, worldWidth: Int, isStrip: Bool) -> Double {
        let seconds = crossing(size: size, isStrip: isStrip)
        guard seconds > 0 else { return 0 }
        return Double(max(1, worldWidth)) / seconds
    }

    /// The same crossing the bird's old `worldWidth / 38` flight took.
    public static func birdPixelsPerSecond(worldWidth: Int) -> Double {
        let width = Double(max(1, worldWidth))
        return width / birdFlightSeconds(worldWidth: worldWidth)
    }

    public static func birdFlightSeconds(worldWidth: Int) -> TimeInterval {
        max(6.5, Double(max(1, worldWidth)) / 38.0)
    }

    /// Where a body that set out from `origin` sits `elapsed` seconds later.
    public static func drifted(
        origin: Double,
        elapsed: TimeInterval,
        pixelsPerSecond: Double,
        spriteWidth: Double,
        worldWidth: Int,
        scale: Double
    ) -> Double {
        let travelled = origin - pixelsPerSecond * max(0, elapsed)
        let wrapped = wrapped(travelled, spriteWidth: spriteWidth, worldWidth: worldWidth)
        return snapped(wrapped, scale: scale)
    }

    /// A cloud that has left one edge re-enters fully off the other, so it drifts
    /// back in rather than popping on-screen. The wrap is modular rather than a
    /// single step, so a cloud lands where the clock says even when whole laps
    /// went by between two frames.
    public static func wrapped(_ x: Double, spriteWidth: Double, worldWidth: Int) -> Double {
        let low = -spriteWidth / 2
        let lap = Double(max(1, worldWidth)) + spriteWidth
        let offset = (x - low).truncatingRemainder(dividingBy: lap)
        return low + (offset < 0 ? offset + lap : offset)
    }

    /// Quantise onto the view's pixel grid.
    public static func snapped(_ x: Double, scale: Double) -> Double {
        let step = max(1, scale)
        return (x * step).rounded() / step
    }
}
