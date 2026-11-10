// Ported from vscode src/vs/editor/contrib/dnd/browser/dnd.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.dnd.view;

import cityscape.base.common.KeyCodes.KeyCode;
import cityscape.base.common.Lifecycle.Disposable;
import cityscape.base.common.Platform;
import cityscape.common.CursorEvents.CursorChangeReason;
import cityscape.common.EditorCommon.IEditorContribution;
import cityscape.common.EditorCommon.IEditorDecorationsCollection;
import cityscape.common.EditorCommon.ScrollType;
import cityscape.common.config.EditorOptions.EditorOption;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.model.TextModel.ModelDecorationOptions;
import cityscape.platform.keybinding.common.Keybinding.IKeyboardEvent;
import cityscape.view.EditorBrowser;
import cityscape.view.EditorExtensions;
import cityscape.view.widget.codeEditor.CodeEditorWidget;

/**
 * Moves the selection with the mouse (Monaco's drag and drop of the
 * selection, `dragAndDrop` option): a press on a selection, then a drag,
 * shows where the text goes (`dnd-target`, a dotted caret painted by the
 * view), and the release moves the text there; with Alt on macOS (Ctrl
 * elsewhere) the text is copied, and the pointer is the copy cursor. The
 * view's mouse handling starts the drag (`CityscapeView.handleMouseDown`)
 * and fires `onMouseDrag`, `onMouseDrop` and `onMouseDropCanceled`.
 */
class DragAndDropController extends Disposable implements IEditorContribution {

    public static inline final ID = 'editor.contrib.dragAndDrop';

    public static inline final DECORATION_CLASS = 'dnd-target';

    final _editor:ICodeEditor;
    var _dragSelection:Null<Selection>;
    final _dndDecorationIds:IEditorDecorationsCollection;
    var _mouseDown:Bool;
    var _modifierPressed:Bool;

    public static var TRIGGER_KEY_VALUE(get, never):KeyCode;

    static function get_TRIGGER_KEY_VALUE():KeyCode {
        return Platform.isMacintosh ? KeyCode.Alt : KeyCode.Ctrl;
    }

    public static function get(editor:ICodeEditor):Null<DragAndDropController> {
        return editor.getContribution(DragAndDropController.ID);
    }

    static inline function hasTriggerModifier(altKey:Bool, ctrlKey:Bool):Bool {
        return Platform.isMacintosh ? altKey : ctrlKey;
    }

    public function new(editor:ICodeEditor) {
        super();
        this._editor = editor;
        this._dndDecorationIds = this._editor.createDecorationsCollection();
        this._register(this._editor.onMouseDown(e -> this._onEditorMouseDown(e)));
        this._register(this._editor.onMouseUp(e -> this._onEditorMouseUp(e)));
        this._register(this._editor.onMouseDrag(e -> this._onEditorMouseDrag(e)));
        this._register(this._editor.onMouseDrop(e -> this._onEditorMouseDrop(e)));
        this._register(this._editor.onMouseDropCanceled(() -> this._onEditorMouseDropCanceled()));
        this._register(this._editor.onKeyDown(e -> this.onEditorKeyDown(e)));
        this._register(this._editor.onKeyUp(e -> this.onEditorKeyUp(e)));
        this._register(this._editor.onDidBlurEditorWidget(() -> this.onEditorBlur()));
        this._register(this._editor.onDidBlurEditorText(() -> this.onEditorBlur()));
        this._mouseDown = false;
        this._modifierPressed = false;
        this._dragSelection = null;
    }

    function onEditorBlur():Void {
        this._removeDecoration();
        this._dragSelection = null;
        this._mouseDown = false;
        this._modifierPressed = false;
    }

    function onEditorKeyDown(e:IKeyboardEvent):Void {
        if (!this._editor.getOption(EditorOption.dragAndDrop) || this._editor.getOption(EditorOption.columnSelection)) {
            return;
        }

        if (hasTriggerModifier(e.altKey, e.ctrlKey)) {
            this._modifierPressed = true;
        }

        if (this._mouseDown && hasTriggerModifier(e.altKey, e.ctrlKey)) {
            this._editor.updateOptions({
                mouseStyle: 'copy'
            });
        }
    }

    function onEditorKeyUp(e:IKeyboardEvent):Void {
        if (!this._editor.getOption(EditorOption.dragAndDrop) || this._editor.getOption(EditorOption.columnSelection)) {
            return;
        }

        if (hasTriggerModifier(e.altKey, e.ctrlKey)) {
            this._modifierPressed = false;
        }

        if (this._mouseDown && e.keyCode == TRIGGER_KEY_VALUE) {
            this._editor.updateOptions({
                mouseStyle: 'default'
            });
        }
    }

    function _onEditorMouseDown(mouseEvent:IEditorMouseEvent):Void {
        this._mouseDown = true;
    }

    function _onEditorMouseUp(mouseEvent:IEditorMouseEvent):Void {
        this._mouseDown = false;
        // Whenever users release the mouse, the drag and drop operation should finish and the cursor should revert to text.
        this._editor.updateOptions({
            mouseStyle: 'text'
        });
    }

