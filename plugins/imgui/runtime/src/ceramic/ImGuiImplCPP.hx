package ceramic;

import imguicpp.ImGui;
import ceramic.Shortcuts.*;
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

    public static function init(done:()->Void):Void {

        ImGuiImplSDL.bind();
        ImGuiImplOpenGl3.bind();

        ImGui.createContext();
        ImGui.styleColorsDark();

        var glContext = clay.Clay.app.runtime.gl;
        var window = clay.Clay.app.runtime.window;

        untyped __cpp__('ImGui_ImplSDL2_InitForOpenGL({0}, {1})', window, glContext);
        untyped __cpp__('ImGui_ImplOpenGL3_Init("#version 120")');

        done();

    }

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
            Graphics.setTexture2dMagFilter(NEAREST);
            Graphics.setTexture2dMinFilter(NEAREST);

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
