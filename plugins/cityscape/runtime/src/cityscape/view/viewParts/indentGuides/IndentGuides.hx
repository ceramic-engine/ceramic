// Ported from vscode src/vs/editor/browser/viewParts/indentGuides/indentGuides.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.view.viewParts.indentGuides;

import cityscape.base.common.Arrays.ArrayQueue;
import cityscape.base.common.JsValues;
import cityscape.common.TextModelGuides;
import cityscape.common.ViewModel.IViewModel;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.EditorColorRegistry;
import cityscape.common.core.Position;
import cityscape.view.ViewTheme;
import glaze.Hsla;

/**
 * The guides of Monaco's `IndentGuidesOverlay`: `getGuidesByLine` merges
 * the indentation guides and the bracket pair guides of the visible lines
 * (the `guides` option), like Monaco. The Glaze view paints them
 * (`CityscapeViewElement`) with the colors of `IndentGuideColors` (the
 * theming participant of indentGuides.ts) instead of HTML and CSS rules.
 */
class IndentGuides {

    /**
     * Monaco's `IndentGuidesOverlay.getGuidesByLine`.
     */
    static final NO_GUIDES:Array<IndentGuide> = [];

    static final INDENT_CLASS_NAMES:Array<String> = [for (i in 0...30) 'core-guide-indent lvl-' + i];

    static final ACTIVE_INDENT_CLASS_NAMES:Array<String> = [for (i in 0...30) 'core-guide-indent lvl-' + i + ' indent-active'];

    /**
     * `'core-guide-indent lvl-' + level + (active ? ' indent-active' : '')`
     * (level below 30), made once.
     */
    public static inline function indentClassName(level:Int, active:Bool):String {
        return active ? ACTIVE_INDENT_CLASS_NAMES[level] : INDENT_CLASS_NAMES[level];
    }

    public static function getGuidesByLine(
        viewModel:IViewModel,
        bracketPairGuideOptions:InternalGuidesOptions,
        visibleStartLineNumber:Int,
        visibleEndLineNumber:Int,
        activeCursorPosition:Null<Position>,
        ?cache:IndentGuideCache,
        ?reuse:Array<Array<IndentGuide>>
    ):Array<Array<IndentGuide>> {
        final bracketGuides = !JsValues.strictEquals(bracketPairGuideOptions.bracketPairs, false)
            ? viewModel.getBracketGuidesInRangeByLine(
                visibleStartLineNumber,
                visibleEndLineNumber,
                activeCursorPosition,
                {
                    highlightActive: bracketPairGuideOptions.highlightActiveBracketPair,
                    horizontalGuides: JsValues.strictEquals(bracketPairGuideOptions.bracketPairsHorizontal, true)
                        ? HorizontalGuidesState.Enabled
                        : JsValues.strictEquals(bracketPairGuideOptions.bracketPairsHorizontal, 'active')
                            ? HorizontalGuidesState.EnabledForActive
                            : HorizontalGuidesState.Disabled,
                    includeInactive: JsValues.strictEquals(bracketPairGuideOptions.bracketPairs, true),
                }
            )
            : null;

        final indentGuides = bracketPairGuideOptions.indentation
            ? viewModel.getLinesIndentGuides(
                visibleStartLineNumber,
                visibleEndLineNumber
            )
            : null;

        var activeIndentStartLineNumber = 0;
        var activeIndentEndLineNumber = 0;
        var activeIndentLevel = 0;

        if (!JsValues.strictEquals(bracketPairGuideOptions.highlightActiveIndentation, false) && activeCursorPosition != null) {
            final activeIndentInfo = viewModel.getActiveIndentGuide(activeCursorPosition.lineNumber, visibleStartLineNumber, visibleEndLineNumber);
            activeIndentStartLineNumber = activeIndentInfo.startLineNumber;
            activeIndentEndLineNumber = activeIndentInfo.endLineNumber;
            activeIndentLevel = activeIndentInfo.indent;
        }

        final indentSize = viewModel.model.getOptions().indentSize;
        final highlightAlways = JsValues.strictEquals(bracketPairGuideOptions.highlightActiveIndentation, 'always');

        final result:Array<Array<IndentGuide>> = reuse != null ? reuse : [];
        final lineCount = visibleEndLineNumber - visibleStartLineNumber + 1;
        if (result.length > lineCount) {
            result.resize(lineCount);
        }
        for (lineNumber in visibleStartLineNumber...visibleEndLineNumber + 1) {
            final index = lineNumber - visibleStartLineNumber;
            var lineGuides = index < result.length ? result[index] : null;
            if (lineGuides == null) {
                lineGuides = [];
                if (index < result.length) {
                    result[index] = lineGuides;
                }
                else {
                    result.push(lineGuides);
                }
            }
            else {
                lineGuides.resize(0);
            }

            // Monaco's ArrayQueue of the line's bracket guides, read by index
            final bracketGuidesInLine:Array<IndentGuide> = bracketGuides != null ? bracketGuides[index] : NO_GUIDES;
            final bracketCount = bracketGuidesInLine.length;
            var next = 0;

            final indentGuidesInLine = indentGuides != null ? indentGuides[index] : 0;

            for (indentLvl in 1...indentGuidesInLine + 1) {
                final indentGuide = (indentLvl - 1) * indentSize + 1;
                final isActive =
                    // Disable active indent guide if there are bracket guides.
                    (highlightAlways || bracketCount == 0) &&
                    activeIndentStartLineNumber <= lineNumber &&
                    lineNumber <= activeIndentEndLineNumber &&
                    indentLvl == activeIndentLevel;
                // takeWhile(g -> g.visibleColumn < indentGuide)
                while (next < bracketCount && bracketGuidesInLine[next].visibleColumn < indentGuide) {
                    lineGuides.push(bracketGuidesInLine[next]);
                    next++;
                }
                final peeked = next < bracketCount ? bracketGuidesInLine[next] : null;
                if (peeked == null || peeked.visibleColumn != indentGuide || peeked.horizontalLine != null) {
                    final level = (indentLvl - 1) % 30;
                    lineGuides.push(
                        cache != null
                            ? cache.indentGuide(indentGuide, level, isActive)
                            : new IndentGuide(indentGuide, -1, indentClassName(level, isActive), null, -1, -1)
                    );
                }
            }

            // takeWhile(g -> true)
            while (next < bracketCount) {
                lineGuides.push(bracketGuidesInLine[next]);
                next++;
            }
        }

        return result;
    }

}

