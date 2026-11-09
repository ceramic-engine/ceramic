// New code for Cityscape (not a port): what the editor's popup widgets
// (suggest, hover, code action menu) share to place themselves with the
// Glaze kit and take the colors of the VS Code theme.
package cityscape.view;

import cityscape.base.common.Color;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.view.EditorBrowser.ICodeEditor;
import cityscape.view.widget.codeEditor.CodeEditorWidget;
import glaze.AnyElement;
import glaze.Bounds;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.Point;
import glaze.Size;
import glaze.kit.base.Geometry.Placement;
import glaze.kit.base.Popup;
import glaze.kit.base.Positioner;

import glaze.Prelude.*;

/**
 * Helpers of the editor's popup widgets. Monaco's content widgets are DOM
 * nodes positioned next to a text position; Cityscape's are Glaze elements
 * drawn above everything (`deferred`) by the kit's `Positioner`, anchored on
 * the window bounds of the text, so that they can leave the editor and
 * flip above or below the line when there is no room (the kit's popups).
 */
class EditorWidgets {

    /**
     * The Glaze view of an editor (null for an editor without view, like
     * the test editors).
     */
    public static function viewOf(editor:ICodeEditor):Null<CityscapeView> {
        final widget = Std.downcast(editor, CodeEditorWidget);
        if (widget == null) {
            return null;
        }
        return Std.downcast(widget.getView(), CityscapeView);
    }

    /**
     * The window bounds of the editor (from its last prepaint), null
     * without view.
     */
    public static function editorBounds(editor:ICodeEditor):Null<Bounds> {
        final view = viewOf(editor);
        return view != null ? view.elementBounds : null;
    }

    /**
     * The window bounds of the line box of `start` (to `end` when given, on
     * the same line): what a popup anchors on. Null when the editor has no
     * view or the position is not rendered.
     */
    public static function positionBounds(editor:ICodeEditor, start:Position, ?end:Position):Null<Bounds> {
        final bounds = editorBounds(editor);
        if (bounds == null || !editor.hasModel()) {
            return null;
        }
        final a = editor.getScrolledVisiblePosition(start);
        if (a == null) {
            return null;
        }
        var width = 1.0;
        if (end != null && end.lineNumber == start.lineNumber) {
            final b = editor.getScrolledVisiblePosition(end);
            if (b != null && b.left > a.left) {
                width = b.left - a.left;
            }
        }
        return new Bounds(new Point(bounds.origin.x + a.left, bounds.origin.y + a.top), new Size(width, a.height));
    }

    /**
     * Whether the line box of a position shows in the editor (a popup is
     * hidden when its anchor scrolled out).
     */
    public static function isPositionVisible(editor:ICodeEditor, position:Position):Bool {
        final bounds = editorBounds(editor);
        if (bounds == null || !editor.hasModel()) {
            return false;
        }
        final p = editor.getScrolledVisiblePosition(position);
        if (p == null) {
            return false;
        }
        return p.top + p.height > 0 && p.top < bounds.size.height;
    }

    /**
     * A popup anchored on `trigger`: on the side `placement` (`Top` or
     * `Bottom`, flipped by the kit when there is no room), its leading edge
     * on the trigger's, drawn above everything else and blocking the mouse.
     */
    public static function popup(trigger:Bounds, placement:Placement, child:IntoElement, ?onPosition:(resolved:glaze.kit.base.Positioner.ResolvedPosition) -> Void):AnyElement {
        final positioner = Positioner.side(trigger)
            .placement(placement)
            .align(Align.Start)
            .offset(0)
            .margin(4)
            .occlude()
            .child(child);
        if (onPosition != null) {
            positioner.onPosition(onPosition);
        }
        return deferred(positioner).withPriority(Popup.POPUP_PRIORITY).intoAnyElement();
    }

    /**
     * A color of the VS Code theme of the editor's context (null when the
     * theme has none).
     */
    public static function themeColor(editor:ICodeEditor, key:String):Null<Hsla> {
        final color:Null<Color> = editor.context.themeService.getColorTheme().getColor(key);
        if (color == null) {
            return null;
        }
        final rgba = color.rgba;
        return new glaze.Rgba(rgba.r / 255, rgba.g / 255, rgba.b / 255, rgba.a).toHsla();
    }

    /**
     * A color of the theme, or `fallback`.
     */
    public static function color(editor:ICodeEditor, key:String, fallback:Hsla):Hsla {
        final c = themeColor(editor, key);
        return c != null ? c : fallback;
    }

    /**
     * Whether the editor's theme is a dark one.
     */
    public static function isDark(editor:ICodeEditor):Bool {
        return cityscape.platform.theme.common.Theme.isDark(editor.context.themeService.getColorTheme().type);
    }

    /**
     * The Glaze font family of the editor's text (`fontFamily` option, the
     * first family the text system has).
     */
    public static function editorFontFamily(editor:ICodeEditor):String {
        final view = viewOf(editor);
        final fontInfo = editor.getOption(EditorOption.fontInfo);
        if (view == null) {
            return 'JetBrains Mono';
        }
        return view.measurements.resolveEditorFont(fontInfo.fontFamily, glaze.FontWeight.NORMAL, false, glaze.FontFeatures.defaultValue()).family;
    }

}
