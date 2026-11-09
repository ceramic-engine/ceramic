// Ported from vscode src/vs/base/common/path.ts (the posix `basename` and
// `dirname`, node's path module)
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common;

/**
 * The parts of path.ts that Cityscape uses, with posix semantics (the
 * paths of models are posix paths on every target; Monaco on Windows uses
 * the win32 functions for file paths).
 */
class Path {

    static inline final CHAR_FORWARD_SLASH = 47; /* / */

    /**
     * `posix.basename(path)` (without the suffix argument).
     */
    public static function basename(path:String):String {
        var start = 0;
        var end = -1;
        var matchedSlash = true;
        var i = path.length - 1;
        while (i >= 0) {
            if (StringTools.fastCodeAt(path, i) == CHAR_FORWARD_SLASH) {
                // If we reached a path separator that was not part of a set of path
                // separators at the end of the string, stop now
                if (!matchedSlash) {
                    start = i + 1;
                    break;
                }
            }
            else if (end == -1) {
                // We saw the first non-path separator, mark this as the end of our
                // path component
                matchedSlash = false;
                end = i + 1;
            }
            i--;
        }
        if (end == -1) {
            return '';
        }
        return path.substring(start, end);
    }

    /**
     * `posix.dirname(path)`.
     */
    public static function dirname(path:String):String {
        if (path.length == 0) {
            return '.';
        }
        final hasRoot = StringTools.fastCodeAt(path, 0) == CHAR_FORWARD_SLASH;
        var end = -1;
        var matchedSlash = true;
        var i = path.length - 1;
        while (i >= 1) {
            if (StringTools.fastCodeAt(path, i) == CHAR_FORWARD_SLASH) {
                if (!matchedSlash) {
                    end = i;
                    break;
                }
            }
            else {
                // We saw the first non-path separator
                matchedSlash = false;
            }
            i--;
        }

        if (end == -1) {
            return hasRoot ? '/' : '.';
        }
        if (hasRoot && end == 1) {
            return '//';
        }
        return path.substring(0, end);
    }

}
