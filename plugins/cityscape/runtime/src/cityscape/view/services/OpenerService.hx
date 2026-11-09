// Ported from vscode src/vs/editor/browser/services/openerService.ts
// (monaco-editor 0.52.2 build: the file is not in the sparse reference clone)
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.view.services;

import cityscape.Cityscape;
import cityscape.base.common.JsValues;
import cityscape.base.common.Uri;
import cityscape.common.core.Range.IRange;
import haxe.extern.EitherType;

/**
 * The options of `OpenerService.open` (Monaco's `OpenOptions`, the fields
 * the editor uses).
 */
typedef OpenOptions = {
    @:optional var openToSide:Bool;
    @:optional var fromUserGesture:Bool;
    @:optional var allowContributedOpeners:Bool;
    /**
     * Whether `command:` links run their command (else they are ignored).
     */
    @:optional var allowCommands:Bool;
    @:optional var fromWorkspace:Bool;
    @:optional var openExternal:Bool;
}

/**
 * Opens links (Monaco's `IOpenerService`), one per `Cityscape` context.
 *
 * The host's `Cityscape.openLink` is asked first (Monaco's contributed
 * openers, `registerOpener`); when it is null or returns false, Monaco's
 * default openers run in their order: `mailto:`, `http:` and `https:`
 * links open with the platform (Ceramic's `backend.openUrl`: the system
 * browser, a new tab on the web, nothing when headless), `command:` links
 * run their command through the command service (when `allowCommands`),
 * other links open in an editor through `CodeEditorService.openCodeEditor`
 * (the host's open handlers), with the selection of their fragment
 * (`#L10,5`).
 */
class OpenerService {

    final context:Cityscape;

    public function new(context:Cityscape) {
        this.context = context;
    }

    /**
     * Opens `target` (a `Uri` or a string), true when an opener handled it.
     * Monaco's promise is synchronous here.
     */
    public function open(target:EitherType<Uri, String>, ?options:OpenOptions):Bool {
        final targetURI:Uri = Std.isOfType(target, std.String) ? Uri.parse((cast target : String)) : (cast target : Uri);

        final hook = context.openLink;
        if (hook != null && hook(targetURI, options != null && options.fromUserGesture == true)) {
            return true;
        }

        // Default opener: any external, mailto, http(s)
        if ((options != null && options.openExternal == true) || matchesSomeScheme(targetURI, ['mailto', 'http', 'https', 'vsls'])) {
            _doOpenExternal(target, targetURI);
            return true;
        }
        if (_openCommand(target, targetURI, options)) {
            return true;
        }
        return _openEditor(targetURI, options);
    }

    static function matchesSomeScheme(uri:Uri, schemes:Array<String>):Bool {
        final scheme = uri.scheme.toLowerCase();
        for (s in schemes) {
            if (scheme == s) {
                return true;
            }
        }
        return false;
    }

    function _doOpenExternal(resource:EitherType<Uri, String>, uri:Uri):Void {
        // open the url-string AS IS, a URI with the toString(noEncode)+encodeURI-trick
        final href = Std.isOfType(resource, std.String) ? (cast resource : String) : encodeURI(uri.toString(true));
        final app = ceramic.App.app;
        if (app != null && app.backend != null) {
            app.backend.openUrl(href);
        }
    }

    /**
     * JavaScript's `encodeURI`.
     */
    static function encodeURI(value:String):String {
        final buf = new StringBuf();
        final reserved = ";,/?:@&=+$-_.!~*'()#";
        final bytes = haxe.io.Bytes.ofString(value);
        for (i in 0...bytes.length) {
            final b = bytes.get(i);
            final isAlnum = (b >= 'a'.code && b <= 'z'.code) || (b >= 'A'.code && b <= 'Z'.code) || (b >= '0'.code && b <= '9'.code);
            if (isAlnum || (b < 128 && reserved.indexOf(String.fromCharCode(b)) >= 0)) {
                buf.addChar(b);
            }
            else {
                buf.add('%' + StringTools.hex(b, 2));
            }
        }
        return buf.toString();
    }

    /**
     * Monaco's `CommandOpener`.
     */
    function _openCommand(target:EitherType<Uri, String>, uri:Uri, options:Null<OpenOptions>):Bool {
        if (uri.scheme.toLowerCase() != 'command') {
            return false;
        }
        if (options == null || options.allowCommands != true) {
            // silently ignore commands when command-links are disabled, also
            // suppress other openers by returning TRUE
            return true;
        }
        // execute as command
        var args:Any = [];
        try {
            args = haxe.Json.parse(StringTools.urlDecode(uri.query));
        }
        catch (e:Dynamic) {
            // ignore and retry
            try {
                args = haxe.Json.parse(uri.query);
            }
            catch (e:Dynamic) {
                // ignore error
            }
        }
        final list:Array<Any> = Std.isOfType(args, Array) ? (cast args : Array<Any>) : [args];
        context.commandService.executeCommand(uri.path, list);
        return true;
    }

    /**
     * Monaco's `EditorOpener`.
     */
    function _openEditor(target:Uri, options:Null<OpenOptions>):Bool {
        final extracted = extractSelection(target);
        context.codeEditorService.openCodeEditor({
            resource: extracted.uri,
            options: {
                selection: extracted.selection
            }
        }, context.codeEditorService.getFocusedCodeEditor(), options != null && options.openToSide == true);
        return true;
    }

    /**
     * Monaco's `extractSelection` (opener.ts): the selection of a fragment
     * `L10,5-L12,3` (the `L` optional), removed from the uri.
     */
    public static function extractSelection(uri:Uri):{selection:Null<IRange>, uri:Uri} {
        var selection:Null<IRange> = null;
        final match = new cityscape.base.common.RegExp('^L?(\\d+)(?:,(\\d+))?(-L?(\\d+)(?:,(\\d+))?)?').exec(uri.fragment);
        if (match != null) {
            final startLineNumber = Std.int(JsValues.parseInt(match[1]));
            final startColumn = match[2] != null ? Std.int(JsValues.parseInt(match[2])) : 1;
            selection = {
                startLineNumber: startLineNumber,
                startColumn: startColumn,
                endLineNumber: match[4] != null ? Std.int(JsValues.parseInt(match[4])) : startLineNumber,
                endColumn: match[4] != null ? (match[5] != null ? Std.int(JsValues.parseInt(match[5])) : 1) : startColumn
            };
            uri = uri.with({fragment: ''});
        }
        return {selection: selection, uri: uri};
    }

}
