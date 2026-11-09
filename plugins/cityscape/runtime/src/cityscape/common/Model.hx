// Ported from vscode src/vs/editor/common/model.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common;

import cityscape.base.common.Event;
import cityscape.base.common.HtmlContent.IMarkdownString;
import cityscape.base.common.Lifecycle.IDisposable;
import cityscape.base.common.RegExp;
import cityscape.base.common.Themables.ThemeColor;
import cityscape.base.common.Uri;
import cityscape.common.Languages.FormattingOptions;
import cityscape.common.TextModelBracketPairs.IBracketPairsTextModelPart;
import cityscape.common.TextModelEvents;
import cityscape.common.TextModelGuides.IGuidesTextModelPart;
import cityscape.common.TokenizationTextModelPart.ITokenizationTextModelPart;
import cityscape.common.core.EditOperation.ISingleEditOperation;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.core.TextChange;
import cityscape.common.core.WordCharacterClassifier;
import cityscape.common.core.WordHelper.IWordAtPosition;
import cityscape.common.languages.Language.ILanguageSelection;
import cityscape.platform.undoRedo.common.UndoRedo.UndoRedoGroup;
import haxe.extern.EitherType;

/**
 * Vertical Lane in the overview ruler of the editor.
 */
enum abstract OverviewRulerLane(Int) from Int to Int {
    var Left = 1;
    var Center = 2;
    var Right = 4;
    var Full = 7;
}

/**
 * Vertical Lane in the glyph margin of the editor.
 */
enum abstract GlyphMarginLane(Int) from Int to Int {
    var Left = 1;
    var Center = 2;
    var Right = 3;
}

interface IGlyphMarginLanesModel {
    /**
     * The number of lanes that should be rendered in the editor.
     */
    var requiredLanes(get, never):Int;

    /**
     * Gets the lanes that should be rendered starting at a given line number.
     */
    function getLanesAtLine(lineNumber:Int):Array<GlyphMarginLane>;

    /**
     * Resets the model and ensures it can contain at least `maxLine` lines.
     */
    function reset(maxLine:Int):Void;

    /**
     * Registers that a lane should be visible at the Range in the model.
     * @param persist - if true, notes that the lane should always be visible,
     * even on lines where there's no specific request for that lane.
     */
    function push(lane:GlyphMarginLane, range:Range, ?persist:Bool):Void;
}

/**
 * Position in the minimap to render the decoration.
 */
enum abstract MinimapPosition(Int) from Int to Int {
    var Inline = 1;
    var Gutter = 2;
}

/**
 * Section header style.
 */
enum abstract MinimapSectionHeaderStyle(Int) from Int to Int {
    var Normal = 1;
    var Underlined = 2;
}

/**
 * A color of a decoration: a CSS-like color string (`#rrggbb`...) or a
 * theme color key (`ThemeColor`).
 */
typedef DecorationColor = EitherType<String, ThemeColor>;

typedef IDecorationOptions = {
    /**
     * CSS color to render.
     * e.g.: rgba(100, 100, 100, 0.5) or a color from the color registry
     */
    var color:Null<DecorationColor>;
    /**
     * CSS color to render.
     * e.g.: rgba(100, 100, 100, 0.5) or a color from the color registry
     */
    @:optional var darkColor:DecorationColor;
}

typedef IModelDecorationGlyphMarginOptions = {
    /**
     * The position in the glyph margin.
     */
    var position:GlyphMarginLane;

    /**
     * Whether the glyph margin lane in {@link position} should be rendered even
     * outside of this decoration's range.
     */
    @:optional var persistLane:Bool;
}

/**
 * Options for rendering a model decoration in the overview ruler.
 */
typedef IModelDecorationOverviewRulerOptions = IDecorationOptions & {
    /**
     * The position in the overview ruler.
     */
    var position:OverviewRulerLane;
}

/**
 * Options for rendering a model decoration in the minimap. Cityscape has no
 * minimap: the type is kept so that Monaco decoration options pass as they
 * are.
 */
typedef IModelDecorationMinimapOptions = IDecorationOptions & {
    /**
     * The position in the minimap.
     */
    var position:MinimapPosition;
    /**
     * If the decoration is for a section header, which header style.
     */
    @:optional var sectionHeaderStyle:Null<MinimapSectionHeaderStyle>;
    /**
     * If the decoration is for a section header, the header text.
     */
    @:optional var sectionHeaderText:Null<String>;
}

/**
 * A hover message: one markdown string or several.
 */
typedef HoverMessage = EitherType<IMarkdownString, Array<IMarkdownString>>;

/**
 * Options for a model decoration.
 *
 * Cityscape adds a typed decoration style (`IDecorationStyle`, see
 * `DecorationStyle.hx`) next to Monaco's class names: `inlineStyle` (text
 * and inline boxes, like `inlineClassName`), `style` (boxes behind the
 * text, like `className`), `lineStyle` (whole line background, like a
 * `className` with `isWholeLine`), `glyphMarginStyle`,
 * `linesDecorationsStyle`, `lineNumberStyle` and `marginStyle`, plus hidden
 * ranges (`hidden`, `replacement`, `revealOnCursorLine`). The class names
 * stay accepted: a class name registered with
 * `DecorationStyles.registerDecorationStyle` gives its style. These fields
 * are Cityscape additions (docs/DEVIATIONS.md, "Typed decoration style" and
 * "Hidden text inside a line").
 */
