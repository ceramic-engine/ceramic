// Ported from gpui-pre 0.3.10: src/style.rs (the `PartialEq` derived on `StyleRefinement` and
// `TextStyleRefinement` by `#[refineable(PartialEq)]`), as used by gpui-kit 0.8.1
// crates/component/src/command/state.rs and crates/component/src/icon.rs (`same_layout`)
// Original code Copyright 2022-2025 Zed Industries, Inc. and 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.command;

import glaze.StyleRefinement;
import glaze.TextStyleRefinement;
import glaze.kit.Icon;

/**
 * Structural equality of style refinements (Rust `PartialEq`), for the
 * command palette's layout cache: a value type field is equal when both are
 * unset, or both set to the same value.
 */
class StyleRefinementEq {

    public static function equals(a:Null<StyleRefinement>, b:Null<StyleRefinement>):Bool {
        if (a == b) return true;
        if (a == null || b == null) return false;
        if (a.mask != b.mask) return false;
        if (!same(a.scrollbarWidth, b.scrollbarWidth)) return false;
        if (!same(a.insetTop, b.insetTop)) return false;
        if (!same(a.insetRight, b.insetRight)) return false;
        if (!same(a.insetBottom, b.insetBottom)) return false;
        if (!same(a.insetLeft, b.insetLeft)) return false;
        if (!same(a.sizeWidth, b.sizeWidth)) return false;
        if (!same(a.sizeHeight, b.sizeHeight)) return false;
        if (!same(a.minSizeWidth, b.minSizeWidth)) return false;
        if (!same(a.minSizeHeight, b.minSizeHeight)) return false;
        if (!same(a.maxSizeWidth, b.maxSizeWidth)) return false;
        if (!same(a.maxSizeHeight, b.maxSizeHeight)) return false;
        if (!same(a.marginTop, b.marginTop)) return false;
        if (!same(a.marginRight, b.marginRight)) return false;
        if (!same(a.marginBottom, b.marginBottom)) return false;
        if (!same(a.marginLeft, b.marginLeft)) return false;
        if (!same(a.paddingTop, b.paddingTop)) return false;
        if (!same(a.paddingRight, b.paddingRight)) return false;
        if (!same(a.paddingBottom, b.paddingBottom)) return false;
        if (!same(a.paddingLeft, b.paddingLeft)) return false;
        if (!same(a.borderWidthTop, b.borderWidthTop)) return false;
        if (!same(a.borderWidthRight, b.borderWidthRight)) return false;
        if (!same(a.borderWidthBottom, b.borderWidthBottom)) return false;
        if (!same(a.borderWidthLeft, b.borderWidthLeft)) return false;
        if (!same(a.gapWidth, b.gapWidth)) return false;
        if (!same(a.gapHeight, b.gapHeight)) return false;
        if (!same(a.flexBasis, b.flexBasis)) return false;
        if (!same(a.background, b.background)) return false;
        if (!same(a.borderColor, b.borderColor)) return false;
        if (!same(a.cornerRadiusTopLeft, b.cornerRadiusTopLeft)) return false;
        if (!same(a.cornerRadiusTopRight, b.cornerRadiusTopRight)) return false;
        if (!same(a.cornerRadiusBottomRight, b.cornerRadiusBottomRight)) return false;
        if (!same(a.cornerRadiusBottomLeft, b.cornerRadiusBottomLeft)) return false;
        if (!arrayEquals(a.boxShadow, b.boxShadow)) return false;
        if (!textEquals(a.text, b.text)) return false;
        if (!same(a.gridCols, b.gridCols)) return false;
        if (!same(a.gridRows, b.gridRows)) return false;
        if (!same(a.gridLocation, b.gridLocation)) return false;
        if (a.has(StyleRefinement.DISPLAY) && a.display != b.display) return false;
        if (a.has(StyleRefinement.VISIBILITY) && a.visibility != b.visibility) return false;
        if (a.has(StyleRefinement.OVERFLOW_X) && a.overflowX != b.overflowX) return false;
        if (a.has(StyleRefinement.OVERFLOW_Y) && a.overflowY != b.overflowY) return false;
        if (a.has(StyleRefinement.ALLOW_CONCURRENT_SCROLL) && a.allowConcurrentScroll != b.allowConcurrentScroll) return false;
        if (a.has(StyleRefinement.RESTRICT_SCROLL_TO_AXIS) && a.restrictScrollToAxis != b.restrictScrollToAxis) return false;
        if (a.has(StyleRefinement.POSITION) && a.position != b.position) return false;
        if (a.has(StyleRefinement.ASPECT_RATIO) && a.aspectRatio != b.aspectRatio) return false;
        if (a.has(StyleRefinement.ALIGN_ITEMS) && a.alignItems != b.alignItems) return false;
        if (a.has(StyleRefinement.ALIGN_SELF) && a.alignSelf != b.alignSelf) return false;
        if (a.has(StyleRefinement.ALIGN_CONTENT) && a.alignContent != b.alignContent) return false;
        if (a.has(StyleRefinement.JUSTIFY_CONTENT) && a.justifyContent != b.justifyContent) return false;
        if (a.has(StyleRefinement.FLEX_DIRECTION) && a.flexDirection != b.flexDirection) return false;
        if (a.has(StyleRefinement.FLEX_WRAP) && a.flexWrap != b.flexWrap) return false;
        if (a.has(StyleRefinement.FLEX_GROW) && a.flexGrow != b.flexGrow) return false;
        if (a.has(StyleRefinement.FLEX_SHRINK) && a.flexShrink != b.flexShrink) return false;
        if (a.has(StyleRefinement.BORDER_STYLE) && a.borderStyle != b.borderStyle) return false;
        if (a.has(StyleRefinement.MOUSE_CURSOR) && a.mouseCursor != b.mouseCursor) return false;
        if (a.has(StyleRefinement.OPACITY) && a.opacity != b.opacity) return false;
        if (a.has(StyleRefinement.DEBUG) && a.debug != b.debug) return false;
        if (a.has(StyleRefinement.DEBUG_BELOW) && a.debugBelow != b.debugBelow) return false;
        return true;
    }

