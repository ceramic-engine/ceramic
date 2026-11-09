// Ported from vscode src/vs/editor/contrib/peekView/browser/peekView.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.peekView.view;

import cityscape.platform.contextkey.common.ContextKey;
import cityscape.platform.theme.common.ColorUtils;
import cityscape.platform.theme.common.ColorUtils.ColorIdentifier;
import cityscape.platform.theme.common.colors.BaseColors;
import cityscape.platform.theme.common.colors.EditorColors;

/**
 * The context keys of the peek views (Monaco's `PeekContext` namespace).
 */
class PeekContext {

    static var _inPeekEditor:Null<RawContextKey<Bool>> = null;

    /**
     * `inReferenceSearchEditor`: whether the code editor is embedded in a
     * peek view (true by default, like Monaco: the embedded editors of the
     * peek view keep it, the others set it to false).
     */
    public static var inPeekEditor(get, never):RawContextKey<Bool>;
    static function get_inPeekEditor():RawContextKey<Bool> {
        if (_inPeekEditor == null) {
            _inPeekEditor = new RawContextKey<Bool>('inReferenceSearchEditor', true, "Whether the current code editor is embedded inside peek");
        }
        return _inPeekEditor;
    }

    static var _notInPeekEditor:Null<ContextKeyExpression> = null;

    public static var notInPeekEditor(get, never):ContextKeyExpression;
    static function get_notInPeekEditor():ContextKeyExpression {
        if (_notInPeekEditor == null) {
            _notInPeekEditor = inPeekEditor.toNegated();
        }
        return _notInPeekEditor;
    }

}

/**
 * Whether an editor is the embedded editor of a peek view (Monaco checks
 * `instanceof EmbeddedCodeEditorWidget` and `PeekContext.inPeekEditor`):
 * the peek view sets `inReferenceSearchEditor` in the context keys of its
 * preview editor.
 */
class PeekViewEditors {

    public static function isEmbedded(editor:cityscape.view.EditorBrowser.ICodeEditor):Bool {
        final value:Null<Bool> = editor.contextKeyService.getContextKeyValue('inReferenceSearchEditor');
        return value == true;
    }

}

/**
 * The colors of the peek views.
 *
 * Monaco's `PeekViewWidget` is a zone widget (a view zone that pushes the
 * lines down, with a DOM overlay on it): Cityscape shows the references
 * peek in a popup below the line instead (see `ReferencesWidget` and
 * DEVIATIONS.md). Its head (`_fillHead`, `setTitle`, `setMetaTitle`) and
 * its height (`_doLayout`: the head is `ceil(lineHeight * 1.2)` high, the
 * body the rest less the 2 pixels of the borders) are kept.
 */
class PeekViewColors {

    public static inline final peekViewTitleBackground:ColorIdentifier = 'peekViewTitle.background';
    public static inline final peekViewTitleForeground:ColorIdentifier = 'peekViewTitleLabel.foreground';
    public static inline final peekViewTitleInfoForeground:ColorIdentifier = 'peekViewTitleDescription.foreground';
    public static inline final peekViewBorder:ColorIdentifier = 'peekView.border';
    public static inline final peekViewResultsBackground:ColorIdentifier = 'peekViewResult.background';
    public static inline final peekViewResultsMatchForeground:ColorIdentifier = 'peekViewResult.lineForeground';
    public static inline final peekViewResultsFileForeground:ColorIdentifier = 'peekViewResult.fileForeground';
    public static inline final peekViewResultsSelectionBackground:ColorIdentifier = 'peekViewResult.selectionBackground';
    public static inline final peekViewResultsSelectionForeground:ColorIdentifier = 'peekViewResult.selectionForeground';
    public static inline final peekViewEditorBackground:ColorIdentifier = 'peekViewEditor.background';
    public static inline final peekViewEditorGutterBackground:ColorIdentifier = 'peekViewEditorGutter.background';
    public static inline final peekViewEditorStickyScrollBackground:ColorIdentifier = 'peekViewEditorStickyScroll.background';
    public static inline final peekViewResultsMatchHighlight:ColorIdentifier = 'peekViewResult.matchHighlightBackground';
    public static inline final peekViewEditorMatchHighlight:ColorIdentifier = 'peekViewEditor.matchHighlightBackground';
    public static inline final peekViewEditorMatchHighlightBorder:ColorIdentifier = 'peekViewEditor.matchHighlightBorder';