typedef IModelDecorationOptions = {
    /**
     * A debug description that can be used for inspecting model decorations.
     * @internal
     */
    var description:String;
    /**
     * Customize the growing behavior of the decoration when typing at the edges of the decoration.
     * Defaults to TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges
     */
    @:optional var stickiness:TrackedRangeStickiness;
    /**
     * CSS class name describing the decoration.
     */
    @:optional var className:Null<String>;
    /**
     * Indicates whether the decoration should span across the entire line when it continues onto the next line.
     */
    @:optional var shouldFillLineOnLineBreak:Null<Bool>;
    @:optional var blockClassName:Null<String>;
    /**
     * Indicates if this block should be rendered after the last line.
     * In this case, the range must be empty and set to the last line.
     */
    @:optional var blockIsAfterEnd:Null<Bool>;
    @:optional var blockDoesNotCollapse:Null<Bool>;
    /**
     * Padding of the block: top, right, bottom, left.
     */
    @:optional var blockPadding:Null<Array<Float>>;
    /**
     * Message to be rendered when hovering over the glyph margin decoration.
     */
    @:optional var glyphMarginHoverMessage:Null<HoverMessage>;
    /**
     * Array of MarkdownString to render as the decoration message.
     */
    @:optional var hoverMessage:Null<HoverMessage>;
    /**
     * Array of MarkdownString to render as the line number message.
     */
    @:optional var lineNumberHoverMessage:Null<HoverMessage>;
    /**
     * Should the decoration expand to encompass a whole line.
     */
    @:optional var isWholeLine:Bool;
    /**
     * Always render the decoration (even when the range it encompasses is collapsed).
     */
    @:optional var showIfCollapsed:Bool;
    /**
     * Collapse the decoration if its entire range is being replaced via an edit.
     * @internal
     */
    @:optional var collapseOnReplaceEdit:Bool;
    /**
     * Specifies the stack order of a decoration.
     * A decoration with greater stack order is always in front of a decoration with
     * a lower stack order when the decorations are on the same line.
     */
    @:optional var zIndex:Float;
    /**
     * If set, render this decoration in the overview ruler.
     */
    @:optional var overviewRuler:Null<IModelDecorationOverviewRulerOptions>;
    /**
     * If set, render this decoration in the minimap (no minimap in Cityscape).
     */
    @:optional var minimap:Null<IModelDecorationMinimapOptions>;
    /**
     * If set, the decoration will be rendered in the glyph margin with this CSS class name.
     */
    @:optional var glyphMarginClassName:Null<String>;
    /**
     * If set and the decoration has {@link glyphMarginClassName} set, render this decoration
     * with the specified {@link IModelDecorationGlyphMarginOptions} in the glyph margin.
     */
    @:optional var glyphMargin:Null<IModelDecorationGlyphMarginOptions>;
    /**
     * If set, the decoration will be rendered in the lines decorations with this CSS class name.
     */
    @:optional var linesDecorationsClassName:Null<String>;
    /**
     * Controls the tooltip text of the line decoration.
     */
    @:optional var linesDecorationsTooltip:Null<String>;
    /**
     * If set, the decoration will be rendered on the line number.
     */
    @:optional var lineNumberClassName:Null<String>;
    /**
     * If set, the decoration will be rendered in the lines decorations with this CSS class name, but only for the first line in case of line wrapping.
     */
    @:optional var firstLineDecorationClassName:Null<String>;
    /**
     * If set, the decoration will be rendered in the margin (covering its full width) with this CSS class name.
     */
    @:optional var marginClassName:Null<String>;
    /**
     * If set, the decoration will be rendered inline with the text with this CSS class name.
     * Please use this only for CSS rules that must impact the text. For example, use `className`
     * to have a background color decoration.
     */
    @:optional var inlineClassName:Null<String>;
    /**
     * If there is an `inlineClassName` which affects letter spacing.
     */
    @:optional var inlineClassNameAffectsLetterSpacing:Bool;
    /**
     * If set, the decoration will be rendered before the text with this CSS class name.
     */
    @:optional var beforeContentClassName:Null<String>;
    /**
     * If set, the decoration will be rendered after the text with this CSS class name.
     */
    @:optional var afterContentClassName:Null<String>;
    /**
     * If set, text will be injected in the view after the range.
     */
    @:optional var after:Null<InjectedTextOptions>;
    /**
     * If set, text will be injected in the view before the range.
     */
    @:optional var before:Null<InjectedTextOptions>;
    /**
     * If set, this decoration will not be rendered for comment tokens.
     * @internal
     */
    @:optional var hideInCommentTokens:Null<Bool>;
    /**
     * If set, this decoration will not be rendered for string tokens.
     * @internal
     */
    @:optional var hideInStringTokens:Null<Bool>;

    // Cityscape additions (typed decoration style, hidden ranges)

    /**
     * Typed style of the text of the range (Cityscape): what Monaco does with
     * an `inlineClassName`. Applied after the style registered for
     * `inlineClassName`, if any.
     */
    @:optional var inlineStyle:Null<cityscape.common.DecorationStyle.IDecorationStyle>;
    /**
     * Typed style of a box drawn behind the text of the range (Cityscape):
     * what Monaco does with a `className` (background, border, radius).
     * Applied after the style registered for `className`, if any.
     */
    @:optional var style:Null<cityscape.common.DecorationStyle.IDecorationStyle>;
    /**
     * Typed style of the whole lines of the range (Cityscape): background
     * and border of the line, like a `className` with `isWholeLine`.
     */
    @:optional var lineStyle:Null<cityscape.common.DecorationStyle.IDecorationStyle>;
    /**
     * Typed style of the glyph margin (Cityscape), like `glyphMarginClassName`.
     */
    @:optional var glyphMarginStyle:Null<cityscape.common.DecorationStyle.IDecorationStyle>;
    /**
     * Typed style of the lines decorations (Cityscape), like `linesDecorationsClassName`.
     */
    @:optional var linesDecorationsStyle:Null<cityscape.common.DecorationStyle.IDecorationStyle>;
    /**
     * Typed style of the line number (Cityscape), like `lineNumberClassName`.
     */
    @:optional var lineNumberStyle:Null<cityscape.common.DecorationStyle.IDecorationStyle>;
    /**
     * Typed style of the whole margin (Cityscape), like `marginClassName`.
     */
    @:optional var marginStyle:Null<cityscape.common.DecorationStyle.IDecorationStyle>;
    /**
     * Hide the text of the range (Cityscape): it is not laid out nor painted,
     * the cursor skips it. Ranges are taken one line at a time (a range
     * spanning lines hides the end of its first line, the full lines between
     * and the start of its last line).
     */
    @:optional var hidden:Null<Bool>;
    /**
     * Hide the text of the range and show this injected text instead
     * (Cityscape), for example a symbol standing for the hidden text.
     */
    @:optional var replacement:Null<InjectedTextOptions>;
    /**
     * With `hidden` or `replacement`: show the text again on the lines that
     * hold a cursor or a selection of the editor (Cityscape).
     */
    @:optional var revealOnCursorLine:Null<Bool>;
}

/**
 * Configures text that is injected into the view without changing the underlying document.
 */
