package ceramic;

import ceramic.Shortcuts.*;

using StringTools;

/**
 * Utilities for converting JavaScript/TypeScript syntax to HScript.
 * 
 * Provides transpilation of common JS/TS idioms to make scripts more
 * familiar to web developers while maintaining HScript compatibility.
 * 
 * Supported conversions:
 * - Arrow functions: `() => expr` → `function() expr`
 * - Arrow functions: `=> ` → `-> `
 * - For-of loops: `for (x of array)` → `for (x in array)`
 * - Const declarations: `const` → `var`
 * - Template literals: `` `text` `` → `"text"`
 * - Infinite loop protection in while loops
 */
class ScriptUtils {

    /**
     * Converts JavaScript/TypeScript-like code to HScript.
     * 
     * Performs multiple transformation passes:
     * 1. Clean code (arrow functions, comments, template literals)
     * 2. Convert for-of loops to for-in
     * 3. Replace const with var
     * 4. Add infinite loop protection to while loops
     * 
     * @param code Source code with JS/TS syntax
     * @return Equivalent HScript code
     */
    public static function toHscript(code:String):String {

        code = cleanCode(code);

        var i = 0;
        var c = '';
        var cc = '';
        var after = '';
        var len = code.length;
        var inSingleLineComment = false;
        var inMultiLineComment = false;
        var inRegex = false;
        var inRegexEscapeChar = false;
        var result = new StringBuf();
        var word = '';
        var openBraces:Int = 0;
        var openParens:Int = 0;
        var loopIndex:Int = 0;

        /**
         * Updates the current word being processed.
         * Extracts the word at the current position for keyword detection.
         */
        inline function updateWord() {

            var result:String = '';
    
            if (i > 0 && RE_SEP_WORD.match(code.charAt(i-1) + after)) {
                result = RE_SEP_WORD.matched(1);
            }
            else if (i == 0 && RE_WORD.match(after)) {
                result = RE_WORD.matched(0);
            }
            
            word = result;
    
        }

        /**
         * Updates the remaining code string from current position.
         */
        inline function updateAfter() {

            after = code.substring(i);
    
        }

        /**
         * Converts for-of loops to for-in loops.
         * JavaScript: `for (item of array)`
         * HScript: `for (item in array)`
         */
        inline function consumeFor() {

            if (RE_FOR_OF.match(after)) {
                // For (for (var a of B) ...)
                openParens++;
                result.add('for (');
                result.add(RE_FOR_OF.matched(2));
                result.add(' in ');
                i += RE_FOR_OF.matched(0).length;
            }
            else {
                result.add(c);
                i++;
            }

        }

        /**
         * Adds infinite loop protection to while loops.
         * Injects _checkLoop() call to track iterations.
         * 
         * Transform: `while (condition)`
         * To: `while (_checkLoop(index) && (condition))`
         */
        inline function consumeWhile() {

            if (RE_WHILE_START.match(after)) {
                var targetParens = openParens;
                openParens++;
                i += RE_WHILE_START.matched(0).length;
                result.add(RE_WHILE_START.matched(0));
                result.add('_checkLoop($loopIndex) && (');
                loopIndex++;
                while (i < len) {
                    c = code.charAt(i);
                    if (c == '(') {
                        openParens++;
                        result.add('(');
                        i++;
                    }
                    else if (c == ')') {
                        openParens--;
                        if (openParens == targetParens) {
                            result.add('))');
                            i++;
                            break;
                        }
                        else {
                            result.add(')');
                            i++;
                        }
                    }
                    else {
                        result.add(c);
                        i++;
                    }
                }
            }
            else {
                result.add(c);
                i++;
            }

        }

        while (i < len) {

            c = code.charAt(i);
            cc = i + 1 < len ? (c + code.charAt(i + 1)) : c;

            if (c == '{') {
                openBraces++;
                result.add(c);
                i++;
            }
            else if (c == '}') {
                openBraces--;
                result.add(c);
                i++;
            }
            else if (c == '(') {
                openParens++;
                result.add(c);
                i++;
            }
            else if (c == ')') {
                openParens--;
                result.add(c);
                i++;
            }
            else if (c == '"' || c == '\'') {
                after = code.substring(i);
                if (!RE_STRING.match(after)) {
                    fail('Invalid string', i, code);
                }
                result.add(RE_STRING.matched(0));
                i += RE_STRING.matched(0).length;
            }
            else {
                updateAfter();
                updateWord();
                if (word == 'for') {
                    consumeFor();
                }
                else if (word == 'const') {
                    result.add('var');
                    i += word.length;
                }
                else if (word == 'while') {
                    consumeWhile();
                }
                else {
                    result.add(c);
                    i++;
                }
            }
        }

        return result.toString();

    }

