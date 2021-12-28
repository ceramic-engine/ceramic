package elements;

#if !macro
import ceramic.Assert.assert;
import ceramic.AssetId;
import ceramic.Click;
import ceramic.Color;
import ceramic.ColumnLayout;
import ceramic.Component;
import ceramic.DoubleClick;
import ceramic.EditText;
import ceramic.Entity;
import ceramic.Flags;
import ceramic.ImageAsset;
import ceramic.IntBoolMap;
import ceramic.IntFloatMap;
import ceramic.IntIntMap;
import ceramic.IntMap;
import ceramic.KeyBinding;
import ceramic.KeyCode;
import ceramic.LongPress;
import ceramic.Quad;
import ceramic.ReadOnlyArray;
import ceramic.ReadOnlyMap;
import ceramic.ScanCode;
import ceramic.Scroller;
import ceramic.SelectText;
import ceramic.Shortcuts.*;
import ceramic.TextAlign;
import ceramic.Texture;
import ceramic.TextureFilter;
import ceramic.TextureTile;
import ceramic.View;
import ceramic.ViewSize;
import ceramic.ViewSystem;
import ceramic.Visual;
import elements.Context.context;

using StringTools;
using ceramic.Extensions;

#if plugin_dialogs
import ceramic.DialogsFileFilter;
#end

#if plugin_spine
import ceramic.Spine;
import ceramic.SpineData;
#end

#end

#if macro
import haxe.io.Path;
import haxe.macro.Context;
import haxe.macro.Expr;
import sys.FileSystem;
import sys.io.File;
#end


typedef IntPointer = (?val:Int)->Int;

/**
 * API inspired by Dear ImGui,
 * but using ceramic elements UI,
 * making it work with any ceramic target
 */
class Im {

    #if !macro

    inline static final DESTROY_ASSET_AFTER_X_FRAMES:Int = 60;

    inline static final DEFAULT_SPACE_HEIGHT:Float = -60001.0; // ViewSize.auto();

    inline static final DEFAULT_LABEL_WIDTH:Float = -49965.0; // ViewSize.percent(35);

    inline static final DEFAULT_SEPARATOR_HEIGHT:Float = 7;

    inline static final DEFAULT_LABEL_POSITION:LabelPosition = RIGHT;

    inline static final DEFAULT_TEXT_ALIGN:TextAlign = LEFT;

    inline static final INT_MIN_VALUE:Int = -2147483647;

    inline static final INT_MAX_VALUE:Int = 2147483647;

    inline static final FLOAT_MIN_VALUE:Float = -2147483647;

    inline static final FLOAT_MAX_VALUE:Float = 2147483647;

    inline static final DIALOG_WIDTH:Float = 300;

    inline static final DIALOG_OVERFLOW_HEIGHT:Float = 400;

    public static var YES:String = 'Yes';

    public static var NO:String = 'No';

    public static var OK:String = 'OK';

    static var _beginFrameCallbacks:Array<Void->Void> = [];

    static var _orderedWindows:Array<Window> = [];

    static var _orderedWindowsIterated:Array<Window> = [];

    static var _currentWindowData:WindowData = null;

    static var _inRow:Bool = false;

    static var _currentRowIndex:Int = -1;

    static var _currentTabBarItem:WindowItem = null;

    static var _inTab:Bool = false;

    static var _currentTabIndex:Int = -1;

    static var _labelWidth:Float = DEFAULT_LABEL_WIDTH;

    static var _labelPosition:LabelPosition = DEFAULT_LABEL_POSITION;

    static var _textAlign:TextAlign = DEFAULT_TEXT_ALIGN;

    static var _fieldsDisabled:Bool = false;

    static var _flex:Int = 1;

    static var _pointerBaseHandles:Map<String,Int> = new Map();

    static var _pointerHandles:Map<String,Int> = new Map();

    static var _pointerBaseHandleOccurences:Array<Int> = [];

    static var _nextPointerHandle:Int = 0;

    static var _boolPointerValues:IntBoolMap = new IntBoolMap();

    static var _intPointerValues:IntIntMap = new IntIntMap();

    static var _floatPointerValues:IntFloatMap = new IntFloatMap();

    static var _stringPointerValues:IntMap<String> = new IntMap<String>();

    static var _arrayPointerValues:IntMap<Array<Dynamic>> = new IntMap<Array<Dynamic>>();

    static var _assetUses:Map<String,Int> = new Map();

    static var _pendingChoices:Array<PendingChoice> = [];

    static var _displayedPendingChoice:PendingChoice = null;

    static var _allowedOwners:Array<Entity> = [];

    public static function extractId(key:String):String {

        return key;

    }

    public static function extractTitle(key:String):String {

        return key;

    }

    @:noCompletion public static function beginFrame():Void {

        while (_beginFrameCallbacks.length > 0) {
            var cb = _beginFrameCallbacks.pop();
            cb();
        }

        for (i in 0..._pointerBaseHandleOccurences.length) {
            _pointerBaseHandleOccurences.unsafeSet(i, 0);
        }

        for (assetId => count in _assetUses) {
            if (count > 0) {
                _assetUses.set(assetId, 0);
            }
            else {
                count--;
                if (count < -DESTROY_ASSET_AFTER_X_FRAMES) {
                    _assetUses.remove(assetId);
                    var assets = context.assets;
                    var asset = assets.asset(assetId);
                    if (asset != null) {
                        asset.destroy();
                    }
                }
                else {
                    _assetUses.set(assetId, count);
                }
            }
        }

        for (id => windowData in context.windowsData) {
            windowData.beginFrame();
        }

    }

    static function updateWindowsDepth():Void {

        var len = _orderedWindows.length;
        for (i in 0...len) {
            _orderedWindowsIterated[i] = _orderedWindows.unsafeGet(i);
        }

        var hasWindowWithOverlay = false;
        for (i in 0...len) {
            var window = _orderedWindowsIterated.unsafeGet(i);
            if (window.overlay != null) {
                hasWindowWithOverlay = true;
                break;
            }
        }

        if (hasWindowWithOverlay) {
            for (i in 0...len-1) {
                var window = _orderedWindowsIterated.unsafeGet(i);
                _orderedWindowsIterated.unsafeSet(i, null);
                if (window.overlay != null && _orderedWindows[len-1].overlay == null) {
                    _orderedWindows.remove(window);
                    _orderedWindows.push(window);
                }
            }
        }
        else {
            for (i in 0...len-1) {
                var window = _orderedWindowsIterated.unsafeGet(i);
                _orderedWindowsIterated.unsafeSet(i, null);
                if (screen.focusedVisual != null && (screen.focusedVisual == window || screen.focusedVisual.hasIndirectParent(window))) {
                    _orderedWindows.remove(window);
                    _orderedWindows.push(window);
                }
            }
        }

        var d = 1;
        for (i in 0...len) {
            var window = _orderedWindows.unsafeGet(i);
            if (window.overlay != null) {
                window.overlay.depth = d++;
            }
            window.depth = d++;
        }

    }