typedef InjectedTextOptions = {
    /**
     * Sets the text to inject. Must be a single line.
     */
    final content:String;
    /**
     * If set, the decoration will be rendered inline with the text with this CSS class name.
     */
    @:optional final inlineClassName:Null<String>;
    /**
     * If there is an `inlineClassName` which affects letter spacing.
     */
    @:optional final inlineClassNameAffectsLetterSpacing:Bool;
    /**
     * This field allows to attach data to this injected text.
     * The data can be read when injected texts at a given position are queried.
     */
    @:optional final attachedData:Any;
    /**
     * Configures cursor stops around injected text.
     * Defaults to {@link InjectedTextCursorStops.Both}.
     */
    @:optional final cursorStops:Null<InjectedTextCursorStops>;
    /**
     * Typed style of the injected text (Cityscape), applied after the style
     * registered for `inlineClassName`, if any.
     */
    @:optional final inlineStyle:Null<cityscape.common.DecorationStyle.IDecorationStyle>;
    /**
     * The number of UTF-16 code units of the model line this injected text
     * replaces, starting at its column (Cityscape, 0 by default: Monaco only
     * inserts). The view uses it for hidden ranges (`hidden`, `replacement`).
     */
    @:optional final replacedLength:Int;
}

enum abstract InjectedTextCursorStops(Int) from Int to Int {
    var Both = 0;
    var Right = 1;
    var Left = 2;
    var None = 3;
}

/**
 * New model decorations.
 */
typedef IModelDeltaDecoration = {
    /**
     * Range that this decoration covers.
     */
    var range:IRange;
    /**
     * Options associated with this decoration.
     */
    var options:IModelDecorationOptions;
}

/**
 * A decoration in the model.
 */
typedef IModelDecoration = {
    /**
     * Identifier for a decoration.
     */
    final id:String;
    /**
     * Identifier for a decoration's owner.
     */
    final ownerId:Int;
    /**
     * Range that this decoration covers.
     */
    final range:Range;
    /**
     * Options associated with this decoration.
     */
    final options:IModelDecorationOptions;
}

/**
 * An accessor that can add, change or remove model decorations.
 * @internal
 */
interface IModelDecorationsChangeAccessor {
    /**
     * Add a new decoration.
     * @return An unique identifier associated with this decoration.
     */
    function addDecoration(range:IRange, options:IModelDecorationOptions):String;
    /**
     * Change the range that an existing decoration covers.
     */
    function changeDecoration(id:String, newRange:IRange):Void;
    /**
     * Change the options associated with an existing decoration.
     */
    function changeDecorationOptions(id:String, newOptions:IModelDecorationOptions):Void;
    /**
     * Remove an existing decoration.
     */
    function removeDecoration(id:String):Void;
    /**
     * Perform a minimum amount of operations, in order to transform the decorations
     * identified by `oldDecorations` to the decorations described by `newDecorations`
     * and returns the new identifiers associated with the resulting decorations.
     */
    function deltaDecorations(oldDecorations:Array<String>, newDecorations:Array<IModelDeltaDecoration>):Array<String>;
}

/**
 * End of line character preference.
 */
enum abstract EndOfLinePreference(Int) from Int to Int {
    /**
     * Use the end of line character identified in the text buffer.
     */
    var TextDefined = 0;
    /**
     * Use line feed (\n) as the end of line character.
     */
    var LF = 1;
    /**
     * Use carriage return and line feed (\r\n) as the end of line character.
     */
    var CRLF = 2;
}

/**
 * The default end of line to use when instantiating models.
 */
enum abstract DefaultEndOfLine(Int) from Int to Int {
    /**
     * Use line feed (\n) as the end of line character.
     */
    var LF = 1;
    /**
     * Use carriage return and line feed (\r\n) as the end of line character.
     */
    var CRLF = 2;
}

/**
 * End of line character preference.
 */
enum abstract EndOfLineSequence(Int) from Int to Int {
    /**
     * Use line feed (\n) as the end of line character.
     */
    var LF = 0;
    /**
     * Use carriage return and line feed (\r\n) as the end of line character.
     */
    var CRLF = 1;
}

/**
 * An identifier for a single edit operation.
 * @internal
 */
typedef ISingleEditOperationIdentifier = {
    /**
     * Identifier major
     */
    var major:Int;
    /**
     * Identifier minor
     */
    var minor:Int;
}

/**
 * A single edit operation, that has an identifier.
 */
typedef IIdentifiedSingleEditOperation = ISingleEditOperation & {
    /**
     * An identifier associated with this single edit operation.
     * @internal
     */
    @:optional var identifier:Null<ISingleEditOperationIdentifier>;
    /**
     * This indicates that this operation is inserting automatic whitespace
     * that can be removed on next model edit operation if `config.trimAutoWhitespace` is true.
     * @internal
     */
    @:optional var isAutoWhitespaceEdit:Bool;
    /**
     * This indicates that this operation is in a set of operations that are tracked and should not be "simplified".
     * @internal
     */
    @:optional var _isTracked:Bool;
}

typedef IValidEditOperation = {
    /**
     * An identifier associated with this single edit operation.
     * @internal
     */
    var identifier:Null<ISingleEditOperationIdentifier>;
    /**
     * The range to replace. This can be empty to emulate a simple insert.
     */
    var range:Range;
    /**
     * The text to replace with. This can be empty to emulate a simple delete.
     */
    var text:String;
    /**
     * @internal
     */
    var textChange:TextChange;
}

/**
 * A callback that can compute the cursor state after applying a series of edit operations.
 */
typedef ICursorStateComputer = (inverseEditOperations:Array<IValidEditOperation>) -> Null<Array<Selection>>;

/**
 * A model's `indentSize` option: a number of spaces, or `'tabSize'` (the
 * indent size follows the tab size).
 */
typedef IndentSize = EitherType<Int, String>;

class TextModelResolvedOptions {

    public final tabSize:Int;

    public final indentSize:Int;

    final _indentSizeIsTabSize:Bool;

    public final insertSpaces:Bool;

    public final defaultEOL:DefaultEndOfLine;

    public final trimAutoWhitespace:Bool;

    public final bracketPairColorizationOptions:BracketPairColorizationOptions;

    /**
     * `indentSize` as given: `'tabSize'` when it follows the tab size,
     * otherwise the number.
     */
    public var originalIndentSize(get, never):IndentSize;
    function get_originalIndentSize():IndentSize {
        return this._indentSizeIsTabSize ? 'tabSize' : this.indentSize;
    }

