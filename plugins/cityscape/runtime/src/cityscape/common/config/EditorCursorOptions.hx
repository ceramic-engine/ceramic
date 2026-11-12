// Ported from vscode src/vs/editor/common/config/editorOptions.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.config;

import cityscape.base.common.JsValues;
import cityscape.common.config.EditorOptions;
import cityscape.common.config.EditorOptions.AnyEditorOption;

/*
 * The editor options the cursor and its commands read, ported with the
 * cursor (step 3): autoClosingComments, columnSelection,
 * copyWithSyntaxHighlighting, cursorSurroundingLinesStyle,
 * multiCursorMergeOverlapping, multiCursorPaste, multiCursorLimit,
 * stickyTabStops, tabCompletion, useTabStops, wordSegmenterLocales.
 *
 * They are registered by `EditorOptions.init()` through `registerSimple()`
 * below (the registry is indexed by id: the order does not matter).
 */

/**
 * `wordSegmenterLocales`: a locale or a list of locales.
 *
 * Monaco keeps the locales `Intl.Segmenter.supportedLocalesOf` accepts. On
 * JavaScript the same check is made; other targets have no `Intl` and keep
 * the well formed BCP 47 tags (letters, digits and hyphens, starting with a
 * language subtag of 2 to 8 letters), see DEVIATIONS.md.
 */
class WordSegmenterLocales extends BaseEditorOption<Array<String>> {

    public function new() {
        super(EditorOption.wordSegmenterLocales, 'wordSegmenterLocales', []);
    }

    public function validate(input:Any):Array<String> {
        if (JsValues.isString(input)) {
            input = [input];
        }
        if (JsValues.isArray(input)) {
            final validLocales:Array<String> = [];
            for (locale in (input : Array<Any>)) {
                if (JsValues.isString(locale)) {
                    if (isSupportedLocale(locale)) {
                        validLocales.push(locale);
                    }
                }
            }
            return validLocales;
        }

        return this.defaultValue;
    }

    static function isSupportedLocale(locale:String):Bool {
        #if js
        try {
            return js.Syntax.code('Intl.Segmenter.supportedLocalesOf({0}).length > 0', locale);
        }
        catch (e:Dynamic) {
            // ignore invalid locales
            return false;
        }
        #else
        final parts = locale.split('-');
        final language = parts[0];
        if (language.length < 2 || language.length > 8) {
            return false;
        }
        for (i in 0...language.length) {
            final c = StringTools.fastCodeAt(language, i);
            if (!((c >= 'a'.code && c <= 'z'.code) || (c >= 'A'.code && c <= 'Z'.code))) {
                return false;
            }
        }
        for (p in 1...parts.length) {
            final part = parts[p];
            if (part.length < 1 || part.length > 8) {
                return false;
            }
            for (i in 0...part.length) {
                final c = StringTools.fastCodeAt(part, i);
                if (!((c >= 'a'.code && c <= 'z'.code) || (c >= 'A'.code && c <= 'Z'.code) || (c >= '0'.code && c <= '9'.code))) {
                    return false;
                }
            }
        }
        return true;
        #end
    }

}

class EditorCursorOptions {

    /**
     * Registers the cursor options (called by `EditorOptions.init()`).
     */
    public static function registerSimple(register:(option:AnyEditorOption) -> Void):Void {
        register(cast new EditorStringEnumOption(EditorOption.autoClosingComments, 'autoClosingComments', 'languageDefined', ['always', 'languageDefined', 'beforeWhitespace', 'never']));
        register(cast new EditorBooleanOption(EditorOption.columnSelection, 'columnSelection', false));
        register(cast new EditorBooleanOption(EditorOption.copyWithSyntaxHighlighting, 'copyWithSyntaxHighlighting', true));
        register(cast new EditorStringEnumOption(EditorOption.cursorSurroundingLinesStyle, 'cursorSurroundingLinesStyle', 'default', ['default', 'all']));
        register(cast new EditorBooleanOption(EditorOption.multiCursorMergeOverlapping, 'multiCursorMergeOverlapping', true));
        register(cast new EditorStringEnumOption(EditorOption.multiCursorPaste, 'multiCursorPaste', 'spread', ['spread', 'full']));
        register(cast new EditorIntOption(EditorOption.multiCursorLimit, 'multiCursorLimit', 10000, 1, 100000));
        register(cast new EditorBooleanOption(EditorOption.stickyTabStops, 'stickyTabStops', false));
        register(cast new EditorStringEnumOption(EditorOption.tabCompletion, 'tabCompletion', 'off', ['on', 'off', 'onlySnippets']));
        register(cast new EditorBooleanOption(EditorOption.useTabStops, 'useTabStops', true));
        register(cast new WordSegmenterLocales());
    }

}
