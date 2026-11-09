// Ported from vscode src/vs/editor/common/model/utils.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.model;

import cityscape.base.common.CharCode;

class Utils {

    /**
     * Returns:
     *  - -1 => the line consists of whitespace
     *  - otherwise => the indent level is returned value
     */
    public static function computeIndentLevel(line:String, tabSize:Int):Int {
        var indent = 0;
        var i = 0;
        final len = line.length;

        while (i < len) {
            final chCode = StringTools.fastCodeAt(line, i);
            if (chCode == CharCode.Space) {
                indent++;
            }
            else if (chCode == CharCode.Tab) {
                indent = indent - indent % tabSize + tabSize;
            }
            else {
                break;
            }
            i++;
        }

        if (i == len) {
            return -1; // line only consists of whitespace
        }

        return indent;
    }

}
