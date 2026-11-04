// Ported from gpui-pre 0.3.10: src/style.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// Also modified: deliberate deviation DEV-002 (background under an opaque border). See DEVIATIONS.md.
package gpui;

import gpui.scene.BorderStyle;

/**
 * The CSS styling that can be applied to an element via the `Styled` methods.
 *
 * Differences with GPUI: geometry fields are flattened like in
 * `StyleRefinement` (`sizeWidth` for `size.width`, `marginTop` for
 * `margin.top`...). Optional value fields (`aspectRatio`, `alignItems`,
 * `alignSelf`, `alignContent`, `justifyContent`, `mouseCursor`, `opacity`)
 * are `None` unless their `StyleRefinement` bit is set in `optionMask` (see
 * `isSome()`). `background` is a `Background` (GPUI's `Fill` only has the
 * `Fill::Color(Background)` variant). `text` is `null` when no text style is set.
 */
class Style {

    static final ZERO_ABSOLUTE:AbsoluteLength = AbsoluteLength.Pixels(0.0);
    static final ZERO_DEFINITE:DefiniteLength = DefiniteLength.Absolute(ZERO_ABSOLUTE);
    static final ZERO_LENGTH:Length = Length.Definite(ZERO_DEFINITE);
    static final NO_SHADOWS:Array<BoxShadow> = [];
    static final SQUARE_CORNERS:Corners = new Corners(0.0, 0.0, 0.0, 0.0);

    static inline function isPositiveZero(value:Float):Bool {
        return value == 0.0 && 1.0 / value > 0.0;
    }

    /** Bits (`StyleRefinement` constants) of the optional value fields that are `Some` */
    public var optionMask:Int = 0;

    /** What layout strategy should be used? */
    public var display:Display = Block;

    /** Should the element be painted on screen? */
    public var visibility:Visibility = Visible;

    /** How children overflowing their container should affect layout (x axis) */
    public var overflowX:Overflow = Visible;

    /** How children overflowing their container should affect layout (y axis) */
    public var overflowY:Overflow = Visible;

    /** Whether both x and y axis should be scrollable at the same time. */
    public var allowConcurrentScroll:Bool = false;

    /** Whether scrolling should be restricted to the input gesture's axis. */
    public var restrictScrollToAxis:Bool = false;

    /** What should the `position` value of this struct use as a base offset? */
    public var position:Position = Relative;

    /** Sets the preferred aspect ratio for the item (width divided by height). (optional, see `isSome()`) */
    public var aspectRatio:Float = 0.0;

    /** How this node's children aligned in the cross/block axis? (optional, see `isSome()`) */
    public var alignItems:AlignItems = Start;

    /** How this node should be aligned in the cross/block axis. (optional, see `isSome()`) */
    public var alignSelf:AlignItems = Start;

    /** How should content contained within this item be aligned in the cross/block axis (optional, see `isSome()`) */
    public var alignContent:AlignContent = Start;

    /** How should contained within this item be aligned in the main/inline axis (optional, see `isSome()`) */
    public var justifyContent:AlignContent = Start;

    /** Which direction does the main axis flow in? */
    public var flexDirection:FlexDirection = Row;

    /** Should elements wrap, or stay in a single line? */
    public var flexWrap:FlexWrap = NoWrap;

    /** The relative rate at which this item grows when it is expanding to fill space. */
    public var flexGrow:Float = 0.0;

    /** The relative rate at which this item shrinks when it is contracting to fit into space. */
    public var flexShrink:Float = 1.0;

    /** The border style of this element */
    public var borderStyle:gpui.scene.BorderStyle = Solid;

    /** The mouse cursor style shown when the mouse pointer is over an element. (optional, see `isSome()`) */
    public var mouseCursor:CursorStyle = Arrow;

    /** The opacity of this element (optional, see `isSome()`) */
    public var opacity:Float = 1.0;

    /** Whether to draw a red debugging outline around this element */
    public var debug:Bool = false;

    /** Whether to draw a red debugging outline around this element and all of its conforming children */
    public var debugBelow:Bool = false;

