package backend;

#if clay_sdl
import clay.sdl.SDL;
#end

import ceramic.Shortcuts.*;

class Clipboard implements spec.Clipboard {

    var clipboardText:String = null;

    #if web
    var didLogBrowserClipboardReadWarning:Bool = false;
    var didLogBrowserClipboardWriteWarning:Bool = false;
    var didBindBrowserClipboard:Bool = false;
    #end

    public function new() {

        #if (web && ceramic_use_electron)
        var electron = ceramic.Platform.resolveElectron();
        if (electron == null) {
            #if ceramic_browser_clipboard
            // Electron allowed but not available, fallback to browser
            bindBrowserClipboard();
            #end
        }
        #elseif web
        #if ceramic_browser_clipboard
        bindBrowserClipboard();
        #end
        #end

    }

    #if web

    public function bindBrowserClipboard() {

        didBindBrowserClipboard = true;

        readBrowserClipboard();

        var window:Dynamic = js.Browser.window;
        window.addEventListener('focus', function() {
            readBrowserClipboard();
        });

    }

    function readBrowserClipboard() {

        var navigator:Dynamic = js.Browser.navigator;
        try {
            navigator.clipboard.readText().then(function(text:String) {
                if (clipboardText != text) {
                    #if ceramic_debug_clipboard
                    trace('Clipboard contents changed: $text');
                    #end
                    clipboardText = text;
                }
            });
        }
        catch (e:Dynamic) {
            if (!didLogBrowserClipboardReadWarning) {
                didLogBrowserClipboardReadWarning = true;
                log.warning('Failed to read browser clipboard: $e');
            }
        }

    }

    function writeBrowserClipboard(text:String) {

        var navigator:Dynamic = js.Browser.navigator;
        try {
            navigator.clipboard.writeText(text).then(function() {
                #if ceramic_debug_clipboard
                trace('Did write to clipboard: $text');
                #end
            });
        }
        catch (e:Dynamic) {
            if (!didLogBrowserClipboardWriteWarning) {
                didLogBrowserClipboardWriteWarning = true;
                log.warning('Failed to write browser clipboard: $e');
            }
        }

    }

    #end

    public function getText():String {

        #if (web && ceramic_use_electron)
        var electron = ceramic.Platform.resolveElectron();
        if (electron != null) {
            var text = electron.clipboard.readText();
            return text;
        }
        #elseif clay_sdl
        if (SDL.hasClipboardText()) {
            return SDL.getClipboardText();
        }
        #end

        return clipboardText;

    }

    public function setText(text:String):Void {

        clipboardText = text;

        #if (web && ceramic_use_electron)
        var electron = ceramic.Platform.resolveElectron();
        if (electron != null) {
            electron.clipboard.writeText(text);
            ceramic.Timer.delay(null, 0.1, () -> {
                // Somehow, this is needed to ensure clipboard is
                // not overwritten by some default behavior
                electron.clipboard.writeText(text);
            });
        }
        else if (didBindBrowserClipboard) {
            writeBrowserClipboard(text);
        }
        #elseif web
        if (didBindBrowserClipboard) {
            writeBrowserClipboard(text);
        }
        #elseif clay_sdl
        SDL.setClipboardText(text);
        #end

    }

}