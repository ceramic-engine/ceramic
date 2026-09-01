package ceramic;

#if plugin_imgui

import ceramic.Shortcuts.*;
import imgui.ImGui;

using ceramic.Extensions;

/**
 * Dear ImGui integration for ceramic - fully backend-agnostic.
 *
 * Everything goes through ceramic itself, so the SAME code runs on clay
 * (native + web) and unity:
 *  - INPUT: ceramic events are forwarded to ImGui's 1.87+ event queue
 *    (`addMousePosEvent`, `addKeyEvent`, ...), text goes through ceramic's
 *    text input sessions (IME-aware), driven by `io.wantTextInput`.
 *  - FRAME: `newFrame()` at early update (before user code builds its UI in
 *    `update()`), `render()` at late update.
 *  - RENDERING: `ImGuiRenderable` consumes the draw data through the concrete
 *    `backend.Draw` during the normal visuals pass (no imgui_impl_* backend).
 *  - TEXTURES: the 1.92 `ImTextureData` protocol handled with ceramic
 *    textures; `ImTextureID` is a registry key (see `ImGuiTextures`).
 *  - LAYOUT: window positions, sizes and dock nodes are persisted through
 *    ceramic's `PersistentData` instead of ImGui's own `imgui.ini` file (see
 *    `saveLayout()`); opt out with the `imgui_no_persistent_layout` define.
 *
 * Usage stays the same as before: make `ImGui.*` calls anywhere between
 * updates (typically in `update()`); frame boundaries are automatic.
 */
class ImGuiSystem extends System {

    /**
     * Name of the default font bundled with the plugin (Roboto-Medium), used
     * when the project does not provide its own `imgui_font` define.
     */
    public static inline final DEFAULT_FONT:String = 'Roboto-Medium.ttf.bin';

    /**
     * Name of the default fallback font bundled with the plugin (Kosugi,
     * for CJK glyph coverage), merged into the default font.
     */
    public static inline final DEFAULT_FONT_FALLBACK:String = 'Kosugi-Regular.ttf.bin';

    /**
     * Shared ImGui system instance.
     * Automatically created when first accessed.
     */
    @lazy public static var shared = new ImGuiSystem();

    /** True when ImGui wants the mouse (apps should ignore clicks then). */
    public var wantCaptureMouse(default, null):Bool = false;

    /** True when ImGui wants the keyboard. */
    public var wantCaptureKeyboard(default, null):Bool = false;

    /** The renderable that draws ImGui (its `depth` places the UI, default topmost). */
    public var renderable(default, null):ImGuiRenderable = null;

    /**
     * The custom font loaded from the `imgui_font` define (if any).
     * It is also assigned to `io.fontDefault`; use it with
     * `ImGui.pushFontFloat(customFont, size)` for per-window sizes.
     */
    public var customFont(default, null):imgui.ImGuiFonts.ImGuiFontPtr = #if cpp null #else cast 0 #end;

    /**
     * Multiplier applied to ceramic wheel deltas before feeding ImGui.
     * The default (1/24) is calibrated for a comfortable trackpad feel with
     * ceramic's wheel units; raise it if a notched mouse wheel feels too slow.
     */
    public var wheelScale:Float = 1.0 / 24.0;

    /**
     * When enabled (default), the ImGui UI is laid out at the screen's
     * NATIVE size (1 ImGui point = 1 screen point), independently of the
     * app's logical scaling (FIT, FILL...): the game keeps its own scaling
     * while the UI stays at a consistent, crisp size. This is the same
     * behavior as the `elements` plugin's Im UI. Set to `false` to lay out the UI in
     * the app's logical coordinates instead (the previous behavior, where
     * the UI is scaled together with the app content).
     */
    public var nativeScreen:Bool = true;

    /**
     * Id of the `PersistentData` storage holding the ImGui layout (window
     * positions and sizes, dock node tree, collapsed/selected tabs...).
     */
    public static inline final LAYOUT_STORAGE_ID:String = 'imgui-layout';

    /** Key of the ini settings blob inside that storage. */
    static inline final LAYOUT_KEY:String = 'iniSettings';