/**
 * The indentation guides made by `IndentGuides.getGuidesByLine` (immutable,
 * the same for the same column, level and state), kept by a view so that
 * its frames do not make them again.
 */
class IndentGuideCache {

    final guides:Map<Int, IndentGuide> = new Map();

    public function new() {}

    public function indentGuide(visibleColumn:Int, level:Int, active:Bool):IndentGuide {
        final key = (visibleColumn * 32 + level) * 2 + (active ? 1 : 0);
        var guide = guides.get(key);
        if (guide == null) {
            guide = new IndentGuide(visibleColumn, -1, IndentGuides.indentClassName(level, active), null, -1, -1);
            guides.set(key, guide);
        }
        return guide;
    }

}

/**
 * How a guide of a class name is painted: Monaco's CSS rules of the
 * theming participant of indentGuides.ts and of indentGuides.css.
 */
class IndentGuideStyle {

    /**
     * An indentation guide (`core-guide-indent`), else a bracket pair guide.
     */
    public final isIndent:Bool;

    /**
     * `lvl-N`.
     */
    public final level:Int;

    /**
     * `indent-active`.
     */
    public final active:Bool;

    public function new(isIndent:Bool, level:Int, active:Bool) {
        this.isIndent = isIndent;
        this.level = level;
        this.active = active;
    }

}

/**
 * The colors of the guides (the theming participant of indentGuides.ts):
 * the bracket pair guides take `editorBracketPairGuide.background1..6` and
 * `activeBackground1..6`, or else the bracket colors
 * (`editorBracketHighlight.foreground1..6`, 30% opaque when inactive); the
 * indentation guides take `editorIndentGuide.background1..6` and
 * `activeBackground1..6`. Transparent colors are skipped and the levels
 * cycle through the others, like Monaco's CSS rules.
 */
class IndentGuideColors {

    final theme:ViewTheme;
    var version:Int = -1;

    var guideColors:Array<Hsla> = [];
    var guideColorsActive:Array<Hsla> = [];
    var indentColors:Array<Hsla> = [];
    var indentColorsActive:Array<Hsla> = [];

    final styles:Map<String, IndentGuideStyle> = new Map();

    public function new(theme:ViewTheme) {
        this.theme = theme;
    }

    static inline function transparentToUndefined(color:Null<Hsla>):Null<Hsla> {
        if (color != null && color.a <= 0) {
            return null;
        }
        return color;
    }