    /**
     * @internal
     */
    public function new(src:{
        tabSize:Int,
        indentSize:IndentSize,
        insertSpaces:Bool,
        defaultEOL:DefaultEndOfLine,
        trimAutoWhitespace:Bool,
        bracketPairColorizationOptions:BracketPairColorizationOptions
    }) {
        this.tabSize = Std.int(Math.max(1, src.tabSize));
        if (src.indentSize == 'tabSize') {
            this.indentSize = this.tabSize;
            this._indentSizeIsTabSize = true;
        }
        else {
            final indentSize:Int = src.indentSize;
            this.indentSize = Std.int(Math.max(1, indentSize));
            this._indentSizeIsTabSize = false;
        }
        this.insertSpaces = src.insertSpaces;
        this.defaultEOL = src.defaultEOL;
        this.trimAutoWhitespace = src.trimAutoWhitespace;
        this.bracketPairColorizationOptions = src.bracketPairColorizationOptions;
    }

    /**
     * @internal
     */
    public function equals(other:TextModelResolvedOptions):Bool {
        return (
            this.tabSize == other.tabSize
            && this._indentSizeIsTabSize == other._indentSizeIsTabSize
            && this.indentSize == other.indentSize
            && this.insertSpaces == other.insertSpaces
            && this.defaultEOL == other.defaultEOL
            && this.trimAutoWhitespace == other.trimAutoWhitespace
            && this.bracketPairColorizationOptions.enabled == other.bracketPairColorizationOptions.enabled
            && this.bracketPairColorizationOptions.independentColorPoolPerBracketType == other.bracketPairColorizationOptions.independentColorPoolPerBracketType
        );
    }

    /**
     * @internal
     */
    public function createChangeEvent(newOpts:TextModelResolvedOptions):IModelOptionsChangedEvent {
        return {
            tabSize: this.tabSize != newOpts.tabSize,
            indentSize: this.indentSize != newOpts.indentSize,
            insertSpaces: this.insertSpaces != newOpts.insertSpaces,
            trimAutoWhitespace: this.trimAutoWhitespace != newOpts.trimAutoWhitespace,
        };
    }

}

/**
 * @internal
 */
typedef ITextModelCreationOptions = {
    var tabSize:Int;
    var indentSize:IndentSize;
    var insertSpaces:Bool;
    var detectIndentation:Bool;
    var trimAutoWhitespace:Bool;
    var defaultEOL:DefaultEndOfLine;
    var isForSimpleWidget:Bool;
    var largeFileOptimizations:Bool;
    var bracketPairColorizationOptions:BracketPairColorizationOptions;
}

typedef BracketPairColorizationOptions = {
    var enabled:Bool;
    var independentColorPoolPerBracketType:Bool;
}

typedef ITextModelUpdateOptions = {
    @:optional var tabSize:Int;
    @:optional var indentSize:IndentSize;
    @:optional var insertSpaces:Bool;
    @:optional var trimAutoWhitespace:Bool;
    @:optional var bracketColorizationOptions:BracketPairColorizationOptions;
}

class FindMatch {

    public final range:Range;

    public final matches:Null<Array<String>>;

    /**
     * @internal
     */
    public function new(range:Range, matches:Null<Array<String>>) {
        this.range = range;
        this.matches = matches;
    }

}

/**
 * Describes the behavior of decorations when typing/editing near their edges.
 * Note: Please do not edit the values, as they very carefully match `DecorationRangeBehavior`
 */
enum abstract TrackedRangeStickiness(Int) from Int to Int {
    var AlwaysGrowsWhenTypingAtEdges = 0;
    var NeverGrowsWhenTypingAtEdges = 1;
    var GrowsOnlyWhenTypingBefore = 2;
    var GrowsOnlyWhenTypingAfter = 3;
}

/**
 * Text snapshot that works like an iterator.
 * Will try to return chunks of roughly ~64KB size.
 * Will return null when finished.
 */
interface ITextSnapshot {
    function read():Null<String>;
}

/**
 * The searchScope of `ITextModel.findMatches`: `searchOnlyEditableRange`
 * (a boolean), a range, or several ranges.
 */
typedef FindMatchesScope = EitherType<Bool, EitherType<IRange, Array<IRange>>>;

/**
 * A text model's value: a string or a snapshot (`setValue`).
 */
typedef TextModelValue = EitherType<String, ITextSnapshot>;

/**
 * The event of `onDidChangeContentOrInjectedText`: an
 * `InternalModelContentChangeEvent` or a `ModelInjectedTextChangedEvent`
 * (test with `Std.isOfType`, like Monaco's `instanceof`).
 */
typedef ModelContentOrInjectedTextChangedEvent = EitherType<InternalModelContentChangeEvent, ModelInjectedTextChangedEvent>;

/**
 * A model.
 *
 * Differences with Monaco's interface, all due to Haxe: overloads are merged
 * into one method with optional arguments or `EitherType` parameters
 * (`findMatches`, `setLanguage`, `applyEdits`, `_setTrackedRange`,
 * `pushEditOperations`); `undo()` and `redo()` return nothing (Monaco may
 * return a promise); `Event<void>` is `VoidEvent`. The model is an
 * `ICursorSimpleModel` (Monaco passes it as one, structurally typed).
 */
interface ITextModel extends cityscape.common.CursorCommon.ICursorSimpleModel {

    /**
     * Gets the resource associated with this editor model.
     */
    final uri:Uri;

    /**
     * A unique identifier associated with this model.
     */
    final id:String;

    /**
     * This model is constructed for a simple widget code editor.
     * @internal
     */
    final isForSimpleWidget:Bool;

    /**
     * If true, the text model might contain RTL.
     * If false, the text model **contains only** contain LTR.
     * @internal
     */
    function mightContainRTL():Bool;

    /**
     * If true, the text model might contain LINE SEPARATOR (LS), PARAGRAPH SEPARATOR (PS).
     * If false, the text model definitely does not contain these.
     * @internal
     */
    function mightContainUnusualLineTerminators():Bool;

    /**
     * @internal
     */
    function removeUnusualLineTerminators(?selections:Array<Selection>):Void;

    /**
     * If true, the text model might contain non basic ASCII.
     * If false, the text model **contains only** basic ASCII.
     * @internal
     */
    function mightContainNonBasicASCII():Bool;

    /**
     * Get the resolved options for this model.
     */
    function getOptions():TextModelResolvedOptions;

    /**
     * Get the formatting options for this model.
     * @internal
     */
    function getFormattingOptions():FormattingOptions;

    /**
     * Get the current version id of the model.
     * Anytime a change happens to the model (even undo/redo),
     * the version id is incremented.
     */
    function getVersionId():Int;

