package elements;

import ceramic.Equal;
import ceramic.Pool;
import ceramic.View;
import tracker.Autorun.reobserve;
import tracker.Autorun.unobserve;

using StringTools;
using elements.WindowItem.WindowItemExtensions;

/**
 * A simple class to hold window item data.
 * The same class is used for every window item kind so
 * that it's easier to recycle it and avoid allocating
 * too much data at every frame.
 */
class WindowItem {

    static var pool = new Pool<WindowItem>();

    public static function get():WindowItem {

        var item = pool.get();
        if (item == null) {
            item = new WindowItem();
        }
        return item;

    }

    public var kind:WindowItemKind = UNKNOWN;

    public var previous:WindowItem = null;

    public var int0:Int = 0;

    public var int1:Int = 0;

    public var int2:Int = 0;

    public var float0:Float = 0;

    public var float1:Float = 0;

    public var float2:Float = 0;

    public var float3:Float = 0;

    public var float4:Float = 0;

    public var bool0:Bool = false;

    public var string0:String = null;

    public var string1:String = null;

    public var string2:String = null;

    public var string3:String = null;

    public var stringArray0:Array<String> = null;

    public function new() {}

    public function isSameItem(item:WindowItem):Bool {

        if (item == null)
            return false;

        if (item.kind != kind)
            return false;

        switch kind {

            case UNKNOWN:
                return false;

            case SELECT:
                if (isSimilarLabel(item) &&
                    (item.stringArray0 == stringArray0 || Equal.arrayEqual(item.stringArray0, stringArray0))) {
                    return true;
                }
                else {
                    return false;
                }

            case EDIT_TEXT:
                return isSimilarLabel(item);

            case EDIT_FLOAT:
                return isSimilarLabel(item);

            case EDIT_INT:
                return isSimilarLabel(item);

            case TEXT:
                return true;

        }

    }

    inline function isSimilarLabel(item:WindowItem):Bool {

        return ((item.string2 != null && string2 != null) || (item.string2 == null && string2 == null));

    }

    public function updateView(view:View):View {

        switch kind {

            case UNKNOWN:
                return view;

            case SELECT:
                return createOrUpdateSelectField(view);

            case EDIT_TEXT | EDIT_FLOAT | EDIT_INT:
                return createOrUpdateEditTextField(view);

            case TEXT:
                return createOrUpdateText(view);

        }

    }

    public function recycle() {

        kind = UNKNOWN;
        previous = null;
        int0 = 0;
        int1 = 0;
        int2 = 0;
        float0 = 0;
        float1 = 0;
        float2 = 0;
        float3 = 0;
        float4 = 0;
        bool0 = false;
        string0 = null;
        string1 = null;
        string2 = null;
        string3 = null;
        stringArray0 = null;

        pool.recycle(this);

    }

    function createOrUpdateSelectField(view:View):View {

        var field:SelectFieldView = null;
        var labeled:LabeledFieldView<SelectFieldView> = null;
        var justCreated = false;
        if (string2 != null) {
            labeled = (view != null ? cast view : null);
            if (labeled == null) {
                justCreated = true;
                field = new SelectFieldView();
                labeled = new LabeledFieldView(field);
            }
            else {
                field = labeled.field;
            }
            labeled.label = string2;
            labeled.labelPosition = int2;
            labeled.labelWidth = float2;
        }
        else {
            field = (view != null ? cast view : null);
            if (field == null) {
                justCreated = true;
                field = new SelectFieldView();
            }
        }
        field.data = this;
        field.list = stringArray0;
        if (justCreated) {
            field.setValue = _selectSetIntValue;
        }
        var newValue = stringArray0[int0];
        if (newValue != field.value) {
            field.value = newValue;
        }
        return labeled != null ? labeled : field;

    }

    static function _selectSetIntValue(field:SelectFieldView, value:String):Void {

        final item = field.windowItem();
        final index = field.list.indexOf(value);
        item.int1 = index;

    }

