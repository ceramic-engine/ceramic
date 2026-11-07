// Ported from gpui-kit 0.8.1: crates/component/src/setting/fields/mod.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.setting;

import gpui.AnyElement;
import gpui.App;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.component.setting.ElementField.SettingFieldElement;
import gpui.component.setting.ElementField.FnSettingFieldElement;
import gpui.component.setting.NumberField.NumberFieldOptions;

/**
 * Custom reset behavior for a setting field or item.
 *
 * `isDirty` reports whether the target is "dirty" (controls the reset button
 * visibility), `reset` performs the reset. Used by `element` / `render`
 * fields and custom element items whose state is not expressed through the
 * typed `defaultValue` mechanism.
 */
class ResetHandler {

    public final isDirty:(App) -> Bool;

    public final reset:(Window, App) -> Void;

    public function new(isDirty:(App) -> Bool, reset:(Window, App) -> Void) {
        this.isDirty = isDirty;
        this.reset = reset;
    }

}

/**
 * Renders the control of a setting field.
 */
interface SettingFieldRender {

    function render(field:AnySettingField, options:RenderOptions, style:StyleRefinement, window:Window, cx:App):AnyElement;

}

/**
 * An option of a dropdown field: the value stored by the setting and the
 * label shown (Rust `(SharedString, SharedString)`).
 */
typedef DropdownOption = {
    final value:String;
    final label:String;
}

/**
 * The type of setting field to render.
 */
enum SettingFieldType {
    Switch;
    Checkbox;
    NumberInput(options:NumberFieldOptions);
    Input;
    Dropdown(options:Array<DropdownOption>, scrollable:Bool);
    Element(element:SettingFieldElement);
}

class SettingFieldTypeTools {

    public static inline function isSwitch(self:SettingFieldType):Bool {
        return self.match(Switch);
    }

    public static inline function isNumberInput(self:SettingFieldType):Bool {
        return self.match(NumberInput(_));
    }

    public static inline function isInput(self:SettingFieldType):Bool {
        return self.match(Input);
    }

    public static inline function isDropdown(self:SettingFieldType):Bool {
        return self.match(Dropdown(_, _));
    }

    public static inline function isElement(self:SettingFieldType):Bool {
        return self.match(Element(_));
    }

    public static function dropdownOptions(self:SettingFieldType):Null<Array<DropdownOption>> {
        return switch self {
            case Dropdown(options, _): options;
            case _: null;
        }
    }

    public static function dropdownScrollable(self:SettingFieldType):Bool {
        return switch self {
            case Dropdown(_, scrollable): scrollable;
            case _: false;
        }
    }

    public static function numberInputOptions(self:SettingFieldType):Null<NumberFieldOptions> {
        return switch self {
            case NumberInput(options): options;
            case _: null;
        }
    }

    public static function element(self:SettingFieldType):SettingFieldElement {
        return switch self {
            case Element(element): element;
            case _: throw 'element_render called on non-element field';
        }
    }

}

/**
 * The value type of a setting field (Rust dispatches the renderers on the
 * `TypeId` of `T`; `String` and `SharedString` are both `String` here).
 */
enum abstract SettingValueKind(Int) {
    var BoolValue;
    var FloatValue;
    var StringValue;
}

/**
 * A trait for setting fields that allows for dynamic typing.
 */
interface AnySettingField {

    /** Rust `type_id`: the value type of the field. */
    function valueKind():SettingValueKind;

    function fieldType():SettingFieldType;

    function style():StyleRefinement;

    function isResettable(cx:App):Bool;

    function reset(window:Window, cx:App):Void;

}

/**
 * A setting field that can get and set a value of type T in the App.
 */
class SettingField<T> implements AnySettingField implements Styled {

    @:allow(gpui.component.setting, tests)
    final fieldTypeValue:SettingFieldType;

    @:allow(gpui.component.setting, tests)
    final fieldStyle:StyleRefinement = new StyleRefinement();

    /**
     * Function to get the value for this field.
     */
    @:allow(gpui.component.setting, tests)
    final value:(App) -> T;

    /**
     * Function to set the value for this field.
     */
    @:allow(gpui.component.setting, tests)
    final setValue:(T, App) -> Void;

    @:allow(gpui.component.setting, tests)
    var defaultValueValue:Null<T> = null;

    var hasDefaultValue:Bool = false;

    /**
     * Optional custom reset behavior, used by `element` / `render` fields
     * whose state is not expressed through the typed `defaultValue`
     * mechanism. When set, it takes precedence over the `defaultValue` based
     * reset.
     */
    @:allow(gpui.component.setting, tests)
    var resetHandler:Null<ResetHandler> = null;

    final kind:SettingValueKind;

    /**
     * Create a new Switch field.
     */
    public static function switch_(value:(App) -> Bool, setValue:(Bool, App) -> Void):SettingField<Bool> {
        return new SettingField<Bool>(BoolValue, SettingFieldType.Switch, value, setValue);
    }

