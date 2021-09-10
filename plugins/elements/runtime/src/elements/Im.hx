package elements;

import ceramic.Color;
import ceramic.Flags;
import ceramic.IntBoolMap;
import ceramic.IntFloatMap;
import ceramic.IntIntMap;
import ceramic.IntMap;
import ceramic.TextAlign;

using ceramic.Extensions;

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


typedef IntPointer = (?val:Int)->Int;

/**
 * API inspired by Dear ImGui,
 * but using ceramic elements UI,
 * making it work with any ceramic target
 */
class Im {

    inline static final DEFAULT_LABEL_WIDTH:Float = -49965.0; // ViewSize.percent(35);

    inline static final DEFAULT_LABEL_POSITION:LabelPosition = RIGHT;

    inline static final DEFAULT_TEXT_ALIGN:TextAlign = LEFT;

    inline static final INT_MIN_VALUE:Int = -2147483647;

    inline static final INT_MAX_VALUE:Int = 2147483647;

    inline static final FLOAT_MIN_VALUE:Float = -2147483647;

    inline static final FLOAT_MAX_VALUE:Float = 2147483647;

    static var _labelWidth:Float = DEFAULT_LABEL_WIDTH;

    static var _labelPosition:LabelPosition = DEFAULT_LABEL_POSITION;

    static var _textAlign:TextAlign = DEFAULT_TEXT_ALIGN;

    static var _pointerBaseHandles:Map<String,Int> = new Map();

    static var _pointerHandles:Map<String,Int> = new Map();

    static var _pointerBaseHandleOccurences:Array<Int> = [];

    static var _nextPointerHandle:Int = 0;

    static var _boolPointerValues:IntBoolMap = new IntBoolMap();

    static var _intPointerValues:IntIntMap = new IntIntMap();

    static var _floatPointerValues:IntFloatMap = new IntFloatMap();

    static var _stringPointerValues:IntMap<String> = new IntMap<String>();

    #if !macro

    public static function extractId(key:String):String {

        return key; // TODO smarter

    }

    public static function extractTitle(key:String):String {

        return key; // TODO smarter

    }

