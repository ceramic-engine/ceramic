// Ported from vscode src/vs/editor/common/languageSelector.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common;

import cityscape.base.common.JsValues;
import cityscape.base.common.Uri;
import haxe.extern.EitherType;

typedef LanguageFilter = {
    @:optional var language:String;
    @:optional var scheme:String;
    /**
     * A file path (glob patterns and relative patterns are not supported
     * yet: the pattern must be the path itself).
     */
    @:optional var pattern:String;
    @:optional var notebookType:String;
    /**
     * This provider is implemented in the UI thread.
     */
    @:optional var hasAccessToAllModels:Bool;
    @:optional var exclusive:Bool;

    /**
     * This provider comes from a builtin extension.
     */
    @:optional var isBuiltin:Bool;
}

/**
 * A language id (`'*'` for all), a `LanguageFilter`, or an array of them.
 */
typedef LanguageSelector = EitherType<String, EitherType<LanguageFilter, Array<EitherType<String, LanguageFilter>>>>;

/**
 * Module functions of languageSelector.ts.
 */
class LanguageSelectorUtils {

    public static function score(selector:Null<LanguageSelector>, candidateUri:Uri, candidateLanguage:String, candidateIsSynchronized:Bool, candidateNotebookUri:Null<Uri>, candidateNotebookType:Null<String>):Int {

        if (selector == null) {
            return 0;
        }

        if (JsValues.isArray(selector)) {
            // array -> take max individual value
            var ret = 0;
            final filters:Array<EitherType<String, LanguageFilter>> = cast selector;
            for (filter in filters) {
                final value = score(cast filter, candidateUri, candidateLanguage, candidateIsSynchronized, candidateNotebookUri, candidateNotebookType);
                if (value == 10) {
                    return value; // already at the highest
                }
                if (value > ret) {
                    ret = value;
                }
            }
            return ret;

        }
        else if (JsValues.isString(selector)) {

            if (!candidateIsSynchronized) {
                return 0;
            }

            // short-hand notion, desugars to
            // 'fooLang' -> { language: 'fooLang'}
            // '*' -> { language: '*' }
            final s:String = cast selector;
            if (s == '*') {
                return 5;
            }
            else if (s == candidateLanguage) {
                return 10;
            }
            else {
                return 0;
            }

        }
        else {
            // filter -> select accordingly, use defaults for scheme
            final filter:LanguageFilter = cast selector;
            final language:Null<String> = filter.language;
            final pattern:Null<String> = filter.pattern;
            final scheme:Null<String> = filter.scheme;
            final hasAccessToAllModels = filter.hasAccessToAllModels == true;
            final notebookType:Null<String> = filter.notebookType;

            if (!candidateIsSynchronized && !hasAccessToAllModels) {
                return 0;
            }

            // selector targets a notebook -> use the notebook uri instead
            // of the "normal" document uri.
            if (nonEmpty(notebookType) && candidateNotebookUri != null) {
                candidateUri = candidateNotebookUri;
            }

            var ret = 0;

            if (nonEmpty(scheme)) {
                if (scheme == candidateUri.scheme) {
                    ret = 10;
                }
                else if (scheme == '*') {
                    ret = 5;
                }
                else {
                    return 0;
                }
            }

            if (nonEmpty(language)) {
                if (language == candidateLanguage) {
                    ret = 10;
                }
                else if (language == '*') {
                    ret = Std.int(Math.max(ret, 5));
                }
                else {
                    return 0;
                }
            }

            if (nonEmpty(notebookType)) {
                if (notebookType == candidateNotebookType) {
                    ret = 10;
                }
                else if (notebookType == '*' && candidateNotebookType != null) {
                    ret = Std.int(Math.max(ret, 5));
                }
                else {
                    return 0;
                }
            }

            if (nonEmpty(pattern)) {
                // TODO: glob patterns (vs/base/common/glob) are not ported:
                // only a pattern equal to the path matches
                if (pattern == candidateUri.fsPath) {
                    ret = 10;
                }
                else {
                    return 0;
                }
            }

            return ret;
        }
    }

    public static function targetsNotebooks(selector:LanguageSelector):Bool {
        if (JsValues.isString(selector)) {
            return false;
        }
        else if (JsValues.isArray(selector)) {
            final filters:Array<EitherType<String, LanguageFilter>> = cast selector;
            for (f in filters) {
                if (targetsNotebooks(cast f)) {
                    return true;
                }
            }
            return false;
        }
        else {
            return nonEmpty((cast selector : LanguageFilter).notebookType);
        }
    }

    static inline function nonEmpty(s:Null<String>):Bool {
        return s != null && s.length > 0;
    }

}
