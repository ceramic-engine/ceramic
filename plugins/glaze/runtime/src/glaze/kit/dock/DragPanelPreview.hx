// Ported from gpui-kit 0.8.1: crates/component/src/dock/tab_panel.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.dock;

import glaze.AnyElement;
import glaze.App;
import glaze.Context;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.Window;
import glaze.kit.base.dock.PanelId;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;

/**
 * The preview that follows the cursor while a panel is dragged.
 *
 * `glaze.kit.base.dock.DragPanel` is the payload and draws nothing; this is the
 * appearance half.
 */
class DragPanelPreview extends Model implements Render {

    final panel:glaze.kit.base.dock.PanelView;

    @:allow(glaze.kit.dock)
    function new(panel:glaze.kit.base.dock.PanelView) {
        super();
        this.panel = panel;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        return div()
            .id('drag-panel')
            .cursorGrab()
            .py1()
            .px3()
            .w24()
            .overflowHidden()
            .whitespaceNowrap()
            .border1()
            .borderColor(theme.border)
            .rounded(theme.radius)
            .textColor(theme.tabForeground)
            .bg(theme.tokens.tabActive.background)
            .opacity(0.75)
            .child(panelTitle(panel, window, cx.app));
    }

    /**
     * Panels already warned about. `panelTitle` sits on the render path, so
     * an unguarded warning would repeat at frame rate and bury the very
     * signal it exists to give. Keyed by panel so a second wrongly installed
     * panel is still named.
     */
    static final warnedUnwrapped:Map<Int, Bool> = new Map();

    /**
     * A panel's title, or its registered name when it reached base without
     * this crate's handle and so carries no presentation. See
     * `PanelHandle.of`.
     */
    @:allow(glaze.kit.dock)
    static function panelTitle(panel:glaze.kit.base.dock.PanelView, window:Window, cx:App):AnyElement {
        final handle = PanelHandle.of(panel);
        if (handle == null) {
            final name = panel.panelName(cx);
            warnUnwrappedOnce(panel.panelId(cx), name);
            return (name : IntoElement).intoAnyElement();
        }
        return handle.title(window, cx);
    }

    /**
     * Say once, per panel, that a panel reached the skin without its
     * presentation handle. Silent otherwise, and visual-only: the panel
     * docks, drags and persists, it just has no title.
     */
    static function warnUnwrappedOnce(panel:PanelId, name:String):Void {
        final key:Int = panel.asU64();
        if (warnedUnwrapped.exists(key)) return;
        warnedUnwrapped.set(key, true);
        ceramic.Shortcuts.log.warning('dock panel `$name` reached the skin without its presentation handle, so it '
            + 'draws its panel name instead of its title; install it with '
            + '`PanelHandle.panelHandle(..)` and `DockLayout.panelView` / `DockArea.addPanelView` rather than '
            + '`DockLayout.panel` / `DockArea.addPanel`');
    }

}