    static function displayPendingChoiceIfNeeded():Void {

        if (_pendingChoices.length > 0) {

            var choice = null;
            for (i in 0..._pendingChoices.length) {
                var aChoice = _pendingChoices.unsafeGet(i);
                if (!aChoice.canceled && aChoice.chosenIndex == -1) {
                    choice = aChoice;
                    break;
                }
            }

            if (choice != null) {

                var needsFocusReset = (_displayedPendingChoice != choice);
                _displayedPendingChoice = choice;

                var clickedIndex = -1;
                var closed = false;

                var window = Im.begin(
                    'Im.pendingChoice',
                    choice.title, choice.width
                );
                Im.position(screen.nativeWidth * 0.5, screen.nativeHeight * 0.5, 0.5, 0.5);
                if (Im.overlay() && choice.cancelable) {
                    closed = true;
                }
                Im.expanded();
                Im.titleAlign(CENTER);

                if (choice.cancelable && Im.closable()) {
                    closed = true;
                }

                Im.textAlign(CENTER);
                Im.text(choice.message);

                if (choice.choices.length == 2) {
                    Im.beginRow();
                }

                for (i in 0...choice.choices.length) {
                    var item = choice.choices.unsafeGet(i);

                    if (Im.button(item)) {
                        clickedIndex = i;
                    }
                }

                if (choice.choices.length == 2) {
                    Im.endRow();
                }

                Im.end();

                if (clickedIndex != -1) {
                    choice.callback(clickedIndex, choice.choices[clickedIndex]);
                    choice.chosenIndex = clickedIndex;
                    if (choice.async) {
                        _pendingChoices.remove(choice);
                        choice.destroy();
                    }
                }
                else if (closed) {
                    choice.canceled = true;
                    if (choice.async) {
                        _pendingChoices.remove(choice);
                        choice.destroy();
                    }
                }
                else if (context.focusedWindow != window || needsFocusReset) {
                    screen.focusedVisual = window;
                }
            }

        }

    }

