package ceramic;

#if (cpp && (mac || windows || linux))
import dialogs.Dialogs as LincDialogs;
#end

#if (web && ceramic_use_electron)
import ceramic.Platform;
#end

import ceramic.Shortcuts.*;

using StringTools;

/**
 * Cross-platform native file dialog implementation.
 * 
 * This class provides access to native file dialogs for opening files,
 * selecting directories, and saving files. It supports:
 * 
 * - **Desktop platforms** (Mac/Windows/Linux): Uses native OS dialogs via linc_dialogs
 * - **Electron**: Uses Electron's dialog API for web-based desktop apps
 * - **Other platforms**: Falls back to warning logs (no dialog support)
 * 
 * The dialogs are synchronous on desktop but appear asynchronous due to the
 * callback-based API. This ensures consistent behavior across platforms.
 * 
 * File filters can be specified to limit selectable file types, improving
 * user experience by showing only relevant files.
 * 
 * @see DialogsFileFilter For specifying file type filters
 */
class Dialogs {

    /**
     * When set, handles `choosePaths` and `chooseNewPath` instead of the
     * platform (tests, embedders): `save` is true for `chooseNewPath`, and
     * `done` takes the chosen paths (null when cancelled) or an error.
     */
    public static var handler:Null<(save:Bool, options:DialogsOptions, done:(paths:Null<Array<String>>, error:Null<String>)->Void)->Void> = null;

    /**
     * Whether `choosePaths` and `chooseNewPath` can show a dialog on this
     * platform (or a `handler` is set): native desktop targets (SDL file
     * dialogs) and Electron. Browsers, mobile, headless and Unity cannot:
     * the functions report an error there.
     */
    public static function pathDialogsAvailable():Bool {

        if (handler != null) return true;

        #if (clay && cpp && (mac || windows || linux))
        return true;
        #elseif (web && ceramic_use_electron)
        return Platform.electronRemote() != null;
        #else
        return false;
        #end

    }

    /**
     * Whether `choosePaths` can offer files and folders in the same dialog.
     * Native dialogs pick one or the other: when both are requested, folders
     * are picked.
     */
    public static function canSelectMixedFilesAndDirectories():Bool {

        return false;

    }

    /**
     * Asks the user to choose existing files or folders, without blocking.
     *
     * `done` is called later (never during this call) with the chosen paths,
     * with null paths and a null error when the user cancels, or with null
     * paths and an error message when no dialog can be shown here (see
     * `pathDialogsAvailable`).
     *
     * Native desktop targets use SDL's file dialogs (a sheet attached to the
     * window on macOS); Electron uses its own dialogs. Hidden test windows
     * (`clay_sdl_headless`) never show one: they get a cancellation.
     */
    public static function choosePaths(options:DialogsOptions, done:(paths:Null<Array<String>>, error:Null<String>)->Void):Void {

        if (options == null) options = {};
        showPathDialog(false, options, done);

    }

    /**
     * Asks the user for a new file path to save to (a save dialog), without
     * blocking. The dialog starts in `options.directory` with
     * `options.defaultName` proposed, and confirms before an existing file is
     * replaced. Nothing is written: save the data with `Files` once a path is
     * chosen.
     *
     * `done` is called later (never during this call) with the chosen path,
     * with a null path and a null error when the user cancels, or with a null
     * path and an error message when no dialog can be shown here.
     */
    public static function chooseNewPath(options:DialogsOptions, done:(path:Null<String>, error:Null<String>)->Void):Void {

        if (options == null) options = {};
        showPathDialog(true, options, (paths, error) -> {
            done(paths != null && paths.length > 0 ? paths[0] : null, error);
        });

    }