    var inited:Bool = false;
    var frameStarted:Bool = false;
    var layoutData:PersistentData = null;
    var lastSavedLayout:String = null;
    var textInputActive:Bool = false;
    var lastTextInputText:String = '';
    var blockingDefaultScroll:Bool = false;

    override function new() {

        super();

        // Start the ImGui frame before other systems and user code update.
        earlyUpdateOrder = 1000;
        // Finish (render) the ImGui frame after all user code ran.
        lateUpdateOrder = 10000;

    }

    @:allow(ceramic.ImGuiPlugin)
    function start(done:()->Void):Void {

        #if js

        // Load the emscripten-built dcimgui module (copied into the web
        // project automatically at the end of every web build), then init
        // like any target.
        loadScript('./dcimgui.js', ok -> {
            if (!ok) {
                log.warning('imgui: failed to load dcimgui.js (rebuild, or run: ceramic imgui setup web)');
                done();
                return;
            }
            var factory:Dynamic = js.Syntax.code('DCImGui');
            var promise:js.lib.Promise<Dynamic> = factory();
            promise.then(function(module:Dynamic) {
                imguijs.ImGuiJs.init(module);
                initImGui();
                done();
            });
        });

        #elseif cpp

        initImGui();
        done();

        #elseif cs

        imguics.ImGuiCs.init();
        initImGui();
        done();

        #else

        done();

        #end

    }

    #if js
    static function loadScript(src:String, done:Bool->Void) {
        var script = js.Browser.document.createScriptElement();
        script.setAttribute('type', 'text/javascript');
        script.addEventListener('load', function() done(true));
        script.addEventListener('error', function() done(false));
        script.setAttribute('src', src);
        js.Browser.document.head.appendChild(script);
    }
    #end

    function initImGui():Void {

        #if (cpp || js || cs)

        ImGui.createContext();

        var io = ImGui.getIO();
        // We are a 1.92-style renderer: dynamic textures (font atlas pages are
        // delivered through draw data) + large-mesh vertex offsets.
        io.backendFlags = io.backendFlags
            | ImGuiBackendFlags.RendererHasTextures
            | ImGuiBackendFlags.RendererHasVtxOffset;
        io.configFlags = io.configFlags | ImGuiConfigFlags.DockingEnable;

        // Persist the layout through ceramic instead of ImGui's own file IO.
        // Opt out with the `imgui_no_persistent_layout` define.
        #if !imgui_no_persistent_layout
        initLayoutPersistence();
        #end

        // Apply ceramic's default ImGui theme (a dark blue style, nicer than
        // the built-in default). Opt out with the `imgui_no_default_theme` define.
        #if !imgui_no_default_theme
        imgui.ImGuiThemes.applyDarkBlue();
        #end

        bindInput();

        // Route ImGui's clipboard (copy/paste in InputText etc.) through
        // ceramic's clipboard backend, on native AND web: the backend itself
        // picks the best channel (Electron's clipboard module when running
        // under electron, an internal fallback in a plain browser - the
        // browser clipboard API being async/permission-gated).
        imgui.ImGuiClipboard.setHandlers(
            () -> app.backend.clipboard.getText(),
            text -> app.backend.clipboard.setText(text)
        );

        #if web
        // Native builds detect macOS at compile time and switch ImGui to the
        // mac conventions (Cmd instead of Ctrl for copy/paste/select-all...).
        // The wasm build cannot, so a mac host must be detected at runtime.
        // Without this, Cmd+V does nothing in input fields on web.
        try {
            final hostPlatform:String = js.Syntax.code("(navigator.platform || '')");
            if (hostPlatform.indexOf('Mac') != -1) {
                var io = ImGui.getIO();
                io.configMacOSXBehaviors = true;
            }
        }
        catch (e:Dynamic) {}
        #end

        renderable = new ImGuiRenderable();
        renderable.active = true;

        inited = true;

        // Default font. If the project sets the `imgui_font` define, that TTF is
        // used; otherwise the fonts bundled with the plugin (Roboto-Medium +
        // Kosugi CJK fallback) are used, giving a clean look out of the box.
        // Opt out of the bundled default with the `imgui_no_default_font` define.
        // Both are registered as binary assets by ImGuiPlugin and loaded with the
        // default assets; fonts are dynamic in ImGui 1.92, so adding one after
        // init is fine.
        #if imgui_font
        loadFont(
            ceramic.macros.DefinesMacro.getDefine('imgui_font'),
            #if imgui_font_fallback ceramic.macros.DefinesMacro.getDefine('imgui_font_fallback') #else null #end
        );
        #elseif !imgui_no_default_font
        loadFont(DEFAULT_FONT, DEFAULT_FONT_FALLBACK);
        #end

        #end

    }

