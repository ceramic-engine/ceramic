// Ported from vscode src/vs/editor/contrib/indentation/common/indentUtils.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.indentation.common;

import cityscape.base.common.CharCode;

/**
 * The module functions of indentUtils.ts.
 */
class IndentUtils {

    public static function getSpaceCnt(str:String, tabSize:Int):Int {
        var spacesCnt = 0;

        for (i in 0...str.length) {
            if (StringTools.fastCodeAt(str, i) == CharCode.Tab) {
                spacesCnt += tabSize;
            }
            else {
                spacesCnt++;
            }
        }

        return spacesCnt;
    }

    public static function generateIndent(spacesCnt:Int, tabSize:Int, insertSpaces:Bool):String {
        spacesCnt = spacesCnt < 0 ? 0 : spacesCnt;

        final result = new StringBuf();
        if (!insertSpaces) {
            final tabsCnt = Std.int(spacesCnt / tabSize);
            spacesCnt = spacesCnt % tabSize;
            for (i in 0...tabsCnt) {
                result.addChar(CharCode.Tab);
            }
        }

        for (i in 0...spacesCnt) {
            result.addChar(CharCode.Space);
        }

        return result.toString();
    }

}
