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
