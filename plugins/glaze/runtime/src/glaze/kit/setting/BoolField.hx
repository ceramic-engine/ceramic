// Ported from gpui-kit 0.8.1: crates/component/src/setting/fields/bool.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.setting;

import gpui.AnyElement;
import gpui.App;
import gpui.IntoElement;
import gpui.StyleRefinement;
import gpui.Window;
import gpui.component.checkbox.Checkbox;
import gpui.component.setting.SettingField.AnySettingField;
import gpui.component.setting.SettingField.SettingFieldRender;
import gpui.component.switch_.Switch;

import gpui.Prelude.*;

using gpui.base.StyledExt;

/**
 * Renders a boolean field as a switch or a checkbox.
 */
@:allow(gpui.component.setting)
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
            new Switch('check')
                .accessibilityLabel(title)
                .checked(checked)
                .disabled(options.isDisabled())
                .withSize(options.size())
                .onClick((checked:Bool, _, cx:App) -> {
                    setValue(checked, cx);
                });
        } else {
            new Checkbox('check')
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
