// Ported from gpui-pre-derive-refineable 0.3.10: src/derive_refineable.rs (`is_superset_of` and
// `subtract` of `impl Refineable for StyleRefinement` / `TextStyleRefinement`, generated for
// gpui-pre 0.3.10's src/style.rs) and gpui-pre-refineable 0.3.10 (the trait)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * `Refineable::is_superset_of` and `Refineable::subtract` of
 * `StyleRefinement` (and the `TextStyleRefinement` inside it), as the derive
 * generates them for a refinement:
 *
 * - `a.isSupersetOf(b)`: every field set in `b` is set to the same value in
 *   `a` (nested refinements recursively);
 * - `a.subtract(b)`: `a` without the fields equal in `b` (a field set in `a`
 *   and unset in `b` stays; nested refinements recursively).
 *
 * Use with `using glaze.StyleRefinementOps;`. The port's `debug` and
 * `debugBelow` fields only exist in Rust debug builds and are ignored.
 */
class StyleRefinementOps {

    /** `Option` equality of a value type field of `StyleRefinement` */
    static function fieldEq(a:StyleRefinement, b:StyleRefinement, bit:Int):Bool {
        if (a.has(bit) != b.has(bit)) return false;
        if (!a.has(bit)) return true;
        return switch bit {
            case StyleRefinement.DISPLAY: a.display == b.display;
            case StyleRefinement.VISIBILITY: a.visibility == b.visibility;
            case StyleRefinement.OVERFLOW_X: a.overflowX == b.overflowX;
            case StyleRefinement.OVERFLOW_Y: a.overflowY == b.overflowY;
            case StyleRefinement.ALLOW_CONCURRENT_SCROLL: a.allowConcurrentScroll == b.allowConcurrentScroll;
            case StyleRefinement.RESTRICT_SCROLL_TO_AXIS: a.restrictScrollToAxis == b.restrictScrollToAxis;
            case StyleRefinement.POSITION: a.position == b.position;
            case StyleRefinement.ASPECT_RATIO: a.aspectRatio == b.aspectRatio;
            case StyleRefinement.ALIGN_ITEMS: a.alignItems == b.alignItems;
            case StyleRefinement.ALIGN_SELF: a.alignSelf == b.alignSelf;
            case StyleRefinement.ALIGN_CONTENT: a.alignContent == b.alignContent;
            case StyleRefinement.JUSTIFY_CONTENT: a.justifyContent == b.justifyContent;
            case StyleRefinement.FLEX_DIRECTION: a.flexDirection == b.flexDirection;
            case StyleRefinement.FLEX_WRAP: a.flexWrap == b.flexWrap;
            case StyleRefinement.FLEX_GROW: a.flexGrow == b.flexGrow;
            case StyleRefinement.FLEX_SHRINK: a.flexShrink == b.flexShrink;
            case StyleRefinement.BORDER_STYLE: a.borderStyle == b.borderStyle;
            case StyleRefinement.MOUSE_CURSOR: a.mouseCursor == b.mouseCursor;
            case StyleRefinement.OPACITY: a.opacity == b.opacity;
            case _: true;
        }
    }

    /** The value type fields of `StyleRefinement` (without the debug ones) */
    static final STYLE_BITS = [
        StyleRefinement.DISPLAY, StyleRefinement.VISIBILITY, StyleRefinement.OVERFLOW_X, StyleRefinement.OVERFLOW_Y,
        StyleRefinement.ALLOW_CONCURRENT_SCROLL, StyleRefinement.RESTRICT_SCROLL_TO_AXIS, StyleRefinement.POSITION,
        StyleRefinement.ASPECT_RATIO, StyleRefinement.ALIGN_ITEMS, StyleRefinement.ALIGN_SELF, StyleRefinement.ALIGN_CONTENT,
        StyleRefinement.JUSTIFY_CONTENT, StyleRefinement.FLEX_DIRECTION, StyleRefinement.FLEX_WRAP, StyleRefinement.FLEX_GROW,
        StyleRefinement.FLEX_SHRINK, StyleRefinement.BORDER_STYLE, StyleRefinement.MOUSE_CURSOR, StyleRefinement.OPACITY
    ];

    static inline function objEq<T>(a:Null<T>, b:Null<T>, eq:(T, T) -> Bool):Bool {
        return a == null ? b == null : b != null && eq(a, b);
    }

    static function lengthEq(a:Length, b:Length):Bool return LengthTools.equals(a, b);

