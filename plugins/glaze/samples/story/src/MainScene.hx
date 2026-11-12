// Ported from gpui-kit 0.8.1: crates/story/src/main.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package;

import ceramic.Platform;
import ceramic.Scene;
import glaze.Glaze;
import glaze.Window;
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

        final cx = Glaze.app;
        final name = Platform.getEnv('GLAZE_STORY');

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

        // The icons need no loading: the kit's icons and the full-catalog
        // icons of the stories (samples/story/resources/glaze/icons: ToolbarStory's save
        // icon and the reference icons of InputTokens) are embedded in the
        // code (`IconName`)
        cx.update(cx -> {
            Lib.init(cx);
            // Required for system notifications on Windows; macOS only
            // shows them when running from the signed app bundle
            cx.setAppIdentity('com.longbridge.gpui-component.story', 'GPUI Component');
        });
        // The pages specific to the Haxe port are listed by the app
        Gallery.portStories = true;
        var gallery:Null<glaze.Entity<Gallery>> = null;
        window = Lib.createNewWindow('GPUI Component', (window, cx) -> {
            final view = Gallery.view(name != null && name != '' ? name : null, window, cx);
            gallery = view;
            return view;
        }, cx, width, height);
        add(window.renderable);
        // Automated tour of every page (GLAZE_STORY_TOUR, see StoryTour)
        StoryTour.startIfRequested(gallery, window);

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
