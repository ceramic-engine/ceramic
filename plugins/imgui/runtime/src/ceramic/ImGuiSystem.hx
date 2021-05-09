package ceramic;

using ceramic.Extensions;

import ceramic.Shortcuts.*;
import clay.opengl.GLGraphics;

#if web

import imguijs.ImGui;

#end

#if cpp

import imguicpp.ImGui;

@:headerInclude("imgui_impl_sdl.h")
class ImGuiImplSDL {
	@:keep public static function bind() {}
}

@:headerInclude("imgui_impl_opengl3.h")
class ImGuiImplOpenGl3 {
	@:keep public static function bind() {}
}

#end

class ImGuiSystem extends System {

    /**
     * Shared imgui system
     */
    @lazy public static var shared = new ImGuiSystem();

    var framePending:Bool = false;

    override function new() {

        super();

        earlyUpdateOrder = 1000;

    }

    #if web

    static var ImGui_Impl(get,never):Dynamic;
    inline static function get_ImGui_Impl():Dynamic return untyped window.ImGui_Impl;

    var io:imguijs.ImGui.ImGuiIO = null;

    @:allow(ceramic.ImGuiPlugin)
    function start(done:()->Void):Void {

        loadImGui(done);

    }

    function loadScript(src:String, done:Bool->Void) {

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

    function loadImGui(done:()->Void) {

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

    function initImGui(done:()->Void) {

        var canvas = clay.Clay.app.runtime.window;

        ImGui.createContext();
        ImGui.styleColorsDark();
        ImGui_Impl.Init(canvas);

        io = ImGui.getIO();

        // Ensure font texture is using NEAREST filtering
        // Note: if in a future version we handle loading custom fonts, we might want to use LINEAR filtering
        GLGraphics.bindTexture2d(io.fonts.texID);
        GLGraphics.setTexture2dMagFilter(NEAREST);
        GLGraphics.setTexture2dMinFilter(NEAREST);
    
        app.onFinishDraw(this, finishDraw);

        done();

    }

    override function earlyUpdate(delta:Float):Void {

		ImGui_Impl.NewFrame(Timer.now * 1000);
        ImGui.newFrame();

        framePending = true;

    }

    function finishDraw():Void {

        if (!framePending) return;
        framePending = false;

        ImGui.endFrame();
        ImGui.render();

        ImGui_Impl.RenderDrawData(ImGui.getDrawData());

		clay.Clay.app.runtime.skipKeyboardEvents = io.wantCaptureKeyboard;
		clay.Clay.app.runtime.skipMouseEvents = io.wantCaptureMouse;

    }

    #end

    #if cpp

    var didSetTextureFilter:Bool = false;

    @:allow(ceramic.ImGuiPlugin)
    function start(done:()->Void):Void {

		ImGuiImplSDL.bind();
		ImGuiImplOpenGl3.bind();

		ImGui.createContext();
		ImGui.styleColorsDark();

		var glContext = clay.Clay.app.runtime.gl;
		var window = clay.Clay.app.runtime.window;

		untyped __cpp__('ImGui_ImplSDL2_InitForOpenGL({0}, {1})', window, glContext);
		untyped __cpp__('ImGui_ImplOpenGL3_Init("#version 120")');

		app.onFinishDraw(this, finishDraw);

        done();

    }

    override function earlyUpdate(delta:Float):Void {

		var window = clay.Clay.app.runtime.window;

		untyped __cpp__('ImGui_ImplOpenGL3_NewFrame()');
		untyped __cpp__('ImGui_ImplSDL2_NewFrame({0})', window);

		ImGui.newFrame();

        if (!didSetTextureFilter) {

            // Ensure font texture is using NEAREST filtering
            // Note: if in a future version we handle loading custom fonts, we might want to use LINEAR filtering
            var io = ImGui.getIO();
            var textureID:clay.Types.TextureId = untyped __cpp__('(int)(long long){0}', io.fonts.texID);
            GLGraphics.bindTexture2d(textureID);
            GLGraphics.setTexture2dMagFilter(NEAREST);
            GLGraphics.setTexture2dMinFilter(NEAREST);

            didSetTextureFilter = true;
        }

        framePending = true;

    }

    function finishDraw():Void {

        if (!framePending) return;
        framePending = false;

        ImGui.endFrame();
		ImGui.render();

		untyped __cpp__('ImGui_ImplOpenGL3_RenderDrawData({0})', ImGui.getDrawData());

        var io = ImGui.getIO();
		clay.Clay.app.runtime.skipKeyboardEvents = io.wantCaptureKeyboard;
		clay.Clay.app.runtime.skipMouseEvents = io.wantCaptureMouse;

    }

    #end

}
