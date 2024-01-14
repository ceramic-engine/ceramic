package ceramic;

#if (cpp && (mac || windows || linux))
import dialogs.Dialogs as LincDialogs;
#end

#if (web && ceramic_use_electron)
import ceramic.PlatformSpecific;
#end

import ceramic.Shortcuts.*;

using StringTools;

/**
 * A way to create filesystem dialogs
 */
class Dialogs {

    /**
     * Opens a file picker
     * IMPORTANT: On non-electron web targets, the dialog will only open on click events
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

        var remote = PlatformSpecific.electronRemote();
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

        #elseif web

        final extensions:Array<String> = [
            for (filter in filters) {
                for (extension in filter.extensions) {
                    '.$extension';
                }
            }
        ];

        var input: js.html.InputElement = cast js.Browser.document.createElement("input");
        input.type = "file";
        input.accept = extensions.join(",");

        input.onchange = () -> {
            var reader = new js.html.FileReader();
            reader.readAsText(input.files[0]);
            reader.onloadend = () -> {
                done(reader.result);
            };
        };
        input.click();

        #else

        log.warning('Dialogs not implemented on this platform');
        done(null);

        #end

    }

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

        var remote = PlatformSpecific.electronRemote();
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

        #else

        log.warning('openDirectory is not implemented on this platform');
        done(null);

        #end

    }

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

        var remote = PlatformSpecific.electronRemote();
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

        #else

        log.warning('saveFile is not implemented on this platform');
        done(null);

        #end

    }

}