    /**
     * Registered with the other colors (`ColorRegistry.registerAllColors`).
     */
    public static function registerColors():Void {
        ColorUtils.registerColor(peekViewTitleBackground, {dark: '#252526', light: '#F3F3F3', hcDark: '#000000', hcLight: '#FFFFFF'}, 'Background color of the peek view title area.');
        ColorUtils.registerColor(peekViewTitleForeground, {dark: '#FFFFFF', light: '#000000', hcDark: '#FFFFFF', hcLight: EditorColors.editorForeground}, 'Color of the peek view title.');
        ColorUtils.registerColor(peekViewTitleInfoForeground, {dark: '#ccccccb3', light: '#616161', hcDark: '#FFFFFF99', hcLight: '#292929'}, 'Color of the peek view title info.');
        ColorUtils.registerColor(peekViewBorder, {dark: EditorColors.editorInfoForeground, light: EditorColors.editorInfoForeground, hcDark: BaseColors.contrastBorder, hcLight: BaseColors.contrastBorder}, 'Color of the peek view borders and arrow.');
        ColorUtils.registerColor(peekViewResultsBackground, {dark: '#252526', light: '#F3F3F3', hcDark: '#000000', hcLight: '#FFFFFF'}, 'Background color of the peek view result list.');
        ColorUtils.registerColor(peekViewResultsMatchForeground, {dark: '#bbbbbb', light: '#646465', hcDark: '#FFFFFF', hcLight: EditorColors.editorForeground}, 'Foreground color for line nodes in the peek view result list.');
        ColorUtils.registerColor(peekViewResultsFileForeground, {dark: '#FFFFFF', light: '#1E1E1E', hcDark: '#FFFFFF', hcLight: EditorColors.editorForeground}, 'Foreground color for file nodes in the peek view result list.');
        ColorUtils.registerColor(peekViewResultsSelectionBackground, {dark: '#3399ff33', light: '#3399ff33', hcDark: null, hcLight: null}, 'Background color of the selected entry in the peek view result list.');
        ColorUtils.registerColor(peekViewResultsSelectionForeground, {dark: '#FFFFFF', light: '#6C6C6C', hcDark: '#FFFFFF', hcLight: EditorColors.editorForeground}, 'Foreground color of the selected entry in the peek view result list.');
        ColorUtils.registerColor(peekViewEditorBackground, {dark: '#001F33', light: '#F2F8FC', hcDark: '#000000', hcLight: '#FFFFFF'}, 'Background color of the peek view editor.');
        ColorUtils.registerColor(peekViewEditorGutterBackground, peekViewEditorBackground, 'Background color of the gutter in the peek view editor.');
        ColorUtils.registerColor(peekViewEditorStickyScrollBackground, peekViewEditorBackground, 'Background color of sticky scroll in the peek view editor.');
        ColorUtils.registerColor(peekViewResultsMatchHighlight, {dark: '#ea5c004d', light: '#ea5c004d', hcDark: null, hcLight: null}, 'Match highlight color in the peek view result list.');
        ColorUtils.registerColor(peekViewEditorMatchHighlight, {dark: '#ff8f0099', light: '#f5d802de', hcDark: null, hcLight: null}, 'Match highlight color in the peek view editor.');
        ColorUtils.registerColor(peekViewEditorMatchHighlightBorder, {dark: null, light: null, hcDark: BaseColors.activeContrastBorder, hcLight: BaseColors.activeContrastBorder}, 'Match highlight border in the peek view editor.');
    }

}
