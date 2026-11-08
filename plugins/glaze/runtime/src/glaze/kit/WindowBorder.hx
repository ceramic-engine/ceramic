// Ported from gpui-kit 0.8.1: crates/component/src/window_border.rs
// (itself from Zed's crates/gpui/examples/window_shadow.rs)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit;

import glaze.AnyElement;
import glaze.App;
import glaze.BoxShadow;
import glaze.CursorStyle;
import glaze.Decorations;
import glaze.Edges;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.OperatingSystem;
import glaze.ParentElement;
import glaze.Pixels;
import glaze.Point;
import glaze.RenderOnce;
import glaze.ResizeEdge;
import glaze.Size;
import glaze.Window;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;

/**
 * Renders a custom window border and shadow on Linux.
 *
 * With server side decorations (macOS, Windows, the web, and the port's
 * windows, which are always server decorated unless a test sets
 * `Window.platformDecorations`), the border renders its children unchanged.
 * With client side decorations it draws the frame: shadow padding, a 1px
 * border, the shadow and the resize hit zones.
 *
 * The free functions of the Rust module (`window_border`, `window_paddings`,
 * `window_content_insets`, `window_safe_insets`) are static functions here.
 */
class WindowBorder implements RenderOnce implements ParentElement {

    /**
     * The shadow size of typical Linux client side decorations: 20 on Linux,
     * 0 elsewhere (Rust decides it at compile time, the port from
     * `OperatingSystem.current`).
     */
    public static var SHADOW_SIZE(get, never):Pixels;

    static function get_SHADOW_SIZE():Pixels {
        return OperatingSystem.current == Linux ? px(20.0) : px(0.0);
    }

    static inline final BORDER_SIZE:Pixels = 1.0;

    /** Half-width of the resize hit band on each side of the visible frame (inner border). */
    static inline final RESIZE_HIT_SIZE:Pixels = 4.0;

    /**
     * GPUI currently clips overflowing children to a rectangular content mask. A non-zero
     * radius here would round the frame itself but leave child backgrounds visible in the
     * corners, so keep the generic window wrapper square until rounded content masks exist.
     */
    static inline final BORDER_RADIUS:Pixels = 0.0;

    var shadowSizeValue:Pixels;

    var resizeHitSizeValue:Pixels;

    final childElements:Array<AnyElement> = [];

    public function new() {
        shadowSizeValue = SHADOW_SIZE;
        resizeHitSizeValue = RESIZE_HIT_SIZE;
    }

    /**
     * Create a new window border.
     */
    public static function windowBorder():WindowBorder {
        return WindowBorder.component();
    }

    /**
     * Set the shadow size for typical Linux client-side decorations.
     *
     * Default: `SHADOW_SIZE`
     */
    public function shadowSize(size:Pixels):WindowBorder {
        shadowSizeValue = size;
        return this;
    }