    #if (cpp || js || cs)
    /**
     * Load `fontId` as the default ImGui font and, if `fallbackId` is provided,
     * merge its glyphs (e.g. CJK) into it. Both are binary asset names.
     */
    function loadFont(fontId:String, ?fallbackId:String):Void {

        ceramic.App.app.onceReady(null, function() {
            var bytes = ceramic.App.app.assets.bytes(fontId);
            if (bytes != null) {
                customFont = imgui.ImGuiFonts.addFontFromBytes(bytes);
                var io = ImGui.getIO();
                io.fontDefault = customFont;

                if (fallbackId != null) {
                    // Merge fallback glyphs (e.g. CJK) into the font we just added
                    var fallbackBytes = ceramic.App.app.assets.bytes(fallbackId);
                    if (fallbackBytes != null) {
                        imgui.ImGuiFonts.addFontFromBytes(fallbackBytes, 0.0, true);
                    }
                    else {
                        log.warning('imgui: could not read fallback font bytes for ' + fallbackId);
                    }
                }
            }
            else {
                log.warning('imgui: could not read font bytes for ' + fontId);
            }
        });

    }
    #end

    // =========================================================================
    // Layout persistence
    // =========================================================================

    #if (cpp || js || cs)
    /**
     * Take over ImGui's ini settings and store them through ceramic.
     *
     * Left alone, ImGui reads and writes `imgui.ini` in the process working
     * directory: inside the bundle for a packaged mac app (where a stale file
     * silently overrides every `FirstUseEver` position), and nowhere at all on
     * web. `PersistentData` goes through `app.backend.io`, so the layout lands
     * where the backend puts save data on every target, web included.
     */
    function initLayoutPersistence():Void {

        imgui.ImGuiIniSettings.disable();

        layoutData = new PersistentData(LAYOUT_STORAGE_ID);

        var iniSettings:String = layoutData.get(LAYOUT_KEY);
        if (iniSettings != null && iniSettings != '') {
            lastSavedLayout = iniSettings;
            // Must happen before the first frame, like ImGui's own ini loading
            ImGui.loadIniSettingsFromMemory(iniSettings);
        }

        // ImGui only raises `wantSaveIniSettings` every `io.iniSavingRate`
        // seconds (5 by default), so a quit right after a window move would
        // otherwise lose it.
        app.onTerminate(this, saveLayout);

    }
    #end

    /**
     * Write the current ImGui layout to persistent storage now.
     *
     * Called automatically when ImGui reports the layout changed and when the
     * app terminates; call it explicitly to save at another moment (before a
     * scene switch, on window blur...). No-op when layout persistence is off.
     */
    public function saveLayout():Void {

        #if (cpp || js || cs)
        if (layoutData == null) return;

        var iniSettings = ImGui.saveIniSettingsToMemory();
        if (iniSettings == null) iniSettings = '';
        // ImGui flags the layout dirty more eagerly than it actually changes
        if (iniSettings == lastSavedLayout) return;

        lastSavedLayout = iniSettings;
        layoutData.set(LAYOUT_KEY, iniSettings);
        layoutData.save();
        #end

    }

    /**
     * Forget the persisted layout, so the next run starts from the app's
     * default arrangement again (see `imgui.ImGuiDockBuilder` to build one).
     *
     * This does not rearrange the live windows: pair it with a rebuild of the
     * layout, or with a restart.
     */
    public function clearLayout():Void {

        #if (cpp || js || cs)
        if (layoutData == null) return;

        lastSavedLayout = null;
        layoutData.remove(LAYOUT_KEY);
        layoutData.save();
        #end

    }

    // =========================================================================
    // Frame lifecycle
    // =========================================================================