    /** How much space (in points) should be reserved for the scrollbars of `Overflow.Scroll` and `Overflow.Auto` nodes. */
    public var scrollbarWidth:AbsoluteLength = ZERO_ABSOLUTE;

    /** Inset (top) */
    public var insetTop:Length = Length.Auto;

    /** Inset (right) */
    public var insetRight:Length = Length.Auto;

    /** Inset (bottom) */
    public var insetBottom:Length = Length.Auto;

    /** Inset (left) */
    public var insetLeft:Length = Length.Auto;

    /** Sets the initial width of the item */
    public var sizeWidth:Length = Length.Auto;

    /** Sets the initial height of the item */
    public var sizeHeight:Length = Length.Auto;

    /** Controls the minimum width of the item */
    public var minSizeWidth:Length = Length.Auto;

    /** Controls the minimum height of the item */
    public var minSizeHeight:Length = Length.Auto;

    /** Controls the maximum width of the item */
    public var maxSizeWidth:Length = Length.Auto;

    /** Controls the maximum height of the item */
    public var maxSizeHeight:Length = Length.Auto;

    /** Margin (top) */
    public var marginTop:Length = ZERO_LENGTH;

    /** Margin (right) */
    public var marginRight:Length = ZERO_LENGTH;

    /** Margin (bottom) */
    public var marginBottom:Length = ZERO_LENGTH;

    /** Margin (left) */
    public var marginLeft:Length = ZERO_LENGTH;

    /** Padding (top) */
    public var paddingTop:DefiniteLength = ZERO_DEFINITE;

    /** Padding (right) */
    public var paddingRight:DefiniteLength = ZERO_DEFINITE;

    /** Padding (bottom) */
    public var paddingBottom:DefiniteLength = ZERO_DEFINITE;

    /** Padding (left) */
    public var paddingLeft:DefiniteLength = ZERO_DEFINITE;

    /** Border width (top) */
    public var borderWidthTop:AbsoluteLength = ZERO_ABSOLUTE;

    /** Border width (right) */
    public var borderWidthRight:AbsoluteLength = ZERO_ABSOLUTE;

    /** Border width (bottom) */
    public var borderWidthBottom:AbsoluteLength = ZERO_ABSOLUTE;

    /** Border width (left) */
    public var borderWidthLeft:AbsoluteLength = ZERO_ABSOLUTE;

    /** Gap between columns */
    public var gapWidth:DefiniteLength = ZERO_DEFINITE;

    /** Gap between rows */
    public var gapHeight:DefiniteLength = ZERO_DEFINITE;

    /** Sets the initial main axis size of the item */
    public var flexBasis:Length = Length.Auto;

    /** The fill of this element (Rust `Fill::Color`, the only `Fill` variant) */
    public var background:Null<Background> = null;

    /** The border color of this element */
    public var borderColor:Null<Hsla> = null;

    /** Corner radius (top left) */
    public var cornerRadiusTopLeft:AbsoluteLength = ZERO_ABSOLUTE;

    /** Corner radius (top right) */
    public var cornerRadiusTopRight:AbsoluteLength = ZERO_ABSOLUTE;

    /** Corner radius (bottom right) */
    public var cornerRadiusBottomRight:AbsoluteLength = ZERO_ABSOLUTE;

    /** Corner radius (bottom left) */
    public var cornerRadiusBottomLeft:AbsoluteLength = ZERO_ABSOLUTE;

    /** Box shadow of the element */
    public var boxShadow:Array<BoxShadow> = NO_SHADOWS;

    /** The text style of this element (created on demand, see `textStyle()`) */
    public var text:Null<TextStyleRefinement> = null;

    /** The grid columns of this element */
    public var gridCols:Null<GridTemplate> = null;

    /** The grid rows of this element */
    public var gridRows:Null<GridTemplate> = null;

    /** The grid location of this element */
    public var gridLocation:Null<GridLocation> = null;

    /**
     * Creates the default style (Rust `Style::default()`).
     */
    static var sharedDefault:Null<Style> = null;