    static function definiteEq(a:DefiniteLength, b:DefiniteLength):Bool return DefiniteLengthTools.equals(a, b);

    static function absoluteEq(a:AbsoluteLength, b:AbsoluteLength):Bool return AbsoluteLengthTools.equals(a, b);

    static function hslaEq(a:Hsla, b:Hsla):Bool return a.equals(b);

    static function backgroundEq(a:Background, b:Background):Bool return a.equals(b);

    static function shadowsEq(a:Array<BoxShadow>, b:Array<BoxShadow>):Bool return RefinementEq.shadows(a, b);

    static function gridTemplateEq(a:GridTemplate, b:GridTemplate):Bool return a.equals(b);

    static function gridLocationEq(a:GridLocation, b:GridLocation):Bool return a.equals(b);

    /** Rust `refinement.f.is_some() && self.f != refinement.f` is false */
    static inline function covers<T>(self:Null<T>, refinement:Null<T>, eq:(T, T) -> Bool):Bool {
        return refinement == null || objEq(self, refinement, eq);
    }

    /** `if self.f == refinement.f { None } else { self.f.clone() }` */
    static inline function minus<T>(self:Null<T>, refinement:Null<T>, eq:(T, T) -> Bool):Null<T> {
        return objEq(self, refinement, eq) ? null : self;
    }

    /**
     * Returns `true` if every field set in `refinement` has the same value in `self`.
     */
    public static function isSupersetOf(self:StyleRefinement, refinement:StyleRefinement):Bool {
        for (bit in STYLE_BITS) {
            if (refinement.has(bit) && !fieldEq(self, refinement, bit)) return false;
        }
        return covers(self.scrollbarWidth, refinement.scrollbarWidth, absoluteEq)
            && covers(self.insetTop, refinement.insetTop, lengthEq)
            && covers(self.insetRight, refinement.insetRight, lengthEq)
            && covers(self.insetBottom, refinement.insetBottom, lengthEq)
            && covers(self.insetLeft, refinement.insetLeft, lengthEq)
            && covers(self.sizeWidth, refinement.sizeWidth, lengthEq)
            && covers(self.sizeHeight, refinement.sizeHeight, lengthEq)
            && covers(self.minSizeWidth, refinement.minSizeWidth, lengthEq)
            && covers(self.minSizeHeight, refinement.minSizeHeight, lengthEq)
            && covers(self.maxSizeWidth, refinement.maxSizeWidth, lengthEq)
            && covers(self.maxSizeHeight, refinement.maxSizeHeight, lengthEq)
            && covers(self.marginTop, refinement.marginTop, lengthEq)
            && covers(self.marginRight, refinement.marginRight, lengthEq)
            && covers(self.marginBottom, refinement.marginBottom, lengthEq)
            && covers(self.marginLeft, refinement.marginLeft, lengthEq)
            && covers(self.paddingTop, refinement.paddingTop, definiteEq)
            && covers(self.paddingRight, refinement.paddingRight, definiteEq)
            && covers(self.paddingBottom, refinement.paddingBottom, definiteEq)
            && covers(self.paddingLeft, refinement.paddingLeft, definiteEq)
            && covers(self.borderWidthTop, refinement.borderWidthTop, absoluteEq)
            && covers(self.borderWidthRight, refinement.borderWidthRight, absoluteEq)
            && covers(self.borderWidthBottom, refinement.borderWidthBottom, absoluteEq)
            && covers(self.borderWidthLeft, refinement.borderWidthLeft, absoluteEq)
            && covers(self.gapWidth, refinement.gapWidth, definiteEq)
            && covers(self.gapHeight, refinement.gapHeight, definiteEq)
            && covers(self.flexBasis, refinement.flexBasis, lengthEq)
            && covers(self.background, refinement.background, backgroundEq)
            && covers(self.borderColor, refinement.borderColor, hslaEq)
            && covers(self.cornerRadiusTopLeft, refinement.cornerRadiusTopLeft, absoluteEq)
            && covers(self.cornerRadiusTopRight, refinement.cornerRadiusTopRight, absoluteEq)
            && covers(self.cornerRadiusBottomRight, refinement.cornerRadiusBottomRight, absoluteEq)
            && covers(self.cornerRadiusBottomLeft, refinement.cornerRadiusBottomLeft, absoluteEq)
            && covers(self.boxShadow, refinement.boxShadow, shadowsEq)
            && textIsSupersetOf(self.text, refinement.text)
            && covers(self.gridCols, refinement.gridCols, gridTemplateEq)
            && covers(self.gridRows, refinement.gridRows, gridTemplateEq)
            && covers(self.gridLocation, refinement.gridLocation, gridLocationEq);
    }

