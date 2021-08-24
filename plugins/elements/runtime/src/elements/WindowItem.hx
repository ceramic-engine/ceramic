package elements;

import ceramic.Equal;
import ceramic.Pool;
import ceramic.View;

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

    public var bool0:Bool = false;

    public var string0:String = null;

    public var string1:String = null;

    public var string2:String = null;

    public var string3:String = null;

    public var stringArray0:Array<String> = null;

    public var pendingCallbacks:Array<Void->Void> = [];

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
                if (((item.string2 != null && string2 != null) || (item.string2 == null && string2 == null)) &&
                    (item.stringArray0 == stringArray0 || Equal.arrayEqual(item.stringArray0, stringArray0))) {
                    return true;
                }
                else {
                    return false;
                }

            case EDIT_TEXT:
                if (((item.string2 != null && string2 != null) || (item.string2 == null && string2 == null)) &&
                    item.bool0 == bool0) {
                    return true;
                }
                else {
                    return false;
                }

        }

    }

    public function updateView(view:View):View {

        switch kind {

            case UNKNOWN:
                return view;

            case SELECT:
                return createOrUpdateSelectField(view);

            case EDIT_TEXT:
                return createOrUpdateTextField(view);

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
        if (string2 != null) {
            labeled = (view != null ? cast view : null);
            if (labeled == null) {
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
                field = new SelectFieldView();
            }
        }
        field.list = stringArray0;
        field.setValue = function(field, value) {
            scheduleSetInt1Value(field.list.indexOf(value));
        };
        var newValue = stringArray0[int0];
        if (newValue != field.value) {
            field.value = newValue;
        }
        return labeled != null ? labeled : field;

    }

    function createOrUpdateTextField(view:View):View {

        var field:TextFieldView = null;
        var labeled:LabeledFieldView<TextFieldView> = null;
        if (string2 != null) {
            labeled = (view != null ? cast view : null);
            if (labeled == null) {
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
                field = new TextFieldView();
            }
        }
        if (string0 != field.textValue) {
            field.textValue = string0;
        }
        field.multiline = bool0;
        field.placeholder = string3;
        field.setValue = function(field, value) {
            scheduleSetString1Value(value);
        };
        return labeled != null ? labeled : field;

    }

    public function flushPendingCallbacks():Void {

        if (pendingCallbacks != null) {
            while (pendingCallbacks.length > 0) {
                var cb = pendingCallbacks.shift();
                cb();
            }
        }

    }

    function scheduleSetInt1Value(value:Int):Void {

        pendingCallbacks.push(function() {
            int1 = value;
        });

    }

    function scheduleSetString1Value(value:String):Void {

        pendingCallbacks.push(function() {
            string1 = value;
        });

    }

}