    function _onEditorMouseDrag(mouseEvent:IEditorMouseEvent):Void {
        final target = mouseEvent.target;

        if (this._dragSelection == null) {
            final selections = this._editor.getSelections();
            final possibleSelections = selections == null ? [] : selections.filter(selection -> target.position != null && selection.containsPosition(target.position));
            if (possibleSelections.length == 1) {
                this._dragSelection = possibleSelections[0];
            }
            else {
                return;
            }
        }

        if (hasTriggerModifier(mouseEvent.event.altKey, mouseEvent.event.ctrlKey)) {
            this._editor.updateOptions({
                mouseStyle: 'copy'
            });
        }
        else {
            this._editor.updateOptions({
                mouseStyle: 'default'
            });
        }

        if (target.position != null) {
            if (this._dragSelection.containsPosition(target.position)) {
                this._removeDecoration();
            }
            else {
                this.showAt(target.position);
            }
        }
    }

    function _onEditorMouseDropCanceled():Void {
        this._editor.updateOptions({
            mouseStyle: 'text'
        });

        this._removeDecoration();
        this._dragSelection = null;
        this._mouseDown = false;
    }

    function _onEditorMouseDrop(mouseEvent:IPartialEditorMouseEvent):Void {
        if (mouseEvent.target != null && (this._hitContent(mouseEvent.target) || this._hitMargin(mouseEvent.target)) && mouseEvent.target.position != null) {
            final newCursorPosition = new Position(mouseEvent.target.position.lineNumber, mouseEvent.target.position.column);

            if (this._dragSelection == null) {
                var newSelections:Null<Array<Selection>> = null;
                if (mouseEvent.event.shiftKey) {
                    final primarySelection = this._editor.getSelection();
                    if (primarySelection != null) {
                        newSelections = [new Selection(primarySelection.selectionStartLineNumber, primarySelection.selectionStartColumn, newCursorPosition.lineNumber, newCursorPosition.column)];
                    }
                }
                else {
                    final selections = this._editor.getSelections();
                    newSelections = (selections == null ? [] : selections).map(selection -> {
                        if (selection.containsPosition(newCursorPosition)) {
                            return new Selection(newCursorPosition.lineNumber, newCursorPosition.column, newCursorPosition.lineNumber, newCursorPosition.column);
                        }
                        else {
                            return selection;
                        }
                    });
                }
                // Use `mouse` as the source instead of `api` and setting the reason to explicit (to behave like any other mouse operation).
                (cast this._editor : CodeEditorWidget).setSelections(newSelections != null ? cast newSelections : [], 'mouse', CursorChangeReason.Explicit);
            }
            else if (!this._dragSelection.containsPosition(newCursorPosition)
                || (
                    (
                        hasTriggerModifier(mouseEvent.event.altKey, mouseEvent.event.ctrlKey)
                        || this._modifierPressed
                    ) && (
                        this._dragSelection.getEndPosition().equals(newCursorPosition) || this._dragSelection.getStartPosition().equals(newCursorPosition)
                    ) // we allow users to paste content beside the selection
                )) {
                this._editor.pushUndoStop();
                this._editor.executeCommand(DragAndDropController.ID, new DragAndDropCommand(this._dragSelection, newCursorPosition, hasTriggerModifier(mouseEvent.event.altKey, mouseEvent.event.ctrlKey) || this._modifierPressed));
                this._editor.pushUndoStop();
            }
        }

        this._editor.updateOptions({
            mouseStyle: 'text'
        });

        this._removeDecoration();
        this._dragSelection = null;
        this._mouseDown = false;
    }

    static var _DECORATION_OPTIONS:Null<ModelDecorationOptions> = null;

    static function decorationOptions():ModelDecorationOptions {
        if (_DECORATION_OPTIONS == null) {
            _DECORATION_OPTIONS = ModelDecorationOptions.register({
                description: 'dnd-target',
                className: DECORATION_CLASS
            });
        }
        return _DECORATION_OPTIONS;
    }

    public function showAt(position:Position):Void {
        this._dndDecorationIds.set([{
            range: new Range(position.lineNumber, position.column, position.lineNumber, position.column),
            options: cast decorationOptions()
        }]);
        this._editor.revealPosition(position, ScrollType.Immediate);
    }

    function _removeDecoration():Void {
        this._dndDecorationIds.clear();
    }

    function _hitContent(target:IMouseTarget):Bool {
        return target.type == MouseTargetType.CONTENT_TEXT || target.type == MouseTargetType.CONTENT_EMPTY;
    }

    function _hitMargin(target:IMouseTarget):Bool {
        return target.type == MouseTargetType.GUTTER_GLYPH_MARGIN || target.type == MouseTargetType.GUTTER_LINE_NUMBERS || target.type == MouseTargetType.GUTTER_LINE_DECORATIONS;
    }

    public function saveViewState():Any {
        return null;
    }

    public function restoreViewState(state:Any):Void {}

    override public function dispose():Void {
        this._removeDecoration();
        this._dragSelection = null;
        this._mouseDown = false;
        this._modifierPressed = false;
        super.dispose();
    }

}

/**
 * The registration of dnd.ts (its module level code).
 */
class DndRegistration {

    public static function register(r:EditorExtensionsRegistry):Void {
        r.registerEditorContribution(DragAndDropController.ID, editor -> new DragAndDropController(editor), EditorContributionInstantiation.BeforeFirstInteraction);
    }

}
