// Ported from vscode src/vs/editor/contrib/hover/browser/markdownHoverParticipant.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.hover.view;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.HtmlContent.IMarkdownString;
import cityscape.base.common.JsValues;
import cityscape.common.Languages.Hover;
import cityscape.common.Languages.HoverProvider;
import cityscape.common.Model.IModelDecoration;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.contrib.hover.view.HoverTypes;
import cityscape.view.EditorBrowser;
import glaze.App;
import glaze.IntoElement;
import glaze.Window;

import glaze.Prelude.*;

class MarkdownHover implements IHoverPart {

    public var owner(default, null):IEditorHoverParticipant;
    public var range(default, null):Range;
    public var forceShowAtRange(default, null):Bool = false;
    public var isBeforeContent(default, null):Bool;
    public final contents:Array<IMarkdownString>;
    public final ordinal:Int;
    public final source:Null<HoverSource>;

    public function new(owner:IEditorHoverParticipant, range:Range, contents:Array<IMarkdownString>, isBeforeContent:Bool, ordinal:Int, ?source:HoverSource) {
        this.owner = owner;
        this.range = range;
        this.contents = contents;
        this.isBeforeContent = isBeforeContent;
        this.ordinal = ordinal;
        this.source = source;
    }

    public function isValidForHoverAnchor(anchor:HoverAnchor):Bool {
        return (
            anchor.type == cityscape.contrib.hover.view.HoverAnchorType.Range
            && this.range.startColumn <= anchor.range.startColumn
            && this.range.endColumn >= anchor.range.endColumn
        );
    }
}

class HoverSource {

    public final hover:Hover;
    public final hoverProvider:HoverProvider;
    public final hoverPosition:Position;

    public function new(hover:Hover, hoverProvider:HoverProvider, hoverPosition:Position) {
        this.hover = hover;
        this.hoverProvider = hoverProvider;
        this.hoverPosition = hoverPosition;
    }
}

/**
 * The markdown parts of the hover: the hover messages of the decorations
 * (computed at once) and the hovers of the providers (Monaco's
 * `MarkdownHoverParticipant`). The verbosity actions are not ported.
 */
class MarkdownHoverParticipant implements IEditorHoverParticipant {

    public var hoverOrdinal(default, null):Int = 3;

    public var computeAsync(default, null):Null<(anchor:HoverAnchor, lineDecorations:Array<IModelDecoration>, token:CancellationToken, onItem:(part:IHoverPart) -> Void, onDone:() -> Void) -> Void>;

    final _editor:ICodeEditor;

    public function new(editor:ICodeEditor) {
        this._editor = editor;
        this.computeAsync = _computeAsync;
    }

    public function suggestHoverAnchor(mouseEvent:IEditorMouseEvent):Null<HoverAnchor> {
        return null;
    }

    static function isEmptyMarkdownString(oneOrMany:Any):Bool {
        if (JsValues.isArray(oneOrMany)) {
            final many:Array<IMarkdownString> = oneOrMany;
            for (one in many) {
                if (!isEmptyMarkdownString(one)) {
                    return false;
                }
            }
            return true;
        }
        if (oneOrMany == null) {
            return true;
        }
        final one:IMarkdownString = oneOrMany;
        return one.value == null || one.value.length == 0;
    }

    public function createLoadingMessage(anchor:HoverAnchor):Null<IHoverPart> {
        return new MarkdownHover(this, anchor.range, [{value: _editor.context.nls.localize('modesContentHover.loading', "Loading...")}], false, 2000);
    }