    /**
     * Create a new Checkbox field.
     */
    public static function checkbox(value:(App) -> Bool, setValue:(Bool, App) -> Void):SettingField<Bool> {
        return new SettingField<Bool>(BoolValue, SettingFieldType.Checkbox, value, setValue);
    }

    /**
     * Create a new Input field.
     */
    public static function input(value:(App) -> String, setValue:(String, App) -> Void):SettingField<String> {
        return new SettingField<String>(StringValue, SettingFieldType.Input, value, setValue);
    }

    /**
     * Create a new Dropdown field with the given options.
     *
     * The popup menu does not scroll. For long option lists that may exceed
     * the viewport, use `scrollableDropdown` instead.
     */
    public static function dropdown(options:Array<DropdownOption>, value:(App) -> String, setValue:(String, App) -> Void):SettingField<String> {
        return new SettingField<String>(StringValue, SettingFieldType.Dropdown(options, false), value, setValue);
    }

    /**
     * Create a new Dropdown field whose popup menu scrolls when its content
     * exceeds the viewport.
     */
    public static function scrollableDropdown(options:Array<DropdownOption>, value:(App) -> String, setValue:(String, App) -> Void):SettingField<String> {
        return new SettingField<String>(StringValue, SettingFieldType.Dropdown(options, true), value, setValue);
    }

    /**
     * Create a new setting field with the given custom element that
     * implements `SettingFieldElement`.
     *
     * See also `render` for simply building with a render closure.
     */
    public static function element(element:SettingFieldElement):SettingField<String> {
        return new SettingField<String>(StringValue, SettingFieldType.Element(element), _ -> '', (_, _) -> {});
    }

    /**
     * Create a new setting field with the given element render closure.
     *
     * See also `element` for building with a custom field for more complex scenarios.
     */
    public static function render(elementRender:(RenderOptions, Window, App) -> gpui.IntoElement):SettingField<String> {
        return element(new FnSettingFieldElement((options, window, cx) -> elementRender(options, window, cx).intoAnyElement()));
    }

    /**
     * Create a new Number Input field with the given options.
     */
    public static function numberInput(options:NumberFieldOptions, value:(App) -> Float, setValue:(Float, App) -> Void):SettingField<Float> {
        return new SettingField<Float>(FloatValue, SettingFieldType.NumberInput(options), value, setValue);
    }

    /**
     * Create a new setting field with the given get and set functions.
     */
    function new(kind:SettingValueKind, fieldType:SettingFieldType, value:(App) -> T, setValue:(T, App) -> Void) {
        this.kind = kind;
        this.fieldTypeValue = fieldType;
        this.value = value;
        this.setValue = setValue;
    }

    /**
     * Set the default value for this setting field, default is null.
     *
     * If set, this value can be used to reset the setting to its default state.
     * If not set, the setting cannot be reset.
     */
    public function defaultValue(defaultValue:T):SettingField<T> {
        this.defaultValueValue = defaultValue;
        this.hasDefaultValue = true;
        return this;
    }

    /**
     * Provide custom reset behavior for this field.
     *
     * This is intended for `element` / `render` fields, whose state is
     * managed externally and therefore not covered by the typed
     * `defaultValue` reset mechanism.
     *
     * - `isDirty` reports whether the field differs from its default and thus
     *   whether the reset button should appear.
     * - `reset` performs the reset.
     *
     * When set, this takes precedence over the `defaultValue` based reset.
     */
    public function onReset(isDirty:(App) -> Bool, reset:(Window, App) -> Void):SettingField<T> {
        this.resetHandler = new ResetHandler(isDirty, reset);
        return this;
    }

    public inline function style():StyleRefinement {
        return fieldStyle;
    }

    public function valueKind():SettingValueKind {
        return kind;
    }

    public function fieldType():SettingFieldType {
        return fieldTypeValue;
    }

    public function isResettable(cx:App):Bool {
        if (resetHandler != null) {
            return resetHandler.isDirty(cx);
        }

        // `element` / `render` fields carry no typed value (their `value`
        // always returns the default), so the `defaultValue` comparison is
        // meaningless for them. Without a custom `onReset`, they are not
        // resettable.
        if (SettingFieldTypeTools.isElement(fieldTypeValue)) {
            return false;
        }

        if (!hasDefaultValue) {
            return false;
        }

        return value(cx) != defaultValueValue;
    }

    public function reset(window:Window, cx:App):Void {
        if (resetHandler != null) {
            resetHandler.reset(window, cx);
            return;
        }

        if (!hasDefaultValue) {
            return;
        }

        setValue(defaultValueValue, cx);
    }

    /**
     * Rust `get_value::<T>(field, cx)`: the field's current value.
     */
    public static function getValueOf<V>(field:AnySettingField, cx:App):V {
        final settingField:SettingField<V> = cast field;
        return settingField.value(cx);
    }

    /**
     * Rust `set_value::<T>(field, cx)`: the field's setter.
     */
    public static function setValueOf<V>(field:AnySettingField, cx:App):(V, App) -> Void {
        final settingField:SettingField<V> = cast field;
        return settingField.setValue;
    }

}
