// Ported from gpui-kit 0.8.1: crates/story/src/embedded_themes.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/**
 * The themes of gpui-kit's `themes` folder (copied into
 * `samples/story/shared/story/themes`), inlined at compile time. Rust only
 * embeds them on the web; the port has no theme folder watcher, so it uses
 * them on every target.
 */
class EmbeddedThemes {

    public static function embeddedThemes():Map<String, String> {
        final themes = new Map<String, String>();

        themes.set('adventure', theme('adventure'));
        themes.set('alduin', theme('alduin'));
        themes.set('asciinema', theme('asciinema'));
        themes.set('aurora', theme('aurora'));
        themes.set('ayu', theme('ayu'));
        themes.set('catppuccin', theme('catppuccin'));
        themes.set('everforest', theme('everforest'));
        themes.set('fahrenheit', theme('fahrenheit'));
        themes.set('flexoki', theme('flexoki'));
        themes.set('gruvbox', theme('gruvbox'));
        themes.set('harper', theme('harper'));
        themes.set('hybrid', theme('hybrid'));
        themes.set('jellybeans', theme('jellybeans'));
        themes.set('kibble', theme('kibble'));
        themes.set('macos-classic', theme('macos-classic'));
        themes.set('mellifluous', theme('mellifluous'));
        themes.set('molokai', theme('molokai'));
        themes.set('solarized', theme('solarized'));
        themes.set('spaceduck', theme('spaceduck'));
        themes.set('tokyonight', theme('tokyonight'));
        themes.set('twilight', theme('twilight'));

        return themes;
    }

    macro static function theme(name:String):ExprOf<String> {
        final dir = haxe.io.Path.directory(sys.FileSystem.absolutePath(Context.resolvePath('story/EmbeddedThemes.hx')));
        final path = haxe.io.Path.join([dir, 'themes', name + '.json']);
        Context.registerModuleDependency(Context.getLocalModule(), path);
        return macro $v{sys.io.File.getContent(path)};
    }

}
