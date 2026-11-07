// Ported from gpui-kit 0.8.1: crates/base/src/theme_tokens.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.theme;

/**
 * Semantic design tokens shared by application-owned components.
 *
 * These tokens describe visual roles and scales. They intentionally do not
 * contain component names such as `button`, `table`, or `sidebar`.
 */
class SemanticThemeTokens {

    public var colors:ColorTokens;

    public var radius:RadiusTokens;

    public var spacing:SpacingTokens;

    public var typography:TypographyTokens;

    public var shadow:ShadowTokens;

    /**
     * Without arguments, the default tokens (light palette).
     */
    public function new(?colors:ColorTokens, ?radius:RadiusTokens, ?spacing:SpacingTokens, ?typography:TypographyTokens, ?shadow:ShadowTokens) {

        this.colors = colors != null ? colors : ColorTokens.light();
        this.radius = radius != null ? radius : new RadiusTokens();
        this.spacing = spacing != null ? spacing : new SpacingTokens();
        this.typography = typography != null ? typography : new TypographyTokens();
        this.shadow = shadow != null ? shadow : new ShadowTokens();

    }

    public function copy():SemanticThemeTokens {

        return new SemanticThemeTokens(colors.copy(), radius.copy(), spacing.copy(), typography.copy(), shadow.copy());

    }

    public function equals(other:SemanticThemeTokens):Bool {

        return other != null
            && colors.equals(other.colors)
            && radius.equals(other.radius)
            && spacing.equals(other.spacing)
            && typography.equals(other.typography)
            && shadow.equals(other.shadow);

    }

}