    override function earlyUpdate(delta:Float):Void {

        #if (cpp || js || cs)
        if (!inited) return;

        var io = ImGui.getIO();
        if (nativeScreen) {
            // The UI is laid out in native screen points, whatever the
            // app's logical scaling is (see `nativeScreen` doc)
            io.displaySize = ImVec2.make(screen.nativeWidth, screen.nativeHeight);
            io.displayFramebufferScale = ImVec2.make(screen.nativeDensity, screen.nativeDensity);
        }
        else {
            io.displaySize = ImVec2.make(screen.width, screen.height);
            io.displayFramebufferScale = ImVec2.make(screen.texturesDensity, screen.texturesDensity);
        }
        io.deltaTime = delta > 0 ? delta : 1.0 / 60.0;

        ImGui.newFrame();
        frameStarted = true;
        #end

    }

    override function lateUpdate(delta:Float):Void {

        #if (cpp || js || cs)
        if (!inited || !frameStarted) return;
        frameStarted = false;

        ImGui.render();

        var io = ImGui.getIO();
        wantCaptureMouse = io.wantCaptureMouse;
        wantCaptureKeyboard = io.wantCaptureKeyboard;

        #if ceramic_auto_block_default_scroll
        // While ImGui wants the mouse (pointer over/interacting with the UI),
        // flag ourselves as blocking default scroll, like ceramic's Scroller
        // does: on web, this keeps the page from scrolling when the user
        // scrolls inside an ImGui window.
        if (wantCaptureMouse != blockingDefaultScroll) {
            blockingDefaultScroll = wantCaptureMouse;
            if (blockingDefaultScroll) {
                app.numBlockingDefaultScroll++;
            }
            else {
                app.numBlockingDefaultScroll--;
            }
        }
        #end

        if (io.wantSaveIniSettings) {
            io.wantSaveIniSettings = false;
            saveLayout();
        }

        updateTextInputSession(io.wantTextInput);

        // Sweep visuals displayed through ImGuiVisuals (release unused entries)
        ImGuiVisuals.endFrame();

        // Renderable dependencies may have changed (new font pages, user images).
        renderable.usedTexturesDirty = true;

        // NOTE: unlike the old imgui_impl_sdl integration, we must NOT use clay's
        // skipMouseEvents/skipKeyboardEvents here: ImGui is FED by ceramic's events
        // now, so skipping them would starve ImGui itself (captured once → dead
        // input forever). Apps that want to ignore UI-consumed input should check
        // `wantCaptureMouse` / `wantCaptureKeyboard` instead.
        #end

    }

    // =========================================================================
    // Coordinate conversion (ceramic logical space <-> ImGui space)
    // =========================================================================

    /**
     * Convert a position in ceramic's logical screen coordinates to ImGui
     * coordinates (native screen points when `nativeScreen` is enabled,
     * identical coordinates otherwise).
     */
    public function screenToImGuiX(x:Float, y:Float):Float {
        if (!nativeScreen) return x;
        var matrix = @:privateAccess screen.matrix;
        return matrix.transformX(x, y) / screen.nativeDensity;
    }

    /** @see screenToImGuiX */
    public function screenToImGuiY(x:Float, y:Float):Float {
        if (!nativeScreen) return y;
        var matrix = @:privateAccess screen.matrix;
        return matrix.transformY(x, y) / screen.nativeDensity;
    }

    /**
     * Convert a position in ImGui coordinates back to ceramic's logical
     * screen coordinates.
     */
    public function imGuiToScreenX(x:Float, y:Float):Float {
        if (!nativeScreen) return x;
        var density = screen.nativeDensity;
        var reverseMatrix = @:privateAccess screen.reverseMatrix;
        return reverseMatrix.transformX(x * density, y * density);
    }

    /** @see imGuiToScreenX */
    public function imGuiToScreenY(x:Float, y:Float):Float {
        if (!nativeScreen) return y;
        var density = screen.nativeDensity;
        var reverseMatrix = @:privateAccess screen.reverseMatrix;
        return reverseMatrix.transformY(x * density, y * density);
    }

    // =========================================================================
    // Input bridge (ceramic events → ImGui event queue)
    // =========================================================================

