// Ported from gpui-kit 0.8.1: crates/base/src/theme_tokens.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.theme;

import gpui.Hsla;
import gpui.Prelude.hsla;
import gpui.Prelude.rgb;

/**
 * The semantic color roles. Mutable like the Rust struct (it is `Copy` in
 * Rust: use `copy()` before editing a shared value).
 */
class ColorTokens {

    public var background:Hsla;

    public var foreground:Hsla;

    public var surface:Hsla;

    public var surfaceForeground:Hsla;

    public var primary:Hsla;

    public var primaryForeground:Hsla;

    public var secondary:Hsla;

    public var secondaryForeground:Hsla;

    public var muted:Hsla;

    public var mutedForeground:Hsla;

    public var accent:Hsla;

    public var accentForeground:Hsla;

    public var destructive:Hsla;

    public var destructiveForeground:Hsla;

    public var border:Hsla;

    public var input:Hsla;

    public var ring:Hsla;

    /**
     * Background painted behind selected text.
     *
     * Selection quads are painted under the glyphs, so this is a translucent
     * wash that leaves the text legible.
     */
    public var selection:Hsla;

    function new() {}

    /**
     * The default palette: the light one (Rust: `Default`).
     */
    public static function defaultValue():ColorTokens {

        return light();

    }

    /**
     * Default light palette, aligned with gpui-component's Default Light theme.
     */
    public static function light():ColorTokens {

        final c = new ColorTokens();
        c.background = hsla(0., 0., 1., 1.);
        c.foreground = hsla(0., 0., 0.039, 1.);
        c.surface = hsla(0., 0., 1., 1.);
        c.surfaceForeground = hsla(0., 0., 0.039, 1.);
        c.primary = hsla(0., 0., 0.09, 1.);
        c.primaryForeground = hsla(0., 0., 0.98, 1.);
        c.secondary = hsla(0., 0., 0.898, 1.);
        c.secondaryForeground = hsla(0., 0., 0.09, 1.);
        c.muted = hsla(0., 0., 0.961, 1.);
        c.mutedForeground = hsla(0., 0., 0.451, 1.);
        c.accent = hsla(0., 0., 0.961, 1.);
        c.accentForeground = hsla(0., 0., 0.09, 1.);
        c.destructive = hsla(0., 0.842, 0.602, 1.);
        c.destructiveForeground = hsla(0., 0., 0.98, 1.);
        c.border = hsla(0., 0., 0.898, 1.);
        c.input = hsla(0., 0., 0.898, 1.);
        c.ring = hsla(0., 0., 0.639, 1.);
        c.selection = Hsla.fromRgba(rgb(0x55a0fc)).alpha(0.3);
        return c;

    }

    /**
     * Default dark palette, aligned with gpui-component's Default Dark theme.
     */
    public static function dark():ColorTokens {

        final c = new ColorTokens();
        c.background = hsla(0., 0., 0.039, 1.);
        c.foreground = hsla(0., 0., 0.98, 1.);
        c.surface = hsla(0., 0., 0.039, 1.);
        c.surfaceForeground = hsla(0., 0., 0.98, 1.);
        c.primary = hsla(0., 0., 0.98, 1.);
        c.primaryForeground = hsla(0., 0., 0.09, 1.);
        c.secondary = hsla(0., 0., 0.149, 1.);
        c.secondaryForeground = hsla(0., 0., 0.98, 1.);
        c.muted = hsla(0., 0., 0.149, 1.);
        c.mutedForeground = hsla(0., 0., 0.639, 1.);
        c.accent = hsla(0., 0., 0.149, 1.);
        c.accentForeground = hsla(0., 0., 0.98, 1.);
        c.destructive = hsla(0., 0.906, 0.708, 1.);
        c.destructiveForeground = hsla(0., 0.722, 0.506, 1.);
        c.border = hsla(0., 0., 0.149, 1.);
        c.input = hsla(0., 0., 47. / 255., 1.);
        c.ring = hsla(0., 0., 0.451, 1.);
        c.selection = Hsla.fromRgba(rgb(0x1d4ed8)).alpha(0.3);
        return c;

    }

    /**
     * The selection color a palette falls back to when it predates the token.
     */
    public static function defaultSelection():Hsla {

        return light().selection;

    }

    public function copy():ColorTokens {

        final c = new ColorTokens();
        c.background = background;
        c.foreground = foreground;
        c.surface = surface;
        c.surfaceForeground = surfaceForeground;
        c.primary = primary;
        c.primaryForeground = primaryForeground;
        c.secondary = secondary;
        c.secondaryForeground = secondaryForeground;
        c.muted = muted;
        c.mutedForeground = mutedForeground;
        c.accent = accent;
        c.accentForeground = accentForeground;
        c.destructive = destructive;
        c.destructiveForeground = destructiveForeground;
        c.border = border;
        c.input = input;
        c.ring = ring;
        c.selection = selection;
        return c;

    }

    public function equals(other:ColorTokens):Bool {

        return other != null
            && background.equals(other.background)
            && foreground.equals(other.foreground)
            && surface.equals(other.surface)
            && surfaceForeground.equals(other.surfaceForeground)
            && primary.equals(other.primary)
            && primaryForeground.equals(other.primaryForeground)
            && secondary.equals(other.secondary)
            && secondaryForeground.equals(other.secondaryForeground)
            && muted.equals(other.muted)
            && mutedForeground.equals(other.mutedForeground)
            && accent.equals(other.accent)
            && accentForeground.equals(other.accentForeground)
            && destructive.equals(other.destructive)
            && destructiveForeground.equals(other.destructiveForeground)
            && border.equals(other.border)
            && input.equals(other.input)
            && ring.equals(other.ring)
            && selection.equals(other.selection)
        ;

    }

    /**
     * The names of the fields, in declaration order (Rust snake_case names).
     */
    public static final FIELD_NAMES:Array<String> = [
        'background',
        'foreground',
        'surface',
        'surface_foreground',
        'primary',
        'primary_foreground',
        'secondary',
        'secondary_foreground',
        'muted',
        'muted_foreground',
        'accent',
        'accent_foreground',
        'destructive',
        'destructive_foreground',
        'border',
        'input',
        'ring',
        'selection'
    ];

}
