// Ported from gpui-kit 0.8.1: crates/component/src/theme/theme_color.rs (ThemeToken), crates/component/src/theme/schema.rs (try_parse_theme_token)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.theme;

import gpui.Background;
import gpui.Hsla;

/**
 * A theme token that keeps a solid representative color and its renderable background.
 *
 * Immutable. Rust's `Deref<Target = Hsla>` and `From<ThemeToken>` conversions
 * become the `color` and `background` fields.
 */
class ThemeToken {

    public final color:Hsla;

    public final background:Background;

    /**
     * Without arguments, the default token (transparent black, solid).
     */
    public function new(?color:Hsla, ?background:Background) {

        this.color = color != null ? color : new Hsla();
        this.background = background != null ? background : new Background();

    }

    /**
     * A solid token of the given color (Rust: `From<Hsla> for ThemeToken`).
     */
    public static inline function fromHsla(color:Hsla):ThemeToken {

        return new ThemeToken(color, Background.fromHsla(color));

    }

    /**
     * Parses a theme value (a color or a `linear-gradient(...)`): the color is
     * the color itself or the first stop of the gradient. Returns `null` when
     * invalid (Rust: `try_parse_theme_token`).
     */
    public static function tryParse(value:String):Null<ThemeToken> {

        final color = Color.tryParseThemeColor(value);
        if (color == null) return null;
        final background = Color.tryParseBackground(value);
        if (background == null) return null;
        return new ThemeToken(color, background);

    }

    /**
     * Structural equality (Rust: `PartialEq`).
     */
    public function equals(other:ThemeToken):Bool {

        return other != null && color.equals(other.color) && background.equals(other.background);

    }

    public function toString():String {

        return 'ThemeToken($color, $background)';

    }

}