    /**
     * A default style shared by the elements that request their layout with
     * `new Style()` and never change it (the layout only reads it): no
     * allocation per element and frame. Never change it either.
     */
    @:allow(gpui)
    static function sharedDefaultStyle():Style {
        var style = sharedDefault;
        if (style == null) {
            style = new Style();
            sharedDefault = style;
        }
        return style;
    }

    public function new() {
        #if gpui_count_allocations gpui.util.AllocationCounters.styles++; #end
    }

    /**
     * `true` if the optional value field of the given `StyleRefinement` bit is `Some`.
     */
    public inline function isSome(bit:Int):Bool {
        return (optionMask & bit) != 0;
    }

    /**
     * Applies the fields set in the given refinement (Rust `Refineable::refine`).
     */
    public function refine(refinement:StyleRefinement):Void {
        if (refinement == null)
            return;
        final m = refinement.mask;
        if ((m & StyleRefinement.DISPLAY) != 0) display = refinement.display;
        if ((m & StyleRefinement.VISIBILITY) != 0) visibility = refinement.visibility;
        if ((m & StyleRefinement.OVERFLOW_X) != 0) overflowX = refinement.overflowX;
        if ((m & StyleRefinement.OVERFLOW_Y) != 0) overflowY = refinement.overflowY;
        if ((m & StyleRefinement.ALLOW_CONCURRENT_SCROLL) != 0) allowConcurrentScroll = refinement.allowConcurrentScroll;
        if ((m & StyleRefinement.RESTRICT_SCROLL_TO_AXIS) != 0) restrictScrollToAxis = refinement.restrictScrollToAxis;
        if ((m & StyleRefinement.POSITION) != 0) position = refinement.position;
        if ((m & StyleRefinement.ASPECT_RATIO) != 0) aspectRatio = refinement.aspectRatio;
        if ((m & StyleRefinement.ALIGN_ITEMS) != 0) alignItems = refinement.alignItems;
        if ((m & StyleRefinement.ALIGN_SELF) != 0) alignSelf = refinement.alignSelf;
        if ((m & StyleRefinement.ALIGN_CONTENT) != 0) alignContent = refinement.alignContent;
        if ((m & StyleRefinement.JUSTIFY_CONTENT) != 0) justifyContent = refinement.justifyContent;
        if ((m & StyleRefinement.FLEX_DIRECTION) != 0) flexDirection = refinement.flexDirection;
        if ((m & StyleRefinement.FLEX_WRAP) != 0) flexWrap = refinement.flexWrap;
        if ((m & StyleRefinement.FLEX_GROW) != 0) flexGrow = refinement.flexGrow;
        if ((m & StyleRefinement.FLEX_SHRINK) != 0) flexShrink = refinement.flexShrink;
        if ((m & StyleRefinement.BORDER_STYLE) != 0) borderStyle = refinement.borderStyle;
        if ((m & StyleRefinement.MOUSE_CURSOR) != 0) mouseCursor = refinement.mouseCursor;
        if ((m & StyleRefinement.OPACITY) != 0) opacity = refinement.opacity;
        if ((m & StyleRefinement.DEBUG) != 0) debug = refinement.debug;
        if ((m & StyleRefinement.DEBUG_BELOW) != 0) debugBelow = refinement.debugBelow;
        optionMask |= m & (StyleRefinement.ASPECT_RATIO | StyleRefinement.ALIGN_ITEMS | StyleRefinement.ALIGN_SELF | StyleRefinement.ALIGN_CONTENT | StyleRefinement.JUSTIFY_CONTENT | StyleRefinement.MOUSE_CURSOR | StyleRefinement.OPACITY);
        if (refinement.scrollbarWidth != null) scrollbarWidth = refinement.scrollbarWidth;
        if (refinement.insetTop != null) insetTop = refinement.insetTop;
        if (refinement.insetRight != null) insetRight = refinement.insetRight;
        if (refinement.insetBottom != null) insetBottom = refinement.insetBottom;
        if (refinement.insetLeft != null) insetLeft = refinement.insetLeft;
        if (refinement.sizeWidth != null) sizeWidth = refinement.sizeWidth;
        if (refinement.sizeHeight != null) sizeHeight = refinement.sizeHeight;
        if (refinement.minSizeWidth != null) minSizeWidth = refinement.minSizeWidth;
        if (refinement.minSizeHeight != null) minSizeHeight = refinement.minSizeHeight;
        if (refinement.maxSizeWidth != null) maxSizeWidth = refinement.maxSizeWidth;
        if (refinement.maxSizeHeight != null) maxSizeHeight = refinement.maxSizeHeight;
        if (refinement.marginTop != null) marginTop = refinement.marginTop;
        if (refinement.marginRight != null) marginRight = refinement.marginRight;
        if (refinement.marginBottom != null) marginBottom = refinement.marginBottom;
        if (refinement.marginLeft != null) marginLeft = refinement.marginLeft;
        if (refinement.paddingTop != null) paddingTop = refinement.paddingTop;
        if (refinement.paddingRight != null) paddingRight = refinement.paddingRight;
        if (refinement.paddingBottom != null) paddingBottom = refinement.paddingBottom;
        if (refinement.paddingLeft != null) paddingLeft = refinement.paddingLeft;
        if (refinement.borderWidthTop != null) borderWidthTop = refinement.borderWidthTop;
        if (refinement.borderWidthRight != null) borderWidthRight = refinement.borderWidthRight;
        if (refinement.borderWidthBottom != null) borderWidthBottom = refinement.borderWidthBottom;
        if (refinement.borderWidthLeft != null) borderWidthLeft = refinement.borderWidthLeft;
        if (refinement.gapWidth != null) gapWidth = refinement.gapWidth;
        if (refinement.gapHeight != null) gapHeight = refinement.gapHeight;
        if (refinement.flexBasis != null) flexBasis = refinement.flexBasis;
        if (refinement.background != null) background = refinement.background;
        if (refinement.borderColor != null) borderColor = refinement.borderColor;
        if (refinement.cornerRadiusTopLeft != null) cornerRadiusTopLeft = refinement.cornerRadiusTopLeft;
        if (refinement.cornerRadiusTopRight != null) cornerRadiusTopRight = refinement.cornerRadiusTopRight;
        if (refinement.cornerRadiusBottomRight != null) cornerRadiusBottomRight = refinement.cornerRadiusBottomRight;
        if (refinement.cornerRadiusBottomLeft != null) cornerRadiusBottomLeft = refinement.cornerRadiusBottomLeft;
        if (refinement.boxShadow != null) boxShadow = refinement.boxShadow;
        if (refinement.text != null) {
            if (text == null) text = new TextStyleRefinement();
            text.refine(refinement.text);
        }
        if (refinement.gridCols != null) gridCols = refinement.gridCols;
        if (refinement.gridRows != null) gridRows = refinement.gridRows;
        if (refinement.gridLocation != null) gridLocation = refinement.gridLocation.clone();
    }

