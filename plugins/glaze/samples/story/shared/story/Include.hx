// Part of the port of gpui-kit 0.8.1: crates/story (the `include_str!` calls of the stories)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/**
 * Rust `include_str!` for the story gallery: the content of a file of
 * `samples/story/shared/story/fixtures` (copies of gpui-kit's
 * `crates/story/src/fixtures` and of its README), inlined at compile time.
 */
class Include {

    macro public static function str(name:String):ExprOf<String> {
        final dir = haxe.io.Path.directory(sys.FileSystem.absolutePath(Context.resolvePath('story/Include.hx')));
        final path = haxe.io.Path.join([dir, 'fixtures', name]);
        if (!sys.FileSystem.exists(path)) {
            Context.error('Missing fixture: $path', Context.currentPos());
        }
        Context.registerModuleDependency(Context.getLocalModule(), path);
        return macro $v{sys.io.File.getContent(path)};
    }


    /**
     * Rust `include_bytes!("../../../assets/assets/icons/<name>")`: an icon
     * of the plugin's `assets/icons` (the same files as gpui-kit's assets
     * crate), as bytes.
     */
    macro public static function iconBytes(name:String):ExprOf<haxe.io.Bytes> {
        final dir = haxe.io.Path.directory(sys.FileSystem.absolutePath(Context.resolvePath('story/Include.hx')));
        final path = haxe.io.Path.join([dir, '..', '..', '..', '..', 'assets', 'icons', name]);
        if (!sys.FileSystem.exists(path)) {
            Context.error('Missing icon: $path', Context.currentPos());
        }
        Context.registerModuleDependency(Context.getLocalModule(), path);
        final content = sys.io.File.getContent(path);
        return macro haxe.io.Bytes.ofString($v{content});
    }

}