    function createOrUpdateEditTextField(view:View):View {

        var field:TextFieldView = null;
        var labeled:LabeledFieldView<TextFieldView> = null;
        var justCreated = false;
        if (string2 != null) {
            labeled = (view != null ? cast view : null);
            if (labeled == null) {
                justCreated = true;
                field = new TextFieldView();
                labeled = new LabeledFieldView(field);
            }
            else {
                field = labeled.field;
            }
            labeled.label = string2;
            labeled.labelPosition = int2;
            labeled.labelWidth = float2;
        }
        else {
            field = (view != null ? cast view : null);
            if (field == null) {
                justCreated = true;
                field = new TextFieldView();
            }
        }


        var previous = field.windowItem();
        field.data = this;

        if (kind == EDIT_TEXT) {
            if (justCreated) {
                field.setValue = _editTextSetValue;
            }
            if (string0 != field.textValue) {
                field.textValue = string0;
            }
            field.multiline = bool0;
            field.placeholder = string3;
        }
        else if (kind == EDIT_FLOAT) {
            if (justCreated) {
                field.setTextValue = _editFloatSetTextValue;
                field.setEmptyValue = _editFloatSetEmptyValue;
                field.setValue = _editFloatSetValue;
                field.onFocusedChange(null, (focused, _) -> {
                    if (!focused)
                        _editFloatFinishEditing(field);
                });
            }
            if (justCreated || previous.float1 != float0) {
                field.textValue = '' + float0;
            }
        }
        else if (kind == EDIT_INT) {
            if (justCreated) {
                field.setTextValue = _editIntSetTextValue;
                field.setEmptyValue = _editIntSetEmptyValue;
                field.setValue = _editIntSetValue;
                field.onFocusedChange(null, (focused, _) -> {
                    if (!focused)
                        _editIntFinishEditing(field);
                });
            }
            if (justCreated || previous.int1 != int0) {
                field.textValue = '' + int0;
            }
        }

        return labeled != null ? labeled : field;

    }

    static function _editTextSetValue(field:TextFieldView, value:String):Void {

        field.windowItem().string1 = value;

    }

    static function _editFloatSetTextValue(field:TextFieldView, textValue:String):Void {

        if (!_editFloatOrIntOperations(field, textValue)) {
            var item = field.windowItem();
            var minValue = -999999999; // Allow lower value at this stage because we are typing
            var maxValue = item.float4;
            SanitizeTextField.setTextValueToFloat(field, textValue, minValue, maxValue);
        }

    }

    static function _editFloatSetEmptyValue(field:TextFieldView):Void {

        final item = field.windowItem();
        var minValue = item.float3;
        var maxValue = item.float4;
        item.float1 = SanitizeTextField.setEmptyToFloat(field, minValue, maxValue);

    }

    static function _editFloatSetValue(field:TextFieldView, value:Dynamic):Void {

        final item = field.windowItem();
        var minValue = item.float3;
        var maxValue = item.float4;
        var floatValue:Float = value;
        if (value >= minValue && value <= maxValue) {
            item.float1 = floatValue;
        }

    }

    static function _editFloatFinishEditing(field:TextFieldView):Void {

        var item = field.windowItem();
        var minValue = item.float3;
        var maxValue = item.float4;
        if (!_applyFloatOrIntOperationsIfNeeded(field, field.textValue, minValue, maxValue, false)) {
            SanitizeTextField.setTextValueToFloat(field, field.textValue, minValue, maxValue);
            if (field.textValue.endsWith('.')) {
                field.textValue = field.textValue.substring(0, field.textValue.length - 1);
                field.invalidateTextValue();
            }
        }

    }

    static function _editIntSetTextValue(field:TextFieldView, textValue:String):Void {

        if (!_editFloatOrIntOperations(field, textValue)) {
            var item = field.windowItem();
            var minValue = -999999999; // Allow lower value at this stage because we are typing
            var maxValue = Std.int(item.float4);
            SanitizeTextField.setTextValueToInt(field, textValue, minValue, maxValue);
        }

    }

    static function _editIntSetEmptyValue(field:TextFieldView):Void {

        final item = field.windowItem();
        var minValue = Std.int(item.float3);
        var maxValue = Std.int(item.float4);
        item.int1 = SanitizeTextField.setEmptyToInt(field, minValue, maxValue);

    }

    static function _editIntSetValue(field:TextFieldView, value:Dynamic):Void {

        final item = field.windowItem();
        var minValue = item.float3;
        var maxValue = item.float4;
        var intValue:Int = value;
        if (value >= minValue && value <= maxValue) {
            item.int1 = intValue;
        }

    }

    static function _editIntFinishEditing(field:TextFieldView):Void {

        var item = field.windowItem();
        var minValue = Std.int(item.float3);
        var maxValue = Std.int(item.float4);
        if (!_applyFloatOrIntOperationsIfNeeded(field, field.textValue, minValue, maxValue, true)) {
            SanitizeTextField.setTextValueToInt(field, field.textValue, minValue, maxValue);
        }

    }

