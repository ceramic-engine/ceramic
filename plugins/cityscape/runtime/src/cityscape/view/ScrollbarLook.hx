// New code for Cityscape (not a port): the look of the kit scrollbars of an
// editor (its vertical scrollbar and the scrollbars of its widgets).
package cityscape.view;

import cityscape.common.config.EditorOptions.EditorOption;
import cityscape.common.config.EditorOptions.InternalEditorScrollbarOptions;
import cityscape.platform.theme.common.ThemeService.IColorTheme;
import cityscape.view.EditorBrowser.ICodeEditor;
import glaze.Hsla;
import glaze.kit.base.Scrollbar.ScrollbarStyles;
import glaze.kit.base.Scrollbar.ScrollbarThumbStyle;
import glaze.kit.base.Scrollbar.ScrollbarTrackStyle;

import glaze.Prelude.*;

/**
 * The styles (`Scrollbar.styles`) of the kit scrollbars of an editor, one
 * shape across Glaze (owner decision 2026-11-11, DEVIATIONS.md): the kit's
 * scrollbar (a rounded 6 pixel thumb 4 pixels from the edge) in the colors
 * of the editor's theme, `scrollbarSlider.background` at rest,
 * `scrollbarSlider.hoverBackground` under the mouse and
 * `scrollbarSlider.activeBackground` while dragged, without the kit's track
 * fill and drag border (the editor paints its own track, `scrollbar.trackColor`).
 * In the kit theme (`cityscape.kit.KitTheme`) the colors stay the kit's.
 * `scrollbar.thumbColor` and `scrollbar.thumbRadius` give the thumb's color
 * (every state) and corner radius.
 *
 * The editor's look (`forEditor`) also fits the thumb to the band the layout
 * gives the scrollbar (`verticalScrollbarSize`, `verticalSliderSize`); the
 * widgets' look (`forWidget`) is the kit's whole scrollbar, or with
 * `scrollbar.widgetStyle: 'monaco'` Monaco's widget scrollbars: a 10 pixel
 * square slider filling its track, at least 20 pixels long (scrollbars.css,
 * measured on the real Monaco 0.52.2).
 *
 * A look is kept by the editor's view and resolved again only when the
 * theme, the `scrollbar` option or the band changed, so that a render
 * allocates nothing for it.
 */
class ScrollbarLook {

    /** The width of Monaco's widget scrollbars and of their slider (`widgetStyle: 'monaco'`). */
    public static inline final MONACO_WIDGET_SIZE:Float = 10.;

    /** The minimum length of their slider (scrollbarState.ts `MINIMUM_SLIDER_SIZE`). */
    public static inline final MONACO_SLIDER_MIN_SIZE:Float = 20.;

    /** The kit scrollbar's thumb sizes (`glaze.kit.base.Scrollbar`). */
    public static inline final KIT_THUMB_WIDTH:Float = 6.;

    public static inline final KIT_THUMB_ACTIVE_WIDTH:Float = 8.;

    public static inline final KIT_THUMB_INSET:Float = 4.;

    /** The styles to give the scrollbar (`Scrollbar.styles`), the same function for the look's life. */
    public final apply:(ScrollbarStyles) -> ScrollbarStyles;

    final widget:Bool;

    var resolvedTheme:Null<IColorTheme> = null;
    var resolvedOptions:Null<InternalEditorScrollbarOptions> = null;
    var resolvedBand:Float = -1;
    var resolved:Bool = false;

    /** The thumb colors by state (rest, hovered, dragged), null to keep the kit's. */
    final thumbColors:Array<Null<Hsla>> = [null, null, null];
    /** The thumb widths and insets by state, NaN to keep the kit's. */
    final thumbWidths:Array<Float> = [Math.NaN, Math.NaN, Math.NaN];
    final thumbInsets:Array<Float> = [Math.NaN, Math.NaN, Math.NaN];
    /** The track widths by state, NaN to keep the kit's. */
    final trackWidths:Array<Float> = [Math.NaN, Math.NaN, Math.NaN];
    var thumbRadius:Float = Math.NaN;
    var thumbMinLength:Float = Math.NaN;
    /** Whether the track has no fill and no border (the editor's colors). */
    var clearTrack:Bool = false;

    final trackRest:(ScrollbarTrackStyle) -> ScrollbarTrackStyle;
    final trackHover:(ScrollbarTrackStyle) -> ScrollbarTrackStyle;
    final trackActive:(ScrollbarTrackStyle) -> ScrollbarTrackStyle;
    final thumbRest:(ScrollbarThumbStyle) -> ScrollbarThumbStyle;
    final thumbHover:(ScrollbarThumbStyle) -> ScrollbarThumbStyle;
    final thumbActive:(ScrollbarThumbStyle) -> ScrollbarThumbStyle;

    static final TRANSPARENT:Hsla = hsla(0, 0, 0, 0);

    function new(widget:Bool) {
        this.widget = widget;
        trackRest = t -> trackStyle(t, 0);
        trackHover = t -> trackStyle(t, 1);
        trackActive = t -> trackStyle(t, 2);
        thumbRest = t -> thumbStyle(t, 0);
        thumbHover = t -> thumbStyle(t, 1);
        thumbActive = t -> thumbStyle(t, 2);
        apply = s -> s
            .track(trackRest)
            .trackHover(trackHover)
            .trackActive(trackActive)
            .thumb(thumbRest)
            .thumbHover(thumbHover)
            .thumbActive(thumbActive);
    }

    /** A look for the editor's vertical scrollbar. */
    public static function editorLook():ScrollbarLook {
        return new ScrollbarLook(false);
    }

