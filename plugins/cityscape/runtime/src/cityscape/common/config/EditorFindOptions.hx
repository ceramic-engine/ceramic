// Ported from vscode src/vs/editor/common/config/editorOptions.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.config;

import cityscape.base.common.JsValues;
import cityscape.common.config.EditorOptions;
import cityscape.common.config.EditorOptions.AnyEditorOption;

/*
 * The `find` editor option (`#region find` of editorOptions.ts), ported
 * with the find contribution. Registered by `EditorOptions.init()` through
 * `registerSimple()` below.
 */

/**
 * Configuration options for editor find widget
 */
typedef IEditorFindOptions = {
    /**
     * Controls whether the cursor should move to find matches while typing.
     */
    @:optional var cursorMoveOnType:Bool;
    /**
     * Controls if we seed search string in the Find Widget with editor
     * selection: `'never'`, `'always'` or `'selection'` (a boolean is
     * accepted: true is `'always'`, false `'never'`).
     */
    @:optional var seedSearchStringFromSelection:Any;
    /**
     * Controls if Find in Selection flag is turned on in the editor:
     * `'never'`, `'always'` or `'multiline'` (a boolean is accepted: true is
     * `'always'`, false `'never'`).
     */
    @:optional var autoFindInSelection:Any;
    /**
     * Controls whether the Find Widget should add extra lines on top of the editor.
     */
    @:optional var addExtraSpaceOnTop:Bool;
    /**
     * Controls if the Find Widget should read or modify the shared find clipboard on macOS
     * @internal
     */
    @:optional var globalFindClipboard:Bool;
    /**
     * Controls whether the search result and diff result automatically restarts from the beginning (or the end) when no further matches can be found
     */
    @:optional var loop:Bool;
}

/**
 * @internal
 */
typedef EditorFindOptions = {
    final cursorMoveOnType:Bool;
    final seedSearchStringFromSelection:String;
    final autoFindInSelection:String;
    final globalFindClipboard:Bool;
    final addExtraSpaceOnTop:Bool;
    final loop:Bool;
}

class EditorFind extends BaseEditorOption<EditorFindOptions> {

    public function new() {
        final defaults:EditorFindOptions = {
            cursorMoveOnType: true,
            seedSearchStringFromSelection: 'always',
            autoFindInSelection: 'never',
            globalFindClipboard: false,
            addExtraSpaceOnTop: true,
            loop: true
        };
        super(EditorOption.find, 'find', defaults);
    }

    public function validate(_input:Any):EditorFindOptions {
        if (!JsValues.truthy(_input) || !JsValues.isObject(_input)) {
            return this.defaultValue;
        }
        final input = _input;
        final seed:Any = JsValues.field(input, 'seedSearchStringFromSelection');
        final auto:Any = JsValues.field(input, 'autoFindInSelection');
        return {
            cursorMoveOnType: EditorOptions.boolean(JsValues.field(input, 'cursorMoveOnType'), this.defaultValue.cursorMoveOnType),
            seedSearchStringFromSelection: JsValues.isBoolean(seed)
                ? ((seed : Bool) ? 'always' : 'never')
                : EditorOptions.stringSet(seed, this.defaultValue.seedSearchStringFromSelection, ['never', 'always', 'selection']),
            autoFindInSelection: JsValues.isBoolean(auto)
                ? ((auto : Bool) ? 'always' : 'never')
                : EditorOptions.stringSet(auto, this.defaultValue.autoFindInSelection, ['never', 'always', 'multiline']),
            globalFindClipboard: EditorOptions.boolean(JsValues.field(input, 'globalFindClipboard'), this.defaultValue.globalFindClipboard),
            addExtraSpaceOnTop: EditorOptions.boolean(JsValues.field(input, 'addExtraSpaceOnTop'), this.defaultValue.addExtraSpaceOnTop),
            loop: EditorOptions.boolean(JsValues.field(input, 'loop'), this.defaultValue.loop),
        };
    }

}

class EditorFindOptionsRegistration {

    /**
     * Registers the `find` option (called by `EditorOptions.init()`).
     */
    public static function registerSimple(register:(option:AnyEditorOption) -> Void):Void {
        register(cast new EditorFind());
    }

}