    /**
     * Get the alternative version id of the model.
     * This alternative version id is not always incremented,
     * it will return the same values in the case of undo-redo.
     */
    function getAlternativeVersionId():Int;

    /**
     * Replace the entire text buffer value contained in this model.
     */
    function setValue(newValue:TextModelValue):Void;

    /**
     * Get the text stored in this model.
     * @param eol The end of line character preference. Defaults to `EndOfLinePreference.TextDefined`.
     * @param preserverBOM Preserve a BOM character if it was detected when the model was constructed.
     * @return The text.
     */
    function getValue(?eol:EndOfLinePreference, ?preserveBOM:Bool):String;

    /**
     * Get the text stored in this model.
     * @param preserverBOM Preserve a BOM character if it was detected when the model was constructed.
     * @return The text snapshot (it is safe to consume it asynchronously).
     */
    function createSnapshot(?preserveBOM:Bool):ITextSnapshot;

    /**
     * Get the length of the text stored in this model.
     */
    function getValueLength(?eol:EndOfLinePreference, ?preserveBOM:Bool):Int;

    /**
     * Check if the raw text stored in this model equals another raw text.
     * @internal
     */
    function equalsTextBuffer(other:ITextBuffer):Bool;

    /**
     * Get the underling text buffer.
     * @internal
     */
    function getTextBuffer():ITextBuffer;

    /**
     * Get the text in a certain range.
     * @param range The range describing what text to get.
     * @param eol The end of line character preference. This will only be used for multiline ranges. Defaults to `EndOfLinePreference.TextDefined`.
     * @return The text.
     */
    function getValueInRange(range:IRange, ?eol:EndOfLinePreference):String;

    /**
     * Get the length of text in a certain range.
     * @param range The range describing what text length to get.
     * @return The text length.
     */
    function getValueLengthInRange(range:IRange, ?eol:EndOfLinePreference):Int;

    /**
     * Get the character count of text in a certain range.
     * @param range The range describing what text length to get.
     */
    function getCharacterCountInRange(range:IRange, ?eol:EndOfLinePreference):Int;

    /**
     * Splits characters in two buckets. First bucket (A) is of characters that
     * sit in lines with length < `LONG_LINE_BOUNDARY`. Second bucket (B) is of
     * characters that sit in lines with length >= `LONG_LINE_BOUNDARY`.
     * If count(B) > count(A) return true. Returns false otherwise.
     * @internal
     */
    function isDominatedByLongLines():Bool;

    /**
     * Get the number of lines in the model.
     */
    function getLineCount():Int;

    /**
     * Get the text for a certain line.
     */
    function getLineContent(lineNumber:Int):String;

    /**
     * Get the text length for a certain line.
     */
    function getLineLength(lineNumber:Int):Int;

    /**
     * Get the text for all lines.
     */
    function getLinesContent():Array<String>;

    /**
     * Get the end of line sequence predominantly used in the text buffer.
     * @return EOL char sequence (e.g.: '\n' or '\r\n').
     */
    function getEOL():String;

    /**
     * Get the end of line sequence predominantly used in the text buffer.
     */
    function getEndOfLineSequence():EndOfLineSequence;

    /**
     * Get the minimum legal column for line at `lineNumber`
     */
    function getLineMinColumn(lineNumber:Int):Int;

    /**
     * Get the maximum legal column for line at `lineNumber`
     */
    function getLineMaxColumn(lineNumber:Int):Int;

    /**
     * Returns the column before the first non whitespace character for line at `lineNumber`.
     * Returns 0 if line is empty or contains only whitespace.
     */
    function getLineFirstNonWhitespaceColumn(lineNumber:Int):Int;

    /**
     * Returns the column after the last non whitespace character for line at `lineNumber`.
     * Returns 0 if line is empty or contains only whitespace.
     */
    function getLineLastNonWhitespaceColumn(lineNumber:Int):Int;

    /**
     * Create a valid position.
     */
    function validatePosition(position:IPosition):Position;

    /**
     * Advances the given position by the given offset (negative offsets are also accepted)
     * and returns it as a new valid position.
     *
     * If the offset and position are such that their combination goes beyond the beginning or
     * end of the model, throws an exception.
     *
     * If the offset is such that the new position would be in the middle of a multi-byte
     * line terminator, throws an exception.
     */
    function modifyPosition(position:IPosition, offset:Int):Position;

    /**
     * Create a valid range.
     */
    function validateRange(range:IRange):Range;

    /**
     * Converts the position to a zero-based offset.
     *
     * The position will be [adjusted](#TextDocument.validatePosition).
     *
     * @param position A position.
     * @return A valid zero-based offset.
     */
    function getOffsetAt(position:IPosition):Int;

    /**
     * Converts a zero-based offset to a position.
     *
     * @param offset A zero-based offset.
     * @return A valid [position](#Position).
     */
    function getPositionAt(offset:Int):Position;

    /**
     * Get a range covering the entire model.
     */
    function getFullModelRange():Range;

    /**
     * Returns if the model was disposed or not.
     */
    function isDisposed():Bool;

    /**
     * This model is so large that it would not be a good idea to sync it over
     * to web workers or other places.
     * @internal
     */
    function isTooLargeForSyncing():Bool;

    /**
     * The file is so large, that even tokenization is disabled.
     * @internal
     */
    function isTooLargeForTokenization():Bool;

    /**
     * The file is so large, that operations on it might be too large for heap
     * and can lead to OOM crashes so they should be disabled.
     * @internal
     */
    function isTooLargeForHeapOperation():Bool;

    /**
     * Search the model.
     * @param searchString The string used to search. If it is a regular expression, set `isRegex` to true.
     * @param searchScope Limit the searching to only search inside the editable range of the model
     * (a boolean, Monaco's `searchOnlyEditableRange`), or inside these ranges.
     * @param isRegex Used to indicate that `searchString` is a regular expression.
     * @param matchCase Force the matching to match lower/upper case exactly.
     * @param wordSeparators Force the matching to match entire words only. Pass null otherwise.
     * @param captureMatches The result will contain the captured groups.
     * @param limitResultCount Limit the number of results
     * @return The ranges where the matches are. It is empty if not matches have been found.
     */
    function findMatches(searchString:String, searchScope:FindMatchesScope, isRegex:Bool, matchCase:Bool, wordSeparators:Null<String>, captureMatches:Bool, ?limitResultCount:Int):Array<FindMatch>;

