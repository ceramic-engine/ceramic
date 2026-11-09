// Ported from vscode src/vs/editor/contrib/folding/browser/foldingDecorations.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.folding.view;

import cityscape.common.DecorationStyle.DecorationStyles;
import cityscape.common.Model.IModelDecorationOptions;
import cityscape.common.Model.IModelDecorationsChangeAccessor;
import cityscape.common.Model.MinimapPosition;
import cityscape.common.Model.TrackedRangeStickiness;
import cityscape.common.model.TextModel.ModelDecorationOptions;
import cityscape.contrib.folding.view.Folding.IFoldingEditor;
import cityscape.contrib.folding.view.FoldingModel.IDecorationProvider;
import cityscape.platform.theme.common.ColorUtils;
import cityscape.platform.theme.common.ColorUtils.ColorIdentifier;
import cityscape.platform.theme.common.colors.BaseColors;
import cityscape.platform.theme.common.colors.EditorColors;

/**
 * The colors and icons of foldingDecorations.ts.
 *
 * Monaco's icons are codicons (`ThemeIcon.asClassName` gives
 * `codicon codicon-<id>`): the class names are kept on the decorations, and
 * the Cityscape view draws the chevrons of these class names in the gutter
 * (`CityscapeViewElement.paintFoldingControls`).
 */
class FoldingColors {

    public static inline final foldBackground:ColorIdentifier = 'editor.foldBackground';
    public static inline final foldPlaceholderForeground:ColorIdentifier = 'editor.foldPlaceholderForeground';
    public static inline final foldingControlForeground:ColorIdentifier = 'editorGutter.foldingControlForeground';

    /**
     * `ThemeIcon.asClassName` of the icons `folding-expanded` (codicon
     * `chevron-down`), `folding-collapsed` (`chevron-right`),
     * `folding-manual-collapsed` and `folding-manual-expanded`.
     */
    public static inline final foldingExpandedIconClassName = 'codicon codicon-folding-expanded';
    public static inline final foldingCollapsedIconClassName = 'codicon codicon-folding-collapsed';
    public static inline final foldingManualCollapsedIconClassName = 'codicon codicon-folding-manual-collapsed';
    public static inline final foldingManualExpandedIconClassName = 'codicon codicon-folding-manual-expanded';

    /**
     * Registered with the other colors (`ColorRegistry.registerAllColors`).
     */
    public static function registerColors():Void {
        ColorUtils.registerColor(foldBackground,
            { light: ColorUtils.transparent(EditorColors.editorSelectionBackground, 0.3), dark: ColorUtils.transparent(EditorColors.editorSelectionBackground, 0.3), hcDark: null, hcLight: null },
            'Background color behind folded ranges. The color must not be opaque so as not to hide underlying decorations.', true);
        ColorUtils.registerColor(foldPlaceholderForeground,
            { light: '#808080', dark: '#808080', hcDark: null, hcLight: null },
            'Color of the collapsed text after the first line of a folded range.');
        ColorUtils.registerColor(foldingControlForeground,
            BaseColors.iconForeground,
            'Color of the folding control in the editor gutter.');
    }

    /**
     * The styles of the class names of folding.css that are not icons:
     * `folded-background` (`background-color: var(--vscode-editor-foldBackground)`).
     * `inline-folded` (the `⋯` after a folded line) is drawn by the view.
     * Registered once per context, unless the host registered its own.
     */
    public static function registerDecorationStyles(styles:DecorationStyles):Void {
        if (styles.get('folded-background') == null) {
            styles.registerDecorationStyle('folded-background', {background: {id: foldBackground}});
        }
    }

}

class FoldingDecorationProvider implements IDecorationProvider {

    static inline final collapsed = 'Click to expand the range.';
    static inline final expanded = 'Click to collapse the range.';

    static var _options:Null<Array<ModelDecorationOptions>> = null;

