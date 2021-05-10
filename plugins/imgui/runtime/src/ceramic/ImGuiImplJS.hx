package ceramic;

import imguijs.ImGui;
import ceramic.Shortcuts.*;
import clay.graphics.Graphics;

class ImGuiImplJS {

    static var ImGui_Impl(get,never):Dynamic;
    inline static function get_ImGui_Impl():Dynamic return untyped window.ImGui_Impl;

    static var io:ImGuiIO = null;

    static var framePending:Bool = false;

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

        // Ensure font texture is using NEAREST filtering
        // Note: if in a future version we handle loading custom fonts, we might want to use LINEAR filtering
        Graphics.bindTexture2d(io.fonts.texID);
        Graphics.setTexture2dMagFilter(NEAREST);
        Graphics.setTexture2dMinFilter(NEAREST);

        done();

    }

    public static function newFrame():Void {

        ImGui_Impl.NewFrame(Timer.now * 1000);
        ImGui.newFrame();

        framePending = true;

    }

    public static function endFrame():Void {

        if (!framePending) return;
        framePending = false;

        ImGui.endFrame();
        ImGui.render();

        ImGui_Impl.RenderDrawData(ImGui.getDrawData());

        clay.Clay.app.runtime.skipKeyboardEvents = io.wantCaptureKeyboard;
        clay.Clay.app.runtime.skipMouseEvents = io.wantCaptureMouse;

    }

}
