// Ported from vscode src/vs/editor/common/services/modelService.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.services;

import cityscape.base.common.JsValues;
import cityscape.base.common.Platform;
import cityscape.common.Model.BracketPairColorizationOptions;
import cityscape.common.Model.DefaultEndOfLine;
import cityscape.common.Model.ITextModelCreationOptions;
import cityscape.common.Model.IndentSize;
import cityscape.common.core.TextModelDefaults;

/**
 * The model options of the settings (`editor.tabSize`, `editor.insertSpaces`...),
 * as Monaco reads them: untyped values validated like JavaScript would.
 */
typedef IRawEditorConfig = {
    @:optional var tabSize:Any;
    @:optional var indentSize:Any;
    @:optional var insertSpaces:Any;
    @:optional var detectIndentation:Any;
    @:optional var trimAutoWhitespace:Any;
    @:optional var creationOptions:Any;
    @:optional var largeFileOptimizations:Any;
    @:optional var bracketPairColorization:Any;
}

typedef IRawConfig = {
    @:optional var eol:Any;
    @:optional var editor:IRawEditorConfig;
}

/**
 * TODO(step 1): only the reading of the model options so far. The model
 * service (models by uri, creation, disposal, undo/redo snapshots) is a field
 * of the `Cityscape` context, shared by its editors.
 */
class ModelService {

    static var DEFAULT_EOL(get, never):DefaultEndOfLine;
    static function get_DEFAULT_EOL():DefaultEndOfLine {
        return (Platform.isLinux || Platform.isMacintosh) ? DefaultEndOfLine.LF : DefaultEndOfLine.CRLF;
    }

    static function readBoolean(value:Any):Bool {
        return (JsValues.isString(value) && (value : String) == 'false') ? false : JsValues.truthy(value);
    }

    public static function _readModelOptions(config:IRawConfig, isForSimpleWidget:Bool):ITextModelCreationOptions {
        final defaults = TextModelDefaults.EDITOR_MODEL_DEFAULTS;
        final editor = config.editor;

        var tabSize = defaults.tabSize;
        if (editor != null && !JsValues.isUndefined(editor.tabSize)) {
            final parsedTabSize = JsValues.parseInt(editor.tabSize);
            if (!Math.isNaN(parsedTabSize)) {
                tabSize = Std.int(parsedTabSize);
            }
            if (tabSize < 1) {
                tabSize = 1;
            }
        }

        var indentSize:IndentSize = 'tabSize';
        if (editor != null && !JsValues.isUndefined(editor.indentSize) && !(JsValues.isString(editor.indentSize) && (editor.indentSize : String) == 'tabSize')) {
            final parsedIndentSize = JsValues.parseInt(editor.indentSize);
            if (!Math.isNaN(parsedIndentSize)) {
                indentSize = Std.int(Math.max(parsedIndentSize, 1));
            }
        }

        var insertSpaces = defaults.insertSpaces;
        if (editor != null && !JsValues.isUndefined(editor.insertSpaces)) {
            insertSpaces = readBoolean(editor.insertSpaces);
        }

        var newDefaultEOL = DEFAULT_EOL;
        final eol = config.eol;
        if (JsValues.isString(eol) && (eol : String) == '\r\n') {
            newDefaultEOL = DefaultEndOfLine.CRLF;
        }
        else if (JsValues.isString(eol) && (eol : String) == '\n') {
            newDefaultEOL = DefaultEndOfLine.LF;
        }

        var trimAutoWhitespace = defaults.trimAutoWhitespace;
        if (editor != null && !JsValues.isUndefined(editor.trimAutoWhitespace)) {
            trimAutoWhitespace = readBoolean(editor.trimAutoWhitespace);
        }

        var detectIndentation = defaults.detectIndentation;
        if (editor != null && !JsValues.isUndefined(editor.detectIndentation)) {
            detectIndentation = readBoolean(editor.detectIndentation);
        }

        var largeFileOptimizations = defaults.largeFileOptimizations;
        if (editor != null && !JsValues.isUndefined(editor.largeFileOptimizations)) {
            largeFileOptimizations = readBoolean(editor.largeFileOptimizations);
        }
        var bracketPairColorizationOptions:BracketPairColorizationOptions = defaults.bracketPairColorizationOptions;
        if (editor != null && JsValues.truthy(editor.bracketPairColorization) && JsValues.isObject(editor.bracketPairColorization)) {
            bracketPairColorizationOptions = {
                enabled: JsValues.truthy(JsValues.field(editor.bracketPairColorization, 'enabled')),
                independentColorPoolPerBracketType: JsValues.truthy(JsValues.field(editor.bracketPairColorization, 'independentColorPoolPerBracketType'))
            };
        }

        return {
            isForSimpleWidget: isForSimpleWidget,
            tabSize: tabSize,
            indentSize: indentSize,
            insertSpaces: insertSpaces,
            detectIndentation: detectIndentation,
            defaultEOL: newDefaultEOL,
            trimAutoWhitespace: trimAutoWhitespace,
            largeFileOptimizations: largeFileOptimizations,
            bracketPairColorizationOptions: bracketPairColorizationOptions
        };
    }

}
