package tools;

import haxe.io.Path;

using StringTools;

class Glob {

    inline public static function toEReg(globPattern:String, regexOptions:String = ""):EReg {
        return new EReg(toRegEx(globPattern), regexOptions);
    }

    // Extracted from haxe-files: https://github.com/vegardit/haxe-files/blob/660ee7c76d80e12cb0d6fa81f67c348e073fa3c8/src/hx/files/GlobPatterns.hx#L76-L190
    // (Apache License), and edited to work without dependencies
    /**
     * Creates a regular expression pattern from the given globbing/wildcard pattern.
     *
     * ```
     * Glob.toRegEx("file")          == "^file$"
     * Glob.toRegEx("*.txt")         == "^[^\\\\^\\/]*\\.txt$"
     * Glob.toRegEx("*file*")        == "^[^\\\\^\\/]*file[^\\\\^\\/]*$"
     * Glob.toRegEx("file?.txt")     == "^file[^\\\\^\\/]\\.txt$"
     * Glob.toRegEx("file[A-Z]")     == "^file[A-Z]$"
     * Glob.toRegEx("file[!A-Z]")    == "^file[^A-Z]$"
     * Glob.toRegEx("")              == ""
     * Glob.toRegEx(null)            == null
     * ```
     *
     * @param globPattern Pattern in the Glob syntax style, see https://docs.oracle.com/javase/tutorial/essential/io/fileOps.html#glob
     *
     * @return regular expression string
     */
    public static function toRegEx(globPattern:String):String {

        if (globPattern == null || globPattern.trim().length == 0)
            return globPattern;

        final sb = new StringBuf();
        sb.addChar('^'.code);
        final charsLenMinus1 = globPattern.length - 1;
        var chPrev:Int = -1;
        var groupDepth = 0;
        var idx = -1;
        while (idx < charsLenMinus1) {
            idx++;
            var ch = globPattern.charCodeAt(idx);

            switch ch {
                case '\\'.code:
                    if (chPrev == '\\'.code)
                        sb.add("\\\\"); // "\\" => "\\"
                case '/'.code:
                    // "/" => "[\/\\]"
                    sb.add("[\\/\\\\]");
                case '$'.code:
                    // "$" => "\$"
                    sb.add("\\$");
                case '?'.code:
                    if (chPrev == '\\'.code)
                        sb.add("\\?"); // "\?" => "\?"
                    else
                        sb.add("[^\\\\^\\/]"); // "?" => "[^\\^\/]"
                case '.'.code:
                    // "." => "\."
                    sb.add("\\.");
                case '('.code:
                    // "(" => "\("
                    sb.add("\\(");
                case ')'.code:
                    // ")" => "\)"
                    sb.add("\\)");
                case '{'.code:
                    if (chPrev == '\\'.code)
                        sb.add("\\{"); // "\{" => "\{"
                    else {
                        groupDepth++;
                        sb.addChar('('.code);
                    }
                case '}'.code:
                    if (chPrev == '\\'.code)
                        sb.add("\\}"); // "\}" => "\}"
                    else {
                        groupDepth--;
                        sb.addChar(')'.code);
                    }
                case ','.code:
                    if (chPrev == '\\'.code)
                        sb.add("\\,"); // "\," => "\,"
                    else {
                        // "," => "|" if in group or => "," if not in group
                        sb.addChar(groupDepth > 0 ? '|'.code : ','.code);
                    }
                case '!'.code:
                    if (chPrev == '['.code)
                        sb.addChar('^'.code); // "[!" => "[^"
                    else
                        sb.addChar(ch);
                case '*'.code:
                    if (globPattern.charCodeAt(idx + 1) == '*'.code) { // **
                        if (globPattern.charCodeAt(idx + 2) == '/'.code) { // **/
                            if (globPattern.charCodeAt(idx + 3) == '*'.code) {
                                // "**/*" => ".*"
                                sb.add(".*");
                                idx += 3;
                            } else {
                                // "**/" => "(.*[\/\\])?"
                                sb.add("(.*[\\/\\\\])?");
                                idx += 2;
                                ch = '/'.code;
                            }
                        } else {
                            sb.add(".*"); // "**" => ".*"
                            idx++;
                        }
                    } else {
                        sb.add("[^\\\\^\\/]*"); // "*" => "[^\\^\/]*"
                    }
                default:
                    if (chPrev == '\\'.code) {
                        sb.addChar('\\'.code);
                    }
                    sb.addChar(ch);
            }

            chPrev = ch;
        }
        sb.addChar('$'.code);

        return sb.toString();

    }

    public static function find(pattern:String):Array<String> {

        pattern = Path.normalize(pattern);

        final regex = toEReg(pattern);

        var tokenIndex:Int = Std.int(Math.min(
            pattern.indexOf('*'),
            Math.min(
                pattern.indexOf('['),
                pattern.indexOf('?')
            )
        ));

        if (tokenIndex == -1) {
            return [pattern];
        }

        var slashIndex:Int = pattern.substring(0, tokenIndex).lastIndexOf('/');
        if (slashIndex == -1) {
            throw 'Invalid glob pattern: $pattern';
        }

        var basePath = pattern.substring(0, slashIndex);

        var result = [];
        for (pathItem in Files.getFlatDirectory(basePath)) {
            var path = Path.join([basePath, pathItem]);
            if (regex.match(path)) {
                result.push(path);
            }
        }

        return result;

    }

}