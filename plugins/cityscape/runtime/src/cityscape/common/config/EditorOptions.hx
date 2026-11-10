// Ported from vscode src/vs/editor/common/config/editorOptions.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.config;

import cityscape.base.common.JsValues;
import cityscape.base.common.Platform;
import cityscape.base.common.Scrollable.ScrollbarVisibility;
import cityscape.common.config.FontInfo;
import cityscape.common.core.WordHelper;
import cityscape.platform.accessibility.common.Accessibility.AccessibilitySupport;
import haxe.extern.EitherType;

/*
 * Editor options: ids, input types, defaults and validation.
 *
 * Ported so far (validation and defaults faithful to Monaco), see
 * `EditorOptions`: acceptSuggestionOnEnter, accessibilitySupport,
 * autoClosingBrackets, autoClosingDelete, autoClosingOvertype,
 * autoClosingQuotes, autoIndent, automaticLayout, autoSurround,
 * colorDecorators, contextmenu, cursorBlinking, cursorSmoothCaretAnimation,
 * cursorStyle, cursorSurroundingLines, cursorWidth,
 * definitionLinkOpensInPeek, fixedOverflowWidgets, folding, foldingHighlight,
 * foldingImportsByDefault, foldingMaximumRegions, foldingStrategy,
 * fontFamily, fontLigatures, fontSize, fontWeight, glyphMargin, gotoLocation,
 * hover, letterSpacing, lineDecorationsWidth, lineHeight, lineNumbers,
 * lineNumbersMinChars, links, matchBrackets, mouseWheelZoom,
 * multiCursorModifier, occurrencesHighlight, padding, quickSuggestions,
 * quickSuggestionsDelay, readOnly, renderControlCharacters,
 * renderFinalNewline, renderLineHighlight, renderWhitespace, roundedSelection,
 * rulers, scrollbar, scrollBeyondLastColumn, scrollBeyondLastLine,
 * selectionHighlight, showFoldingControls, smoothScrolling, stickyScroll,
 * suggest, suggestOnTriggerCharacters, unfoldOnClickAfterEndOfLine,
 * wordSeparators, wordWrap,
 * wordWrapColumn, wrappingIndent; and the options of the view, see
 * `EditorViewOptions` (including the computed `fontInfo`, `pixelRatio`,
 * `layoutInfo` and `wrappingInfo`).
 *
 * Every id of Monaco's `EditorOption` is declared (same numbers); the
 * options not ported yet have the value type `Any` and no entry in the
 * registry (TODO: add them as the modules that read them are ported; the
 * computed ones, `layoutInfo`, `wrappingInfo`, `fontInfo`, `pixelRatio`,
 * `editorClassName`, `tabFocusMode`, come with the view in step 2).
 * `minimap` is not ported (Cityscape has no minimap). The JSON schemas and
 * localized descriptions of the settings UI are not ported.
 *
 * Input values are read like Monaco reads them, with JavaScript semantics
 * (`JsValues`): a string `'14'` is a valid font size, `'false'` a false
 * boolean.
 */

/**
 * Configuration options for auto closing quotes and brackets:
 * `'always'`, `'languageDefined'`, `'beforeWhitespace'` or `'never'`.
 */
typedef EditorAutoClosingStrategy = String;

/**
 * Configuration options for auto wrapping quotes and brackets:
 * `'languageDefined'`, `'quotes'`, `'brackets'` or `'never'`.
 */
typedef EditorAutoSurroundStrategy = String;

/**
 * Configuration options for typing over closing quotes or brackets:
 * `'always'`, `'auto'` or `'never'`.
 */
typedef EditorAutoClosingEditStrategy = String;

/**
 * Configuration options for auto indentation in the editor
 */
enum abstract EditorAutoIndentStrategy(Int) from Int to Int {
    var None = 0;
    var Keep = 1;
    var Brackets = 2;
    var Advanced = 3;
    var Full = 4;
}

/**
 * Configuration options for the editor (the ones ported so far, see the
 * module comment). Monaco's union types are `EitherType` here.
 */
typedef IEditorOptions = {
    /**
     * Control the rendering of line numbers: `'on'`, `'off'`, `'relative'`,
     * `'interval'`, or a function that renders a line number.
     * Defaults to `on`.
     */
    @:optional var lineNumbers:LineNumbersType;
    /**
     * Render vertical lines at the specified columns.
     * Defaults to empty array.
     */
    @:optional var rulers:Array<EitherType<Int, IRulerOption>>;
    /**
     * A string containing the word separators used when doing word navigation.
     * Defaults to `~!@#$%^&*()-=+[{]}\\|;:\'",.<>/?
     */
    @:optional var wordSeparators:String;
    /**
     * Should the corresponding line be selected when clicking on the line number?
     * Defaults to true.
     */
    @:optional var roundedSelection:Bool;
    /**
     * Should the editor be read only.
     * Defaults to false.
     */
    @:optional var readOnly:Bool;
    /**
     * Controls if the editor should allow to move selections via drag and drop.
     * Defaults to true.
     */
    @:optional var dragAndDrop:Bool;
    /**
     * Control the mouse pointer style, either 'text' or 'default' or 'copy'
     * Defaults to 'text'
     */
    @:optional var mouseStyle:String;
    /**
     * Enable that the editor will install a ResizeObserver to check if its container dom node size has changed.
     * Defaults to false.
     */
    @:optional var automaticLayout:Bool;
    /**
     * Control the wrapping of the editor: `'off'`, `'on'`,
     * `'wordWrapColumn'` or `'bounded'`.
     * Defaults to "off".
     */
    @:optional var wordWrap:String;
    /**
     * Control the wrapping of the editor.
     * When `wordWrap` = "wordWrapColumn" or `wordWrap` = "bounded", the lines
     * will wrap at `wordWrapColumn`. Defaults to 80.
     */
    @:optional var wordWrapColumn:Int;
    /**
     * Control indentation of wrapped lines: `'none'`, `'same'`, `'indent'` or
     * `'deepIndent'`. Defaults to 'same' in vscode and to 'none' in monaco-editor.
     */
    @:optional var wrappingIndent:String;
    /**
     * Control the behavior and rendering of the scrollbars.
     */
    @:optional var scrollbar:IEditorScrollbarOptions;
    /**
     * Control the behavior of sticky scroll options
     */
    @:optional var stickyScroll:IEditorStickyScrollOptions;
    /**
     * Configures bracket pair colorization (disabled by default).
     */
    @:optional var bracketPairColorization:IBracketPairColorizationOptions;
    /**
     * Controls the rendering of the guides (indentation and bracket pairs).
     */
    @:optional var guides:IGuidesOptions;
    /**
     * Enable that scrolling can go one screen size after the last line.
     * Defaults to true.
     */
    @:optional var scrollBeyondLastLine:Bool;
    /**
     * Cityscape addition (not in Monaco): how far past the last line the
     * editor scrolls when `scrollBeyondLastLine` is on, as gpui-kit's code
     * editor does it: `max(viewportFraction * viewport, minLines * lineHeight)`,
     * the viewport being the editor height without the top and bottom padding
     * (gpui-kit `TextElement::empty_bottom_height` is `{viewportFraction: 0.5,
     * minLines: 3}`). Null (the default): Monaco's, one viewport less a line.
     */
    @:optional var scrollBeyondLastLineGap:IScrollBeyondLastLineGap;
    /**
     * Cityscape addition (not in Monaco): the vertical scrollbar thumb is
     * measured against the viewport and the content without the editor's
     * top and bottom padding, like the scrollbar of gpui-kit's editors (whose
     * padding is outside the scrolled text). The track and the scroll range
     * stay the editor's. Defaults to false.
     */
    @:optional var scrollbarThumbExcludesPadding:Bool;
    /**
     * Cityscape addition (not in Monaco): every emoji (Unicode's
     * `Extended_Pictographic`: `☕`, `☂`, `❤`, `©`..., unless followed by
     * U+FE0E) is drawn with the color emoji font, on every target, even
     * when a font of `fontFamily` has a text glyph for it. False gives the
     * browser's order (Chromium draws `☕` with Menlo's text glyph when
     * Menlo is in the list). Defaults to true.
     */
    @:optional var preferColorEmoji:Bool;
    /**
     * Cityscape addition (not in Monaco): where the decorations overview
     * ruler goes. `'overlay'` (the default) is Monaco's: the ruler lies
     * under the vertical scrollbar, in the same column. `'beside'` puts it
     * in its own column, left of the scrollbar (`overviewRulerGap` pixels
     * apart), so the marks and the scrollbar thumb do not overlap, like
     * loreline-monaco does with its style sheet. The text area keeps
     * Monaco's layout (the content width and the wrapping column do not
     * change): the ruler is drawn over the right of the text area.
     */
    @:optional var overviewRulerPosition:String;
    /**
     * Cityscape addition (not in Monaco): with `overviewRulerPosition:
     * 'beside'`, the space between the overview ruler and the vertical
     * scrollbar, in pixels. Defaults to 0.
     */
    @:optional var overviewRulerGap:Float;
    /**
     * Enable that scrolling can go beyond the last column by a number of columns.
     * Defaults to 5.
     */
    @:optional var scrollBeyondLastColumn:Int;
    /**
     * Enable that the editor animates scrolling to a position.
     * Defaults to false.
     */
    @:optional var smoothScrolling:Bool;
    /**
     * Control the cursor animation style: `'blink'`, `'smooth'`, `'phase'`,
     * `'expand'` or `'solid'`. Defaults to 'blink'.
     */
    @:optional var cursorBlinking:String;
    /**
     * Enable smooth caret animation: `'off'`, `'explicit'` or `'on'`.
     * Defaults to 'off'.
     */
    @:optional var cursorSmoothCaretAnimation:String;
    /**
     * Control the cursor style: `'line'`, `'block'`, `'underline'`,
     * `'line-thin'`, `'block-outline'` or `'underline-thin'`.
     * Defaults to 'line'.
     */
    @:optional var cursorStyle:String;
    /**
     * Control the width of the cursor when cursorStyle is set to 'line'
     */
    @:optional var cursorWidth:Int;
    /**
     * Controls the minimal number of visible leading and trailing lines surrounding the cursor.
     * Defaults to 0.
     */
    @:optional var cursorSurroundingLines:Int;
    /**
     * Enable font ligatures.
     * Defaults to false.
     */
    @:optional var fontLigatures:EitherType<Bool, String>;
    /**
     * Prevent the editor from rendering its widgets outside of its own box
     * (Monaco: fixed positioning of the overflow widgets).
     * Defaults to false.
     */
    @:optional var fixedOverflowWidgets:Bool;
    /**
     * Enable custom contextmenu.
     * Defaults to true.
     */
    @:optional var contextmenu:Bool;
    /**
     * Zoom the font in the editor when using the mouse wheel in combination with holding Ctrl.
     * Defaults to false.
     */
    @:optional var mouseWheelZoom:Bool;
    /**
     * The modifier to be used to add multiple cursors with the mouse:
     * `'ctrlCmd'` or `'alt'`. Defaults to 'alt'
     */
    @:optional var multiCursorModifier:String;
    /**
     * Configure the editor's accessibility support: `'auto'`, `'off'` or `'on'`.
     * Defaults to 'auto'.
     */
    @:optional var accessibilitySupport:String;
    /**
     * Enable quick suggestions (shadow suggestions)
     * Defaults to true.
     */
    @:optional var quickSuggestions:EitherType<Bool, IQuickSuggestionsOptions>;
    /**
     * Quick suggestions show delay (in ms)
     * Defaults to 10 (ms)
     */
    @:optional var quickSuggestionsDelay:Int;
    /**
     * Controls the spacing around the editor.
     */
    @:optional var padding:IEditorPaddingOptions;
    /**
     * Options for auto closing brackets.
     * Defaults to language defined behavior.
     */
    @:optional var autoClosingBrackets:EditorAutoClosingStrategy;
    /**
     * Options for auto closing quotes.
     * Defaults to language defined behavior.
     */
    @:optional var autoClosingQuotes:EditorAutoClosingStrategy;
    /**
     * Options for pressing backspace near quotes or bracket pairs.
     */
    @:optional var autoClosingDelete:EditorAutoClosingEditStrategy;
    /**
     * Options for typing over closing quotes or brackets.
     */
    @:optional var autoClosingOvertype:EditorAutoClosingEditStrategy;
    /**
     * Options for auto surrounding.
     * Defaults to always allowing auto surrounding.
     */
    @:optional var autoSurround:EditorAutoSurroundStrategy;
    /**
     * Controls whether the editor should automatically adjust the indentation when users type, paste, move or indent lines:
     * `'none'`, `'keep'`, `'brackets'`, `'advanced'` or `'full'`.
     * Defaults to advanced.
     */
    @:optional var autoIndent:String;
    /**
     * Enable the suggestion box to pop-up on trigger characters.
     * Defaults to true.
     */
    @:optional var suggestOnTriggerCharacters:Bool;
    /**
     * Accept suggestions on ENTER: `'on'`, `'smart'` or `'off'`.
     * Defaults to 'on'.
     */
    @:optional var acceptSuggestionOnEnter:String;
    /**
     * Suggest options.
     */
    @:optional var suggest:ISuggestOptions;
    /**
     * Configure the behaviour of the go to location commands.
     */
    @:optional var gotoLocation:IGotoLocationOptions;
    /**
     * Configure the editor's hover.
     */
    @:optional var hover:IEditorHoverOptions;
    /**
     * Control the behavior of the find widget.
     */
    @:optional var find:cityscape.common.config.EditorFindOptions.IEditorFindOptions;
    /**
     * Control the behaviour of comments in the editor.
     */
    @:optional var comments:cityscape.common.config.EditorCommentsOptions.IEditorCommentsOptions;
    /**
     * Configuration options for inline suggestions (step 7, cs7-rest-inline).
     */
    @:optional var inlineSuggest:cityscape.common.config.EditorInlineSuggestOptions.IInlineSuggestOptions;
    /**
     * Controls whether the definition link opens element in the peek widget.
     * Defaults to false.
     */
    @:optional var definitionLinkOpensInPeek:Bool;
    /**
     * Controls whether to focus the inline editor or the tree in the peek
     * widget: `'tree'` (the default) or `'editor'`.
     */
    @:optional var peekWidgetDefaultFocus:String;
    /**
     * Enable highlighting of matching brackets: `'never'`, `'near'` or `'always'`.
     * Defaults to 'always'.
     */
    @:optional var matchBrackets:String;
    /**
     * Enable selection highlight.
     * Defaults to true.
     */
    @:optional var selectionHighlight:Bool;
    /**
     * Enable semantic occurrences highlight: `'off'`, `'singleFile'` or `'multiFile'`.
     * Defaults to 'singleFile'.
     */
    @:optional var occurrencesHighlight:String;
    /**
     * Enable code folding.
     * Defaults to true.
     */
    @:optional var folding:Bool;
    /**
     * Selects the folding strategy: `'auto'` or `'indentation'`.
     * Defaults to 'auto'.
     */
    @:optional var foldingStrategy:String;
    /**
     * Controls whether the fold actions in the gutter stay always visible or hide unless the mouse is over the gutter:
     * `'always'`, `'never'` or `'mouseover'`.
     * Defaults to 'mouseover'.
     */
    @:optional var showFoldingControls:String;
    /**
     * Enable highlight for folded regions.
     * Defaults to true.
     */
    @:optional var foldingHighlight:Bool;
    /**
     * Auto fold imports folding regions.
     * Defaults to true.
     */
    @:optional var foldingImportsByDefault:Bool;
    /**
     * Maximum number of foldable regions.
     * Defaults to 5000.
     */
    @:optional var foldingMaximumRegions:Int;
    /**
     * Controls whether clicking on the empty content after a folded line will unfold the line.
     * Defaults to false.
     */
    @:optional var unfoldOnClickAfterEndOfLine:Bool;
    /**
     * Enable rendering of control characters.
     * Defaults to true.
     */
    @:optional var renderControlCharacters:Bool;
    /**
     * Enable rendering of whitespace: `'none'`, `'boundary'`, `'selection'`,
     * `'trailing'` or `'all'`. Defaults to 'selection'.
     */
    @:optional var renderWhitespace:String;
    /**
     * Enable rendering of current line highlight: `'none'`, `'gutter'`,
     * `'line'` or `'all'`. Defaults to all.
     */
    @:optional var renderLineHighlight:String;
    /**
     * Render last line number when the file ends with a newline: `'off'`,
     * `'on'` or `'dimmed'`. Defaults to 'on' for Windows and macOS and 'dimmed' for Linux.
     */
    @:optional var renderFinalNewline:String;
    /**
     * Enable the rendering of the glyph margin.
     * Defaults to true in vscode and to false in monaco-editor.
     */
    @:optional var glyphMargin:Bool;
    /**
     * The width reserved for line decorations (in px), or a number of
     * characters (`'2ch'`). Defaults to 10.
     */
    @:optional var lineDecorationsWidth:EitherType<Float, String>;
    /**
     * Control the width of line numbers, by reserving horizontal space for
     * rendering at least an amount of digits. Defaults to 5.
     */
    @:optional var lineNumbersMinChars:Int;
    /**
     * Enable detecting links and making them clickable.
     * Defaults to true.
     */
    @:optional var links:Bool;
    /**
     * Enable inline color decorators and color picker rendering.
     */
    @:optional var colorDecorators:Bool;
    /**
     * Controls what is the condition to spawn a color picker from a color
     * dectorator: `'clickAndHover'` (the default), `'click'` or `'hover'`.
     */
    @:optional var colorDecoratorsActivatedOn:String;
    /**
     * Controls the max number of color decorators that can be rendered in
     * an editor at once (500 by default).
     */
    @:optional var colorDecoratorsLimit:Int;
    /**
     * Controls whether to use default color decorations or not using the
     * default document color provider (false by default).
     */
    @:optional var defaultColorDecorators:Bool;
    /**
     * The font family
     */
    @:optional var fontFamily:String;
    /**
     * The font weight
     */
    @:optional var fontWeight:String;
    /**
     * The font size
     */
    @:optional var fontSize:Float;
    /**
     * The line height
     */
    @:optional var lineHeight:Float;
    /**
     * The letter spacing
     */
    @:optional var letterSpacing:Float;

    // Read by the view (EditorViewOptions.hx)

    /**
     * Disable the optimizations for monospace fonts.
     * Defaults to false.
     */
    @:optional var disableMonospaceOptimizations:Bool;
    /**
     * Copying without a selection copies the current line.
     * Defaults to true.
     */
    @:optional var emptySelectionClipboard:Bool;
    /**
     * `'svg'`, `'font'` or `'off'`. Defaults to 'svg'.
     */
    @:optional var experimentalWhitespaceRendering:String;
    /**
     * Options for auto closing comments: `'always'`, `'languageDefined'`,
     * `'beforeWhitespace'` or `'never'`.
     * Defaults to language defined behavior.
     */
    @:optional var autoClosingComments:EditorAutoClosingStrategy;
    /**
     * Enable that the selection with the mouse and keys is doing column selection.
     * Defaults to false.
     */
    @:optional var columnSelection:Bool;
    /**
     * Syntax highlighting is copied.
     */
    @:optional var copyWithSyntaxHighlighting:Bool;
    /**
     * Controls when `cursorSurroundingLines` should be enforced:
     * `'default'` or `'all'`. Defaults to `default`.
     */
    @:optional var cursorSurroundingLinesStyle:String;
    /**
     * Merge overlapping selections.
     * Defaults to true
     */
    @:optional var multiCursorMergeOverlapping:Bool;
    /**
     * Configure the behaviour when pasting a text with the line count equal to the cursor count:
     * `'spread'` or `'full'`. Defaults to 'spread'.
     */
    @:optional var multiCursorPaste:String;
    /**
     * Controls the max number of text cursors that can be in an active editor at once.
     */
    @:optional var multiCursorLimit:Int;
    /**
     * Emulate selection behaviour of tab characters when using spaces for indentation.
     * This means selection will stick to tab stops.
     */
    @:optional var stickyTabStops:Bool;
    /**
     * Enable tab completion: `'on'`, `'off'` or `'onlySnippets'`.
     */
    @:optional var tabCompletion:String;
    /**
     * Accept suggestions on provider defined characters.
     * Defaults to true.
     */
    @:optional var acceptSuggestionOnCommitCharacter:Bool;
    /**
     * Enable snippet suggestions: `'top'`, `'bottom'`, `'inline'` or `'none'`.
     * Default to 'inline'.
     */
    @:optional var snippetSuggestions:String;
    /**
     * Font size for the suggest widget.
     * Defaults to the editor font size.
     */
    @:optional var suggestFontSize:Int;
    /**
     * Line height for the suggest widget.
     * Defaults to the editor line height.
     */
    @:optional var suggestLineHeight:Int;
    /**
     * The history mode for suggestions: `'first'`, `'recentlyUsed'` or
     * `'recentlyUsedByPrefix'`.
     */
    @:optional var suggestSelection:String;
    /**
     * Control the behavior and rendering of the code action lightbulb.
     */
    @:optional var lightbulb:cityscape.common.config.EditorLanguageFeatureOptions.IEditorLightbulbOptions;
    /**
     * Enable format on type.
     * Defaults to false.
     */
    @:optional var formatOnType:Bool;
    // Inlay hints and code lens (step 7, cs7-rest-inlay)
    /**
     * Show code lens
     * Defaults to true.
     */
    @:optional var codeLens:Bool;
    /**
     * Code lens font family. Defaults to editor font family.
     */
    @:optional var codeLensFontFamily:String;
    /**
     * Code lens font size. Default to 90% of the editor font size
     */
    @:optional var codeLensFontSize:Int;
    /**
     * Control the behavior and rendering of the inline hints.
     */
    @:optional var inlayHints:cityscape.common.config.EditorInlayHintsCodeLensOptions.IEditorInlayHintsOptions;
    /**
     * Parameter hint options.
     */
    @:optional var parameterHints:cityscape.common.config.EditorParameterHintsOptions.IEditorParameterHintOptions;
    /**
     * Inserting and deleting whitespace follows tab stops.
     */
    @:optional var useTabStops:Bool;
    /**
     * Locales to be used for word segmentation when doing word related navigations or operations.
     * Specify the BCP 47 language tag of the word you wish to recognize (e.g., ja, zh-CN, zh-Hant-TW, etc.).
     * A string or an array of strings. Defaults to empty array.
     */
    @:optional var wordSegmenterLocales:EitherType<String, Array<String>>;
    /**
     * Should the cursor be hidden in the overview ruler.
     * Defaults to false.
     */
    @:optional var hideCursorInOverviewRuler:Bool;
    /**
     * Controls if a border should be drawn around the overview ruler.
     * Defaults to `true`.
     */
    @:optional var overviewRulerBorder:Bool;
    /**
     * The number of vertical lanes the overview ruler should render.
     * Defaults to 3.
     */
    @:optional var overviewRulerLanes:Int;
    /**
     * Should the editor render the current line highlight only when the editor is focused.
     * Defaults to false.
     */
    @:optional var renderLineHighlightOnlyWhenFocus:Bool;
    /**
     * Performance guard: Stop rendering a line after x characters.
     * Defaults to 10000. Use -1 to never stop rendering
     */
    @:optional var stopRenderingLineAfter:Int;
    /**
     * Sets whether line breaks appear wherever the text would otherwise overflow its content box:
     * `'normal'` or `'keepAll'`. Defaults to 'normal'.
     */
    @:optional var wordBreak:String;
    /**
     * Configure word wrapping characters. A break will be introduced after these characters.
     */
    @:optional var wordWrapBreakAfterCharacters:String;
    /**
     * Configure word wrapping characters. A break will be introduced before these characters.
     */
    @:optional var wordWrapBreakBeforeCharacters:String;
    /**
     * Override the `wordWrap` setting: `'off'`, `'on'` or `'inherit'`.
     */
    @:optional var wordWrapOverride1:String;
    /**
     * Override the `wordWrapOverride1` setting: `'off'`, `'on'` or `'inherit'`.
     */
    @:optional var wordWrapOverride2:String;
    /**
     * Controls the wrapping strategy to use: `'simple'` or `'advanced'`.
     * Defaults to 'simple'.
     */
    @:optional var wrappingStrategy:String;
    /**
     * Controls whether the validation decorations are rendered: `'editable'`,
     * `'on'` or `'off'`. Defaults to 'editable'.
     */
    @:optional var renderValidationDecorations:String;
    // Semantic tokens (step 7, cs7-rest-sem)
    /**
     * Monaco's global editor option `'semanticHighlighting.enabled'`
     * (`IGlobalEditorOptions`, written to the configuration as
     * `editor.semanticHighlighting.enabled`), as `{enabled: value}`: `true`
     * (semantic highlighting for all themes), `false` (for none) or
     * `'configuredByTheme'` (the theme's `semanticHighlighting`, the
     * default). Not an editor option: the setting is global to the context.
     */
    @:optional var semanticHighlighting:{enabled:Any};
}

