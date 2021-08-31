package elements;

import ceramic.ReadOnlyArray;
import elements.Context.context;
import tracker.Model;

using ceramic.Extensions;

class WindowData extends Model {

    @serialize public var x:Float = 20;

    @serialize public var y:Float = 40;

    @serialize public var expanded:Bool = true;

    var itemIndex:Int = 0;

    public var items(default, null):ReadOnlyArray<WindowItem> = [];

    public var numItems(get, never):Int;
    inline function get_numItems():Int return itemIndex;

    public var form:FormLayout = null;

    public var used:Bool = true;

    public var window:Window = null;

    public function new() {

        super();

    }

    public function beginFrame():Void {

        // Mark window as not used at the beginning of the frame
        used = false;

        var len = itemIndex;
        itemIndex = 0;

    }

    public function endFrame():Void {

        // If window still marked as not used,
        // destroy view and recycle items
        if (!used) {
            if (window != null) {
                var w = window;
                window = null;
                w.destroy();
            }
        }
        else {
            if (window != null) {
                // Save position
                x = window.x;
                y = window.y;
            }
        }

        // In any case, check remaining items that are not used and recycle them
        for (i in itemIndex...items.length) {
            var item = items[i];
            if (item != null) {
                items.original[i] = null;
                item.recycle();
            }
        }

    }

    public function addItem(item:WindowItem):Void {

        var previous = items[itemIndex];

        if (previous != null) {
            if (previous.previous != null) {
                previous.previous.recycle();
                previous.previous = null;
            }
        }

        item.previous = previous;
        items.original[itemIndex] = item;

        itemIndex++;

    }

}