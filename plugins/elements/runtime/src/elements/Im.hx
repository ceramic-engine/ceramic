package elements;

#if !macro
import ceramic.Assert.assert;
import ceramic.AssetId;
import ceramic.Assets;
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
import ceramic.Pool;
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
import haxe.macro.Printer;
import sys.FileSystem;
import sys.io.File;

using haxe.macro.Tools;
#end


typedef IntPointer = (?val:Int)->Int;

/**
 * Immediate mode UI system for Ceramic inspired by Dear ImGui.
 * 
 * Im provides a stateless, code-driven UI API that creates and manages UI elements
 * on-the-fly. Unlike traditional retained-mode UI systems where you create and
 * maintain UI objects, Im allows you to declare UI in a procedural way:
 * 
 * ```haxe
 * Im.begin();
 * 
 * if (Im.button("Click me!")) {
 *     trace("Button clicked!");
 * }
 * 
 * Im.textField("Name", namePointer);
 * Im.slider("Volume", volumePointer, 0, 100);
 * 
 * Im.end();
 * ```
 * 
 * Key features:
 * - Immediate mode paradigm - UI is rebuilt every frame
 * - Automatic layout with rows and columns
 * - Built-in controls: buttons, text fields, sliders, checkboxes, etc.
 * - Window management with docking and tabs
 * - Theme support with runtime customization
 * - Cross-platform compatibility through Ceramic
 * 
 * The system uses pointers (functions that get/set values) to bind controls
 * to data, allowing the UI to automatically reflect and modify application state.
 * 
 * @see ImSystem
 * @see Window
 * @see Theme
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

    @:allow(elements.WindowItem)
    static var _beginFrameCallbacks:Array<Void->Void> = [];

    static var _orderedWindows:Array<Window> = [];

    static var _orderedWindowsIterated:Array<Window> = [];

    static var _currentWindowData:WindowData = null;

    static var _inRow:Bool = false;

    static var _currentRowIndex:Int = -1;

    static var _currentTabBarItem:Array<WindowItem> = [];

    static var _labelWidth:Float = DEFAULT_LABEL_WIDTH;

    static var _labelPosition:LabelPosition = DEFAULT_LABEL_POSITION;

    static var _textAlign:TextAlign = DEFAULT_TEXT_ALIGN;

    static var _fieldsDisabled:Bool = false;

    static var _flex:Int = 1;

    static var _bold:Bool = false;

    static var _pointSize:Int = 12;

    static var _preRenderedSize:Int = -1;

    static var _assets:Assets = null;

    static var _theme:Theme = null;

    static var _explicitTheme:Theme = null;

    static var _themeClonedIndex:Int = -1;

    static var _themeTint:Color = Color.NONE;

    static var _themeAltTint:Color = Color.NONE;

    static var _themeTextColor:Color = Color.NONE;

    static var _themeBackgroundColor:Color = Color.NONE;

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

    static var _pendingDialogs:Array<PendingDialog> = [];

    static var _displayedPendingDialog:PendingDialog = null;

    static var _allowedOwners:Array<Entity> = [];

    static var _usedWindowKeys:Map<String,String> = new Map();

    static var _changeChecks:Array<Bool> = [];

    static var _themePool:Array<Theme> = null;

    @:allow(elements.ImSystem)
    static var _numUsedWindows:Int = 0;

    static var _imTheme:Theme;

    static var _shouldSkipRender:Bool = false;

    /**
     * Initializes the Im system if not already initialized.
     * 
     * This method ensures that:
     * - The global context view exists
     * - A default theme is created
     * - The Im system is ready for use
     * 
     * This is automatically called by most Im methods, but can be
     * called manually if early initialization is needed.
     */
    public static function initIfNeeded():Void {

        if (context.view == null) {
            ImSystem.shared.createView();
        }

        if (_imTheme == null) {
            _imTheme = new Theme();
        }

        if (_theme == null) {
            _theme = _imTheme;
        }

    }

    /**
     * Extracts the ID portion from a window key.
     * 
     * Window keys can contain both an ID and a title. This method
     * extracts just the ID portion, which is used for window lookup
     * and persistence.
     * 
     * Currently returns the key as-is, but may parse complex keys
     * in the future (e.g., "id###title" format).
     * 
     * @param key The window key to extract ID from
     * @return The extracted ID
     */
    public static function extractId(key:String):String {

        return key;

    }

    /**
     * Extracts the title portion from a window key.
     * 
     * Window keys can contain both an ID and a title. This method
     * extracts just the title portion, which is displayed in the
     * window header.
     * 
     * Currently returns the key as-is, but may parse complex keys
     * in the future (e.g., "id###title" format).
     * 
     * @param key The window key to extract title from
     * @return The extracted title
     */
    public static function extractTitle(key:String):String {

        return key;

    }

    @:noCompletion public static function beginFrame():Void {

        initIfNeeded();

        _shouldSkipRender = false;

        _imTheme.backgroundInFormLayout = true;

        _usedWindowKeys.clear();
        _numUsedWindows = 0;
        _assets = null;
        _theme = _imTheme;
        _themeTint = Color.NONE;
        _themeAltTint = Color.NONE;
        _themeBackgroundColor = Color.NONE;
        _themeTextColor = Color.NONE;

        if (_themePool != null) {
            for (i in 0..._themePool.length) {
                _themePool.unsafeGet(i)._used = false;
            }
        }

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
                    var assets = _assets != null ? _assets : context.assets;
                    var asset = assets.asset(assetId, null, null);
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

    static function displayPendingDialogIfNeeded():Void {

        if (_pendingDialogs.length > 0) {

            var dialog = null;
            for (i in 0..._pendingDialogs.length) {
                var aDialog = _pendingDialogs.unsafeGet(i);
                if (!aDialog.canceled && aDialog.chosenIndex == -1) {
                    dialog = aDialog;
                    break;
                }
            }

            if (dialog != null) {

                var needsFocusReset = (_displayedPendingDialog != dialog);
                _displayedPendingDialog = dialog;

                var clickedIndex = -1;
                var closed = false;

                var window = Im.begin(
                    'Im.pendingDialog',
                    dialog.title, dialog.width
                );
                Im.position(screen.nativeWidth * 0.5, screen.nativeHeight * 0.5, 0.5, 0.5);
                if (Im.overlay() && dialog.cancelable) {
                    closed = true;
                }
                Im.expanded();
                Im.titleAlign(CENTER);

                if (dialog.cancelable && Im.closable()) {
                    closed = true;
                }

                Im.textAlign(CENTER);

                final message = dialog.message;
                if (message != null) {
                    Im.text(message);
                }

                if (dialog.promptPointer != null) {
                    if (Im.editText(dialog.promptPointer, false, dialog.promptPlaceholder, true).submitted) {
                        clickedIndex = 0;
                    }
                }

                if (dialog.choices.length == 2) {
                    Im.beginRow();
                }

                for (i in 0...dialog.choices.length) {
                    var item = dialog.choices.unsafeGet(i);

                    if (Im.button(item)) {
                        clickedIndex = i;
                    }
                }

                if (dialog.choices.length == 2) {
                    Im.endRow();
                }

                Im.end();

                if (clickedIndex != -1) {
                    dialog.callback(clickedIndex, dialog.choices[clickedIndex]);
                    dialog.chosenIndex = clickedIndex;
                    if (dialog.async) {
                        _pendingDialogs.remove(dialog);
                        dialog.destroy();
                    }
                }
                else if (closed) {
                    dialog.canceled = true;
                    if (dialog.async) {
                        _pendingDialogs.remove(dialog);
                        dialog.destroy();
                    }
                }
                else if (context.focusedWindow != window || needsFocusReset) {
                    screen.focusedVisual = window;
                }
            }

        }

    }

    @:noCompletion public static function endFrame():Void {

        assert(_changeChecks.length == 0, 'Called beginChangeCheck() without calling endChangeCheck()');
        while (_changeChecks.length > 0)
            _changeChecks.pop();

        displayPendingDialogIfNeeded();

        updateWindowsDepth();

        for (id => windowData in context.windowsData) {
            windowData.endFrame();
        }

        if (Im._numUsedWindows > 0) {
            ViewSystem.shared.onceEndLateUpdate(ImSystem.shared, _ -> {
                if (!_shouldSkipRender) {
                    ImSystem.shared.requestRender();
                }
            });
        }

    }

    /**
     * Sets the rendering depth for the entire Im UI layer.
     * 
     * This affects the z-order of all Im windows and controls relative
     * to other visuals in the scene. Higher values render on top.
     * 
     * Must be called before any windows are created to take effect.
     * 
     * @param depth The depth value to set
     */
    public static function depth(depth:Float):Void {

        // Create view if needed
        if (context.view == null) {
            ImSystem.shared.createView();
        }

        // Set depth
        context.view.depth = depth;

    }

    /**
     * Gets a window by its key.
     * 
     * Returns the Window instance if it exists, or null if no window
     * with the given key has been created yet.
     * 
     * This is useful for checking if a window is open or accessing
     * its properties from outside the begin/end block.
     * 
     * @param key The window key
     * @return The Window instance or null
     */
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

        var field = FieldSystem.shared.focusedFieldThisFrame;
        if (field != null) {
            if (field.usesScanCode(scanCode))
                return true;
        }

        var newField = FieldSystem.shared.focusedField;
        if (newField != null && newField != field) {
            if (newField.usesScanCode(scanCode))
                return true;
        }


        return false;

    }

    /**
     * Returns `true` if there is a currently focused field that uses the given key code
     * @param keyCode The key code to test
     * @return `true` if this key code is used
     */
    public static function usesKeyCode(keyCode:KeyCode):Bool {

        var field = FieldSystem.shared.focusedFieldThisFrame;
        if (field != null) {
            if (field.usesKeyCode(keyCode))
                return true;
        }

        var newField = FieldSystem.shared.focusedField;
        if (newField != null && newField != field) {
            if (newField.usesKeyCode(keyCode))
                return true;
        }

        return false;

    }

    /**
     * Checks if any Command (Mac) or Control (Windows/Linux) key is being used.
     * 
     * This is useful for detecting platform-specific modifier keys for
     * keyboard shortcuts. Returns true if any focused field is using
     * these keys.
     * 
     * @return True if Cmd/Ctrl keys are in use
     */
    public static function usesCmdOrCtrl():Bool {

        return usesScanCode(LMETA) || usesScanCode(RMETA) || usesScanCode(LCTRL) || usesScanCode(RCTRL);

    }

    /**
     * Checks if any Shift key is being used.
     * 
     * Returns true if any focused field is using either the left or
     * right Shift key. Useful for detecting shift-modified shortcuts.
     * 
     * @return True if Shift keys are in use
     */
    public static function usesShift():Bool {

        return usesScanCode(LSHIFT) || usesScanCode(RSHIFT);

    }

    /**
     * Begins an Im window with separate key and title.
     * 
     * This starts the declaration of a new window or continues an existing one.
     * All Im controls called after begin() will be added to this window until
     * end() is called.
     * 
     * The key is used to identify the window across frames, while the title
     * is displayed in the window header.
     * 
     * @param key Unique identifier for the window
     * @param title Display title for the window header
     * @param width Initial window width (default: 200)
     * @param height Initial window height (default: 400)
     * @param pos Source position (auto-provided)
     * @return The Window instance
     */
    public extern inline static overload function begin(key:String, title:String, width:Float = WindowData.DEFAULT_WIDTH, height:Float = WindowData.DEFAULT_HEIGHT, ?pos:haxe.PosInfos):Window {

        return _begin(key, title, width, height, pos);

    }

    /**
     * Begins an Im window using the key as both identifier and title.
     * 
     * This starts the declaration of a new window or continues an existing one.
     * All Im controls called after begin() will be added to this window until
     * end() is called.
     * 
     * @param key Unique identifier and display title for the window
     * @param width Initial window width (default: 200)
     * @param height Initial window height (default: 400)
     * @param pos Source position (auto-provided)
     * @return The Window instance
     */
    public extern inline static overload function begin(key:String, width:Float = WindowData.DEFAULT_WIDTH, height:Float = WindowData.DEFAULT_HEIGHT, ?pos:haxe.PosInfos):Window {

        return _begin(key, null, width, height, pos);

    }

    static function _begin(key:String, title:String, width:Float = WindowData.DEFAULT_WIDTH, height:Float = WindowData.DEFAULT_HEIGHT, ?pos:haxe.PosInfos):Window {

        assert(_currentWindowData == null, 'Duplicate begin() calls!');

        // Create view if needed
        var firstIteration = false;
        if (context.view == null) {
            firstIteration = true;
            ImSystem.shared.createView();
        }

        // Reset text settings
        pointSize();
        preRenderedSize();
        bold(false);

        // Get or create window
        var id = extractId(key);

        assert(!_usedWindowKeys.exists(id), 'Duplicate window with identifier: $id / First call ${_usedWindowKeys.get(id)}');
        _usedWindowKeys.set(id, _posInfosToString(pos));
        _numUsedWindows++;

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

            // When we just created a window, we make it inactive
            // and should skip render to prevent flickering
            _shouldSkipRender = true;
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

        // Mark as header as active but value can be changed
        // until Im.end() is called
        windowData.header = true;

        // Mark scrollbar as AUTO_ADD by default
        windowData.scrollbar = AUTO_ADD;

        // Keep some data up to date to handle `AUTO_ADD_STAY`
        if (windowData.scrollable) {
            if (windowData.didScrollWithHeight < -1) {
                windowData.didScrollWithHeight++;
            }
            else if (windowData.didScrollWithHeight > -1 && window != null && window.height > windowData.didScrollWithHeight) {
                windowData.didScrollWithHeight = -2;
            }
            else if (window != null) {
                windowData.didScrollWithHeight = Math.round(Math.max(windowData.didScrollWithHeight, window.height));
            }
        }

        // Mark as titleAlign LEFT but value can be changed
        // until Im.end() is called
        windowData.titleAlign = LEFT;

        // Mark as no overlay but value can be changed
        // until Im.end() is called
        windowData.overlay = false;
        windowData.overlayTheme = null;

        windowData.width = width;
        windowData.height = height;

        // No explicit target position (unless we call position() at this frame)
        windowData.targetX = -999999999;
        windowData.targetY = -999999999;
        windowData.targetAnchorX = -999999999;
        windowData.targetAnchorY = -999999999;

        // Set theme (can be changed with Im.theme())
        windowData.theme = _theme;
        if (window != null)
            window.theme = _theme;

        // Make the window current
        _currentWindowData = windowData;

        return window;

    }

    // #if (display || completion)

    // public extern inline static overload function beginTabs():Bool {

    //     return _beginTabs(null);

    // }

    /**
     * Begins a tab bar container.
     * 
     * Creates a horizontal tab bar where each tab() call adds a new tab.
     * The selected tab is controlled by the StringPointer parameter.
     * 
     * Must be followed by one or more tab() calls and ended with endTabs().
     * 
     * @param selected Pointer to the currently selected tab ID
     * @return True if the selected tab changed this frame
     */
    public extern inline static overload function beginTabs(selected:StringPointer):Bool {

        return _beginTabs(selected);

    }

    // #end

    private static function _beginTabs(selected:StringPointer):Bool {

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.theme = _theme;
        item.disabled = _fieldsDisabled;
        item.kind = TABS;
        item.string0 = Im.readString(selected);
        item.string1 = item.string0;

        // TODO recycle arrays
        item.intArray0 = [];
        item.stringArray0 = [];
        item.stringArray1 = [];
        item.anyArray0 = [];

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

        _currentTabBarItem.push(item);

        return selectedChanged;

    }

    /**
     * Ends a tab bar container.
     * 
     * Must be called after beginTabs() and all tab() declarations.
     * Will assert if called without a matching beginTabs() or if
     * no tabs were declared.
     */
    public static function endTabs():Void {

        assert(_currentTabBarItem.length > 0, 'beginTabs() must be called before endTabs()');

        var tabItem = _currentTabBarItem[_currentTabBarItem.length - 1];
        assert(tabItem.stringArray0.length > 0, 'there should be at least one tab() call between beginTabs() and endTabs()');

        _currentTabBarItem.pop();

    }

    /**
     * Declares a tab in the current tab bar.
     * 
     * Uses the key as both the tab ID and display title.
     * Must be called between beginTabs() and endTabs().
     * 
     * @param key Tab identifier and display title
     * @return True if this tab is currently selected
     */
    public static inline extern overload function tab(key:String):Bool {

        return _tab(key, null);

    }

    /**
     * Declares a tab in the current tab bar with separate ID and title.
     * 
     * Must be called between beginTabs() and endTabs().
     * 
     * @param key Tab identifier for selection tracking
     * @param title Display title for the tab
     * @return True if this tab is currently selected
     */
    public static inline extern overload function tab(key:String, title:String):Bool {

        return _tab(key, title);

    }

    static function _tab(key:String, title:String):Bool {

        assert(_currentTabBarItem.length > 0, 'tab() must be between beginTabs() and endTabs() calls');

        // Get or create window
        var id = extractId(key);
        var title = title != null ? title : extractTitle(key);

        var tabItem = _currentTabBarItem[_currentTabBarItem.length - 1];

        tabItem.intArray0.push(_fieldsDisabled ? 1 : 0);
        tabItem.stringArray0.push(id);
        tabItem.stringArray1.push(title);
        tabItem.anyArray0.push(_theme);

        if (tabItem.stringArray0.length == 1) {
            // First tab, set it default if there is no tab selected yet
            var selected:StringPointer = tabItem.any0;
            var selectedValue = Im.readString(selected);
            if (selectedValue == null) {
                selectedValue = id;
                Im.writeString(selected, selectedValue);
                tabItem.string0 = selectedValue;
                tabItem.string1 = selectedValue;
            }
        }

        return id == tabItem.string0;

    }

    /**
     * Begins a row layout for subsequent controls.
     * 
     * Controls added after beginRow() will be arranged horizontally
     * in a single row until endRow() is called. The width of each
     * control is determined by its flex value.
     * 
     * Nested rows are not supported - calling beginRow() while already
     * in a row will trigger an assertion.
     * 
     * ```haxe
     * Im.beginRow();
     * Im.button("Left");    // Default flex=1
     * Im.flex(2);
     * Im.button("Middle");  // Takes up twice the space
     * Im.button("Right");   // Default flex=1
     * Im.endRow();
     * ```
     * 
     * @see endRow
     * @see flex
     */
    public static function beginRow():Void {

        assert(_inRow == false, 'Called beginRow() multiple times! (nested rows are not supported)');

        _currentRowIndex++;
        _inRow = true;
        _flex = 1;

    }

    /**
     * Ends the current row layout.
     * 
     * Must be called after beginRow() to complete the row.
     * Resets the flex value to default (1) for subsequent controls.
     * 
     * @see beginRow
     */
    public static function endRow():Void {

        _inRow = false;
        _flex = 1;

    }

    /**
     * Begins tracking changes to control values.
     * 
     * After calling this method, any changes to control values
     * (text fields, sliders, checkboxes, etc.) will be tracked.
     * Call endChangeCheck() to check if any values changed.
     * 
     * Change checks can be nested - each begin/end pair tracks
     * changes independently.
     * 
     * ```haxe
     * Im.beginChangeCheck();
     * Im.textField("Name", namePointer);
     * Im.slider("Volume", volumePointer, 0, 100);
     * if (Im.endChangeCheck()) {
     *     trace("Settings changed!");
     *     saveSettings();
     * }
     * ```
     * 
     * @see endChangeCheck
     */
    public static function beginChangeCheck():Void {

        _changeChecks.push(false);

    }

    /**
     * Ends change tracking and returns if any changes occurred.
     * 
     * Must be called after beginChangeCheck(). Returns true if any
     * control values changed between the begin/end calls.
     * 
     * @return True if any tracked values changed
     */
    public static function endChangeCheck():Bool {

        assert(_changeChecks.length > 0, 'beginChangeCheck() must be called before endChangeCheck()');

        return _changeChecks.pop();

    }

    static function _markChanged():Void {

        for (i in 0..._changeChecks.length) {
            _changeChecks.unsafeSet(i, true);
        }

    }

    /**
     * Sets the label position for subsequent controls.
     * 
     * Controls where labels appear relative to their input fields:
     * - LEFT: Label to the left of the field
     * - RIGHT: Label to the right of the field
     * - TOP: Label above the field
     * - BOTTOM: Label below the field
     * 
     * @param labelPosition The position to use (default: RIGHT)
     */
    public static function labelPosition(labelPosition:LabelPosition = DEFAULT_LABEL_POSITION):Void {

        _labelPosition = labelPosition;

    }

    /**
     * Sets the width of labels for subsequent controls.
     * 
     * Can be specified as:
     * - Absolute pixels: positive values
     * - Percentage: use ViewSize.percent()
     * - Auto-size: use ViewSize.auto()
     * 
     * @param labelWidth The width to use (default: 35%)
     */
    public static function labelWidth(labelWidth:Float = DEFAULT_LABEL_WIDTH):Void {

        _labelWidth = labelWidth;

    }

    /**
     * Sets the text alignment for subsequent text controls.
     * 
     * Affects text(), labels, and other text-based controls.
     * 
     * @param textAlign The alignment to use (LEFT, CENTER, RIGHT)
     */
    public static function textAlign(textAlign:TextAlign = DEFAULT_TEXT_ALIGN):Void {

        _textAlign = textAlign;

    }

    /**
     * Sets whether subsequent controls should be disabled.
     * 
     * Disabled controls are rendered with reduced opacity and
     * don't respond to user interaction.
     * 
     * @param disabled True to disable controls, false to enable
     */
    public static function disabled(disabled:Bool):Void {

        _fieldsDisabled = disabled;

    }

    /**
     * Sets the flex value for the next control in a row.
     * 
     * When in a row layout (between beginRow/endRow), flex determines
     * the relative width of controls. A control with flex=2 will be
     * twice as wide as a control with flex=1.
     * 
     * Only applies to the next control added.
     * 
     * @param flex The flex value (default: 1)
     */
    public static function flex(flex:Int):Void {

        _flex = flex;

    }

    /**
     * Resets the text color to the default theme color.
     * 
     * Removes any custom text color override, allowing subsequent
     * text to use the theme's default text color.
     */
    public static extern inline overload function textColor():Void {
        _themeTextColor = Color.NONE;
        _updateTheme();
    }

    /**
     * Sets a custom text color for subsequent controls.
     * 
     * Overrides the theme's text color until reset. Affects all
     * text-based controls including labels, buttons, and text fields.
     * 
     * @param color The color to use for text
     */
    public static extern inline overload function textColor(color:Color):Void {
        _themeTextColor = color;
        _updateTheme();
    }

    /**
     * Resets the background color to the default theme color.
     * 
     * Removes any custom background color override, allowing subsequent
     * controls to use the theme's default background color.
     */
    public static extern inline overload function background():Void {
        _themeBackgroundColor = Color.NONE;
        _updateTheme();
    }

    /**
     * Sets a custom background color for subsequent controls.
     * 
     * Overrides the theme's background color until reset. Affects
     * controls that have background fills like windows, panels, and
     * input fields.
     * 
     * @param color The color to use for backgrounds
     */
    public static extern inline overload function background(color:Color):Void {
        _themeBackgroundColor = color;
        _updateTheme();
    }

    /**
     * Resets the tint color to default (no tint).
     * 
     * Removes any color tinting applied to subsequent controls,
     * returning them to their original theme colors.
     */
    public static extern inline overload function tint():Void {
        _themeTint = Color.NONE;
        _themeAltTint = Color.NONE;
        _updateTheme();
    }

    /**
     * Sets a tint color for subsequent controls.
     * 
     * Applies a color overlay to controls, blending with their
     * original colors. Both primary and alternate elements will
     * use the same tint color.
     * 
     * @param tint The tint color to apply
     */
    public static extern inline overload function tint(tint:Color):Void {
        _themeTint = tint;
        _themeAltTint = tint;
        _updateTheme();
    }

    /**
     * Sets separate tint colors for primary and alternate elements.
     * 
     * Allows different tinting for primary controls (buttons, fields)
     * and alternate elements (backgrounds, borders).
     * 
     * @param tint The tint color for primary elements
     * @param altTint The tint color for alternate elements
     */
    public static extern inline overload function tint(tint:Color, altTint:Color):Void {
        _themeTint = tint;
        _themeAltTint = altTint;
        _updateTheme();
    }

    /**
     * Sets whether subsequent text should be rendered in bold.
     * 
     * Affects text(), labels, and other text-based controls.
     * The actual bold rendering depends on the font's bold variant
     * being available.
     * 
     * @param bold True for bold text, false for normal
     */
    public static function bold(bold:Bool):Void {
        _bold = bold;
    }

    private static function _updateTheme():Void {

        initIfNeeded();

        if (_themePool == null)
            _themePool = [];

        var resolvedTheme:Theme = null;

        for (i in 0..._themePool.length) {
            var theme = _themePool[i];
            if (theme._tint == _themeTint && theme._altTint == _themeAltTint && theme._backgroundColor == _themeBackgroundColor && theme._textColor == _themeTextColor || theme._clonedIndex == _themeClonedIndex) {
                theme._used = true;
                resolvedTheme = theme;
                break;
            }
        }

        if (resolvedTheme == null) {
            for (i in 0..._themePool.length) {
                var theme = _themePool[i];
                if (!theme._used) {
                    theme._used = true;
                    if (theme._tint != _themeTint || theme._altTint != _themeAltTint || theme._backgroundColor != _themeBackgroundColor || theme._textColor != _themeTextColor || theme._clonedIndex != _themeClonedIndex) {

                        (_explicitTheme ?? _imTheme).clone(theme);
                        _themeClonedIndex = theme._clonedIndex;

                        if (_themeTint != Color.NONE) {
                            theme.applyTint(_themeTint);
                        }
                        theme._tint = _themeTint;

                        if (_themeAltTint != Color.NONE) {
                            theme.applyAltTint(_themeAltTint);
                        }
                        theme._altTint = _themeAltTint;

                        if (_themeBackgroundColor != Color.NONE) {
                            theme.applyBackgroundColor(_themeBackgroundColor);
                        }
                        theme._backgroundColor = _themeBackgroundColor;

                        if (_themeTextColor != Color.NONE) {
                            theme.applyTextColor(_themeTextColor);
                        }
                        theme._textColor = _themeTextColor;

                    }
                    resolvedTheme = theme;
                    break;
                }
            }
        }

        if (resolvedTheme == null) {
            var theme = new Theme();
            theme._used = true;

            (_explicitTheme ?? _imTheme).clone(theme);
            _themeClonedIndex = theme._clonedIndex;

            if (_themeTint != Color.NONE) {
                theme.applyTint(_themeTint);
            }
            theme._tint = _themeTint;

            if (_themeAltTint != Color.NONE) {
                theme.applyAltTint(_themeAltTint);
            }
            theme._altTint = _themeAltTint;

            if (_themeBackgroundColor != Color.NONE) {
                theme.applyBackgroundColor(_themeBackgroundColor);
            }
            theme._backgroundColor = _themeBackgroundColor;

            if (_themeTextColor != Color.NONE) {
                theme.applyTextColor(_themeTextColor);
            }
            theme._textColor = _themeTextColor;

            resolvedTheme = theme;
        }

        _themeInternal(resolvedTheme);

    }

    /**
     * Sets the asset manager to use for loading images and other resources.
     * 
     * When set, Im will use this asset manager for loading images referenced
     * by asset ID. If not set, Im will use the default asset manager.
     * 
     * @param assets The asset manager to use, or null to use default
     */
    public static function assets(?assets:Assets):Void {

        _assets = assets;

    }

    public static var defaultTheme(get,never):Theme;
    static function get_defaultTheme():Theme {
        initIfNeeded();
        return _imTheme;
    }

    public static var currentTheme(get,never):Theme;
    static function get_currentTheme():Theme {
        initIfNeeded();
        return _theme;
    }

    public static var current(get,never):WindowData;
    static function get_current():WindowData {
        initIfNeeded();
        return _currentWindowData;
    }

    /**
     * Sets the theme to use for subsequent controls.
     * 
     * The theme controls colors, fonts, and other visual properties
     * of Im controls. Pass null to revert to the default theme.
     * 
     * Changes to the theme affect all controls created after this
     * call within the current frame.
     * 
     * @param theme The theme to use, or null for default
     */
    public static function theme(theme:Theme):Void {

        initIfNeeded();

        _explicitTheme = theme;

        if (theme == null) {
            theme = _imTheme;
        }

        _theme = theme;
        _theme.backgroundInFormLayout = true;

    }

    static function _themeInternal(theme:Theme):Void {

        initIfNeeded();

        if (theme == null) {
            theme = _imTheme;
        }

        _theme = theme;
        _theme.backgroundInFormLayout = true;

    }

    /**
     * Sets the position of the current window.
     * 
     * Positions the window at the specified coordinates with optional
     * anchor points. The window becomes non-movable when positioned
     * manually.
     * 
     * Must be called between begin() and end().
     * 
     * @param x X position in screen coordinates
     * @param y Y position in screen coordinates
     * @param anchorX Horizontal anchor (0=left, 0.5=center, 1=right)
     * @param anchorY Vertical anchor (0=top, 0.5=center, 1=bottom)
     * @param roundXY Whether to round coordinates to whole pixels
     */
    public static function position(x:Float, y:Float, anchorX:Float = 0, anchorY:Float = 0, roundXY:Bool = true):Void {

        var windowData = _currentWindowData;

        windowData.targetX = roundXY ? Math.round(x) : x;
        windowData.targetY = roundXY ? Math.round(y) : y;
        windowData.targetAnchorX = anchorX;
        windowData.targetAnchorY = anchorY;

        windowData.movable = false;

    }

    /**
     * Sets the scrollbar visibility for the current window.
     * 
     * Controls when scrollbars appear in the window:
     * - AUTO: Show when content overflows
     * - ALWAYS: Always visible
     * - NEVER: Never show scrollbars
     * 
     * Must be called between begin() and end().
     * 
     * @param visibility The scrollbar visibility mode
     */
    public static function scrollbar(visibility:ScrollbarVisibility):Void {

        var windowData = _currentWindowData;

        windowData.scrollbar = visibility;

        windowData.movable = false;

    }

    /**
     * Requests focus for the current window.
     * 
     * The window will be brought to front and receive input focus.
     * Must be called between begin() and end().
     */
    public static function focus():Void {

        var windowData = _currentWindowData;

        if (windowData != null && windowData.window != null) {
            screen.focusedVisual = windowData.window;
        }

    }

    /**
     * Marks the current window as expanded.
     * 
     * Expanded windows start maximized and cannot be collapsed.
     * Must be called between begin() and end().
     */
    public static function expanded():Void {

        var windowData = _currentWindowData;

        windowData.collapsible = false;
        windowData.expanded = true;

    }

    /**
     * Sets whether the current window should display a header.
     * 
     * The header contains the window title and optional close button.
     * Windows without headers cannot be dragged by the title bar.
     * 
     * @param header True to show header, false to hide
     */
    public static function header(header:Bool):Void {

        var windowData = _currentWindowData;

        windowData.header = header;

    }

    /**
     * Makes the window display with a modal overlay.
     * 
     * An overlay darkens the background and blocks interaction with
     * other windows. Returns true if the overlay (outside the window)
     * was clicked this frame.
     * 
     * @return True if the overlay background was clicked
     */
    public static function overlay():Bool {

        var windowData = _currentWindowData;

        windowData.overlay = true;
        windowData.overlayTheme = _theme;

        if (windowData.overlayClicked) {
            windowData.overlayClicked = false;
            return true;
        }

        return false;

    }

    /**
     * Sets the alignment of the window title in the header.
     * 
     * Only applies to windows with headers enabled.
     * 
     * @param titleAlign The text alignment (LEFT, CENTER, RIGHT)
     */
    public static function titleAlign(titleAlign:TextAlign):Void {

        var windowData = _currentWindowData;

        windowData.titleAlign = titleAlign;

    }

    /**
     * Makes the window closable with a close button.
     * 
     * Adds a close button to the window header. If an isOpen pointer
     * is provided, it will be set to false when the window is closed.
     * 
     * @param isOpen Optional pointer to control window open state
     * @return True if the window was closed this frame
     */
    public static function closable(?isOpen:BoolPointer):Bool {

        var windowData = _currentWindowData;

        windowData.closable = true;

        if (windowData.justClosed) {
            windowData.justClosed = false;
            if (isOpen != null) {
                Im.writeBool(isOpen, false);
            }
            _markChanged();
            return true;
        }

        return false;

    }

    /**
     * Creates a list view with standard-sized items.
     * 
     * Displays a scrollable list of items with optional features:
     * - Selection tracking through the selected pointer
     * - Drag-and-drop sorting
     * - Item locking/unlocking
     * - Item deletion
     * - Item duplication
     * 
     * @param height List height in pixels (-1 for auto)
     * @param items Pointer to the array of items to display
     * @param selected Pointer to the selected item index
     * @param sortable Enable drag-and-drop reordering
     * @param lockable Enable lock/unlock toggle per item
     * @param trashable Enable delete button per item
     * @param duplicable Enable duplicate button per item
     * @return Status flags indicating what changed
     */
    public static extern inline overload function list(height:Float = -1, items:ArrayPointer, ?selected:IntPointer, sortable:Bool = false, lockable:Bool = false, trashable:Bool = false, duplicable:Bool = false):ListStatus {
        return _list(height, true, items, selected, sortable, lockable, trashable, duplicable);
    }

    /**
     * Creates a list view with configurable item size.
     * 
     * Same as list() but allows control over item size:
     * - bigItems=true: Larger items with more padding
     * - bigItems=false: Compact items with minimal padding
     * 
     * @param bigItems Use larger item size
     * @param height List height in pixels (-1 for auto)
     * @param items Pointer to the array of items to display
     * @param selected Pointer to the selected item index
     * @param sortable Enable drag-and-drop reordering
     * @param lockable Enable lock/unlock toggle per item
     * @param trashable Enable delete button per item
     * @param duplicable Enable duplicate button per item
     * @return Status flags indicating what changed
     */
    public static extern inline overload function list(bigItems:Bool, height:Float = -1, items:ArrayPointer, ?selected:IntPointer, sortable:Bool = false, lockable:Bool = false, trashable:Bool = false, duplicable:Bool = false):ListStatus {
        return _list(height, !bigItems, items, selected, sortable, lockable, trashable, duplicable);
    }

    private static function _list(height:Float = -1, smallItems:Bool, items:ArrayPointer, ?selected:IntPointer, sortable:Bool = false, lockable:Bool = false, trashable:Bool = false, duplicable:Bool = false):ListStatus {

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.theme = _theme;
        item.flex = _flex;
        item.disabled = _fieldsDisabled;
        item.kind = LIST;
        item.int0 = Im.readInt(selected);
        item.int1 = item.int0;
        item.int2 = Flags.fromValues(sortable, lockable, trashable, duplicable, smallItems).toInt();
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

            var status = new ListStatus(item.previous);
            if (status.itemsChanged || status.selectedChanged)
                _markChanged();
            return status;
        }

        var status = new ListStatus(item);
        if (status.itemsChanged || status.selectedChanged)
            _markChanged();
        return status;

    }

    public inline extern static overload function select(?title:String, value:StringPointer, list:Array<String>, ?nullValueText:String):Bool {

        var index:Int = list.indexOf(Im.readString(value));
        var changed = false;
        if (_select(title, Im.int(index), list, nullValueText)) {
            Im.writeString(value, list[index]);
            changed = true;
            _markChanged();
        }
        return changed;

    }

    public inline extern static overload function select(?title:String, value:IntPointer, list:Array<String>, ?nullValueText:String):Bool {

        var changed = false;
        if (_select(title, value, list, nullValueText)) {
            changed = true;
            _markChanged();
        }
        return changed;

    }

    public inline extern static overload function select(?title:String, value:EnumValuePointer, enumType:Dynamic, ?list:Array<String>, ?nullValueText:String):Bool {
        return _selectEnum(title, value, enumType, list, nullValueText);
    }

    static function _select(?title:String, index:IntPointer, list:Array<String>, ?nullValueText:String):Bool {

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.theme = _theme;
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
                _markChanged();
                return true;
            }
        }

        return false;

    }

    static function _selectEnum(?title:String, value:EnumValuePointer, enumType:Dynamic, list:Array<String>, nullValueText:String):Bool {

        var enumValue:Dynamic = Im.readEnumValue(value);
        var strValue:String = null;
        if (list == null) {
            if (Std.isOfType(enumType, EnumAbstractInfo)) {
                var abstractInfo:EnumAbstractInfo = cast enumType;
                list = abstractInfo.getEnumFields();
                strValue = abstractInfo.getEnumFieldFromValue(enumValue);
            }
            else {
                var enumTypeAsEnum:Enum<Dynamic> = enumType;
                list = enumTypeAsEnum.getConstructors();
                strValue = enumValue != null ? ''+enumValue : null;
            }
        }
        var changed = false;
        changed = select(title, Im.string(strValue), list, nullValueText);
        if (changed) {
            if (Std.isOfType(enumType, EnumAbstractInfo)) {
                var abstractInfo:EnumAbstractInfo = cast enumType;
                Im.writeEnumValue(value, abstractInfo.createEnumValue(strValue));
            }
            else {
                var index = strValue != null ? list.indexOf(strValue) : -1;
                Im.writeEnumValue(value, index != -1 ? Type.createEnum(enumType, list[index], []) : null);
            }
        }
        return changed;

    }

    /**
     * Creates a checkbox control.
     * 
     * Displays a checkbox that toggles a boolean value. The checkbox
     * shows a checkmark when true and is empty when false.
     * 
     * @param title Optional label for the checkbox
     * @param value Pointer to the boolean value
     * @param alignLabel Align label using standard label width
     * @return Status flags indicating checked state and if changed
     */
    public inline extern static overload function check(?title:String, value:BoolPointer, alignLabel:Bool = false):CheckStatus {

        return _check(title, value, alignLabel);

    }

    public static function _check(?title:String, value:BoolPointer, alignLabel:Bool):CheckStatus {

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.theme = _theme;
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
                _markChanged();
            }
        }

        return Flags.fromValues(checked, changed).toInt();

    }

    /**
     * Creates a color picker field.
     * 
     * Shows a color preview that opens a color picker dialog when clicked.
     * The color value is stored as an integer in ARGB format.
     * 
     * @param title Optional label for the field
     * @param value Pointer to the color value
     * @return True if the color changed this frame
     */
    public static function editColor(?title:String, value:IntPointer):Bool {

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.theme = _theme;
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
                _markChanged();
                return true;
            }
        }

        return false;

    }

    /**
     * Creates a text input field.
     * 
     * Supports single-line or multi-line text editing with optional
     * placeholder text and autocomplete suggestions.
     * 
     * @param title Optional label for the field
     * @param value Pointer to the string value
     * @param multiline Enable multi-line editing
     * @param placeholder Text shown when field is empty
     * @param autocompleteCandidates List of autocomplete suggestions
     * @param focused Request focus on this field
     * @param autocompleteOnFocus Show autocomplete when focused
     * @return Status flags indicating edit state
     */
    public static function editText(?title:String, value:StringPointer, multiline:Bool = false, ?placeholder:String, ?autocompleteCandidates:Array<String>, focused:Bool = false, autocompleteOnFocus:Bool = true):EditTextStatus {

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.theme = _theme;
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
        item.bool2 = focused;
        item.string2 = title;
        item.string3 = placeholder;
        item.stringArray0 = autocompleteCandidates;
        item.bool4 = autocompleteOnFocus;
        item.row = _inRow ? _currentRowIndex : -1;

        windowData.addItem(item);

        if (item.isSameItem(item.previous)) {
            // Did value changed from field last frame?
            var prevValue = item.previous.string0;
            var newValue = item.previous.string1;
            var submitted = item.previous.bool1;
            var blurred = item.previous.bool3;
            if (newValue != prevValue) {
                item.string0 = newValue;
                item.string1 = newValue;
                Im.writeString(value, newValue);
                _markChanged();
                return Flags.fromValues(true, submitted, blurred).toInt();
            }
            else {
                return Flags.fromValues(false, submitted, blurred).toInt();
            }
        }

        return Flags.fromValues(false, false).toInt();

    }

    #if plugin_dialogs

    /**
     * Creates a directory picker field.
     * 
     * Shows a text field with a browse button that opens a directory
     * selection dialog. Only available when dialogs plugin is enabled.
     * 
     * @param title Optional label for the field
     * @param value Pointer to the directory path string
     * @param placeholder Text shown when field is empty
     * @return True if the directory changed this frame
     */
    @:plugin('dialogs')
    public static function editDir(?title:String, value:StringPointer, ?placeholder:String):Bool {

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.theme = _theme;
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
                _markChanged();
                return true;
            }
        }

        return false;

    }

    /**
     * Creates a file picker field.
     * 
     * Shows a text field with a browse button that opens a file
     * selection dialog. Only available when dialogs plugin is enabled.
     * 
     * @param title Optional label for the field
     * @param value Pointer to the file path string
     * @param placeholder Text shown when field is empty
     * @param filters File type filters for the dialog
     * @return True if the file path changed this frame
     */
    @:plugin('dialogs')
    public static function editFile(?title:String, value:StringPointer, ?placeholder:String, ?filters:DialogsFileFilter):Bool {

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.theme = _theme;
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
                _markChanged();
                return true;
            }
        }

        return false;

    }

    #end

    /**
     * Creates an integer input field.
     * 
     * Allows numeric input with optional min/max constraints.
     * Non-numeric input is automatically filtered out.
     * 
     * @param title Optional label for the field
     * @param value Pointer to the integer value
     * @param placeholder Text shown when field is empty
     * @param minValue Minimum allowed value
     * @param maxValue Maximum allowed value
     * @return True if the value changed this frame
     */
    public static function editInt(
        #if (display || completion)
        ?title:String, value:IntPointer, ?placeholder:String, ?minValue:Int, ?maxValue:Int
        #else
        ?title:String, value:IntPointer, ?placeholder:String, minValue:Int = INT_MIN_VALUE, maxValue:Int = INT_MAX_VALUE
        #end
    ):Bool {

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.theme = _theme;
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
                _markChanged();
                return true;
            }
        }

        return false;

    }

    /**
     * Creates a float input field.
     * 
     * Allows decimal numeric input with optional min/max constraints
     * and rounding precision.
     * 
     * @param title Optional label for the field
     * @param value Pointer to the float value
     * @param placeholder Text shown when field is empty
     * @param minValue Minimum allowed value
     * @param maxValue Maximum allowed value
     * @param round Rounding precision (e.g., 100 = 2 decimals)
     * @return True if the value changed this frame
     */
    public static function editFloat(
        #if (display || completion)
        ?title:String, value:FloatPointer, ?placeholder:String, ?minValue:Float, ?maxValue:Float, ?round:Int
        #else
        ?title:String, value:FloatPointer, ?placeholder:String, minValue:Float = FLOAT_MIN_VALUE, maxValue:Float = FLOAT_MAX_VALUE, round:Int = 1000
        #end
    ):Bool {

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.theme = _theme;
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
                _markChanged();
                return true;
            }
        }

        return false;

    }

    /**
     * Creates an integer slider control.
     * 
     * Provides a draggable slider for selecting integer values within
     * a specified range. More intuitive than text input for ranges.
     * 
     * @param title Optional label for the slider
     * @param value Pointer to the integer value
     * @param minValue Minimum slider value
     * @param maxValue Maximum slider value
     * @return True if the value changed this frame
     */
    public static function slideInt(
        ?title:String, value:IntPointer, minValue:Int, maxValue:Int
    ):Bool {

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.theme = _theme;
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
                _markChanged();
                return true;
            }
        }

        return false;

    }

    /**
     * Creates a float slider control.
     * 
     * Provides a draggable slider for selecting float values within
     * a specified range with configurable precision.
     * 
     * @param title Optional label for the slider
     * @param value Pointer to the float value
     * @param minValue Minimum slider value
     * @param maxValue Maximum slider value
     * @param round Rounding precision (e.g., 100 = 2 decimals)
     * @return True if the value changed this frame
     */
    public static function slideFloat(
        ?title:String, value:FloatPointer, minValue:Float, maxValue:Float, round:Int = 1000
    ):Bool {

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.theme = _theme;
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
                _markChanged();
                return true;
            }
        }

        return false;

    }

    /**
     * Displays a custom visual element.
     * 
     * Embeds any Ceramic Visual object within the Im layout. The visual
     * can be scaled to fit within constraints or displayed at its natural size.
     * 
     * @param title Optional label for the visual
     * @param visual The Visual object to display
     * @param scaleToFit Scale the visual to fit available space
     * @param alignLabel Align label using standard label width
     * @param useFilter Apply texture filtering when scaling
     */
    public static function visual(?title:String, visual:Visual, scaleToFit:Bool = false, alignLabel:Bool = false, useFilter:Bool = true):Void {

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.theme = _theme;
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

    /**
     * Displays an image from a texture tile.
     * 
     * Shows a TextureTile (sub-region of a texture) within the Im layout.
     * 
     * @param title Optional label for the image
     * @param tile The texture tile to display
     * @param scaleToFit Scale image to fit available space
     * @param alignLabel Align label using standard label width
     * @param textureFilter Texture filtering mode (LINEAR/NEAREST)
     * @return The Quad visual displaying the image
     */
    inline extern overload public static function image(?title:String, tile:TextureTile, scaleToFit:Bool = false, alignLabel:Bool = false, ?textureFilter:TextureFilter):Quad {

        return _imageWithTile(title, tile, scaleToFit, alignLabel, textureFilter);

    }

    static function _imageWithTile(title:String, tile:TextureTile, scaleToFit:Bool, alignLabel:Bool, textureFilter:TextureFilter):Quad {

        return _image(title, null, tile, -1, -1, -1, -1, scaleToFit, alignLabel, textureFilter);

    }

    /**
     * Displays an image from an asset ID with label.
     * 
     * Loads and displays an image asset by ID. The asset is automatically
     * managed and loaded if not already available.
     * 
     * @param title Label for the image
     * @param assetId Asset identifier (can omit "image:" prefix)
     * @param frameX X position of sub-region (-1 for full image)
     * @param frameY Y position of sub-region (-1 for full image)
     * @param frameWidth Width of sub-region (-1 for full width)
     * @param frameHeight Height of sub-region (-1 for full height)
     * @param scaleToFit Scale image to fit available space
     * @param alignLabel Align label using standard label width
     * @param textureFilter Texture filtering mode (LINEAR/NEAREST)
     * @return The Quad visual displaying the image
     */
    inline extern overload public static function image(title:String, assetId:String, frameX:Float = -1, frameY:Float = -1, frameWidth:Float = -1, frameHeight:Float = -1, scaleToFit:Bool = false, alignLabel:Bool = false, ?textureFilter:TextureFilter):Quad {

        return _imageWithAsset(title, assetId, frameX, frameY, frameWidth, frameHeight, scaleToFit, alignLabel, textureFilter);

    }

    /**
     * Displays an image from an asset ID without label.
     * 
     * Loads and displays an image asset by ID. The asset is automatically
     * managed and loaded if not already available.
     * 
     * @param assetId Asset identifier (can omit "image:" prefix)
     * @param frameX X position of sub-region (-1 for full image)
     * @param frameY Y position of sub-region (-1 for full image)
     * @param frameWidth Width of sub-region (-1 for full width)
     * @param frameHeight Height of sub-region (-1 for full height)
     * @param scaleToFit Scale image to fit available space
     * @param alignLabel Align label using standard label width
     * @param textureFilter Texture filtering mode (LINEAR/NEAREST)
     * @return The Quad visual displaying the image
     */
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

        var assets = _assets != null ? _assets : context.assets;
        var texture = assets.texture(assetId);
        if (texture == null) {
            var imageAsset = assets.asset(assetId, null, null);
            if (imageAsset == null) {
                assets.addImage(assetId);
                assets.load();
            }
        }
        return _image(title, texture, null, frameX, frameY, frameWidth, frameHeight, scaleToFit, alignLabel, textureFilter);

    }

    /**
     * Displays an image from a texture.
     * 
     * Shows a Texture object within the Im layout, optionally displaying
     * only a sub-region of the texture.
     * 
     * @param title Optional label for the image
     * @param texture The texture to display
     * @param frameX X position of sub-region (-1 for full image)
     * @param frameY Y position of sub-region (-1 for full image)
     * @param frameWidth Width of sub-region (-1 for full width)
     * @param frameHeight Height of sub-region (-1 for full height)
     * @param scaleToFit Scale image to fit available space
     * @param alignLabel Align label using standard label width
     * @param textureFilter Texture filtering mode (LINEAR/NEAREST)
     * @return The Quad visual displaying the image
     */
    inline extern overload public static function image(?title:String, texture:Texture, frameX:Float = -1, frameY:Float = -1, frameWidth:Float = -1, frameHeight:Float = -1, scaleToFit:Bool = false, alignLabel:Bool = false, ?textureFilter:TextureFilter):Quad {

        return _image(title, texture, null, frameX, frameY, frameWidth, frameHeight, scaleToFit, alignLabel, textureFilter);

    }

    static function _image(title:String, texture:Texture, tile:TextureTile, frameX:Float, frameY:Float, frameWidth:Float, frameHeight:Float, scaleToFit:Bool, alignLabel:Bool, textureFilter:TextureFilter):Quad {

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.theme = _theme;
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
        item.theme = _theme;
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

    @:plugin('spine')
    inline extern overload public static function spine(?title:String, spineData:SpineData, ?animation:String, ?skin:String, time:Float = -1, scaleToFit:Bool = false, alignLabel:Bool = false):Spine {

        return _spine(title, spineData, animation, skin, time, scaleToFit, alignLabel);

    }

    @:plugin('spine')
    static function _spine(title:String, spineData:SpineData, animation:String, skin:String, time:Float, scaleToFit:Bool, alignLabel:Bool):Spine {

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.theme = _theme;
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

    /**
     * Adds a standard margin space.
     * 
     * Inserts negative spacing to reduce the gap between form items.
     * Useful for tightening layouts.
     */
    public static function margin():Void {

        initIfNeeded();

        space(-_theme.formItemSpacing / 2);

    }

    /**
     * Adds vertical spacing.
     * 
     * Inserts empty vertical space between controls. Use negative values
     * to reduce spacing. Default uses theme spacing.
     * 
     * @param height Space height in pixels (default: theme spacing)
     */
    public static function space(height:Float = DEFAULT_SPACE_HEIGHT):Void {

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.theme = _theme;
        item.flex = _flex;
        item.kind = SPACE;
        item.float0 = height;
        item.row = _inRow ? _currentRowIndex : -1;

        windowData.addItem(item);

    }

    /**
     * Adds a horizontal line separator.
     * 
     * Draws a horizontal line to visually separate sections.
     * The line color is determined by the current theme.
     * 
     * @param height Total height including padding (default: 7)
     */
    public static function separator(height:Float = DEFAULT_SEPARATOR_HEIGHT):Void {

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.theme = _theme;
        item.flex = _flex;
        item.kind = SEPARATOR;
        item.float0 = height;
        item.row = _inRow ? _currentRowIndex : -1;

        windowData.addItem(item);

    }

    /**
     * Creates a button with explicit enabled state.
     * 
     * @param title The button label
     * @param enabled Whether the button is clickable
     * @return True if the button was clicked this frame
     */
    inline extern overload public static function button(title:String, enabled:Bool):Bool {

        return _button(title, enabled);

    }

    /**
     * Creates a clickable button.
     * 
     * The button uses the current theme for styling and respects
     * the disabled state set by disabled().
     * 
     * @param title The button label
     * @return True if the button was clicked this frame
     */
    inline extern overload public static function button(title:String):Bool {

        return _button(title, true);

    }

    /**
     * Internal button implementation.
     * 
     * Creates a button control and tracks click state across frames.
     * 
     * @param title The button label
     * @param enabled Whether the button can be clicked
     * @return True if clicked this frame
     */
    public static function _button(title:String, enabled:Bool):Bool {

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.theme = _theme;
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
                _markChanged();
                return true;
            }
        }

        return false;

    }

    /**
     * Sets the font point size for subsequent text.
     * 
     * Affects text(), labels, and all text-based controls until
     * changed again or the frame ends.
     * 
     * @param pointSize Font size in points (default: 12)
     */
    public static function pointSize(pointSize:Int = 12):Void {

        _pointSize = pointSize;

    }

    /**
     * Sets the pre-rendered font size for bitmap fonts.
     * 
     * When using bitmap fonts, this specifies which pre-rendered
     * size to use. Set to -1 to use automatic size selection.
     * 
     * @param preRenderedSize The bitmap font size to use, or -1 for auto
     */
    public static function preRenderedSize(preRenderedSize:Int = -1):Void {

        _preRenderedSize = preRenderedSize;

    }

    /**
     * Displays static text.
     * 
     * Renders a text label using the current theme settings.
     * The text is not selectable or editable.
     * 
     * @param value The text to display
     * @param align Optional text alignment override
     */
    public static function text(value:String, ?align:TextAlign):Void {

        var windowData = _currentWindowData;

        var item = WindowItem.get();
        item.theme = _theme;
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
        item.bool0 = _bold;

        item.int2 = _pointSize;
        if (_preRenderedSize > 0) {
            item.int3 = _preRenderedSize;
        }
        else {
            item.int3 = Math.ceil((_pointSize + 7.9) / 5) * 5;
        }

        windowData.addItem(item);

    }

    /**
     * Ends the current window declaration.
     * 
     * Must be called after begin() and all window content has been added.
     * This finalizes the window layout and renders all controls.
     * 
     * Will assert if called without a matching begin().
     */
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

            if (window != null && windowData.targetX != -999999999) {
                // We update window after we are sure its content layout is done
                ViewSystem.shared.onceEndLateUpdate(window, function(delta) {
                    windowData.x = windowData.targetX - windowData.targetAnchorX * window.width;
                    windowData.y = windowData.targetY - windowData.targetAnchorY * window.height;
                    window.x = windowData.x;
                    window.y = windowData.y;
                });
            }
        }
        else {
            window.closable = windowData.closable;
            window.movable = windowData.movable;
            window.collapsible = windowData.collapsible;
            window.titleAlign = windowData.titleAlign;
            window.header = windowData.header;

            if (!windowData.expanded) {
                var prevContentView = window.contentView;
                if (prevContentView != null) {
                    window.contentView = null;
                    prevContentView.destroy();
                    windowData.form = null;
                    windowData.filler = null;
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

                if (window != null && windowData.targetX != -999999999) {
                    // We update window after we are sure its content layout is done
                    ViewSystem.shared.onceEndLateUpdate(window, function(delta) {
                        windowData.x = windowData.targetX - windowData.targetAnchorX * window.width;
                        windowData.y = windowData.targetY - windowData.targetAnchorY * window.height;
                        window.x = windowData.x;
                        window.y = windowData.y;
                    });
                }
            }
            else {
                var form = windowData.form;
                var filler = windowData.filler;
                var needsContentRebuild = false;
                var canReuseViews = true;

                var overflowScroll = (windowData.height != ViewSize.auto()) && switch windowData.scrollbar {
                    case AUTO_ADD:
                        windowData.computedContentHeight > windowData.height;
                    case AUTO_ADD_STAY:
                        windowData.computedContentHeight > windowData.height || windowData.didScrollWithHeight >= 0;
                    case AUTO_SHOW:
                        true;
                    case ALWAYS:
                        true;
                    case NEVER:
                        false;
                }
                windowData.scrollable = overflowScroll;

                inline function createScrollingLayout(container:ColumnLayout) {
                    container.paddingRight = 12;
                    var scroll = new ScrollingLayout(container, true);
                    scroll.theme = windowData.theme;
                    scroll.checkChildrenOfView = form;
                    var scrollbar = new Scrollbar();
                    scrollbar.active = false;
                    scrollbar.inset(2, 1, 1, 2);
                    scroll.scroller.scrollbar = scrollbar;
                    scroll.transparent = true;
                    scroll.viewSize(ViewSize.fill(), windowData.height);
                    var scrollbarBackground = new Quad();
                    scrollbarBackground.id = 'scrollbar-bg';
                    scrollbarBackground.transparent = false;
                    scrollbarBackground.pos(scroll.width - 12, 0);
                    scrollbarBackground.size(12, scroll.height);
                    scrollbarBackground.alpha = windowData.theme.windowBackgroundAlpha;
                    scrollbarBackground.color = windowData.theme.windowBackgroundColor;
                    scroll.onResize(scrollbarBackground, (width, height) -> {
                        scrollbarBackground.pos(width - 12, 0);
                        scrollbarBackground.size(12, height);
                    });
                    scroll.add(scrollbarBackground);
                    window.contentView = scroll;
                }

                if (window.contentView != null) {
                    if (window.contentView is ScrollingLayout) {
                        var scroll:ScrollingLayout<ColumnLayout> = cast window.contentView;
                        if (!overflowScroll) {
                            // Changed from overflow scroll to no overflow
                            var container = scroll.layoutView;
                            if (container.parent != null)
                                container.parent.remove(container);
                            window.contentView = container;

                            container.paddingRight = 0;
                            needsContentRebuild = true;

                            var views = form.subviews;
                            if (views == null)
                                return;
                            for (i in 0...views.length) {
                                var view = views[i];
                                if (!view.active)
                                    continue;
                                view.visible = true;
                            }
                        }
                        else {
                            scroll.viewSize(ViewSize.fill(), windowData.height);
                        }
                    }
                    else {
                        if (overflowScroll) {
                            // Changed from no overflow to overflow scroll
                            needsContentRebuild = true;
                            var container:ColumnLayout = cast window.contentView;
                            createScrollingLayout(container);
                        }
                    }
                }
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

                    filler = new View();
                    filler.viewSize(ViewSize.fill(), 0);
                    filler.transparent = false;
                    container.add(filler);

                    windowData.filler = filler;

                    if (overflowScroll) {
                        createScrollingLayout(container);
                    }
                    else {
                        window.contentView = container;
                    }
                }

                if (form != null) {
                    form.tabFocus.focusRoot = window;
                    form.theme = windowData.theme;
                }

                if (filler != null) {
                    filler.alpha = windowData.theme.windowBackgroundAlpha;
                    filler.color = windowData.theme.windowBackgroundColor;
                }

                if (window.contentView != null && window.contentView is ScrollingLayout) {
                    var rawScrollbarBackground = window.contentView.childWithId('scrollbar-bg');
                    if (rawScrollbarBackground != null) {
                        var scrollbarBackground:Quad = cast rawScrollbarBackground;
                        scrollbarBackground.alpha = windowData.theme.windowBackgroundAlpha;
                        scrollbarBackground.color = windowData.theme.windowBackgroundColor;
                    }
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
                    if (subviews != null) {
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
                        var reuseView = canReuseViews && (item.previous != null && item.isSameItem(item.previous));
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
                var theme = windowData.overlayTheme ?? context.theme;
                window.overlay.color = theme.overlayBackgroundColor;
                window.overlay.alpha = theme.overlayBackgroundAlpha;
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

            // We update window computed height after we are sure its content layout is done
            ViewSystem.shared.onceEndLateUpdate(window, function(delta) {
                if (window.contentView != null && windowData.height > 0) {
                    if (window.contentView is ScrollingLayout) {
                        var scroll:ScrollingLayout<ColumnLayout> = cast window.contentView;
                        windowData.computedContentHeight = scroll.contentView.height;

                        if (windowData.scrollbar == AUTO_SHOW || windowData.scrollbar == AUTO_ADD || (windowData.scrollbar == AUTO_ADD_STAY && windowData.didScrollWithHeight < 0)) {
                            final makeActive = (windowData.computedContentHeight > windowData.height);
                            final scrollbar = scroll.scroller.scrollbar;
                            if (scrollbar != null) {
                                if (!makeActive) {
                                    scrollbar.active = false;
                                }
                                else {
                                    _shouldSkipRender = !scrollbar.active;
                                }
                                app.onceUpdate(scrollbar, _ -> {
                                    scrollbar.active = makeActive;
                                });
                            }
                        }
                        else if (windowData.scrollbar == ALWAYS || (windowData.scrollbar == AUTO_ADD_STAY && windowData.didScrollWithHeight >= 0)) {
                            final scrollbar = scroll.scroller.scrollbar;
                            if (scrollbar != null && !scrollbar.active) {
                                _shouldSkipRender = !scrollbar.active;
                                app.onceUpdate(scrollbar, _ -> {
                                    if (windowData.scrollbar == ALWAYS || (windowData.scrollbar == AUTO_ADD_STAY && windowData.didScrollWithHeight >= 0)) {
                                        scrollbar.active = true;
                                    }
                                });
                            }
                        }
                    }
                    else {
                        windowData.computedContentHeight = window.contentView.height;
                        if ((windowData.scrollbar == AUTO_ADD || windowData.scrollbar == AUTO_ADD_STAY) && windowData.computedContentHeight > windowData.height) {
                            final contentView = window.contentView;
                            contentView.visible = false;
                            _shouldSkipRender = true;
                            app.onceUpdate(contentView, _ -> {
                                contentView.visible = true;
                            });
                        }
                    }
                    if (windowData.filler != null && windowData.form != null) {
                        windowData.filler.viewHeight = Math.max(0, windowData.height - windowData.form.height);
                    }
                }
            });
        }

        // Done with this window
        _currentWindowData = null;
        _currentRowIndex = -1;
        _inRow = false;

        _textAlign = DEFAULT_TEXT_ALIGN;
        _labelWidth = DEFAULT_LABEL_WIDTH;
        _labelPosition = DEFAULT_LABEL_POSITION;

        while (_currentTabBarItem.length > 0) {
            _currentTabBarItem.pop();
        }

    }

/// Focused?

    /**
     * Gets the currently focused Im window.
     * 
     * Returns the Window that currently has input focus, or null
     * if no Im window is focused. Useful for checking if the Im
     * UI is capturing input.
     * 
     * @return The focused Window or null
     */
    inline public static function focusedWindow():Window {

        return Context.context.focusedWindow;

    }

/// Filter event owners

    /**
     * Allows events from a specific entity owner.
     * 
     * When Im windows are focused, they block events from other entities
     * by default. Use this to whitelist specific entities whose events
     * should still be processed. The entity is automatically removed
     * from the allowed list when destroyed.
     * 
     * @param owner The entity to allow events from
     */
    public static function allow(owner:Entity):Void {

        if (_allowedOwners.indexOf(owner) == -1) {
            _allowedOwners.push(owner);
            owner.onDestroy(null, _allowedOwnerDestroyed);
        }

    }

    /**
     * Removes an entity from the allowed owners list.
     * 
     * Events from this entity will be blocked again when Im windows
     * are focused. Also removes the destroy listener if the entity
     * still exists.
     * 
     * @param owner The entity to remove from allowed list
     */
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
            var n = 0;
            while (entity != null && n < 10) {
                if (entity is Visual) {
                    var visual:Visual = cast entity;
                    if (visual.hasIndirectParent(view)) {
                        return true;
                    }
                }
                if (_allowedOwners.indexOf(entity) != -1) {
                    return true;
                }
                if (entity is Component) {
                    var subComponent:Component = cast entity;
                    entity = @:privateAccess subComponent.getEntity();
                }
                else {
                    entity = null;
                }
                n++;
            }
        }

        if (owner is KeyBinding) {
            var keyBinding:KeyBinding = cast owner;
            var bindings = keyBinding.bindings;
            if (bindings != null) {
                var entity = @:privateAccess bindings.getEntity();
                if (entity != null) {
                    if (entity is Visual) {
                        var visual:Visual = cast entity;
                        if (visual.hasIndirectParent(view)) {
                            return true;
                        }
                    }
                    if (_allowedOwners.indexOf(entity) != -1) {
                        return true;
                    }
                }
                if (_allowedOwners.indexOf(bindings) != 1) {
                    return true;
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

    /**
     * Shows a confirmation dialog (synchronous version).
     * 
     * Displays a modal dialog with Yes/No buttons. The dialog can be
     * canceled by clicking outside if cancelable is true.
     * 
     * This version returns immediately with the current status. Use
     * the returned ConfirmStatus to check if the user made a choice.
     * 
     * @param title Dialog window title
     * @param message Message to display
     * @param cancelable Allow closing by clicking outside
     * @param yes Custom "Yes" button text
     * @param no Custom "No" button text
     * @param width Dialog width in pixels
     * @param height Dialog height in pixels
     * @param key Optional unique key for persistent dialogs
     * @return Current dialog status
     */
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

    /**
     * Shows a confirmation dialog (async version with boolean callback).
     * 
     * Displays a modal dialog with Yes/No buttons. The dialog can be
     * canceled by clicking outside if cancelable is true.
     * 
     * This version shows the dialog and calls the callback when the
     * user makes a choice. The callback receives true for "Yes",
     * false for "No" or cancel.
     * 
     * @param title Dialog window title
     * @param message Message to display
     * @param cancelable Allow closing by clicking outside
     * @param yes Custom "Yes" button text
     * @param no Custom "No" button text
     * @param width Dialog width in pixels
     * @param height Dialog height in pixels
     * @param callback Called with true if confirmed, false otherwise
     */
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

    /**
     * Shows a confirmation dialog (async version with void callback).
     * 
     * Displays a modal dialog with Yes/No buttons. The dialog can be
     * canceled by clicking outside if cancelable is true.
     * 
     * This version shows the dialog and calls the callback only when
     * the user clicks "Yes". Clicking "No" or cancel does nothing.
     * 
     * @param title Dialog window title
     * @param message Message to display
     * @param cancelable Allow closing by clicking outside
     * @param yes Custom "Yes" button text
     * @param no Custom "No" button text
     * @param width Dialog width in pixels
     * @param height Dialog height in pixels
     * @param callback Called only if user confirms
     */
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

        initIfNeeded();

        if (yes == null)
            yes = YES;

        if (no == null)
            no = NO;

        var choice:PendingDialog = null;

        if (key != null) {
            key = extractId(key);
            for (i in 0..._pendingDialogs.length) {
                var existing = _pendingDialogs.unsafeGet(i);
                if (existing.key == key) {
                    choice = existing;
                    break;
                }
            }
        }

        if (choice == null) {
            choice = new PendingDialog(
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
                        _pendingDialogs.remove(choice);
                        choice.destroy();
                    }
                }
            });

            _pendingDialogs.push(choice);
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
            _pendingDialogs.remove(choice);
            choice.destroy();
        }

        return status;

    }

    /**
     * Shows an information dialog (synchronous version).
     * 
     * Displays a modal dialog with an OK button. The dialog can be
     * canceled by clicking outside if cancelable is true.
     * 
     * This version returns immediately with the current status. Use
     * the returned InfoStatus to check if the user clicked OK.
     * 
     * @param title Dialog window title
     * @param message Message to display
     * @param cancelable Allow closing by clicking outside
     * @param ok Custom "OK" button text
     * @param width Dialog width in pixels
     * @param height Dialog height in pixels
     * @param key Optional unique key for persistent dialogs
     * @return Current dialog status
     */
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

    /**
     * Shows an information dialog (async version).
     * 
     * Displays a modal dialog with an OK button. The dialog can be
     * canceled by clicking outside if cancelable is true.
     * 
     * This version shows the dialog and calls the callback when the
     * user clicks OK. Canceling the dialog does not call the callback.
     * 
     * @param title Dialog window title
     * @param message Message to display
     * @param cancelable Allow closing by clicking outside
     * @param ok Custom "OK" button text
     * @param width Dialog width in pixels
     * @param height Dialog height in pixels
     * @param callback Called when user clicks OK
     */
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

        initIfNeeded();

        if (ok == null)
            ok = OK;

        var choice:PendingDialog = null;

        if (key != null) {
            key = extractId(key);
            for (i in 0..._pendingDialogs.length) {
                var existing = _pendingDialogs.unsafeGet(i);
                if (existing.key == key) {
                    choice = existing;
                    break;
                }
            }
        }

        if (choice == null) {
            choice = new PendingDialog(
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
                        _pendingDialogs.remove(choice);
                        choice.destroy();
                    }
                }
            });

            _pendingDialogs.push(choice);
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
            _pendingDialogs.remove(choice);
            choice.destroy();
        }

        return status;

    }

    /**
     * Shows a text input dialog (synchronous version).
     * 
     * Displays a modal dialog with a text field and OK/Cancel buttons.
     * The dialog can be canceled by clicking outside if cancelable is true.
     * 
     * This version returns immediately with the current status. The text
     * value is read from and written to the provided StringPointer.
     * 
     * @param title Dialog window title
     * @param message Message to display
     * @param value Pointer to the text value
     * @param placeholder Placeholder text for empty field
     * @param cancelable Allow closing by clicking outside
     * @param ok Custom "OK" button text
     * @param cancel Custom "Cancel" button text
     * @param width Dialog width in pixels
     * @param height Dialog height in pixels
     * @param key Optional unique key for persistent dialogs
     * @return Current dialog status
     */
    public extern inline static overload function prompt(
        title:String,
        message:String,
        value:StringPointer,
        ?placeholder:String,
        cancelable:Bool = false,
        ?ok:String, ?cancel:String,
        width:Float = DIALOG_WIDTH,
        height:Float = WindowData.DEFAULT_HEIGHT,
        ?key:String):PromptStatus {

        return _prompt(
            key != null ? key : title,
            title,
            message,
            value,
            placeholder,
            cancelable,
            ok, cancel,
            width,
            height,
            false,
            null
        );

    }

    /**
     * Shows a text input dialog (async version).
     * 
     * Displays a modal dialog with a text field and OK/Cancel buttons.
     * The dialog can be canceled by clicking outside if cancelable is true.
     * 
     * This version shows the dialog and calls the callback when the
     * user clicks OK. The callback receives the entered text. Canceling
     * the dialog does not call the callback.
     * 
     * @param title Dialog window title
     * @param message Message to display
     * @param placeholder Placeholder text for empty field
     * @param cancelable Allow closing by clicking outside
     * @param ok Custom "OK" button text
     * @param cancel Custom "Cancel" button text
     * @param width Dialog width in pixels
     * @param height Dialog height in pixels
     * @param callback Called with entered text when OK is clicked
     */
    public extern inline static overload function prompt(
        title:String,
        message:String,
        ?placeholder:String,
        cancelable:Bool = false,
        ?ok:String, ?cancel:String,
        width:Float = DIALOG_WIDTH,
        height:Float = WindowData.DEFAULT_HEIGHT,
        callback:(text:String)->Void) {

        _prompt(
            null,
            title,
            message,
            null,
            placeholder,
            cancelable,
            ok, cancel,
            width,
            height,
            true,
            callback
        );

    }

    static function _prompt(
        key:String,
        title:String,
        message:String,
        value:StringPointer,
        placeholder:String,
        cancelable:Bool = false,
        ?ok:String, ?cancel:String,
        width:Float = DIALOG_WIDTH,
        height:Float = WindowData.DEFAULT_HEIGHT,
        async:Bool, callback:(text:String)->Void):PromptStatus {

        initIfNeeded();

        if (ok == null)
            ok = OK;

        var prompt:PendingDialog = null;

        if (key != null) {
            key = extractId(key);
            for (i in 0..._pendingDialogs.length) {
                var existing = _pendingDialogs.unsafeGet(i);
                if (existing.key == key) {
                    prompt = existing;
                    break;
                }
            }
        }

        if (prompt == null) {
            prompt = new PendingDialog(
                key, title, message, true, value, placeholder, cancelable && cancel != null ? [ok, cancel] : [ok], cancelable, width, height, async, function(index, text) {
                    if (prompt.chosenIndex != -1 || prompt.canceled)
                        return;

                    prompt.chosenIndex = index;
                    if (callback != null) {
                        var cb = callback;
                        callback = null;
                        cb(Im.readString(prompt.promptPointer));
                    }
                }
            );

            input.onKeyDown(prompt, function(key) {
                if (prompt.chosenIndex != -1 || prompt.canceled)
                    return;

                if (prompt.cancelable && key.scanCode == ESCAPE) {

                    prompt.canceled = true;
                    callback = null;

                    if (prompt.async) {
                        _pendingDialogs.remove(prompt);
                        prompt.destroy();
                    }
                }
            });

            _pendingDialogs.push(prompt);
        }
        else {
            prompt.title = title;
            prompt.message = message;

            prompt.promptPlaceholder = placeholder;
            if (value != null)
                prompt.promptPointer = value;

            var hasSameChoices = true;
            if (cancel != null) {
                if (prompt.choices.length != 2)
                    hasSameChoices = false;
                else if (prompt.choices[0] != ok || prompt.choices[1] != cancel)
                    hasSameChoices = false;
            }
            else {
                if (prompt.choices.length != 1)
                    hasSameChoices = false;
                else if (prompt.choices[0] != ok)
                    hasSameChoices = false;
            }
            if (!hasSameChoices) {
                prompt.choices = [ok, cancel];
            }

            prompt.cancelable = cancelable;
            prompt.width = width;
            prompt.height = height;
        }

        var status = new PromptStatus(
            prompt.canceled ? -2 : prompt.chosenIndex
        );

        if (!prompt.async && status.complete) {
            _pendingDialogs.remove(prompt);
            prompt.destroy();
        }

        return status;

    }

    /**
     * Shows a multiple choice dialog (synchronous version).
     * 
     * Displays a modal dialog with multiple buttons for each choice.
     * The dialog can be canceled by clicking outside if cancelable is true.
     * 
     * This version returns immediately with the current status. Use
     * the returned ChoiceStatus to check which choice was selected.
     * 
     * @param title Dialog window title
     * @param message Message to display
     * @param cancelable Allow closing by clicking outside
     * @param choices Array of choice button labels
     * @param width Dialog width in pixels
     * @param height Dialog height in pixels
     * @param key Optional unique key for persistent dialogs
     * @return Current dialog status with selected index
     */
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

    /**
     * Shows a multiple choice dialog (async version).
     * 
     * Displays a modal dialog with multiple buttons for each choice.
     * The dialog can be canceled by clicking outside if cancelable is true.
     * 
     * This version shows the dialog and calls the callback when the
     * user makes a choice. The callback receives the selected index
     * and the choice text. Canceling does not call the callback.
     * 
     * @param title Dialog window title
     * @param message Message to display
     * @param cancelable Allow closing by clicking outside
     * @param choices Array of choice button labels
     * @param width Dialog width in pixels
     * @param height Dialog height in pixels
     * @param callback Called with index and text of selected choice
     */
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

        initIfNeeded();

        assert(choices != null, 'Choices array must not be null');

        if (height == WindowData.DEFAULT_HEIGHT && choices.length >= 8) {
            height = DIALOG_OVERFLOW_HEIGHT;
        }

        var choice:PendingDialog = null;

        if (key != null) {
            key = extractId(key);
            for (i in 0..._pendingDialogs.length) {
                var existing = _pendingDialogs.unsafeGet(i);
                if (existing.key == key) {
                    choice = existing;
                    break;
                }
            }
        }

        if (choice == null) {
            choice = new PendingDialog(
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
                        _pendingDialogs.remove(choice);
                        choice.destroy();
                    }
                }
            });

            _pendingDialogs.push(choice);
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
            _pendingDialogs.remove(choice);
            choice.destroy();
        }

        return status;

    }

