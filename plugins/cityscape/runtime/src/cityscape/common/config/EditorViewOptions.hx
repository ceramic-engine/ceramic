// Ported from vscode src/vs/editor/common/config/editorOptions.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.config;

import cityscape.common.config.EditorOptions;
import cityscape.common.config.FontInfo;
import cityscape.platform.accessibility.common.Accessibility.AccessibilitySupport;

/*
 * The editor options the view reads, ported with the view (step 2):
 * disableMonospaceOptimizations, emptySelectionClipboard,
 * experimentalWhitespaceRendering, fontInfo, hideCursorInOverviewRuler,
 * overviewRulerBorder, overviewRulerLanes, renderLineHighlightOnlyWhenFocus,
 * renderValidationDecorations,
 * stopRenderingLineAfter, wordBreak, wordWrapBreakAfterCharacters,
 * wordWrapBreakBeforeCharacters, wordWrapOverride1, wordWrapOverride2,
 * pixelRatio, layoutInfo, wrappingInfo, wrappingStrategy.
 *
 * They are registered by `EditorOptions.init()` through `register()` below,
 * in Monaco's order. The layout computation has no minimap (Cityscape has
 * none): `layoutInfo.minimap` is Monaco's layout of a disabled minimap.
 */

/**
 * The position of the overview ruler.
 */
typedef OverviewRulerPosition = {
    /**
     * Width of the overview ruler
     */
    final width:Float;
    /**
     * Height of the overview ruler
     */
    final height:Float;
    /**
     * Top position for the overview ruler
     */
    final top:Float;
    /**
     * Right position for the overview ruler
     */
    final right:Float;
}

enum abstract RenderMinimap(Int) from Int to Int {
    var None = 0;
    var Text = 1;
    var Blocks = 2;
}

/**
 * The internal layout details of the editor (Monaco keeps this for the
 * minimap; it is always the layout of a disabled minimap here).
 */
typedef EditorMinimapLayoutInfo = {
    final renderMinimap:RenderMinimap;
    final minimapLeft:Float;
    final minimapWidth:Float;
    final minimapHeightIsEditorHeight:Bool;
    final minimapIsSampling:Bool;
    final minimapScale:Float;
    final minimapLineHeight:Float;
    final minimapCanvasInnerWidth:Float;
    final minimapCanvasInnerHeight:Float;
    final minimapCanvasOuterWidth:Float;
    final minimapCanvasOuterHeight:Float;
}

/**
 * The internal layout details of the editor.
 */
typedef EditorLayoutInfo = {
    /**
     * Full editor width.
     */
    final width:Float;
    /**
     * Full editor height.
     */
    final height:Float;
    /**
     * Left position for the glyph margin.
     */
    final glyphMarginLeft:Float;
    /**
     * The width of the glyph margin.
     */
    final glyphMarginWidth:Float;
    /**
     * The number of decoration lanes to render in the glyph margin.
     */
    final glyphMarginDecorationLaneCount:Int;
    /**
     * Left position for the line numbers.
     */
    final lineNumbersLeft:Float;
    /**
     * The width of the line numbers.
     */
    final lineNumbersWidth:Float;
    /**
     * Left position for the line decorations.
     */
    final decorationsLeft:Float;
    /**
     * The width of the line decorations.
     */
    final decorationsWidth:Float;
    /**
     * Left position for the content (actual text)
     */
    final contentLeft:Float;
    /**
     * The width of the content (actual text)
     */
    final contentWidth:Float;
    /**
     * Layout information for the minimap
     */
    final minimap:EditorMinimapLayoutInfo;
    /**
     * The number of columns (of typical characters) fitting on a viewport line.
     */
    final viewportColumn:Int;
    final isWordWrapMinified:Bool;
    final isViewportWrapping:Bool;
    final wrappingColumn:Int;
    /**
     * The width of the vertical scrollbar.
     */
    final verticalScrollbarWidth:Float;
    /**
     * The height of the horizontal scrollbar.
     */
    final horizontalScrollbarHeight:Float;
    /**
     * The position of the overview ruler.
     */
    final overviewRuler:OverviewRulerPosition;
}

/**
 * @internal
 */
typedef EditorLayoutInfoComputerEnv = {
    final memory:Null<ComputeOptionsMemory>;
    final outerWidth:Float;
    final outerHeight:Float;
    final isDominatedByLongLines:Bool;
    final lineHeight:Float;
    final viewLineCount:Int;
    final lineNumbersDigitCount:Int;
    final typicalHalfwidthCharacterWidth:Float;
    final maxDigitWidth:Float;
    final pixelRatio:Float;
    final glyphMarginDecorationLaneCount:Int;
}