    /**
     * Search the model for the next match. Loops to the beginning of the model if needed.
     * @return The range where the next match is. It is null if no next match has been found.
     */
    function findNextMatch(searchString:String, searchStart:IPosition, isRegex:Bool, matchCase:Bool, wordSeparators:Null<String>, captureMatches:Bool):Null<FindMatch>;

    /**
     * Search the model for the previous match. Loops to the end of the model if needed.
     * @return The range where the previous match is. It is null if no previous match has been found.
     */
    function findPreviousMatch(searchString:String, searchStart:IPosition, isRegex:Bool, matchCase:Bool, wordSeparators:Null<String>, captureMatches:Bool):Null<FindMatch>;

    /**
     * Get the language associated with this model.
     */
    function getLanguageId():String;

    /**
     * Set the current language mode associated with the model: a language id
     * or a language selection (which updates the language when it changes).
     * @param source The source of the call that set the language.
     * @internal
     */
    function setLanguage(languageIdOrSelection:EitherType<String, ILanguageSelection>, ?source:String):Void;

    /**
     * Returns the real (inner-most) language mode at a given position.
     * The result might be inaccurate. Use `forceTokenization` to ensure accurate tokens.
     * @internal
     */
    function getLanguageIdAtPosition(lineNumber:Int, column:Int):String;

    /**
     * Get the word under or besides `position`.
     * @param position The position to look for a word.
     * @return The word under or besides `position`. Might be null.
     */
    function getWordAtPosition(position:IPosition):Null<IWordAtPosition>;

    /**
     * Get the word under or besides `position` trimmed to `position`.column
     * @param position The position to look for a word.
     * @return The word under or besides `position`. Will never be null.
     */
    function getWordUntilPosition(position:IPosition):IWordAtPosition;

    /**
     * Change the decorations. The callback will be called with a change accessor
     * that becomes invalid as soon as the callback finishes executing.
     * This allows for all events to be queued up until the change is completed. Returns whatever the callback returns.
     * @param ownerId Identifies the editor id in which these decorations should appear. If no `ownerId` is provided, the decorations will appear in all editors that attach this model.
     * @internal
     */
    function changeDecorations<T>(callback:(changeAccessor:IModelDecorationsChangeAccessor) -> T, ?ownerId:Int):Null<T>;

    /**
     * Perform a minimum amount of operations, in order to transform the decorations
     * identified by `oldDecorations` to the decorations described by `newDecorations`
     * and returns the new identifiers associated with the resulting decorations.
     *
     * @param oldDecorations Array containing previous decorations identifiers.
     * @param newDecorations Array describing what decorations should result after the call.
     * @param ownerId Identifies the editor id in which these decorations should appear. If no `ownerId` is provided, the decorations will appear in all editors that attach this model.
     * @return An array containing the new decorations identifiers.
     */
    function deltaDecorations(oldDecorations:Array<String>, newDecorations:Array<IModelDeltaDecoration>, ?ownerId:Int):Array<String>;

    /**
     * Remove all decorations that have been added with this specific ownerId.
     * @param ownerId The owner id to search for.
     * @internal
     */
    function removeAllDecorationsWithOwnerId(ownerId:Int):Void;

    /**
     * Get the options associated with a decoration.
     * @param id The decoration id.
     * @return The decoration options or null if the decoration was not found.
     */
    function getDecorationOptions(id:String):Null<IModelDecorationOptions>;

    /**
     * Get the range associated with a decoration.
     * @param id The decoration id.
     * @return The decoration range or null if the decoration was not found.
     */
    function getDecorationRange(id:String):Null<Range>;

    /**
     * Gets all the decorations for the line `lineNumber` as an array.
     * @param lineNumber The line number
     * @param ownerId If set, it will ignore decorations belonging to other owners.
     * @param filterOutValidation If set, it will ignore decorations specific to validation (i.e. warnings, errors).
     * @return An array with the decorations
     */
    function getLineDecorations(lineNumber:Int, ?ownerId:Int, ?filterOutValidation:Bool):Array<IModelDecoration>;

    /**
     * Gets all the decorations for the lines between `startLineNumber` and `endLineNumber` as an array.
     * @param startLineNumber The start line number
     * @param endLineNumber The end line number
     * @param ownerId If set, it will ignore decorations belonging to other owners.
     * @param filterOutValidation If set, it will ignore decorations specific to validation (i.e. warnings, errors).
     * @return An array with the decorations
     */
    function getLinesDecorations(startLineNumber:Int, endLineNumber:Int, ?ownerId:Int, ?filterOutValidation:Bool):Array<IModelDecoration>;

    /**
     * Gets all the decorations in a range as an array. Only `startLineNumber` and `endLineNumber` from `range` are used for filtering.
     * So for now it returns all the decorations on the same line as `range`.
     * @param range The range to search in
     * @param ownerId If set, it will ignore decorations belonging to other owners.
     * @param filterOutValidation If set, it will ignore decorations specific to validation (i.e. warnings, errors).
     * @param onlyMinimapDecorations If set, it will return only decorations that render in the minimap.
     * @param onlyMarginDecorations If set, it will return only decorations that render in the glyph margin.
     * @return An array with the decorations
     */
    function getDecorationsInRange(range:IRange, ?ownerId:Int, ?filterOutValidation:Bool, ?onlyMinimapDecorations:Bool, ?onlyMarginDecorations:Bool):Array<IModelDecoration>;

    /**
     * Gets all the decorations as an array.
     * @param ownerId If set, it will ignore decorations belonging to other owners.
     * @param filterOutValidation If set, it will ignore decorations specific to validation (i.e. warnings, errors).
     */
    function getAllDecorations(?ownerId:Int, ?filterOutValidation:Bool):Array<IModelDecoration>;

    /**
     * Gets all decorations that render in the glyph margin as an array.
     * @param ownerId If set, it will ignore decorations belonging to other owners.
     */
    function getAllMarginDecorations(?ownerId:Int):Array<IModelDecoration>;

    /**
     * Gets all the decorations that should be rendered in the overview ruler as an array.
     * @param ownerId If set, it will ignore decorations belonging to other owners.
     * @param filterOutValidation If set, it will ignore decorations specific to validation (i.e. warnings, errors).
     */
    function getOverviewRulerDecorations(?ownerId:Int, ?filterOutValidation:Bool):Array<IModelDecoration>;

