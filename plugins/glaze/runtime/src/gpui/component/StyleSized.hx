// Ported from gpui-kit 0.8.1: crates/component/src/sizing.rs (StyleSized)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component;

import gpui.StyleBuilder;
import gpui.Styled;

using gpui.component.Size.SizeTools;

/**
 * Size-driven style helpers on any `Styled` element, as a static extension:
 * `using gpui.component.StyleSized;` then `div().inputTextSize(size)`.
 */
class StyleSized {

    static inline function b<T:Styled>(self:T):StyleBuilder {
        return new StyleBuilder(self.style());
    }

    public static function inputTextSize<T:Styled>(self:T, size:Size):T {
        switch size {
            case XSmall: b(self).textXs();
            case Small: b(self).textSm();
            case Medium: b(self).textSm();
            case Large: b(self).textBase();
            case Size(value): b(self).textSize(gpui.Prelude.px(gpui.SpringMath.f32(value * 0.875)));
        }
        return self;
    }

    public static function inputSize<T:Styled>(self:T, size:Size):T {
        inputPx(self, size);
        inputPy(self, size);
        return inputH(self, size);
    }

    public static function inputPl<T:Styled>(self:T, size:Size):T {
        b(self).pl(size.inputPx());
        return self;
    }

    public static function inputPr<T:Styled>(self:T, size:Size):T {
        b(self).pr(size.inputPx());
        return self;
    }

    public static function inputPx<T:Styled>(self:T, size:Size):T {
        b(self).px(size.inputPx());
        return self;
    }

    public static function inputPy<T:Styled>(self:T, size:Size):T {
        b(self).py(size.inputPy());
        return self;
    }

    public static function inputH<T:Styled>(self:T, size:Size):T {
        switch size {
            case Large: b(self).h11();
            case Medium: b(self).h8();
            case Small: b(self).h6();
            case XSmall: b(self).h5();
            case _: b(self).h6();
        }
        return self;
    }

    public static function listSize<T:Styled>(self:T, size:Size):T {
        listPx(self, size);
        listPy(self, size);
        return inputTextSize(self, size);
    }

    public static function listPx<T:Styled>(self:T, size:Size):T {
        b(self).px(size.listPx());
        return self;
    }

    public static function listPy<T:Styled>(self:T, size:Size):T {
        switch size {
            case Large: b(self).py2();
            case Medium: b(self).py1();
            case Small: b(self).py0p5();
            case _: b(self).py1();
        }
        return self;
    }

    /**
     * Apply size with the given `Size`.
     */
    public static function sizeWith<T:Styled>(self:T, size:Size):T {
        switch size {
            case Large: b(self).size11();
            case Medium: b(self).size8();
            case Small: b(self).size5();
            case XSmall: b(self).size4();
            case Size(value): b(self).size(value);
        }
        return self;
    }

    /**
     * Apply the table cell size (font size, padding) with the given `Size`.
     */
    public static function tableCellSize<T:Styled>(self:T, size:Size):T {
        final padding = size.tableCellPadding();
        switch size {
            case XSmall: b(self).textXs();
            case Small | Medium: b(self).textSm();
            case Large: b(self).textBase();
            case _:
        }
        b(self).pl(gpui.Prelude.px(padding.left)).pr(gpui.Prelude.px(padding.right)).pt(gpui.Prelude.px(padding.top)).pb(gpui.Prelude.px(padding.bottom));
        return self;
    }

    public static function buttonTextSize<T:Styled>(self:T, size:Size):T {
        switch size {
            case XSmall: b(self).textXs();
            case Small | Medium: b(self).textSm();
            case _: b(self).textBase();
        }
        return self;
    }

}
