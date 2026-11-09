// Ported from vscode src/vs/nls.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape;

import cityscape.base.common.JsValues;

/**
 * The translations of a `Cityscape` context (Monaco's `nls`): the editor's
 * texts go through `localize(key, defaultMessage, ?args)`, which looks the
 * text up in the table of the context, by key first, then by its English
 * text (the shape of loreline-monaco's tables), and falls back to the
 * English text.
 *
 * Monaco reads its texts when its modules load; Cityscape reads them when
 * the editor actions of a context are registered (the first editor of the
 * context) or when a widget is created: load the table before creating the
 * editors.
 *
 * ```haxe
 * Cityscape.defaultContext.nls.loadJson(Assets.text('editor-fr.json'));
 * ```
 */
class Nls {

    final _table:Map<String, String> = new Map();

    public function new() {}

    /**
     * Localizes a message: `{0}`, `{1}`... in the message are replaced by
     * the arguments.
     */
    public function localize(key:String, defaultMessage:String, ?args:Array<Any>):String {
        var message = _table.get(key);
        if (message == null) {
            message = _table.get(defaultMessage);
        }
        if (message == null) {
            message = defaultMessage;
        }
        return format(message, args != null ? args : []);
    }

    /**
     * Whether the table has a translation for `key` or for `defaultMessage`.
     */
    public function has(key:String, ?defaultMessage:String):Bool {
        return _table.exists(key) || (defaultMessage != null && _table.exists(defaultMessage));
    }

    /**
     * Adds the entries of `table` (key or English text to translated text)
     * to the translations, replacing existing entries.
     */
    public function loadTable(table:Map<String, String>):Void {
        for (key => value in table) {
            _table.set(key, value);
        }
    }

    /**
     * Adds the entries of a JSON object of strings (`{"Find": "Rechercher"}`):
     * the shape of loreline-monaco's tables. Entries whose value is not a
     * string are ignored.
     */
    public function loadJson(json:String):Void {
        final parsed:Dynamic = haxe.Json.parse(json);
        if (parsed == null || !JsValues.isObject(parsed)) {
            throw 'NLS table: a JSON object of strings is expected';
        }
        for (key in Reflect.fields(parsed)) {
            final value:Any = Reflect.field(parsed, key);
            if (JsValues.isString(value)) {
                _table.set(key, value);
            }
        }
    }

    /**
     * Removes every translation (the editor's texts are English again).
     */
    public function clear():Void {
        _table.clear();
    }

    /**
     * nls.ts `_format`: replaces `{n}` with the argument `n` (only the first
     * digit is read, like Monaco); strings as they are, numbers, booleans and
     * null with `String(arg)`, other values leave the placeholder.
     */
    public static function format(message:String, args:Array<Any>):String {
        if (args.length == 0) {
            return message;
        }
        final result = new StringBuf();
        var i = 0;
        final len = message.length;
        while (i < len) {
            final c = StringTools.fastCodeAt(message, i);
            if (c == '{'.code) {
                var j = i + 1;
                while (j < len && StringTools.fastCodeAt(message, j) >= '0'.code && StringTools.fastCodeAt(message, j) <= '9'.code) {
                    j++;
                }
                if (j > i + 1 && j < len && StringTools.fastCodeAt(message, j) == '}'.code) {
                    final index = StringTools.fastCodeAt(message, i + 1) - '0'.code;
                    final match = message.substring(i, j + 1);
                    if (index < args.length) {
                        final arg = args[index];
                        if (JsValues.isString(arg)) {
                            result.add((arg : String));
                        }
                        else if (arg == null || JsValues.isNumber(arg) || JsValues.isBoolean(arg)) {
                            result.add(arg == null ? 'undefined' : JsValues.toJsString(arg));
                        }
                        else {
                            result.add(match);
                        }
                    }
                    else {
                        // `args[index]` is undefined: String(undefined)
                        result.add('undefined');
                    }
                    i = j + 1;
                    continue;
                }
            }
            result.addChar(c);
            i++;
        }
        return result.toString();
    }

}
