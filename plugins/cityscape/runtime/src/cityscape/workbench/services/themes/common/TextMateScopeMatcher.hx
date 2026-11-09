// Ported from vscode src/vs/workbench/services/themes/common/textMateScopeMatcher.ts
// (not in the sparse reference clone; read from the workbench bundle of VS Code)
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.workbench.services.themes.common;

/**
 * A scope selector matcher giving a score (-1 when it does not match).
 */
typedef ScoreMatcher<T> = (matcherInput:T) -> Int;

typedef ScoreMatcherWithPriority<T> = {
    final matcher:ScoreMatcher<T>;
    /** -1 (`L:`), 0 or 1 (`R:`) */
    final priority:Int;
}

/**
 * The scope selectors of VS Code's themes (the scoring variant of
 * vscode-textmate's matcher): `createMatchers` parses a selector
 * (`source.js keyword - string, (a | b)`) into matchers that score scopes.
 */
class TextMateScopeMatcher {

    public static function createMatchers<T>(selector:String, matchesName:(names:Array<String>, matcherInput:T) -> Int, results:Array<ScoreMatcherWithPriority<T>>):Void {
        new MatcherParser<T>(selector, matchesName).parse(results);
    }

    /**
     * `/[\w\.:]+/` finds a match.
     */
    public static function isIdentifier(token:Null<String>):Bool {
        if (token == null) {
            return false;
        }
        for (i in 0...token.length) {
            if (isIdentifierChar(StringTools.fastCodeAt(token, i))) {
                return true;
            }
        }
        return false;
    }

    static inline function isWordChar(c:Int):Bool {
        return (c >= 'a'.code && c <= 'z'.code) || (c >= 'A'.code && c <= 'Z'.code) || (c >= '0'.code && c <= '9'.code) || c == '_'.code;
    }

    public static inline function isIdentifierChar(c:Int):Bool {
        return isWordChar(c) || c == '.'.code || c == ':'.code;
    }

}

/**
 * The tokenizer (`/([LR]:|[\w\.:][\w\.:\-]*|[\,\|\-\(\)])/g`) and the
 * recursive parser of `createMatchers`.
 */
private class MatcherParser<T> {

    final input:String;
    final matchesName:(names:Array<String>, matcherInput:T) -> Int;
    var pos = 0;
    var token:Null<String> = null;

    public function new(input:String, matchesName:(names:Array<String>, matcherInput:T) -> Int) {
        this.input = input;
        this.matchesName = matchesName;
    }

    function next():Null<String> {
        final len = input.length;
        while (pos < len) {
            final c = StringTools.fastCodeAt(input, pos);
            if ((c == 'L'.code || c == 'R'.code) && pos + 1 < len && StringTools.fastCodeAt(input, pos + 1) == ':'.code) {
                pos += 2;
                return String.fromCharCode(c) + ':';
            }
            if (TextMateScopeMatcher.isIdentifierChar(c)) {
                final start = pos;
                pos++;
                while (pos < len) {
                    final d = StringTools.fastCodeAt(input, pos);
                    if (TextMateScopeMatcher.isIdentifierChar(d) || d == '-'.code) {
                        pos++;
                    }
                    else {
                        break;
                    }
                }
                return input.substring(start, pos);
            }
            if (c == ','.code || c == '|'.code || c == '-'.code || c == '('.code || c == ')'.code) {
                pos++;
                return String.fromCharCode(c);
            }
            pos++;
        }
        return null;
    }

    public function parse(results:Array<ScoreMatcherWithPriority<T>>):Void {
        token = next();
        while (token != null) {
            var priority = 0;
            final t:String = token;
            if (t.length == 2 && t.charAt(1) == ':') {
                switch (t.charAt(0)) {
                    case 'R': priority = 1;
                    case 'L': priority = -1;
                    default:
                }
                token = next();
            }
            final matcher = parseConjunction();
            if (matcher != null) {
                results.push({matcher: matcher, priority: priority});
            }
            if (token != ',') {
                break;
            }
            token = next();
        }
    }

    function parseOperand():Null<ScoreMatcher<T>> {
        if (token == '-') {
            token = next();
            final expressionToNegate = parseOperand();
            if (expressionToNegate == null) {
                return null;
            }
            return matcherInput -> {
                final score = expressionToNegate(matcherInput);
                return score < 0 ? 0 : -1;
            };
        }
        if (token == '(') {
            token = next();
            final expressionInParents = parseInnerExpression();
            if (token == ')') {
                token = next();
            }
            return expressionInParents;
        }
        if (TextMateScopeMatcher.isIdentifier(token)) {
            final identifiers:Array<String> = [];
            do {
                identifiers.push(token);
                token = next();
            } while (TextMateScopeMatcher.isIdentifier(token));
            final matchesName = this.matchesName;
            return matcherInput -> matchesName(identifiers, matcherInput);
        }
        return null;
    }

    function parseConjunction():Null<ScoreMatcher<T>> {
        var matcher = parseOperand();
        if (matcher == null) {
            return null;
        }
        final matchers:Array<ScoreMatcher<T>> = [];
        while (matcher != null) {
            matchers.push(matcher);
            matcher = parseOperand();
        }
        return matcherInput -> { // and
            var min = matchers[0](matcherInput);
            var i = 1;
            while (min >= 0 && i < matchers.length) {
                min = Std.int(Math.min(min, matchers[i](matcherInput)));
                i++;
            }
            return min;
        };
    }

    function parseInnerExpression():Null<ScoreMatcher<T>> {
        var matcher = parseConjunction();
        if (matcher == null) {
            return null;
        }
        final matchers:Array<ScoreMatcher<T>> = [];
        while (matcher != null) {
            matchers.push(matcher);
            if (token == '|' || token == ',') {
                do {
                    token = next();
                } while (token == '|' || token == ','); // ignore subsequent commas
            }
            else {
                break;
            }
            matcher = parseConjunction();
        }
        return matcherInput -> { // or
            var max = matchers[0](matcherInput);
            for (i in 1...matchers.length) {
                max = Std.int(Math.max(max, matchers[i](matcherInput)));
            }
            return max;
        };
    }

}
