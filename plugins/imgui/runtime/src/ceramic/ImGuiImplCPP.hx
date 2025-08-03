package ceramic;

import imguicpp.ImGui;
import ceramic.Shortcuts.*;
import ceramic.UInt8Array;
import clay.graphics.Graphics;

/**
 * SDL2 backend binding for Dear ImGui.
 * This class is used internally to initialize SDL2-specific ImGui functionality.
 */
@:headerInclude("imgui_impl_sdl.h")
class ImGuiImplSDL {
    /**
     * Binds the SDL2 implementation. This method exists to ensure
     * the header is included during compilation.
     */
    @:keep public static function bind() {}
}

/**
 * OpenGL 3 backend binding for Dear ImGui.
 * This class is used internally to initialize OpenGL-specific ImGui functionality.
 */
@:headerInclude("imgui_impl_opengl3.h")
class ImGuiImplOpenGl3 {
    /**
     * Binds the OpenGL 3 implementation. This method exists to ensure
     * the header is included during compilation.
     */
    @:keep public static function bind() {}
}

/**
 * C++ implementation of Dear ImGui integration for Ceramic.
 * This backend uses SDL2 and OpenGL to render ImGui interfaces.
 * 
 * The implementation handles:
 * - ImGui context initialization with SDL2 and OpenGL backends
 * - Custom font loading and texture management
 * - Frame lifecycle management
 * - Input event forwarding between Ceramic and ImGui
 * 
 * @see ImGuiSystem
 */
class ImGuiImplCPP {

    /**
     * Whether a frame is currently being rendered.
     * Used to prevent multiple calls to endFrame() without a matching newFrame().
     */
    static var framePending:Bool = false;

    /**
     * Whether the texture filter has been set for the font texture.
     * This is done once after the first frame to ensure proper rendering.
     */
    static var didSetTextureFilter:Bool = false;

    /**
     * The texture filter to use for ImGui textures.
     * Defaults to NEAREST for pixel-perfect rendering, but changes to LINEAR
     * when a custom font is loaded.
     */
    static var textureFilter:clay.Types.TextureFilter = NEAREST;

    /**
     * Initializes the ImGui C++ implementation.
     * Sets up SDL2 and OpenGL backends, creates the ImGui context,
     * and optionally loads a custom font.
     * @param done Callback invoked when initialization is complete
     */
    public static function init(done:()->Void):Void {

        ImGuiImplSDL.bind();
        ImGuiImplOpenGl3.bind();

        ImGui.createContext();
        ImGui.styleColorsDark();

        var glContext = clay.Clay.app.runtime.gl;
        var window = clay.Clay.app.runtime.window;

        untyped __cpp__('ImGui_ImplSDL2_InitForOpenGL({0}, {1})', window, glContext);

        #if (ios || tvos || android)
        untyped __cpp__('ImGui_ImplOpenGL3_Init("#version 300 es")');
        #else
        untyped __cpp__('ImGui_ImplOpenGL3_Init("#version 120")');
        #end

        #if imgui_font
        loadFont();
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

        var imFont = io.fonts.addFontFromMemoryTTF(font, font.length, 14 / 0.75);
        untyped __cpp__('unsigned char * pixels;');
        var width:Int = 0;
        var height:Int = 0;
        var bytesPerPixels:Int = 0;
        untyped __cpp__('{0}->GetTexDataAsRGBA32(&pixels, &{1}, &{2}, &{3});', io.fonts, width, height, bytesPerPixels);
        var buffer = new UInt8Array(width * height * 4);
        for (i in 0...width * height * 4) {
            buffer[i] = untyped __cpp__('pixels[{0}]', i);
        }
        var texture:clay.graphics.Texture = app.backend.textures.createTexture(
            width,
            height,
            buffer
        );
        io.fonts.setTexID(untyped __cpp__('(void *)(long long){0}', texture.textureId));
        io.fontGlobalScale = 0.75;
        
        textureFilter = LINEAR;

    }
    #end

    /**
     * Begins a new ImGui frame.
     * Must be called before any ImGui drawing commands.
     * This method:
     * - Initializes the OpenGL and SDL2 backends for the new frame
     * - Starts the ImGui frame
     * - Sets texture filtering on the font texture (first frame only)
     */
    public static function newFrame():Void {

        var window = clay.Clay.app.runtime.window;

        untyped __cpp__('ImGui_ImplOpenGL3_NewFrame()');
        untyped __cpp__('ImGui_ImplSDL2_NewFrame({0})', window);

        ImGui.newFrame();

        if (!didSetTextureFilter) {

            // Ensure font texture is using NEAREST filtering
            // Note: if in a future version we handle loading custom fonts, we might want to use LINEAR filtering
            var io = ImGui.getIO();
            var textureID:clay.Types.TextureId = untyped __cpp__('(int)(long long){0}', io.fonts.texID);
            Graphics.bindTexture2d(textureID);
            Graphics.setTexture2dMagFilter(textureFilter);
            Graphics.setTexture2dMinFilter(textureFilter);

            didSetTextureFilter = true;
        }

        framePending = true;

    }

    /**
     * Ends the current ImGui frame and renders it.
     * Must be called after all ImGui drawing commands for the frame.
     * This method:
     * - Finalizes the ImGui frame
     * - Renders the draw data using OpenGL
     * - Updates input capture flags to prevent Ceramic from processing
     *   events when ImGui wants to capture them
     */
    public static function endFrame():Void {

        if (!framePending) return;
        framePending = false;

        ImGui.endFrame();
        ImGui.render();

        untyped __cpp__('ImGui_ImplOpenGL3_RenderDrawData({0})', ImGui.getDrawData());

        var io = ImGui.getIO();
        clay.Clay.app.runtime.skipKeyboardEvents = io.wantCaptureKeyboard;
        clay.Clay.app.runtime.skipMouseEvents = io.wantCaptureMouse;

    }

}