    static function options():Array<ModelDecorationOptions> {
        if (_options == null) {
            final foldedBackgroundMinimap = {color: {id: FoldingColors.foldBackground}, position: MinimapPosition.Inline};
            _options = [
                // COLLAPSED_VISUAL_DECORATION
                ModelDecorationOptions.register({
                    description: 'folding-collapsed-visual-decoration',
                    stickiness: TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges,
                    afterContentClassName: 'inline-folded',
                    isWholeLine: true,
                    linesDecorationsTooltip: collapsed,
                    firstLineDecorationClassName: FoldingColors.foldingCollapsedIconClassName,
                }),
                // COLLAPSED_HIGHLIGHTED_VISUAL_DECORATION
                ModelDecorationOptions.register({
                    description: 'folding-collapsed-highlighted-visual-decoration',
                    stickiness: TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges,
                    afterContentClassName: 'inline-folded',
                    className: 'folded-background',
                    minimap: foldedBackgroundMinimap,
                    isWholeLine: true,
                    linesDecorationsTooltip: collapsed,
                    firstLineDecorationClassName: FoldingColors.foldingCollapsedIconClassName
                }),
                // MANUALLY_COLLAPSED_VISUAL_DECORATION
                ModelDecorationOptions.register({
                    description: 'folding-manually-collapsed-visual-decoration',
                    stickiness: TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges,
                    afterContentClassName: 'inline-folded',
                    isWholeLine: true,
                    linesDecorationsTooltip: collapsed,
                    firstLineDecorationClassName: FoldingColors.foldingManualCollapsedIconClassName
                }),
                // MANUALLY_COLLAPSED_HIGHLIGHTED_VISUAL_DECORATION
                ModelDecorationOptions.register({
                    description: 'folding-manually-collapsed-highlighted-visual-decoration',
                    stickiness: TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges,
                    afterContentClassName: 'inline-folded',
                    className: 'folded-background',
                    minimap: foldedBackgroundMinimap,
                    isWholeLine: true,
                    linesDecorationsTooltip: collapsed,
                    firstLineDecorationClassName: FoldingColors.foldingManualCollapsedIconClassName
                }),
                // NO_CONTROLS_COLLAPSED_RANGE_DECORATION
                ModelDecorationOptions.register({
                    description: 'folding-no-controls-range-decoration',
                    stickiness: TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges,
                    afterContentClassName: 'inline-folded',
                    isWholeLine: true,
                    linesDecorationsTooltip: collapsed,
                }),
                // NO_CONTROLS_COLLAPSED_HIGHLIGHTED_RANGE_DECORATION
                ModelDecorationOptions.register({
                    description: 'folding-no-controls-range-decoration',
                    stickiness: TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges,
                    afterContentClassName: 'inline-folded',
                    className: 'folded-background',
                    minimap: foldedBackgroundMinimap,
                    isWholeLine: true,
                    linesDecorationsTooltip: collapsed,
                }),
                // EXPANDED_VISUAL_DECORATION
                ModelDecorationOptions.register({
                    description: 'folding-expanded-visual-decoration',
                    stickiness: TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges,
                    isWholeLine: true,
                    firstLineDecorationClassName: 'alwaysShowFoldIcons ' + FoldingColors.foldingExpandedIconClassName,
                    linesDecorationsTooltip: expanded,
                }),
                // EXPANDED_AUTO_HIDE_VISUAL_DECORATION
                ModelDecorationOptions.register({
                    description: 'folding-expanded-auto-hide-visual-decoration',
                    stickiness: TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges,
                    isWholeLine: true,
                    firstLineDecorationClassName: FoldingColors.foldingExpandedIconClassName,
                    linesDecorationsTooltip: expanded,
                }),
                // MANUALLY_EXPANDED_VISUAL_DECORATION
                ModelDecorationOptions.register({
                    description: 'folding-manually-expanded-visual-decoration',
                    stickiness: TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges,
                    isWholeLine: true,
                    firstLineDecorationClassName: 'alwaysShowFoldIcons ' + FoldingColors.foldingManualExpandedIconClassName,
                    linesDecorationsTooltip: expanded,
                }),
                // MANUALLY_EXPANDED_AUTO_HIDE_VISUAL_DECORATION
                ModelDecorationOptions.register({
                    description: 'folding-manually-expanded-auto-hide-visual-decoration',
                    stickiness: TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges,
                    isWholeLine: true,
                    firstLineDecorationClassName: FoldingColors.foldingManualExpandedIconClassName,
                    linesDecorationsTooltip: expanded,
                }),
                // NO_CONTROLS_EXPANDED_RANGE_DECORATION
                ModelDecorationOptions.register({
                    description: 'folding-no-controls-range-decoration',
                    stickiness: TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges,
                    isWholeLine: true
                }),
                // HIDDEN_RANGE_DECORATION
                ModelDecorationOptions.register({
                    description: 'folding-hidden-range-decoration',
                    stickiness: TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges
                }),
            ];
        }
        return _options;
    }

