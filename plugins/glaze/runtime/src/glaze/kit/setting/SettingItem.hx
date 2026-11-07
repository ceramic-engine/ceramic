// Ported from gpui-kit 0.8.1: crates/component/src/setting/item.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.setting;

import gpui.AnyElement;
import gpui.App;
import gpui.Axis;
import gpui.Div;
import gpui.ElementId;
import gpui.IntoElement;
import gpui.Window;
import gpui.component.label.Label;
import gpui.component.setting.SettingField.AnySettingField;
import gpui.component.setting.SettingField.ResetHandler;
import gpui.component.setting.SettingField.SettingFieldRender;
import gpui.component.setting.SettingField.SettingFieldTypeTools;
import gpui.component.text.Text;
import gpui.component.theme.Theme;

import gpui.Prelude.*;
import gpui.base.Prelude.*;

using gpui.base.Geometry.AxisExt;
using gpui.base.StyledExt;

/**
 * The two kinds of setting items.
 */
enum SettingItemKind {
    /**
     * A normal setting item with a title, description, and field.
     */
    Item(title:String, description:Null<Text>, keywords:Array<String>, layout:Axis, disabled:Bool, field:AnySettingField);

    /**
     * A full custom element to render. The optional reset handler reports
     * whether the item is "dirty" (controls reset button visibility) and
     * performs the reset.
     */
    Element(disabled:Bool, keywords:Array<String>, resetHandler:Null<ResetHandler>, render:(RenderOptions, Window, App) -> AnyElement);
}

/**
 * Setting item (Rust enum `SettingItem`, here a class holding the variant
 * so the builders can replace it).
 */
class SettingItem {

    @:allow(gpui.component.setting, tests)
    var kind:SettingItemKind;

    function new(kind:SettingItemKind) {
        this.kind = kind;
    }

    /**
     * Rust `Clone`.
     */
    public function clone():SettingItem {
        return new SettingItem(kind);
    }

    /**
     * Create a new setting item.
     */
    public static function create(title:String, field:AnySettingField):SettingItem {
        return new SettingItem(Item(title, null, [], Horizontal, false, field));
    }

    /**
     * Create a new custom element setting item with a render closure.
     */
    public static function render(render:(RenderOptions, Window, App) -> IntoElement):SettingItem {
        return new SettingItem(Element(false, [], null, (options, window, cx) -> render(options, window, cx).intoAnyElement()));
    }

    /**
     * Provide custom reset behavior for a custom element item.
     *
     * Only applies to `SettingItemKind.Element` (created via `render`). When
     * set, the page-level reset button will appear while `isDirty` returns
     * true, and clicking it invokes `reset`.
     */
    public function onReset(isDirty:(App) -> Bool, reset:(Window, App) -> Void):SettingItem {
        switch kind {
            case Element(disabled, keywords, _, render):
                kind = Element(disabled, keywords, new ResetHandler(isDirty, reset), render);
            case Item(_, _, _, _, _, _):
                // `onReset` is meaningless for a value-bearing item: use the
                // field's own `defaultValue` / `SettingField.onReset` instead.
                // (Rust `debug_assert!`.)
                #if debug
                throw 'SettingItem::on_reset only applies to SettingItem::Element; use SettingField::default_value or SettingField::on_reset for a normal item';
                #end
        }
        return this;
    }

    /**
     * Set additional keywords used only for search matching (not rendered).
     *
     * For example, an item titled "Enable Two-factor auth" can be made
     * searchable via "MFA". This is also useful for custom elements that
     * have no title/description but should still show up in search results.
     */
    public function keywords(keywords:Iterable<String>):SettingItem {
        final keywords = gpui.util.Iterables.toArray(keywords);
        switch kind {
            case Item(title, description, _, layout, disabled, field):
                kind = Item(title, description, keywords, layout, disabled, field);
            case Element(disabled, _, resetHandler, render):
                kind = Element(disabled, keywords, resetHandler, render);
        }
        return this;
    }

    /**
     * Set whether the setting item is disabled, default is false.
     *
     * A disabled item is rendered with reduced opacity. For an `Item` the
     * underlying field is also rendered in a non-interactive state. For an
     * `Element` the `disabled` flag is forwarded via
     * `RenderOptions.isDisabled()` so the custom renderer can disable its
     * interactive controls.
     */
    public function disabled(disabled:Bool):SettingItem {
        switch kind {
            case Item(title, description, keywords, layout, _, field):
                kind = Item(title, description, keywords, layout, disabled, field);
            case Element(_, keywords, resetHandler, render):
                kind = Element(disabled, keywords, resetHandler, render);
        }
        return this;
    }