    /**
     * Returns true if the style is visible and the background is opaque.
     */
    public function hasOpaqueBackground():Bool {
        return background != null && !background.isTransparent();
    }

    /**
     * Get the text style in this element style, `null` if it sets nothing.
     */
    public function textStyle():Null<TextStyleRefinement> {
        return text != null && text.isSome() ? text : null;
    }

    /**
     * Get the content mask for this element style, based on the given bounds.
     * If the element does not hide its overflow, this will return `null`.
     */
    public function overflowMask(bounds:Bounds, remSize:Pixels):Null<ContentMask> {
        if (!computeOverflowMask(bounds, remSize)) {
            return null;
        }
        return new ContentMask(new Bounds(
            new Point(overflowMaskX, overflowMaskY),
            new Size(overflowMaskWidth, overflowMaskHeight)
        ));
    }

    /** The bounds of the last `computeOverflowMask()` that returned true */
    @:allow(gpui) static var overflowMaskX:Float = 0;
    @:allow(gpui) static var overflowMaskY:Float = 0;
    @:allow(gpui) static var overflowMaskWidth:Float = 0;
    @:allow(gpui) static var overflowMaskHeight:Float = 0;

    /**
     * The bounds of `overflowMask()` (the same operations, Rust's
     * `Bounds::from_corners`) into `overflowMaskX`, `overflowMaskY`,
     * `overflowMaskWidth` and `overflowMaskHeight`, without allocating;
     * false when there is no mask.
     */
    @:allow(gpui)
    function computeOverflowMask(bounds:Bounds, remSize:Pixels):Bool {
        final xVisible = overflowX == Overflow.Visible;
        final yVisible = overflowY == Overflow.Visible;
        if (xVisible && yVisible) {
            return false;
        }

        var minX = bounds.origin.x;
        var minY = bounds.origin.y;
        var maxX = bounds.origin.x + bounds.size.width;
        var maxY = bounds.origin.y + bounds.size.height;

        if (borderColor != null && !borderColor.isTransparent()) {
            final left:Float = borderWidthLeft.toPixels(remSize);
            final right:Float = borderWidthRight.toPixels(remSize);
            final top:Float = borderWidthTop.toPixels(remSize);
            final bottom:Float = borderWidthBottom.toPixels(remSize);
            minX += left;
            maxX -= right;
            minY += top;
            maxY -= bottom;
        }

        var topLeftX = minX;
        var topLeftY = minY;
        var bottomRightX = maxX;
        var bottomRightY = maxY;
        if (xVisible) {
            // x visible, y hidden
            topLeftY = bounds.origin.y;
            bottomRightY = bounds.origin.y + bounds.size.height;
        }
        else if (yVisible) {
            // x hidden, y visible
            topLeftX = bounds.origin.x;
            bottomRightX = bounds.origin.x + bounds.size.width;
        }
        // Bounds::from_corners
        overflowMaskX = topLeftX;
        overflowMaskY = topLeftY;
        overflowMaskWidth = bottomRightX - topLeftX;
        overflowMaskHeight = bottomRightY - topLeftY;
        return true;
    }