    /**
     * Gets all the decorations that contain injected text.
     * @param ownerId If set, it will ignore decorations belonging to other owners.
     */
    function getInjectedTextDecorations(?ownerId:Int):Array<IModelDecoration>;

    /**
     * @internal
     */
    function _getTrackedRange(id:String):Null<Range>;

    /**
     * Sets (or removes, when `newRange` is null) a tracked range; returns
     * its id, null when removed.
     * @internal
     */
    function _setTrackedRange(id:Null<String>, newRange:Null<Range>, newStickiness:TrackedRangeStickiness):Null<String>;

    /**
     * Normalize a string containing whitespace according to indentation rules (converts to spaces or to tabs).
     */
    function normalizeIndentation(str:String):String;

    /**
     * Change the options of this model.
     */
    function updateOptions(newOpts:ITextModelUpdateOptions):Void;

    /**
     * Detect the indentation options for this model from its content.
     */
    function detectIndentation(defaultInsertSpaces:Bool, defaultTabSize:Int):Void;

    /**
     * Close the current undo-redo element.
     * This offers a way to create an undo/redo stop point.
     */
    function pushStackElement():Void;

    /**
     * Open the current undo-redo element.
     * This offers a way to remove the current undo/redo stop point.
     */
    function popStackElement():Void;

    /**
     * Push edit operations, basically editing the model. This is the preferred way
     * of editing the model. The edit operations will land on the undo stack.
     * @param beforeCursorState The cursor state before the edit operations. This cursor state will be returned when `undo` or `redo` are invoked.
     * @param editOperations The edit operations.
     * @param cursorStateComputer A callback that can compute the resulting cursors state after the edit operations have been executed.
     * @param group The undo/redo group (internal).
     * @return The cursor state returned by the `cursorStateComputer`.
     */
    function pushEditOperations(beforeCursorState:Null<Array<Selection>>, editOperations:Array<IIdentifiedSingleEditOperation>, cursorStateComputer:ICursorStateComputer, ?group:UndoRedoGroup):Null<Array<Selection>>;

    /**
     * Change the end of line sequence. This is the preferred way of
     * changing the eol sequence. This will land on the undo stack.
     */
    function pushEOL(eol:EndOfLineSequence):Void;

    /**
     * Edit the model without adding the edits to the undo stack.
     * This can have dire consequences on the undo stack! See @pushEditOperations for the preferred way.
     * @param operations The edit operations.
     * @param computeUndoEdits Whether to compute and return the undo edits.
     * @return If desired, the undo edit operations, null otherwise.
     */
    function applyEdits(operations:Array<IIdentifiedSingleEditOperation>, ?computeUndoEdits:Bool):Null<Array<IValidEditOperation>>;

    /**
     * Change the end of line sequence without recording in the undo stack.
     * This can have dire consequences on the undo stack! See @pushEOL for the preferred way.
     */
    function setEOL(eol:EndOfLineSequence):Void;

    /**
     * @internal
     */
    function _applyUndo(changes:Array<TextChange>, eol:EndOfLineSequence, resultingAlternativeVersionId:Int, resultingSelection:Null<Array<Selection>>):Void;

    /**
     * @internal
     */
    function _applyRedo(changes:Array<TextChange>, eol:EndOfLineSequence, resultingAlternativeVersionId:Int, resultingSelection:Null<Array<Selection>>):Void;

    /**
     * Undo edit operations until the previous undo/redo point.
     * The inverse edit operations will be pushed on the redo stack.
     */
    function undo():Void;

    /**
     * Is there anything in the undo stack?
     */
    function canUndo():Bool;

    /**
     * Redo edit operations until the next undo/redo point.
     * The inverse edit operations will be pushed on the undo stack.
     */
    function redo():Void;

    /**
     * Is there anything in the redo stack?
     */
    function canRedo():Bool;

    /**
     * @deprecated Please use `onDidChangeContent` instead.
     * An event emitted when the contents of the model have changed.
     * @internal
     * @event
     */
    final onDidChangeContentOrInjectedText:Event<ModelContentOrInjectedTextChangedEvent>;

    /**
     * An event emitted when the contents of the model have changed.
     * @event
     */
    function onDidChangeContent(listener:(e:IModelContentChangedEvent) -> Void):IDisposable;

    /**
     * An event emitted when decorations of the model have changed.
     * @event
     */
    final onDidChangeDecorations:Event<IModelDecorationsChangedEvent>;

    /**
     * An event emitted when the model options have changed.
     * @event
     */
    final onDidChangeOptions:Event<IModelOptionsChangedEvent>;

    /**
     * An event emitted when the language associated with the model has changed.
     * @event
     */
    final onDidChangeLanguage:Event<IModelLanguageChangedEvent>;

    /**
     * An event emitted when the language configuration associated with the model has changed.
     * @event
     */
    final onDidChangeLanguageConfiguration:Event<IModelLanguageConfigurationChangedEvent>;

    /**
     * An event emitted when the tokens associated with the model have changed.
     * @event
     * @internal
     */
    final onDidChangeTokens:Event<IModelTokensChangedEvent>;

    /**
     * An event emitted when the model has been attached to the first editor or detached from the last editor.
     * @event
     */
    final onDidChangeAttached:VoidEvent;

    /**
     * An event emitted right before disposing the model.
     * @event
     */
    final onWillDispose:VoidEvent;

    /**
     * Destroy this model.
     */
    function dispose():Void;

    /**
     * @internal
     */
    function onBeforeAttached():IAttachedView;

    /**
     * @internal
     */
    function onBeforeDetached(view:IAttachedView):Void;

    /**
     * Returns if this model is attached to an editor or not.
     */
    function isAttachedToEditor():Bool;

    /**
     * Returns the count of editors this model is attached to.
     * @internal
     */
    function getAttachedEditorCount():Int;

    /**
     * Among all positions that are projected to the same position in the underlying text model as
     * the given position, select a unique position as indicated by the affinity.
     *
     * PositionAffinity.Left:
     * The normalized position must be equal or left to the requested position.
     *
     * PositionAffinity.Right:
     * The normalized position must be equal or right to the requested position.
     *
     * @internal
     */
    function normalizePosition(position:Position, affinity:PositionAffinity):Position;

    /**
     * Gets the column at which indentation stops at a given line.
     * @internal
     */
    function getLineIndentColumn(lineNumber:Int):Int;

    /**
     * Returns an object that can be used to query brackets.
     * @internal
     */
    final bracketPairs:IBracketPairsTextModelPart;