    function bindInput():Void {

        #if (cpp || js || cs)

        screen.onMouseMove(this, (x, y) -> {
            var io = ImGui.getIO();
            ImGuiIO.addMousePosEvent(io, screenToImGuiX(x, y), screenToImGuiY(x, y));
        });
        screen.onMouseDown(this, (buttonId, x, y) -> {
            var io = ImGui.getIO();
            ImGuiIO.addMousePosEvent(io, screenToImGuiX(x, y), screenToImGuiY(x, y));
            ImGuiIO.addMouseButtonEvent(io, imguiMouseButton(buttonId), true);
        });
        screen.onMouseUp(this, (buttonId, x, y) -> {
            var io = ImGui.getIO();
            ImGuiIO.addMouseButtonEvent(io, imguiMouseButton(buttonId), false);
        });
        screen.onMouseWheel(this, (x, y) -> {
            var io = ImGui.getIO();
            // ceramic wheel: positive y scrolls down; ImGui expects positive = up.
            ImGuiIO.addMouseWheelEvent(io, -x * wheelScale, -y * wheelScale);
        });

        input.onKeyDown(this, key -> forwardKey(key, true));
        input.onKeyUp(this, key -> forwardKey(key, false));

        app.textInput.onUpdate(this, handleTextInputUpdate);

        // Losing focus eats the matching key-up events, for instance when
        // switching apps with a modifier held. Tell ImGui about it, so that
        // it clears its pressed keys and modifiers. Without this, a stuck
        // Shift silently turns every mouse wheel into a horizontal scroll
        // until Shift is pressed again.
        app.onBeginEnterBackground(this, () -> {
            ImGuiIO.addFocusEvent(ImGui.getIO(), false);
        });
        #if web
        // On web, background/FOCUS_LOST only fires when the page is hidden.
        // A plain window blur, like an app switch that keeps the page
        // visible, is reported by nothing else, so listen to it directly.
        js.Browser.window.addEventListener('blur', _ -> {
            if (!ceramic.App.app.destroyed) ImGuiIO.addFocusEvent(ImGui.getIO(), false);
        });
        #end

        #end

    }

    function forwardKey(key:Key, down:Bool):Void {

        #if (cpp || js || cs)
        var io = ImGui.getIO();
        var mod = ImGuiKeyMap.modFromScanCode(key.scanCode);
        if (mod != ImGuiKey.None) {
            ImGuiIO.addKeyEvent(io, mod, down);
        }
        var imKey = ImGuiKeyMap.fromScanCode(key.scanCode);
        if (imKey != ImGuiKey.None) {
            ImGuiIO.addKeyEvent(io, imKey, down);
        }
        #end

    }

    static function imguiMouseButton(buttonId:Int):Int {

        // ceramic: LEFT=0, MIDDLE=1, RIGHT=2 → ImGui: left=0, right=1, middle=2
        return switch buttonId {
            case MouseButton.MIDDLE: 2;
            case MouseButton.RIGHT: 1;
            case _: 0;
        }

    }

    /**
     * Characters flow through ceramic's text input sessions (IME-aware): we
     * open a session while ImGui wants text, and forward what gets typed by
     * diffing the session buffer (editing keys are handled by ImGui itself
     * through the key events).
     */
    function updateTextInputSession(want:Bool):Void {

        #if (cpp || js || cs)
        if (want && !textInputActive) {
            textInputActive = true;
            lastTextInputText = '';
            app.textInput.start('', 0, 0, screen.width, screen.height);
        }
        else if (!want && textInputActive) {
            textInputActive = false;
            app.textInput.stop();
        }
        #end

    }

    function handleTextInputUpdate(text:String):Void {

        #if (cpp || js || cs)
        if (!textInputActive) return;

        // Forward appended characters only (deletions & cursor moves are
        // ImGui's own business, driven by the forwarded key events).
        if (text.length > lastTextInputText.length && StringTools.startsWith(text, lastTextInputText)) {
            var appended = text.substr(lastTextInputText.length);
            var io = ImGui.getIO();
            ImGuiIO.addInputCharactersUTF8(io, appended);
        }
        lastTextInputText = text;
        #end

    }

}

#end