    static function showPathDialog(save:Bool, options:DialogsOptions, done:(paths:Null<Array<String>>, error:Null<String>)->Void):Void {

        var called = false;
        function finish(paths:Null<Array<String>>, error:Null<String>):Void {
            if (called) return;
            called = true;
            if (paths != null && paths.length == 0) paths = null;
            // Always asynchronous, even when the platform answers right away
            app.onceImmediate(() -> done(paths, error));
        }

        if (handler != null) {
            handler(save, options, finish);
            return;
        }

        #if (clay && cpp && (mac || windows || linux))

        final directories = !save && options.directories == true;
        final kind = save ? clay.sdl.SDL.FILE_DIALOG_SAVE_FILE : (directories ? clay.sdl.SDL.FILE_DIALOG_OPEN_FOLDER : clay.sdl.SDL.FILE_DIALOG_OPEN_FILE);
        var location:String = null;
        if (options.directory != null && options.directory.length > 0) {
            #if windows
            final separator = '\\';
            #else
            final separator = '/';
            #end
            location = options.directory;
            if (!location.endsWith('/') && !location.endsWith('\\')) location += separator;
            if (save && options.defaultName != null && options.defaultName.length > 0) location += options.defaultName;
        }
        else if (save && options.defaultName != null && options.defaultName.length > 0) {
            location = options.defaultName;
        }
        var sdlFilters:Array<String> = null;
        if (options.filters != null && !directories) {
            sdlFilters = [];
            for (filter in options.filters) {
                sdlFilters.push(filter.name != null ? filter.name : '');
                sdlFilters.push(filter.extensions != null && filter.extensions.length > 0 ? filter.extensions.join(';') : '*');
            }
        }
        @:privateAccess clay.Clay.app.runtime.showFileDialog(kind, options.title, options.prompt, location, sdlFilters, !save && options.multiple == true, finish);

        #elseif (web && ceramic_use_electron)

        var remote = Platform.electronRemote();
        if (remote == null) {
            finish(null, 'file dialogs are not available in a browser');
            return;
        }
        var dialog:Dynamic = remote.dialog;
        var dialogOptions:Dynamic = {};
        if (options.title != null) dialogOptions.title = options.title;
        if (options.prompt != null) dialogOptions.buttonLabel = options.prompt;
        if (options.filters != null) dialogOptions.filters = options.filters;
        var defaultPath = options.directory;
        if (save && options.defaultName != null) {
            defaultPath = defaultPath != null ? haxe.io.Path.join([defaultPath, options.defaultName]) : options.defaultName;
        }
        if (defaultPath != null) dialogOptions.defaultPath = defaultPath;
        if (save) {
            dialogOptions.properties = ['showOverwriteConfirmation', 'createDirectory'];
            var result:Dynamic = dialog.showSaveDialogSync(dialogOptions);
            ceramic.KeyBindings.forceKeysUp();
            var path:Null<String> = Std.isOfType(result, String) ? result : null;
            finish(path != null && path.trim() != '' ? [path] : null, null);
        }
        else {
            var properties:Array<String> = [options.directories == true ? 'openDirectory' : 'openFile', 'createDirectory'];
            if (options.multiple == true) properties.push('multiSelections');
            dialogOptions.properties = properties;
            var result:Dynamic = dialog.showOpenDialogSync(dialogOptions);
            ceramic.KeyBindings.forceKeysUp();
            var paths:Array<String> = [];
            if (Std.isOfType(result, Array)) {
                var list:Array<Dynamic> = result;
                for (item in list) {
                    if (Std.isOfType(item, String) && (item:String).trim() != '') paths.push(item);
                }
            }
            finish(paths, null);
        }

        #else

        finish(null, 'file dialogs are not available on this platform');

        #end

    }

    /**
     * Opens a native file selection dialog.
     * 
     * Shows the platform's standard file picker dialog, allowing the user
     * to browse and select a single file. The dialog can be configured with
     * file type filters to show only specific file extensions.
     * 
     * On Electron, this also ensures keyboard state is reset after the dialog
     * closes to prevent stuck keys.
     * 
     * @param title The dialog window title
     * @param filters Optional array of file type filters
     * @param done Callback invoked with the selected file path (null if cancelled)
     */
    public static function openFile(title:String, ?filters:Array<DialogsFileFilter>, done:(file:Null<String>)->Void) {

        #if (cpp && (mac || windows || linux))
        var lincFilters = null;
        if (filters != null) {
            lincFilters = [];
            for (filter in filters) {
                for (extension in filter.extensions) {
                    lincFilters.push({
                        desc: filter.name,
                        ext: extension
                    });
                }
            }
        }
        var result:Null<String> = LincDialogs.open(title, lincFilters);
        if (result == null || result.trim() == '') {
            done(null);
        }
        else {
            done(result);
        }

        #elseif (web && ceramic_use_electron)

        var remote = Platform.electronRemote();
        if (remote != null) {
            var dialog:Dynamic = remote.dialog;
            var options:Dynamic = {
                title: title,
                properties: [
                    'promptToCreate',
                    'openFile'
                ]
            };
            if (filters != null) {
                options.filters = filters;
            }
            var result:Dynamic = dialog.showOpenDialogSync(options);
            ceramic.KeyBindings.forceKeysUp();
            if (Std.isOfType(result, Array)) {
                var first:Null<String> = result[0];
                if (first == null || first.trim() == '') {
                    done(null);
                }
                else {
                    done(first);
                }
            }
            else if (Std.isOfType(result, String)) {
                var resultStr:String = result;
                if (resultStr == null || resultStr.trim() == '') {
                    done(null);
                }
                else {
                    done(resultStr);
                }
            }
        }
        else {
            log.warning('Dialogs not implemented on web without electron');
            done(null);
        }

        #else

        log.warning('Dialogs not implemented on this platform');
        done(null);

        #end

    }