    @:noCompletion public static function beginFrame():Void {

        for (i in 0..._pointerBaseHandleOccurences.length) {
            _pointerBaseHandleOccurences.unsafeSet(i, 0);
        }

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

    public static function begin(key:String, width:Float = WindowData.DEFAULT_WIDTH, height:Float = WindowData.DEFAULT_HEIGHT):Window {

        assert(context.currentWindowData == null, 'Duplicate begin() calls!');

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
        window.viewHeight = ViewSize.auto();
        window.title = title;

        // Mark window as used this frame
        windowData.used = true;
        windowData.width = width;
        windowData.height = height;

        // Make the window current
        context.currentWindowData = windowData;

        return window;

    }

    public static function labelPosition(labelPosition:LabelPosition = DEFAULT_LABEL_POSITION):Void {

        _labelPosition = labelPosition;

    }

    public static function labelWidth(labelWidth:Float = DEFAULT_LABEL_WIDTH):Void {

        _labelWidth = labelWidth;

    }

    public static function textAlign(textAlign:TextAlign = DEFAULT_TEXT_ALIGN):Void {

        _textAlign = textAlign;

    }

    public inline extern static overload function select(?title:String, value:StringPointer, list:Array<String>, labelPosition:LabelPosition = RIGHT, labelWidth:Float = DEFAULT_LABEL_WIDTH, ?nullValueText:String):Bool {

        var index:Int = list.indexOf(Im.readString(value));
        var changed = false;
        if (_select(title, Im.int(index), list, nullValueText)) {
            Im.writeString(value, list[index]);
            changed = true;
        }
        return changed;

    }

    public inline extern static overload function select(?title:String, value:IntPointer, list:Array<String>, ?nullValueText:String):Bool {

        return _select(title, value, list, nullValueText);

    }

    static function _select(?title:String, index:IntPointer, list:Array<String>, ?nullValueText:String):Bool {

        var windowData = context.currentWindowData;

        var item = WindowItem.get();
        item.kind = SELECT;
        item.int0 = Im.readInt(index);
        item.int1 = item.int0;
        item.labelPosition = _labelPosition;
        item.labelWidth = _labelWidth;
        item.string2 = title;
        item.stringArray0 = list;
        item.string1 = nullValueText;

        windowData.addItem(item);

        if (item.isSameItem(item.previous)) {
            // Did value changed from field last frame?
            var prevValue = item.previous.int0;
            var newValue = item.previous.int1;
            if (newValue != prevValue) {
                item.int0 = newValue;
                item.int1 = newValue;
                Im.writeInt(index, newValue);
                return true;
            }
        }

        return false;

    }

    public inline extern static overload function check(?title:String, value:BoolPointer):CheckStatus {

        return _check(title, value);

    }

    public static function _check(?title:String, value:BoolPointer):CheckStatus {

        var windowData = context.currentWindowData;

        var item = WindowItem.get();
        item.kind = CHECK;
        item.int0 = Im.readBool(value) ? 1 : 0;
        item.int1 = item.int0;
        item.labelPosition = _labelPosition;
        item.labelWidth = _labelWidth;
        item.string2 = title;

        windowData.addItem(item);

        var checked = (item.int0 != 0);
        var changed = false;

        if (item.isSameItem(item.previous)) {
            // Did value changed from field last frame?
            var prevValue = item.previous.int0;
            var newValue = item.previous.int1;
            if (newValue != prevValue) {
                changed = true;
                item.int0 = newValue;
                item.int1 = newValue;
                Im.writeBool(value, newValue != 0 ? true : false);
            }
        }

        return Flags.fromValues(checked, changed).toInt();

    }

    public static function editColor(?title:String, value:IntPointer):Bool {

        var windowData = context.currentWindowData;

        var item = WindowItem.get();
        item.kind = EDIT_COLOR;
        item.int0 = Im.readInt(value);
        item.int1 = item.int0;
        item.labelPosition = _labelPosition;
        item.labelWidth = _labelWidth;
        item.string2 = title;

        windowData.addItem(item);

        if (item.isSameItem(item.previous)) {
            // Did value changed from field last frame?
            var prevValue = item.previous.int0;
            var newValue = item.previous.int1;
            if (newValue != prevValue) {
                item.int0 = newValue;
                item.int1 = newValue;
                Im.writeInt(value, newValue);
                return true;
            }
        }

        return false;

    }

    public static function editText(?title:String, value:StringPointer, multiline:Bool = false, ?placeholder:String):Bool {

        var windowData = context.currentWindowData;

        var item = WindowItem.get();
        item.kind = EDIT_TEXT;
        item.string0 = Im.readString(value);
        if (item.string0 == null)
            item.string0 = '';
        item.string1 = item.string0;
        item.labelPosition = _labelPosition;
        item.labelWidth = _labelWidth;
        item.bool0 = multiline;
        item.string2 = title;
        item.string3 = placeholder;

        windowData.addItem(item);

        if (item.isSameItem(item.previous)) {
            // Did value changed from field last frame?
            var prevValue = item.previous.string0;
            var newValue = item.previous.string1;
            if (newValue != prevValue) {
                item.string0 = newValue;
                item.string1 = newValue;
                Im.writeString(value, newValue);
                return true;
            }
        }

        return false;

    }

    public static function editInt(
        #if completion
        ?title:String, value:IntPointer, ?minValue:Int, ?maxValue:Int
        #else
        ?title:String, value:IntPointer, minValue:Int = INT_MIN_VALUE, maxValue:Int = INT_MAX_VALUE
        #end
    ):Bool {

        var windowData = context.currentWindowData;

        var item = WindowItem.get();
        item.kind = EDIT_INT;
        item.int0 = Im.readInt(value);
        item.int1 = item.int0;
        item.float3 = minValue;
        item.float4 = maxValue;
        item.labelPosition = _labelPosition;
        item.labelWidth = _labelWidth;
        item.string2 = title;

        windowData.addItem(item);

        if (item.isSameItem(item.previous)) {
            // Did value changed from field last frame?
            var prevValue = item.previous.int0;
            var newValue = item.previous.int1;
            if (newValue != prevValue) {
                item.int0 = newValue;
                item.int1 = newValue;
                Im.writeInt(value, newValue);
                return true;
            }
        }

        return false;

    }

    public static function editFloat(
        #if completion
        ?title:String, value:FloatPointer, ?minValue:Float, ?maxValue:Float, ?decimals:Int
        #else
        ?title:String, value:FloatPointer, minValue:Float = FLOAT_MIN_VALUE, maxValue:Float = FLOAT_MAX_VALUE, decimals:Int = -1
        #end
    ):Bool {

        var windowData = context.currentWindowData;

        var item = WindowItem.get();
        item.kind = EDIT_FLOAT;
        item.float0 = Im.readFloat(value);
        item.float1 = item.float0;
        item.float3 = minValue;
        item.float4 = maxValue;
        item.int0 = decimals;
        item.labelPosition = _labelPosition;
        item.labelWidth = _labelWidth;
        item.string2 = title;

        windowData.addItem(item);

        if (item.isSameItem(item.previous)) {
            // Did value changed from field last frame?
            var prevValue = item.previous.float0;
            var newValue = item.previous.float1;
            if (newValue != prevValue) {
                item.float0 = newValue;
                item.float1 = newValue;
                Im.writeFloat(value, newValue);
                return true;
            }
        }

        return false;

    }

    public static function slideInt(
        ?title:String, value:IntPointer, minValue:Int, maxValue:Int
    ):Bool {

        var windowData = context.currentWindowData;

        var item = WindowItem.get();
        item.kind = SLIDE_INT;
        item.int0 = Im.readInt(value);
        item.int1 = item.int0;
        item.float3 = minValue;
        item.float4 = maxValue;
        item.labelPosition = _labelPosition;
        item.labelWidth = _labelWidth;
        item.string2 = title;

        windowData.addItem(item);

        if (item.isSameItem(item.previous)) {
            // Did value changed from field last frame?
            var prevValue = item.previous.int0;
            var newValue = item.previous.int1;
            if (newValue != prevValue) {
                item.int0 = newValue;
                item.int1 = newValue;
                Im.writeInt(value, newValue);
                return true;
            }
        }

        return false;

    }

    public static function slideFloat(
        ?title:String, value:FloatPointer, minValue:Float, maxValue:Float, decimals:Int = 3
    ):Bool {

        var windowData = context.currentWindowData;

        var item = WindowItem.get();
        item.kind = SLIDE_FLOAT;
        item.float0 = Im.readFloat(value);
        item.float1 = item.float0;
        item.float3 = minValue;
        item.float4 = maxValue;
        item.int0 = decimals;
        item.labelPosition = _labelPosition;
        item.labelWidth = _labelWidth;
        item.string2 = title;

        windowData.addItem(item);

        if (item.isSameItem(item.previous)) {
            // Did value changed from field last frame?
            var prevValue = item.previous.float0;
            var newValue = item.previous.float1;
            if (newValue != prevValue) {
                item.float0 = newValue;
                item.float1 = newValue;
                Im.writeFloat(value, newValue);
                return true;
            }
        }

        return false;

    }

    inline extern overload public static function button(title:String, enabled:Bool):Bool {

        return _button(title, enabled);

    }

    inline extern overload public static function button(title:String):Bool {

        return _button(title, true);

    }

    public static function _button(title:String, enabled:Bool):Bool {

        var windowData = context.currentWindowData;

        var item = WindowItem.get();
        item.kind = BUTTON;
        item.int0 = 0;
        item.int1 = 0;
        item.labelWidth = _labelWidth;
        item.string0 = title;
        item.bool0 = enabled;

        windowData.addItem(item);

        if (item.isSameItem(item.previous)) {
            var justClicked = (item.previous.int1 == 1);
            if (justClicked) {
                return true;
            }
        }

        return false;

    }

    public static function text(value:String, ?align:TextAlign):Void {

        var windowData = context.currentWindowData;

        var item = WindowItem.get();
        item.kind = TEXT;
        item.string0 = value;
        item.string1 = item.string0;
        item.int0 = switch align {
            case null: switch _textAlign {
                case LEFT: 0;
                case RIGHT: 1;
                case CENTER: 2;
            };
            case LEFT: 0;
            case RIGHT: 1;
            case CENTER: 2;
        };

        windowData.addItem(item);

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
                container.transparent = true;
                container.viewSize(ViewSize.auto(), ViewSize.auto());
                container.add(form);

                var overflowScroll = windowData.height != ViewSize.auto();
                if (overflowScroll) {
                    container.paddingRight = 12;
                    var scroll = new ScrollingLayout(container, true);
                    scroll.checkChildrenOfView = form;
                    var scrollbar = new Scrollbar();
                    scrollbar.inset(2, 1, 1, 2);
                    scroll.scroller.scrollbar = scrollbar;
                    scroll.transparent = true;
                    scroll.viewSize(ViewSize.fill(), 200);
                    window.contentView = scroll;
                }
                else {
                    window.contentView = container;
                }
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

                // Remove any unused view
                while (windowData.numItems < views.length) {
                    views.pop().destroy();
                }
            }
            else {
                var views = form.subviews;
                for (i in 0...windowData.numItems) {
                    var item = windowItems.unsafeGet(i);
                    item.updateView(views[i]);
                }

                // Remove any unused view
                if (views != null && windowData.numItems < views.length) {
                    var toRemove = [];
                    for (i in windowData.numItems...views.length) {
                        toRemove.push(views[i]);
                    }
                    for (view in toRemove) {
                        view.destroy();
                    }
                }
            }
        }