    static function _editFloatOrIntOperations(field:TextFieldView, textValue:String):Bool {

        // TODO move this somewhere else?

        var addIndex = textValue.indexOf('+');
        var subtractIndex = textValue.indexOf('-');
        var multiplyIndex = textValue.indexOf('*');
        var divideIndex = textValue.indexOf('/');
        if (addIndex > 0 && !(subtractIndex > 0 || multiplyIndex > 0 || divideIndex > 0)) {
            field.textValue = textValue.trim();
            if (textValue != field.textValue)
                field.invalidateTextValue();
            return true;
        }
        if (subtractIndex > 0 && !(addIndex > 0 || multiplyIndex > 0 || divideIndex > 0)) {
            field.textValue = textValue.trim();
            if (textValue != field.textValue)
                field.invalidateTextValue();
            return true;
        }
        if (multiplyIndex > 0 && !(addIndex > 0 || subtractIndex > 0 || divideIndex > 0)) {
            field.textValue = textValue.trim();
            if (textValue != field.textValue)
                field.invalidateTextValue();
            return true;
        }
        if (divideIndex > 0 && !(addIndex > 0 || multiplyIndex > 0 || subtractIndex > 0)) {
            field.textValue = textValue.trim();
            if (textValue != field.textValue)
                field.invalidateTextValue();
            return true;
        }

        return false;

    }

    static function _applyFloatOrIntOperationsIfNeeded(field:TextFieldView, textValue:String, minValue:Float, maxValue:Float, castToInt:Bool):Bool {

        var addIndex = textValue.indexOf('+');
        var subtractIndex = textValue.indexOf('-');
        var multiplyIndex = textValue.indexOf('*');
        var divideIndex = textValue.indexOf('/');
        if (addIndex > 0) {
            var before = textValue.substr(0, addIndex).trim();
            var after = textValue.substr(addIndex + 1).trim();
            var result = Std.parseFloat(before) + Std.parseFloat(after);
            if (!Math.isNaN(result)) {
                if (castToInt)
                    SanitizeTextField.setTextValueToInt(field, ''+result, Std.int(minValue), Std.int(maxValue));
                else
                    SanitizeTextField.setTextValueToFloat(field, ''+result, minValue, maxValue);
            }
            else {
                if (castToInt)
                    SanitizeTextField.setTextValueToInt(field, before, Std.int(minValue), Std.int(maxValue));
                else
                    SanitizeTextField.setTextValueToFloat(field, before, minValue, maxValue);
            }
            return true;
        }
        else if (subtractIndex > 0) {
            var before = textValue.substr(0, subtractIndex).trim();
            var after = textValue.substr(subtractIndex + 1).trim();
            var result = Std.parseFloat(before) - Std.parseFloat(after);
            if (!Math.isNaN(result)) {
                if (castToInt)
                    SanitizeTextField.setTextValueToInt(field, ''+result, Std.int(minValue), Std.int(maxValue));
                else
                    SanitizeTextField.setTextValueToFloat(field, ''+result, minValue, maxValue);
            }
            else {
                if (castToInt)
                    SanitizeTextField.setTextValueToInt(field, before, Std.int(minValue), Std.int(maxValue));
                else
                    SanitizeTextField.setTextValueToFloat(field, before, minValue, maxValue);
            }
            return true;
        }
        else if (multiplyIndex > 0) {
            var before = textValue.substr(0, multiplyIndex).trim();
            var after = textValue.substr(multiplyIndex + 1).trim();
            var result = Std.parseFloat(before) * Std.parseFloat(after);
            if (!Math.isNaN(result)) {
                if (castToInt)
                    SanitizeTextField.setTextValueToInt(field, ''+result, Std.int(minValue), Std.int(maxValue));
                else
                    SanitizeTextField.setTextValueToFloat(field, ''+result, minValue, maxValue);
            }
            else {
                if (castToInt)
                    SanitizeTextField.setTextValueToInt(field, before, Std.int(minValue), Std.int(maxValue));
                else
                    SanitizeTextField.setTextValueToFloat(field, before, minValue, maxValue);
            }
            return true;
        }
        else if (divideIndex > 0) {
            var before = textValue.substr(0, divideIndex).trim();
            var after = textValue.substr(divideIndex + 1).trim();
            var result = Std.parseFloat(before) / Std.parseFloat(after);
            if (!Math.isNaN(result)) {
                if (castToInt)
                    SanitizeTextField.setTextValueToInt(field, ''+result, Std.int(minValue), Std.int(maxValue));
                else
                    SanitizeTextField.setTextValueToFloat(field, ''+result, minValue, maxValue);
            }
            else {
                if (castToInt)
                    SanitizeTextField.setTextValueToInt(field, before, Std.int(minValue), Std.int(maxValue));
                else
                    SanitizeTextField.setTextValueToFloat(field, before, minValue, maxValue);
            }
            return true;
        }
        else {
            return false;
        }

    }

    function createOrUpdateText(view:View):View {

        var text:LabelView = (view != null ? cast view : null);
        if (text == null) {
            text = new LabelView();
        }
        if (text.content != string0) {
            text.content = string0;
        }
        text.align = switch int0 {
            default: LEFT;
            case 1: RIGHT;
            case 2: CENTER;
        };
        return text;

    }

}

private class WindowItemExtensions {

    inline public static function windowItem(field:FieldView):WindowItem {
        return field.hasData ? field.data : null;
    }

}
