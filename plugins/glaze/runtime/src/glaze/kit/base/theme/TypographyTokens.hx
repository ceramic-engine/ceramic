// Ported from gpui-kit 0.8.1: crates/base/src/theme_tokens.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.theme;

import glaze.OperatingSystem;

/**
 * The font families and the text style scale.
 */
class TypographyTokens {

    public var sans:String = '.SystemUIFont';

    public var mono:String = defaultMonoFontFamily();

    public var xs:TextStyleToken = new TextStyleToken(12., 16.);

    public var sm:TextStyleToken = new TextStyleToken(14., 20.);

    public var md:TextStyleToken = new TextStyleToken(16., 24.);

    public var lg:TextStyleToken = new TextStyleToken(18., 28.);

    public var xl:TextStyleToken = new TextStyleToken(20., 28.);

    public var monoMd:TextStyleToken = new TextStyleToken(13., 20.);

    public function new() {}

    /**
     * The platform monospace family: `Menlo` on macOS, `Consolas` on
     * Windows, `DejaVu Sans Mono` elsewhere. Rust decides it at compile time
     * (`cfg!(target_os)`); here it follows `OperatingSystem.current`.
     */
    public static function defaultMonoFontFamily():String {

        return switch OperatingSystem.current {
            case Mac: 'Menlo';
            case Windows: 'Consolas';
            case _: 'DejaVu Sans Mono';
        }

    }

    public function copy():TypographyTokens {

        final t = new TypographyTokens();
        t.sans = sans;
        t.mono = mono;
        t.xs = xs.copy();
        t.sm = sm.copy();
        t.md = md.copy();
        t.lg = lg.copy();
        t.xl = xl.copy();
        t.monoMd = monoMd.copy();
        return t;

    }

    public function equals(other:TypographyTokens):Bool {

        return other != null
            && sans == other.sans
            && mono == other.mono
            && xs.equals(other.xs)
            && sm.equals(other.sm)
            && md.equals(other.md)
            && lg.equals(other.lg)
            && xl.equals(other.xl)
            && monoMd.equals(other.monoMd);

    }

}
