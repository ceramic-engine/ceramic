// Ported from vscode src/vs/editor/common/core/textModelDefaults.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.core;

import cityscape.common.Model.BracketPairColorizationOptions;

typedef EditorModelDefaults = {
    final tabSize:Int;
    final indentSize:Int;
    final insertSpaces:Bool;
    final detectIndentation:Bool;
    final trimAutoWhitespace:Bool;
    final largeFileOptimizations:Bool;
    final bracketPairColorizationOptions:BracketPairColorizationOptions;
}

class TextModelDefaults {

    /**
     * Default options of a text model.
     */
    public static final EDITOR_MODEL_DEFAULTS:EditorModelDefaults = {
        tabSize: 4,
        indentSize: 4,
        insertSpaces: true,
        detectIndentation: true,
        trimAutoWhitespace: true,
        largeFileOptimizations: true,
        bracketPairColorizationOptions: {
            enabled: true,
            independentColorPoolPerBracketType: false,
        },
    };

}