typedef EditorWrappingInfo = {
    final isDominatedByLongLines:Bool;
    final isWordWrapMinified:Bool;
    final isViewportWrapping:Bool;
    final wrappingColumn:Int;
}

class EditorEmptySelectionClipboard extends EditorBooleanOption {

    public function new() {
        super(EditorOption.emptySelectionClipboard, 'emptySelectionClipboard', true);
    }

    override public function compute(env:IEnvironmentalOptions, options:IComputedEditorOptions, value:Bool):Bool {
        return value && env.emptySelectionClipboard;
    }

}

class EditorFontInfo extends ComputedEditorOption<FontInfo> {

    public function new() {
        super(EditorOption.fontInfo);
    }

    public function compute(env:IEnvironmentalOptions, options:IComputedEditorOptions, _:FontInfo):FontInfo {
        return env.fontInfo;
    }

}

class EditorPixelRatio extends ComputedEditorOption<Float> {

    public function new() {
        super(EditorOption.pixelRatio);
    }

    public function compute(env:IEnvironmentalOptions, options:IComputedEditorOptions, _:Float):Float {
        return env.pixelRatio;
    }

}

class WrappingStrategy extends BaseEditorOption<String> {

    public function new() {
        super(EditorOption.wrappingStrategy, 'wrappingStrategy', 'simple');
    }

    public function validate(input:Any):String {
        return EditorOptions.stringSet(input, 'simple', ['simple', 'advanced']);
    }

    override public function compute(env:IEnvironmentalOptions, options:IComputedEditorOptions, value:String):String {
        final accessibilitySupport = options.get(EditorOption.accessibilitySupport);
        if (accessibilitySupport == AccessibilitySupport.Enabled) {
            // if we know for a fact that a screen reader is attached, we switch our strategy to advanced to
            // help that the editor's wrapping points match the textarea's wrapping points
            return 'advanced';
        }
        return value;
    }

}

/**
 * @internal
 */
class EditorLayoutInfoComputer extends ComputedEditorOption<EditorLayoutInfo> {

    public function new() {
        super(EditorOption.layoutInfo);
    }

    public function compute(env:IEnvironmentalOptions, options:IComputedEditorOptions, _:EditorLayoutInfo):EditorLayoutInfo {
        return EditorLayoutInfoComputer.computeLayout(options, {
            memory: env.memory,
            outerWidth: env.outerWidth,
            outerHeight: env.outerHeight,
            isDominatedByLongLines: env.isDominatedByLongLines,
            lineHeight: env.fontInfo.lineHeight,
            viewLineCount: env.viewLineCount,
            lineNumbersDigitCount: env.lineNumbersDigitCount,
            typicalHalfwidthCharacterWidth: env.fontInfo.typicalHalfwidthCharacterWidth,
            maxDigitWidth: env.fontInfo.maxDigitWidth,
            pixelRatio: env.pixelRatio,
            glyphMarginDecorationLaneCount: env.glyphMarginDecorationLaneCount
        });
    }

    /**
     * `x | 0` in JavaScript.
     */
    static inline function toInt32(value:Float):Int {
        return Math.isNaN(value) || !Math.isFinite(value) ? 0 : Std.int(value);
    }

    /**
     * Monaco's `_computeMinimapLayout` for a disabled minimap.
     */
    static function disabledMinimapLayout(outerHeight:Float, pixelRatio:Float):EditorMinimapLayoutInfo {
        return {
            renderMinimap: RenderMinimap.None,
            minimapLeft: 0,
            minimapWidth: 0,
            minimapHeightIsEditorHeight: false,
            minimapIsSampling: false,
            minimapScale: 1,
            minimapLineHeight: 1,
            minimapCanvasInnerWidth: 0,
            minimapCanvasInnerHeight: Math.floor(pixelRatio * outerHeight),
            minimapCanvasOuterWidth: 0,
            minimapCanvasOuterHeight: outerHeight,
        };
    }

