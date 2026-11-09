// Ported from vscode src/vs/editor/common/languages/supports/indentRules.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.languages.supports;

import cityscape.base.common.RegExp;
import cityscape.common.languages.LanguageConfiguration.IndentationRule;

enum abstract IndentConsts(Int) from Int to Int {
    var INCREASE_MASK = 0x01;
    var DECREASE_MASK = 0x02;
    var INDENT_NEXTLINE_MASK = 0x04;
    var UNINDENT_MASK = 0x08;
}

class IndentRulesSupport {

    final _indentationRules:IndentationRule;

    public function new(indentationRules:IndentationRule) {
        _indentationRules = indentationRules;
    }

    static inline function resetGlobalRegex(reg:RegExp):Bool {
        if (reg.global) {
            reg.lastIndex = 0;
        }

        return true;
    }

    public function shouldIncrease(text:String):Bool {
        if (_indentationRules != null) {
            final pattern = _indentationRules.increaseIndentPattern;
            if (pattern != null && resetGlobalRegex(pattern) && pattern.test(text)) {
                return true;
            }
            // if (this._indentationRules.indentNextLinePattern && this._indentationRules.indentNextLinePattern.test(text)) {
            // 	return true;
            // }
        }
        return false;
    }

    public function shouldDecrease(text:String):Bool {
        if (_indentationRules != null) {
            final pattern = _indentationRules.decreaseIndentPattern;
            if (pattern != null && resetGlobalRegex(pattern) && pattern.test(text)) {
                return true;
            }
        }
        return false;
    }

    public function shouldIndentNextLine(text:String):Bool {
        if (_indentationRules != null) {
            final pattern = _indentationRules.indentNextLinePattern;
            if (pattern != null && resetGlobalRegex(pattern) && pattern.test(text)) {
                return true;
            }
        }
        return false;
    }

    public function shouldIgnore(text:String):Bool {
        // the text matches `unIndentedLinePattern`
        if (_indentationRules != null) {
            final pattern = _indentationRules.unIndentedLinePattern;
            if (pattern != null && resetGlobalRegex(pattern) && pattern.test(text)) {
                return true;
            }
        }
        return false;
    }

    public function getIndentMetadata(text:String):Int {
        var ret = 0;
        if (shouldIncrease(text)) {
            ret += IndentConsts.INCREASE_MASK;
        }
        if (shouldDecrease(text)) {
            ret += IndentConsts.DECREASE_MASK;
        }
        if (shouldIndentNextLine(text)) {
            ret += IndentConsts.INDENT_NEXTLINE_MASK;
        }
        if (shouldIgnore(text)) {
            ret += IndentConsts.UNINDENT_MASK;
        }
        return ret;
    }

}