    /**
     * Paints the background of an element styled with this style, then calls
     * `continuation` (children), then paints the border on top.
     */
    public function paint(bounds:Bounds, window:Window, cx:App, continuation:(Window, App) -> Void):Void {
        final cornerRadii = paintBackground(bounds, window, cx);
        continuation(window, cx);
        paintBorder(bounds, cornerRadii, window, cx);
    }

    /**
     * First half of `paint()`: drop shadows, background and inset shadows.
     * Returns the corner radii in pixels, to give to `paintBorder()`.
     * (Split so elements can paint their children in between without a closure.)
     */
    public function paintBackground(bounds:Bounds, window:Window, cx:App):Corners {
        final remSize = window.remSize();
        // `Corners.clampRadiiForQuadSize()` inlined: square corners (all +0,
        // the common case) share one `Corners` (immutable)
        final size = bounds.size;
        final max = (size.width <= size.height ? size.width : size.height) / 2.0;
        final topLeft:Float = cornerRadiusTopLeft.toPixels(remSize);
        final topRight:Float = cornerRadiusTopRight.toPixels(remSize);
        final bottomRight:Float = cornerRadiusBottomRight.toPixels(remSize);
        final bottomLeft:Float = cornerRadiusBottomLeft.toPixels(remSize);
        final clampedTopLeft = topLeft <= max ? topLeft : max;
        final clampedTopRight = topRight <= max ? topRight : max;
        final clampedBottomRight = bottomRight <= max ? bottomRight : max;
        final clampedBottomLeft = bottomLeft <= max ? bottomLeft : max;
        final cornerRadii = isPositiveZero(clampedTopLeft) && isPositiveZero(clampedTopRight)
            && isPositiveZero(clampedBottomRight) && isPositiveZero(clampedBottomLeft)
            ? SQUARE_CORNERS
            : new Corners(clampedTopLeft, clampedTopRight, clampedBottomRight, clampedBottomLeft);

        window.paintDropShadows(bounds, cornerRadii, boxShadow);

        final backgroundColor = background;
        if (backgroundColor != null && !backgroundColor.isTransparent()) {
            final borderColor:Hsla = switch backgroundColor.tag {
                case Solid | PatternSlash | Checkerboard: backgroundColor.solid;
                case LinearGradient: backgroundColor.colors0.color;
            }
            final quad = window.scratchPaintQuad();
            quad.bounds = bounds;
            quad.cornerRadii = cornerRadii;
            // Deliberate deviation DEV-002: the background of a rounded element
            // with an opaque border stops under the middle of the border.
            backgroundUnderBorder(quad, window);
            quad.background = backgroundColor;
            quad.setBorderWidths(0, 0, 0, 0);
            quad.setBorderColor(borderColor.h, borderColor.s, borderColor.l, 0.0);
            quad.borderStyle = borderStyle;
            window.paintQuad(quad);
        }

        window.paintInsetShadows(bounds, cornerRadii, boxShadow);

        return cornerRadii;
    }

