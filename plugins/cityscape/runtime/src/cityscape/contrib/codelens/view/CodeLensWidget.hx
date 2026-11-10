// Ported from vscode src/vs/editor/contrib/codelens/browser/codelensWidget.ts
// (and the look of codelensWidget.css)
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.codelens.view;

import cityscape.common.Languages.CodeLens;
import cityscape.common.Languages.Command;
import cityscape.common.Model;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Range;
import cityscape.common.model.TextModel.ModelDecorationOptions;
import cityscape.contrib.codelens.view.CodeLensModel;
import cityscape.view.Codicons;
import cityscape.view.EditorBrowser;
import cityscape.view.EditorWidgets;
import glaze.Hsla;
import glaze.Point;

/**
 * What the lenses of an editor paint with (the CSS variables Monaco's
 * `CodeLensContribution._updateLensStyle` sets on the editor), and the
 * link under the mouse (`a:hover`). One per contribution, shared by its
 * widgets.
 */
class CodeLensPaintStyle {

    /**
     * `--vscode-editorCodeLens-fontSize`.
     */
    public var fontSize:Float = 12;
    /**
     * `--vscode-editorCodeLens-lineHeight` (the height of the zones).
     */
    public var lineHeight:Float = 16;
    /**
     * The `codeLensFontFamily` option (empty: the font of the editor's
     * chrome, the UI font, like Monaco's `.monaco-editor` font family).
     */
    public var fontFamily:String = '';
    /**
     * The id of the link under the mouse (`a:hover`), or null.
     */
    public var hoveredLinkId:Null<String> = null;

    public function new() {}

}

/**
 * A part of the lenses of a line: a text or a `$(name)` codicon of a lens
 * title (part of a link when its command has an id), or the ` | `
 * separator.
 */
class CodeLensSegment {

    /**
     * The text (empty for a codicon).
     */
    public final text:String;
    /**
     * The codicon id of a `$(name)` of the title, null for a text.
     */
    public final icon:Null<String>;
    /**
     * The id of the link (the command of the lens), null for plain text.
     */
    public final linkId:Null<String>;
    public final tooltip:Null<String>;
    /**
     * The x of the segment from the start of the lenses, and its width
     * (measured when painted, estimated before).
     */
    public var x:Float = 0;
    public var width:Float = 0;

    public function new(text:String, linkId:Null<String>, tooltip:Null<String>, ?icon:String) {
        this.text = text;
        this.linkId = linkId;
        this.tooltip = tooltip;
        this.icon = icon;
    }

}

class CodeLensViewZone {

    public final suppressMouseDown:Bool;

    public var afterLineNumber:Int;
    /**
     * We want that this view zone, which reserves space for a code lens appears
     * as close as possible to the next line, so we use a very large value here.
     */
    public final afterColumn:Int = Constants.MAX_SAFE_SMALL_INTEGER;
    public var heightInPx:Float;

    var _lastHeight:Null<Float> = null;
    final _onHeight:() -> Void;

    /**
     * The view zone given to the editor (Monaco passes this object; its
     * `domNode` is `paint` here).
     */
    public final zone:IViewZone;

    public function new(afterLineNumber:Int, heightInPx:Float, onHeight:() -> Void, paint:ViewZonePainter) {
        this.afterLineNumber = afterLineNumber;
        this.heightInPx = heightInPx;

        this._onHeight = onHeight;
        this.suppressMouseDown = true;
        final self = this;
        this.zone = {
            afterLineNumber: afterLineNumber,
            afterColumn: afterColumn,
            heightInPx: heightInPx,
            suppressMouseDown: true,
            paint: paint,
            onComputedHeight: height -> self.onComputedHeight(height)
        };
    }

    /**
     * Writes the position and height into the zone given to the editor
     * (Monaco's zone is this object).
     */
    public function sync():Void {
        zone.afterLineNumber = afterLineNumber;
        zone.heightInPx = heightInPx;
    }

    public function onComputedHeight(height:Float):Void {
        if (this._lastHeight == null) {
            this._lastHeight = height;
        } else if (this._lastHeight != height) {
            this._lastHeight = height;
            this._onHeight();
        }
    }

