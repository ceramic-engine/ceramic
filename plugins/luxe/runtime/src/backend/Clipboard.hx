package backend;

#if (cpp && linc_sdl)
import sdl.SDL;
#end

import ceramic.Shortcuts.*;

class Clipboard implements spec.Clipboard {

    var clipboardText:String = null;

    public function new() {

        /*
        // Maybe later we will use modern js clipboard API?
        #if web
        var window:Dynamic = js.Browser.window;
        var navigator:Dynamic = js.Browser.navigator;
        window.addEventListener('clipboardchange', function() {
            trace('Clipboard contents changed');
            try {
                navigator.clipboard.readText().then(function(text:String) {
                    trace('Clipboard content: ' + text);
                    clipboardText = text;
                });
            }
            catch (e:Dynamic) {
                log.warning('Failed to handle clipboard change: $e');
            }
        });
        #end
        */

    }

    public function getText():String {

        #if (web && ceramic_use_electron)
        var electron = ceramic.internal.PlatformSpecific.resolveElectron();
        if (electron != null) {
            var text = electron.clipboard.readText();
            return text;
        }
        #elseif (cpp && linc_sdl)
        if (SDL.hasClipboardText()) {
            return SDL.getClipboardText();
        }
        #end

        return clipboardText;

    }

    public function setText(text:String):Void {

        clipboardText = text;

        #if (web && ceramic_use_electron)
        var electron = ceramic.internal.PlatformSpecific.resolveElectron();
        if (electron != null) {
            electron.clipboard.writeText(text);
            ceramic.Timer.delay(null, 0.1, () -> {
                // Somehow, this is needed to ensure clipboard is
                // not overwritten by some default behavior
                electron.clipboard.writeText(text);
            });
        }
        #elseif (cpp && linc_sdl)
        SDL.setClipboardText(text);
        #end

    }

}