    /**
     * Set the resize hit band half-width around the visible inner frame edge.
     *
     * Default: `RESIZE_HIT_SIZE`
     */
    public function resizeHitSize(size:Pixels):WindowBorder {
        resizeHitSizeValue = size;
        return this;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):WindowBorder {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):WindowBorder {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    /**
     * Per-side inset of the visible frame from the outer window bounds.
     */
    @:allow(tests)
    static function clientFrameInsets(shadowSize:Pixels, tiling:Tiling):Edges {
        return new Edges(
            tiling.top ? px(0.0) : shadowSize,
            tiling.right ? px(0.0) : shadowSize,
            tiling.bottom ? px(0.0) : shadowSize,
            tiling.left ? px(0.0) : shadowSize
        );
    }

    /**
     * Get the window paddings.
     */
    public static function windowPaddings(window:Window):Edges {
        final inset = window.clientInset();
        final shadowSize:Pixels = inset != null ? inset : SHADOW_SIZE;
        return switch window.windowDecorations() {
            case Server: Edges.all(px(0.0));
            case Client(tiling): clientFrameInsets(shadowSize, tiling);
        }
    }

    /**
     * Per-side inset from the window bounds to the visible frame's content area.
     *
     * This is `windowPaddings` plus the frame's own border, which the window
     * wrapper draws on every side it is not tiled against. Allows to lay an element
     * flush against the inside of the window frame.
     */
    public static function windowContentInsets(window:Window):Edges {
        final inset = window.clientInset();
        final shadowSize:Pixels = inset != null ? inset : SHADOW_SIZE;
        return switch window.windowDecorations() {
            case Server: Edges.all(px(0.0));
            case Client(tiling):
                final insets = clientFrameInsets(shadowSize, tiling);
                new Edges(
                    !tiling.top ? insets.top + BORDER_SIZE : insets.top,
                    !tiling.right ? insets.right + BORDER_SIZE : insets.right,
                    !tiling.bottom ? insets.bottom + BORDER_SIZE : insets.bottom,
                    !tiling.left ? insets.left + BORDER_SIZE : insets.left
                );
        }
    }

    /**
     * Per-side inset from the window bounds to the part of the window that is
     * fully visible: not under the system bars, a display cutout or the on-screen
     * keyboard (`Window.fullyVisibleBounds`). Zero on desktop.
     */
    public static function windowSafeInsets(window:Window):Edges {
        final viewport = window.viewportSize();
        final visible = window.fullyVisibleBounds();
        return new Edges(
            visible.top(),
            viewport.width - visible.right(),
            viewport.height - visible.bottom(),
            visible.left()
        );
    }

    @:allow(tests)
    static function usesClientBorder(decorations:Decorations):Bool {
        return switch decorations {
            case Client(_): true;
            case Server: false;
        }
    }

    public function render(window:Window, cx:App):IntoElement {
        final decorations = window.windowDecorations();
        final children = childElements;
        if (!usesClientBorder(decorations)) {
            return switch children.length {
                case 1: children[0];
                case _: div().sizeFull().children(cast children);
            }
        }
        final tiling = switch decorations {
            case Client(tiling): tiling;
            case Server: throw 'client border requires client decorations';
        };

        // Keep the platform client inset stable. When the window is tiled on all sides we stop drawing
        // shadow padding, but `set_client_inset` must still use the full shadow size. Clearing it
        // makes the first resize after restore double-count the shadow in `compute_outer_size`, and
        // the window jumps larger.
        final platformInset = shadowSizeValue;
        final visualShadow = if (tiling.top && tiling.bottom && tiling.left && tiling.right) {
            px(0.0);
        } else {
            shadowSizeValue;
        };
        final resizeHitSize = resizeHitSizeValue;
        window.setClientInset(platformInset);
        // Rust `window.window_bounds().get_bounds().size`: the port has no
        // platform window bounds, the window is its viewport.
        final windowSize = window.viewportSize();
        final isWindowActive = window.isWindowActive();
        final borderColor = if (Theme.global(cx).isDark()) {
            hsla(0., 0., 0.2, 1.0);
        } else {
            hsla(0., 0., 0.8, 1.0);
        };

        final backdrop = div()
            .id('window-backdrop')
            .bg(transparentBlack())
            .flex()
            .flexCol()
            .overflowHidden();
        if (!(tiling.top || tiling.right)) backdrop.roundedTr(BORDER_RADIUS);
        if (!(tiling.top || tiling.left)) backdrop.roundedTl(BORDER_RADIUS);
        if (!tiling.top) backdrop.pt(visualShadow);
        if (!tiling.bottom) backdrop.pb(visualShadow);
        if (!tiling.left) backdrop.pl(visualShadow);
        if (!tiling.right) backdrop.pr(visualShadow);
        backdrop.onMouseDown(Left, (_, window, _) -> {
            final tiling = switch window.windowDecorations() {
                case Client(tiling): tiling;
                case Server: return;
            };
            if (!window.isResizable()) {
                return;
            }
            if (tiling.top && tiling.bottom && tiling.left && tiling.right) {
                return;
            }
            final size = window.viewportSize();
            final pos = window.mousePosition();
            final insets = clientFrameInsets(platformInset, tiling);

            final edge = resizeEdge(pos, size, insets, tiling, resizeHitSize);
            if (edge != null) window.startWindowResize(edge);
        })
            .sizeFull();

        final frame = div()
            .cursor(CursorStyle.Arrow)
            .flex1()
            .minH0()
            .minW0()
            .overflowHidden();
        if (!(tiling.top || tiling.right)) frame.roundedTr(BORDER_RADIUS);
        if (!(tiling.top || tiling.left)) frame.roundedTl(BORDER_RADIUS);
        frame.borderColor(borderColor);
        if (!tiling.top) frame.borderT(BORDER_SIZE);
        if (!tiling.bottom) frame.borderB(BORDER_SIZE);
        if (!tiling.left) frame.borderL(BORDER_SIZE);
        if (!tiling.right) frame.borderR(BORDER_SIZE);
        if (!tiling.isTiled()) {
            final opacity = isWindowActive ? 1.0 : 0.7;
            frame.shadow([
                // Keep the effective outer reach below SHADOW_SIZE. GPUI
                // does not grow the paint bounds for blur, so a larger blur
                // or offset would be visibly cut off by the window surface.
                //
                // GNOME-style ambient shadow: horizontally centered
                // with only a slight downward bias.
                new BoxShadow(px(0.0), px(2.0), hsla(0., 0., 0., 0.18 * opacity))
                    .withBlurRadius(px(10.))
                    .withSpreadRadius(px(-1.)),
                // The contact layer adds definition without increasing the
                // space between the content and the outer window bounds.
                new BoxShadow(px(0.0), px(1.0), hsla(0., 0., 0., 0.18 * opacity))
                    .withBlurRadius(px(3.))
                    .withSpreadRadius(px(0.)),
            ]);
        }
        frame.onMouseMove((_, _, cx) -> {
            cx.stopPropagation();
        })
            .bg(transparentBlack())
            .extend(children);
        backdrop.child(frame);

        if (window.isResizable()) {
            final nativeZones:Array<Float> = [];
            backdrop.child(div().absolute().sizeFull().children(cast resizeHitZones(
                windowSize,
                platformInset,
                resizeHitSize,
                tiling,
                nativeZones
            )));
            window.nativeResizeZones = nativeZones;
        }
        else {
            window.nativeResizeZones = null;
        }
        return backdrop;
    }

    @:allow(tests)
    static function cursorStyleForResizeEdge(edge:ResizeEdge):CursorStyle {
        return switch edge {
            case Top | Bottom: ResizeUpDown;
            case Left | Right: ResizeLeftRight;
            case TopLeft | BottomRight: ResizeUpLeftDownRight;
            case TopRight | BottomLeft: ResizeUpRightDownLeft;
        }
    }

    /**
     * Cursor-only overlay for each resize edge/corner. Resize starts from the backdrop
     * `onMouseDown` via `resizeEdge`. `.cursor()` updates immediately on hitbox changes
     * without `window.refresh()` (PR #617).
     */
    @:allow(tests)
    /** The native hit kind of a resize edge (port addition, `ceramic.WindowHitKind`). */
    static function nativeHitKind(edge:ResizeEdge):Int {
        return switch edge {
            case TopLeft: ceramic.WindowHitKind.RESIZE_TOP_LEFT;
            case Top: ceramic.WindowHitKind.RESIZE_TOP;
            case TopRight: ceramic.WindowHitKind.RESIZE_TOP_RIGHT;
            case Right: ceramic.WindowHitKind.RESIZE_RIGHT;
            case BottomRight: ceramic.WindowHitKind.RESIZE_BOTTOM_RIGHT;
            case Bottom: ceramic.WindowHitKind.RESIZE_BOTTOM;
            case BottomLeft: ceramic.WindowHitKind.RESIZE_BOTTOM_LEFT;
            case Left: ceramic.WindowHitKind.RESIZE_LEFT;
        }
    }

    static function resizeHitZones(windowSize:Size, shadowSize:Float, hitSize:Float, tiling:Tiling, ?nativeZones:Array<Float>):Array<AnyElement> {
        if (tiling.top && tiling.bottom && tiling.left && tiling.right) {
            return [];
        }

        final insets = clientFrameInsets(shadowSize, tiling);
        final innerLeft:Float = insets.left;
        final innerRight:Float = windowSize.width - insets.right;
        final innerTop:Float = insets.top;
        final innerBottom:Float = windowSize.height - insets.bottom;
        // Overlay is laid out in the padded content box; convert from window coords.
        final frameOrigin = new Point(insets.left, insets.top);
        final band = hitSize + hitSize;
        final spanX = innerRight - innerLeft + band;
        final spanY = innerBottom - innerTop + band;

        final zones:Array<AnyElement> = [];

        function pushZone(edge:ResizeEdge, origin:Point, zoneSize:Size):Void {
            if (nativeZones != null) {
                // Port addition: the same zone in window coordinates for the
                // native window (see Window.nativeResizeZones)
                nativeZones.push(origin.x);
                nativeZones.push(origin.y);
                nativeZones.push(zoneSize.width);
                nativeZones.push(zoneSize.height);
                nativeZones.push(nativeHitKind(edge));
            }
            final origin = origin.sub(frameOrigin);
            zones.push(div()
                .absolute()
                .left(px(origin.x))
                .top(px(origin.y))
                .w(px(zoneSize.width))
                .h(px(zoneSize.height))
                .cursor(cursorStyleForResizeEdge(edge))
                .intoAnyElement());
        }

        if (!tiling.top) {
            pushZone(ResizeEdge.Top, new Point(innerLeft - hitSize, innerTop - hitSize), new Size(spanX, band));
        }
        if (!tiling.bottom) {
            pushZone(ResizeEdge.Bottom, new Point(innerLeft - hitSize, innerBottom - hitSize), new Size(spanX, band));
        }
        if (!tiling.left) {
            pushZone(ResizeEdge.Left, new Point(innerLeft - hitSize, innerTop - hitSize), new Size(band, spanY));
        }
        if (!tiling.right) {
            pushZone(ResizeEdge.Right, new Point(innerRight - hitSize, innerTop - hitSize), new Size(band, spanY));
        }

        // Corners are pushed after edge strips so hit-testing prefers them over adjacent edges.
        if (!tiling.top && !tiling.left) {
            pushZone(ResizeEdge.TopLeft, new Point(innerLeft - hitSize, innerTop - hitSize), new Size(band, band));
        }
        if (!tiling.top && !tiling.right) {
            pushZone(ResizeEdge.TopRight, new Point(innerRight - hitSize, innerTop - hitSize), new Size(band, band));
        }
        if (!tiling.bottom && !tiling.left) {
            pushZone(ResizeEdge.BottomLeft, new Point(innerLeft - hitSize, innerBottom - hitSize), new Size(band, band));
        }
        if (!tiling.bottom && !tiling.right) {
            pushZone(ResizeEdge.BottomRight, new Point(innerRight - hitSize, innerBottom - hitSize), new Size(band, band));
        }

        return zones;
    }

    /**
     * Hit-test resize edges on a narrow band around the visible inner frame, not the full shadow padding.
     */
    @:allow(tests)
    static function resizeEdge(pos:Point, size:Size, insets:Edges, tiling:Tiling, hitSize:Float):Null<ResizeEdge> {
        final innerLeft:Float = insets.left;
        final innerRight:Float = size.width - insets.right;
        final innerTop:Float = insets.top;
        final innerBottom:Float = size.height - insets.bottom;

        // Each edge only applies along its corresponding inner-frame segment; it does not extend along the "extension lines" of the shadow padding.
        final onLeft = pos.x >= innerLeft - hitSize
            && pos.x <= innerLeft + hitSize
            && pos.y >= innerTop - hitSize
            && pos.y <= innerBottom + hitSize;
        final onRight = pos.x >= innerRight - hitSize
            && pos.x <= innerRight + hitSize
            && pos.y >= innerTop - hitSize
            && pos.y <= innerBottom + hitSize;
        final onTop = pos.y >= innerTop - hitSize
            && pos.y <= innerTop + hitSize
            && pos.x >= innerLeft - hitSize
            && pos.x <= innerRight + hitSize;
        final onBottom = pos.y >= innerBottom - hitSize
            && pos.y <= innerBottom + hitSize
            && pos.x >= innerLeft - hitSize
            && pos.x <= innerRight + hitSize;

        if (!tiling.top && !tiling.left && onTop && onLeft) {
            return ResizeEdge.TopLeft;
        }
        if (!tiling.top && !tiling.right && onTop && onRight) {
            return ResizeEdge.TopRight;
        }
        if (!tiling.bottom && !tiling.left && onBottom && onLeft) {
            return ResizeEdge.BottomLeft;
        }
        if (!tiling.bottom && !tiling.right && onBottom && onRight) {
            return ResizeEdge.BottomRight;
        }
        if (!tiling.top && onTop) {
            return ResizeEdge.Top;
        }
        if (!tiling.bottom && onBottom) {
            return ResizeEdge.Bottom;
        }
        if (!tiling.left && onLeft) {
            return ResizeEdge.Left;
        }
        if (!tiling.right && onRight) {
            return ResizeEdge.Right;
        }
        return null;
    }

}