    /**
     * Opens a native directory selection dialog.
     * 
     * Shows the platform's standard folder picker dialog, allowing the user
     * to browse and select a directory. On supported platforms, this can
     * also create new directories during selection.
     * 
     * Platform capabilities:
     * - Desktop: Full directory browsing and creation
     * - Electron: Directory selection with create option
     * - Others: Not supported (logs warning)
     * 
     * @param title The dialog window title
     * @param done Callback invoked with the selected directory path (null if cancelled)
     */
    public static function openDirectory(title:String, done:(file:Null<String>)->Void) {

        #if (cpp && (mac || windows || linux))
        var result:Null<String> = LincDialogs.folder(title);
        if (result == null || result.trim() == '') {
            done(null);
        }
        else {
            done(result);
        }

        #elseif (web && ceramic_use_electron)

        var remote = Platform.electronRemote();
        if (remote != null) {
            var dialog:Dynamic = remote.dialog;
            var options:Dynamic = {
                title: title,
                properties: [
                    'createDirectory',
                    'promptToCreate',
                    'openDirectory'
                ]
            };
            var result:Dynamic = dialog.showOpenDialogSync(options);
            ceramic.KeyBindings.forceKeysUp();
            if (result == null) {
                done(null);
            }
            else if (Std.isOfType(result, Array)) {
                var first:Null<String> = result[0];
                if (first == null || first.trim() == '') {
                    done(null);
                }
                else {
                    done(first);
                }
            }
            else if (Std.isOfType(result, String)) {
                var resultStr:String = result;
                if (resultStr == null || resultStr.trim() == '') {
                    done(null);
                }
                else {
                    done(resultStr);
                }
            }
            else {
                done(null);
            }
        }
        else {
            log.warning('Dialogs not implemented on web without electron');
            done(null);
        }

        #else

        log.warning('Dialogs not implemented on this platform');
        done(null);

        #end

    }

    /**
     * Opens a native save file dialog.
     * 
     * Shows the platform's standard save dialog, allowing the user to
     * specify a location and filename for saving. Features include:
     * - Overwrite confirmation for existing files
     * - File type filters to suggest appropriate extensions
     * - Directory creation during navigation
     * 
     * The dialog doesn't actually save any data - it only returns the
     * chosen file path for the application to use.
     * 
     * @param title The dialog window title
     * @param filters Optional array of file type filters (first filter used as default on some platforms)
     * @param done Callback invoked with the chosen file path (null if cancelled)
     */
    public static function saveFile(title:String, ?filters:Array<DialogsFileFilter>, done:(file:Null<String>)->Void) {

        #if (cpp && (mac || windows || linux))
        var lincFilters = null;
        if (filters != null) {
            lincFilters = [];
            for (filter in filters) {
                for (extension in filter.extensions) {
                    lincFilters.push({
                        desc: filter.name,
                        ext: extension
                    });
                }
            }
        }
        var result:Null<String> = LincDialogs.save(title, lincFilters != null ? lincFilters[0] : null);
        if (result != null && result.trim() == '') {
            done(null);
        }
        else {
            done(result);
        }

        #elseif (web && ceramic_use_electron)

        var remote = Platform.electronRemote();
        if (remote != null) {
            var dialog:Dynamic = remote.dialog;
            var options:Dynamic = {
                title: title,
                properties: [
                    'showOverwriteConfirmation'
                ]
            };
            if (filters != null) {
                options.filters = filters;
            }
            var result:Dynamic = dialog.showSaveDialogSync(options);
            ceramic.KeyBindings.forceKeysUp();
            if (Std.isOfType(result, Array)) {
                var first:Null<String> = result[0];
                if (first != null && first.trim() == '') {
                    done(null);
                }
                else {
                    done(first);
                }
            }
            else if (Std.isOfType(result, String)) {
                var resultStr:String = result;
                if (resultStr != null && resultStr.trim() == '') {
                    done(null);
                }
                else {
                    done(resultStr);
                }
            }
        }
        else {
            log.warning('Dialogs not implemented on web without electron');
            done(null);
        }

        #else

        log.warning('Dialogs not implemented on this platform');
        done(null);

        #end

    }

}
