package ceramic;

import js.lib.Uint8Array;
import imguijs.ImGui;
import ceramic.Shortcuts.*;
import clay.graphics.Graphics;

/**
 * JavaScript/WebGL implementation of Dear ImGui integration for Ceramic.
 * This backend uses the emscripten-compiled version of ImGui for web targets.
 * 
 * The implementation handles:
 * - Dynamic loading of ImGui JavaScript modules
 * - WebGL rendering context setup
 * - Custom font loading and texture management
 * - Frame lifecycle management
 * - Input event forwarding between Ceramic and ImGui
 * 
 * @see ImGuiSystem
 */
class ImGuiImplJS {

    /**
     * Reference to the ImGui implementation object loaded from JavaScript.
     * This provides the WebGL-specific rendering functions.
     */
    static var ImGui_Impl(get,never):Dynamic;
    inline static function get_ImGui_Impl():Dynamic return untyped window.ImGui_Impl;

    /**
     * ImGui IO structure for handling input and configuration.
     */
    static var io:ImGuiIO = null;

    /**
     * Whether a frame is currently being rendered.
     * Used to prevent multiple calls to endFrame() without a matching newFrame().
     */
    static var framePending:Bool = false;

    #if imgui_font
    /**
     * Reference to the loaded custom font.
     * Used to push/pop the font during frame rendering.
     */
    static var imFont:ImFont;
    #end

    /**
     * Initializes the ImGui JavaScript implementation.
     * Loads the required JavaScript modules and sets up the WebGL backend.
     * @param done Callback invoked when initialization is complete
     */
    public static function init(done:()->Void):Void {

        loadImGui(done);

    }

    /**
     * Dynamically loads a JavaScript file.
     * @param src The URL of the script to load
     * @param done Callback with success status (true if loaded successfully)
     */
    static function loadScript(src:String, done:Bool->Void) {

        var didCallDone = false;

        var script = js.Browser.document.createScriptElement();
        script.setAttribute('type', 'text/javascript');
        script.addEventListener('load', function() {
            if (didCallDone) return;
            didCallDone = true;
            done(true);
        });
        script.addEventListener('error', function() {
            if (didCallDone) return;
            didCallDone = true;
            done(false);
        });
        script.setAttribute('src', src);
        
        js.Browser.document.head.appendChild(script);

    }

    /**
     * Loads the ImGui JavaScript modules in sequence.
     * First loads the main ImGui module, then the implementation module.
     * @param done Callback invoked when both modules are loaded and initialized
     */
    static function loadImGui(done:()->Void) {

        loadScript('./imgui.umd.js', function(_) {
            loadScript('./imgui_impl.umd.js', function(_) {
                Reflect.field(untyped window.ImGui, 'default')().then(function() {
                    initImGui(done);
                }, function() {
                    log.error('Failed to load ImGui bindings');
                });
            });
        });

    }

    /**
     * Initializes ImGui after the JavaScript modules are loaded.
     * Creates the context, sets up the style, and initializes the WebGL backend.
     * @param done Callback invoked when initialization is complete
     */
    static function initImGui(done:()->Void) {

        var canvas = clay.Clay.app.runtime.window;

        ImGui.createContext();
        ImGui.styleColorsDark();
        ImGui_Impl.Init(canvas);

        io = ImGui.getIO();

        #if imgui_font
        loadFont();
        #else
        Graphics.bindTexture2d(io.fonts.texID);
        Graphics.setTexture2dMagFilter(NEAREST);
        Graphics.setTexture2dMinFilter(NEAREST);
        #end

        done();

    }

    #if imgui_font
    /**
     * Loads a custom TrueType font for ImGui.
     * The font is specified via the `imgui_font` compile-time define.
     * The font texture is created and uploaded to the GPU with LINEAR filtering
     * for better quality at different scales.
     */
    static function loadFont() {

        var font = app.assets.bytes(ceramic.macros.DefinesMacro.getDefine('imgui_font'));
        var io = ImGui.getIO();

        var fontData = new js.lib.Uint8Array(font.getData());
        imFont = js.Syntax.code('{0}.AddFontFromMemoryTTF({1}, {2})', io.fonts, fontData.buffer, Math.round(14 / 0.75));
        var texData = js.Syntax.code('{0}.GetTexDataAsRGBA32()', io.fonts);
        var texDataPixels:js.lib.Uint8ClampedArray = texData.pixels;
        var width:Int = texData.width;
        var height:Int = texData.height;
        var buffer = new UInt8Array(width * height * 4);
        for (i in 0...width * height * 4) {
            buffer[i] = texDataPixels[i];
        }
        var texture:clay.graphics.Texture = app.backend.textures.createTexture(
            width,
            height,
            buffer
        );
        io.fonts.setTexID(texture.textureId);
        io.fontGlobalScale = 0.75;

        Graphics.bindTexture2d(io.fonts.texID);
        Graphics.setTexture2dMagFilter(LINEAR);
        Graphics.setTexture2dMinFilter(LINEAR);

    }
    #end

    /**
     * Begins a new ImGui frame.
     * Must be called before any ImGui drawing commands.
     * This method:
     * - Initializes the WebGL backend for the new frame with current time
     * - Starts the ImGui frame
     * - Pushes the custom font if one is loaded
     */
    public static function newFrame():Void {

        ImGui_Impl.NewFrame(Timer.now * 1000);
        ImGui.newFrame();
        #if imgui_font
        ImGui.pushFont(imFont);
        #end

        framePending = true;

    }

    /**
     * Ends the current ImGui frame and renders it.
     * Must be called after all ImGui drawing commands for the frame.
     * This method:
     * - Pops the custom font if one was pushed
     * - Finalizes the ImGui frame
     * - Renders the draw data using WebGL
     * - Updates input capture flags to prevent Ceramic from processing
     *   events when ImGui wants to capture them
     */
    public static function endFrame():Void {

        if (!framePending) return;
        framePending = false;

        #if imgui_font
        ImGui.popFont();
        #end
        ImGui.endFrame();
        ImGui.render();

        ImGui_Impl.RenderDrawData(ImGui.getDrawData());

        clay.Clay.app.runtime.skipKeyboardEvents = io.wantCaptureKeyboard;
        clay.Clay.app.runtime.skipMouseEvents = io.wantCaptureMouse;

    }

}
