// Ported from vscode src/vs/editor/common/core/indentation.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.core;

import cityscape.base.common.Strings;

class Indentation {

    static function _normalizeIndentationFromWhitespace(str:String, indentSize:Int, insertSpaces:Bool):String {
        var spacesCnt = 0;
        for (i in 0...str.length) {
            if (StringTools.fastCodeAt(str, i) == '\t'.code) {
                spacesCnt = CursorColumns.nextIndentTabStop(spacesCnt, indentSize);
            }
            else {
                spacesCnt++;
            }
        }

        final result = new StringBuf();
        if (!insertSpaces) {
            final tabsCnt = Std.int(spacesCnt / indentSize);
            spacesCnt = spacesCnt % indentSize;
            for (i in 0...tabsCnt) {
                result.addChar('\t'.code);
            }
        }

        for (i in 0...spacesCnt) {
            result.addChar(' '.code);
        }

        return result.toString();
    }

    public static function normalizeIndentation(str:String, indentSize:Int, insertSpaces:Bool):String {
        var firstNonWhitespaceIndex = Strings.firstNonWhitespaceIndex(str);
        if (firstNonWhitespaceIndex == -1) {
            firstNonWhitespaceIndex = str.length;
        }
        return _normalizeIndentationFromWhitespace(str.substring(0, firstNonWhitespaceIndex), indentSize, insertSpaces) + str.substring(firstNonWhitespaceIndex);
    }

}
