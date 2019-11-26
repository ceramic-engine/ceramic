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

    } //new

    public function getText():String {

        #if (cpp && linc_sdl)
        if (SDL.hasClipboardText()) {
            return SDL.getClipboardText();
        }
        #end

        return clipboardText;

    } //getText

    public function setText(text:String):Void {

        clipboardText = text;

        #if (cpp && linc_sdl)
        SDL.setClipboardText(text);
        #end

    } //setText

} //Clipboard