    /**
     * Second half of `paint()`: the border, painted over the children.
     */
    public function paintBorder(bounds:Bounds, cornerRadii:Corners, window:Window, cx:App):Void {
        if (isBorderVisible()) {
            final remSize = window.remSize();
            final color = borderColor;
            final quad = window.scratchPaintQuad();
            quad.bounds = bounds;
            quad.cornerRadii = cornerRadii;
            quad.setSolidBackground(color.h, color.s, color.l, 0.0);
            quad.setBorderWidths(
                borderWidthTop.toPixels(remSize),
                borderWidthRight.toPixels(remSize),
                borderWidthBottom.toPixels(remSize),
                borderWidthLeft.toPixels(remSize)
            );
            quad.setBorderColor(color.h, color.s, color.l, color.a);
            quad.borderStyle = borderStyle;
            window.paintQuad(quad);
        }
    }

    /**
     * Deliberate deviation DEV-002 (see DEVIATIONS.md). `paint` draws the
     * background and the border as two quads on the same outer edge, each
     * antialiased on its own, so on a rounded edge the background color leaked
     * through the antialiased outer edge of the border. When the border is
     * solid, opaque and of one width on every side, and the background is a
     * solid color, the background quad (`quad.bounds` and `quad.cornerRadii`)
     * is inset by half the border width (in whole device pixels) with its radii
     * reduced by the same amount: its antialiased edge then lies where the
     * border is opaque. Other cases keep the original bounds.
     */
    function backgroundUnderBorder(quad:PaintQuad, window:Window):Void {
        final backgroundColor = background;
        if (backgroundColor == null || backgroundColor.tag != BackgroundTag.Solid) return;
        if (borderColor == null || borderColor.a < 1.0 || window.currentElementOpacity() < 1.0) return;
        if (!isBorderVisible() || borderStyle != BorderStyle.Solid) return;
        final remSize = window.remSize();
        final width:Float = borderWidthTop.toPixels(remSize);
        if (borderWidthRight.toPixels(remSize) != width || borderWidthBottom.toPixels(remSize) != width
            || borderWidthLeft.toPixels(remSize) != width) return;
        final radii = quad.cornerRadii;
        final rounded = radii.topLeft > 0 || radii.topRight > 0 || radii.bottomRight > 0 || radii.bottomLeft > 0;
        final scaleFactor = window.scaleFactor();
        final deviceInset = Math.ffloor(TaffyLayoutEngine.roundStrokeToDevicePixel(width, scaleFactor) / 2.0);
        if (!rounded || deviceInset <= 0) return;
        final inset = deviceInset / scaleFactor;
        inline function reduce(radius:Float):Float {
            return radius > inset ? radius - inset : 0.0;
        }
        quad.bounds = quad.bounds.inset(inset);
        quad.cornerRadii = new Corners(reduce(radii.topLeft), reduce(radii.topRight), reduce(radii.bottomRight), reduce(radii.bottomLeft));
    }

    function isBorderVisible():Bool {
        return borderColor != null && !borderColor.isTransparent()
            && (!borderWidthTop.isZero() || !borderWidthRight.isZero() || !borderWidthBottom.isZero() || !borderWidthLeft.isZero());
    }

}
