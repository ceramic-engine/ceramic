// Ported from gpui-kit 0.8.1: crates/story/src/lib.rs (AppState)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story;

import gpui.App;
import gpui.AppContext;
import gpui.Entity;
import gpui.Window.StateModel;

/**
 * The global state of the story gallery.
 */
class AppState {

    public var invisiblePanels:Entity<StateModel<Array<String>>>;

    /**
     * Whether the window root renders the performance HUD. Toggled from the
     * title bar's settings menu, read by `StoryRoot`. The port has no FPS
     * monitor (gpui-fps is out of scope), so it only keeps the setting.
     */
    public var showFpsMonitor:Bool;

    /**
     * Whether the title bar draws the in-window `AppMenuBar` instead of the
     * window title. Toggled from the title bar's settings menu, read by
     * `AppTitleBar`.
     */
    public var showAppMenuBar:Bool;

    public var previewingTheme:Bool;

    function new() {}

    public static function init(cx:AppContext):Void {
        final state = new AppState();
        state.invisiblePanels = cx.newEntity(_ -> new StateModel<Array<String>>([]));
        state.showFpsMonitor = false;
        // macOS draws the app menus in the system menu bar, so an in-window
        // menu bar would be a second copy of them. Off by default there,
        // but still switchable so the component stays demoable on a Mac.
        // Unity has no system menu bar (Ceramic's `setMenuBar` is a no-op
        // there): the in-window one is the only way to the menus.
        state.showAppMenuBar = #if unity true #else !Lib.isMacos() #end;
        state.previewingTheme = false;
        cx.setGlobal(state);
    }

    public static function global(cx:AppContext):AppState {
        return cx.global(AppState);
    }

    public static function globalMut(cx:AppContext):AppState {
        return cx.globalMut(AppState);
    }

}
