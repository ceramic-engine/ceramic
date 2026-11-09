// Ported from vscode src/vs/base/common/search.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common;

/**
 * Module functions of search.ts: the case preserving replace string of the
 * find widget ("Preserve Case").
 */
class Search {

    public static function buildReplaceStringWithCasePreserved(matches:Null<Array<String>>, pattern:String):String {
        if (matches != null && (matches[0] != '')) {
            final containsHyphens = validateSpecificSpecialCharacter(matches, pattern, '-');
            final containsUnderscores = validateSpecificSpecialCharacter(matches, pattern, '_');
            if (containsHyphens && !containsUnderscores) {
                return buildReplaceStringForSpecificSpecialCharacter(matches, pattern, '-');
            } else if (!containsHyphens && containsUnderscores) {
                return buildReplaceStringForSpecificSpecialCharacter(matches, pattern, '_');
            }
            final match0 = matches[0];
            if (match0.toUpperCase() == match0) {
                return pattern.toUpperCase();
            } else if (match0.toLowerCase() == match0) {
                return pattern.toLowerCase();
            } else if (containsUppercaseCharacter(match0.charAt(0)) && pattern.length > 0) {
                return pattern.charAt(0).toUpperCase() + pattern.substr(1);
            } else if (match0.charAt(0).toUpperCase() != match0.charAt(0) && pattern.length > 0) {
                return pattern.charAt(0).toLowerCase() + pattern.substr(1);
            } else {
                // we don't understand its pattern yet.
                return pattern;
            }
        } else {
            return pattern;
        }
    }

    static function validateSpecificSpecialCharacter(matches:Array<String>, pattern:String, specialCharacter:String):Bool {
        final doesContainSpecialCharacter = matches[0].indexOf(specialCharacter) != -1 && pattern.indexOf(specialCharacter) != -1;
        return doesContainSpecialCharacter && matches[0].split(specialCharacter).length == pattern.split(specialCharacter).length;
    }

    static function buildReplaceStringForSpecificSpecialCharacter(matches:Array<String>, pattern:String, specialCharacter:String):String {
        final splitPatternAtSpecialCharacter = pattern.split(specialCharacter);
        final splitMatchAtSpecialCharacter = matches[0].split(specialCharacter);
        var replaceString:String = '';
        for (index in 0...splitPatternAtSpecialCharacter.length) {
            final splitValue = splitPatternAtSpecialCharacter[index];
            // JavaScript reads `undefined` past the end of the array, which
            // `buildReplaceStringWithCasePreserved` treats like no match
            final splitMatch = index < splitMatchAtSpecialCharacter.length ? [splitMatchAtSpecialCharacter[index]] : null;
            replaceString += buildReplaceStringWithCasePreserved(splitMatch, splitValue) + specialCharacter;
        }

        return replaceString.substr(0, replaceString.length - 1);
    }

    /**
     * strings.ts `containsUppercaseCharacter(target)` (without
     * `ignoreEscapedChars`).
     */
    static function containsUppercaseCharacter(target:String):Bool {
        if (target == null || target.length == 0) {
            return false;
        }
        return target.toLowerCase() != target;
    }

}
