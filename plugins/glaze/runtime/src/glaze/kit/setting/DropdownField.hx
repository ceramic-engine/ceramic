// Ported from gpui-kit 0.8.1: crates/component/src/setting/fields/dropdown.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.setting;

import glaze.AnyElement;
import glaze.App;
import glaze.IntoElement;
import glaze.StyleRefinement;
import glaze.Window;
import glaze.kit.button.Button;
import glaze.kit.menu.PopupMenu;
import glaze.kit.menu.PopupMenu.PopupMenuItem;
import glaze.kit.setting.SettingField.AnySettingField;
import glaze.kit.setting.SettingField.DropdownOption;
import glaze.kit.setting.SettingField.SettingFieldRender;

using glaze.kit.base.Geometry.AxisExt;
using glaze.kit.base.StyledExt;
using glaze.kit.menu.DropdownMenu;

/**
 * Renders a dropdown field: an outline button showing the selected option,
 * opening a menu of the options.
 */
@:allow(glaze.kit.setting)
class DropdownField implements SettingFieldRender {

    final options:Array<DropdownOption>;

    final scrollable:Bool;

    /**
     * The setting's title. The button shows only the selected option, so its
     * accessible name puts the title in front of that option.
     */
    final title:String;

    function new(options:Null<Array<DropdownOption>>, scrollable:Bool, title:String) {
        this.options = options != null ? options.copy() : [];
        this.scrollable = scrollable;
        this.title = title;
    }

    public function render(field:AnySettingField, options:RenderOptions, style:StyleRefinement, window:Window, cx:App):AnyElement {
        final oldValue:String = SettingField.getValueOf(field, cx);
        final setValue:(String, App) -> Void = SettingField.setValueOf(field, cx);
        final dropdownOptions = this.options.copy();
        final scrollable = this.scrollable;

        var oldLabel = oldValue;
        for (option in dropdownOptions) {
            if (option.value == oldValue) {
                oldLabel = option.label;
                break;
            }
        }

        final button = Button.component('btn');
        if (options.layout().isVertical()) button.wFull();
        final popover = button
            .accessibilityLabel('$title: $oldLabel')
            .label(oldLabel)
            .dropdownCaret(true)
            .outline()
            .disabled(options.isDisabled())
            .withSize(options.size())
            .refineStyle(style)
            .dropdownMenuWithAnchor(TopRight, (menu, _, _) -> {
                for (option in dropdownOptions) {
                    final checked = oldValue == option.value;
                    final value = option.value;
                    menu.item(
                        PopupMenuItem.create(option.label)
                            .checked(checked)
                            .onClick((_, _, cx) -> {
                                setValue(value, cx);
                            })
                    );
                }
                return menu.scrollable(scrollable);
            });
        return (popover : IntoElement).intoAnyElement();
    }

}