/**
 * An event describing that the configuration of the editor has changed.
 */
class ConfigurationChangedEvent {

    final _values:Array<Bool>;

    /**
     * @internal
     */
    public function new(values:Array<Bool>) {
        this._values = values;
    }

    public function hasChanged<V>(id:EditorOption<V>):Bool {
        return this._values[id] == true;
    }

}

/**
 * All computed editor options.
 */
interface IComputedEditorOptions {
    function get<V>(id:EditorOption<V>):V;
}

//#region IEditorOption

/**
 * @internal
 */
typedef IEnvironmentalOptions = {
    final memory:Null<ComputeOptionsMemory>;
    final outerWidth:Float;
    final outerHeight:Float;
    final fontInfo:FontInfo;
    final extraEditorClassName:String;
    final isDominatedByLongLines:Bool;
    final viewLineCount:Int;
    final lineNumbersDigitCount:Int;
    final emptySelectionClipboard:Bool;
    final pixelRatio:Float;
    final tabFocusMode:Bool;
    final accessibilitySupport:AccessibilitySupport;
    final glyphMarginDecorationLaneCount:Int;
}

/**
 * @internal
 *
 * Monaco keeps the stable minimap layout here; Cityscape has no minimap.
 * TODO(step 2): kept for the layout computation.
 */
class ComputeOptionsMemory {

    public function new() {}

}

interface IEditorOption<V> {
    final id:Int;
    final name:String;
    final defaultValue:V;
    /**
     * @internal
     */
    function validate(input:Any):V;
    /**
     * @internal
     */
    function compute(env:IEnvironmentalOptions, options:IComputedEditorOptions, value:V):V;

    /**
     * Might modify `value`.
     */
    function applyUpdate(value:Null<V>, update:V):ApplyUpdateResult<V>;
}

/**
 * @internal
 */
abstract class BaseEditorOption<V> implements IEditorOption<V> {

    public final id:Int;
    public final name:String;
    public final defaultValue:V;

    public function new(id:Int, name:String, defaultValue:V) {
        this.id = id;
        this.name = name;
        this.defaultValue = defaultValue;
    }

    public function applyUpdate(value:Null<V>, update:V):ApplyUpdateResult<V> {
        return EditorOptions.applyUpdate(value, update);
    }

    abstract public function validate(input:Any):V;

    public function compute(env:IEnvironmentalOptions, options:IComputedEditorOptions, value:V):V {
        return value;
    }

}

class ApplyUpdateResult<T> {

    public final newValue:T;

    public final didChange:Bool;

    public function new(newValue:T, didChange:Bool) {
        this.newValue = newValue;
        this.didChange = didChange;
    }

}

/**
 * @internal
 */
abstract class ComputedEditorOption<V> implements IEditorOption<V> {

    public final id:Int;
    public final name:String;
    public final defaultValue:V;

    public function new(id:Int) {
        this.id = id;
        this.name = '_never_';
        this.defaultValue = null;
    }

    public function applyUpdate(value:Null<V>, update:V):ApplyUpdateResult<V> {
        return EditorOptions.applyUpdate(value, update);
    }

    public function validate(input:Any):V {
        return this.defaultValue;
    }

    abstract public function compute(env:IEnvironmentalOptions, options:IComputedEditorOptions, value:V):V;

}

class SimpleEditorOption<V> implements IEditorOption<V> {

    public final id:Int;
    public final name:String;
    public final defaultValue:V;

    public function new(id:Int, name:String, defaultValue:V) {
        this.id = id;
        this.name = name;
        this.defaultValue = defaultValue;
    }

    public function applyUpdate(value:Null<V>, update:V):ApplyUpdateResult<V> {
        return EditorOptions.applyUpdate(value, update);
    }

    public function validate(input:Any):V {
        if (JsValues.isUndefined(input)) {
            return this.defaultValue;
        }
        return cast input;
    }

    public function compute(env:IEnvironmentalOptions, options:IComputedEditorOptions, value:V):V {
        return value;
    }

}

class EditorBooleanOption extends SimpleEditorOption<Bool> {

    public function new(id:Int, name:String, defaultValue:Bool) {
        super(id, name, defaultValue);
    }

    override public function validate(input:Any):Bool {
        return EditorOptions.boolean(input, this.defaultValue);
    }

}

class EditorIntOption extends SimpleEditorOption<Int> {

    public static function clampedInt(value:Any, defaultValue:Int, minimum:Int, maximum:Int):Int {
        return EditorOptions.clampedInt(value, defaultValue, minimum, maximum);
    }

    public final minimum:Int;
    public final maximum:Int;

    public function new(id:Int, name:String, defaultValue:Int, minimum:Int, maximum:Int) {
        super(id, name, defaultValue);
        this.minimum = minimum;
        this.maximum = maximum;
    }

    override public function validate(input:Any):Int {
        return EditorIntOption.clampedInt(input, this.defaultValue, this.minimum, this.maximum);
    }

}

class EditorFloatOption extends SimpleEditorOption<Float> {

    public static function clamp(n:Float, min:Float, max:Float):Float {
        if (n < min) {
            return min;
        }
        if (n > max) {
            return max;
        }
        return n;
    }

    public static function float(value:Any, defaultValue:Float):Float {
        if (JsValues.isNumber(value)) {
            return (value : Float);
        }
        if (JsValues.isUndefined(value)) {
            return defaultValue;
        }
        final r = JsValues.parseFloat(value);
        return (Math.isNaN(r) ? defaultValue : r);
    }

    public final validationFn:(value:Float) -> Float;

    public function new(id:Int, name:String, defaultValue:Float, validationFn:(value:Float) -> Float) {
        super(id, name, defaultValue);
        this.validationFn = validationFn;
    }

    override public function validate(input:Any):Float {
        return this.validationFn(EditorFloatOption.float(input, this.defaultValue));
    }

}

class EditorStringOption extends SimpleEditorOption<String> {

    public static function string(value:Any, defaultValue:String):String {
        if (!JsValues.isString(value)) {
            return defaultValue;
        }
        return (value : String);
    }

    public function new(id:Int, name:String, defaultValue:String) {
        super(id, name, defaultValue);
    }

    override public function validate(input:Any):String {
        return EditorStringOption.string(input, this.defaultValue);
    }

}

class EditorStringEnumOption extends SimpleEditorOption<String> {

    final _allowedValues:Array<String>;

    public function new(id:Int, name:String, defaultValue:String, allowedValues:Array<String>) {
        super(id, name, defaultValue);
        this._allowedValues = allowedValues;
    }

    override public function validate(input:Any):String {
        return EditorOptions.stringSet(input, this.defaultValue, this._allowedValues);
    }

}

class EditorEnumOption<V> extends BaseEditorOption<V> {

    final _allowedValues:Array<String>;
    final _convert:(value:String) -> V;

    public function new(id:Int, name:String, defaultValue:V, defaultStringValue:String, allowedValues:Array<String>, convert:(value:String) -> V) {
        super(id, name, defaultValue);
        this._allowedValues = allowedValues;
        this._convert = convert;
    }

    public function validate(input:Any):V {
        if (!JsValues.isString(input)) {
            return this.defaultValue;
        }
        if (this._allowedValues.indexOf((input : String)) == -1) {
            return this.defaultValue;
        }
        return this._convert((input : String));
    }

}

//#endregion

//#region autoIndent

private function _autoIndentFromString(autoIndent:String):EditorAutoIndentStrategy {
    return switch (autoIndent) {
        case 'none': EditorAutoIndentStrategy.None;
        case 'keep': EditorAutoIndentStrategy.Keep;
        case 'brackets': EditorAutoIndentStrategy.Brackets;
        case 'advanced': EditorAutoIndentStrategy.Advanced;
        case _: EditorAutoIndentStrategy.Full;
    }
}

//#endregion

//#region accessibilitySupport

class EditorAccessibilitySupport extends BaseEditorOption<AccessibilitySupport> {

    public function new() {
        super(EditorOption.accessibilitySupport, 'accessibilitySupport', AccessibilitySupport.Unknown);
    }

    public function validate(input:Any):AccessibilitySupport {
        if (JsValues.isString(input)) {
            switch ((input : String)) {
                case 'auto': return AccessibilitySupport.Unknown;
                case 'off': return AccessibilitySupport.Disabled;
                case 'on': return AccessibilitySupport.Enabled;
                case _:
            }
        }
        return this.defaultValue;
    }

    override public function compute(env:IEnvironmentalOptions, options:IComputedEditorOptions, value:AccessibilitySupport):AccessibilitySupport {
        if (value == AccessibilitySupport.Unknown) {
            // The editor reads the `accessibilitySupport` from the environment
            return env.accessibilitySupport;
        }
        return value;
    }

}

//#endregion

//#region cursorBlinking

/**
 * The kind of animation in which the editor's cursor should be rendered.
 */
enum abstract TextEditorCursorBlinkingStyle(Int) from Int to Int {
    /**
     * Hidden
     */
    var Hidden = 0;
    /**
     * Blinking
     */
    var Blink = 1;
    /**
     * Blinking with smooth fading
     */
    var Smooth = 2;
    /**
     * Blinking with prolonged filled state and smooth fading
     */
    var Phase = 3;
    /**
     * Expand collapse animation on the y axis
     */
    var Expand = 4;
    /**
     * No-Blinking
     */
    var Solid = 5;
}

