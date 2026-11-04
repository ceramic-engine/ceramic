// Ported from gpui-pre 0.3.10: src/platform/test/platform.rs (quit, activate,
// path prompts, menus, dock menu, window appearance and scrollbars of
// `TestPlatform`)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import gpui.Menu.MenuItem;
import gpui.Menu.OwnedMenu;

/**
 * `PlatformOperations` for tests, like GPUI's test platform: nothing reaches
 * the system. Path prompts stay pending until the test answers them
 * (`simulateNewPathSelection`, `simulatePathPromptResponse`); quitting and
 * activations are counted.
 */
class TestPlatformOperations implements PlatformOperations {

    /** How many times `quit` was called. */
    public var quitCount(default, null):Int = 0;

    /** The `ignoringOtherApps` argument of each `activate` call. */
    public final activations:Array<Bool> = [];

    final pathPrompts:Array<{options:PathPromptOptions, task:Task<Null<Array<String>>>}> = [];

    final newPathPrompts:Array<{directory:String, suggestedName:Null<String>, task:Task<Null<String>>}> = [];

    var quitCallback:Null<() -> Null<AnyTask>> = null;

    var menus:Array<OwnedMenu> = [];

    public function new() {}

    /** GPUI's test platform does nothing; the call is counted (the `onQuit` callback is not run). */
    public function quit():Void {
        quitCount++;
    }

    public function onQuit(callback:() -> Null<AnyTask>):Void {
        quitCallback = callback;
    }

    /** Runs the `onQuit` callback, as a platform does when it quits, and returns its task. */
    public function simulateQuit():Null<AnyTask> {
        return quitCallback != null ? quitCallback() : null;
    }

    public function activate(ignoringOtherApps:Bool):Void {
        activations.push(ignoringOtherApps);
    }

    public function promptForPaths(options:PathPromptOptions):Task<Null<Array<String>>> {
        final task = new Task<Null<Array<String>>>();
        pathPrompts.push({options: options, task: task});
        return task;
    }

    public function promptForNewPath(directory:String, suggestedName:Null<String>):Task<Null<String>> {
        final task = new Task<Null<String>>();
        newPathPrompts.push({directory: directory, suggestedName: suggestedName, task: task});
        return task;
    }

    /** Whether a new path prompt waits for an answer (`did_prompt_for_new_path`). */
    public function didPromptForNewPath():Bool {
        return newPathPrompts.length > 0;
    }

    /** Whether a path prompt waits for an answer. */
    public function didPromptForPaths():Bool {
        return pathPrompts.length > 0;
    }

    /**
     * Answers the oldest new path prompt with `selectPath(directory, suggestedName)`
     * (`simulate_new_path_selection`; `null` cancels).
     */
    public function simulateNewPathSelection(selectPath:(directory:String, suggestedName:Null<String>) -> Null<String>):Void {
        final prompt = newPathPrompts.shift();
        if (prompt == null)
            throw 'no pending new path prompt';
        prompt.task.resolve(selectPath(prompt.directory, prompt.suggestedName));
    }

    /**
     * Answers the oldest path prompt with `selectPaths(options)`
     * (`simulate_path_prompt_response`; `null` cancels).
     */
    public function simulatePathPromptResponse(selectPaths:(PathPromptOptions) -> Null<Array<String>>):Void {
        final prompt = pathPrompts.shift();
        if (prompt == null)
            throw 'no pending path prompt';
        prompt.task.resolve(selectPaths(prompt.options));
    }

    public function canSelectMixedFilesAndDirs():Bool {
        return true;
    }

    public function setMenus(menus:Array<Menu>, keymap:Keymap):Void {
        this.menus = [for (menu in menus) menu.owned()];
    }

    public function getMenus():Null<Array<OwnedMenu>> {
        return menus;
    }

    var menuActionCallback:Null<(Action) -> Void> = null;

    var willOpenMenuCallback:Null<() -> Void> = null;

    var validateMenuCommandCallback:Null<(Action) -> Bool> = null;

    /** GPUI's test platform ignores it; kept for `simulateMenuAction`. */
    public function onAppMenuAction(callback:(Action) -> Void):Void {
        menuActionCallback = callback;
    }

    /** GPUI's test platform ignores it; kept for `simulateWillOpenMenu`. */
    public function onWillOpenAppMenu(callback:() -> Void):Void {
        willOpenMenuCallback = callback;
    }

    /** GPUI's test platform ignores it; kept for `simulateValidateMenuCommand`. */
    public function onValidateAppMenuCommand(callback:(Action) -> Bool):Void {
        validateMenuCommandCallback = callback;
    }

    /** Runs the menu action callback, as a platform does when a menu item is chosen. */
    public function simulateMenuAction(action:Action):Void {
        if (menuActionCallback != null)
            menuActionCallback(action);
    }

    /** Runs the will open menu callback, as a platform does when a menu opens. */
    public function simulateWillOpenMenu():Void {
        if (willOpenMenuCallback != null)
            willOpenMenuCallback();
    }

    /** The dock menu items of each `setDockMenu` call (GPUI's test platform ignores them). */
    public final dockMenus:Array<Array<MenuItem>> = [];

    /** The index of each `performDockMenuAction` call (ignored by GPUI's test platform). */
    public final dockMenuActions:Array<Int> = [];

    public function setDockMenu(menu:Array<MenuItem>, keymap:Keymap):Void {
        dockMenus.push(menu);
    }

    public function performDockMenuAction(action:Int):Void {
        dockMenuActions.push(action);
    }

    /** What `windowAppearance` answers: `Light`, like GPUI's test platform, unless a test changes it. */
    public var appearance:WindowAppearance = Light;

    public function windowAppearance():WindowAppearance {
        return appearance;
    }

    /** What `shouldAutoHideScrollbars` answers: false, like GPUI's test platform, unless a test changes it. */
    public var autoHideScrollbars:Bool = false;

    public function shouldAutoHideScrollbars():Bool {
        return autoHideScrollbars;
    }

    /** Runs the validation callback, as a platform does to enable a menu item (false without one). */
    public function simulateValidateMenuCommand(action:Action):Bool {
        return validateMenuCommandCallback != null && validateMenuCommandCallback(action);
    }

}