    public static function computeLayout(options:IComputedEditorOptions, env:EditorLayoutInfoComputerEnv):EditorLayoutInfo {
        final outerWidth = toInt32(env.outerWidth);
        final outerHeight = toInt32(env.outerHeight);
        final lineHeight = toInt32(env.lineHeight);
        final lineNumbersDigitCount = env.lineNumbersDigitCount;
        final typicalHalfwidthCharacterWidth = env.typicalHalfwidthCharacterWidth;
        final maxDigitWidth = env.maxDigitWidth;
        final pixelRatio = env.pixelRatio;

        final wordWrapOverride2 = options.get(EditorOption.wordWrapOverride2);
        final wordWrapOverride1 = (wordWrapOverride2 == 'inherit' ? options.get(EditorOption.wordWrapOverride1) : wordWrapOverride2);
        final wordWrap = (wordWrapOverride1 == 'inherit' ? options.get(EditorOption.wordWrap) : wordWrapOverride1);

        final wordWrapColumn = options.get(EditorOption.wordWrapColumn);
        final isDominatedByLongLines = env.isDominatedByLongLines;

        final showGlyphMargin = options.get(EditorOption.glyphMargin);
        final showLineNumbers = (options.get(EditorOption.lineNumbers).renderType != RenderLineNumbersType.Off);
        final lineNumbersMinChars = options.get(EditorOption.lineNumbersMinChars);

        final scrollbar = options.get(EditorOption.scrollbar);
        final verticalScrollbarWidth = scrollbar.verticalScrollbarSize;
        final verticalScrollbarHasArrows = scrollbar.verticalHasArrows;
        final scrollbarArrowSize = scrollbar.arrowSize;
        final horizontalScrollbarHeight = scrollbar.horizontalScrollbarSize;

        final folding = options.get(EditorOption.folding);
        final showFoldingDecoration = options.get(EditorOption.showFoldingControls) != 'never';

        var lineDecorationsWidth = options.get(EditorOption.lineDecorationsWidth);
        if (folding && showFoldingDecoration) {
            lineDecorationsWidth += 16;
        }

        var lineNumbersWidth:Float = 0;
        if (showLineNumbers) {
            final digitCount = (lineNumbersDigitCount > lineNumbersMinChars ? lineNumbersDigitCount : lineNumbersMinChars);
            lineNumbersWidth = Math.round(digitCount * maxDigitWidth);
        }

        var glyphMarginWidth:Float = 0;
        if (showGlyphMargin) {
            glyphMarginWidth = lineHeight * env.glyphMarginDecorationLaneCount;
        }

        final glyphMarginLeft:Float = 0;
        final lineNumbersLeft = glyphMarginLeft + glyphMarginWidth;
        final decorationsLeft = lineNumbersLeft + lineNumbersWidth;
        final contentLeft = decorationsLeft + lineDecorationsWidth;

        final remainingWidth = outerWidth - glyphMarginWidth - lineNumbersWidth - lineDecorationsWidth;

        var isWordWrapMinified = false;
        var isViewportWrapping = false;
        var wrappingColumn = -1;

        if (wordWrapOverride1 == 'inherit' && isDominatedByLongLines) {
            // Force viewport width wrapping if model is dominated by long lines
            isWordWrapMinified = true;
            isViewportWrapping = true;
        } else if (wordWrap == 'on' || wordWrap == 'bounded') {
            isViewportWrapping = true;
        } else if (wordWrap == 'wordWrapColumn') {
            wrappingColumn = wordWrapColumn;
        }

        final minimapLayout = disabledMinimapLayout(outerHeight, pixelRatio);

        final contentWidth = remainingWidth - minimapLayout.minimapWidth;

        // (leaving 2px for the cursor to have space after the last character)
        final viewportColumnFloat = Math.floor((contentWidth - verticalScrollbarWidth - 2) / typicalHalfwidthCharacterWidth);
        final viewportColumn = (viewportColumnFloat > 1 ? Std.int(viewportColumnFloat) : 1);

        final verticalArrowSize = (verticalScrollbarHasArrows ? scrollbarArrowSize : 0);

        if (isViewportWrapping) {
            // compute the actual wrappingColumn
            wrappingColumn = (viewportColumn > 1 ? viewportColumn : 1);
            if (wordWrap == 'bounded') {
                wrappingColumn = (wrappingColumn < wordWrapColumn ? wrappingColumn : wordWrapColumn);
            }
        }

        return {
            width: outerWidth,
            height: outerHeight,

            glyphMarginLeft: glyphMarginLeft,
            glyphMarginWidth: glyphMarginWidth,
            glyphMarginDecorationLaneCount: env.glyphMarginDecorationLaneCount,

            lineNumbersLeft: lineNumbersLeft,
            lineNumbersWidth: lineNumbersWidth,

            decorationsLeft: decorationsLeft,
            decorationsWidth: lineDecorationsWidth,

            contentLeft: contentLeft,
            contentWidth: contentWidth,

            minimap: minimapLayout,

            viewportColumn: viewportColumn,

            isWordWrapMinified: isWordWrapMinified,
            isViewportWrapping: isViewportWrapping,
            wrappingColumn: wrappingColumn,

            verticalScrollbarWidth: verticalScrollbarWidth,
            horizontalScrollbarHeight: horizontalScrollbarHeight,

            overviewRuler: {
                top: verticalArrowSize,
                width: verticalScrollbarWidth,
                height: (outerHeight - 2 * verticalArrowSize),
                right: 0
            }
        };
    }

}

class EditorWrappingInfoComputer extends ComputedEditorOption<EditorWrappingInfo> {