private function _cursorBlinkingStyleFromString(cursorBlinkingStyle:String):TextEditorCursorBlinkingStyle {
    return switch (cursorBlinkingStyle) {
        case 'blink': TextEditorCursorBlinkingStyle.Blink;
        case 'smooth': TextEditorCursorBlinkingStyle.Smooth;
        case 'phase': TextEditorCursorBlinkingStyle.Phase;
        case 'expand': TextEditorCursorBlinkingStyle.Expand;
        case _: TextEditorCursorBlinkingStyle.Solid;
    }
}

//#endregion

//#region cursorStyle

/**
 * The style in which the editor's cursor should be rendered.
 */
enum abstract TextEditorCursorStyle(Int) from Int to Int {
    /**
     * As a vertical line (sitting between two characters).
     */
    var Line = 1;
    /**
     * As a block (sitting on top of a character).
     */
    var Block = 2;
    /**
     * As a horizontal line (sitting under a character).
     */
    var Underline = 3;
    /**
     * As a thin vertical line (sitting between two characters).
     */
    var LineThin = 4;
    /**
     * As an outlined block (sitting on top of a character).
     */
    var BlockOutline = 5;
    /**
     * As a thin horizontal line (sitting under a character).
     */
    var UnderlineThin = 6;
}

class TextEditorCursorStyleUtils {

    /**
     * @internal
     */
    public static function cursorStyleToString(cursorStyle:TextEditorCursorStyle):String {
        return switch (cursorStyle) {
            case TextEditorCursorStyle.Line: 'line';
            case TextEditorCursorStyle.Block: 'block';
            case TextEditorCursorStyle.Underline: 'underline';
            case TextEditorCursorStyle.LineThin: 'line-thin';
            case TextEditorCursorStyle.BlockOutline: 'block-outline';
            case TextEditorCursorStyle.UnderlineThin: 'underline-thin';
            case _: null;
        }
    }

}

private function _cursorStyleFromString(cursorStyle:String):TextEditorCursorStyle {
    return switch (cursorStyle) {
        case 'line': TextEditorCursorStyle.Line;
        case 'block': TextEditorCursorStyle.Block;
        case 'underline': TextEditorCursorStyle.Underline;
        case 'line-thin': TextEditorCursorStyle.LineThin;
        case 'block-outline': TextEditorCursorStyle.BlockOutline;
        case _: TextEditorCursorStyle.UnderlineThin;
    }
}

//#endregion

//#region fontLigatures

/**
 * @internal
 */
class EditorFontLigatures extends BaseEditorOption<String> {

    public static final OFF = '"liga" off, "calt" off';
    public static final ON = '"liga" on, "calt" on';

    public function new() {
        super(EditorOption.fontLigatures, 'fontLigatures', EditorFontLigatures.OFF);
    }

    public function validate(input:Any):String {
        if (JsValues.isUndefined(input)) {
            return this.defaultValue;
        }
        if (JsValues.isString(input)) {
            final s:String = input;
            if (s == 'false' || s.length == 0) {
                return EditorFontLigatures.OFF;
            }
            if (s == 'true') {
                return EditorFontLigatures.ON;
            }
            return s;
        }
        if (JsValues.truthy(input)) {
            return EditorFontLigatures.ON;
        }
        return EditorFontLigatures.OFF;
    }

}

//#endregion

//#region fontSize

class EditorFontSize extends SimpleEditorOption<Float> {

    public function new() {
        super(EditorOption.fontSize, 'fontSize', EditorOptions.EDITOR_FONT_DEFAULTS.fontSize);
    }

    override public function validate(input:Any):Float {
        final r = EditorFloatOption.float(input, this.defaultValue);
        if (r == 0) {
            return EditorOptions.EDITOR_FONT_DEFAULTS.fontSize;
        }
        return EditorFloatOption.clamp(r, 6, 100);
    }

    override public function compute(env:IEnvironmentalOptions, options:IComputedEditorOptions, value:Float):Float {
        // The final fontSize respects the editor zoom level.
        // So take the result from env.fontInfo
        return env.fontInfo.fontSize;
    }

}

//#endregion

//#region fontWeight

class EditorFontWeight extends BaseEditorOption<String> {

    static final SUGGESTION_VALUES = ['normal', 'bold', '100', '200', '300', '400', '500', '600', '700', '800', '900'];
    static inline final MINIMUM_VALUE = 1;
    static inline final MAXIMUM_VALUE = 1000;

    public function new() {
        super(EditorOption.fontWeight, 'fontWeight', EditorOptions.EDITOR_FONT_DEFAULTS.fontWeight);
    }

    public function validate(input:Any):String {
        if (JsValues.isString(input) && ((input : String) == 'normal' || (input : String) == 'bold')) {
            return input;
        }
        // String(EditorIntOption.clampedInt(input, EDITOR_FONT_DEFAULTS.fontWeight, 1, 1000)):
        // the default is a string, returned as is when `input` is not a number
        if (JsValues.isUndefined(input) || Math.isNaN(JsValues.parseInt(input))) {
            return EditorOptions.EDITOR_FONT_DEFAULTS.fontWeight;
        }
        return Std.string(EditorIntOption.clampedInt(input, 0, EditorFontWeight.MINIMUM_VALUE, EditorFontWeight.MAXIMUM_VALUE));
    }

}

//#endregion

//#region gotoLocation

/**
 * `'peek'`, `'gotoAndPeek'` or `'goto'`.
 */
typedef GoToLocationValues = String;

/**
 * Configuration options for go to location
 */
typedef IGotoLocationOptions = {
    @:optional var multiple:GoToLocationValues;
    @:optional var multipleDefinitions:GoToLocationValues;
    @:optional var multipleTypeDefinitions:GoToLocationValues;
    @:optional var multipleDeclarations:GoToLocationValues;
    @:optional var multipleImplementations:GoToLocationValues;
    @:optional var multipleReferences:GoToLocationValues;
    @:optional var multipleTests:GoToLocationValues;
    @:optional var alternativeDefinitionCommand:String;
    @:optional var alternativeTypeDefinitionCommand:String;
    @:optional var alternativeDeclarationCommand:String;
    @:optional var alternativeImplementationCommand:String;
    @:optional var alternativeReferenceCommand:String;
    @:optional var alternativeTestsCommand:String;
}

/**
 * @internal
 */
typedef GoToLocationOptions = {
    final multiple:GoToLocationValues;
    final multipleDefinitions:GoToLocationValues;
    final multipleTypeDefinitions:GoToLocationValues;
    final multipleDeclarations:GoToLocationValues;
    final multipleImplementations:GoToLocationValues;
    final multipleReferences:GoToLocationValues;
    final multipleTests:GoToLocationValues;
    final alternativeDefinitionCommand:String;
    final alternativeTypeDefinitionCommand:String;
    final alternativeDeclarationCommand:String;
    final alternativeImplementationCommand:String;
    final alternativeReferenceCommand:String;
    final alternativeTestsCommand:String;
}

class EditorGoToLocation extends BaseEditorOption<GoToLocationOptions> {

    public function new() {
        final defaults:GoToLocationOptions = {
            multiple: 'peek',
            multipleDefinitions: 'peek',
            multipleTypeDefinitions: 'peek',
            multipleDeclarations: 'peek',
            multipleImplementations: 'peek',
            multipleReferences: 'peek',
            multipleTests: 'peek',
            alternativeDefinitionCommand: 'editor.action.goToReferences',
            alternativeTypeDefinitionCommand: 'editor.action.goToReferences',
            alternativeDeclarationCommand: 'editor.action.goToReferences',
            alternativeImplementationCommand: '',
            alternativeReferenceCommand: '',
            alternativeTestsCommand: '',
        };
        super(EditorOption.gotoLocation, 'gotoLocation', defaults);
    }

    /**
     * `input.multipleX ?? stringSet(input.multipleX, 'peek', ...)`: a string
     * is kept as given, without checking it is an allowed value, like Monaco.
     */
    static function multipleValue(input:Any, name:String):GoToLocationValues {
        final value = JsValues.field(input, name);
        if (JsValues.isString(value)) {
            return (value : String);
        }
        return EditorOptions.stringSet(value, 'peek', ['peek', 'gotoAndPeek', 'goto']);
    }

    public function validate(_input:Any):GoToLocationOptions {
        if (!JsValues.truthy(_input) || !JsValues.isObject(_input)) {
            return this.defaultValue;
        }
        final input = _input;
        return {
            multiple: EditorOptions.stringSet(JsValues.field(input, 'multiple'), this.defaultValue.multiple, ['peek', 'gotoAndPeek', 'goto']),
            multipleDefinitions: multipleValue(input, 'multipleDefinitions'),
            multipleTypeDefinitions: multipleValue(input, 'multipleTypeDefinitions'),
            multipleDeclarations: multipleValue(input, 'multipleDeclarations'),
            multipleImplementations: multipleValue(input, 'multipleImplementations'),
            multipleReferences: multipleValue(input, 'multipleReferences'),
            multipleTests: multipleValue(input, 'multipleTests'),
            alternativeDefinitionCommand: EditorStringOption.string(JsValues.field(input, 'alternativeDefinitionCommand'), this.defaultValue.alternativeDefinitionCommand),
            alternativeTypeDefinitionCommand: EditorStringOption.string(JsValues.field(input, 'alternativeTypeDefinitionCommand'), this.defaultValue.alternativeTypeDefinitionCommand),
            alternativeDeclarationCommand: EditorStringOption.string(JsValues.field(input, 'alternativeDeclarationCommand'), this.defaultValue.alternativeDeclarationCommand),
            alternativeImplementationCommand: EditorStringOption.string(JsValues.field(input, 'alternativeImplementationCommand'), this.defaultValue.alternativeImplementationCommand),
            alternativeReferenceCommand: EditorStringOption.string(JsValues.field(input, 'alternativeReferenceCommand'), this.defaultValue.alternativeReferenceCommand),
            alternativeTestsCommand: EditorStringOption.string(JsValues.field(input, 'alternativeTestsCommand'), this.defaultValue.alternativeTestsCommand),
        };
    }

}

//#endregion

//#region hover

/**
 * Configuration options for editor hover
 */
typedef IEditorHoverOptions = {
    /**
     * Enable the hover.
     * Defaults to true.
     */
    @:optional var enabled:Bool;
    /**
     * Delay for showing the hover.
     * Defaults to 300.
     */
    @:optional var delay:Int;
    /**
     * Is the hover sticky such that it can be clicked and its contents selected?
     * Defaults to true.
     */
    @:optional var sticky:Bool;
    /**
     * Controls how long the hover is visible after you hovered out of it.
     * Require sticky setting to be true.
     */
    @:optional var hidingDelay:Int;
    /**
     * Should the hover be shown above the line if possible?
     * Defaults to false.
     */
    @:optional var above:Bool;
}

/**
 * @internal
 */
typedef EditorHoverOptions = {
    final enabled:Bool;
    final delay:Int;
    final sticky:Bool;
    final hidingDelay:Int;
    final above:Bool;
}

class EditorHover extends BaseEditorOption<EditorHoverOptions> {

    public function new() {
        final defaults:EditorHoverOptions = {
            enabled: true,
            delay: 300,
            hidingDelay: 300,
            sticky: true,
            above: true,
        };
        super(EditorOption.hover, 'hover', defaults);
    }

    public function validate(_input:Any):EditorHoverOptions {
        if (!JsValues.truthy(_input) || !JsValues.isObject(_input)) {
            return this.defaultValue;
        }
        final input = _input;
        return {
            enabled: EditorOptions.boolean(JsValues.field(input, 'enabled'), this.defaultValue.enabled),
            delay: EditorIntOption.clampedInt(JsValues.field(input, 'delay'), this.defaultValue.delay, 0, 10000),
            sticky: EditorOptions.boolean(JsValues.field(input, 'sticky'), this.defaultValue.sticky),
            hidingDelay: EditorIntOption.clampedInt(JsValues.field(input, 'hidingDelay'), this.defaultValue.hidingDelay, 0, 600000),
            above: EditorOptions.boolean(JsValues.field(input, 'above'), this.defaultValue.above),
        };
    }

}

//#endregion

//#region stickyScroll

typedef IEditorStickyScrollOptions = {
    /**
     * Enable the sticky scroll
     */
    @:optional var enabled:Bool;
    /**
     * Maximum number of sticky lines to show
     */
    @:optional var maxLineCount:Int;
    /**
     * Model to choose for sticky scroll by default: `'outlineModel'`,
     * `'foldingProviderModel'` or `'indentationModel'`.
     */
    @:optional var defaultModel:String;
    /**
     * Define whether to scroll sticky scroll with editor horizontal scrollbae
     */
    @:optional var scrollWithEditor:Bool;
}

/**
 * @internal
 */
typedef EditorStickyScrollOptions = {
    final enabled:Bool;
    final maxLineCount:Int;
    final defaultModel:String;
    final scrollWithEditor:Bool;
}

class EditorStickyScroll extends BaseEditorOption<EditorStickyScrollOptions> {

    public function new() {
        final defaults:EditorStickyScrollOptions = {enabled: true, maxLineCount: 5, defaultModel: 'outlineModel', scrollWithEditor: true};
        super(EditorOption.stickyScroll, 'stickyScroll', defaults);
    }

    public function validate(_input:Any):EditorStickyScrollOptions {
        if (!JsValues.truthy(_input) || !JsValues.isObject(_input)) {
            return this.defaultValue;
        }
        final input = _input;
        return {
            enabled: EditorOptions.boolean(JsValues.field(input, 'enabled'), this.defaultValue.enabled),
            maxLineCount: EditorIntOption.clampedInt(JsValues.field(input, 'maxLineCount'), this.defaultValue.maxLineCount, 1, 20),
            defaultModel: EditorOptions.stringSet(JsValues.field(input, 'defaultModel'), this.defaultValue.defaultModel, ['outlineModel', 'foldingProviderModel', 'indentationModel']),
            scrollWithEditor: EditorOptions.boolean(JsValues.field(input, 'scrollWithEditor'), this.defaultValue.scrollWithEditor)
        };
    }

}

//#endregion

//#region bracketPairColorization

typedef IBracketPairColorizationOptions = {
    /**
     * Enable or disable bracket pair colorization.
     */
    @:optional var enabled:Bool;
    /**
     * Use independent color pool per bracket type.
     */
    @:optional var independentColorPoolPerBracketType:Bool;
}

/**
 * @internal
 */
typedef InternalBracketPairColorizationOptions = {
    final enabled:Bool;
    final independentColorPoolPerBracketType:Bool;
}

/**
 * Configuration options for inline suggestions
 */
class BracketPairColorization extends BaseEditorOption<InternalBracketPairColorizationOptions> {

    public function new() {
        final defaults:InternalBracketPairColorizationOptions = {
            enabled: cityscape.common.core.TextModelDefaults.EDITOR_MODEL_DEFAULTS.bracketPairColorizationOptions.enabled,
            independentColorPoolPerBracketType: cityscape.common.core.TextModelDefaults.EDITOR_MODEL_DEFAULTS.bracketPairColorizationOptions.independentColorPoolPerBracketType,
        };
        super(EditorOption.bracketPairColorization, 'bracketPairColorization', defaults);
    }

    public function validate(_input:Any):InternalBracketPairColorizationOptions {
        if (!JsValues.truthy(_input) || !JsValues.isObject(_input)) {
            return this.defaultValue;
        }
        final input = _input;
        return {
            enabled: EditorOptions.boolean(JsValues.field(input, 'enabled'), this.defaultValue.enabled),
            independentColorPoolPerBracketType: EditorOptions.boolean(JsValues.field(input, 'independentColorPoolPerBracketType'), this.defaultValue.independentColorPoolPerBracketType),
        };
    }

}

//#endregion

//#region guides

typedef IGuidesOptions = {
    /**
     * Enable rendering of bracket pair guides: `true`, `false` or `'active'`.
     * Defaults to false.
     */
    @:optional var bracketPairs:Any;
    /**
     * Enable rendering of vertical bracket pair guides: `true`, `false` or
     * `'active'`. Defaults to 'active'.
     */
    @:optional var bracketPairsHorizontal:Any;
    /**
     * Enable highlighting of the active bracket pair.
     * Defaults to true.
     */
    @:optional var highlightActiveBracketPair:Bool;
    /**
     * Enable rendering of indent guides.
     * Defaults to true.
     */
    @:optional var indentation:Bool;
    /**
     * Enable highlighting of the active indent guide: `true`, `false` or
     * `'always'`. Defaults to true.
     */
    @:optional var highlightActiveIndentation:Any;
}

/**
 * @internal
 *
 * `bracketPairs` and `bracketPairsHorizontal` are `true`, `false` or
 * `'active'`; `highlightActiveIndentation` is `true`, `false` or
 * `'always'` (Monaco's `boolean | string` values, compared with
 * `JsValues`).
 */
typedef InternalGuidesOptions = {
    final bracketPairs:Any;
    final bracketPairsHorizontal:Any;
    final highlightActiveBracketPair:Bool;
    final indentation:Bool;
    final highlightActiveIndentation:Any;
}

/**
 * Configuration options for inline suggestions
 */
class GuideOptions extends BaseEditorOption<InternalGuidesOptions> {

    public function new() {
        final defaults:InternalGuidesOptions = {
            bracketPairs: false,
            bracketPairsHorizontal: 'active',
            highlightActiveBracketPair: true,
            indentation: true,
            highlightActiveIndentation: true
        };
        super(EditorOption.guides, 'guides', defaults);
    }

