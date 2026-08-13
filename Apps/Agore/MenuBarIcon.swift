import AppKit

enum MenuBarIcon {
    static var image: NSImage {
        let pixels: [String] = [
            "................",
            ".....######.....",
            "....########....",
            "....##.##.##....",
            "....########....",
            ".....######.....",
            "...##########...",
            "..############..",
            "..############..",
            "..############..",
            "...##########...",
            ".....##..##.....",
            ".....##..##.....",
            ".....##..##.....",
            ".....##..##.....",
            "................",
        ]
        let canvas: CGFloat = 18
        let grid = CGFloat(pixels[0].count)
        let pixel = canvas / grid
        let image = NSImage(size: NSSize(width: canvas, height: canvas))
        image.lockFocus()
        NSColor.black.setFill()
        for (y, row) in pixels.enumerated() {
            for (x, ch) in row.enumerated() where ch == "#" {
                NSRect(
                    x: CGFloat(x) * pixel,
                    y: CGFloat(pixels.count - 1 - y) * pixel,
                    width: pixel,
                    height: pixel
                ).fill()
            }
        }
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
