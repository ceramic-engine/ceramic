// Ported from vscode src/vs/editor/contrib/suggest/browser/suggestOvertypingCapturer.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.suggest.view;

import cityscape.base.common.Lifecycle;
import cityscape.contrib.suggest.view.SuggestModel;
import cityscape.view.EditorBrowser.ICodeEditor;

typedef OvertypedInfo = {
    final value:String;
    final multiline:Bool;
}

/**
 * Remembers the text a typed character replaced (the `SELECTION`
 * variable of a snippet inserted by suggest uses it).
 */
class OvertypingCapturer implements IDisposable {

    static inline final _maxSelectionLength = 51200;
    final _disposables = new DisposableStore();

    var _lastOvertyped:Array<OvertypedInfo> = [];
    var _locked:Bool = false;

    public function new(editor:ICodeEditor, suggestModel:SuggestModel) {

        this._disposables.add(editor.onWillType(_ -> {
            if (this._locked || !editor.hasModel()) {
                return;
            }

            final selections = editor.getSelections();
            final selectionsLength = selections.length;

            // Check if it will overtype any selections
            var willOvertype = false;
            for (i in 0...selectionsLength) {
                if (!selections[i].isEmpty()) {
                    willOvertype = true;
                    break;
                }
            }
            if (!willOvertype) {
                if (this._lastOvertyped.length != 0) {
                    this._lastOvertyped = [];
                }
                return;
            }

            this._lastOvertyped = [];
            final model = editor.getModel();
            for (i in 0...selectionsLength) {
                final selection = selections[i];
                // Check for overtyping capturer restrictions
                if (model.getValueLengthInRange(selection) > OvertypingCapturer._maxSelectionLength) {
                    return;
                }
                this._lastOvertyped[i] = {value: model.getValueInRange(selection), multiline: selection.startLineNumber != selection.endLineNumber};
            }
        }));

        this._disposables.add(suggestModel.onDidTrigger(e -> {
            this._locked = true;
        }));

        this._disposables.add(suggestModel.onDidCancel(e -> {
            this._locked = false;
        }));
    }

    public function getLastOvertypedInfo(idx:Int):Null<OvertypedInfo> {
        if (idx >= 0 && idx < this._lastOvertyped.length) {
            return this._lastOvertyped[idx];
        }
        return null;
    }

    public function dispose():Void {
        this._disposables.dispose();
    }

}