    public function validate(_input:Any):InternalGuidesOptions {
        if (!JsValues.truthy(_input) || !JsValues.isObject(_input)) {
            return this.defaultValue;
        }
        final input = _input;
        return {
            bracketPairs: primitiveSet(JsValues.field(input, 'bracketPairs'), this.defaultValue.bracketPairs, [true, false, 'active']),
            bracketPairsHorizontal: primitiveSet(JsValues.field(input, 'bracketPairsHorizontal'), this.defaultValue.bracketPairsHorizontal, [true, false, 'active']),
            highlightActiveBracketPair: EditorOptions.boolean(JsValues.field(input, 'highlightActiveBracketPair'), this.defaultValue.highlightActiveBracketPair),
            indentation: EditorOptions.boolean(JsValues.field(input, 'indentation'), this.defaultValue.indentation),
            highlightActiveIndentation: primitiveSet(JsValues.field(input, 'highlightActiveIndentation'), this.defaultValue.highlightActiveIndentation, [true, false, 'always']),
        };
    }

    /**
     * `allowedValues.indexOf(value)` with JavaScript's strict equality
     * (a boolean or a string).
     */
    static function primitiveSet(value:Any, defaultValue:Any, allowedValues:Array<Any>):Any {
        for (allowed in allowedValues) {
            if (JsValues.isString(allowed)) {
                if (JsValues.isString(value) && (value : String) == (allowed : String)) {
                    return allowed;
                }
            }
            else if (JsValues.isBoolean(value) && (value : Bool) == (allowed : Bool)) {
                return allowed;
            }
        }
        return defaultValue;
    }

}

//#endregion

//#region lineDecorationsWidth

class EditorLineDecorationsWidth extends BaseEditorOption<Float> {

    public function new() {
        super(EditorOption.lineDecorationsWidth, 'lineDecorationsWidth', 10);
    }

    /**
     * `/^\d+(\.\d+)?ch$/`
     */
    static function isChMultiple(s:String):Bool {
        final len = s.length;
        if (len < 3 || s.substr(len - 2) != 'ch')
            return false;
        final n = s.substr(0, len - 2);
        var i = 0;
        var digits = 0;
        while (i < n.length && n.charCodeAt(i) >= '0'.code && n.charCodeAt(i) <= '9'.code) {
            i++;
            digits++;
        }
        if (digits == 0)
            return false;
        if (i == n.length)
            return true;
        if (n.charCodeAt(i) != '.'.code)
            return false;
        i++;
        var fraction = 0;
        while (i < n.length && n.charCodeAt(i) >= '0'.code && n.charCodeAt(i) <= '9'.code) {
            i++;
            fraction++;
        }
        return fraction > 0 && i == n.length;
    }

    public function validate(input:Any):Float {
        if (JsValues.isString(input) && isChMultiple((input : String))) {
            final s:String = input;
            final multiple = JsValues.parseFloat(s.substring(0, s.length - 2));
            return -multiple; // negative numbers signal a multiple
        }
        else {
            return EditorIntOption.clampedInt(input, Std.int(this.defaultValue), 0, 1000);
        }
    }

    override public function compute(env:IEnvironmentalOptions, options:IComputedEditorOptions, value:Float):Float {
        if (value < 0) {
            // negative numbers signal a multiple
            return EditorIntOption.clampedInt(-value * env.fontInfo.typicalHalfwidthCharacterWidth, Std.int(this.defaultValue), 0, 1000);
        }
        else {
            return value;
        }
    }

}

//#endregion

//#region lineHeight

class EditorLineHeight extends EditorFloatOption {

    public function new() {
        super(EditorOption.lineHeight, 'lineHeight', EditorOptions.EDITOR_FONT_DEFAULTS.lineHeight, x -> EditorFloatOption.clamp(x, 0, 150));
    }

    override public function compute(env:IEnvironmentalOptions, options:IComputedEditorOptions, value:Float):Float {
        // The lineHeight is computed from the fontSize if it is 0.
        // Moreover, the final lineHeight respects the editor zoom level.
        // So take the result from env.fontInfo
        return env.fontInfo.lineHeight;
    }

}

//#endregion

//#region multiCursorModifier

/**
 * `'altKey'`, `'metaKey'` or `'ctrlKey'`.
 */
private function _multiCursorModifierFromString(multiCursorModifier:String):String {
    if (multiCursorModifier == 'ctrlCmd') {
        return (Platform.isMacintosh ? 'metaKey' : 'ctrlKey');
    }
    return 'altKey';
}

//#endregion

//#region padding

/**
 * Configuration options for editor padding
 */
typedef IEditorPaddingOptions = {
    /**
     * Spacing between top edge of editor and first line.
     */
    @:optional var top:Int;
    /**
     * Spacing between bottom edge of editor and last line.
     */
    @:optional var bottom:Int;
}

/**
 * @internal
 */
typedef InternalEditorPaddingOptions = {
    final top:Int;
    final bottom:Int;
}

class EditorPadding extends BaseEditorOption<InternalEditorPaddingOptions> {

    public function new() {
        super(EditorOption.padding, 'padding', {top: 0, bottom: 0});
    }

    public function validate(_input:Any):InternalEditorPaddingOptions {
        if (!JsValues.truthy(_input) || !JsValues.isObject(_input)) {
            return this.defaultValue;
        }
        final input = _input;
        return {
            top: EditorIntOption.clampedInt(JsValues.field(input, 'top'), 0, 0, 1000),
            bottom: EditorIntOption.clampedInt(JsValues.field(input, 'bottom'), 0, 0, 1000)
        };
    }

}

//#endregion

//#region quickSuggestions

/**
 * `'on'`, `'inline'` or `'off'`.
 */
typedef QuickSuggestionsValue = String;

/**
 * Configuration options for quick suggestions
 */
typedef IQuickSuggestionsOptions = {
    @:optional var other:EitherType<Bool, QuickSuggestionsValue>;
    @:optional var comments:EitherType<Bool, QuickSuggestionsValue>;
    @:optional var strings:EitherType<Bool, QuickSuggestionsValue>;
}

typedef InternalQuickSuggestionsOptions = {
    final other:QuickSuggestionsValue;
    final comments:QuickSuggestionsValue;
    final strings:QuickSuggestionsValue;
}

class EditorQuickSuggestions extends BaseEditorOption<InternalQuickSuggestionsOptions> {

    public function new() {
        final defaults:InternalQuickSuggestionsOptions = {
            other: 'on',
            comments: 'off',
            strings: 'off'
        };
        super(EditorOption.quickSuggestions, 'quickSuggestions', defaults);
    }

    static function validateValue(value:Any, defaultValue:QuickSuggestionsValue):QuickSuggestionsValue {
        if (JsValues.isBoolean(value)) {
            return (value : Bool) ? 'on' : 'off';
        }
        return EditorOptions.stringSet(value, defaultValue, ['on', 'inline', 'off']);
    }

    public function validate(input:Any):InternalQuickSuggestionsOptions {
        if (JsValues.isBoolean(input)) {
            // boolean -> all on/off
            final value = (input : Bool) ? 'on' : 'off';
            return {comments: value, strings: value, other: value};
        }
        if (!JsValues.truthy(input) || !JsValues.isObject(input)) {
            // invalid object
            return this.defaultValue;
        }

        return {
            other: validateValue(JsValues.field(input, 'other'), this.defaultValue.other),
            comments: validateValue(JsValues.field(input, 'comments'), this.defaultValue.comments),
            strings: validateValue(JsValues.field(input, 'strings'), this.defaultValue.strings)
        };
    }

}

//#endregion

//#region renderLineNumbers

/**
 * `'on'`, `'off'`, `'relative'`, `'interval'` or a function that renders a
 * line number.
 */
typedef LineNumbersType = EitherType<String, (lineNumber:Int) -> String>;

enum abstract RenderLineNumbersType(Int) from Int to Int {
    var Off = 0;
    var On = 1;
    var Relative = 2;
    var Interval = 3;
    var Custom = 4;
}

typedef InternalEditorRenderLineNumbersOptions = {
    final renderType:RenderLineNumbersType;
    final renderFn:Null<(lineNumber:Int) -> String>;
}

class EditorRenderLineNumbersOption extends BaseEditorOption<InternalEditorRenderLineNumbersOptions> {

    public function new() {
        super(EditorOption.lineNumbers, 'lineNumbers', {renderType: RenderLineNumbersType.On, renderFn: null});
    }

    public function validate(lineNumbers:Any):InternalEditorRenderLineNumbersOptions {
        var renderType:RenderLineNumbersType = this.defaultValue.renderType;
        var renderFn:Null<(lineNumber:Int) -> String> = this.defaultValue.renderFn;

        if (!JsValues.isUndefined(lineNumbers)) {
            if (JsValues.isFunction(lineNumbers)) {
                renderType = RenderLineNumbersType.Custom;
                renderFn = cast lineNumbers;
            }
            else if (JsValues.isString(lineNumbers) && (lineNumbers : String) == 'interval') {
                renderType = RenderLineNumbersType.Interval;
            }
            else if (JsValues.isString(lineNumbers) && (lineNumbers : String) == 'relative') {
                renderType = RenderLineNumbersType.Relative;
            }
            else if (JsValues.isString(lineNumbers) && (lineNumbers : String) == 'on') {
                renderType = RenderLineNumbersType.On;
            }
            else {
                renderType = RenderLineNumbersType.Off;
            }
        }

        return {
            renderType: renderType,
            renderFn: renderFn
        };
    }

}

//#endregion

//#region rulers

typedef IRulerOption = {
    final column:Int;
    final color:Null<String>;
}

class EditorRulers extends BaseEditorOption<Array<IRulerOption>> {

    public function new() {
        final defaults:Array<IRulerOption> = [];
        super(EditorOption.rulers, 'rulers', defaults);
    }

    public function validate(input:Any):Array<IRulerOption> {
        if (JsValues.isArray(input)) {
            final rulers:Array<IRulerOption> = [];
            final array:Array<Any> = input;
            for (_element in array) {
                if (JsValues.isNumber(_element)) {
                    rulers.push({
                        column: EditorIntOption.clampedInt(_element, 0, 0, 10000),
                        color: null
                    });
                }
                else if (JsValues.truthy(_element) && JsValues.isObject(_element)) {
                    final color = JsValues.field(_element, 'color');
                    rulers.push({
                        column: EditorIntOption.clampedInt(JsValues.field(_element, 'column'), 0, 0, 10000),
                        color: JsValues.isString(color) ? (color : String) : null
                    });
                }
            }
            // Stable sort, like JavaScript's Array.prototype.sort
            haxe.ds.ArraySort.sort(rulers, (a, b) -> a.column - b.column);
            return rulers;
        }
        return this.defaultValue;
    }

}

//#endregion

//#region scrollbar

/**
 * Configuration options for editor scrollbars
 */
typedef IEditorScrollbarOptions = {
    /**
     * The size of arrows (if displayed).
     * Defaults to 11.
     * **NOTE**: This option cannot be updated using `updateOptions()`
     */
    @:optional var arrowSize:Int;
    /**
     * Render vertical scrollbar: `'auto'`, `'visible'` or `'hidden'`.
     * Defaults to 'auto'.
     */
    @:optional var vertical:String;
    /**
     * Render horizontal scrollbar: `'auto'`, `'visible'` or `'hidden'`.
     * Defaults to 'auto'.
     */
    @:optional var horizontal:String;
    /**
     * Cast horizontal and vertical shadows when the content is scrolled.
     * Defaults to true.
     */
    @:optional var useShadows:Bool;
    /**
     * Render arrows at the top and bottom of the vertical scrollbar.
     * Defaults to false.
     */
    @:optional var verticalHasArrows:Bool;
    /**
     * Render arrows at the left and right of the horizontal scrollbar.
     * Defaults to false.
     */
    @:optional var horizontalHasArrows:Bool;
    /**
     * Listen to mouse wheel events and react to them by scrolling.
     * Defaults to true.
     */
    @:optional var handleMouseWheel:Bool;
    /**
     * Always consume mouse wheel events (always call preventDefault() and stopPropagation() on the browser events).
     * Defaults to true.
     */
    @:optional var alwaysConsumeMouseWheel:Bool;
    /**
     * Height in pixels for the horizontal scrollbar.
     * Defaults to 12 (px).
     */
    @:optional var horizontalScrollbarSize:Int;
    /**
     * Width in pixels for the vertical scrollbar.
     * Defaults to 14 (px).
     */
    @:optional var verticalScrollbarSize:Int;
    /**
     * Width in pixels for the vertical slider.
     * Defaults to `verticalScrollbarSize`.
     */
    @:optional var verticalSliderSize:Int;
    /**
     * Height in pixels for the horizontal slider.
     * Defaults to `horizontalScrollbarSize`.
     */
    @:optional var horizontalSliderSize:Int;
    /**
     * Scroll gutter clicks move by page vs jump to position.
     * Defaults to false.
     */
    @:optional var scrollByPage:Bool;
    /**
     * When set, the horizontal scrollbar will not increase content height.
     * Defaults to false.
     */
    @:optional var ignoreHorizontalScrollbarInContentHeight:Bool;
    /**
     * Cityscape addition (not in Monaco): the color of the vertical
     * scrollbar's track, a CSS color (`#rgb`, `#rrggbb`, `#rrggbbaa`,
     * `rgb()`, `rgba()` or `'transparent'`). The track is opaque by default:
     * it is filled with `editor.background`, so the whole line backgrounds
     * (current line highlight, whole line decorations, selections) and the
     * text stop where the scrollbar starts (and where the overview ruler
     * starts with `overviewRulerPosition: 'beside'`). `'transparent'` gives
     * Monaco's scrollbar, over the text. The overview ruler and the thumb are
     * drawn over the track.
     */
    @:optional var trackColor:String;
    /**
     * Cityscape addition (not in Monaco): the color of the vertical
     * scrollbar's thumb (a CSS color, the same when hovered or dragged).
     * Defaults to the kit's thumb colors.
     */
    @:optional var thumbColor:String;
    /**
     * Cityscape addition (not in Monaco): the corner radius of the vertical
     * scrollbar's thumb, in pixels (at most half its width). Defaults to the
     * kit's.
     */
    @:optional var thumbRadius:Float;
}

typedef InternalEditorScrollbarOptions = {
    final arrowSize:Int;
    final vertical:ScrollbarVisibility;
    final horizontal:ScrollbarVisibility;
    final useShadows:Bool;
    final verticalHasArrows:Bool;
    final horizontalHasArrows:Bool;
    final handleMouseWheel:Bool;
    final alwaysConsumeMouseWheel:Bool;
    final horizontalScrollbarSize:Int;
    final horizontalSliderSize:Int;
    final verticalScrollbarSize:Int;
    final verticalSliderSize:Int;
    final scrollByPage:Bool;
    final ignoreHorizontalScrollbarInContentHeight:Bool;
    /** Cityscape addition: the track color as given, null for the default (`editor.background`). */
    final trackColor:Null<String>;
    /** Cityscape addition: the thumb color as given, null for the kit's. */
    final thumbColor:Null<String>;
    /** Cityscape addition: the thumb corner radius (0 to 1000), null for the kit's. */
    final thumbRadius:Null<Float>;
}

private function _scrollbarVisibilityFromString(visibility:Any, defaultValue:ScrollbarVisibility):ScrollbarVisibility {
    if (!JsValues.isString(visibility)) {
        return defaultValue;
    }
    return switch ((visibility : String)) {
        case 'hidden': ScrollbarVisibility.Hidden;
        case 'visible': ScrollbarVisibility.Visible;
        default: ScrollbarVisibility.Auto;
    }
}

class EditorScrollbar extends BaseEditorOption<InternalEditorScrollbarOptions> {

    public function new() {
        final defaults:InternalEditorScrollbarOptions = {
            vertical: ScrollbarVisibility.Auto,
            horizontal: ScrollbarVisibility.Auto,
            arrowSize: 11,
            useShadows: true,
            verticalHasArrows: false,
            horizontalHasArrows: false,
            horizontalScrollbarSize: 12,
            horizontalSliderSize: 12,
            verticalScrollbarSize: 14,
            verticalSliderSize: 14,
            handleMouseWheel: true,
            alwaysConsumeMouseWheel: true,
            scrollByPage: false,
            ignoreHorizontalScrollbarInContentHeight: false,
            trackColor: null,
            thumbColor: null,
            thumbRadius: null,
        };
        super(EditorOption.scrollbar, 'scrollbar', defaults);
    }

