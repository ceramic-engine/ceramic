// Ported from vscode src/vs/editor/common/languages/supports/onEnter.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.languages.supports;

import cityscape.base.common.Errors;
import cityscape.base.common.RegExp;
import cityscape.base.common.Strings;
import cityscape.common.config.EditorOptions.EditorAutoIndentStrategy;
import cityscape.common.languages.LanguageConfiguration;

typedef IOnEnterSupportOptions = {
    @:optional var brackets:Array<CharacterPair>;
    @:optional var onEnterRules:Array<OnEnterRule>;
}

private typedef IProcessedBracketPair = {
    final open:String;
    final close:String;
    final openRegExp:RegExp;
    final closeRegExp:RegExp;
}

class OnEnterSupport {

    final _brackets:Array<IProcessedBracketPair>;
    final _regExpRules:Array<OnEnterRule>;

    /**
     * Like Monaco, sets `opts.brackets` to the default brackets when it is
     * not set (the options object is the language configuration).
     */
    public function new(opts:Null<IOnEnterSupportOptions>) {
        if (opts == null) {
            opts = {};
        }
        if (opts.brackets == null) {
            opts.brackets = [
                ['(', ')'],
                ['{', '}'],
                ['[', ']']
            ];
        }

        _brackets = [];
        for (bracket in opts.brackets) {
            final openRegExp = OnEnterSupport._createOpenBracketRegExp(bracket[0]);
            final closeRegExp = OnEnterSupport._createCloseBracketRegExp(bracket[1]);
            if (openRegExp != null && closeRegExp != null) {
                _brackets.push({
                    open: bracket[0],
                    openRegExp: openRegExp,
                    close: bracket[1],
                    closeRegExp: closeRegExp,
                });
            }
        }
        _regExpRules = opts.onEnterRules != null ? opts.onEnterRules : [];
    }

    static inline function _testRule(reg:Null<RegExp>, text:String):Bool {
        if (reg == null) {
            return true;
        }
        reg.lastIndex = 0; // To disable the effect of the "g" flag.
        return reg.test(text);
    }

    public function onEnter(autoIndent:EditorAutoIndentStrategy, previousLineText:String, beforeEnterText:String, afterEnterText:String):Null<EnterAction> {
        // (1): `regExpRules`
        if ((autoIndent:Int) >= (EditorAutoIndentStrategy.Advanced:Int)) {
            for (i in 0..._regExpRules.length) {
                final rule = _regExpRules[i];
                final regResult = (
                    _testRule(rule.beforeText, beforeEnterText)
                    && _testRule(rule.afterText, afterEnterText)
                    && _testRule(rule.previousLineText, previousLineText)
                );

                if (regResult) {
                    return rule.action;
                }
            }
        }

        // (2): Special indent-outdent
        if ((autoIndent:Int) >= (EditorAutoIndentStrategy.Brackets:Int)) {
            if (beforeEnterText.length > 0 && afterEnterText.length > 0) {
                for (i in 0..._brackets.length) {
                    final bracket = _brackets[i];
                    if (bracket.openRegExp.test(beforeEnterText) && bracket.closeRegExp.test(afterEnterText)) {
                        return {indentAction: IndentAction.IndentOutdent};
                    }
                }
            }
        }

        // (4): Open bracket based logic
        if ((autoIndent:Int) >= (EditorAutoIndentStrategy.Brackets:Int)) {
            if (beforeEnterText.length > 0) {
                for (i in 0..._brackets.length) {
                    final bracket = _brackets[i];
                    if (bracket.openRegExp.test(beforeEnterText)) {
                        return {indentAction: IndentAction.Indent};
                    }
                }
            }
        }

        return null;
    }

    /**
     * `/\B/.test(c)` on a string of at most one character.
     */
    static function _isNotWordBoundary(c:String):Bool {
        if (c.length == 0) {
            return true;
        }
        return !RegExp.isAsciiWordChar(StringTools.fastCodeAt(c, 0));
    }

    static function _createOpenBracketRegExp(bracket:String):Null<RegExp> {
        var str = Strings.escapeRegExpCharacters(bracket);
        if (!_isNotWordBoundary(str.charAt(0))) {
            str = '\\b' + str;
        }
        str += '\\s*$';
        return OnEnterSupport._safeRegExp(str);
    }

    static function _createCloseBracketRegExp(bracket:String):Null<RegExp> {
        var str = Strings.escapeRegExpCharacters(bracket);
        if (!_isNotWordBoundary(str.charAt(str.length - 1))) {
            str = str + '\\b';
        }
        str = '^\\s*' + str;
        return OnEnterSupport._safeRegExp(str);
    }

    static function _safeRegExp(def:String):Null<RegExp> {
        try {
            return new RegExp(def);
        }
        catch (err:Dynamic) {
            Errors.onUnexpectedError(err);
            return null;
        }
    }

}
