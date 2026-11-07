// Ported from gpui-kit 0.8.1: crates/story/src/main.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package;

import ceramic.Platform;
import ceramic.Scene;
import glaze.App;
import glaze.Window;
import glaze.kit.Component;
import glaze.kit.IconName;
import story.Gallery;
import story.Lib;

/**
 * The gpui-kit story gallery (Rust `cargo run -- <story_name>`): start on a
 * story with `GLAZE_STORY=<name>`.
 */
class MainScene extends Scene {

    var window:Window;

    /** The key of the gallery settings in Ceramic's app storage (`backend.io`). */
    static inline final STATE_KEY = 'story-state.json';

    override function create() {

        final cx = App.current;
        final name = Platform.getEnv('GLAZE_STORY');

        // On the web, the browser also draws the CJK text of the stories
        // (gpui-pre-web's `CanvasFontFallback::EmojiAndCjk`; GPUI's default
        // only draws emoji). No effect on native targets.
        final platform:glaze.platform.CeramicTextSystem = cast cx.textSystem().platformTextSystem;
        platform.canvasFontFallback = glaze.platform.CanvasFontFallback.EmojiAndCjk;

        // The icons are loaded before the first frame (needed on the web)
        final paths = [for (icon in IconName.ALL) icon.path()];
        // The full-catalog icons of the stories (samples/story/assets/icons):
        // ToolbarStory's save icon and the reference icons of InputTokens
        paths.push(story.stories.ToolbarStory.SAVE_ICON_PATH);
        for (path in ['icons/image.svg', 'icons/sparkles.svg', 'icons/at-sign.svg']) paths.push(path);
        // Rust keeps the settings of the gallery in `target/state.json` on
        // native targets (not on the web): here in Ceramic's app storage
        #if !web
        final io = ceramic.App.app.backend.io;
        story.Themes.stateStorage = {
            read: () -> io.readString(STATE_KEY),
            write: json -> {
                io.saveString(STATE_KEY, json);
            }
        };
        #end

        App.defaultAssetSource().preload(paths, _ -> {
            cx.update(cx -> {
                Lib.init(cx);
                // Required for system notifications on Windows; macOS only
                // shows them when running from the signed app bundle
                cx.setAppIdentity('com.longbridge.gpui-component.story', 'GPUI Component');
            });
            var gallery:Null<glaze.Entity<Gallery>> = null;
            window = Lib.createNewWindow('GPUI Component', (window, cx) -> {
                final view = Gallery.view(name != null && name != '' ? name : null, window, cx);
                gallery = view;
                return view;
            }, cx, width, height);
            add(window.renderable);
            // Automated tour of every page (GLAZE_STORY_TOUR, see StoryTour)
            StoryTour.startIfRequested(gallery, window);
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