    public function computeSync(anchor:HoverAnchor, lineDecorations:Array<IModelDecoration>):Array<IHoverPart> {
        if (!this._editor.hasModel() || anchor.type != cityscape.contrib.hover.view.HoverAnchorType.Range) {
            return [];
        }

        final model = this._editor.getModel();
        final lineNumber = anchor.range.startLineNumber;
        final maxColumn = model.getLineMaxColumn(lineNumber);
        final result:Array<IHoverPart> = [];

        var index = 1000;

        final lineLength = model.getLineLength(lineNumber);
        final stopRenderingLineAfter = this._editor.getOption(EditorOption.stopRenderingLineAfter);
        if (stopRenderingLineAfter >= 0 && lineLength > stopRenderingLineAfter && anchor.range.startColumn >= stopRenderingLineAfter) {
            result.push(new MarkdownHover(this, anchor.range, [{
                value: _editor.context.nls.localize('stopped rendering', "Rendering paused for long line for performance reasons. This can be configured via `editor.stopRenderingLineAfter`.")
            }], false, index++));
        }

        var isBeforeContent = false;

        for (d in lineDecorations) {
            final startColumn = (d.range.startLineNumber == lineNumber) ? d.range.startColumn : 1;
            final endColumn = (d.range.endLineNumber == lineNumber) ? d.range.endColumn : maxColumn;

            final hoverMessage:Any = d.options.hoverMessage;
            if (hoverMessage == null || isEmptyMarkdownString(hoverMessage)) {
                continue;
            }

            if (d.options.beforeContentClassName != null) {
                isBeforeContent = true;
            }

            final range = new Range(anchor.range.startLineNumber, startColumn, anchor.range.startLineNumber, endColumn);
            final contents:Array<IMarkdownString> = JsValues.isArray(hoverMessage) ? cast hoverMessage : [cast hoverMessage];
            result.push(new MarkdownHover(this, range, contents, isBeforeContent, index++));
        }

        return result;
    }

    function _computeAsync(anchor:HoverAnchor, lineDecorations:Array<IModelDecoration>, token:CancellationToken, onItem:(part:IHoverPart) -> Void, onDone:() -> Void):Void {
        if (!this._editor.hasModel() || anchor.type != cityscape.contrib.hover.view.HoverAnchorType.Range) {
            onDone();
            return;
        }

        final model = this._editor.getModel();

        final hoverProviderRegistry = this._editor.context.languageFeaturesService.hoverProvider;
        if (!hoverProviderRegistry.has(model)) {
            onDone();
            return;
        }
        final position = anchor.range.getStartPosition();
        GetHover.getHoverProviderResults(hoverProviderRegistry, model, position, token, item -> {
            if (isEmptyMarkdownString(item.hover.contents)) {
                return;
            }
            final range = item.hover.range != null ? Range.lift(item.hover.range) : anchor.range;
            final hoverSource = new HoverSource(item.hover, item.provider, position);
            onItem(new MarkdownHover(this, range, item.hover.contents, false, item.ordinal, hoverSource));
        }, onDone);
    }

    public function renderHoverParts(context:IEditorHoverRenderContext, hoverParts:Array<IHoverPart>, window:Window, cx:App):Array<IntoElement> {
        final result:Array<IntoElement> = [];
        var partIndex = 0;
        // Monaco sorts the markdown hovers by ordinal before rendering them
        final parts:Array<MarkdownHover> = [for (p in hoverParts) cast p];
        haxe.ds.ArraySort.sort(parts, (a, b) -> a.ordinal - b.ordinal);
        for (hoverPart in parts) {
            final row = div().flex().flexCol().gap(px(4)).px(px(8)).py(px(4));
            var contentIndex = 0;
            for (content in hoverPart.contents) {
                if (content.value == null || content.value.length == 0) {
                    continue;
                }
                row.child(MarkdownRenderer.render(_editor, 'cityscape-hover-md-' + partIndex + '-' + contentIndex, content, cx));
                contentIndex++;
            }
            result.push(row);
            partIndex++;
        }
        return result;
    }

    public function getAccessibleContent(hoverPart:IHoverPart):String {
        final part:MarkdownHover = cast hoverPart;
        return [for (c in part.contents) c.value].join('\n');
    }

}