    /**
     * Monaco's `isVisible`: the zone has a height and is in the viewport
     * (Monaco's `monaco-visible-view-zone` attribute, set on the zones the
     * view renders): here, the line below the zone is in the visible ranges
     * of the editor.
     */
    public function isVisible(editor:ICodeEditor):Bool {
        if (this._lastHeight == 0) {
            return false;
        }
        final lineNumber = this.afterLineNumber + 1;
        for (range in editor.getVisibleRanges()) {
            if (range.startLineNumber <= lineNumber && lineNumber <= range.endLineNumber) {
                return true;
            }
        }
        return false;
    }

}

/**
 * The lenses of a line (Monaco's `CodeLensContentWidget`, a content widget
 * above the line): painted in the view zone of the line at the column of
 * its first non whitespace character, in `editorCodeLens.foreground`, the
 * links in `editorLink.activeForeground` under the mouse.
 */
class CodeLensContentWidget {

    static var _idPool:Int = 0;

    final _id:String;
    final _editor:ICodeEditor;
    final _commands = new Map<String, Command>();

    var _lineNumber:Int = 1;
    var _column:Int = 1;
    var _isEmpty:Bool = true;

    /**
     * The texts painted (Monaco's child nodes).
     */
    public final segments:Array<CodeLensSegment> = [];

    /**
     * The window x where the texts were last painted, null before.
     */
    var _paintedLeft:Null<Float> = null;
    var _measuredFontSize:Float = -1;

    public function new(editor:ICodeEditor, line:Int) {
        this._editor = editor;
        this._id = 'codelens.widget-${(CodeLensContentWidget._idPool++)}';

        this.updatePosition(line);
    }

    public function withCommands(lenses:Array<Null<CodeLens>>, animate:Bool):Void {
        this._commands.clear();
        this.segments.resize(0);
        this._measuredFontSize = -1;

        var hasSymbol = false;
        for (i in 0...lenses.length) {
            final lens = lenses[i];
            if (lens == null) {
                continue;
            }
            hasSymbol = true;
            if (lens.command != null) {
                // renderLabelWithIcons: texts and codicons
                final title = Codicons.parseLabelWithIcons(StringTools.trim(lens.command.title));
                var linkId:Null<String> = null;
                if (lens.command.id != null && lens.command.id.length > 0) {
                    linkId = 'c${(CodeLensContentWidget._idPool++)}';
                    this._commands.set(linkId, lens.command);
                }
                for (part in title) {
                    switch part {
                        case LabelText(text):
                            this.segments.push(new CodeLensSegment(text, linkId, lens.command.tooltip));
                        case LabelIcon(icon):
                            this.segments.push(new CodeLensSegment('', linkId, lens.command.tooltip, icon));
                    }
                }
                if (i + 1 < lenses.length) {
                    this.segments.push(new CodeLensSegment('\u00a0|\u00a0', null, null));
                }
            }
        }

        if (!hasSymbol) {
            // symbols but no commands
            this.segments.resize(0);
            this.segments.push(new CodeLensSegment('no commands', null, null));

        } else {
            // symbols and commands (Monaco fades the lenses in: not ported)
            this._isEmpty = false;
        }
    }

    /**
     * The command of a link id (Monaco's `getCommand(link)`).
     */
    public function getCommand(linkId:String):Null<Command> {
        return this._commands.get(linkId);
    }

    public function getId():String {
        return this._id;
    }

    public function updatePosition(line:Int):Void {
        final column = this._editor.getModel().getLineFirstNonWhitespaceColumn(line);
        this._lineNumber = line;
        this._column = column;
    }

    /**
     * The window x of the start of the lenses: where they were painted, else
     * computed from the editor's layout (an editor without view).
     */
    function lensesLeft(style:CodeLensPaintStyle):Float {
        final painted = this._paintedLeft;
        if (painted != null) {
            return painted;
        }
        final layoutInfo = this._editor.getLayoutInfo();
        var offset = this._editor.getOffsetForColumn(this._lineNumber, this._column);
        if (offset < 0) {
            final column = this._column > 0 ? this._column : 1;
            offset = (column - 1) * this._editor.getOption(EditorOption.fontInfo).typicalHalfwidthCharacterWidth;
        }
        return layoutInfo.contentLeft + offset - this._editor.getScrollLeft();
    }