    public function validate(_input:Any):InternalEditorScrollbarOptions {
        if (!JsValues.truthy(_input) || !JsValues.isObject(_input)) {
            return this.defaultValue;
        }
        final input = _input;
        final horizontalScrollbarSize = EditorIntOption.clampedInt(JsValues.field(input, 'horizontalScrollbarSize'), this.defaultValue.horizontalScrollbarSize, 0, 1000);
        final verticalScrollbarSize = EditorIntOption.clampedInt(JsValues.field(input, 'verticalScrollbarSize'), this.defaultValue.verticalScrollbarSize, 0, 1000);
        return {
            arrowSize: EditorIntOption.clampedInt(JsValues.field(input, 'arrowSize'), this.defaultValue.arrowSize, 0, 1000),
            vertical: _scrollbarVisibilityFromString(JsValues.field(input, 'vertical'), this.defaultValue.vertical),
            horizontal: _scrollbarVisibilityFromString(JsValues.field(input, 'horizontal'), this.defaultValue.horizontal),
            useShadows: EditorOptions.boolean(JsValues.field(input, 'useShadows'), this.defaultValue.useShadows),
            verticalHasArrows: EditorOptions.boolean(JsValues.field(input, 'verticalHasArrows'), this.defaultValue.verticalHasArrows),
            horizontalHasArrows: EditorOptions.boolean(JsValues.field(input, 'horizontalHasArrows'), this.defaultValue.horizontalHasArrows),
            handleMouseWheel: EditorOptions.boolean(JsValues.field(input, 'handleMouseWheel'), this.defaultValue.handleMouseWheel),
            alwaysConsumeMouseWheel: EditorOptions.boolean(JsValues.field(input, 'alwaysConsumeMouseWheel'), this.defaultValue.alwaysConsumeMouseWheel),
            horizontalScrollbarSize: horizontalScrollbarSize,
            horizontalSliderSize: EditorIntOption.clampedInt(JsValues.field(input, 'horizontalSliderSize'), horizontalScrollbarSize, 0, 1000),
            verticalScrollbarSize: verticalScrollbarSize,
            verticalSliderSize: EditorIntOption.clampedInt(JsValues.field(input, 'verticalSliderSize'), verticalScrollbarSize, 0, 1000),
            scrollByPage: EditorOptions.boolean(JsValues.field(input, 'scrollByPage'), this.defaultValue.scrollByPage),
            ignoreHorizontalScrollbarInContentHeight: EditorOptions.boolean(JsValues.field(input, 'ignoreHorizontalScrollbarInContentHeight'), this.defaultValue.ignoreHorizontalScrollbarInContentHeight),
            trackColor: _color(JsValues.field(input, 'trackColor')),
            thumbColor: _color(JsValues.field(input, 'thumbColor')),
            thumbRadius: _radius(JsValues.field(input, 'thumbRadius')),
        };
    }

    /**
     * A color of the Cityscape additions: a non empty string, else null
     * (the default). A string that is not a color the view can read is
     * also the default, when painting.
     */
    static function _color(value:Any):Null<String> {
        if (!JsValues.isString(value)) {
            return null;
        }
        final color = StringTools.trim((value : String));
        return color.length > 0 ? color : null;
    }

    /** A radius of the Cityscape additions: a number clamped to 0..1000, else null. */
    static function _radius(value:Any):Null<Float> {
        if (!JsValues.isNumber(value)) {
            return null;
        }
        final radius:Float = value;
        return Math.isNaN(radius) ? null : EditorFloatOption.clamp(radius, 0, 1000);
    }

}

//#endregion

//#region scrollBeyondLastLineGap

/**
 * Cityscape addition: the space past the last line (see
 * `IEditorOptions.scrollBeyondLastLineGap`).
 */
typedef IScrollBeyondLastLineGap = {
    /**
     * Fraction of the viewport (the editor height without its vertical
     * padding), from 0 to 1.
     */
    @:optional var viewportFraction:Float;
    /**
     * Minimum, in lines.
     */
    @:optional var minLines:Float;
}

typedef InternalScrollBeyondLastLineGap = {
    final viewportFraction:Float;
    final minLines:Float;
    /**
     * The height of the editor as laid out (computed: Monaco's layout
     * truncates it to an integer, gpui-kit's rule takes the exact height).
     */
    final outerHeight:Float;
}

class EditorScrollBeyondLastLineGap extends BaseEditorOption<Null<InternalScrollBeyondLastLineGap>> {

    public function new() {
        super(EditorOption.scrollBeyondLastLineGap, 'scrollBeyondLastLineGap', null);
    }

    public function validate(_input:Any):Null<InternalScrollBeyondLastLineGap> {
        if (!JsValues.truthy(_input) || !JsValues.isObject(_input)) {
            return null;
        }
        final input = _input;
        return {
            viewportFraction: EditorFloatOption.clamp(EditorFloatOption.float(JsValues.field(input, 'viewportFraction'), 0), 0, 1),
            minLines: EditorFloatOption.clamp(EditorFloatOption.float(JsValues.field(input, 'minLines'), 0), 0, 1000),
            outerHeight: 0
        };
    }

    override public function compute(env:IEnvironmentalOptions, options:IComputedEditorOptions, value:Null<InternalScrollBeyondLastLineGap>):Null<InternalScrollBeyondLastLineGap> {
        if (value == null) {
            return null;
        }
        return {viewportFraction: value.viewportFraction, minLines: value.minLines, outerHeight: env.outerHeight};
    }

}

//#endregion

//#region suggest

/**
 * Configuration options for editor suggest widget
 */
typedef ISuggestOptions = {
    /**
     * Overwrite word ends on accept: `'insert'` or `'replace'`. Default to false.
     */
    @:optional var insertMode:String;
    /**
     * Enable graceful matching. Defaults to true.
     */
    @:optional var filterGraceful:Bool;
    /**
     * Prevent quick suggestions when a snippet is active. Defaults to true.
     */
    @:optional var snippetsPreventQuickSuggestions:Bool;
    /**
     * Favors words that appear close to the cursor.
     */
    @:optional var localityBonus:Bool;
    /**
     * Enable using global storage for remembering suggestions.
     */
    @:optional var shareSuggestSelections:Bool;
    /**
     * Select suggestions when triggered via quick suggest or trigger characters:
     * `'always'`, `'never'`, `'whenTriggerCharacter'` or `'whenQuickSuggestion'`.
     */
    @:optional var selectionMode:String;
    /**
     * Enable or disable icons in suggestions. Defaults to true.
     */
    @:optional var showIcons:Bool;
    /**
     * Enable or disable the suggest status bar.
     */
    @:optional var showStatusBar:Bool;
    /**
     * Enable or disable the rendering of the suggestion preview.
     */
    @:optional var preview:Bool;
    /**
     * Configures the mode of the preview: `'prefix'`, `'subword'` or `'subwordSmart'`.
     */
    @:optional var previewMode:String;
    /**
     * Show details inline with the label. Defaults to true.
     */
    @:optional var showInlineDetails:Bool;
    @:optional var showMethods:Bool;
    @:optional var showFunctions:Bool;
    @:optional var showConstructors:Bool;
    @:optional var showDeprecated:Bool;
    /**
     * Controls whether suggestions allow matches in the middle of the word instead of only at the beginning
     */
    @:optional var matchOnWordStartOnly:Bool;
    @:optional var showFields:Bool;
    @:optional var showVariables:Bool;
    @:optional var showClasses:Bool;
    @:optional var showStructs:Bool;
    @:optional var showInterfaces:Bool;
    @:optional var showModules:Bool;
    @:optional var showProperties:Bool;
    @:optional var showEvents:Bool;
    @:optional var showOperators:Bool;
    @:optional var showUnits:Bool;
    @:optional var showValues:Bool;
    @:optional var showConstants:Bool;
    @:optional var showEnums:Bool;
    @:optional var showEnumMembers:Bool;
    @:optional var showKeywords:Bool;
    @:optional var showWords:Bool;
    @:optional var showColors:Bool;
    @:optional var showFiles:Bool;
    @:optional var showReferences:Bool;
    @:optional var showFolders:Bool;
    @:optional var showTypeParameters:Bool;
    @:optional var showIssues:Bool;
    @:optional var showUsers:Bool;
    @:optional var showSnippets:Bool;
}

/**
 * @internal
 */
typedef InternalSuggestOptions = {
    final insertMode:String;
    final filterGraceful:Bool;
    final snippetsPreventQuickSuggestions:Bool;
    final localityBonus:Bool;
    final shareSuggestSelections:Bool;
    final selectionMode:String;
    final showIcons:Bool;
    final showStatusBar:Bool;
    final preview:Bool;
    final previewMode:String;
    final showInlineDetails:Bool;
    final showMethods:Bool;
    final showFunctions:Bool;
    final showConstructors:Bool;
    final showDeprecated:Bool;
    final matchOnWordStartOnly:Bool;
    final showFields:Bool;
    final showVariables:Bool;
    final showClasses:Bool;
    final showStructs:Bool;
    final showInterfaces:Bool;
    final showModules:Bool;
    final showProperties:Bool;
    final showEvents:Bool;
    final showOperators:Bool;
    final showUnits:Bool;
    final showValues:Bool;
    final showConstants:Bool;
    final showEnums:Bool;
    final showEnumMembers:Bool;
    final showKeywords:Bool;
    final showWords:Bool;
    final showColors:Bool;
    final showFiles:Bool;
    final showReferences:Bool;
    final showFolders:Bool;
    final showTypeParameters:Bool;
    final showIssues:Bool;
    final showUsers:Bool;
    final showSnippets:Bool;
}

class EditorSuggest extends BaseEditorOption<InternalSuggestOptions> {

    public function new() {
        final defaults:InternalSuggestOptions = {
            insertMode: 'insert',
            filterGraceful: true,
            snippetsPreventQuickSuggestions: false,
            localityBonus: false,
            shareSuggestSelections: false,
            selectionMode: 'always',
            showIcons: true,
            showStatusBar: false,
            preview: false,
            previewMode: 'subwordSmart',
            showInlineDetails: true,
            showMethods: true,
            showFunctions: true,
            showConstructors: true,
            showDeprecated: true,
            matchOnWordStartOnly: true,
            showFields: true,
            showVariables: true,
            showClasses: true,
            showStructs: true,
            showInterfaces: true,
            showModules: true,
            showProperties: true,
            showEvents: true,
            showOperators: true,
            showUnits: true,
            showValues: true,
            showConstants: true,
            showEnums: true,
            showEnumMembers: true,
            showKeywords: true,
            showWords: true,
            showColors: true,
            showFiles: true,
            showReferences: true,
            showFolders: true,
            showTypeParameters: true,
            showSnippets: true,
            showUsers: true,
            showIssues: true,
        };
        super(EditorOption.suggest, 'suggest', defaults);
    }

    public function validate(_input:Any):InternalSuggestOptions {
        if (!JsValues.truthy(_input) || !JsValues.isObject(_input)) {
            return this.defaultValue;
        }
        final input = _input;
        inline function b(name:String, defaultValue:Bool):Bool {
            return EditorOptions.boolean(JsValues.field(input, name), defaultValue);
        }
        final d = this.defaultValue;
        return {
            insertMode: EditorOptions.stringSet(JsValues.field(input, 'insertMode'), d.insertMode, ['insert', 'replace']),
            filterGraceful: b('filterGraceful', d.filterGraceful),
            // Monaco reads the default of snippetsPreventQuickSuggestions from filterGraceful
            snippetsPreventQuickSuggestions: b('snippetsPreventQuickSuggestions', d.filterGraceful),
            localityBonus: b('localityBonus', d.localityBonus),
            shareSuggestSelections: b('shareSuggestSelections', d.shareSuggestSelections),
            selectionMode: EditorOptions.stringSet(JsValues.field(input, 'selectionMode'), d.selectionMode, ['always', 'never', 'whenQuickSuggestion', 'whenTriggerCharacter']),
            showIcons: b('showIcons', d.showIcons),
            showStatusBar: b('showStatusBar', d.showStatusBar),
            preview: b('preview', d.preview),
            previewMode: EditorOptions.stringSet(JsValues.field(input, 'previewMode'), d.previewMode, ['prefix', 'subword', 'subwordSmart']),
            showInlineDetails: b('showInlineDetails', d.showInlineDetails),
            showMethods: b('showMethods', d.showMethods),
            showFunctions: b('showFunctions', d.showFunctions),
            showConstructors: b('showConstructors', d.showConstructors),
            showDeprecated: b('showDeprecated', d.showDeprecated),
            matchOnWordStartOnly: b('matchOnWordStartOnly', d.matchOnWordStartOnly),
            showFields: b('showFields', d.showFields),
            showVariables: b('showVariables', d.showVariables),
            showClasses: b('showClasses', d.showClasses),
            showStructs: b('showStructs', d.showStructs),
            showInterfaces: b('showInterfaces', d.showInterfaces),
            showModules: b('showModules', d.showModules),
            showProperties: b('showProperties', d.showProperties),
            showEvents: b('showEvents', d.showEvents),
            showOperators: b('showOperators', d.showOperators),
            showUnits: b('showUnits', d.showUnits),
            showValues: b('showValues', d.showValues),
            showConstants: b('showConstants', d.showConstants),
            showEnums: b('showEnums', d.showEnums),
            showEnumMembers: b('showEnumMembers', d.showEnumMembers),
            showKeywords: b('showKeywords', d.showKeywords),
            showWords: b('showWords', d.showWords),
            showColors: b('showColors', d.showColors),
            showFiles: b('showFiles', d.showFiles),
            showReferences: b('showReferences', d.showReferences),
            showFolders: b('showFolders', d.showFolders),
            showTypeParameters: b('showTypeParameters', d.showTypeParameters),
            showSnippets: b('showSnippets', d.showSnippets),
            showUsers: b('showUsers', d.showUsers),
            showIssues: b('showIssues', d.showIssues),
        };
    }

}

//#endregion

//#region wrappingIndent

/**
 * Describes how to indent wrapped lines.
 */
enum abstract WrappingIndent(Int) from Int to Int {
    /**
     * No indentation => wrapped lines begin at column 1.
     */
    var None = 0;
    /**
     * Same => wrapped lines get the same indentation as the parent.
     */
    var Same = 1;
    /**
     * Indent => wrapped lines get +1 indentation toward the parent.
     */
    var Indent = 2;
    /**
     * DeepIndent => wrapped lines get +2 indentation toward the parent.
     */
    var DeepIndent = 3;
}

class WrappingIndentOption extends BaseEditorOption<WrappingIndent> {

    public function new() {
        super(EditorOption.wrappingIndent, 'wrappingIndent', WrappingIndent.Same);
    }

    public function validate(input:Any):WrappingIndent {
        if (JsValues.isString(input)) {
            switch ((input : String)) {
                case 'none': return WrappingIndent.None;
                case 'same': return WrappingIndent.Same;
                case 'indent': return WrappingIndent.Indent;
                case 'deepIndent': return WrappingIndent.DeepIndent;
                case _:
            }
        }
        return WrappingIndent.Same;
    }

    override public function compute(env:IEnvironmentalOptions, options:IComputedEditorOptions, value:WrappingIndent):WrappingIndent {
        final accessibilitySupport = options.get(EditorOption.accessibilitySupport);
        if (accessibilitySupport == AccessibilitySupport.Enabled) {
            // if we know for a fact that a screen reader is attached, we use no indent wrapping to
            // help that the editor's wrapping points match the textarea's wrapping points
            return WrappingIndent.None;
        }
        return value;
    }

}

//#endregion

typedef EditorFontDefaults = {
    final fontFamily:String;
    final fontWeight:String;
    final fontSize:Float;
    final lineHeight:Float;
    final letterSpacing:Float;
}

/**
 * The ids of the editor options, typed by the value of the option
 * (`options.get(EditorOption.fontSize)` is a `Float`). The numbers are
 * Monaco's `EditorOption` enum. Options not ported yet have the type `Any`.
 */