    function update():Void {
        if (version == theme.version) {
            return;
        }
        version = theme.version;
        guideColors = [];
        guideColorsActive = [];
        indentColors = [];
        indentColorsActive = [];

        final colors = [
            [EditorColorRegistry.editorBracketHighlightingForeground1, EditorColorRegistry.editorBracketPairGuideBackground1, EditorColorRegistry.editorBracketPairGuideActiveBackground1],
            [EditorColorRegistry.editorBracketHighlightingForeground2, EditorColorRegistry.editorBracketPairGuideBackground2, EditorColorRegistry.editorBracketPairGuideActiveBackground2],
            [EditorColorRegistry.editorBracketHighlightingForeground3, EditorColorRegistry.editorBracketPairGuideBackground3, EditorColorRegistry.editorBracketPairGuideActiveBackground3],
            [EditorColorRegistry.editorBracketHighlightingForeground4, EditorColorRegistry.editorBracketPairGuideBackground4, EditorColorRegistry.editorBracketPairGuideActiveBackground4],
            [EditorColorRegistry.editorBracketHighlightingForeground5, EditorColorRegistry.editorBracketPairGuideBackground5, EditorColorRegistry.editorBracketPairGuideActiveBackground5],
            [EditorColorRegistry.editorBracketHighlightingForeground6, EditorColorRegistry.editorBracketPairGuideBackground6, EditorColorRegistry.editorBracketPairGuideActiveBackground6]
        ];
        for (c in colors) {
            final bracketColor = theme.getColor(c[0]);
            final guideColor = theme.getColor(c[1]);
            final guideColorActive = theme.getColor(c[2]);

            var effectiveGuideColor = transparentToUndefined(guideColor);
            if (effectiveGuideColor == null && bracketColor != null) {
                effectiveGuideColor = bracketColor.opacity(0.3);
            }
            effectiveGuideColor = transparentToUndefined(effectiveGuideColor);
            var effectiveGuideColorActive = transparentToUndefined(guideColorActive);
            if (effectiveGuideColorActive == null) {
                effectiveGuideColorActive = bracketColor;
            }
            effectiveGuideColorActive = transparentToUndefined(effectiveGuideColorActive);

            if (effectiveGuideColor == null || effectiveGuideColorActive == null) {
                continue;
            }
            guideColors.push(effectiveGuideColor);
            guideColorsActive.push(effectiveGuideColorActive);
        }

        final indents = [
            [EditorColorRegistry.editorIndentGuide1, EditorColorRegistry.editorActiveIndentGuide1],
            [EditorColorRegistry.editorIndentGuide2, EditorColorRegistry.editorActiveIndentGuide2],
            [EditorColorRegistry.editorIndentGuide3, EditorColorRegistry.editorActiveIndentGuide3],
            [EditorColorRegistry.editorIndentGuide4, EditorColorRegistry.editorActiveIndentGuide4],
            [EditorColorRegistry.editorIndentGuide5, EditorColorRegistry.editorActiveIndentGuide5],
            [EditorColorRegistry.editorIndentGuide6, EditorColorRegistry.editorActiveIndentGuide6]
        ];
        for (c in indents) {
            final indentColor = transparentToUndefined(theme.getColor(c[0]));
            final indentColorActive = transparentToUndefined(theme.getColor(c[1]));
            if (indentColor == null || indentColorActive == null) {
                continue;
            }
            indentColors.push(indentColor);
            indentColorsActive.push(indentColorActive);
        }
    }

    /**
     * The style of a guide class name (cached).
     */
    public function styleOf(className:String):IndentGuideStyle {
        var style = styles.get(className);
        if (style == null) {
            final isIndent = className.indexOf('core-guide-indent') != -1;
            var level = 0;
            final lvl = className.indexOf('lvl-');
            if (lvl != -1) {
                var end = lvl + 4;
                while (end < className.length && className.charCodeAt(end) >= '0'.code && className.charCodeAt(end) <= '9'.code) {
                    end++;
                }
                final parsed = Std.parseInt(className.substring(lvl + 4, end));
                level = parsed != null ? parsed : 0;
            }
            style = new IndentGuideStyle(isIndent, level, className.indexOf('indent-active') != -1);
            styles.set(className, style);
        }
        return style;
    }

    /**
     * The color of a guide, or null when its CSS rule would not exist (no
     * usable color in the theme).
     */
    public function colorOf(style:IndentGuideStyle):Null<Hsla> {
        update();
        if (style.isIndent) {
            if (indentColors.length == 0) {
                return null;
            }
            final i = style.level % indentColors.length;
            return style.active ? indentColorsActive[i] : indentColors[i];
        }
        if (guideColors.length == 0) {
            return null;
        }
        final i = style.level % guideColors.length;
        return style.active ? guideColorsActive[i] : guideColors[i];
    }

}