    /**
     * Returns a refinement that represents the difference between `self` and `refinement`.
     */
    public static function subtract(self:StyleRefinement, refinement:StyleRefinement):StyleRefinement {
        final result = new StyleRefinement();
        if (self.has(StyleRefinement.DISPLAY) && !fieldEq(self, refinement, StyleRefinement.DISPLAY)) result.display = self.display;
        if (self.has(StyleRefinement.VISIBILITY) && !fieldEq(self, refinement, StyleRefinement.VISIBILITY)) result.visibility = self.visibility;
        if (self.has(StyleRefinement.OVERFLOW_X) && !fieldEq(self, refinement, StyleRefinement.OVERFLOW_X)) result.overflowX = self.overflowX;
        if (self.has(StyleRefinement.OVERFLOW_Y) && !fieldEq(self, refinement, StyleRefinement.OVERFLOW_Y)) result.overflowY = self.overflowY;
        result.scrollbarWidth = minus(self.scrollbarWidth, refinement.scrollbarWidth, absoluteEq);
        if (self.has(StyleRefinement.ALLOW_CONCURRENT_SCROLL) && !fieldEq(self, refinement, StyleRefinement.ALLOW_CONCURRENT_SCROLL)) result.allowConcurrentScroll = self.allowConcurrentScroll;
        if (self.has(StyleRefinement.RESTRICT_SCROLL_TO_AXIS) && !fieldEq(self, refinement, StyleRefinement.RESTRICT_SCROLL_TO_AXIS)) result.restrictScrollToAxis = self.restrictScrollToAxis;
        if (self.has(StyleRefinement.POSITION) && !fieldEq(self, refinement, StyleRefinement.POSITION)) result.position = self.position;
        result.insetTop = minus(self.insetTop, refinement.insetTop, lengthEq);
        result.insetRight = minus(self.insetRight, refinement.insetRight, lengthEq);
        result.insetBottom = minus(self.insetBottom, refinement.insetBottom, lengthEq);
        result.insetLeft = minus(self.insetLeft, refinement.insetLeft, lengthEq);
        result.sizeWidth = minus(self.sizeWidth, refinement.sizeWidth, lengthEq);
        result.sizeHeight = minus(self.sizeHeight, refinement.sizeHeight, lengthEq);
        result.minSizeWidth = minus(self.minSizeWidth, refinement.minSizeWidth, lengthEq);
        result.minSizeHeight = minus(self.minSizeHeight, refinement.minSizeHeight, lengthEq);
        result.maxSizeWidth = minus(self.maxSizeWidth, refinement.maxSizeWidth, lengthEq);
        result.maxSizeHeight = minus(self.maxSizeHeight, refinement.maxSizeHeight, lengthEq);
        if (self.has(StyleRefinement.ASPECT_RATIO) && !fieldEq(self, refinement, StyleRefinement.ASPECT_RATIO)) result.aspectRatio = self.aspectRatio;
        result.marginTop = minus(self.marginTop, refinement.marginTop, lengthEq);
        result.marginRight = minus(self.marginRight, refinement.marginRight, lengthEq);
        result.marginBottom = minus(self.marginBottom, refinement.marginBottom, lengthEq);
        result.marginLeft = minus(self.marginLeft, refinement.marginLeft, lengthEq);
        result.paddingTop = minus(self.paddingTop, refinement.paddingTop, definiteEq);
        result.paddingRight = minus(self.paddingRight, refinement.paddingRight, definiteEq);
        result.paddingBottom = minus(self.paddingBottom, refinement.paddingBottom, definiteEq);
        result.paddingLeft = minus(self.paddingLeft, refinement.paddingLeft, definiteEq);
        result.borderWidthTop = minus(self.borderWidthTop, refinement.borderWidthTop, absoluteEq);
        result.borderWidthRight = minus(self.borderWidthRight, refinement.borderWidthRight, absoluteEq);
        result.borderWidthBottom = minus(self.borderWidthBottom, refinement.borderWidthBottom, absoluteEq);
        result.borderWidthLeft = minus(self.borderWidthLeft, refinement.borderWidthLeft, absoluteEq);
        if (self.has(StyleRefinement.ALIGN_ITEMS) && !fieldEq(self, refinement, StyleRefinement.ALIGN_ITEMS)) result.alignItems = self.alignItems;
        if (self.has(StyleRefinement.ALIGN_SELF) && !fieldEq(self, refinement, StyleRefinement.ALIGN_SELF)) result.alignSelf = self.alignSelf;
        if (self.has(StyleRefinement.ALIGN_CONTENT) && !fieldEq(self, refinement, StyleRefinement.ALIGN_CONTENT)) result.alignContent = self.alignContent;
        if (self.has(StyleRefinement.JUSTIFY_CONTENT) && !fieldEq(self, refinement, StyleRefinement.JUSTIFY_CONTENT)) result.justifyContent = self.justifyContent;
        result.gapWidth = minus(self.gapWidth, refinement.gapWidth, definiteEq);
        result.gapHeight = minus(self.gapHeight, refinement.gapHeight, definiteEq);
        if (self.has(StyleRefinement.FLEX_DIRECTION) && !fieldEq(self, refinement, StyleRefinement.FLEX_DIRECTION)) result.flexDirection = self.flexDirection;
        if (self.has(StyleRefinement.FLEX_WRAP) && !fieldEq(self, refinement, StyleRefinement.FLEX_WRAP)) result.flexWrap = self.flexWrap;
        result.flexBasis = minus(self.flexBasis, refinement.flexBasis, lengthEq);
        if (self.has(StyleRefinement.FLEX_GROW) && !fieldEq(self, refinement, StyleRefinement.FLEX_GROW)) result.flexGrow = self.flexGrow;
        if (self.has(StyleRefinement.FLEX_SHRINK) && !fieldEq(self, refinement, StyleRefinement.FLEX_SHRINK)) result.flexShrink = self.flexShrink;
        result.background = minus(self.background, refinement.background, backgroundEq);
        result.borderColor = minus(self.borderColor, refinement.borderColor, hslaEq);
        if (self.has(StyleRefinement.BORDER_STYLE) && !fieldEq(self, refinement, StyleRefinement.BORDER_STYLE)) result.borderStyle = self.borderStyle;
        result.cornerRadiusTopLeft = minus(self.cornerRadiusTopLeft, refinement.cornerRadiusTopLeft, absoluteEq);
        result.cornerRadiusTopRight = minus(self.cornerRadiusTopRight, refinement.cornerRadiusTopRight, absoluteEq);
        result.cornerRadiusBottomRight = minus(self.cornerRadiusBottomRight, refinement.cornerRadiusBottomRight, absoluteEq);
        result.cornerRadiusBottomLeft = minus(self.cornerRadiusBottomLeft, refinement.cornerRadiusBottomLeft, absoluteEq);
        result.boxShadow = minus(self.boxShadow, refinement.boxShadow, shadowsEq);
        final text = textSubtract(self.text, refinement.text);
        result.text = text.isSome() ? text : null;
        if (self.has(StyleRefinement.MOUSE_CURSOR) && !fieldEq(self, refinement, StyleRefinement.MOUSE_CURSOR)) result.mouseCursor = self.mouseCursor;
        if (self.has(StyleRefinement.OPACITY) && !fieldEq(self, refinement, StyleRefinement.OPACITY)) result.opacity = self.opacity;
        result.gridCols = minus(self.gridCols, refinement.gridCols, gridTemplateEq);
        result.gridRows = minus(self.gridRows, refinement.gridRows, gridTemplateEq);
        result.gridLocation = minus(self.gridLocation, refinement.gridLocation, gridLocationEq);
        return result;
    }