    public static function textEquals(a:Null<TextStyleRefinement>, b:Null<TextStyleRefinement>):Bool {
        if (a == b) return true;
        if (a == null || b == null) return false;
        if (a.mask != b.mask) return false;
        if (!same(a.color, b.color)) return false;
        if (!same(a.fontFamily, b.fontFamily)) return false;
        if (!same(a.fontFeatures, b.fontFeatures)) return false;
        if (!same(a.fontFallbacks, b.fontFallbacks)) return false;
        if (!same(a.fontSize, b.fontSize)) return false;
        if (!same(a.lineHeight, b.lineHeight)) return false;
        if (!same(a.backgroundColor, b.backgroundColor)) return false;
        if (!same(a.underline, b.underline)) return false;
        if (!same(a.strikethrough, b.strikethrough)) return false;
        if (!same(a.textOverflow, b.textOverflow)) return false;
        if (a.has(TextStyleRefinement.FONT_WEIGHT) && a.fontWeight != b.fontWeight) return false;
        if (a.has(TextStyleRefinement.FONT_STYLE) && a.fontStyle != b.fontStyle) return false;
        if (a.has(TextStyleRefinement.WHITE_SPACE) && a.whiteSpace != b.whiteSpace) return false;
        if (a.has(TextStyleRefinement.TEXT_ALIGN) && a.textAlign != b.textAlign) return false;
        if (a.has(TextStyleRefinement.LINE_CLAMP) && a.lineClamp != b.lineClamp) return false;
        return true;
    }

    /**
     * Rust `Icon::same_layout`: whether `b` takes up exactly the same space
     * as `a`. The source, color and transformation change only what it paints.
     */
    public static function iconSameLayout(a:Icon, b:Icon):Bool {
        return equals(a.style(), b.style()) && same(a.size, b.size);
    }

    static function same(a:Any, b:Any):Bool {
        if (a == b) return true;
        if (a == null || b == null) return false;
        if (Reflect.isEnumValue(a)) return Reflect.isEnumValue(b) && Type.enumEq(a, b);
        return (cast a:{function equals(other:Dynamic):Bool;}).equals(b);
    }

    static function arrayEquals<T>(a:Null<Array<T>>, b:Null<Array<T>>):Bool {
        if (a == b) return true;
        if (a == null || b == null || a.length != b.length) return false;
        for (i in 0...a.length) if (!same(a[i], b[i])) return false;
        return true;
    }

}