    /**
     * The x and width of the segments when they were not measured yet (an
     * editor without view): the typical character width of the editor's
     * font at the lenses' size.
     */
    function estimateSegments(style:CodeLensPaintStyle):Void {
        if (this._measuredFontSize == style.fontSize) {
            return;
        }
        final fontInfo = this._editor.getOption(EditorOption.fontInfo);
        final charWidth = fontInfo.typicalHalfwidthCharacterWidth * style.fontSize / fontInfo.fontSize;
        var x = 0.0;
        for (segment in this.segments) {
            segment.x = x;
            // a codicon is one em wide
            segment.width = segment.icon != null ? (cityscape.view.CodiconOutlines.pathOf(segment.icon) != null ? style.fontSize : 0) : segment.text.length * charWidth;
            x += segment.width;
        }
        this._measuredFontSize = style.fontSize;
    }

    /**
     * The link segment at window x `posx`, or null.
     */
    public function linkAt(posx:Float, style:CodeLensPaintStyle):Null<CodeLensSegment> {
        estimateSegments(style);
        final x = posx - lensesLeft(style);
        for (segment in this.segments) {
            if (segment.linkId != null && x >= segment.x && x < segment.x + segment.width) {
                return segment;
            }
        }
        return null;
    }

    /**
     * Paints the lenses in the zone (`bounds`, window coordinates).
     */
    public function paint(window:glaze.Window, cx:glaze.App, bounds:glaze.Bounds, style:CodeLensPaintStyle):Void {
        if (this.segments.length == 0) {
            return;
        }
        final editor = this._editor;
        final foreground = EditorWidgets.color(editor, 'editorCodeLens.foreground', new Hsla(0, 0, 0.6, 1));
        final linkForeground = EditorWidgets.color(editor, 'editorLink.activeForeground', foreground);
        var family = style.fontFamily;
        if (family.length == 0) {
            family = '.SystemUIFont';
            try {
                family = glaze.kit.theme.Theme.global(cx).fontFamily;
            }
            catch (e:Dynamic) {}
        } else {
            final view = EditorWidgets.viewOf(editor);
            if (view != null) {
                family = view.measurements.resolveEditorFont(family, glaze.FontWeight.NORMAL, false, glaze.FontFeatures.defaultValue()).family;
            }
        }
        final font = new glaze.Font(family);
        final textSystem = window.textSystem();
        final offset = editor.getOffsetForColumn(this._lineNumber, this._column);
        final left = bounds.origin.x + (offset > 0 ? offset : 0) - editor.getScrollLeft();
        this._paintedLeft = left;
        // `vertical-align: sub` in a line of `lineHeight`: the text sits a
        // little below the middle of the zone
        final top = bounds.origin.y + (bounds.size.height - style.lineHeight) / 2 + 1;
        // the codicons: `vertical-align: middle` (the middle of their em square
        // half the x-height above the baseline of the text), the font size of
        // the lenses
        final metrics = textSystem.textSystem;
        final fontId = metrics.resolveFont(font);
        // the baseline of the texts as `ShapedLine.paint` places it
        final reference = textSystem.shapeLine('x', style.fontSize, [new glaze.TextRun(1, font, foreground)]);
        final ascent:Float = reference.layout.ascent;
        final descent:Float = reference.layout.descent;
        final baselineOffset:Float = (style.lineHeight - ascent - descent) / 2 + ascent;
        // the x-height of the font (its OS/2 value, else the height of `x`)
        var xHeight:Float = metrics.xHeight(fontId, style.fontSize);
        if (!(xHeight > 0)) {
            final bounds = metrics.typographicBounds(fontId, style.fontSize, 'x'.code);
            xHeight = Math.abs((bounds.size.height : Float));
        }
        if (!(xHeight > 0) || xHeight > style.fontSize) {
            xHeight = style.fontSize / 2;
        }
        final iconBaseline = top + baselineOffset - xHeight / 2 + style.fontSize / 2;
        var x = 0.0;
        for (segment in this.segments) {
            final color = segment.linkId != null && segment.linkId == style.hoveredLinkId ? linkForeground : foreground;
            if (segment.icon != null) {
                // a codicon without outline here is not drawn and takes no room
                final painted = Codicons.paintCodicon(window, cx, segment.icon, left + x, iconBaseline, style.fontSize, color);
                segment.x = x;
                segment.width = painted ? style.fontSize : 0;
                x += segment.width;
                continue;
            }
            final text = segment.text.split('\u00a0').join(' ');
            final shaped = textSystem.shapeLine(text, style.fontSize, [new glaze.TextRun(glaze.util.Utf8.byteLength(text), font, color)]);
            shaped.paint(new Point(left + x, top), style.lineHeight, glaze.TextAlign.Left, null, window.textPainter());
            segment.x = x;
            segment.width = shaped.layout.width;
            x += shaped.layout.width;
        }
        this._measuredFontSize = style.fontSize;
    }

}

