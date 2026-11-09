// Ported from vscode src/vs/editor/contrib/inlineCompletions/browser/view/ghostTextView.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.inlineCompletions.view.view;

import cityscape.base.common.Lifecycle;
import cityscape.base.common.Observable;
import cityscape.base.common.observableInternal.Base;
import cityscape.common.Model;
import cityscape.common.ViewModel.InlineDecorationType;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.viewLayout.LineDecorations.LineDecoration;
import cityscape.contrib.inlineCompletions.view.Utils;
import cityscape.contrib.inlineCompletions.view.model.GhostText;
import cityscape.view.CityscapeView;
import cityscape.view.EditorBrowser;

typedef IGhostTextWidgetModel = {
    final targetTextModel:IObservable<Null<ITextModel>>;
    final ghostText:IObservable<Null<GhostTextOrReplacement>>;
    final minReservedLineCount:IObservable<Int>;
}

typedef LineData = {
    /**
     * Must not contain a linebreak!
     */
    var content:String;
    var decorations:Array<LineDecoration>;
}

private typedef InlineText = {
    final column:Int;
    final text:String;
    final preview:Bool;
}

private class GhostTextUiState {
    public final replacedRange:Null<ColumnRange>;
    public final inlineTexts:Array<InlineText>;
    public final additionalLines:Array<LineData>;
    public final hiddenRange:Null<ColumnRange>;
    public final lineNumber:Int;
    public final additionalReservedLineCount:Int;
    public final targetTextModel:ITextModel;

    public function new(replacedRange:Null<ColumnRange>, inlineTexts:Array<InlineText>, additionalLines:Array<LineData>, hiddenRange:Null<ColumnRange>, lineNumber:Int, additionalReservedLineCount:Int, targetTextModel:ITextModel) {
        this.replacedRange = replacedRange;
        this.inlineTexts = inlineTexts;
        this.additionalLines = additionalLines;
        this.hiddenRange = hiddenRange;
        this.lineNumber = lineNumber;
        this.additionalReservedLineCount = additionalReservedLineCount;
        this.targetTextModel = targetTextModel;
    }
}

typedef AdditionalLinesData = {
    final targetTextModel:ITextModel;
    final lineNumber:Int;
    final additionalLines:Array<LineData>;
    final minReservedLineCount:Int;
}

/**
 * Shows a ghost text in an editor (Monaco's `GhostTextView`): the first
 * line of each part as injected text after its column (the
 * `ghost-text-decoration` class, `ghost-text-decoration-preview` for the
 * preview of a suggestion), the text after a multi line part hidden
 * (Monaco's `ghost-text-hidden` class: a `hidden` decoration here), and the
 * other lines in a view zone below the line (`AdditionalLinesWidget`).
 */
class GhostTextView extends Disposable {

    public static inline final GHOST_TEXT_DESCRIPTION = 'ghost-text';

    final isDisposed:ISettableObservable<Bool>;
    final currentTextModel:IObservable<Null<ITextModel>>;
    final uiState:IObservable<Null<GhostTextUiState>>;
    final decorations:IObservable<Array<IModelDeltaDecoration>>;
    final additionalLinesWidget:AdditionalLinesWidget;

    final editor:ICodeEditor;
    final model:IGhostTextWidgetModel;

