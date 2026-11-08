// Ported from gpui-kit 0.8.1: crates/component/src/setting/group.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.setting;

import glaze.AnyElement;
import glaze.App;
import glaze.IntoElement;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.groupbox.GroupBox;
import glaze.kit.label.Label;
import glaze.kit.theme.Theme;

import glaze.kit.base.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * A setting group that can contain multiple setting items.
 */
class SettingGroup implements Styled {

    var groupStyle:StyleRefinement = new StyleRefinement();

    var footerValue:Null<(Window, App) -> AnyElement> = null;

    var variantValue:Null<GroupBoxVariant> = null;

    @:allow(glaze.kit.setting, tests)
    var titleValue:Null<String> = null;

    @:allow(glaze.kit.setting, tests)
    var descriptionValue:Null<String> = null;

    @:allow(glaze.kit.setting, tests)
    var itemsValue:Array<SettingItem> = [];

    /**
     * Create a new setting group.
     */
    public function new() {}

    /**
     * Rust `Clone` (the style is copied, the items are shared like Rust's
     * clones of their `Rc` fields).
     */
    public function clone():SettingGroup {
        final copy = new SettingGroup();
        final style = new StyleRefinement();
        style.refine(groupStyle);
        copy.groupStyle = style;
        copy.footerValue = footerValue;
        copy.variantValue = variantValue;
        copy.titleValue = titleValue;
        copy.descriptionValue = descriptionValue;
        copy.itemsValue = [for (item in itemsValue) item.clone()];
        return copy;
    }

    public inline function style():StyleRefinement {
        return groupStyle;
    }

    /**
     * Set the label of the setting group, default is null.
     */
    public function title(title:String):SettingGroup {
        this.titleValue = title;
        return this;
    }

    /**
     * Set the description of the setting group, default is null.
     */
    public function description(description:String):SettingGroup {
        descriptionValue = description;
        return this;
    }

    /**
     * Set the variant of the group surface, overriding the variant set via
     * `Settings.withGroupVariant` for this group, default is null (use the
     * settings-level variant).
     */
    public function variant(variant:GroupBoxVariant):SettingGroup {
        variantValue = variant;
        return this;
    }

    /**
     * Render supporting content below, and outside, the group's surface.
     *
     * The footer aligns with the group title and renders as small muted
     * text, like a description. It scrolls with the group and follows its
     * search visibility; it does not add an independently searchable item or
     * a sidebar entry, and a group needs at least one item to be shown.
     */
    public function footer(footer:(Window, App) -> IntoElement):SettingGroup {
        footerValue = (window, cx) -> footer(window, cx).intoAnyElement();
        return this;
    }

    /**
     * Add a setting item to the group.
     */
    public function item(item:SettingItem):SettingGroup {
        itemsValue.push(item);
        return this;
    }

    /**
     * Add multiple setting items to the group.
     */
    public function items(items:Iterable<SettingItem>):SettingGroup {
        glaze.util.Iterables.append(this.itemsValue, items);
        return this;
    }

    /**
     * Return true if any of the setting items in the group match the given query.
     */
    @:allow(glaze.kit.setting, tests)
    function isMatch(query:String, cx:App):Bool {
        for (item in itemsValue) {
            if (item.isMatch(query, cx)) return true;
        }
        return false;
    }

    @:allow(glaze.kit.setting, tests)
    function isResettable(query:String, cx:App):Bool {
        for (item in itemsValue) {
            if (item.isMatch(query, cx) && item.isResettable(cx)) return true;
        }
        return false;
    }

    @:allow(glaze.kit.setting, tests)
    function render(query:String, options:RenderOptions, window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final group = GroupBox.component()
            .id('group-${options.groupIx()}')
            .withVariant(variantValue != null ? variantValue : options.groupVariant());
        if (titleValue != null) {
            final heading = vFlex().gap1().child(titleValue);
            if (descriptionValue != null) {
                heading.child(
                    Label.component(descriptionValue)
                        .textSm()
                        .textColor(theme.mutedForeground)
                );
            }
            group.title(heading);
        }
        group.gap4();
        for (itemIx in 0...itemsValue.length) {
            final item = itemsValue[itemIx];
            if (item.isMatch(query, cx)) {
                group.child(item.clone().renderItem(options.withItemIx(itemIx), window, cx));
            }
        }
        if (footerValue != null) group.footer(footerValue(window, cx));
        return group.refineStyle(groupStyle);
    }

    @:allow(glaze.kit.setting, tests)
    function reset(query:String, window:Window, cx:App):Void {
        for (item in itemsValue) {
            if (item.isMatch(query, cx)) {
                item.reset(window, cx);
            }
        }
    }

}