typedef IDecorationIdCallback = (decorationId:String) -> Void;

class CodeLensHelper {

    final _removeDecorations:Array<String>;
    final _addDecorations:Array<IModelDeltaDecoration>;
    final _addDecorationsCallbacks:Array<IDecorationIdCallback>;

    public function new() {
        this._removeDecorations = [];
        this._addDecorations = [];
        this._addDecorationsCallbacks = [];
    }

    public function addDecoration(decoration:IModelDeltaDecoration, callback:IDecorationIdCallback):Void {
        this._addDecorations.push(decoration);
        this._addDecorationsCallbacks.push(callback);
    }

    public function removeDecoration(decorationId:String):Void {
        this._removeDecorations.push(decorationId);
    }

    public function commit(changeAccessor:IModelDecorationsChangeAccessor):Void {
        final resultingDecorations = changeAccessor.deltaDecorations(this._removeDecorations, this._addDecorations);
        for (i in 0...resultingDecorations.length) {
            this._addDecorationsCallbacks[i](resultingDecorations[i]);
        }
    }

}

/**
 * The lenses of a line: their decorations (tracking the lens ranges), the
 * view zone above the line and the lenses painted in it.
 */
class CodeLensWidget {

    static var _codeLensDecorationOptions:Null<ModelDecorationOptions> = null;

    static function codeLensDecorationOptions():IModelDecorationOptions {
        if (_codeLensDecorationOptions == null) {
            _codeLensDecorationOptions = ModelDecorationOptions.register({
                collapseOnReplaceEdit: true,
                description: 'codelens'
            });
        }
        return cast _codeLensDecorationOptions;
    }

    final _editor:ICodeEditor;
    final _viewZone:CodeLensViewZone;
    final _viewZoneId:String;
    final _style:CodeLensPaintStyle;

    var _contentWidget:Null<CodeLensContentWidget> = null;
    var _decorationIds:Array<String>;
    var _data:Array<CodeLensItem>;
    var _isDisposed:Bool = false;

    public function new(data:Array<CodeLensItem>, editor:ICodeEditor, helper:CodeLensHelper, viewZoneChangeAccessor:IViewZoneChangeAccessor, heightInPx:Float, updateCallback:() -> Void, style:CodeLensPaintStyle) {
        this._editor = editor;
        this._data = data;
        this._style = style;

        // create combined range, track all ranges with decorations,
        // check if there is already something to render
        this._decorationIds = [];
        var range:Null<Range> = null;
        final lenses:Array<Null<CodeLens>> = [];

        for (i in 0...this._data.length) {
            final codeLensData = this._data[i];

            if (codeLensData.symbol.command != null) {
                lenses.push(codeLensData.symbol);
            }

            final index = i;
            helper.addDecoration({
                range: codeLensData.symbol.range,
                options: codeLensDecorationOptions()
            }, id -> this._decorationIds[index] = id);

            // the range contains all lenses on this line
            if (range == null) {
                range = Range.lift(codeLensData.symbol.range);
            } else {
                range = Range.plusRangeStatic(range, codeLensData.symbol.range);
            }
        }

        this._viewZone = new CodeLensViewZone(range.startLineNumber - 1, heightInPx, updateCallback, (window, cx, bounds) -> {
            final widget = this._contentWidget;
            if (widget != null) {
                widget.paint(window, cx, bounds, this._style);
            }
        });
        this._viewZoneId = viewZoneChangeAccessor.addZone(this._viewZone.zone);

        if (lenses.length > 0) {
            this._createContentWidgetIfNecessary();
            this._contentWidget.withCommands(lenses, false);
        }
    }