    public function new(editor:ICodeEditor, model:IGhostTextWidgetModel) {
        super();
        this.editor = editor;
        this.model = model;
        this.isDisposed = Observable.observableValue('isDisposed', false);
        this.currentTextModel = Observable.observableFromEvent(cb -> this.editor.onDidChangeModel(_ -> cb()), () -> /** @description editor.model */ this.editor.getModel());

        this.uiState = Observable.derived(reader -> {
            if (this.isDisposed.read(reader)) {
                return null;
            }
            final textModel = this.currentTextModel.read(reader);
            if (textModel != this.model.targetTextModel.read(reader)) {
                return null;
            }
            final ghostText = this.model.ghostText.read(reader);
            if (ghostText == null) {
                return null;
            }

            final replacedRange = Std.isOfType(ghostText, GhostTextReplacement) ? (cast ghostText : GhostTextReplacement).columnRange : null;

            final inlineTexts:Array<InlineText> = [];
            final additionalLines:Array<LineData> = [];

            function addToAdditionalLines(lines:Array<String>, className:Null<String>):Void {
                if (additionalLines.length > 0) {
                    final lastLine = additionalLines[additionalLines.length - 1];
                    if (className != null) {
                        lastLine.decorations.push(new LineDecoration(lastLine.content.length + 1, lastLine.content.length + 1 + lines[0].length, className, InlineDecorationType.Regular));
                    }
                    lastLine.content += lines[0];

                    lines = lines.slice(1);
                }
                for (line in lines) {
                    additionalLines.push({
                        content: line,
                        decorations: className != null ? [new LineDecoration(1, line.length + 1, className, InlineDecorationType.Regular)] : []
                    });
                }
            }

            final textBufferLine = textModel.getLineContent(ghostText.lineNumber);

            var hiddenTextStartColumn:Null<Int> = null;
            var lastIdx = 0;
            for (part in ghostText.parts) {
                var lines = part.lines;
                if (hiddenTextStartColumn == null) {
                    inlineTexts.push({
                        column: part.column,
                        text: lines[0],
                        preview: part.preview,
                    });
                    lines = lines.slice(1);
                }
                else {
                    addToAdditionalLines([textBufferLine.substring(lastIdx, part.column - 1)], null);
                }

                if (lines.length > 0) {
                    addToAdditionalLines(lines, GHOST_TEXT_DESCRIPTION);
                    if (hiddenTextStartColumn == null && part.column <= textBufferLine.length) {
                        hiddenTextStartColumn = part.column;
                    }
                }

                lastIdx = part.column - 1;
            }
            if (hiddenTextStartColumn != null) {
                addToAdditionalLines([textBufferLine.substring(lastIdx)], null);
            }

            final hiddenRange = hiddenTextStartColumn != null ? new ColumnRange(hiddenTextStartColumn, textBufferLine.length + 1) : null;

            return new GhostTextUiState(
                replacedRange,
                inlineTexts,
                additionalLines,
                hiddenRange,
                ghostText.lineNumber,
                this.model.minReservedLineCount.read(reader),
                textModel
            );
        });

        this.decorations = Observable.derived(reader -> {
            final uiState = this.uiState.read(reader);
            if (uiState == null) {
                return [];
            }

            final decorations:Array<IModelDeltaDecoration> = [];

            if (uiState.replacedRange != null) {
                decorations.push({
                    range: uiState.replacedRange.toRange(uiState.lineNumber),
                    options: {inlineClassName: 'inline-completion-text-to-replace', description: 'GhostTextReplacement'}
                });
            }

            if (uiState.hiddenRange != null) {
                // `ghost-text-hidden` is `opacity: 0; font-size: 0` in Monaco's
                // CSS: the text is hidden (Cityscape's `hidden` decorations)
                decorations.push({
                    range: uiState.hiddenRange.toRange(uiState.lineNumber),
                    options: {inlineClassName: 'ghost-text-hidden', description: 'ghost-text-hidden', hidden: true}
                });
            }

            for (p in uiState.inlineTexts) {
                decorations.push({
                    range: Range.fromPositions(new Position(uiState.lineNumber, p.column)),
                    options: {
                        description: GHOST_TEXT_DESCRIPTION,
                        after: {content: p.text, inlineClassName: p.preview ? 'ghost-text-decoration-preview' : 'ghost-text-decoration', cursorStops: InjectedTextCursorStops.Left},
                        showIfCollapsed: true,
                    }
                });
            }

            return decorations;
        });

        this._register(Lifecycle.toDisposable(() -> {
            this.isDisposed.set(true, null);
        }));
        this._register(Utils.applyObservableDecorations(this.editor, this.decorations));

        this.additionalLinesWidget = this._register(
            new AdditionalLinesWidget(
                this.editor,
                Observable.derived(reader -> {
                    /** @description lines */
                    final uiState = this.uiState.read(reader);
                    return uiState != null ? ({
                        lineNumber: uiState.lineNumber,
                        additionalLines: uiState.additionalLines,
                        minReservedLineCount: uiState.additionalReservedLineCount,
                        targetTextModel: uiState.targetTextModel,
                    } : AdditionalLinesData) : null;
                })
            )
        );
    }

    public function ownsViewZone(viewZoneId:String):Bool {
        return this.additionalLinesWidget.viewZoneId == viewZoneId;
    }

    /**
     * The lines the view zone of the ghost text paints (null when there is
     * no zone; tests).
     */
    public function getAdditionalLines():Null<Array<LineData>> {
        return this.additionalLinesWidget.lines;
    }

