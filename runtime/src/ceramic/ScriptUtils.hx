package ceramic;

import ceramic.Shortcuts.*;

using StringTools;

class ScriptUtils {

    /**
     * Converts the given `inScript` to hscript.
     * This will take care of transforming a few idioms borrowed from js/ts to hscript equivalent.
     * @param inScript 
     * @return String
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

        inline function updateAfter() {

            after = code.substring(i);
    
        }

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
                else {
                    result.add(c);
                    i++;
                }
            }
        }

        return result.toString();

    }

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

    static function fail(error:Dynamic, i:Int, code:String) {

        throw '' + error;

    }

/// Regular expressions
        
    static var RE_WORD = ~/^[a-zA-Z0-9_]+/;
    
    static var RE_SEP_WORD = ~/^[^a-zA-Z0-9_]([a-zA-Z0-9_]+)/;

    static var RE_STRING = ~/^(?:"(?:[^"\\]*(?:\\.[^"\\]*)*)"|'(?:[^'\\]*(?:\\.[^'\\]*)*)'|`(?:[^`\\]*(?:\\.[^`\\]*)*)`)/;

    static var RE_FOR_OF = ~/^for\s*\(\s*(var\s+)?([a-zA-Z0-9_]+)\s*(of|in)\s+/;

}