    function _createContentWidgetIfNecessary():Void {
        if (this._contentWidget == null) {
            this._contentWidget = new CodeLensContentWidget(this._editor, this._viewZone.afterLineNumber + 1);
        }
        this._editor.render();
    }

    public function dispose(helper:CodeLensHelper, ?viewZoneChangeAccessor:IViewZoneChangeAccessor):Void {
        for (id in this._decorationIds) {
            helper.removeDecoration(id);
        }
        this._decorationIds = [];
        if (viewZoneChangeAccessor != null) {
            viewZoneChangeAccessor.removeZone(this._viewZoneId);
        }
        this._contentWidget = null;
        this._isDisposed = true;
    }

    public function isDisposed():Bool {
        return this._isDisposed;
    }

    public function isValid():Bool {
        final model = this._editor.getModel();
        for (i in 0...this._decorationIds.length) {
            final range = model.getDecorationRange(this._decorationIds[i]);
            final symbol = this._data[i].symbol;
            if (range != null && Range.isEmptyStatic(symbol.range) == range.isEmpty()) {
                return true;
            }
        }
        return false;
    }

    public function updateCodeLensSymbols(data:Array<CodeLensItem>, helper:CodeLensHelper):Void {
        for (id in this._decorationIds) {
            helper.removeDecoration(id);
        }
        this._decorationIds = [];
        this._data = data;
        for (i in 0...this._data.length) {
            final codeLensData = this._data[i];
            final index = i;
            helper.addDecoration({
                range: codeLensData.symbol.range,
                options: codeLensDecorationOptions()
            }, id -> this._decorationIds[index] = id);
        }
    }

    public function updateHeight(height:Float, viewZoneChangeAccessor:IViewZoneChangeAccessor):Void {
        this._viewZone.heightInPx = height;
        this._viewZone.sync();
        viewZoneChangeAccessor.layoutZone(this._viewZoneId);
    }

    public function computeIfNecessary(model:ITextModel):Null<Array<CodeLensItem>> {
        if (!this._viewZone.isVisible(this._editor)) {
            return null;
        }

        // Read editor current state
        for (i in 0...this._decorationIds.length) {
            final range = model.getDecorationRange(this._decorationIds[i]);
            if (range != null) {
                this._data[i].symbol.range = range;
            }
        }
        return this._data;
    }

    public function updateCommands(symbols:Array<Null<CodeLens>>):Void {

        this._createContentWidgetIfNecessary();
        this._contentWidget.withCommands(symbols, true);

        for (i in 0...this._data.length) {
            final resolved = symbols[i];
            if (resolved != null) {
                final symbol = this._data[i].symbol;
                symbol.command = resolved.command != null ? resolved.command : symbol.command;
            }
        }
    }

    /**
     * The command of a link id of this widget (Monaco's `getCommand(link)`).
     */
    public function getCommand(linkId:String):Null<Command> {
        final widget = this._contentWidget;
        return widget != null ? widget.getCommand(linkId) : null;
    }

    public function getLineNumber():Int {
        final range = this._editor.getModel().getDecorationRange(this._decorationIds[0]);
        if (range != null) {
            return range.startLineNumber;
        }
        return -1;
    }

    public function update(viewZoneChangeAccessor:IViewZoneChangeAccessor):Void {
        if (this.isValid()) {
            final range = this._editor.getModel().getDecorationRange(this._decorationIds[0]);
            if (range != null) {
                this._viewZone.afterLineNumber = range.startLineNumber - 1;
                this._viewZone.sync();
                viewZoneChangeAccessor.layoutZone(this._viewZoneId);

                if (this._contentWidget != null) {
                    this._contentWidget.updatePosition(range.startLineNumber);
                }
            }
        }
    }

    public function getItems():Array<CodeLensItem> {
        return this._data;
    }

    /**
     * The id of the view zone of the widget.
     */
    public function getViewZoneId():String {
        return this._viewZoneId;
    }

    /**
     * The painted lenses (null before the first lens with a command).
     */
    public function getContentWidget():Null<CodeLensContentWidget> {
        return this._contentWidget;
    }

    /**
     * The view zone of the widget.
     */
    public function getViewZone():CodeLensViewZone {
        return this._viewZone;
    }

}

private class Constants {
    public static inline final MAX_SAFE_SMALL_INTEGER = 1073741824;
}
