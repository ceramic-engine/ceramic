// Ported from gpui-kit 0.8.1: crates/component/src/dock/panel.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.dock;

import glaze.AnyElement;
import glaze.App;
import glaze.Entity;
import glaze.Model;
import glaze.Window;
import glaze.kit.button.Button;
import glaze.kit.menu.PopupMenu;

/**
 * The presentation `PanelView` of a panel entity (Rust's blanket
 * `impl<T: Panel> PanelView for Entity<T>`).
 */
class EntityPanelView<T:Model & Panel> extends glaze.kit.base.dock.EntityPanelView<T> implements PanelView {

    public function new(entity:Entity<T>) {
        super(entity);
    }

    public function tabName(cx:App):Null<String> {
        return entity.read(cx).tabName(cx);
    }

    public function title(window:Window, cx:App):AnyElement {
        return entity.update(cx, (panel, cx) -> panel.title(window, cx).intoAnyElement());
    }

    public function titleStyle(cx:App):Null<TitleStyle> {
        return entity.read(cx).titleStyle(cx);
    }

    public function titleSuffix(window:Window, cx:App):Null<AnyElement> {
        return entity.update(cx, (panel, cx) -> {
            final element = panel.titleSuffix(window, cx);
            element != null ? element.intoAnyElement() : null;
        });
    }

    public function toolbarButtons(window:Window, cx:App):Null<Array<Button>> {
        return entity.update(cx, (panel, cx) -> panel.toolbarButtons(window, cx));
    }

    public function dropdownMenu(menu:PopupMenu, window:Window, cx:App):PopupMenu {
        return entity.update(cx, (panel, cx) -> panel.dropdownMenu(menu, window, cx));
    }

    public function zoomControl(cx:App):Null<PanelControl> {
        return entity.read(cx).zoomControl(cx);
    }

    public function innerPadding(cx:App):Bool {
        return entity.read(cx).innerPadding(cx);
    }

    public function titleBar(cx:App):Bool {
        return entity.read(cx).titleBar(cx);
    }

}
