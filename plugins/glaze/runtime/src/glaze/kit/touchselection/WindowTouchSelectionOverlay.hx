// Ported from gpui-kit 0.8.1: crates/component/src/touch_selection/window_overlay.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.touchselection;

import glaze.App;
import glaze.ClipboardItem;
import glaze.Context;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.Subscription;
import glaze.Window;
import glaze.kit.base.TextSelection;
import glaze.kit.I18n;
import glaze.kit.touchselection.EditMenu.EditMenuItem;

import glaze.Prelude.*;

/**
 * Draws the handles and the edit menu of the window text selection, the one
 * a `TextView` takes part in. `Root` mounts one per window, after the
 * content, so the surfaces float above whatever was selected.
 *
 * Read-only text offers Copy and Select All.
 */
class WindowTouchSelectionOverlay extends Model implements Render {

    final subscription:Subscription;

    public function new(window:Window, cx:Context<WindowTouchSelectionOverlay>) {
        super();
        final self = cx.weakEntity();
        subscription = TextSelection.observeTouchSelection(window, cx.app, cx -> {
            final entity = self.upgrade();
            if (entity != null) entity.update(cx, (_, cx) -> cx.notify());
        });
    }

    static function copy(window:Window, cx:App):Void {
        final text = glaze.kit.base.text.TextUtils.trim(TextSelection.selectedText(window, cx));
        if (text.length > 0) {
            cx.writeToClipboard(ClipboardItem.newString(text));
        }
        TextSelection.closeEditMenu(window, cx);
    }

    static function selectAll(window:Window, cx:App):Void {
        TextSelection.selectAll(window, cx);
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        if (TextSelection.touchSelection(window, cx.app) == null) {
            return div();
        }
        // The handles are painted by the text that owns them, where they are
        // covered by whatever covers the text; only the menu floats.
        final overlay = new TouchSelectionOverlay(Name('window-touch-selection'), (window, cx) -> TextSelection.touchSelection(window, cx))
            .items([
                new EditMenuItem(I18n.t("Input.Copy"), copy),
                new EditMenuItem(I18n.t("Input.Select All"), selectAll),
            ])
            .onPaint((bounds, window, cx) -> TextSelection.registerTouchUi(bounds, window, cx));
        return div().children(cast overlay.intoElements(window, cx.app));
    }

}