    @:noCompletion public static function endFrame():Void {

        displayPendingChoiceIfNeeded();

        updateWindowsDepth();

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

    public static function get(key:String):Window {

        var id = extractId(key);
        var windowData = context.windowsData.get(id);
        var window = windowData != null ? windowData.window : null;
        return window;

    }

    /**
     * Return `true` if any window is hitten given point.
     * @param x X position (logical screen metric)
     * @param y Y position (logical screen metric)
     * @return Bool
     */
    public static function hits(x:Float, y:Float):Bool {

        for (id => windowData in context.windowsData) {
            var window = windowData.window;
            if (window != null && window.hits(x, y)) {
                return true;
            }
        }

        var field = FieldSystem.shared.focusedField;
        if (field != null) {
            return field.hitsSelfOrDerived(x, y);
        }

        return false;

    }

    /**
     * Returns `true` if there is a currently focused field that uses the given scan code
     * @param scanCode The scan code to test
     * @return `true` if this scan code is used
     */
    public static function usesScanCode(scanCode:ScanCode):Bool {

        var field = FieldSystem.shared.focusedField;
        if (field != null) {
            return field.usesScanCode(scanCode);
        }

        return false;

    }

    /**
     * Returns `true` if there is a currently focused field that uses the given key code
     * @param keyCode The key code to test
     * @return `true` if this key code is used
     */
    public static function usesKeyCode(keyCode:KeyCode):Bool {

        var field = FieldSystem.shared.focusedField;
        if (field != null) {
            return field.usesKeyCode(keyCode);
        }

        return false;

    }

    public extern inline static overload function begin(key:String, title:String, width:Float = WindowData.DEFAULT_WIDTH, height:Float = WindowData.DEFAULT_HEIGHT):Window {

        return _begin(key, title, width, height);

    }

    public extern inline static overload function begin(key:String, width:Float = WindowData.DEFAULT_WIDTH, height:Float = WindowData.DEFAULT_HEIGHT):Window {

        return _begin(key, null, width, height);

    }

    static function _begin(key:String, title:String, width:Float = WindowData.DEFAULT_WIDTH, height:Float = WindowData.DEFAULT_HEIGHT):Window {

        assert(_currentWindowData == null, 'Duplicate begin() calls!');

        // Create view if needed
        var firstIteration = false;
        if (context.view == null) {
            firstIteration = true;
            ImSystem.shared.createView();
        }

        // Get or create window
        var id = extractId(key);
        var title = title != null ? title : extractTitle(key);
        var windowData = context.windowsData.get(id);
        var window = windowData != null ? windowData.window : null;

        if (windowData == null) {
            windowData = new WindowData();
            windowData.id = id;
            if (window != null) {
                windowData.x = window.x;
                windowData.y = window.y;
            }
            var anyWindowOverlap:Bool;
            do {
                anyWindowOverlap = false;
                for (otherWindowData in context.windowsData) {
                    if (windowData.y == otherWindowData.y) {
                        anyWindowOverlap = true;
                        windowData.y += 21;
                        windowData.x += 4;
                    }
                }
            }
            while (anyWindowOverlap);
            context.addWindowData(windowData);
        }

        if (window == null) {
            window = new Window();
            _orderedWindows.push(window);
            window.onDestroy(null, entity -> {
                var window:Window = cast entity;
                _orderedWindows.remove(window);
            });
            window.id = id;
            window.active = false;
            window.pos(windowData.x, windowData.y);
            window.viewHeight = ViewSize.auto();
            window.onHeaderDoubleClick(window, function() {
                if (windowData.collapsible)
                    windowData.expanded = !windowData.expanded;
            });
            window.onExpandCollapseClick(window, function() {
                if (windowData.collapsible)
                    windowData.expanded = !windowData.expanded;
            });
            window.onClose(window, function() {
                if (windowData.closable)
                    windowData.justClosed = true;
            });
            context.view.add(window);
            windowData.window = window;
            windowData.justClosed = false;
            _beginFrameCallbacks.push(function() {
                if (window != null && !window.destroyed) {
                    window.active = true;
                }
            });
        }

        if (window.x < 0)
            window.x = 0;
        if (window.x + window.width > context.view.width)
            window.x = context.view.width - window.width;
        if (window.y < 0)
            window.y = 0;
        if (window.y + Window.HEADER_HEIGHT > context.view.height)
            window.y = context.view.height - Window.HEADER_HEIGHT;

        windowData.x = window.x;
        windowData.y = window.y;

        window.viewWidth = width;
        window.viewHeight = ViewSize.auto();
        window.title = title;

        // Mark window as used this frame
        windowData.used = true;

        // Mark as non closable but value can be changed
        // until Im.end() is called
        windowData.closable = false;

        // Mark as movable but value can be changed
        // until Im.end() is called
        windowData.movable = true;

        // Mark as collapsible but value can be changed
        // until Im.end() is called
        windowData.collapsible = true;

        // Mark as titleAlign LEFT but value can be changed
        // until Im.end() is called
        windowData.titleAlign = LEFT;

        // Mark as no overlay but value can be changed
        // until Im.end() is called
        windowData.overlay = false;

        windowData.width = width;
        windowData.height = height;

        // No explicit target position (unless we call position() at this frame)
        windowData.targetX = -999999999;
        windowData.targetY = -999999999;
        windowData.targetAnchorX = -999999999;
        windowData.targetAnchorY = -999999999;

        // Make the window current
        _currentWindowData = windowData;

        return window;

    }

    public static function beginTabs(selected:StringPointer):Bool {

        assert(_currentTabBarItem == null, 'Called beginTabs() multiple times! (nested tabs are not supported)');

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.disabled = _fieldsDisabled;
        item.kind = TABS;
        item.string0 = Im.readString(selected);
        item.string1 = item.string0;
        item.stringArray0 = [];
        item.stringArray1 = [];
        item.any0 = selected;

        windowData.addItem(item);

        var selectedChanged = false;

        if (item.isSameItem(item.previous)) {
            // Did selected changed from list last frame?
            var prevSelected = item.previous.string0;
            var newSelected = item.previous.string1;
            if (newSelected != prevSelected) {
                selectedChanged = true;
                item.string0 = newSelected;
                item.string1 = newSelected;
                Im.writeString(selected, newSelected);
            }
        }

        _currentTabBarItem = item;
        _currentTabIndex = -1;
        _inTab = false;

        return selectedChanged;

    }

    public static function endTabs():Void {

        assert(_currentTabBarItem == null, 'beginTabs() must be called before endTabs()');

        // Ensure that selected value is valid.
        // If not, change it to first entry in array
        // var selectedValue = _currentTabBarItem.string0;
        // if (_currentTabBarItem.stringArray0.indexOf(selectedValue) == -1) {
        //     selectedValue = _currentTabBarItem.stringArray0[0];
        //     _currentTabBarItem.string1 = selectedValue;
        // }

        _inTab = false;
        _currentTabBarItem = null;

    }

    public static inline extern overload function tab(key:String):Bool {

        return _tab(key, null);

    }

    public static inline extern overload function tab(key:String, title:String):Bool {

        return _tab(key, title);

    }

    static function _tab(key:String, title:String):Bool {

        assert(_currentTabBarItem == null, 'Duplicate tab() calls!');

        // Get or create window
        var id = extractId(key);
        var title = title != null ? title : extractTitle(key);

        _currentTabBarItem.stringArray0.push(id);
        _currentTabBarItem.stringArray1.push(title);

        if (_currentTabBarItem.stringArray0.length == 1) {
            // First tab, set it default if there is no tab selected yet
            var selected:StringPointer = _currentTabBarItem.any0;
            var selectedValue = Im.readString(selected);
            if (selectedValue == null) {
                selectedValue = id;
                Im.writeString(selected, selectedValue);
                _currentTabBarItem.string0 = selectedValue;
                _currentTabBarItem.string1 = selectedValue;
            }
        }

        return id == _currentTabBarItem.string0;

    }

    public static function beginRow():Void {

        assert(_inRow == false, 'Called beginRow() multiple times! (nested rows are not supported)');

        _currentRowIndex++;
        _inRow = true;
        _flex = 1;

    }

    public static function endRow():Void {

        _inRow = false;

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

    public static function disabled(disabled:Bool):Void {

        _fieldsDisabled = disabled;

    }

    public static function flex(flex:Int):Void {

        _flex = flex;

    }

    public static function position(x:Float, y:Float, anchorX:Float = 0, anchorY:Float = 0):Void {

        var windowData = _currentWindowData;

        windowData.targetX = x;
        windowData.targetY = y;
        windowData.targetAnchorX = anchorX;
        windowData.targetAnchorY = anchorY;

        windowData.movable = false;

    }

    public static function expanded():Void {

        var windowData = _currentWindowData;

        windowData.collapsible = false;
        windowData.expanded = true;

    }

    public static function overlay():Bool {

        var windowData = _currentWindowData;

        windowData.overlay = true;

        if (windowData.overlayClicked) {
            windowData.overlayClicked = false;
            return true;
        }

        return false;

    }

    public static function titleAlign(titleAlign:TextAlign):Void {

        var windowData = _currentWindowData;

        windowData.titleAlign = titleAlign;

    }

    public static function closable(?isOpen:BoolPointer):Bool {

        var windowData = _currentWindowData;

        windowData.closable = true;

        if (windowData.justClosed) {
            windowData.justClosed = false;
            if (isOpen != null) {
                Im.writeBool(isOpen, false);
            }
            return true;
        }

        return false;

    }

    public static function list(height:Float, items:ArrayPointer, ?selected:IntPointer, sortable:Bool = false, lockable:Bool = false, trashable:Bool = false, duplicable:Bool = false):ListStatus {

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.flex = _flex;
        item.disabled = _fieldsDisabled;
        item.kind = LIST;
        item.int0 = Im.readInt(selected);
        item.int1 = item.int0;
        item.int2 = Flags.fromValues(sortable, lockable, trashable, duplicable).toInt();
        item.float0 = height;
        item.labelPosition = _labelPosition;
        item.labelWidth = _labelWidth;
        item.any0 = Im.readArray(items);
        item.any1 = item.any0;
        item.row = _inRow ? _currentRowIndex : -1;

        windowData.addItem(item);

        if (item.isSameItem(item.previous)) {
            // Did selected changed from list last frame?
            var prevSelected = item.previous.int0;
            var newSelected = item.previous.int1;
            var selectedChanged = false;
            if (newSelected != prevSelected) {
                selectedChanged = true;
                item.int0 = newSelected;
                item.int1 = newSelected;
                Im.writeInt(selected, newSelected);
            }
            // Did items changed from list last frame?
            var prevItems:Array<Dynamic> = item.previous.any0;
            var newItems:Array<Dynamic> = item.previous.any1;
            var itemsChanged = false;
            if (newItems != prevItems) {
                itemsChanged = true;
                item.any0 = newItems;
                item.any1 = newItems;
                Im.writeArray(items, newItems);
            }

            return new ListStatus(item.previous);
        }

        return new ListStatus(item);

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

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.flex = _flex;
        item.disabled = _fieldsDisabled;
        item.kind = SELECT;
        item.int0 = Im.readInt(index);
        item.int1 = item.int0;
        item.labelPosition = _labelPosition;
        item.labelWidth = _labelWidth;
        item.string2 = title;
        item.stringArray0 = list;
        item.string1 = nullValueText;
        item.row = _inRow ? _currentRowIndex : -1;

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

    public inline extern static overload function check(?title:String, value:BoolPointer, alignLabel:Bool = false):CheckStatus {

        return _check(title, value, alignLabel);

    }

    public static function _check(?title:String, value:BoolPointer, alignLabel:Bool):CheckStatus {

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.flex = _flex;
        item.disabled = _fieldsDisabled;
        item.kind = CHECK;
        item.int0 = Im.readBool(value) ? 1 : 0;
        item.int1 = item.int0;
        item.labelPosition = _labelPosition;
        item.labelWidth = alignLabel ? _labelWidth : ViewSize.fill();
        item.string2 = title;
        item.row = _inRow ? _currentRowIndex : -1;

        windowData.addItem(item);

        var checked = (item.int0 != 0);
        var changed = false;

        if (item.isSameItem(item.previous)) {
            // Did value changed from field last frame?
            var prevValue = item.previous.int0;
            var newValue = item.previous.int1;
            if (newValue != prevValue) {
                changed = true;
                checked = (newValue != 0);
                item.int0 = newValue;
                item.int1 = newValue;
                Im.writeBool(value, newValue != 0 ? true : false);
            }
        }

        return Flags.fromValues(checked, changed).toInt();

    }

    public static function editColor(?title:String, value:IntPointer):Bool {

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.flex = _flex;
        item.disabled = _fieldsDisabled;
        item.kind = EDIT_COLOR;
        item.int0 = Im.readInt(value);
        item.int1 = item.int0;
        item.labelPosition = _labelPosition;
        item.labelWidth = _labelWidth;
        item.string2 = title;
        item.row = _inRow ? _currentRowIndex : -1;

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

    public static function editText(?title:String, value:StringPointer, multiline:Bool = false, ?placeholder:String, ?autocompleteCandidates:Array<String>):Bool {

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.flex = _flex;
        item.disabled = _fieldsDisabled;
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
        item.stringArray0 = autocompleteCandidates;
        item.row = _inRow ? _currentRowIndex : -1;

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

    #if plugin_dialogs

    public static function editDir(?title:String, value:StringPointer, ?placeholder:String):Bool {

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.flex = _flex;
        item.disabled = _fieldsDisabled;
        item.kind = EDIT_DIR;
        item.string0 = Im.readString(value);
        if (item.string0 == null)
            item.string0 = '';
        item.string1 = item.string0;
        item.labelPosition = _labelPosition;
        item.labelWidth = _labelWidth;
        item.string2 = title;
        item.string3 = placeholder;
        item.row = _inRow ? _currentRowIndex : -1;

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

    public static function editFile(?title:String, value:StringPointer, ?placeholder:String, ?filters:DialogsFileFilter):Bool {

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.flex = _flex;
        item.disabled = _fieldsDisabled;
        item.kind = EDIT_FILE;
        item.string0 = Im.readString(value);
        if (item.string0 == null)
            item.string0 = '';
        item.string1 = item.string0;
        item.labelPosition = _labelPosition;
        item.labelWidth = _labelWidth;
        item.string2 = title;
        item.string3 = placeholder;
        item.any0 = filters;
        item.row = _inRow ? _currentRowIndex : -1;

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

    #end

    public static function editInt(
        #if completion
        ?title:String, value:IntPointer, ?placeholder:String, ?minValue:Int, ?maxValue:Int
        #else
        ?title:String, value:IntPointer, ?placeholder:String, minValue:Int = INT_MIN_VALUE, maxValue:Int = INT_MAX_VALUE
        #end
    ):Bool {

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.flex = _flex;
        item.disabled = _fieldsDisabled;
        item.kind = EDIT_INT;
        item.int0 = Im.readInt(value);
        item.int1 = item.int0;
        item.float3 = minValue;
        item.float4 = maxValue;
        item.labelPosition = _labelPosition;
        item.labelWidth = _labelWidth;
        item.string2 = title;
        item.string3 = placeholder;
        item.row = _inRow ? _currentRowIndex : -1;

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
        ?title:String, value:FloatPointer, ?placeholder:String, ?minValue:Float, ?maxValue:Float, ?round:Int
        #else
        ?title:String, value:FloatPointer, ?placeholder:String, minValue:Float = FLOAT_MIN_VALUE, maxValue:Float = FLOAT_MAX_VALUE, round:Int = 1000
        #end
    ):Bool {

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.flex = _flex;
        item.disabled = _fieldsDisabled;
        item.kind = EDIT_FLOAT;
        item.float0 = Im.readFloat(value);
        item.float1 = item.float0;
        item.float3 = minValue;
        item.float4 = maxValue;
        item.int0 = round;
        item.labelPosition = _labelPosition;
        item.labelWidth = _labelWidth;
        item.string2 = title;
        item.string3 = placeholder;
        item.row = _inRow ? _currentRowIndex : -1;

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

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.flex = _flex;
        item.disabled = _fieldsDisabled;
        item.kind = SLIDE_INT;
        item.int0 = Im.readInt(value);
        item.int1 = item.int0;
        item.float3 = minValue;
        item.float4 = maxValue;
        item.labelPosition = _labelPosition;
        item.labelWidth = _labelWidth;
        item.string2 = title;
        item.row = _inRow ? _currentRowIndex : -1;

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
        ?title:String, value:FloatPointer, minValue:Float, maxValue:Float, round:Int = 1000
    ):Bool {

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.flex = _flex;
        item.disabled = _fieldsDisabled;
        item.kind = SLIDE_FLOAT;
        item.float0 = Im.readFloat(value);
        item.float1 = item.float0;
        item.float3 = minValue;
        item.float4 = maxValue;
        item.int0 = round;
        item.labelPosition = _labelPosition;
        item.labelWidth = _labelWidth;
        item.string2 = title;
        item.row = _inRow ? _currentRowIndex : -1;

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

    public static function visual(?title:String, visual:Visual, scaleToFit:Bool = false, alignLabel:Bool = false, useFilter:Bool = true):Void {

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.flex = _flex;
        item.disabled = _fieldsDisabled;
        item.kind = VISUAL;
        item.bool0 = scaleToFit;
        item.bool1 = useFilter;
        item.int0 = 0; // 0 == unmanaged/custom visual
        item.visual = visual;
        item.string2 = title;
        item.labelPosition = _labelPosition;
        item.labelWidth = alignLabel ? _labelWidth : ViewSize.fill();
        item.row = _inRow ? _currentRowIndex : -1;

        windowData.addItem(item);

    }

    inline extern overload public static function image(?title:String, tile:TextureTile, scaleToFit:Bool = false, alignLabel:Bool = false, ?textureFilter:TextureFilter):Quad {

        return _imageWithTile(title, tile, scaleToFit, alignLabel, textureFilter);

    }

    static function _imageWithTile(title:String, tile:TextureTile, scaleToFit:Bool, alignLabel:Bool, textureFilter:TextureFilter):Quad {

        return _image(title, null, tile, -1, -1, -1, -1, scaleToFit, alignLabel, textureFilter);

    }

    inline extern overload public static function image(title:String, assetId:String, frameX:Float = -1, frameY:Float = -1, frameWidth:Float = -1, frameHeight:Float = -1, scaleToFit:Bool = false, alignLabel:Bool = false, ?textureFilter:TextureFilter):Quad {

        return _imageWithAsset(title, assetId, frameX, frameY, frameWidth, frameHeight, scaleToFit, alignLabel, textureFilter);

    }

    inline extern overload public static function image(assetId:String, frameX:Float = -1, frameY:Float = -1, frameWidth:Float = -1, frameHeight:Float = -1, scaleToFit:Bool = false, alignLabel:Bool = false, ?textureFilter:TextureFilter):Quad {

        return _imageWithAsset(null, assetId, frameX, frameY, frameWidth, frameHeight, scaleToFit, alignLabel, textureFilter);

    }

    static function _imageWithAsset(title:String, assetId:String, frameX:Float, frameY:Float, frameWidth:Float, frameHeight:Float, scaleToFit:Bool, alignLabel:Bool, textureFilter:TextureFilter):Quad {

        assert(assetId != null, 'assedId should not be null');

        if (!assetId.startsWith('image:')) {
            assetId = 'image:' + assetId;
        }

        var count:Int = 0;
        if (_assetUses.exists(assetId)) {
            count = _assetUses.get(assetId);
            if (count < 0)
                count = 0;
        }
        _assetUses.set(assetId, count + 1);

        var assets = context.assets;
        var texture = assets.texture(assetId);
        if (texture == null) {
            var imageAsset = assets.asset(assetId);
            if (imageAsset == null) {
                assets.addImage(assetId);
                assets.load();
            }
        }
        return _image(title, texture, null, frameX, frameY, frameWidth, frameHeight, scaleToFit, alignLabel, textureFilter);

    }

    inline extern overload public static function image(?title:String, texture:Texture, frameX:Float = -1, frameY:Float = -1, frameWidth:Float = -1, frameHeight:Float = -1, scaleToFit:Bool = false, alignLabel:Bool = false, ?textureFilter:TextureFilter):Quad {

        return _image(title, texture, null, frameX, frameY, frameWidth, frameHeight, scaleToFit, alignLabel, textureFilter);

    }

    static function _image(title:String, texture:Texture, tile:TextureTile, frameX:Float, frameY:Float, frameWidth:Float, frameHeight:Float, scaleToFit:Bool, alignLabel:Bool, textureFilter:TextureFilter):Quad {

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.flex = _flex;
        item.disabled = _fieldsDisabled;
        item.kind = VISUAL;
        item.bool0 = scaleToFit;
        item.int0 = 1; // 1 == image
        item.string2 = title;
        item.labelPosition = _labelPosition;
        item.labelWidth = alignLabel ? _labelWidth : ViewSize.fill();
        item.row = _inRow ? _currentRowIndex : -1;

        windowData.addItem(item);

        var visual:Quad = null;
        if (item.previous != null && item.int0 == item.previous.int0) {
            // Can reuse visual
            visual = cast item.previous.visual;
        }
        if (visual == null && @:privateAccess windowData.unobservedExpanded) {
            visual = new Quad();
            visual.active = false;
        }
        if (visual != null) {
            if (tile != null) {
                visual.tile = tile;
                if (textureFilter != null) {
                    tile.texture.filter = textureFilter;
                }
            }
            else {
                visual.texture = texture;
                if (texture != null && textureFilter != null) {
                    texture.filter = textureFilter;
                }
                if (texture == null) {
                    visual.size(0, 0);
                }
                else if (frameX >= 0 && frameY >= 0 && frameWidth >= 0 && frameHeight >= 0) {
                    var textureW = texture.width;
                    var textureH = texture.height;
                    visual.frame(
                        Math.round(frameX * textureW),
                        Math.round(frameY * textureH),
                        Math.round(frameWidth * textureW),
                        Math.round(frameHeight * textureH)
                    );
                }
            }
        }
        item.visual = visual;

        return visual;

    }

    @:noCompletion public static function debugVisual(?title:String, scaleToFit:Bool = false, alignLabel:Bool = false):Quad {

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.flex = _flex;
        item.disabled = _fieldsDisabled;
        item.kind = VISUAL;
        item.bool0 = scaleToFit;
        item.int0 = 1000; // 1000 == debugVisual
        item.string2 = title;
        item.labelPosition = _labelPosition;
        item.labelWidth = alignLabel ? _labelWidth : ViewSize.fill();
        item.row = _inRow ? _currentRowIndex : -1;

        windowData.addItem(item);

        var visual:Quad = null;
        if (item.previous != null && item.int0 == item.previous.int0) {
            // Can reuse visual
            visual = cast item.previous.visual;
        }
        if (visual == null && @:privateAccess windowData.unobservedExpanded) {
            visual = new Quad();
            visual.color = Color.LIME;
            visual.size(
                20 + Math.round(Math.random() * 600),
                20 + Math.round(Math.random() * 600)
            );
        }
        if (visual != null) {
            if (app.frame % 60 == 0) {
                visual.size(
                    20 + Math.round(Math.random() * 600),
                    20 + Math.round(Math.random() * 600)
                );
            }
        }
        item.visual = visual;

        return visual;

    }

    #if plugin_spine

    inline extern overload public static function spine(?title:String, spineData:SpineData, ?animation:String, ?skin:String, time:Float = -1, scaleToFit:Bool = false, alignLabel:Bool = false):Spine {

        return _spine(title, spineData, animation, skin, time, scaleToFit, alignLabel);

    }

    static function _spine(title:String, spineData:SpineData, animation:String, skin:String, time:Float, scaleToFit:Bool, alignLabel:Bool):Spine {

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.flex = _flex;
        item.disabled = _fieldsDisabled;
        item.kind = VISUAL;
        item.bool0 = scaleToFit;
        item.bool1 = true; // use filter (render to texture)
        item.int0 = 100; // 100 == spine
        item.string2 = title;
        item.labelPosition = _labelPosition;
        item.labelWidth = alignLabel ? _labelWidth : ViewSize.fill();
        item.row = _inRow ? _currentRowIndex : -1;

        windowData.addItem(item);

        var visual:Spine = null;
        if (item.previous != null && item.int0 == item.previous.int0) {
            // Can reuse visual
            visual = cast item.previous.visual;
        }
        if ((visual == null && @:privateAccess windowData.unobservedExpanded)) {
            visual = new Spine();
            visual.skeletonScale = 0.1;
            visual.active = false;
            visual.anchor(0.5, 0.5);
        }
        if (visual != null) {
            if (time >= 0) {
                visual.paused = true;
            }
            var state = visual.state;
            var track = state != null ? visual.state.tracks[0] : null;
            var trackAnim = track != null ? track.animation : null;
            var currentAnimationName = trackAnim != null ? trackAnim.name : null;
            if (visual.spineData != spineData || visual.skin != skin || currentAnimationName != animation) {
                if (visual.parent != null) {
                    visual.parent.remove(visual);
                }
                visual.spineData = spineData;
                visual.skin = skin;
                visual.scale(1, 1);
                visual.skew(0, 0);
                visual.anchor(0, 0);
                visual.size(0, 0);
                visual.pos(0, 0);
                visual.rotation = 0;
                visual.skeletonScale = 1;
                visual.skeletonOriginX = 0.5;
                visual.skeletonOriginY = 0.5;
                if (spineData != null) {
                    visual.animate(animation, true, 0, 0);
                }
                visual.forceRender();
                visual.computeBounds();
                if (spineData != null) {
                    visual.animate(animation, true, 0, Math.max(time, 0));
                }
                visual.forceRender();
                visual.anchor(0.5, 0.5);
            }
            else {
                if (time >= 0) {
                    var prevTime:Float = -1;
                    if (track != null) {
                        prevTime = track.trackTime;
                    }
                    if (spineData != null && time != prevTime) {
                        visual.animate(animation, true, 0, time);
                    }
                }
            }
        }
        item.visual = visual;

        return visual;

    }

    #end

    public static function space(height:Float = DEFAULT_SPACE_HEIGHT):Void {

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.flex = _flex;
        item.kind = SPACE;
        item.float0 = height;
        item.row = _inRow ? _currentRowIndex : -1;

        windowData.addItem(item);

    }

    public static function separator(height:Float = DEFAULT_SEPARATOR_HEIGHT):Void {

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.flex = _flex;
        item.kind = SEPARATOR;
        item.float0 = height;
        item.row = _inRow ? _currentRowIndex : -1;

        windowData.addItem(item);

    }

    inline extern overload public static function button(title:String, enabled:Bool):Bool {

        return _button(title, enabled);

    }

    inline extern overload public static function button(title:String):Bool {

        return _button(title, true);

    }

    public static function _button(title:String, enabled:Bool):Bool {

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.flex = _flex;
        item.disabled = _fieldsDisabled;
        item.kind = BUTTON;
        item.int0 = 0;
        item.int1 = 0;
        item.labelWidth = _labelWidth;
        item.string0 = title;
        item.bool0 = enabled;
        item.row = _inRow ? _currentRowIndex : -1;

        windowData.addItem(item);

        if (enabled && item.isSameItem(item.previous)) {
            var justClicked = (item.previous.int1 == 1);
            if (justClicked) {
                return true;
            }
        }

        return false;

    }

    public static function text(value:String, ?align:TextAlign):Void {

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.flex = _flex;
        item.disabled = _fieldsDisabled;
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
        item.row = _inRow ? _currentRowIndex : -1;

        windowData.addItem(item);

    }

    public static function end():Void {

        assert(_currentWindowData != null, 'Called end() without calling begin() before!');

        // Sync window items
        var windowData = _currentWindowData;
        var window = windowData != null ? windowData.window : null;
        var windowItems = windowData != null ? windowData.items : null;

        if (window == null || !window.active) {
            if (windowItems != null) {
                for (i in 0...windowData.numItems) {
                    var item = windowItems.unsafeGet(i);
                    if (item.visual != null) {
                        if (item.visual.parent != null)
                            item.visual.parent.remove(item.visual);
                        if (window == null && item.hasManagedVisual()) {
                            // Managed visual, destroy it
                            item.visual.destroy();
                            item.visual = null;
                        }
                        else {
                            item.visual.active = false;
                        }
                    }
                }
            }
        }
        else {
            window.closable = windowData.closable;
            window.movable = windowData.movable;
            window.collapsible = windowData.collapsible;
            window.titleAlign = windowData.titleAlign;

            if (!windowData.expanded) {
                var prevContentView = window.contentView;
                if (prevContentView != null) {
                    window.contentView = null;
                    prevContentView.destroy();
                    windowData.form = null;
                }
                if (windowItems != null) {
                    for (i in 0...windowData.numItems) {
                        var item = windowItems.unsafeGet(i);
                        if (item.visual != null) {
                            if (item.visual.parent != null)
                                item.visual.parent.remove(item.visual);
                            if (item.hasManagedVisual()) {
                                // Managed visual, destroy it
                                item.visual.destroy();
                                item.visual = null;
                            }
                            else {
                                item.visual.active = false;
                            }
                        }
                    }
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
                        scroll.viewSize(ViewSize.fill(), windowData.height);
                        window.contentView = scroll;
                    }
                    else {
                        window.contentView = container;
                    }
                }

                if (form != null) {
                    form.tabFocus.focusRoot = window;
                }

                var windowItems = windowData.items;
                if (!needsContentRebuild) {
                    for (i in 0...windowData.numItems) {
                        var item = windowItems.unsafeGet(i);
                        if (item.previous == null || !item.isSameItem(item.previous)) {
                            needsContentRebuild = true;
                            break;
                        }
                    }
                }

                if (!needsContentRebuild) {
                    var prevNumItems = 0;
                    var subviews = form.subviews;
                    for (i in 0...subviews.length) {
                        var view = subviews.unsafeGet(i);
                        if (view is ImRowLayout) {
                            var rowLayout:ImRowLayout = cast view;
                            var subviews = rowLayout.subviews;
                            if (subviews != null) {
                                for (j in 0...subviews.length) {
                                    prevNumItems++;
                                }
                            }
                        }
                        else {
                            prevNumItems++;
                        }
                    }
                    if (prevNumItems != windowData.numItems) {
                        needsContentRebuild = true;
                    }
                }

                if (needsContentRebuild) {
                    var viewsWithRows = form.subviews != null ? [].concat(form.subviews.original) : [];
                    var views = [];
                    var rowLayouts = [];
                    var lastRowIndex = -1;
                    for (i in 0...viewsWithRows.length) {
                        var view = viewsWithRows.unsafeGet(i);
                        if (view is ImRowLayout) {
                            var rowLayout:ImRowLayout = cast view;
                            var subviews = rowLayout.subviews;
                            if (subviews != null) {
                                for (j in 0...subviews.length) {
                                    views.push(subviews.unsafeGet(j));
                                }
                            }
                            rowLayout.removeAllViews();
                            rowLayouts.push(rowLayout);
                        }
                        else {
                            views.push(view);
                        }
                    }
                    form.removeAllViews();

                    for (i in 0...windowData.numItems) {
                        var item = windowItems.unsafeGet(i);
                        var view = views[i];
                        var reuseView = (item.previous != null && item.isSameItem(item.previous));
                        if (view == null || !reuseView) {
                            if (view != null) {
                                if (view is VisualContainerView) {
                                    var containerView:VisualContainerView = cast view;
                                    containerView.visual = null;
                                }
                                view.destroy();
                                view = null;
                            }
                        }
                        view = item.updateView(view);

                        var rowLayout:ImRowLayout = null;
                        if (item.row >= 0) {
                            if (lastRowIndex < item.row) {
                                lastRowIndex++;
                                rowLayout = rowLayouts[lastRowIndex];
                                if (rowLayout == null) {
                                    rowLayout = new ImRowLayout();
                                    rowLayouts[lastRowIndex] = rowLayout;
                                    rowLayout.viewSize(ViewSize.fill(), ViewSize.auto());
                                }
                                form.add(rowLayout);
                            }
                            else {
                                rowLayout = rowLayouts[item.row];
                            }
                        }

                        if (rowLayout != null) {
                            rowLayout.add(view);
                        }
                        else {
                            form.add(view);
                        }
                    }

                    // Remove any unused view
                    while (windowData.numItems < views.length) {
                        views.pop().destroy();
                    }

                    // Remove any unused row layout
                    while (lastRowIndex + 1 < rowLayouts.length) {
                        rowLayouts.pop().destroy();
                    }
                }
                else {
                    var views = form.subviews;
                    var n = 0;
                    var i = 0;
                    while (i < windowData.numItems) {
                        var view = views[n];
                        if (view is ImRowLayout) {
                            var rowLayout:ImRowLayout = cast view;
                            var subviews = rowLayout.subviews;
                            if (subviews != null) {
                                for (j in 0...subviews.length) {
                                    var view = subviews.unsafeGet(j);
                                    var item = windowItems.unsafeGet(i);
                                    item.updateView(view);
                                    i++;
                                }
                            }
                        }
                        else {
                            var item = windowItems.unsafeGet(i);
                            item.updateView(view);
                            i++;
                        }
                        n++;
                    }
                }
            }

            // Overlay
            if (windowData.overlay) {
                if (window.overlay == null) {
                    window.overlay = new Quad();
                    window.overlay.onPointerDown(null, _ -> {
                        windowData.overlayClicked = true;
                    });
                    context.view.add(window.overlay);
                }
                window.overlay.color = context.theme.overlayBackgroundColor;
                window.overlay.alpha = context.theme.overlayBackgroundAlpha;
                window.overlay.pos(0, 0);
                window.overlay.size(screen.nativeWidth, screen.nativeHeight);
            }
            else {
                windowData.overlayClicked = false;
                if (window.overlay != null) {
                    window.overlay.destroy();
                    window.overlay = null;
                }
            }

            if (windowData.targetX != -999999999) {
                // We update window after we are sure its content layout is done
                ViewSystem.shared.onceEndLateUpdate(window, function(delta) {
                    windowData.x = windowData.targetX - windowData.targetAnchorX * window.width;
                    windowData.y = windowData.targetY - windowData.targetAnchorY * window.height;
                    window.x = windowData.x;
                    window.y = windowData.y;
                });
            }
        }

        // Done with this window
        _currentWindowData = null;
        _currentRowIndex = -1;
        _inRow = false;
        _currentTabIndex = -1;
        _inTab = false;

    }

/// Focused?

    inline public static function focusedWindow():Window {

        return Context.context.focusedWindow;

    }

/// Filter event owners

    public static function allow(owner:Entity):Void {

        if (_allowedOwners.indexOf(owner) == -1) {
            _allowedOwners.push(owner);
            owner.onDestroy(null, _allowedOwnerDestroyed);
        }

    }

    public static function filter(owner:Entity):Void {

        if (_allowedOwners.indexOf(owner) != -1) {
            _allowedOwners.remove(owner);
            if (!owner.destroyed) {
                owner.offDestroy(_allowedOwnerDestroyed);
            }
        }

    }

    static function _allowedOwnerDestroyed(owner:Entity) {

        _allowedOwners.remove(owner);

    }

    @:noCompletion inline public static function filterEventOwner(owner:Entity):Bool {

        // When a window is focused, block any event emit that are not related to elements UI

        var allow = false;
        var window = Context.context.focusedWindow;
        if (window != null) {
            if (owner != null) {
                allow = _filterEventOwner(owner);
            }
        }
        else {
            allow = true;
        }
        return allow;

    }

    static function _filterEventOwner(owner:Entity):Bool {

        var view = Context.context.view;
        if (view == owner) {
            return true;
        }

        if (owner is Visual) {
            var visual:Visual = cast owner;
            if (visual.hasIndirectParent(view)) {
                return true;
            }
        }

        if (owner is Scroller) {
            var scroller:Scroller = cast owner;
            if (scroller.content != null && (scroller.content == view || scroller.content.hasIndirectParent(view))) {
                return true;
            }
        }

        if (owner is Component) {
            var component:Component = cast owner;
            var entity = @:privateAccess component.getEntity();
            if (entity is Visual) {
                var visual:Visual = cast entity;
                if (visual.hasIndirectParent(view)) {
                    return true;
                }
            }
        }

        if (owner is KeyBinding) {
            var keyBinding:KeyBinding = cast owner;
            var bindings = keyBinding.bindings;
            if (bindings != null) {
                var entity = @:privateAccess bindings.getEntity();
                if (entity is Visual) {
                    var visual:Visual = cast entity;
                    if (visual.hasIndirectParent(view)) {
                        return true;
                    }
                }
            }
        }

        if (_allowedOwners.indexOf(owner) != -1) {
            return true;
        }

        var className = Type.getClassName(Type.getClass(owner));
        if (className.startsWith('elements.')) {
            return true;
        }

        return false;

    }

/// Confirm / Alert / Choice dialogs

    public extern inline static overload function confirm(
        title:String,
        message:String,
        cancelable:Bool = true,
        ?yes:String, ?no:String,
        width:Float = DIALOG_WIDTH,
        height:Float = WindowData.DEFAULT_HEIGHT,
        ?key:String):ConfirmStatus {

        return _confirm(
            key != null ? key : title,
            title,
            message,
            cancelable,
            yes, no,
            width, height,
            false, null
        );

    }

    public extern inline static overload function confirm(
        title:String,
        message:String,
        cancelable:Bool = false,
        ?yes:String, ?no:String,
        width:Float = DIALOG_WIDTH,
        height:Float = WindowData.DEFAULT_HEIGHT,
        callback:(confirmed:Bool)->Void) {

        _confirm(
            null,
            title,
            message,
            cancelable,
            yes, no,
            width, height,
            true, callback
        );

    }

    public extern inline static overload function confirm(
        title:String,
        message:String,
        cancelable:Bool = true,
        ?yes:String, ?no:String,
        width:Float = DIALOG_WIDTH,
        height:Float = WindowData.DEFAULT_HEIGHT,
        callback:()->Void) {

        _confirm(
            null,
            title,
            message,
            cancelable,
            yes, no,
            width, height,
            true, confirmed -> {
                if (confirmed) {
                    callback();
                }
            }
        );

    }

    public static function _confirm(
        key:String,
        title:String,
        message:String,
        cancelable:Bool = false,
        ?yes:String, ?no:String,
        width:Float = DIALOG_WIDTH,
        height:Float = WindowData.DEFAULT_HEIGHT,
        async:Bool, callback:(confirmed:Bool)->Void):ConfirmStatus {

        if (yes == null)
            yes = YES;

        if (no == null)
            no = NO;

        var choice:PendingChoice = null;

        if (key != null) {
            key = extractId(key);
            for (i in 0..._pendingChoices.length) {
                var existing = _pendingChoices.unsafeGet(i);
                if (existing.key == key) {
                    choice = existing;
                    break;
                }
            }
        }

        if (choice == null) {
            choice = new PendingChoice(
                key, title, message, [yes, no], cancelable, width, height, async, function(index, text) {
                    if (choice.chosenIndex != -1 || choice.canceled)
                        return;

                    choice.chosenIndex = index;
                    if (callback != null) {
                        var cb = callback;
                        callback = null;
                        cb(index == 0);
                    }
                }
            );

            input.onKeyDown(choice, function(key) {
                if (choice.chosenIndex != -1 || choice.canceled)
                    return;

                if (choice.cancelable && key.scanCode == ESCAPE) {

                    choice.canceled = true;
                    if (callback != null) {
                        var cb = callback;
                        callback = null;
                        cb(false);
                    }

                    if (choice.async) {
                        _pendingChoices.remove(choice);
                        choice.destroy();
                    }
                }
            });

            _pendingChoices.push(choice);
        }
        else {
            choice.title = title;
            choice.message = message;
            choice.choices[0] = yes;
            choice.choices[1] = no;
            choice.cancelable = cancelable;
            choice.width = width;
            choice.height = height;
        }

        var status = new ConfirmStatus(
            choice.canceled ? -2 : choice.chosenIndex
        );

        if (!choice.async && status.complete) {
            _pendingChoices.remove(choice);
            choice.destroy();
        }

        return status;

    }

    public extern inline static overload function info(
        title:String,
        message:String,
        cancelable:Bool = false,
        ?ok:String,
        width:Float = DIALOG_WIDTH,
        height:Float = WindowData.DEFAULT_HEIGHT,
        ?key:String):InfoStatus {

        return _info(
            key != null ? key : title,
            title,
            message,
            cancelable,
            ok,
            width,
            height,
            false,
            null
        );

    }

    public extern inline static overload function info(
        title:String,
        message:String,
        cancelable:Bool = false,
        ?ok:String,
        width:Float = DIALOG_WIDTH,
        height:Float = WindowData.DEFAULT_HEIGHT,
        callback:()->Void) {

        _info(
            null,
            title,
            message,
            cancelable,
            ok,
            width,
            height,
            true,
            callback
        );

    }

    static function _info(
        key:String,
        title:String,
        message:String,
        cancelable:Bool = false,
        ?ok:String,
        width:Float = DIALOG_WIDTH,
        height:Float = WindowData.DEFAULT_HEIGHT,
        async:Bool, callback:()->Void):InfoStatus {

        if (ok == null)
            ok = OK;

        var choice:PendingChoice = null;

        if (key != null) {
            key = extractId(key);
            for (i in 0..._pendingChoices.length) {
                var existing = _pendingChoices.unsafeGet(i);
                if (existing.key == key) {
                    choice = existing;
                    break;
                }
            }
        }

        if (choice == null) {
            choice = new PendingChoice(
                key, title, message, [ok], cancelable, width, height, async, function(index, text) {
                    if (choice.chosenIndex != -1 || choice.canceled)
                        return;

                    choice.chosenIndex = index;
                    if (callback != null) {
                        var cb = callback;
                        callback = null;
                        cb();
                    }
                }
            );

            input.onKeyDown(choice, function(key) {
                if (choice.chosenIndex != -1 || choice.canceled)
                    return;

                if (choice.cancelable && key.scanCode == ESCAPE) {

                    choice.canceled = true;
                    callback = null;

                    if (choice.async) {
                        _pendingChoices.remove(choice);
                        choice.destroy();
                    }
                }
            });

            _pendingChoices.push(choice);
        }
        else {
            choice.title = title;
            choice.message = message;
            choice.choices[0] = ok;
            choice.cancelable = cancelable;
            choice.width = width;
            choice.height = height;
        }

        var status = new InfoStatus(
            choice.canceled ? -2 : choice.chosenIndex
        );

        if (!choice.async && status.complete) {
            _pendingChoices.remove(choice);
            choice.destroy();
        }

        return status;

    }

    public extern inline static overload function choice(
        title:String,
        message:String,
        cancelable:Bool = false,
        choices:Array<String>,
        width:Float = DIALOG_WIDTH,
        height:Float = WindowData.DEFAULT_HEIGHT,
        ?key:String):ChoiceStatus {

        return _choice(
            key != null ? key : title,
            title,
            message,
            cancelable,
            choices,
            width,
            height,
            false,
            null
        );

    }

    public extern inline static overload function choice(
        title:String,
        message:String,
        cancelable:Bool = false,
        choices:Array<String>,
        width:Float = DIALOG_WIDTH,
        height:Float = WindowData.DEFAULT_HEIGHT,
        callback:(index:Int, text:String)->Void) {

        _choice(
            null,
            title,
            message,
            cancelable,
            choices,
            width,
            height,
            true,
            callback
        );

    }

    static function _choice(
        key:String,
        title:String,
        message:String,
        cancelable:Bool = false,
        choices:Array<String>,
        width:Float = DIALOG_WIDTH,
        height:Float = WindowData.DEFAULT_HEIGHT,
        async:Bool, callback:(index:Int, text:String)->Void):ChoiceStatus {

        if (height == WindowData.DEFAULT_HEIGHT && choices.length >= 8) {
            height = DIALOG_OVERFLOW_HEIGHT;
        }

        var choice:PendingChoice = null;

        if (key != null) {
            key = extractId(key);
            for (i in 0..._pendingChoices.length) {
                var existing = _pendingChoices.unsafeGet(i);
                if (existing.key == key) {
                    choice = existing;
                    break;
                }
            }
        }

        if (choice == null) {
            choice = new PendingChoice(
                key, title, message, async ? [].concat(choices) : choices, cancelable, width, height, async, function(index, text) {
                    if (choice.chosenIndex != -1 || choice.canceled)
                        return;

                    choice.chosenIndex = index;
                    if (callback != null) {
                        var cb = callback;
                        callback = null;
                        cb(index, text);
                    }
                }
            );

            input.onKeyDown(choice, function(key) {
                if (choice.chosenIndex != -1 || choice.canceled)
                    return;

                if (choice.cancelable && key.scanCode == ESCAPE) {

                    choice.canceled = true;
                    callback = null;

                    if (choice.async) {
                        _pendingChoices.remove(choice);
                        choice.destroy();
                    }
                }
            });

            _pendingChoices.push(choice);
        }
        else {
            choice.title = title;
            choice.message = message;
            choice.choices = choices;
            choice.cancelable = cancelable;
            choice.width = width;
            choice.height = height;
        }

        var status = new ChoiceStatus(
            choice.canceled ? -2 : choice.chosenIndex
        );

        if (!choice.async && status.complete) {
            _pendingChoices.remove(choice);
            choice.destroy();
        }

        return status;

    }

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

    @:noCompletion public static function setArrayAtHandle(handle:Handle, value:Array<Dynamic>):Array<Dynamic> {

        _arrayPointerValues.set(handle, value);
        return value;

    }

    @:noCompletion public static function arrayAtHandle(handle:Handle):Array<Dynamic> {

        return _arrayPointerValues.get(handle);

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

    inline public static function readArray(arrayPointer:ArrayPointer):Array<Dynamic> {

        return arrayPointer();

    }

    inline public static function writeArray(arrayPointer:ArrayPointer, value:Array<Dynamic>):Void {

        arrayPointer(value, value == null);

    }

    inline public static function readBool(boolPointer:BoolPointer):Bool {

        return boolPointer();

    }

    inline public static function writeBool(boolPointer:BoolPointer, value:Bool):Void {

        boolPointer(value);

    }

    #end

    macro public static function bool(?value:ExprOf<Bool>):Expr {

        if (Context.defined('cs')) {
            // C# target and its quirks...
            return switch value.expr {
                case EConst(CIdent('null')):
                    var pos = Context.getPosInfos(Context.currentPos());
                    var posInfos = _posInfosFromFileAndChar(pos.file, pos.min);
                    macro {
                        var handle = elements.Im.handle($v{posInfos});
                        function(?_val:Dynamic):Bool {
                            return _val != null ? elements.Im.setBoolAtHandle(handle, _val) : elements.Im.boolAtHandle(handle);
                        };
                    }
                case _:
                    macro function(?_val:Dynamic):Bool {
                        return _val != null ? $value = _val : $value;
                    };
            }
        }
        else {
            return switch value.expr {
                case EConst(CIdent('null')):
                    var pos = Context.getPosInfos(Context.currentPos());
                    var posInfos = _posInfosFromFileAndChar(pos.file, pos.min);
                    macro {
                        var handle = elements.Im.handle($v{posInfos});
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

    }

    macro public static function int(?value:ExprOf<Int>):Expr {

        return switch value.expr {
            case EConst(CIdent('null')):
                var pos = Context.getPosInfos(Context.currentPos());
                var posInfos = _posInfosFromFileAndChar(pos.file, pos.min);
                macro {
                    var handle = elements.Im.handle($v{posInfos});
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
                var pos = Context.getPosInfos(Context.currentPos());
                var posInfos = _posInfosFromFileAndChar(pos.file, pos.min);
                macro {
                    var handle = elements.Im.handle($v{posInfos});
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
                var pos = Context.getPosInfos(Context.currentPos());
                var posInfos = _posInfosFromFileAndChar(pos.file, pos.min);
                macro {
                    var handle = elements.Im.handle($v{posInfos});
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
                var pos = Context.getPosInfos(Context.currentPos());
                var posInfos = _posInfosFromFileAndChar(pos.file, pos.min);
                macro {
                    var handle = elements.Im.handle($v{posInfos});
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

    macro public static function array(?value:Expr):Expr {

        return switch value.expr {
            case EConst(CIdent('null')):
                var pos = Context.getPosInfos(Context.currentPos());
                var posInfos = _posInfosFromFileAndChar(pos.file, pos.min);
                macro {
                    var handle = elements.Im.handle($v{posInfos});
                    function(?_val:Array<Dynamic>, ?erase:Bool):Array<Dynamic> {
                        return _val != null || erase ? elements.Im.setArrayAtHandle(handle, _val) : elements.Im.arrayAtHandle(handle);
                    };
                }
            case _:
                macro function(?_val:Array<Dynamic>, ?erase:Bool):Array<Dynamic> {
                    return _val != null || erase ? $value = _val : $value;
                };
        }

    }

    #if macro

    static var _fileCache:Map<String,String> = null;

    static function _posInfosFromFileAndChar(file:String, char:Int):haxe.PosInfos {

        if (_fileCache == null) {
            _fileCache = new Map();
        }

        if (!Path.isAbsolute(file)) {
            file = Path.normalize(Path.join([Sys.getCwd(), file]));
        }

        if (!_fileCache.exists(file)) {
            var data:String = null;
            if (FileSystem.exists(file) && !FileSystem.isDirectory(file)) {
                data = File.getContent(file);
            }
            _fileCache.set(file, data);
        }

        var fileData:String = _fileCache.get(file);
        if (fileData != null) {

            var line:Int = 1;
            for (i in 0...char) {
                if (fileData.charCodeAt(i) == '\n'.code)
                    line++;
            }

            return {
                fileName: file,
                lineNumber: line,
                className: null,
                methodName: null
            };
        }
        else {
            return null;
        }

    }

    #end

}