    /**
     * Returns an object that can be used to query indent guides.
     * @internal
     */
    final guides:IGuidesTextModelPart;

    /**
     * @internal
     */
    final tokenization:ITokenizationTextModelPart;

}

/**
 * @internal
 */
interface IAttachedView {
    /**
     * @param stabilized Indicates if the visible lines are probably going to change soon or can be considered stable.
     * Is true on reveal range and false on scroll.
     * Tokenizers should tokenize synchronously if stabilized is true.
     */
    function setVisibleLines(visibleLines:Array<{startLineNumber:Int, endLineNumber:Int}>, stabilized:Bool):Void;
}

enum abstract PositionAffinity(Int) from Int to Int {
    /**
     * Prefers the left most position.
     */
    var Left = 0;

    /**
     * Prefers the right most position.
     */
    var Right = 1;

    /**
     * No preference.
     */
    var None = 2;

    /**
     * If the given position is on injected text, prefers the position left of it.
     */
    var LeftOfInjectedText = 3;

    /**
     * If the given position is on injected text, prefers the position right of it.
     */
    var RightOfInjectedText = 4;
}

/**
 * @internal
 */
interface ITextBufferBuilder {
    function acceptChunk(chunk:String):Void;
    function finish():ITextBufferFactory;
}

/**
 * @internal
 */
interface ITextBufferFactory {
    function create(defaultEOL:DefaultEndOfLine):{textBuffer:ITextBuffer, disposable:IDisposable};
    function getFirstLineText(lengthLimit:Int):String;
}

/**
 * @internal
 */
enum abstract ModelConstants(Int) from Int to Int {
    var FIRST_LINE_DETECTION_LENGTH_LIMIT = 1000;
}

/**
 * @internal
 */
class ValidAnnotatedEditOperation {

    public final identifier:Null<ISingleEditOperationIdentifier>;

    public final range:Range;

    public final text:Null<String>;

    public final forceMoveMarkers:Bool;

    public final isAutoWhitespaceEdit:Bool;

    public final _isTracked:Bool;

    public function new(identifier:Null<ISingleEditOperationIdentifier>, range:Range, text:Null<String>, forceMoveMarkers:Bool, isAutoWhitespaceEdit:Bool, _isTracked:Bool) {
        this.identifier = identifier;
        this.range = range;
        this.text = text;
        this.forceMoveMarkers = forceMoveMarkers;
        this.isAutoWhitespaceEdit = isAutoWhitespaceEdit;
        this._isTracked = _isTracked;
    }

}

/**
 * @internal
 *
 * `IReadonlyTextBuffer` is a text buffer that cannot be modified.
 */
interface IReadonlyTextBuffer {
    final onDidChangeContent:VoidEvent;
    function equals(other:ITextBuffer):Bool;
    function mightContainRTL():Bool;
    function mightContainUnusualLineTerminators():Bool;
    function resetMightContainUnusualLineTerminators():Void;
    function mightContainNonBasicASCII():Bool;
    function getBOM():String;
    function getEOL():String;

    function getOffsetAt(lineNumber:Int, column:Int):Int;
    function getPositionAt(offset:Int):Position;
    function getRangeAt(offset:Int, length:Int):Range;

    function getValueInRange(range:Range, eol:EndOfLinePreference):String;
    function createSnapshot(preserveBOM:Bool):ITextSnapshot;
    function getValueLengthInRange(range:Range, eol:EndOfLinePreference):Int;
    function getCharacterCountInRange(range:Range, eol:EndOfLinePreference):Int;
    function getLength():Int;
    function getLineCount():Int;
    function getLinesContent():Array<String>;
    function getLineContent(lineNumber:Int):String;
    function getLineCharCode(lineNumber:Int, index:Int):Int;
    function getCharCode(offset:Int):Int;
    function getLineLength(lineNumber:Int):Int;
    function getLineMinColumn(lineNumber:Int):Int;
    function getLineMaxColumn(lineNumber:Int):Int;
    function getLineFirstNonWhitespaceColumn(lineNumber:Int):Int;
    function getLineLastNonWhitespaceColumn(lineNumber:Int):Int;

    function getNearestChunk(offset:Int):String;

    function findMatchesLineByLine(searchRange:Range, searchData:SearchData, captureMatches:Bool, limitResultCount:Int):Array<FindMatch>;
}

/**
 * @internal
 */
class SearchData {

    /**
     * The regex to search for. Always defined.
     */
    public final regex:RegExp;

    /**
     * The word separator classifier.
     */
    public final wordSeparators:Null<WordCharacterClassifier>;

    /**
     * The simple string to search for (if possible).
     */
    public final simpleSearch:Null<String>;

    public function new(regex:RegExp, wordSeparators:Null<WordCharacterClassifier>, simpleSearch:Null<String>) {
        this.regex = regex;
        this.wordSeparators = wordSeparators;
        this.simpleSearch = simpleSearch;
    }

}

/**
 * @internal
 */
interface ITextBuffer extends IReadonlyTextBuffer extends IDisposable {
    /**
     * `newEOL` is `'\r\n'` or `'\n'`.
     */
    function setEOL(newEOL:String):Void;
    function applyEdits(rawOperations:Array<ValidAnnotatedEditOperation>, recordTrimAutoWhitespace:Bool, computeUndoEdits:Bool):ApplyEditsResult;
}

/**
 * @internal
 */
class ApplyEditsResult {

    public final reverseEdits:Null<Array<IValidEditOperation>>;

    public final changes:Array<IInternalModelContentChange>;

    public final trimAutoWhitespaceLineNumbers:Null<Array<Int>>;

    public function new(reverseEdits:Null<Array<IValidEditOperation>>, changes:Array<IInternalModelContentChange>, trimAutoWhitespaceLineNumbers:Null<Array<Int>>) {
        this.reverseEdits = reverseEdits;
        this.changes = changes;
        this.trimAutoWhitespaceLineNumbers = trimAutoWhitespaceLineNumbers;
    }

}

/**
 * @internal
 */
typedef IInternalModelContentChange = {
    final range:Range;
    final rangeOffset:Int;
    final rangeLength:Int;
    final text:String;
    final forceMoveMarkers:Bool;
}

/**
 * Module functions of model.ts.
 */
class ModelUtils {

    /**
     * @internal
     */
    public static function shouldSynchronizeModel(model:ITextModel):Bool {
        return (
            !model.isTooLargeForSyncing() && !model.isForSimpleWidget
        );
    }

}