    static final TEXT_BITS = [
        TextStyleRefinement.FONT_WEIGHT, TextStyleRefinement.FONT_STYLE, TextStyleRefinement.WHITE_SPACE,
        TextStyleRefinement.TEXT_ALIGN, TextStyleRefinement.LINE_CLAMP
    ];

    static function textFieldEq(a:TextStyleRefinement, b:TextStyleRefinement, bit:Int):Bool {
        if (a.has(bit) != b.has(bit)) return false;
        if (!a.has(bit)) return true;
        return switch bit {
            case TextStyleRefinement.FONT_WEIGHT: a.fontWeight == b.fontWeight;
            case TextStyleRefinement.FONT_STYLE: a.fontStyle == b.fontStyle;
            case TextStyleRefinement.WHITE_SPACE: a.whiteSpace == b.whiteSpace;
            case TextStyleRefinement.TEXT_ALIGN: a.textAlign == b.textAlign;
            case TextStyleRefinement.LINE_CLAMP: a.lineClamp == b.lineClamp;
            case _: true;
        }
    }

    static function stringEq(a:String, b:String):Bool return a == b;

    static function featuresEq(a:FontFeatures, b:FontFeatures):Bool return a.equals(b);

    static function fallbacksEq(a:FontFallbacks, b:FontFallbacks):Bool return a.equals(b);

