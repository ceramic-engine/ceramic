// Ported from gpui-kit 0.8.1: crates/component/src/setting/fields/element.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.setting;

import glaze.AnyElement;
import glaze.App;
import glaze.StyleRefinement;
import glaze.Window;
import glaze.kit.setting.SettingField.AnySettingField;
import glaze.kit.setting.SettingField.SettingFieldRender;

/**
 * A trait for rendering custom setting field elements.
 *
 * For the `SettingField.element` method.
 */
interface SettingFieldElement {

    function renderField(options:RenderOptions, window:Window, cx:App):AnyElement;

}

/**
 * Rust implements `SettingFieldElement` for closures.
 */
class FnSettingFieldElement implements SettingFieldElement {

    final f:(RenderOptions, Window, App) -> AnyElement;

    public function new(f:(RenderOptions, Window, App) -> AnyElement) {
        this.f = f;
    }

    public function renderField(options:RenderOptions, window:Window, cx:App):AnyElement {
        return f(options, window, cx);
    }

}

/**
 * Renders a custom element field.
 */
@:allow(glaze.kit.setting)
class ElementField implements SettingFieldRender {

    final elementRender:SettingFieldElement;

    function new(elementRender:SettingFieldElement) {
        this.elementRender = elementRender;
    }

    public function render(field:AnySettingField, options:RenderOptions, style:StyleRefinement, window:Window, cx:App):AnyElement {
        return elementRender.renderField(options, window, cx);
    }

}