/// Helpers

    static function _posInfosToString(pos:haxe.PosInfos):String {

        if (pos == null) {
            return '?';
        }
        else {
            return pos.fileName + ':' + pos.lineNumber;
        }

    }

    /**
     * Generates a unique handle for storing values.
     * 
     * Handles provide a way to store values that persist across frames
     * without explicitly creating pointers. The handle is unique per
     * source location and occurrence within a frame.
     * 
     * Used internally by the pointer macros (Im.bool(), Im.int(), etc.)
     * to create implicit storage locations.
     * 
     * @param pos Source position info (auto-provided)
     * @return A unique handle identifier
     */
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

    inline public static function readEnumValue(enumValuePointer:EnumValuePointer):Dynamic {

        var func:Dynamic = enumValuePointer;
        return func(null, false);

    }

    inline public static function writeEnumValue(enumValuePointer:EnumValuePointer, value:Dynamic):Void {

        var func:Dynamic = enumValuePointer;
        func(value, value == null);

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
                        var handle = elements.Im.handle(#if !completion $v{posInfos} #end);
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
                        var handle = elements.Im.handle(#if !completion $v{posInfos} #end);
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

    macro public static function int(?value:ExprOf<Int>):ExprOf<elements.IntPointer> {

        return switch value.expr {
            case EConst(CIdent('null')):
                var pos = Context.getPosInfos(Context.currentPos());
                var posInfos = _posInfosFromFileAndChar(pos.file, pos.min);
                macro {
                    var handle = elements.Im.handle(#if !completion $v{posInfos} #end);
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
                    var handle = elements.Im.handle(#if !completion $v{posInfos} #end);
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

    // #if !(completion || display)
    // macro public static function beginTabs(?value:Expr):Expr {

    //     return switch value.expr {
    //         case EConst(CIdent('null')):
    //             macro @:privateAccess elements.Im._beginTabs(Im.string());
    //         case _:
    //             macro @:privateAccess elements.Im._beginTabs($value);
    //     }

    //     return macro null;

    // }
    // #end

    macro public static function string(?value:ExprOf<String>):Expr {

        if (Context.defined('cs')) {
            // C# target and its quirks...
            return switch value.expr {
                case EConst(CIdent('null')):
                    var pos = Context.getPosInfos(Context.currentPos());
                    var posInfos = _posInfosFromFileAndChar(pos.file, pos.min);
                    macro {
                        var handle = elements.Im.handle(#if !completion $v{posInfos} #end);
                        function(?_val:String, ?erase:Dynamic):String {
                            return _val != null || erase ? elements.Im.setStringAtHandle(handle, _val) : elements.Im.stringAtHandle(handle);
                        };
                    }
                case _:
                    macro function(?_val:String, ?erase:Dynamic):String {
                        return _val != null || erase ? $value = _val : $value;
                    };
            }
        }
        else {
            return switch value.expr {
                case EConst(CIdent('null')):
                    var pos = Context.getPosInfos(Context.currentPos());
                    var posInfos = _posInfosFromFileAndChar(pos.file, pos.min);
                    macro {
                        var handle = elements.Im.handle(#if !completion $v{posInfos} #end);
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

    }

    macro public static function float(?value:ExprOf<Float>):Expr {

        return switch value.expr {
            case EConst(CIdent('null')):
                var pos = Context.getPosInfos(Context.currentPos());
                var posInfos = _posInfosFromFileAndChar(pos.file, pos.min);
                macro {
                    var handle = elements.Im.handle(#if !completion $v{posInfos} #end);
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
                    var handle = elements.Im.handle(#if !completion $v{posInfos} #end);
                    function(?_val:Array<Dynamic>, ?erase:Bool):Array<Dynamic> {
                        return _val != null || erase ? elements.Im.setArrayAtHandle(handle, _val) : elements.Im.arrayAtHandle(handle);
                    };
                }
            case _:
                macro function(?_val:Array<Dynamic>, ?erase:Bool):Array<Dynamic> {
                    return _val != null || erase ? $value = cast _val : $value;
                };
        }

    }

    macro public static function enumValue<T>(value:Expr):ExprOf<EnumValuePointer> {

        if (Context.defined('cs')) {
            // C# target and its quirks...
            switch value.expr {
                case _:
                    var enumType = Context.typeExpr(value).t.follow();
                    switch enumType {
                        case TEnum(t, params):
                            return macro function(?_val:Dynamic, ?erase:Dynamic):Dynamic {
                                return _val != null || erase ? $value = _val : $value;
                            };
                        case TAbstract(t, params):
                            return macro function(?_val:Dynamic, ?erase:Dynamic):Dynamic {
                                return _val != null || erase ? $value = _val : $value;
                            };
                        case _:
                            return macro null;
                    }
                    return macro null;
            }
        }
        else {
            switch value.expr {
                case _:
                    var enumType = Context.typeExpr(value).t.follow();
                    switch enumType {
                        case TEnum(t, params):
                            return macro function(?_val:Dynamic, ?erase:Bool):Dynamic {
                                return _val != null || erase ? $value = _val : $value;
                            };
                        case TAbstract(t, params):
                            return macro function(?_val:Dynamic, ?erase:Bool):Dynamic {
                                return _val != null || erase ? $value = _val : $value;
                            };
                        case _:
                            return macro null;
                    }
                    return macro null;
            }
        }

    }

    macro public static function enumAbstract(value:Expr):Expr {

        var type = Context.getType(value.toString()).follow();
        switch type {
            case TAbstract(_.get() => ab, _) if (ab.meta.has(":enum")):
                var fieldExprs = [];
                var valueExprs = [];
                for (field in ab.impl.get().statics.get()) {
                    if (field.meta.has(":enum") && field.meta.has(":impl")) {
                        var fieldName = field.name;
                        fieldExprs.push(macro $v{fieldName});
                        valueExprs.push(macro $value.$fieldName);
                    }
                }
                return macro new elements.EnumAbstractInfo($a{fieldExprs}, $a{valueExprs});
            default:
        }
        return macro null;

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
