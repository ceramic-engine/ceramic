package ceramic;

import js.lib.Uint8Array;
import imguijs.ImGui;
import ceramic.Shortcuts.*;
import clay.graphics.Graphics;

class ImGuiImplJS {

    static var ImGui_Impl(get,never):Dynamic;
    inline static function get_ImGui_Impl():Dynamic return untyped window.ImGui_Impl;

    static var io:ImGuiIO = null;

    static var framePending:Bool = false;

    #if imgui_font
    static var imFont:ImFont;
    #end

    public static function init(done:()->Void):Void {

        loadImGui(done);

    }

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

    public static function newFrame():Void {

        ImGui_Impl.NewFrame(Timer.now * 1000);
        ImGui.newFrame();
        #if imgui_font
        ImGui.pushFont(imFont);
        #end

        framePending = true;

    }

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
