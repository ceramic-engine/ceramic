package elements;

#if !macro
import ceramic.Assert.assert;
import ceramic.ColumnLayout;
import ceramic.ViewSize;
import elements.Context.context;
#end

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/**
 * API inspired by Dear ImGui,
 * but using ceramic elements UI,
 * making it work with any ceramic target
 */
class Im {

    #if !macro

    public static function extractId(key:String):String {

        return key; // TODO smarter

    }

    public static function extractTitle(key:String):String {

        return key; // TODO smarter

    }

    @:noCompletion public static function beginFrame():Void {

        for (id => windowData in context.windowsData) {
            windowData.beginFrame();
        }

    }

    @:noCompletion public static function endFrame():Void {

        for (id => windowData in context.windowsData) {
            windowData.endFrame();
        }

    }

    public static function depth(depth:Float):Void {

        // Create view if needed
        if (context.view == null) {
            ImSystem.shared.createView();
        }

        // Set depth
        context.view.depth = depth;

    }

    public static function begin(key:String, width:Float):Window {

        assert(context.currentWindow == null, 'Duplicate begin() calls!');

        // Create view if needed
        if (context.view == null) {
            ImSystem.shared.createView();
        }

        // Get or create window
        var id = extractId(key);
        var title = extractTitle(key);
        var windowData = context.windowsData.get(id);
        var window = windowData != null ? windowData.window : null;

        if (windowData == null) {
            windowData = new WindowData();
            windowData.id = id;
            windowData.beginFrame();
            context.windowsData.original.set(id, windowData);
        }

        if (window == null) {
            window = new Window();
            window.id = id;
            window.pos(windowData.x, windowData.y);
            window.viewHeight = ViewSize.auto();
            window.onHeaderClick(window, function() {
                windowData.expanded = !windowData.expanded;
            });
            context.view.add(window);
            windowData.window = window;
        }
        window.viewWidth = width;
        window.title = title;

        // Mark window as used this frame
        windowData.used = true;

        // Make the window current
        context.currentWindowData = windowData;

        return window;

    }

    public inline extern static overload function select(title:String, value:StringPointer, list:Array<String>, ?nullValueText:String):Bool {

        var index:Int = list.indexOf(Im.readString(value));
        var changed = false;
        if (_select(title, Im.int(index), list, nullValueText)) {
            Im.writeString(value, list[index]);
            changed = true;
        }
        return changed;

    }

    public inline extern static overload function select(title:String, value:IntPointer, list:Array<String>, ?nullValueText:String):Bool {

        return _select(title, value, list, nullValueText);

    }

    static function _select(title:String, index:IntPointer, list:Array<String>, ?nullValueText:String):Bool {

        var windowData = context.currentWindowData;

        if (!windowData.expanded)
            return false;

        var item = WindowItem.get();
        item.kind = SELECT;
        item.int0 = Im.readInt(index);
        item.int1 = item.int0;
        item.string0 = title;
        item.stringArray0 = list;
        item.string1 = nullValueText;

        windowData.addItem(item);

        if (item.isSameItem(item.previous)) {
            // Did value changed from field last frame?
            var prevValue = item.previous.int0;
            var newValue = item.previous.int1;
            if (newValue != prevValue) {
                Im.writeInt(index, newValue);
                return true;
            }
            // Did value changed from outside?
            prevValue = item.previous.int1;
            newValue = item.int0;
        }

        return false;

    }

    public static function end():Void {

        assert(context.currentWindowData != null, 'Called end() without calling begin() before!');

        // Sync window items
        var windowData = context.currentWindowData;
        var window = windowData != null ? windowData.window : null;

        if (!windowData.expanded) {
            var prevContentView = window.contentView;
            if (prevContentView != null) {
                window.contentView = null;
                prevContentView.destroy();
                windowData.form = null;
            }
        }
        else {
            var form = windowData.form;
            var needsContentRebuild = false;
            if (window.contentView == null) {

                needsContentRebuild = true;

                form = new FormLayout();
                form.viewSize(ViewSize.auto(), ViewSize.auto());
                form.transparent = true;

                windowData.form = form;

                var container = new ColumnLayout();
                container.color = Context.context.theme.darkerBackgroundColor;
                container.alpha = 0.7;
                container.transparent = false;
                container.viewSize(ViewSize.auto(), ViewSize.auto());
                container.add(form);

                /*var overflowScroll = false;
                if (overflowScroll) {
                    container.paddingRight = 12;
                    var scroll = new ScrollingLayout(container, true);
                    scroll.checkChildrenOfView = form;
                    scroll.scroller.scrollbar = new Scrollbar();
                    scroll.transparent = true;
                    scroll.viewSize(ViewSize.fill(), 200);
                    window.contentView = scroll;
                }
                else {*/
                    window.contentView = container;
                //}
            }

            var windowItems = windowData.items;
            if (!needsContentRebuild) {
                for (i in 0...windowData.numItems) {
                    var item = windowItems.unsafeGet(i);
                    if (item.previous == null) {
                        needsContentRebuild = true;
                        break;
                    }
                }
            }

            if (needsContentRebuild) {
                var views = form.subviews != null ? [].concat(form.subviews.original) : [];
                form.removeAllViews();

                for (i in 0...windowData.numItems) {
                    var item = windowItems.unsafeGet(i);
                    var view = views[i];
                    var reuseView = (item.previous != null && item.isSameItem(item.previous));
                    if (view == null || !reuseView) {
                        if (view != null) {
                            view.destroy();
                            view = null;
                        }
                    }
                    view = item.updateView(view);
                    form.add(view);
                }
            }
            else {
                var views = form.subviews;
                for (i in 0...windowData.numItems) {
                    var item = windowItems.unsafeGet(i);
                    item.updateView(views[i]);
                }
            }
        }

        // Done with this window
        context.currentWindowData = null;

    }

    #end

/// Helpers

    inline public static function readInt(intPointer:IntPointer):Int {

        return intPointer();

    }

    inline public static function writeInt(intPointer:IntPointer, value:Int):Void {

        intPointer(value);

    }

    inline public static function readString(stringPointer:StringPointer):String {

        return stringPointer();

    }

    inline public static function writeString(stringPointer:StringPointer, value:String):Void {

        stringPointer(value);

    }

    macro public static function bool(value:ExprOf<Bool>):Expr {

        return macro function(?_val:Bool):Bool {
            return _val != null ? $value = _val : $value;
        };

    }

    macro public static function boolArray(value:ExprOf<Array<Bool>>):Expr {

        return macro $value;

    }

    macro public static function int(value:ExprOf<Int>):Expr {

        return macro function(?_val:Int):Int {
            return _val != null ? $value = _val : $value;
        };

    }

    macro public static function string(value:ExprOf<String>):Expr {

        return macro function(?_val:String):String {
            return _val != null ? $value = _val : $value;
        };

    }

    macro public static function intArray(value:ExprOf<Array<Int>>):Expr {

        return macro $value;

    }

    macro public static function float(value:ExprOf<Float>):Expr {

        return macro function(?_val:Float):Float {
            return _val != null ? $value = _val : $value;
        };

    }

    macro public static function floatArray(value:ExprOf<Array<Float>>):Expr {

        return macro $value;

    }

}