        // Done with this window
        context.currentWindowData = null;

    }

    #end

/// Helpers

    public static function handle(#if !completion ?pos:haxe.PosInfos #end):Handle {

        #if !completion
        if (pos != null) {

            // Retrieve base handle
            var baseKey = pos.fileName + ':' + pos.lineNumber;
            var baseHandle:Int;
            var occurence:Int;
            if (_pointerBaseHandles.exists(baseKey)) {
                baseHandle = _pointerBaseHandles.get(baseKey);
                occurence = _pointerBaseHandleOccurences.unsafeGet(baseHandle);
                var occurencePlus1 = occurence + 1;
                _pointerBaseHandleOccurences.unsafeSet(baseHandle, occurencePlus1);
            }
            else {
                baseHandle = _pointerBaseHandleOccurences.length;
                occurence = 1;
                _pointerBaseHandleOccurences.push(occurence);
                _pointerBaseHandles.set(baseKey, baseHandle);
            }

            var key = baseKey + ':' + occurence;
            var handle:Int;
            var baseHandle:Int;
            if (_pointerHandles.exists(key)) {
                handle = _pointerHandles.get(key);
            }
            else {
                handle = _nextPointerHandle++;
                _pointerHandles.set(key, handle);
            }

            return handle;

        }
        #end
        return -1;

    }

    @:noCompletion public static function setIntAtHandle(handle:Handle, value:Int):Int {

        _intPointerValues.set(handle, value);
        return value;

    }

    @:noCompletion public static function intAtHandle(handle:Handle):Int {

        return _intPointerValues.get(handle);

    }

    @:noCompletion public static function setColorAtHandle(handle:Handle, value:Color):Color {

        _intPointerValues.set(handle, value);
        return value;

    }

    @:noCompletion public static function colorAtHandle(handle:Handle):Color {

        return _intPointerValues.exists(handle) ? _intPointerValues.get(handle) : Color.WHITE;

    }

    @:noCompletion public static function setFloatAtHandle(handle:Handle, value:Float):Float {

        _floatPointerValues.set(handle, value);
        return value;

    }

    @:noCompletion public static function floatAtHandle(handle:Handle):Float {

        return _floatPointerValues.get(handle);

    }

    @:noCompletion public static function setBoolAtHandle(handle:Handle, value:Bool):Bool {

        _boolPointerValues.set(handle, value);
        return value;

    }

    @:noCompletion public static function boolAtHandle(handle:Handle):Bool {

        return _boolPointerValues.get(handle);

    }

    @:noCompletion public static function setStringAtHandle(handle:Handle, value:String):String {

        _stringPointerValues.set(handle, value);
        return value;

    }

    @:noCompletion public static function stringAtHandle(handle:Handle):String {

        return _stringPointerValues.get(handle);

    }

    inline public static function readInt(intPointer:IntPointer):Int {

        return intPointer();

    }

    inline public static function writeInt(intPointer:IntPointer, value:Int):Void {

        intPointer(value);

    }

    inline public static function readFloat(floatPointer:FloatPointer):Float {

        return floatPointer();

    }

    inline public static function writeFloat(floatPointer:FloatPointer, value:Float):Void {

        floatPointer(value);

    }

    inline public static function readString(stringPointer:StringPointer):String {

        return stringPointer();

    }

    inline public static function writeString(stringPointer:StringPointer, value:String):Void {

        stringPointer(value, value == null);

    }

    inline public static function readBool(boolPointer:BoolPointer):Bool {

        return boolPointer();

    }

    inline public static function writeBool(boolPointer:BoolPointer, value:Bool):Void {

        boolPointer(value);

    }

    macro public static function bool(?value:ExprOf<Bool>):Expr {

        return switch value.expr {
            case EConst(CIdent('null')):
                macro {
                    var handle = elements.Im.handle();
                    function(?_val:Bool):Bool {
                        return _val != null ? elements.Im.setBoolAtHandle(handle, _val) : elements.Im.boolAtHandle(handle);
                    };
                }
            case _:
                macro function(?_val:Bool):Bool {
                    return _val != null ? $value = _val : $value;
                };
        }

    }

    macro public static function int(?value:ExprOf<Int>):Expr {

        return switch value.expr {
            case EConst(CIdent('null')):
                macro {
                    var handle = elements.Im.handle();
                    function(?_val:Int):Int {
                        return _val != null ? elements.Im.setIntAtHandle(handle, _val) : elements.Im.intAtHandle(handle);
                    };
                }
            case _:
                macro function(?_val:Int):Int {
                    return _val != null ? $value = _val : $value;
                };
        }

    }

    macro public static function color(?value:ExprOf<ceramic.Color>):Expr {

        return switch value.expr {
            case EConst(CIdent('null')):
                macro {
                    var handle = elements.Im.handle();
                    function(?_val:Int):Int {
                        return _val != null ? elements.Im.setColorAtHandle(handle, _val) : elements.Im.colorAtHandle(handle);
                    };
                }
            case _:
                macro function(?_val:Int):Int {
                    return _val != null ? $value = _val : $value;
                };
        }

    }

    macro public static function string(?value:ExprOf<String>):Expr {

        return switch value.expr {
            case EConst(CIdent('null')):
                macro {
                    var handle = elements.Im.handle();
                    function(?_val:String, ?erase:Bool):String {
                        return _val != null || erase ? elements.Im.setStringAtHandle(handle, _val) : elements.Im.stringAtHandle(handle);
                    };
                }
            case _:
                macro function(?_val:String, ?erase:Bool):String {
                    return _val != null || erase ? $value = _val : $value;
                };
        }

    }

    macro public static function float(?value:ExprOf<Float>):Expr {

        return switch value.expr {
            case EConst(CIdent('null')):
                macro {
                    var handle = elements.Im.handle();
                    function(?_val:Float):Float {
                        return _val != null ? elements.Im.setFloatAtHandle(handle, _val) : elements.Im.floatAtHandle(handle);
                    };
                }
            case _:
                macro function(?_val:Float):Float {
                    return _val != null ? $value = _val : $value;
                };
        }

    }

}