    /**
     * The look of the class names of the ghost text (ghostTextView.css),
     * registered in the context unless the host registered its own.
     */
    public static function registerDecorationStyles(context:cityscape.Cityscape):Void {
        final styles = context.decorationStyles;
        if (styles.get('ghost-text-decoration') == null) {
            context.registerDecorationStyle('ghost-text-decoration', {
                important: true,
                color: {id: 'editorGhostText.foreground'},
                background: {id: 'editorGhostText.background'},
                border: {color: {id: 'editorGhostText.border'}, width: 1},
                fontStyle: 'italic'
            });
        }
        if (styles.get('ghost-text-decoration-preview') == null) {
            context.registerDecorationStyle('ghost-text-decoration-preview', {
                important: true,
                color: {id: 'editorGhostText.foreground'},
                background: {id: 'editorGhostText.background'},
                border: {color: {id: 'editorGhostText.border'}, width: 1}
            });
        }
        if (styles.get('inline-completion-text-to-replace') == null) {
            context.registerDecorationStyle('inline-completion-text-to-replace', {
                underline: {}
            });
        }
    }

}

/**
 * The lines of a ghost text after its first one, in a view zone below its
 * line (Monaco's `AdditionalLinesWidget`). Monaco renders them to HTML with
 * `renderViewLine` (no whitespace rendering, the editor's font); the zone
 * paints them here with the editor's font, the parts of the ghost text
 * (`ghost-text`) in `editorGhostText.foreground` and italic, the other text
 * in `editor.foreground`. Tabs are expanded to the tab size.
 */
class AdditionalLinesWidget extends Disposable {

    var _viewZoneId:Null<String> = null;
    public var viewZoneId(get, never):Null<String>;
    function get_viewZoneId():Null<String> {
        return this._viewZoneId;
    }

    /**
     * The lines of the current zone.
     */
    public var lines(default, null):Null<Array<LineData>> = null;

    final editorOptionsChanged:IObservable<Any>;

    final editor:ICodeEditor;
    final linesObservable:IObservable<Null<AdditionalLinesData>>;

    public function new(editor:ICodeEditor, lines:IObservable<Null<AdditionalLinesData>>) {
        super();
        this.editor = editor;
        this.linesObservable = lines;
        this.editorOptionsChanged = Observable.observableSignalFromEvent('editorOptionChanged', cb -> this.editor.onDidChangeConfiguration(e -> {
            if (e.hasChanged(EditorOption.disableMonospaceOptimizations)
                || e.hasChanged(EditorOption.stopRenderingLineAfter)
                || e.hasChanged(EditorOption.renderWhitespace)
                || e.hasChanged(EditorOption.renderControlCharacters)
                || e.hasChanged(EditorOption.fontLigatures)
                || e.hasChanged(EditorOption.fontInfo)
                || e.hasChanged(EditorOption.lineHeight)) {
                cb();
            }
        }));

        this._register(Observable.autorun(reader -> {
            /** @description update view zone */
            final lines = this.linesObservable.read(reader);
            this.editorOptionsChanged.read(reader);

            if (lines != null) {
                this.updateLines(lines.lineNumber, lines.additionalLines, lines.minReservedLineCount);
            }
            else {
                this.clear();
            }
        }));
    }

    override public function dispose():Void {
        super.dispose();
        this.clear();
    }

    function clear():Void {
        this.lines = null;
        this.editor.changeViewZones(changeAccessor -> {
            if (this._viewZoneId != null) {
                changeAccessor.removeZone(this._viewZoneId);
                this._viewZoneId = null;
            }
        });
    }

    function updateLines(lineNumber:Int, additionalLines:Array<LineData>, minReservedLineCount:Int):Void {
        final textModel = this.editor.getModel();
        if (textModel == null) {
            return;
        }

        final tabSize = textModel.getOptions().tabSize;

        this.editor.changeViewZones(changeAccessor -> {
            if (this._viewZoneId != null) {
                changeAccessor.removeZone(this._viewZoneId);
                this._viewZoneId = null;
            }

            final heightInLines = Std.int(Math.max(additionalLines.length, minReservedLineCount));
            if (heightInLines > 0) {
                this.lines = additionalLines;
                this._viewZoneId = changeAccessor.addZone({
                    afterLineNumber: lineNumber,
                    heightInLines: heightInLines,
                    paint: renderLines(this.editor, tabSize, additionalLines),
                    afterColumnAffinity: PositionAffinity.Right
                });
            }
            else {
                this.lines = null;
            }
        });
    }

