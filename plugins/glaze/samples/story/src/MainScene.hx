// Ported from gpui-kit 0.8.1: crates/story/src/main.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package;

import ceramic.Platform;
import ceramic.Scene;
import gpui.App;
import gpui.Window;
import gpui.component.Component;
import gpui.component.IconName;
import story.Gallery;
import story.Lib;

/**
 * The gpui-kit story gallery (Rust `cargo run -- <story_name>`): start on a
 * story with `GPUI_STORY=<name>`.
 */
class MainScene extends Scene {

    var window:Window;

    override function create() {

        final cx = App.current;
        final name = Platform.getEnv('GPUI_STORY');

        // On the web, the browser also draws the CJK text of the stories
        // (gpui-pre-web's `CanvasFontFallback::EmojiAndCjk`; GPUI's default
        // only draws emoji). No effect on native targets.
        final platform:gpui.platform.CeramicTextSystem = cast cx.textSystem().platformTextSystem;
        platform.canvasFontFallback = gpui.platform.CanvasFontFallback.EmojiAndCjk;

        // The icons are loaded before the first frame (needed on the web)
        final paths = [for (icon in IconName.ALL) icon.path()];
        // The full-catalog icons of the stories (samples/story/assets/icons):
        // ToolbarStory's save icon and the reference icons of InputTokens
        paths.push(story.stories.ToolbarStory.SAVE_ICON_PATH);
        for (path in ['icons/image.svg', 'icons/sparkles.svg', 'icons/at-sign.svg']) paths.push(path);
        App.defaultAssetSource().preload(paths, _ -> {
            cx.update(cx -> Lib.init(cx));
            window = Lib.createNewWindow('GPUI Component', (window, cx) -> Gallery.view(name != '' ? name : null, window, cx), cx, width, height);
            add(window.renderable);
        });

    }

    override function resize(width:Float, height:Float) {

        if (window != null) window.resize(width, height);

    }

    override function destroy() {

        if (window != null) {
            window.destroy();
            window = null;
        }
        super.destroy();

    }

}
