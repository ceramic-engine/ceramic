// Ported from gpui-kit 0.8.1: crates/component/src/dock/invalid_panel.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.dock;

import gpui.App;
import gpui.Context;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.Window;
import gpui.base.dock.PanelState;
import gpui.component.I18n;
import gpui.component.theme.Theme;

import gpui.Prelude.*;

/**
 * Stands in for a panel this build cannot construct: one whose `panelName`
 * no `PanelRegistry` builder answers to.
 *
 * It reports the original `PanelState` from `dump`, so a layout written by a
 * build that knows the panel survives a load and a save here rather than
 * losing it.
 */
@:allow(gpui.component.dock)
class InvalidPanel extends PanelBase {

    final focus:FocusHandle;

    final oldState:PanelState;

    /**
     * The type name goes to the log rather than the screen: it means nothing
     * to the person looking at the panel.
     */
    function new(state:PanelState, cx:Context<InvalidPanel>) {
        super();
        ceramic.Shortcuts.log.warning('the `${state.panelName}` panel type is not registered in PanelRegistry');
        this.focus = cx.focusHandle();
        this.oldState = state;
    }

    public function panelName():String {
        return 'InvalidPanel';
    }

    override public function dump(cx:App):PanelState {
        return oldState.clone();
    }

    public function focusHandle(cx:App):FocusHandle {
        return focus;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div()
            .sizeFull()
            .my6()
            .flex()
            .flexCol()
            .itemsCenter()
            .justifyCenter()
            .textColor(Theme.global(cx.app).mutedForeground)
            .child(I18n.t('Dock.Unavailable Panel'));
    }

}