    /**
     * Set the description of the setting item.
     *
     * Only applies to an `Item`.
     */
    public function description(description:IntoText):SettingItem {
        switch kind {
            case Item(title, _, keywords, layout, disabled, field):
                kind = Item(title, description, keywords, layout, disabled, field);
            case Element(_, _, _, _):
        }
        return this;
    }

    /**
     * Set the layout of the setting item.
     *
     * Only applies to an `Item`.
     */
    public function layout(layout:Axis):SettingItem {
        switch kind {
            case Item(title, description, keywords, _, disabled, field):
                kind = Item(title, description, keywords, layout, disabled, field);
            case Element(_, _, _, _):
        }
        return this;
    }

    /**
     * Rust `str::contains` after `to_lowercase` on both sides.
     */
    static inline function containsLower(text:String, q:String):Bool {
        return text.toLowerCase().indexOf(q) != -1;
    }

    @:allow(gpui.component.setting, tests)
    function isMatch(query:String, cx:App):Bool {
        return switch kind {
            case Item(title, description, keywords, _, _, _):
                final q = query.toLowerCase();
                containsLower(title, q)
                    || (description != null && containsLower(description.getText(cx), q))
                    || Lambda.exists(keywords, s -> containsLower(s, q));
            // We need to show all custom elements when not searching.
            case Element(_, keywords, _, _):
                final q = query.toLowerCase();
                query.length == 0 || Lambda.exists(keywords, s -> containsLower(s, q));
        }
    }

    @:allow(gpui.component.setting, tests)
    function isResettable(cx:App):Bool {
        return switch kind {
            case Item(_, _, _, _, _, field): field.isResettable(cx);
            case Element(_, _, resetHandler, _): resetHandler != null && resetHandler.isDirty(cx);
        }
    }

    @:allow(gpui.component.setting, tests)
    function reset(window:Window, cx:App):Void {
        switch kind {
            case Item(_, _, _, _, _, field): field.reset(window, cx);
            case Element(_, _, resetHandler, _):
                if (resetHandler != null) {
                    resetHandler.reset(window, cx);
                }
        }
    }

    static function renderField(title:String, field:AnySettingField, options:RenderOptions, window:Window, cx:App):AnyElement {
        final fieldType = field.fieldType();
        final style = field.style();
        final kind = field.valueKind();
        final renderer:SettingFieldRender = if (kind == BoolValue) {
            new BoolField(SettingFieldTypeTools.isSwitch(fieldType), title);
        } else if (kind == FloatValue && SettingFieldTypeTools.isNumberInput(fieldType)) {
            new NumberField(SettingFieldTypeTools.numberInputOptions(fieldType), title);
        } else if (kind == StringValue && SettingFieldTypeTools.isInput(fieldType)) {
            new StringField(title);
        } else if (kind == StringValue && SettingFieldTypeTools.isDropdown(fieldType)) {
            new DropdownField(SettingFieldTypeTools.dropdownOptions(fieldType), SettingFieldTypeTools.dropdownScrollable(fieldType), title);
        } else if (SettingFieldTypeTools.isElement(fieldType)) {
            new ElementField(SettingFieldTypeTools.element(fieldType));
        } else {
            throw 'Unsupported setting type: $kind';
        };

        return renderer.render(field, options, style, window, cx);
    }

    @:allow(gpui.component.setting, tests)
    function renderItem(options:RenderOptions, window:Window, cx:App):Div {
        final theme = Theme.global(cx);
        final content:AnyElement = switch kind {
            case Item(title, description, _, layout, disabled, field):
                final layout = options.layout().isVertical() ? Axis.Vertical : layout;

                final row = div().wFull();
                if (disabled) row.opacity(0.5);
                if (layout.isHorizontal()) {
                    row.hFlex().justifyBetween().itemsCenter();
                } else {
                    row.vFlex();
                }
                row.gap3();
                final heading = vFlex();
                if (layout.isHorizontal()) {
                    heading.flex1().maxW3_5();
                } else {
                    heading.wFull();
                }
                heading.child(new Label(title).textSm());
                if (description != null) {
                    heading.child(
                        div()
                            .sizeFull()
                            .textSm()
                            .textColor(theme.mutedForeground)
                            .child(description.render(window, cx))
                    );
                }
                row.child(heading);
                row.child(div().id('field').child(renderField(
                    title,
                    field,
                    options.withLayout(layout).withDisabled(disabled),
                    window,
                    cx
                )));
                row.intoAnyElement();
            case Element(disabled, _, _, render):
                final row = div().wFull();
                if (disabled) row.opacity(0.5);
                row.child(render(options.withDisabled(disabled), window, cx)).intoAnyElement();
        };
        return div()
            .id(ElementId.Name('item-${options.itemIx()}'))
            .wFull()
            .child(content);
    }

}
