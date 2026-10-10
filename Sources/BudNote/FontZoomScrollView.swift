import AppKit

/// Command-wheel zoom belongs to the editor's scroll view, so it also works
/// over the gutter and editor padding. Ordinary scrolling stays with AppKit.
final class FontZoomScrollView: NSScrollView {
    private var zoomDelta: CGFloat = 0
    override func tile() {
        super.tile()
        // Some AppKit versions keep the clip view underneath sibling tracks
        // and reserve only scrolling insets. Use an actual clipped viewport.
        var viewport = contentView.frame
        if rulersVisible, let ruler = verticalRulerView, !ruler.isHidden {
            let edge = convert(ruler.bounds, from: ruler).maxX
            let right = viewport.maxX
            viewport.origin.x = max(viewport.minX, edge)
            viewport.size.width = max(0, right - viewport.minX)
        }
        if scrollerStyle == .legacy {
            if hasVerticalScroller, let scroller = verticalScroller, !scroller.isHidden {
                let track = convert(scroller.bounds, from: scroller)
                viewport.size.width = max(0, min(viewport.maxX, track.minX) - viewport.minX)
            }
            if hasHorizontalScroller, let scroller = horizontalScroller, !scroller.isHidden {
                let track = convert(scroller.bounds, from: scroller)
                if track.midY >= bounds.midY {
                    viewport.size.height = max(0, min(viewport.maxY, track.minY) - viewport.minY)
                } else {
                    let top = viewport.maxY
                    viewport.origin.y = max(viewport.minY, track.maxY)
                    viewport.size.height = max(0, top - viewport.minY)
                }
            }
        }
        if contentView.frame != viewport { contentView.frame = viewport }
    }
    override func scrollWheel(with event: NSEvent) {
        guard event.modifierFlags.contains(.command) else {
            zoomDelta = 0
            super.scrollWheel(with: event)
            return
        }
        // Trackpad momentum must not continue changing the font after release.
        guard event.momentumPhase.isEmpty else { return }
        if event.phase.contains(.began) { zoomDelta = 0 }
        defer {
            if event.phase.contains(.ended) || event.phase.contains(.cancelled) { zoomDelta = 0 }
        }
        let delta = event.isDirectionInvertedFromDevice ? -event.scrollingDeltaY : event.scrollingDeltaY
        guard delta != 0 else { return }
        let steps: Int
        if event.hasPreciseScrollingDeltas {
            zoomDelta = max(-36, min(36, zoomDelta + delta))
            steps = max(-3, min(3, Int(zoomDelta / 12)))
            if steps != 0 { zoomDelta -= CGFloat(steps) * 12 }
        } else {
            zoomDelta = 0
            steps = delta > 0 ? 1 : -1
        }
        if steps != 0 {
            let preferences = Preferences.shared
            let size = min(40, max(10, preferences.fontSize + Double(steps)))
            if size != preferences.fontSize { preferences.fontSize = size }
        }
    }
}