abstract EditorOption<V>(Int) to Int {

    inline function new(id:Int) {
        this = id;
    }

    public static inline final acceptSuggestionOnCommitCharacter:EditorOption<Bool> = new EditorOption<Bool>(0);
    public static inline final acceptSuggestionOnEnter:EditorOption<String> = new EditorOption<String>(1);
    public static inline final accessibilitySupport:EditorOption<AccessibilitySupport> = new EditorOption<AccessibilitySupport>(2);
    public static inline final accessibilityPageSize:EditorOption<Any> = new EditorOption<Any>(3);
    public static inline final ariaLabel:EditorOption<Any> = new EditorOption<Any>(4);
    public static inline final ariaRequired:EditorOption<Any> = new EditorOption<Any>(5);
    public static inline final autoClosingBrackets:EditorOption<String> = new EditorOption<String>(6);
    public static inline final autoClosingComments:EditorOption<String> = new EditorOption<String>(7);
    public static inline final screenReaderAnnounceInlineSuggestion:EditorOption<Any> = new EditorOption<Any>(8);
    public static inline final autoClosingDelete:EditorOption<String> = new EditorOption<String>(9);
    public static inline final autoClosingOvertype:EditorOption<String> = new EditorOption<String>(10);
    public static inline final autoClosingQuotes:EditorOption<String> = new EditorOption<String>(11);
    public static inline final autoIndent:EditorOption<EditorAutoIndentStrategy> = new EditorOption<EditorAutoIndentStrategy>(12);
    public static inline final automaticLayout:EditorOption<Bool> = new EditorOption<Bool>(13);
    public static inline final autoSurround:EditorOption<String> = new EditorOption<String>(14);
    public static inline final bracketPairColorization:EditorOption<InternalBracketPairColorizationOptions> = new EditorOption<InternalBracketPairColorizationOptions>(15);
    public static inline final guides:EditorOption<InternalGuidesOptions> = new EditorOption<InternalGuidesOptions>(16);
    public static inline final codeLens:EditorOption<Bool> = new EditorOption<Bool>(17);
    public static inline final codeLensFontFamily:EditorOption<String> = new EditorOption<String>(18);
    public static inline final codeLensFontSize:EditorOption<Int> = new EditorOption<Int>(19);
    public static inline final colorDecorators:EditorOption<Bool> = new EditorOption<Bool>(20);
    public static inline final colorDecoratorsLimit:EditorOption<Int> = new EditorOption<Int>(21);
    public static inline final columnSelection:EditorOption<Bool> = new EditorOption<Bool>(22);
    public static inline final comments:EditorOption<cityscape.common.config.EditorCommentsOptions.EditorCommentsOptions> = new EditorOption<cityscape.common.config.EditorCommentsOptions.EditorCommentsOptions>(23);
    public static inline final contextmenu:EditorOption<Bool> = new EditorOption<Bool>(24);
    public static inline final copyWithSyntaxHighlighting:EditorOption<Bool> = new EditorOption<Bool>(25);
    public static inline final cursorBlinking:EditorOption<TextEditorCursorBlinkingStyle> = new EditorOption<TextEditorCursorBlinkingStyle>(26);
    public static inline final cursorSmoothCaretAnimation:EditorOption<String> = new EditorOption<String>(27);
    public static inline final cursorStyle:EditorOption<TextEditorCursorStyle> = new EditorOption<TextEditorCursorStyle>(28);
    public static inline final cursorSurroundingLines:EditorOption<Int> = new EditorOption<Int>(29);
    public static inline final cursorSurroundingLinesStyle:EditorOption<String> = new EditorOption<String>(30);
    public static inline final cursorWidth:EditorOption<Int> = new EditorOption<Int>(31);
    public static inline final disableLayerHinting:EditorOption<Any> = new EditorOption<Any>(32);
    public static inline final disableMonospaceOptimizations:EditorOption<Bool> = new EditorOption<Bool>(33);
    public static inline final domReadOnly:EditorOption<Any> = new EditorOption<Any>(34);
    public static inline final dragAndDrop:EditorOption<Bool> = new EditorOption<Bool>(35);
    public static inline final dropIntoEditor:EditorOption<Any> = new EditorOption<Any>(36);
    public static inline final emptySelectionClipboard:EditorOption<Bool> = new EditorOption<Bool>(37);
    public static inline final experimentalWhitespaceRendering:EditorOption<String> = new EditorOption<String>(38);
    public static inline final extraEditorClassName:EditorOption<Any> = new EditorOption<Any>(39);
    public static inline final fastScrollSensitivity:EditorOption<Any> = new EditorOption<Any>(40);
    public static inline final find:EditorOption<cityscape.common.config.EditorFindOptions.EditorFindOptions> = new EditorOption<cityscape.common.config.EditorFindOptions.EditorFindOptions>(41);
    public static inline final fixedOverflowWidgets:EditorOption<Bool> = new EditorOption<Bool>(42);
    public static inline final folding:EditorOption<Bool> = new EditorOption<Bool>(43);
    public static inline final foldingStrategy:EditorOption<String> = new EditorOption<String>(44);
    public static inline final foldingHighlight:EditorOption<Bool> = new EditorOption<Bool>(45);
    public static inline final foldingImportsByDefault:EditorOption<Bool> = new EditorOption<Bool>(46);
    public static inline final foldingMaximumRegions:EditorOption<Int> = new EditorOption<Int>(47);
    public static inline final unfoldOnClickAfterEndOfLine:EditorOption<Bool> = new EditorOption<Bool>(48);
    public static inline final fontFamily:EditorOption<String> = new EditorOption<String>(49);
    public static inline final fontInfo:EditorOption<FontInfo> = new EditorOption<FontInfo>(50);
    public static inline final fontLigatures:EditorOption<String> = new EditorOption<String>(51);
    public static inline final fontSize:EditorOption<Float> = new EditorOption<Float>(52);
    public static inline final fontWeight:EditorOption<String> = new EditorOption<String>(53);
    public static inline final fontVariations:EditorOption<Any> = new EditorOption<Any>(54);
    public static inline final formatOnPaste:EditorOption<Any> = new EditorOption<Any>(55);
    public static inline final formatOnType:EditorOption<Any> = new EditorOption<Any>(56);
    public static inline final glyphMargin:EditorOption<Bool> = new EditorOption<Bool>(57);
    public static inline final gotoLocation:EditorOption<GoToLocationOptions> = new EditorOption<GoToLocationOptions>(58);
    public static inline final hideCursorInOverviewRuler:EditorOption<Bool> = new EditorOption<Bool>(59);
    public static inline final hover:EditorOption<EditorHoverOptions> = new EditorOption<EditorHoverOptions>(60);
    public static inline final inDiffEditor:EditorOption<Any> = new EditorOption<Any>(61);
    public static inline final inlineSuggest:EditorOption<cityscape.common.config.EditorInlineSuggestOptions.InternalInlineSuggestOptions> = new EditorOption<cityscape.common.config.EditorInlineSuggestOptions.InternalInlineSuggestOptions>(62);
    public static inline final inlineEdit:EditorOption<Any> = new EditorOption<Any>(63);
    public static inline final letterSpacing:EditorOption<Float> = new EditorOption<Float>(64);
    public static inline final lightbulb:EditorOption<cityscape.common.config.EditorLanguageFeatureOptions.EditorLightbulbOptions> = new EditorOption<cityscape.common.config.EditorLanguageFeatureOptions.EditorLightbulbOptions>(65);
    public static inline final lineDecorationsWidth:EditorOption<Float> = new EditorOption<Float>(66);
    public static inline final lineHeight:EditorOption<Float> = new EditorOption<Float>(67);
    public static inline final lineNumbers:EditorOption<InternalEditorRenderLineNumbersOptions> = new EditorOption<InternalEditorRenderLineNumbersOptions>(68);
    public static inline final lineNumbersMinChars:EditorOption<Int> = new EditorOption<Int>(69);
    public static inline final linkedEditing:EditorOption<Any> = new EditorOption<Any>(70);
    public static inline final links:EditorOption<Bool> = new EditorOption<Bool>(71);
    public static inline final matchBrackets:EditorOption<String> = new EditorOption<String>(72);
    public static inline final minimap:EditorOption<Any> = new EditorOption<Any>(73);
    public static inline final mouseStyle:EditorOption<String> = new EditorOption<String>(74);
    public static inline final mouseWheelScrollSensitivity:EditorOption<Any> = new EditorOption<Any>(75);
    public static inline final mouseWheelZoom:EditorOption<Bool> = new EditorOption<Bool>(76);
    public static inline final multiCursorMergeOverlapping:EditorOption<Bool> = new EditorOption<Bool>(77);
    public static inline final multiCursorModifier:EditorOption<String> = new EditorOption<String>(78);
    public static inline final multiCursorPaste:EditorOption<String> = new EditorOption<String>(79);
    public static inline final multiCursorLimit:EditorOption<Int> = new EditorOption<Int>(80);
    public static inline final occurrencesHighlight:EditorOption<String> = new EditorOption<String>(81);
    public static inline final overviewRulerBorder:EditorOption<Bool> = new EditorOption<Bool>(82);
    public static inline final overviewRulerLanes:EditorOption<Int> = new EditorOption<Int>(83);
    public static inline final padding:EditorOption<InternalEditorPaddingOptions> = new EditorOption<InternalEditorPaddingOptions>(84);
    public static inline final pasteAs:EditorOption<Any> = new EditorOption<Any>(85);
    public static inline final peekWidgetDefaultFocus:EditorOption<String> = new EditorOption<String>(87);
    public static inline final parameterHints:EditorOption<cityscape.common.config.EditorParameterHintsOptions.InternalParameterHintOptions> = new EditorOption<cityscape.common.config.EditorParameterHintsOptions.InternalParameterHintOptions>(86);
    public static inline final placeholder:EditorOption<Any> = new EditorOption<Any>(88);
    public static inline final definitionLinkOpensInPeek:EditorOption<Bool> = new EditorOption<Bool>(89);
    public static inline final quickSuggestions:EditorOption<InternalQuickSuggestionsOptions> = new EditorOption<InternalQuickSuggestionsOptions>(90);
    public static inline final quickSuggestionsDelay:EditorOption<Int> = new EditorOption<Int>(91);
    public static inline final readOnly:EditorOption<Bool> = new EditorOption<Bool>(92);
    public static inline final readOnlyMessage:EditorOption<Any> = new EditorOption<Any>(93);
    public static inline final renameOnType:EditorOption<Any> = new EditorOption<Any>(94);
    public static inline final renderControlCharacters:EditorOption<Bool> = new EditorOption<Bool>(95);
    public static inline final renderFinalNewline:EditorOption<String> = new EditorOption<String>(96);
    public static inline final renderLineHighlight:EditorOption<String> = new EditorOption<String>(97);
    public static inline final renderLineHighlightOnlyWhenFocus:EditorOption<Bool> = new EditorOption<Bool>(98);
    public static inline final renderValidationDecorations:EditorOption<String> = new EditorOption<String>(99);
    public static inline final renderWhitespace:EditorOption<String> = new EditorOption<String>(100);
    public static inline final revealHorizontalRightPadding:EditorOption<Any> = new EditorOption<Any>(101);
    public static inline final roundedSelection:EditorOption<Bool> = new EditorOption<Bool>(102);
    public static inline final rulers:EditorOption<Array<IRulerOption>> = new EditorOption<Array<IRulerOption>>(103);
    public static inline final scrollbar:EditorOption<InternalEditorScrollbarOptions> = new EditorOption<InternalEditorScrollbarOptions>(104);
    public static inline final scrollBeyondLastColumn:EditorOption<Int> = new EditorOption<Int>(105);
    public static inline final scrollBeyondLastLine:EditorOption<Bool> = new EditorOption<Bool>(106);
    public static inline final scrollPredominantAxis:EditorOption<Any> = new EditorOption<Any>(107);
    public static inline final selectionClipboard:EditorOption<Any> = new EditorOption<Any>(108);
    public static inline final selectionHighlight:EditorOption<Bool> = new EditorOption<Bool>(109);
    public static inline final selectOnLineNumbers:EditorOption<Any> = new EditorOption<Any>(110);
    public static inline final showFoldingControls:EditorOption<String> = new EditorOption<String>(111);
    public static inline final showUnused:EditorOption<Any> = new EditorOption<Any>(112);
    public static inline final snippetSuggestions:EditorOption<String> = new EditorOption<String>(113);
    public static inline final smartSelect:EditorOption<Any> = new EditorOption<Any>(114);
    public static inline final smoothScrolling:EditorOption<Bool> = new EditorOption<Bool>(115);
    public static inline final stickyScroll:EditorOption<EditorStickyScrollOptions> = new EditorOption<EditorStickyScrollOptions>(116);
    public static inline final stickyTabStops:EditorOption<Bool> = new EditorOption<Bool>(117);
    public static inline final stopRenderingLineAfter:EditorOption<Int> = new EditorOption<Int>(118);
    public static inline final suggest:EditorOption<InternalSuggestOptions> = new EditorOption<InternalSuggestOptions>(119);
    public static inline final suggestFontSize:EditorOption<Int> = new EditorOption<Int>(120);
    public static inline final suggestLineHeight:EditorOption<Int> = new EditorOption<Int>(121);
    public static inline final suggestOnTriggerCharacters:EditorOption<Bool> = new EditorOption<Bool>(122);
    public static inline final suggestSelection:EditorOption<String> = new EditorOption<String>(123);
    public static inline final tabCompletion:EditorOption<String> = new EditorOption<String>(124);
    public static inline final tabIndex:EditorOption<Any> = new EditorOption<Any>(125);
    public static inline final unicodeHighlighting:EditorOption<Any> = new EditorOption<Any>(126);
    public static inline final unusualLineTerminators:EditorOption<Any> = new EditorOption<Any>(127);
    public static inline final useShadowDOM:EditorOption<Any> = new EditorOption<Any>(128);
    public static inline final useTabStops:EditorOption<Bool> = new EditorOption<Bool>(129);
    public static inline final wordBreak:EditorOption<String> = new EditorOption<String>(130);
    public static inline final wordSegmenterLocales:EditorOption<Array<String>> = new EditorOption<Array<String>>(131);
    public static inline final wordSeparators:EditorOption<String> = new EditorOption<String>(132);
    public static inline final wordWrap:EditorOption<String> = new EditorOption<String>(133);
    public static inline final wordWrapBreakAfterCharacters:EditorOption<String> = new EditorOption<String>(134);
    public static inline final wordWrapBreakBeforeCharacters:EditorOption<String> = new EditorOption<String>(135);
    public static inline final wordWrapColumn:EditorOption<Int> = new EditorOption<Int>(136);
    public static inline final wordWrapOverride1:EditorOption<String> = new EditorOption<String>(137);
    public static inline final wordWrapOverride2:EditorOption<String> = new EditorOption<String>(138);
    public static inline final wrappingIndent:EditorOption<WrappingIndent> = new EditorOption<WrappingIndent>(139);
    public static inline final wrappingStrategy:EditorOption<String> = new EditorOption<String>(140);
    public static inline final showDeprecated:EditorOption<Any> = new EditorOption<Any>(141);
    public static inline final inlayHints:EditorOption<cityscape.common.config.EditorInlayHintsCodeLensOptions.EditorInlayHintsOptions> = new EditorOption<cityscape.common.config.EditorInlayHintsCodeLensOptions.EditorInlayHintsOptions>(142);
    public static inline final editorClassName:EditorOption<Any> = new EditorOption<Any>(143);
    public static inline final pixelRatio:EditorOption<Float> = new EditorOption<Float>(144);
    public static inline final tabFocusMode:EditorOption<Any> = new EditorOption<Any>(145);
    public static inline final layoutInfo:EditorOption<cityscape.common.config.EditorViewOptions.EditorLayoutInfo> = new EditorOption<cityscape.common.config.EditorViewOptions.EditorLayoutInfo>(146);
    public static inline final wrappingInfo:EditorOption<cityscape.common.config.EditorViewOptions.EditorWrappingInfo> = new EditorOption<cityscape.common.config.EditorViewOptions.EditorWrappingInfo>(147);
    public static inline final defaultColorDecorators:EditorOption<Bool> = new EditorOption<Bool>(148);
    public static inline final colorDecoratorsActivatedOn:EditorOption<String> = new EditorOption<String>(149);
    public static inline final inlineCompletionsAccessibilityVerbose:EditorOption<Any> = new EditorOption<Any>(150);
    /** Cityscape addition. */
    public static inline final scrollBeyondLastLineGap:EditorOption<Null<cityscape.common.config.EditorOptions.InternalScrollBeyondLastLineGap>> = new EditorOption<Null<cityscape.common.config.EditorOptions.InternalScrollBeyondLastLineGap>>(151);

    /**
     * The number of option ids.
     */
    /** Cityscape addition. */
    public static inline final scrollbarThumbExcludesPadding:EditorOption<Bool> = new EditorOption<Bool>(152);
    /** Cityscape addition. */
    public static inline final preferColorEmoji:EditorOption<Bool> = new EditorOption<Bool>(153);
    /** Cityscape addition. */
    public static inline final overviewRulerPosition:EditorOption<String> = new EditorOption<String>(154);
    /** Cityscape addition. */
    public static inline final overviewRulerGap:EditorOption<Float> = new EditorOption<Float>(155);

    /**
     * The number of option ids (Monaco's 151 and the Cityscape additions,
     * `scrollBeyondLastLineGap`, `scrollbarThumbExcludesPadding`,
     * `preferColorEmoji`, `overviewRulerPosition` and `overviewRulerGap`).
     */
    public static inline final COUNT:Int = 156;

}

/**
 * The registry of the editor options (Monaco's `EditorOptions` and
 * `editorOptionsRegistry`), and the validation helpers of editorOptions.ts.
 *
 * The options are created on first use rather than when the program starts,
 * so that their platform dependent defaults can read the platform (Ceramic's
 * app exists by then). They are immutable and shared by every editor.
 */
class EditorOptions {

    /**
     * `Constants.MAX_SAFE_SMALL_INTEGER` (vs/base/common/uint.ts).
     */
    public static inline final MAX_SAFE_SMALL_INTEGER:Int = 1 << 30;

    static final DEFAULT_WINDOWS_FONT_FAMILY = 'Consolas, \'Courier New\', monospace';
    static final DEFAULT_MAC_FONT_FAMILY = 'Menlo, Monaco, \'Courier New\', monospace';
    static final DEFAULT_LINUX_FONT_FAMILY = '\'Droid Sans Mono\', \'monospace\', monospace';

    static var _fontDefaults:Null<EditorFontDefaults> = null;

    /**
     * @internal
     */
    public static var EDITOR_FONT_DEFAULTS(get, never):EditorFontDefaults;
    static function get_EDITOR_FONT_DEFAULTS():EditorFontDefaults {
        if (_fontDefaults == null) {
            _fontDefaults = {
                fontFamily: (
                    Platform.isMacintosh ? DEFAULT_MAC_FONT_FAMILY : (Platform.isLinux ? DEFAULT_LINUX_FONT_FAMILY : DEFAULT_WINDOWS_FONT_FAMILY)
                ),
                fontWeight: 'normal',
                fontSize: (
                    Platform.isMacintosh ? 12 : 14
                ),
                lineHeight: 0,
                letterSpacing: 0,
            };
        }
        return _fontDefaults;
    }

    static var _registry:Null<Array<IEditorOption<Any>>> = null;

