// Ported from gpui-kit 0.8.1: crates/component/src/setting/fields/bool.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.setting;

import glaze.AnyElement;
import glaze.App;
import glaze.IntoElement;
import glaze.StyleRefinement;
import glaze.Window;
import glaze.kit.checkbox.Checkbox;
import glaze.kit.setting.SettingField.AnySettingField;
import glaze.kit.setting.SettingField.SettingFieldRender;
import glaze.kit.switch_.Switch;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * Renders a boolean field as a switch or a checkbox.
 */
@:allow(glaze.kit.setting)
class BoolField implements SettingFieldRender {

    final useSwitch:Bool;

    /**
     * The setting's title. The control has no visible text of its own, so
     * this is its accessible name.
     */
    final title:String;

    function new(useSwitch:Bool, title:String) {
        this.useSwitch = useSwitch;
        this.title = title;
    }

    public function render(field:AnySettingField, options:RenderOptions, style:StyleRefinement, window:Window, cx:App):AnyElement {
        final checked:Bool = SettingField.getValueOf(field, cx);
        final setValue:(Bool, App) -> Void = SettingField.setValueOf(field, cx);

        final control:IntoElement = if (useSwitch) {
            Switch.component('check')
                .accessibilityLabel(title)
                .checked(checked)
                .disabled(options.isDisabled())
                .withSize(options.size())
                .onClick((checked:Bool, _, cx:App) -> {
                    setValue(checked, cx);
                });
        } else {
            Checkbox.component('check')
                .accessibilityLabel(title)
                .checked(checked)
                .disabled(options.isDisabled())
                .withSize(options.size())
                .onClick((checked:Bool, _, cx:App) -> {
                    setValue(checked, cx);
                });
        };
        return div()
            .refineStyle(style)
            .child(control)
            .intoAnyElement();
    }

}