    public function new() {
        super(EditorOption.wrappingInfo);
    }

    public function compute(env:IEnvironmentalOptions, options:IComputedEditorOptions, _:EditorWrappingInfo):EditorWrappingInfo {
        final layoutInfo = options.get(EditorOption.layoutInfo);

        return {
            isDominatedByLongLines: env.isDominatedByLongLines,
            isWordWrapMinified: layoutInfo.isWordWrapMinified,
            isViewportWrapping: layoutInfo.isViewportWrapping,
            wrappingColumn: layoutInfo.wrappingColumn,
        };
    }

}

/**
 * Registration of the view options, called by `EditorOptions.init()`.
 */
class EditorViewOptions {

    /**
     * `filterValidationDecorations` of editorOptions.ts.
     */
    public static function filterValidationDecorations(options:IComputedEditorOptions):Bool {
        final renderValidationDecorations = options.get(EditorOption.renderValidationDecorations);
        if (renderValidationDecorations == 'editable') {
            return options.get(EditorOption.readOnly);
        }
        return renderValidationDecorations == 'on' ? false : true;
    }

    public static inline final DEFAULT_WORD_WRAP_BREAK_AFTER_CHARACTERS = ' \t})]?|/&.,;¢°′″‰℃、。｡､￠，．：；？！％・･ゝゞヽヾーァィゥェォッャュョヮヵヶぁぃぅぇぉっゃゅょゎゕゖㇰㇱㇲㇳㇴㇵㇶㇷㇸㇹㇺㇻㇼㇽㇾㇿ々〻ｧｨｩｪｫｬｭｮｯｰ”〉》」』】〕）］｝｣';

    public static inline final DEFAULT_WORD_WRAP_BREAK_BEFORE_CHARACTERS = '([{‘“〈《「『【〔（［｛｢£¥＄￡￥+＋';

    /**
     * The options registered before the others (Monaco's alphabetical part
     * of `EditorOptions`), in `register` order.
     */
    public static function registerSimple(register:(option:IEditorOption<Any>) -> Void):Void {
        register(cast new EditorBooleanOption(EditorOption.disableMonospaceOptimizations, 'disableMonospaceOptimizations', false));
        register(cast new EditorEmptySelectionClipboard());
        register(cast new EditorStringEnumOption(EditorOption.experimentalWhitespaceRendering, 'experimentalWhitespaceRendering', 'svg', ['svg', 'font', 'off']));
        register(cast new EditorFontInfo());
        register(cast new EditorBooleanOption(EditorOption.hideCursorInOverviewRuler, 'hideCursorInOverviewRuler', false));
        register(cast new EditorBooleanOption(EditorOption.overviewRulerBorder, 'overviewRulerBorder', true));
        register(cast new EditorIntOption(EditorOption.overviewRulerLanes, 'overviewRulerLanes', 3, 0, 3));
        register(cast new EditorBooleanOption(EditorOption.renderLineHighlightOnlyWhenFocus, 'renderLineHighlightOnlyWhenFocus', false));
        register(cast new EditorStringEnumOption(EditorOption.renderValidationDecorations, 'renderValidationDecorations', 'editable', ['editable', 'on', 'off']));
        register(cast new EditorIntOption(EditorOption.stopRenderingLineAfter, 'stopRenderingLineAfter', 10000, -1, EditorOptions.MAX_SAFE_SMALL_INTEGER));
        register(cast new EditorStringEnumOption(EditorOption.wordBreak, 'wordBreak', 'normal', ['normal', 'keepAll']));
        register(cast new EditorStringOption(EditorOption.wordWrapBreakAfterCharacters, 'wordWrapBreakAfterCharacters', DEFAULT_WORD_WRAP_BREAK_AFTER_CHARACTERS));
        register(cast new EditorStringOption(EditorOption.wordWrapBreakBeforeCharacters, 'wordWrapBreakBeforeCharacters', DEFAULT_WORD_WRAP_BREAK_BEFORE_CHARACTERS));
        register(cast new EditorStringEnumOption(EditorOption.wordWrapOverride1, 'wordWrapOverride1', 'inherit', ['off', 'on', 'inherit']));
        register(cast new EditorStringEnumOption(EditorOption.wordWrapOverride2, 'wordWrapOverride2', 'inherit', ['off', 'on', 'inherit']));
    }

    /**
     * The options Monaco registers at the end (they depend on the others):
     * pixelRatio, layoutInfo, wrappingInfo, wrappingStrategy.
     */
    public static function registerComputed(register:(option:IEditorOption<Any>) -> Void):Void {
        register(cast new EditorPixelRatio());
        register(cast new EditorLayoutInfoComputer());
        register(cast new EditorWrappingInfoComputer());
        register(cast new WrappingStrategy());
    }

}