    /**
     * The registered options, indexed by id (null for the ids not ported
     * yet).
     * @internal
     */
    public static var editorOptionsRegistry(get, never):Array<IEditorOption<Any>>;
    static function get_editorOptionsRegistry():Array<IEditorOption<Any>> {
        if (_registry == null) {
            init();
        }
        return _registry;
    }

    static function register<V>(option:IEditorOption<V>):IEditorOption<V> {
        _registry[option.id] = cast option;
        return option;
    }

    static var _acceptSuggestionOnEnter:IEditorOption<String>;
    static var _accessibilitySupport:IEditorOption<AccessibilitySupport>;
    static var _autoClosingBrackets:IEditorOption<String>;
    static var _autoClosingDelete:IEditorOption<String>;
    static var _autoClosingOvertype:IEditorOption<String>;
    static var _autoClosingQuotes:IEditorOption<String>;
    static var _autoIndent:IEditorOption<EditorAutoIndentStrategy>;
    static var _automaticLayout:IEditorOption<Bool>;
    static var _autoSurround:IEditorOption<String>;
    static var _colorDecorators:IEditorOption<Bool>;
    static var _contextmenu:IEditorOption<Bool>;
    static var _cursorBlinking:IEditorOption<TextEditorCursorBlinkingStyle>;
    static var _cursorSmoothCaretAnimation:IEditorOption<String>;
    static var _cursorStyle:IEditorOption<TextEditorCursorStyle>;
    static var _cursorSurroundingLines:IEditorOption<Int>;
    static var _cursorWidth:IEditorOption<Int>;
    static var _fixedOverflowWidgets:IEditorOption<Bool>;
    static var _folding:IEditorOption<Bool>;
    static var _foldingStrategy:IEditorOption<String>;
    static var _foldingHighlight:IEditorOption<Bool>;
    static var _foldingImportsByDefault:IEditorOption<Bool>;
    static var _foldingMaximumRegions:IEditorOption<Int>;
    static var _unfoldOnClickAfterEndOfLine:IEditorOption<Bool>;
    static var _fontFamily:IEditorOption<String>;
    static var _fontLigatures:IEditorOption<String>;
    static var _fontSize:IEditorOption<Float>;
    static var _fontWeight:IEditorOption<String>;
    static var _glyphMargin:IEditorOption<Bool>;
    static var _gotoLocation:IEditorOption<GoToLocationOptions>;
    static var _hover:IEditorOption<EditorHoverOptions>;
    static var _letterSpacing:IEditorOption<Float>;
    static var _lineDecorationsWidth:IEditorOption<Float>;
    static var _lineHeight:IEditorOption<Float>;
    static var _lineNumbers:IEditorOption<InternalEditorRenderLineNumbersOptions>;
    static var _lineNumbersMinChars:IEditorOption<Int>;
    static var _links:IEditorOption<Bool>;
    static var _matchBrackets:IEditorOption<String>;
    static var _mouseWheelZoom:IEditorOption<Bool>;
    static var _multiCursorModifier:IEditorOption<String>;
    static var _occurrencesHighlight:IEditorOption<String>;
    static var _padding:IEditorOption<InternalEditorPaddingOptions>;
    static var _definitionLinkOpensInPeek:IEditorOption<Bool>;
    static var _quickSuggestions:IEditorOption<InternalQuickSuggestionsOptions>;
    static var _quickSuggestionsDelay:IEditorOption<Int>;
    static var _readOnly:IEditorOption<Bool>;
    static var _renderControlCharacters:IEditorOption<Bool>;
    static var _renderFinalNewline:IEditorOption<String>;
    static var _renderLineHighlight:IEditorOption<String>;
    static var _renderWhitespace:IEditorOption<String>;
    static var _roundedSelection:IEditorOption<Bool>;
    static var _rulers:IEditorOption<Array<IRulerOption>>;
    static var _scrollbar:IEditorOption<InternalEditorScrollbarOptions>;
    static var _scrollBeyondLastColumn:IEditorOption<Int>;
    static var _scrollBeyondLastLine:IEditorOption<Bool>;
    static var _selectionHighlight:IEditorOption<Bool>;
    static var _showFoldingControls:IEditorOption<String>;
    static var _smoothScrolling:IEditorOption<Bool>;
    static var _stickyScroll:IEditorOption<EditorStickyScrollOptions>;
    static var _bracketPairColorization:IEditorOption<InternalBracketPairColorizationOptions>;
    static var _guides:IEditorOption<InternalGuidesOptions>;
    static var _suggest:IEditorOption<InternalSuggestOptions>;
    static var _suggestOnTriggerCharacters:IEditorOption<Bool>;
    static var _wordSeparators:IEditorOption<String>;
    static var _wordWrap:IEditorOption<String>;
    static var _wordWrapColumn:IEditorOption<Int>;
    static var _wrappingIndent:IEditorOption<WrappingIndent>;

    public static var acceptSuggestionOnEnter(get, never):IEditorOption<String>;
    static function get_acceptSuggestionOnEnter():IEditorOption<String> {
        if (_registry == null) {
            init();
        }
        return _acceptSuggestionOnEnter;
    }

    public static var accessibilitySupport(get, never):IEditorOption<AccessibilitySupport>;
    static function get_accessibilitySupport():IEditorOption<AccessibilitySupport> {
        if (_registry == null) {
            init();
        }
        return _accessibilitySupport;
    }

    public static var autoClosingBrackets(get, never):IEditorOption<String>;
    static function get_autoClosingBrackets():IEditorOption<String> {
        if (_registry == null) {
            init();
        }
        return _autoClosingBrackets;
    }

    public static var autoClosingDelete(get, never):IEditorOption<String>;
    static function get_autoClosingDelete():IEditorOption<String> {
        if (_registry == null) {
            init();
        }
        return _autoClosingDelete;
    }

    public static var autoClosingOvertype(get, never):IEditorOption<String>;
    static function get_autoClosingOvertype():IEditorOption<String> {
        if (_registry == null) {
            init();
        }
        return _autoClosingOvertype;
    }

    public static var autoClosingQuotes(get, never):IEditorOption<String>;
    static function get_autoClosingQuotes():IEditorOption<String> {
        if (_registry == null) {
            init();
        }
        return _autoClosingQuotes;
    }

    public static var autoIndent(get, never):IEditorOption<EditorAutoIndentStrategy>;
    static function get_autoIndent():IEditorOption<EditorAutoIndentStrategy> {
        if (_registry == null) {
            init();
        }
        return _autoIndent;
    }

    public static var automaticLayout(get, never):IEditorOption<Bool>;
    static function get_automaticLayout():IEditorOption<Bool> {
        if (_registry == null) {
            init();
        }
        return _automaticLayout;
    }

    public static var autoSurround(get, never):IEditorOption<String>;
    static function get_autoSurround():IEditorOption<String> {
        if (_registry == null) {
            init();
        }
        return _autoSurround;
    }

    public static var colorDecorators(get, never):IEditorOption<Bool>;
    static function get_colorDecorators():IEditorOption<Bool> {
        if (_registry == null) {
            init();
        }
        return _colorDecorators;
    }

    public static var contextmenu(get, never):IEditorOption<Bool>;
    static function get_contextmenu():IEditorOption<Bool> {
        if (_registry == null) {
            init();
        }
        return _contextmenu;
    }

    public static var cursorBlinking(get, never):IEditorOption<TextEditorCursorBlinkingStyle>;
    static function get_cursorBlinking():IEditorOption<TextEditorCursorBlinkingStyle> {
        if (_registry == null) {
            init();
        }
        return _cursorBlinking;
    }

    public static var cursorSmoothCaretAnimation(get, never):IEditorOption<String>;
    static function get_cursorSmoothCaretAnimation():IEditorOption<String> {
        if (_registry == null) {
            init();
        }
        return _cursorSmoothCaretAnimation;
    }

    public static var cursorStyle(get, never):IEditorOption<TextEditorCursorStyle>;
    static function get_cursorStyle():IEditorOption<TextEditorCursorStyle> {
        if (_registry == null) {
            init();
        }
        return _cursorStyle;
    }

    public static var cursorSurroundingLines(get, never):IEditorOption<Int>;
    static function get_cursorSurroundingLines():IEditorOption<Int> {
        if (_registry == null) {
            init();
        }
        return _cursorSurroundingLines;
    }

    public static var cursorWidth(get, never):IEditorOption<Int>;
    static function get_cursorWidth():IEditorOption<Int> {
        if (_registry == null) {
            init();
        }
        return _cursorWidth;
    }

    public static var fixedOverflowWidgets(get, never):IEditorOption<Bool>;
    static function get_fixedOverflowWidgets():IEditorOption<Bool> {
        if (_registry == null) {
            init();
        }
        return _fixedOverflowWidgets;
    }

    public static var folding(get, never):IEditorOption<Bool>;
    static function get_folding():IEditorOption<Bool> {
        if (_registry == null) {
            init();
        }
        return _folding;
    }

    public static var foldingStrategy(get, never):IEditorOption<String>;
    static function get_foldingStrategy():IEditorOption<String> {
        if (_registry == null) {
            init();
        }
        return _foldingStrategy;
    }

    public static var foldingHighlight(get, never):IEditorOption<Bool>;
    static function get_foldingHighlight():IEditorOption<Bool> {
        if (_registry == null) {
            init();
        }
        return _foldingHighlight;
    }

    public static var foldingImportsByDefault(get, never):IEditorOption<Bool>;
    static function get_foldingImportsByDefault():IEditorOption<Bool> {
        if (_registry == null) {
            init();
        }
        return _foldingImportsByDefault;
    }

    public static var foldingMaximumRegions(get, never):IEditorOption<Int>;
    static function get_foldingMaximumRegions():IEditorOption<Int> {
        if (_registry == null) {
            init();
        }
        return _foldingMaximumRegions;
    }

    public static var unfoldOnClickAfterEndOfLine(get, never):IEditorOption<Bool>;
    static function get_unfoldOnClickAfterEndOfLine():IEditorOption<Bool> {
        if (_registry == null) {
            init();
        }
        return _unfoldOnClickAfterEndOfLine;
    }

    public static var fontFamily(get, never):IEditorOption<String>;
    static function get_fontFamily():IEditorOption<String> {
        if (_registry == null) {
            init();
        }
        return _fontFamily;
    }

    public static var fontLigatures2(get, never):IEditorOption<String>;
    static function get_fontLigatures2():IEditorOption<String> {
        if (_registry == null) {
            init();
        }
        return _fontLigatures;
    }

    public static var fontSize(get, never):IEditorOption<Float>;
    static function get_fontSize():IEditorOption<Float> {
        if (_registry == null) {
            init();
        }
        return _fontSize;
    }

    public static var fontWeight(get, never):IEditorOption<String>;
    static function get_fontWeight():IEditorOption<String> {
        if (_registry == null) {
            init();
        }
        return _fontWeight;
    }

    public static var glyphMargin(get, never):IEditorOption<Bool>;
    static function get_glyphMargin():IEditorOption<Bool> {
        if (_registry == null) {
            init();
        }
        return _glyphMargin;
    }

    public static var gotoLocation(get, never):IEditorOption<GoToLocationOptions>;
    static function get_gotoLocation():IEditorOption<GoToLocationOptions> {
        if (_registry == null) {
            init();
        }
        return _gotoLocation;
    }

    public static var hover(get, never):IEditorOption<EditorHoverOptions>;
    static function get_hover():IEditorOption<EditorHoverOptions> {
        if (_registry == null) {
            init();
        }
        return _hover;
    }

    public static var letterSpacing(get, never):IEditorOption<Float>;
    static function get_letterSpacing():IEditorOption<Float> {
        if (_registry == null) {
            init();
        }
        return _letterSpacing;
    }

    public static var lineDecorationsWidth(get, never):IEditorOption<Float>;
    static function get_lineDecorationsWidth():IEditorOption<Float> {
        if (_registry == null) {
            init();
        }
        return _lineDecorationsWidth;
    }

    public static var lineHeight(get, never):IEditorOption<Float>;
    static function get_lineHeight():IEditorOption<Float> {
        if (_registry == null) {
            init();
        }
        return _lineHeight;
    }

    public static var lineNumbers(get, never):IEditorOption<InternalEditorRenderLineNumbersOptions>;
    static function get_lineNumbers():IEditorOption<InternalEditorRenderLineNumbersOptions> {
        if (_registry == null) {
            init();
        }
        return _lineNumbers;
    }

    public static var lineNumbersMinChars(get, never):IEditorOption<Int>;
    static function get_lineNumbersMinChars():IEditorOption<Int> {
        if (_registry == null) {
            init();
        }
        return _lineNumbersMinChars;
    }

    public static var links(get, never):IEditorOption<Bool>;
    static function get_links():IEditorOption<Bool> {
        if (_registry == null) {
            init();
        }
        return _links;
    }

    public static var matchBrackets(get, never):IEditorOption<String>;
    static function get_matchBrackets():IEditorOption<String> {
        if (_registry == null) {
            init();
        }
        return _matchBrackets;
    }

    public static var mouseWheelZoom(get, never):IEditorOption<Bool>;
    static function get_mouseWheelZoom():IEditorOption<Bool> {
        if (_registry == null) {
            init();
        }
        return _mouseWheelZoom;
    }

    public static var multiCursorModifier(get, never):IEditorOption<String>;
    static function get_multiCursorModifier():IEditorOption<String> {
        if (_registry == null) {
            init();
        }
        return _multiCursorModifier;
    }

    public static var occurrencesHighlight(get, never):IEditorOption<String>;
    static function get_occurrencesHighlight():IEditorOption<String> {
        if (_registry == null) {
            init();
        }
        return _occurrencesHighlight;
    }

    public static var padding(get, never):IEditorOption<InternalEditorPaddingOptions>;
    static function get_padding():IEditorOption<InternalEditorPaddingOptions> {
        if (_registry == null) {
            init();
        }
        return _padding;
    }

    public static var definitionLinkOpensInPeek(get, never):IEditorOption<Bool>;
    static function get_definitionLinkOpensInPeek():IEditorOption<Bool> {
        if (_registry == null) {
            init();
        }
        return _definitionLinkOpensInPeek;
    }

    public static var quickSuggestions(get, never):IEditorOption<InternalQuickSuggestionsOptions>;
    static function get_quickSuggestions():IEditorOption<InternalQuickSuggestionsOptions> {
        if (_registry == null) {
            init();
        }
        return _quickSuggestions;
    }

    public static var quickSuggestionsDelay(get, never):IEditorOption<Int>;
    static function get_quickSuggestionsDelay():IEditorOption<Int> {
        if (_registry == null) {
            init();
        }
        return _quickSuggestionsDelay;
    }

    public static var readOnly(get, never):IEditorOption<Bool>;
    static function get_readOnly():IEditorOption<Bool> {
        if (_registry == null) {
            init();
        }
        return _readOnly;
    }

    public static var renderControlCharacters(get, never):IEditorOption<Bool>;
    static function get_renderControlCharacters():IEditorOption<Bool> {
        if (_registry == null) {
            init();
        }
        return _renderControlCharacters;
    }

    public static var renderFinalNewline(get, never):IEditorOption<String>;
    static function get_renderFinalNewline():IEditorOption<String> {
        if (_registry == null) {
            init();
        }
        return _renderFinalNewline;
    }

    public static var renderLineHighlight(get, never):IEditorOption<String>;
    static function get_renderLineHighlight():IEditorOption<String> {
        if (_registry == null) {
            init();
        }
        return _renderLineHighlight;
    }

    public static var renderWhitespace(get, never):IEditorOption<String>;
    static function get_renderWhitespace():IEditorOption<String> {
        if (_registry == null) {
            init();
        }
        return _renderWhitespace;
    }

    public static var roundedSelection(get, never):IEditorOption<Bool>;
    static function get_roundedSelection():IEditorOption<Bool> {
        if (_registry == null) {
            init();
        }
        return _roundedSelection;
    }

    public static var rulers(get, never):IEditorOption<Array<IRulerOption>>;
    static function get_rulers():IEditorOption<Array<IRulerOption>> {
        if (_registry == null) {
            init();
        }
        return _rulers;
    }

    public static var scrollbar(get, never):IEditorOption<InternalEditorScrollbarOptions>;
    static function get_scrollbar():IEditorOption<InternalEditorScrollbarOptions> {
        if (_registry == null) {
            init();
        }
        return _scrollbar;
    }

    public static var scrollBeyondLastColumn(get, never):IEditorOption<Int>;
    static function get_scrollBeyondLastColumn():IEditorOption<Int> {
        if (_registry == null) {
            init();
        }
        return _scrollBeyondLastColumn;
    }

    public static var scrollBeyondLastLine(get, never):IEditorOption<Bool>;
    static function get_scrollBeyondLastLine():IEditorOption<Bool> {
        if (_registry == null) {
            init();
        }
        return _scrollBeyondLastLine;
    }

    public static var selectionHighlight(get, never):IEditorOption<Bool>;
    static function get_selectionHighlight():IEditorOption<Bool> {
        if (_registry == null) {
            init();
        }
        return _selectionHighlight;
    }

    public static var showFoldingControls(get, never):IEditorOption<String>;
    static function get_showFoldingControls():IEditorOption<String> {
        if (_registry == null) {
            init();
        }
        return _showFoldingControls;
    }