    /** A look for the scrollbars of the editor's widgets. */
    public static function widgetLook():ScrollbarLook {
        return new ScrollbarLook(true);
    }

    /**
     * The styles of the editor's vertical scrollbar in a band of `band`
     * pixels (`layoutInfo.verticalScrollbarWidth`): the kit look in the
     * kit's own 16 pixel band, else thumbs no wider than
     * `verticalSliderSize`, centered when the band is too narrow for the
     * kit's inset.
     */
    public function forEditor(editor:ICodeEditor, band:Float):(ScrollbarStyles) -> ScrollbarStyles {
        update(editor, band);
        return apply;
    }

    /** The styles of a scrollbar of the editor's widgets. */
    public function forWidget(editor:ICodeEditor):(ScrollbarStyles) -> ScrollbarStyles {
        update(editor, -1);
        return apply;
    }

    function update(editor:ICodeEditor, band:Float):Void {
        final theme = editor.context.themeService.getColorTheme();
        final options = editor.getOption(EditorOption.scrollbar);
        if (resolved && theme == resolvedTheme && options == resolvedOptions && band == resolvedBand) {
            return;
        }
        resolved = true;
        resolvedTheme = theme;
        resolvedOptions = options;
        resolvedBand = band;
        resolve(editor, options, band);
    }

    /** Whether the editor's theme is the kit theme (`KitTheme`), whose scrollbars keep the kit's colors. */
    static function isKitTheme(editor:ICodeEditor):Bool {
        return editor.context.themeService.getColorTheme().themeName == cityscape.kit.KitTheme.THEME_NAME;
    }

    function resolve(editor:ICodeEditor, options:InternalEditorScrollbarOptions, band:Float):Void {
        final monaco = widget && options.widgetStyle == 'monaco';
        for (i in 0...3) {
            thumbColors[i] = null;
            thumbWidths[i] = Math.NaN;
            thumbInsets[i] = Math.NaN;
            trackWidths[i] = Math.NaN;
        }
        thumbRadius = Math.NaN;
        thumbMinLength = Math.NaN;
        clearTrack = false;

        // Colors: the editor's (the kit's in the kit theme, except for
        // Monaco's widget look), `thumbColor` over them
        if (monaco || !isKitTheme(editor)) {
            final dark = EditorWidgets.isDark(editor);
            thumbColors[0] = EditorWidgets.color(editor, 'scrollbarSlider.background', dark ? hsla(0, 0, 121 / 255, 0.4) : hsla(0, 0, 100 / 255, 0.4));
            thumbColors[1] = EditorWidgets.color(editor, 'scrollbarSlider.hoverBackground', hsla(0, 0, 100 / 255, 0.7));
            thumbColors[2] = EditorWidgets.color(editor, 'scrollbarSlider.activeBackground', dark ? hsla(0, 0, 191 / 255, 0.4) : hsla(0, 0, 0, 0.6));
            clearTrack = true;
        }
        if (options.thumbColor != null) {
            final view = EditorWidgets.viewOf(editor);
            final color = view != null ? view.paintState.parsedColor(options.thumbColor) : ViewTheme.parseColor(options.thumbColor);
            if (color != null) {
                for (i in 0...3) {
                    thumbColors[i] = color;
                }
            }
        }

        if (monaco) {
            // Monaco's widget scrollbars: a square slider filling its track
            for (i in 0...3) {
                trackWidths[i] = MONACO_WIDGET_SIZE;
                thumbWidths[i] = MONACO_WIDGET_SIZE;
                thumbInsets[i] = 0;
            }
            thumbRadius = 0;
            thumbMinLength = MONACO_SLIDER_MIN_SIZE;
            return;
        }

        if (options.thumbRadius != null) {
            thumbRadius = options.thumbRadius;
        }

        if (widget || band < 0 || band == glaze.kit.base.Scrollbar.width()) {
            return;
        }
        // The editor's band (`verticalScrollbarSize`), thumbs no wider than
        // `verticalSliderSize`
        final slider:Float = options.verticalSliderSize;
        final normal = Math.max(0, Math.min(KIT_THUMB_WIDTH, slider));
        final active = Math.max(0, Math.min(KIT_THUMB_ACTIVE_WIDTH, slider));
        trackWidths[0] = band;
        thumbWidths[0] = normal;
        thumbInsets[0] = Math.max(0, Math.min(KIT_THUMB_INSET, Math.floor((band - normal) / 2)));
        for (i in 1...3) {
            thumbWidths[i] = active;
            thumbInsets[i] = Math.max(0, Math.min(KIT_THUMB_INSET, Math.floor((band - active) / 2)));
        }
    }

    function trackStyle(t:ScrollbarTrackStyle, state:Int):ScrollbarTrackStyle {
        if (clearTrack) {
            t.bg(TRANSPARENT).borderColor(TRANSPARENT);
        }
        final width = trackWidths[state];
        if (!Math.isNaN(width)) {
            t.width(width);
        }
        return t;
    }

    function thumbStyle(t:ScrollbarThumbStyle, state:Int):ScrollbarThumbStyle {
        final color = thumbColors[state];
        if (color != null) {
            t.bg(color);
        }
        final width = thumbWidths[state];
        if (!Math.isNaN(width)) {
            t.width(width);
        }
        final inset = thumbInsets[state];
        if (!Math.isNaN(inset)) {
            t.inset(inset);
        }
        if (!Math.isNaN(thumbRadius)) {
            t.radius(thumbRadius);
        }
        if (!Math.isNaN(thumbMinLength)) {
            t.minLength(thumbMinLength);
        }
        return t;
    }

}
