package backend;

#if clay_sdl
import clay.sdl.SDL;
#end

import ceramic.Shortcuts.*;

/**
 * Clay backend implementation for system clipboard operations.
 * 
 * This class provides cross-platform clipboard text access with support for:
 * - Native SDL clipboard on desktop platforms
 * - Electron clipboard API when running in Electron
 * - Browser clipboard API as a fallback on web
 * - Internal text storage as a last resort
 * 
 * Platform-specific behavior:
 * - Desktop (SDL): Direct system clipboard access
 * - Electron: Uses Electron's clipboard module with retry logic
 * - Web Browser: Uses navigator.clipboard API with permission handling
 * - Fallback: Internal string storage when system access unavailable
 * 
 * The browser clipboard implementation requires user permission and
 * automatically syncs when the window gains focus.
 * 
 * @see spec.Clipboard The interface this class implements
 */
class Clipboard implements spec.Clipboard {

    /** Internal clipboard text storage used as fallback */
    var clipboardText:String = null;

    #if web
    /** Whether we've already logged a read permission warning */
    var didLogBrowserClipboardReadWarning:Bool = false;
    /** Whether we've already logged a write permission warning */
    var didLogBrowserClipboardWriteWarning:Bool = false;
    /** Whether browser clipboard API has been initialized */
    var didBindBrowserClipboard:Bool = false;
    #end

    /**
     * Creates a new clipboard handler.
     * Automatically detects and initializes the appropriate clipboard API
     * based on the platform and available features.
     */
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

    /**
     * Initializes browser clipboard API access.
     * Sets up automatic clipboard syncing when the window gains focus
     * to detect external clipboard changes.
     */
    public function bindBrowserClipboard() {

        didBindBrowserClipboard = true;

        readBrowserClipboard();

        var window:Dynamic = js.Browser.window;
        window.addEventListener('focus', function() {
            readBrowserClipboard();
        });

    }

    /**
     * Attempts to read text from the browser clipboard.
     * This may fail due to permissions or browser security policies.
     * Failures are logged once to avoid console spam.
     */
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

    /**
     * Attempts to write text to the browser clipboard.
     * This may fail due to permissions or browser security policies.
     * Failures are logged once to avoid console spam.
     * 
     * @param text The text to write to the clipboard
     */
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

    /**
     * Gets the current clipboard text content.
     * 
     * Attempts to read from the system clipboard in this order:
     * 1. Electron clipboard (if available)
     * 2. SDL system clipboard (on desktop)
     * 3. Internal clipboard storage (fallback)
     * 
     * @return The clipboard text content, or null if empty
     */
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

    /**
     * Sets the clipboard text content.
     * 
     * Writes to all available clipboard targets:
     * - Internal storage (always)
     * - Electron clipboard (if available, with retry)
     * - Browser clipboard (if permissions granted)
     * - SDL system clipboard (on desktop)
     * 
     * The Electron implementation includes a 100ms delayed retry
     * to work around timing issues with clipboard access.
     * 
     * @param text The text to copy to the clipboard
     */
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