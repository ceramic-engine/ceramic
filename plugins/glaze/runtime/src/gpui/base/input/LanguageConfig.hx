// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/language_config.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.util.Utf8;

/**
 * Declarative language editing rules, independent of editor preferences and parsers.
 *
 * Mirrors the supported subset of Monaco's language configuration. A null
 * `autoClosingPairs` uses `brackets`; an empty array disables all automatic pairs.
 * Use the builders to configure a default value. Tree-sitter queries are
 * configured in the parser implementation, not in these rules.
 *
 * Without arguments, Rust's `LanguageConfig::default()`.
 */
class LanguageConfig {

    public var brackets:Array<BracketPair>;

    public var autoClosingPairs:Null<Array<AutoClosingPair>>;

    /** Automatic insertion is allowed before these characters, whitespace, or EOF. */
    public var autoCloseBefore:String;

    public var indentationRules:Null<IndentationRules>;

    public function new() {
        brackets = [
            new BracketPair("(", ")"),
            new BracketPair("[", "]"),
            new BracketPair("{", "}"),
        ];
        final pairs = [for (p in brackets) new AutoClosingPair(p.open, p.close).withNotIn([SyntaxContext.String, SyntaxContext.Comment])];
        for (p in [new AutoClosingPair('"', '"'), new AutoClosingPair("'", "'")])
            pairs.push(p.withNotIn([SyntaxContext.String, SyntaxContext.Comment]));
        autoClosingPairs = pairs;
        autoCloseBefore = ";:.,=}])>";
        indentationRules = null;
    }

    public static inline function defaultValue():LanguageConfig {
        return new LanguageConfig();
    }

    /** Rust builder `brackets` */
    public function withBrackets(pairs:Array<BracketPair>):LanguageConfig {
        brackets = pairs.copy();
        return this;
    }

    /** Rust builder `auto_closing_pairs` */
    public function withAutoClosingPairs(pairs:Array<AutoClosingPair>):LanguageConfig {
        autoClosingPairs = pairs.copy();
        return this;
    }

    /** Rust builder `auto_close_before` */
    public function withAutoCloseBefore(characters:String):LanguageConfig {
        autoCloseBefore = characters;
        return this;
    }

    /** Rust builder `indentation_rules` */
    public function withIndentationRules(rules:IndentationRules):LanguageConfig {
        indentationRules = rules;
        return this;
    }

    /**
     * The pairs to close automatically: the configured ones, or the brackets
     * (with no excluded context) when none are configured. Pairs with an empty
     * delimiter are skipped. Rust yields `(open, close, not_in)` tuples.
     */
    public function closingPairs():Array<AutoClosingPair> {
        final result:Array<AutoClosingPair> = [];
        if (autoClosingPairs != null) {
            for (p in autoClosingPairs) {
                if (p.open.length > 0 && p.close.length > 0)
                    result.push(p);
            }
        }
        else {
            for (p in brackets) {
                if (p.open.length > 0 && p.close.length > 0)
                    result.push(new AutoClosingPair(p.open, p.close));
            }
        }
        return result;
    }

    public function opensIndent(text:String):Bool {
        final pattern = indentationRules != null ? indentationRules.increaseIndentPattern : null;
        if (pattern == null) {
            final trimmed = trimEnd(text);
            for (p in brackets) {
                if (p.open.length > 0 && StringTools.endsWith(trimmed, p.open))
                    return true;
            }
            return false;
        }
        return pattern.match(text);
    }

    public function closesIndent(text:String):Bool {
        final pattern = indentationRules != null ? indentationRules.decreaseIndentPattern : null;
        return pattern != null && pattern.match(text);
    }

    /** Rust `str::trim_end` (Unicode `White_Space`, which is all in the BMP) */
    static function trimEnd(text:String):String {
        var end = text.length;
        while (end > 0 && Utf8.isWhitespace(StringTools.fastCodeAt(text, end - 1)))
            end--;
        return text.substr(0, end);
    }

}