    /**
     * Monaco's `renderLines`, as a zone painter. The shaped lines are kept
     * while the fonts, the font size and the theme stay the same (no
     * allocation per frame).
     */
    static function renderLines(editor:ICodeEditor, tabSize:Int, lines:Array<LineData>):ViewZonePainter {
        final rendered = new RenderedGhostLines(tabSize, lines);
        return (window, cx, bounds) -> {
            final widget = Std.downcast(editor, cityscape.view.widget.codeEditor.CodeEditorWidget);
            final view:Null<CityscapeView> = widget != null ? Std.downcast(widget.getView(), CityscapeView) : null;
            if (view == null) {
                return;
            }
            final lineHeight:Float = editor.getOption(EditorOption.lineHeight);
            rendered.update(view, cx);
            final painter = window.textPainter();
            final x = bounds.origin.x - editor.getScrollLeft();
            for (i in 0...rendered.layouts.length) {
                final layout = rendered.layouts[i];
                if (layout == null) {
                    continue;
                }
                glaze.LinePaint.paintLineAligned(new glaze.Point(x, bounds.origin.y + i * lineHeight), layout, lineHeight, glaze.TextAlign.Left, layout.width, rendered.decorationRuns[i], null, painter, null);
            }
        };
    }

}

/**
 * The shaped additional lines of a ghost text: the `ghost-text` parts in
 * `editorGhostText.foreground` and italic (ghostTextView.css), the other
 * text in `editor.foreground`, tabs expanded (Monaco renders with
 * `renderWhitespace: 'none'`).
 */
private class RenderedGhostLines {

    final tabSize:Int;
    final lines:Array<LineData>;

    public final layouts:Array<Null<glaze.LineLayout>> = [];
    public final decorationRuns:Array<Array<glaze.DecorationRun>> = [];

    var fontGeneration:Int = -1;
    var themeVersion:Int = -1;
    var fontSize:Float = -1;
    var fontInfoKey:Null<cityscape.common.config.FontInfo> = null;

    public function new(tabSize:Int, lines:Array<LineData>) {
        this.tabSize = tabSize;
        this.lines = lines;
    }

    public function update(view:CityscapeView, cx:glaze.App):Void {
        final textSystem = cx.textSystem();
        final info = view.fontInfo();
        if (fontGeneration == textSystem.fontGeneration && themeVersion == view.theme.version && fontInfoKey == info) {
            return;
        }
        fontGeneration = textSystem.fontGeneration;
        themeVersion = view.theme.version;
        fontInfoKey = info;
        fontSize = info.fontSize;
        layouts.resize(0);
        decorationRuns.resize(0);

        final ghostColor = view.theme.getColor('editorGhostText.foreground');
        final textColor = view.theme.getColor('editor.foreground');
        final fallback = new glaze.Hsla(0, 0, 0.5, 1);
        final normalFont = textSystem.resolveFont(view.baseFont(null, false, null));
        final italicFont = textSystem.resolveFont(view.baseFont(null, true, null));

        for (lineData in lines) {
            final text = new StringBuf();
            final fontRuns:Array<glaze.FontRun> = [];
            final runs:Array<glaze.DecorationRun> = [];
            var visibleColumn = 0;
            var segmentBytes = 0;
            var segmentGhost = false;
            final content = lineData.content;
            function flush(nextGhost:Bool):Void {
                if (segmentBytes > 0) {
                    fontRuns.push(new glaze.FontRun(segmentBytes, segmentGhost ? italicFont : normalFont));
                    final color = segmentGhost ? ghostColor : textColor;
                    runs.push(new glaze.DecorationRun(segmentBytes, color != null ? color : fallback));
                }
                segmentBytes = 0;
                segmentGhost = nextGhost;
            }
            var c = 0;
            while (c < content.length) {
                final column = c + 1;
                var isGhost = false;
                for (d in lineData.decorations) {
                    if (column >= d.startColumn && column < d.endColumn) {
                        isGhost = true;
                        break;
                    }
                }
                if (isGhost != segmentGhost) {
                    flush(isGhost);
                }
                final code = StringTools.fastCodeAt(content, c);
                var piece:String;
                if (code == '\t'.code) {
                    final insertSpacesCount = tabSize - (visibleColumn % tabSize);
                    piece = StringTools.lpad('', ' ', insertSpacesCount);
                    visibleColumn += insertSpacesCount;
                    c++;
                }
                else if (cityscape.base.common.Strings.isHighSurrogate(code) && c + 1 < content.length) {
                    piece = content.substr(c, 2);
                    visibleColumn++;
                    c += 2;
                }
                else {
                    piece = content.charAt(c);
                    visibleColumn++;
                    c++;
                }
                text.add(piece);
                segmentBytes += glaze.util.Utf8.byteLength(piece);
            }
            flush(false);
            final str = text.toString();
            if (str.length == 0 || fontRuns.length == 0) {
                layouts.push(null);
                decorationRuns.push(runs);
                continue;
            }
            layouts.push(textSystem.platformTextSystem.layoutLine(str, fontSize, fontRuns));
            decorationRuns.push(runs);
        }
    }

}
