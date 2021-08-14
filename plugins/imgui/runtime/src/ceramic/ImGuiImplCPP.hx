package ceramic;

import imguicpp.ImGui;
import ceramic.Shortcuts.*;
import ceramic.UInt8Array;
import clay.graphics.Graphics;

@:headerInclude("imgui_impl_sdl.h")
class ImGuiImplSDL {
    @:keep public static function bind() {}
}

@:headerInclude("imgui_impl_opengl3.h")
class ImGuiImplOpenGl3 {
    @:keep public static function bind() {}
}

class ImGuiImplCPP {

    static var framePending:Bool = false;

    static var didSetTextureFilter:Bool = false;

    static var textureFilter:clay.Types.TextureFilter = NEAREST;

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
