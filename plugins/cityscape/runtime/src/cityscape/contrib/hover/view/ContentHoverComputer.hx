// Ported from vscode src/vs/editor/contrib/hover/browser/contentHoverComputer.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.hover.view;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.common.Model.IModelDecoration;
import cityscape.common.model.TextModel.ModelDecorationOptions;
import cityscape.contrib.hover.view.HoverOperation;
import cityscape.contrib.hover.view.HoverTypes;
import cityscape.view.EditorBrowser.ICodeEditor;

class ContentHoverComputer implements IHoverComputer<IHoverPart> {

    public var anchor:Null<HoverAnchor> = null;
    public var shouldFocus:Bool = false;
    public var source:HoverStartSource = HoverStartSource.Mouse;
    public var insistOnKeepingHoverVisible:Bool = false;

    public var computeAsync(default, null):Null<(token:CancellationToken, onItem:(item:IHoverPart) -> Void, onDone:() -> Void) -> Void>;
    public var computeSync(default, null):Null<() -> Array<IHoverPart>>;

    final _editor:ICodeEditor;
    final _participants:Array<IEditorHoverParticipant>;

    public function new(editor:ICodeEditor, participants:Array<IEditorHoverParticipant>) {
        this._editor = editor;
        this._participants = participants;
        this.computeAsync = _computeAsync;
        this.computeSync = _computeSync;
    }

    static function _getLineDecorations(editor:ICodeEditor, anchor:HoverAnchor):Array<IModelDecoration> {
        if (anchor.type != cityscape.contrib.hover.view.HoverAnchorType.Range && !anchor.supportsMarkerHover) {
            return [];
        }

        final model = editor.getModel();
        final lineNumber = anchor.range.startLineNumber;

        if (lineNumber > model.getLineCount()) {
            // invalid line
            return [];
        }

        final maxColumn = model.getLineMaxColumn(lineNumber);

        final decorations = editor.getLineDecorations(lineNumber);
        if (decorations == null) {
            return [];
        }
        return decorations.filter(d -> {
            if (d.options.isWholeLine == true) {
                return true;
            }

            final startColumn = (d.range.startLineNumber == lineNumber) ? d.range.startColumn : 1;
            final endColumn = (d.range.endLineNumber == lineNumber) ? d.range.endColumn : maxColumn;

            if (d.options.showIfCollapsed == true) {
                // Relax check around `showIfCollapsed` decorations to also include +/- 1 character
                if (startColumn > anchor.range.startColumn + 1 || anchor.range.endColumn - 1 > endColumn) {
                    return false;
                }
            }
            else {
                if (startColumn > anchor.range.startColumn || anchor.range.endColumn > endColumn) {
                    return false;
                }
            }

            return true;
        });
    }

    function _computeAsync(token:CancellationToken, onItem:(item:IHoverPart) -> Void, onDone:() -> Void):Void {
        final anchor = this.anchor;

        if (!this._editor.hasModel() || anchor == null) {
            onDone();
            return;
        }

        final lineDecorations = ContentHoverComputer._getLineDecorations(this._editor, anchor);

        // AsyncIterableObject.merge: the items of all the participants as they come
        var remaining = 1;
        final done = () -> {
            remaining--;
            if (remaining == 0) {
                onDone();
            }
        };
        for (participant in this._participants) {
            final computeAsync = participant.computeAsync;
            if (computeAsync == null) {
                continue;
            }
            remaining++;
            computeAsync(anchor, lineDecorations, token, onItem, done);
        }
        done();
    }

    function _computeSync():Array<IHoverPart> {
        if (!this._editor.hasModel() || this.anchor == null) {
            return [];
        }

        final lineDecorations = ContentHoverComputer._getLineDecorations(this._editor, this.anchor);

        var result:Array<IHoverPart> = [];
        for (participant in this._participants) {
            result = result.concat(participant.computeSync(this.anchor, lineDecorations));
        }

        return [for (r in result) if (r != null) r];
    }

}