    static function underlineEq(a:UnderlineStyle, b:UnderlineStyle):Bool return a.equals(b);

    static function strikethroughEq(a:StrikethroughStyle, b:StrikethroughStyle):Bool return a.equals(b);

    static function overflowEq(a:TextOverflow, b:TextOverflow):Bool return Type.enumEq(a, b);

    /** `TextStyleRefinement::is_superset_of` (`null` is the empty refinement) */
    public static function textIsSupersetOf(self:Null<TextStyleRefinement>, refinement:Null<TextStyleRefinement>):Bool {
        if (refinement == null) return true;
        final a = self != null ? self : new TextStyleRefinement();
        for (bit in TEXT_BITS) {
            if (refinement.has(bit) && !textFieldEq(a, refinement, bit)) return false;
        }
        return covers(a.color, refinement.color, hslaEq)
            && covers(a.fontFamily, refinement.fontFamily, stringEq)
            && covers(a.fontFeatures, refinement.fontFeatures, featuresEq)
            && covers(a.fontFallbacks, refinement.fontFallbacks, fallbacksEq)
            && covers(a.fontSize, refinement.fontSize, absoluteEq)
            && covers(a.lineHeight, refinement.lineHeight, definiteEq)
            && covers(a.backgroundColor, refinement.backgroundColor, hslaEq)
            && covers(a.underline, refinement.underline, underlineEq)
            && covers(a.strikethrough, refinement.strikethrough, strikethroughEq)
            && covers(a.textOverflow, refinement.textOverflow, overflowEq);
    }

    /** `TextStyleRefinement::subtract` (`null` is the empty refinement) */
    public static function textSubtract(self:Null<TextStyleRefinement>, refinement:Null<TextStyleRefinement>):TextStyleRefinement {
        final a = self != null ? self : new TextStyleRefinement();
        final b = refinement != null ? refinement : new TextStyleRefinement();
        final result = new TextStyleRefinement();
        result.color = minus(a.color, b.color, hslaEq);
        result.fontFamily = minus(a.fontFamily, b.fontFamily, stringEq);
        result.fontFeatures = minus(a.fontFeatures, b.fontFeatures, featuresEq);
        result.fontFallbacks = minus(a.fontFallbacks, b.fontFallbacks, fallbacksEq);
        result.fontSize = minus(a.fontSize, b.fontSize, absoluteEq);
        result.lineHeight = minus(a.lineHeight, b.lineHeight, definiteEq);
        if (a.has(TextStyleRefinement.FONT_WEIGHT) && !textFieldEq(a, b, TextStyleRefinement.FONT_WEIGHT)) result.fontWeight = a.fontWeight;
        if (a.has(TextStyleRefinement.FONT_STYLE) && !textFieldEq(a, b, TextStyleRefinement.FONT_STYLE)) result.fontStyle = a.fontStyle;
        result.backgroundColor = minus(a.backgroundColor, b.backgroundColor, hslaEq);
        result.underline = minus(a.underline, b.underline, underlineEq);
        result.strikethrough = minus(a.strikethrough, b.strikethrough, strikethroughEq);
        if (a.has(TextStyleRefinement.WHITE_SPACE) && !textFieldEq(a, b, TextStyleRefinement.WHITE_SPACE)) result.whiteSpace = a.whiteSpace;
        result.textOverflow = minus(a.textOverflow, b.textOverflow, overflowEq);
        if (a.has(TextStyleRefinement.TEXT_ALIGN) && !textFieldEq(a, b, TextStyleRefinement.TEXT_ALIGN)) result.textAlign = a.textAlign;
        if (a.has(TextStyleRefinement.LINE_CLAMP) && !textFieldEq(a, b, TextStyleRefinement.LINE_CLAMP)) result.lineClamp = a.lineClamp;
        return result;
    }

    /**
     * Rust `PartialEq` of `StyleRefinement` in a release build (without
     * the debug fields).
     */
    public static function equalsIgnoringDebug(a:StyleRefinement, b:StyleRefinement):Bool {
        return isSupersetOf(a, b) && isSupersetOf(b, a);
    }

}
