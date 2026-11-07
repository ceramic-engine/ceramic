// Ported from gpui-kit 0.8.1: crates/component/src/tag.rs (TagVariant)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.tag;

import glaze.App;
import glaze.Hsla;
import glaze.kit.theme.ColorName;
import glaze.kit.theme.Theme;

/**
 * The color scheme of a `Tag` (default `Secondary`).
 */
@:using(glaze.kit.tag.TagVariant.TagVariantTools)
enum TagVariant {
    Primary;
    Secondary;
    Danger;
    Success;
    Warning;
    Info;
    Color(color:ColorName);
    Custom(color:Hsla, foreground:Hsla, border:Hsla);
}

class TagVariantTools {

    public static function bg(self:TagVariant, cx:App):Hsla {
        final theme = Theme.global(cx);
        return switch self {
            case Primary: theme.primary;
            case Secondary: theme.secondary;
            case Danger: theme.danger;
            case Success: theme.success;
            case Warning: theme.warning;
            case Info: theme.info;
            case Color(color): theme.isDark() ? color.scale(950).opacity(0.5) : color.scale(50);
            case Custom(color, _, _): color;
        }
    }

    public static function border(self:TagVariant, cx:App):Hsla {
        final theme = Theme.global(cx);
        return switch self {
            case Primary: theme.primary;
            case Secondary: theme.border;
            case Danger: theme.danger;
            case Success: theme.success;
            case Warning: theme.warning;
            case Info: theme.info;
            case Color(color): theme.isDark() ? color.scale(800).opacity(0.5) : color.scale(200);
            case Custom(_, _, border): border;
        }
    }

    public static function fg(self:TagVariant, outline:Bool, cx:App):Hsla {
        final theme = Theme.global(cx);
        return switch self {
            case Primary: outline ? theme.primary : theme.primaryForeground;
            case Secondary: outline ? theme.mutedForeground : theme.secondaryForeground;
            case Danger: outline ? theme.danger : theme.dangerForeground;
            case Success: outline ? theme.success : theme.successForeground;
            case Warning: outline ? theme.warning : theme.warningForeground;
            case Info: outline ? theme.info : theme.infoForeground;
            case Color(color): theme.isDark() ? color.scale(300) : color.scale(600);
            case Custom(_, foreground, _): foreground;
        }
    }

}
