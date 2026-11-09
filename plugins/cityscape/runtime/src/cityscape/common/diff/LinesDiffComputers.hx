// Ported from vscode src/vs/editor/common/diff/linesDiffComputers.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.diff;

import cityscape.common.diff.LinesDiffComputer.ILinesDiffComputer;
import cityscape.common.diff.defaultLinesDiffComputer.DefaultLinesDiffComputer;

/**
 * Monaco's `linesDiffComputers` object.
 */
class LinesDiffComputers {

    public static function getLegacy():ILinesDiffComputer {
        return new LegacyLinesDiffComputer();
    }

    public static function getDefault():ILinesDiffComputer {
        return new DefaultLinesDiffComputer();
    }

}
