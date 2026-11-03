// New code for the Haxe port of GPUI: the application operations of GPUI's
// `Platform` (gpui-pre 0.3.10, src/platform.rs, Zed Industries, Apache-2.0)
// implemented with Ceramic. The web behavior follows gpui-pre-web 0.3.10
// src/platform.rs. See NOTICE.md.
package gpui.platform;

import gpui.AnyTask;
import gpui.Keymap;
import gpui.Menu;
import gpui.Menu.OwnedMenu;
import gpui.PathPromptOptions;
import gpui.PlatformOperations;
import gpui.Task;

/**
 * `PlatformOperations` through Ceramic:
 *
 * - `quit` runs the `onQuit` callback (`App.shutdown`), then quits the
 *   Ceramic app (`ceramic.App.quit`) once its task completes. In a browser it only logs a warning,
 *   like GPUI's web platform (a page cannot quit); in Electron it closes
 *   the window.
 * - `activate` activates the app window (`ceramic.Screen.activateWindow`:
 *   SDL's raise window on native targets, which activates the app on macOS;
 *   nothing on the web, like GPUI's web platform, and in headless builds).
 * - The path prompts use the `dialogs` plugin (`ceramic.Dialogs`: SDL's
 *   native file dialogs on desktop, Electron's dialogs). Without the plugin,
 *   and where it has no dialog (browsers, mobile, headless), the prompts
 *   fail like GPUI's web platform ("not supported").
 * - `setMenus` keeps the menus for `getMenus`: Ceramic has no native menu
 *   bar yet, apps draw them in the window (gpui-kit's `AppMenuBar`).
 */
class CeramicPlatformOperations implements PlatformOperations {

    var quitCallback:Null<Void->Null<AnyTask>> = null;

    var menus:Null<Array<OwnedMenu>> = null;

    public function new() {}

    public function quit():Void {
        #if web
        #if ceramic_use_electron
        final canQuit = ceramic.Platform.electronRemote() != null;
        #else
        final canQuit = false;
        #end
        if (!canQuit) {
            ceramic.Shortcuts.log.warning('quit called, but quitting is not supported in the browser');
            return;
        }
        #end
        final shutdown = quitCallback != null ? quitCallback() : null;
        if (shutdown == null)
            ceramic.App.app.quit();
        else
            shutdown.onComplete(() -> ceramic.App.app.quit());
    }

    public function onQuit(callback:Void->Null<AnyTask>):Void {
        quitCallback = callback;
    }

    public function activate(ignoringOtherApps:Bool):Void {
        final app = ceramic.App.app;
        if (app != null && app.screen != null)
            app.screen.activateWindow();
    }

    public function promptForPaths(options:PathPromptOptions):Task<Null<Array<String>>> {
        #if plugin_dialogs
        final task = new Task<Null<Array<String>>>();
        ceramic.Dialogs.choosePaths({
            prompt: options.prompt,
            files: options.files,
            directories: options.directories,
            multiple: options.multiple
        }, (paths, error) -> {
            if (error != null)
                task.reject(error);
            else
                task.resolve(paths);
        });
        return task;
        #else
        return Task.failed('prompt_for_paths needs the Ceramic dialogs plugin');
        #end
    }

    public function promptForNewPath(directory:String, suggestedName:Null<String>):Task<Null<String>> {
        #if plugin_dialogs
        final task = new Task<Null<String>>();
        ceramic.Dialogs.chooseNewPath({
            directory: directory,
            defaultName: suggestedName
        }, (path, error) -> {
            if (error != null)
                task.reject(error);
            else
                task.resolve(path);
        });
        return task;
        #else
        return Task.failed('prompt_for_new_path needs the Ceramic dialogs plugin');
        #end
    }

    public function canSelectMixedFilesAndDirs():Bool {
        #if plugin_dialogs
        return ceramic.Dialogs.canSelectMixedFilesAndDirectories();
        #else
        return false;
        #end
    }

    public function setMenus(menus:Array<Menu>, keymap:Keymap):Void {
        this.menus = [for (menu in menus) menu.owned()];
    }

    public function getMenus():Null<Array<OwnedMenu>> {
        return menus;
    }

}
