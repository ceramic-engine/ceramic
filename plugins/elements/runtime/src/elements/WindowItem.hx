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

    public var string0:String = null;

    public var string1:String = null;

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
                if (item.stringArray0 == stringArray0 || Equal.arrayEqual(item.stringArray0, stringArray0)) {
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
                var item:LabeledFieldView<SelectFieldView> = (view != null ? cast view : null);
                if (item == null) {
                    var fieldView = new SelectFieldView();
                    fieldView.list = stringArray0;
                    item = new LabeledFieldView(fieldView);
                    item.label = string0;
                }
                item.field.setValue = function(field, value) {
                    scheduleSetIntValue(field.list.indexOf(value));
                };
                var newValue = stringArray0[int0];
                if (newValue != item.field.value) {
                    item.field.value = newValue;
                }
                return item;

        }

    }

    public function recycle() {

        kind = UNKNOWN;
        previous = null;
        int0 = 0;
        int1 = 0;
        string0 = null;
        string1 = null;
        stringArray0 = null;

        pool.recycle(this);

    }

    public function flushPendingCallbacks():Void {

        if (pendingCallbacks != null) {
            while (pendingCallbacks.length > 0) {
                var cb = pendingCallbacks.shift();
                cb();
            }
        }

    }

    function scheduleSetIntValue(value:Int):Void {

        pendingCallbacks.push(function() {
            int1 = value;
        });

    }

}