    public static var COLLAPSED_VISUAL_DECORATION(get, never):ModelDecorationOptions;
    static inline function get_COLLAPSED_VISUAL_DECORATION() return options()[0];
    public static var COLLAPSED_HIGHLIGHTED_VISUAL_DECORATION(get, never):ModelDecorationOptions;
    static inline function get_COLLAPSED_HIGHLIGHTED_VISUAL_DECORATION() return options()[1];
    public static var MANUALLY_COLLAPSED_VISUAL_DECORATION(get, never):ModelDecorationOptions;
    static inline function get_MANUALLY_COLLAPSED_VISUAL_DECORATION() return options()[2];
    public static var MANUALLY_COLLAPSED_HIGHLIGHTED_VISUAL_DECORATION(get, never):ModelDecorationOptions;
    static inline function get_MANUALLY_COLLAPSED_HIGHLIGHTED_VISUAL_DECORATION() return options()[3];
    public static var NO_CONTROLS_COLLAPSED_RANGE_DECORATION(get, never):ModelDecorationOptions;
    static inline function get_NO_CONTROLS_COLLAPSED_RANGE_DECORATION() return options()[4];
    public static var NO_CONTROLS_COLLAPSED_HIGHLIGHTED_RANGE_DECORATION(get, never):ModelDecorationOptions;
    static inline function get_NO_CONTROLS_COLLAPSED_HIGHLIGHTED_RANGE_DECORATION() return options()[5];
    public static var EXPANDED_VISUAL_DECORATION(get, never):ModelDecorationOptions;
    static inline function get_EXPANDED_VISUAL_DECORATION() return options()[6];
    public static var EXPANDED_AUTO_HIDE_VISUAL_DECORATION(get, never):ModelDecorationOptions;
    static inline function get_EXPANDED_AUTO_HIDE_VISUAL_DECORATION() return options()[7];
    public static var MANUALLY_EXPANDED_VISUAL_DECORATION(get, never):ModelDecorationOptions;
    static inline function get_MANUALLY_EXPANDED_VISUAL_DECORATION() return options()[8];
    public static var MANUALLY_EXPANDED_AUTO_HIDE_VISUAL_DECORATION(get, never):ModelDecorationOptions;
    static inline function get_MANUALLY_EXPANDED_AUTO_HIDE_VISUAL_DECORATION() return options()[9];
    public static var NO_CONTROLS_EXPANDED_RANGE_DECORATION(get, never):ModelDecorationOptions;
    static inline function get_NO_CONTROLS_EXPANDED_RANGE_DECORATION() return options()[10];
    public static var HIDDEN_RANGE_DECORATION(get, never):ModelDecorationOptions;
    static inline function get_HIDDEN_RANGE_DECORATION() return options()[11];

    /**
     * `'always'`, `'never'` or `'mouseover'`.
     */
    public var showFoldingControls:String = 'mouseover';

    public var showFoldingHighlights:Bool = true;

    final editor:IFoldingEditor;

    public function new(editor:IFoldingEditor) {
        this.editor = editor;
    }

    static inline function o(options:ModelDecorationOptions):IModelDecorationOptions {
        return cast options;
    }

    public function getDecorationOption(isCollapsed:Bool, isHidden:Bool, isManual:Bool):IModelDecorationOptions {
        if (isHidden) { // is inside another collapsed region
            return o(HIDDEN_RANGE_DECORATION);
        }
        if (showFoldingControls == 'never') {
            if (isCollapsed) {
                return o(showFoldingHighlights ? NO_CONTROLS_COLLAPSED_HIGHLIGHTED_RANGE_DECORATION : NO_CONTROLS_COLLAPSED_RANGE_DECORATION);
            }
            return o(NO_CONTROLS_EXPANDED_RANGE_DECORATION);
        }
        if (isCollapsed) {
            return o(isManual ?
                (showFoldingHighlights ? MANUALLY_COLLAPSED_HIGHLIGHTED_VISUAL_DECORATION : MANUALLY_COLLAPSED_VISUAL_DECORATION)
                : (showFoldingHighlights ? COLLAPSED_HIGHLIGHTED_VISUAL_DECORATION : COLLAPSED_VISUAL_DECORATION));
        }
        else if (showFoldingControls == 'mouseover') {
            return o(isManual ? MANUALLY_EXPANDED_AUTO_HIDE_VISUAL_DECORATION : EXPANDED_AUTO_HIDE_VISUAL_DECORATION);
        }
        else {
            return o(isManual ? MANUALLY_EXPANDED_VISUAL_DECORATION : EXPANDED_VISUAL_DECORATION);
        }
    }

    public function changeDecorations<T>(callback:(changeAccessor:IModelDecorationsChangeAccessor) -> T):Null<T> {
        return editor.changeDecorations(callback);
    }

    public function removeDecorations(decorationIds:Array<String>):Void {
        editor.removeDecorations(decorationIds);
    }
}