    /**
     * First pass: Cleans and converts basic JS/TS syntax.
     * 
     * Handles:
     * - Arrow function conversion
     * - Comment preservation
     * - Template literal conversion
     * - Regex literal handling
     * 
     * @param code Raw JS/TS code
     * @return Cleaned code with basic conversions
     */
    static function cleanCode(code:String) {

        var i = 0;
        var c = '';
        var cc = '';
        var after = '';
        var len = code.length;
        var inSingleLineComment = false;
        var inMultiLineComment = false;
        var inRegex = false;
        var inRegexEscapeChar = false;
        var result = new StringBuf();

        while (i < len) {

            c = code.charAt(i);
            cc = i + 1 < len ? (c + code.charAt(i + 1)) : c;

            if (inSingleLineComment) {
                if (c == "\n") {
                    inSingleLineComment = false;
                    result.add(c);
                }
                else {
                    result.add(' ');
                }
                i++;
            }
            else if (inMultiLineComment) {
                if (cc == '*/') {
                    inMultiLineComment = false;
                    result.add('*/');
                    i += 2;
                } else {
                    result.add(' ');
                    i++;
                }
            }
            else if (inRegex) {
                if (inRegexEscapeChar) {
                    inRegexEscapeChar = false;
                    result.add(c);
                    i++;
                }
                else if (c == '\\') {
                    inRegexEscapeChar = true;
                    result.add(c);
                    i++;
                }
                else if (c == '/') {
                    inRegex = false;
                    result.add('/');
                    i++;
                }
                else {
                    result.add(c);
                    i++;
                }
            }
            else if (cc == '=>') {
                // Convert js/ts arrow functions
                result.add('->');
                i += 2;
            }
            else if (cc == '//') {
                inSingleLineComment = true;
                result.add('//');
                i += 2;
            }
            else if (cc == '/*') {
                inMultiLineComment = true;
                result.add('/*');
                i += 2;
            }
            else if (cc == '~/') {
                inRegex = true;
                result.add('~/');
                i += 2;
            }
            else if (c == '(') {
                after = code.substring(i);
                if (RE_ARROW_FUNC_NO_ARG.match(after)) {
                    result.add('function()');
                    i += RE_ARROW_FUNC_NO_ARG.matched(0).length;
                }
                else {
                    result.add(c);
                    i++;
                }
            }
            /*else if (c == '/') {
                // js/ts regex
                inRegex = true;
                result.add('~/');
                i++;
            }*/
            else if (c == '"' || c == '\'') {
                after = code.substring(i);
                if (!RE_STRING.match(after)) {
                    fail('Invalid string', i, code);
                }
                if (RE_STRING.matched(0).charAt(0) == '`') {
                    // js/ts multiline string
                    result.add(RE_STRING.matched(0).replace('`', '"'));
                }
                else {
                    result.add(RE_STRING.matched(0));
                }
                i += RE_STRING.matched(0).length;
            }
            else {
                result.add(c);
                i++;
            }
        }

        return result.toString();

    }

    /**
     * Throws a parsing error.
     * 
     * @param error Error message
     * @param i Character position where error occurred
     * @param code Full source code
     */
    static function fail(error:Dynamic, i:Int, code:String) {

        throw '' + error;

    }

/// Regular expressions
        
    /** Matches word characters at start of string */
    static var RE_WORD = ~/^[a-zA-Z0-9_]+/;
    
    /** Matches word after non-word character */
    static var RE_SEP_WORD = ~/^[^a-zA-Z0-9_]([a-zA-Z0-9_]+)/;

    /** Matches string literals (single, double, or template) */
    static var RE_STRING = ~/^(?:"(?:[^"\\]*(?:\\.[^"\\]*)*)"|'(?:[^'\\]*(?:\\.[^'\\]*)*)'|`(?:[^`\\]*(?:\\.[^`\\]*)*)`)/;

    /** Matches for-of/for-in loop declarations */
    static var RE_FOR_OF = ~/^for\s*\(\s*(var\s+)?([a-zA-Z0-9_]+)\s*(of|in)\s+/;

    /** Matches while loop start */
    static var RE_WHILE_START = ~/^while\s*\(/;

    /** Matches no-argument arrow function */
    static var RE_ARROW_FUNC_NO_ARG = ~/^\(\s*\)\s*=>/;

}