    public static var smoothScrolling(get, never):IEditorOption<Bool>;
    static function get_smoothScrolling():IEditorOption<Bool> {
        if (_registry == null) {
            init();
        }
        return _smoothScrolling;
    }

    public static var bracketPairColorization(get, never):IEditorOption<InternalBracketPairColorizationOptions>;
    static function get_bracketPairColorization():IEditorOption<InternalBracketPairColorizationOptions> {
        if (_registry == null) {
            init();
        }
        return _bracketPairColorization;
    }

    public static var guides(get, never):IEditorOption<InternalGuidesOptions>;
    static function get_guides():IEditorOption<InternalGuidesOptions> {
        if (_registry == null) {
            init();
        }
        return _guides;
    }

    public static var stickyScroll(get, never):IEditorOption<EditorStickyScrollOptions>;
    static function get_stickyScroll():IEditorOption<EditorStickyScrollOptions> {
        if (_registry == null) {
            init();
        }
        return _stickyScroll;
    }

    public static var suggest(get, never):IEditorOption<InternalSuggestOptions>;
    static function get_suggest():IEditorOption<InternalSuggestOptions> {
        if (_registry == null) {
            init();
        }
        return _suggest;
    }

    public static var suggestOnTriggerCharacters(get, never):IEditorOption<Bool>;
    static function get_suggestOnTriggerCharacters():IEditorOption<Bool> {
        if (_registry == null) {
            init();
        }
        return _suggestOnTriggerCharacters;
    }

    public static var wordSeparators(get, never):IEditorOption<String>;
    static function get_wordSeparators():IEditorOption<String> {
        if (_registry == null) {
            init();
        }
        return _wordSeparators;
    }

    public static var wordWrap(get, never):IEditorOption<String>;
    static function get_wordWrap():IEditorOption<String> {
        if (_registry == null) {
            init();
        }
        return _wordWrap;
    }

    public static var wordWrapColumn(get, never):IEditorOption<Int>;
    static function get_wordWrapColumn():IEditorOption<Int> {
        if (_registry == null) {
            init();
        }
        return _wordWrapColumn;
    }

    public static var wrappingIndent(get, never):IEditorOption<WrappingIndent>;
    static function get_wrappingIndent():IEditorOption<WrappingIndent> {
        if (_registry == null) {
            init();
        }
        return _wrappingIndent;
    }

    static function init():Void {
        _registry = [];
        // Same order as Monaco's `EditorOptions` (the registry is indexed by id)
        _acceptSuggestionOnEnter = register(new EditorStringEnumOption(EditorOption.acceptSuggestionOnEnter, 'acceptSuggestionOnEnter', 'on', ['on', 'smart', 'off']));
        _accessibilitySupport = register(new EditorAccessibilitySupport());
        _autoClosingBrackets = register(new EditorStringEnumOption(EditorOption.autoClosingBrackets, 'autoClosingBrackets', 'languageDefined', ['always', 'languageDefined', 'beforeWhitespace', 'never']));
        _autoClosingDelete = register(new EditorStringEnumOption(EditorOption.autoClosingDelete, 'autoClosingDelete', 'auto', ['always', 'auto', 'never']));
        _autoClosingOvertype = register(new EditorStringEnumOption(EditorOption.autoClosingOvertype, 'autoClosingOvertype', 'auto', ['always', 'auto', 'never']));
        _autoClosingQuotes = register(new EditorStringEnumOption(EditorOption.autoClosingQuotes, 'autoClosingQuotes', 'languageDefined', ['always', 'languageDefined', 'beforeWhitespace', 'never']));
        _autoIndent = register(new EditorEnumOption(EditorOption.autoIndent, 'autoIndent', EditorAutoIndentStrategy.Full, 'full', ['none', 'keep', 'brackets', 'advanced', 'full'], _autoIndentFromString));
        _automaticLayout = register(new EditorBooleanOption(EditorOption.automaticLayout, 'automaticLayout', false));
        _autoSurround = register(new EditorStringEnumOption(EditorOption.autoSurround, 'autoSurround', 'languageDefined', ['languageDefined', 'quotes', 'brackets', 'never']));
        _bracketPairColorization = register(new BracketPairColorization());
        _guides = register(new GuideOptions());
        _colorDecorators = register(new EditorBooleanOption(EditorOption.colorDecorators, 'colorDecorators', true));
        _contextmenu = register(new EditorBooleanOption(EditorOption.contextmenu, 'contextmenu', true));
        _cursorBlinking = register(new EditorEnumOption(EditorOption.cursorBlinking, 'cursorBlinking', TextEditorCursorBlinkingStyle.Blink, 'blink', ['blink', 'smooth', 'phase', 'expand', 'solid'], _cursorBlinkingStyleFromString));
        _cursorSmoothCaretAnimation = register(new EditorStringEnumOption(EditorOption.cursorSmoothCaretAnimation, 'cursorSmoothCaretAnimation', 'off', ['off', 'explicit', 'on']));
        _cursorStyle = register(new EditorEnumOption(EditorOption.cursorStyle, 'cursorStyle', TextEditorCursorStyle.Line, 'line', ['line', 'block', 'underline', 'line-thin', 'block-outline', 'underline-thin'], _cursorStyleFromString));
        _cursorSurroundingLines = register(new EditorIntOption(EditorOption.cursorSurroundingLines, 'cursorSurroundingLines', 0, 0, EditorOptions.MAX_SAFE_SMALL_INTEGER));
        _cursorWidth = register(new EditorIntOption(EditorOption.cursorWidth, 'cursorWidth', 0, 0, EditorOptions.MAX_SAFE_SMALL_INTEGER));
        _stickyScroll = register(new EditorStickyScroll());
        _fixedOverflowWidgets = register(new EditorBooleanOption(EditorOption.fixedOverflowWidgets, 'fixedOverflowWidgets', false));
        _folding = register(new EditorBooleanOption(EditorOption.folding, 'folding', true));
        _foldingStrategy = register(new EditorStringEnumOption(EditorOption.foldingStrategy, 'foldingStrategy', 'auto', ['auto', 'indentation']));
        _foldingHighlight = register(new EditorBooleanOption(EditorOption.foldingHighlight, 'foldingHighlight', true));
        _foldingImportsByDefault = register(new EditorBooleanOption(EditorOption.foldingImportsByDefault, 'foldingImportsByDefault', false));
        _foldingMaximumRegions = register(new EditorIntOption(EditorOption.foldingMaximumRegions, 'foldingMaximumRegions', 5000, 10, 65000)); // limit must be less than foldingRanges MAX_FOLDING_REGIONS
        _unfoldOnClickAfterEndOfLine = register(new EditorBooleanOption(EditorOption.unfoldOnClickAfterEndOfLine, 'unfoldOnClickAfterEndOfLine', false));
        _fontFamily = register(new EditorStringOption(EditorOption.fontFamily, 'fontFamily', EditorOptions.EDITOR_FONT_DEFAULTS.fontFamily));
        _fontLigatures = register(new EditorFontLigatures());
        _fontSize = register(new EditorFontSize());
        _fontWeight = register(new EditorFontWeight());
        // The format on type contribution (contrib/format)
        register(new EditorBooleanOption(EditorOption.formatOnType, 'formatOnType', false));
        _glyphMargin = register(new EditorBooleanOption(EditorOption.glyphMargin, 'glyphMargin', true));
        _gotoLocation = register(new EditorGoToLocation());
        _hover = register(new EditorHover());
        _letterSpacing = register(new EditorFloatOption(EditorOption.letterSpacing, 'letterSpacing', EditorOptions.EDITOR_FONT_DEFAULTS.letterSpacing, x -> EditorFloatOption.clamp(x, -5, 20)));
        _lineDecorationsWidth = register(new EditorLineDecorationsWidth());
        _lineHeight = register(new EditorLineHeight());
        _lineNumbers = register(new EditorRenderLineNumbersOption());
        _lineNumbersMinChars = register(new EditorIntOption(EditorOption.lineNumbersMinChars, 'lineNumbersMinChars', 5, 1, 300));
        _links = register(new EditorBooleanOption(EditorOption.links, 'links', true));
        _matchBrackets = register(new EditorStringEnumOption(EditorOption.matchBrackets, 'matchBrackets', 'always', ['always', 'near', 'never']));
        _mouseWheelZoom = register(new EditorBooleanOption(EditorOption.mouseWheelZoom, 'mouseWheelZoom', false));
        _multiCursorModifier = register(new EditorEnumOption(EditorOption.multiCursorModifier, 'multiCursorModifier', 'altKey', 'alt', ['ctrlCmd', 'alt'], _multiCursorModifierFromString));
        _occurrencesHighlight = register(new EditorStringEnumOption(EditorOption.occurrencesHighlight, 'occurrencesHighlight', 'singleFile', ['off', 'singleFile', 'multiFile']));
        _padding = register(new EditorPadding());
        _definitionLinkOpensInPeek = register(new EditorBooleanOption(EditorOption.definitionLinkOpensInPeek, 'definitionLinkOpensInPeek', false));
        _quickSuggestions = register(new EditorQuickSuggestions());
        _quickSuggestionsDelay = register(new EditorIntOption(EditorOption.quickSuggestionsDelay, 'quickSuggestionsDelay', 10, 0, EditorOptions.MAX_SAFE_SMALL_INTEGER));
        _readOnly = register(new EditorBooleanOption(EditorOption.readOnly, 'readOnly', false));
        // The drag and drop of the selection (dnd contribution)
        register(new EditorBooleanOption(EditorOption.dragAndDrop, 'dragAndDrop', true));
        register(new EditorStringEnumOption(EditorOption.mouseStyle, 'mouseStyle', 'text', ['text', 'default', 'copy']));
        _renderControlCharacters = register(new EditorBooleanOption(EditorOption.renderControlCharacters, 'renderControlCharacters', true));
        _renderFinalNewline = register(new EditorStringEnumOption(EditorOption.renderFinalNewline, 'renderFinalNewline', (Platform.isLinux ? 'dimmed' : 'on'), ['off', 'on', 'dimmed']));
        _renderLineHighlight = register(new EditorStringEnumOption(EditorOption.renderLineHighlight, 'renderLineHighlight', 'line', ['none', 'gutter', 'line', 'all']));
        _renderWhitespace = register(new EditorStringEnumOption(EditorOption.renderWhitespace, 'renderWhitespace', 'selection', ['none', 'boundary', 'selection', 'trailing', 'all']));
        _roundedSelection = register(new EditorBooleanOption(EditorOption.roundedSelection, 'roundedSelection', true));
        _rulers = register(new EditorRulers());
        _scrollbar = register(new EditorScrollbar());
        _scrollBeyondLastColumn = register(new EditorIntOption(EditorOption.scrollBeyondLastColumn, 'scrollBeyondLastColumn', 4, 0, EditorOptions.MAX_SAFE_SMALL_INTEGER));
        _scrollBeyondLastLine = register(new EditorBooleanOption(EditorOption.scrollBeyondLastLine, 'scrollBeyondLastLine', true));
        register(new EditorScrollBeyondLastLineGap());
        register(new EditorBooleanOption(EditorOption.scrollbarThumbExcludesPadding, 'scrollbarThumbExcludesPadding', false));
        register(new EditorBooleanOption(EditorOption.preferColorEmoji, 'preferColorEmoji', true));
        register(new EditorStringEnumOption(EditorOption.overviewRulerPosition, 'overviewRulerPosition', 'overlay', ['overlay', 'beside']));
        register(new EditorFloatOption(EditorOption.overviewRulerGap, 'overviewRulerGap', 0, x -> EditorFloatOption.clamp(x, 0, 1000)));
        _selectionHighlight = register(new EditorBooleanOption(EditorOption.selectionHighlight, 'selectionHighlight', true));
        _showFoldingControls = register(new EditorStringEnumOption(EditorOption.showFoldingControls, 'showFoldingControls', 'mouseover', ['always', 'never', 'mouseover']));
        _smoothScrolling = register(new EditorBooleanOption(EditorOption.smoothScrolling, 'smoothScrolling', false));
        _suggest = register(new EditorSuggest());
        _suggestOnTriggerCharacters = register(new EditorBooleanOption(EditorOption.suggestOnTriggerCharacters, 'suggestOnTriggerCharacters', true));
        _wordSeparators = register(new EditorStringOption(EditorOption.wordSeparators, 'wordSeparators', WordHelper.USUAL_WORD_SEPARATORS));
        _wordWrap = register(new EditorStringEnumOption(EditorOption.wordWrap, 'wordWrap', 'off', ['off', 'on', 'wordWrapColumn', 'bounded']));
        _wordWrapColumn = register(new EditorIntOption(EditorOption.wordWrapColumn, 'wordWrapColumn', 80, 1, EditorOptions.MAX_SAFE_SMALL_INTEGER));
        _wrappingIndent = register(new WrappingIndentOption());
        // The view options (EditorViewOptions.hx), registered with the view
        EditorViewOptions.registerSimple(o -> register(o));
        // The cursor options (EditorCursorOptions.hx), registered with the cursor
        EditorCursorOptions.registerSimple(o -> register(o));
        // The find option (EditorFindOptions.hx), registered with the find contribution
        cityscape.common.config.EditorFindOptions.EditorFindOptionsRegistration.registerSimple(o -> register(o));
        // The comments option (EditorCommentsOptions.hx), registered with the comment contribution
        cityscape.common.config.EditorCommentsOptions.EditorCommentsOptionsRegistration.registerSimple(o -> register(o));
        // The options of suggest, code actions (EditorLanguageFeatureOptions.hx)
        cityscape.common.config.EditorLanguageFeatureOptions.EditorLanguageFeatureOptionsRegistration.registerSimple(o -> register(o));
        EditorViewOptions.registerComputed(o -> register(o));
    }

    /**
     * @internal
     */
    public static function boolean(value:Any, defaultValue:Bool):Bool {
        if (JsValues.isUndefined(value)) {
            return defaultValue;
        }
        if (JsValues.isString(value) && (value : String) == 'false') {
            // treat the string 'false' as false
            return false;
        }
        return JsValues.truthy(value);
    }

    /**
     * @internal
     */
    public static function clampedInt(value:Any, defaultValue:Int, minimum:Int, maximum:Int):Int {
        if (JsValues.isUndefined(value)) {
            return defaultValue;
        }
        var r = JsValues.parseInt(value);
        if (Math.isNaN(r)) {
            return defaultValue;
        }
        r = Math.max(minimum, r);
        r = Math.min(maximum, r);
        return Std.int(r);
    }

    /**
     * @internal
     */
    public static function clampedFloat(value:Any, defaultValue:Float, minimum:Float, maximum:Float):Float {
        if (JsValues.isUndefined(value)) {
            return defaultValue;
        }
        final r = EditorFloatOption.float(value, defaultValue);
        return EditorFloatOption.clamp(r, minimum, maximum);
    }

    /**
     * @internal
     */
    public static function stringSet(value:Any, defaultValue:String, allowedValues:Array<String>, ?renamedValues:Map<String, String>):String {
        if (!JsValues.isString(value)) {
            return defaultValue;
        }
        final s:String = value;
        if (renamedValues != null && renamedValues.exists(s)) {
            return renamedValues.get(s);
        }
        if (allowedValues.indexOf(s) == -1) {
            return defaultValue;
        }
        return s;
    }

    /**
     * `applyUpdate`: deep merges `update` into `value` (anonymous structures
     * field by field, arrays compared element by element), modifying `value`.
     * @internal
     */
    public static function applyUpdate<T>(value:Null<T>, update:T):ApplyUpdateResult<T> {
        if (!JsValues.isObject(value) || !JsValues.isObject(update)) {
            return new ApplyUpdateResult(update, !strictEquals(value, update));
        }
        if (JsValues.isArray(value) || JsValues.isArray(update)) {
            final arrayEquals = JsValues.isArray(value) && JsValues.isArray(update) && arraysEqual(cast value, cast update);
            return new ApplyUpdateResult(update, !arrayEquals);
        }
        var didChange = false;
        for (key in Reflect.fields(update)) {
            final result = applyUpdate(Reflect.field(value, key), Reflect.field(update, key));
            if (result.didChange) {
                Reflect.setField(value, key, result.newValue);
                didChange = true;
            }
        }
        return new ApplyUpdateResult(value, didChange);
    }

    /**
     * JavaScript's `===` on option values: numbers and booleans by value,
     * strings by content, objects and functions by reference.
     */
    static function strictEquals(a:Any, b:Any):Bool {
        if (JsValues.isNumber(a) && JsValues.isNumber(b)) {
            return (a : Float) == (b : Float);
        }
        if (JsValues.isString(a) && JsValues.isString(b)) {
            return (a : String) == (b : String);
        }
        if (JsValues.isBoolean(a) && JsValues.isBoolean(b)) {
            return (a : Bool) == (b : Bool);
        }
        if (JsValues.isFunction(a) || JsValues.isFunction(b)) {
            return Reflect.compareMethods(a, b);
        }
        return a == b;
    }

    static function arraysEqual(a:Array<Any>, b:Array<Any>):Bool {
        if (a == b) {
            return true;
        }
        if (a.length != b.length) {
            return false;
        }
        for (i in 0...a.length) {
            if (!strictEquals(a[i], b[i])) {
                return false;
            }
        }
        return true;
    }

}
