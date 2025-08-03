package ceramic;

import ceramic.App;
import ceramic.Shortcuts.*;

using StringTools;

/**
 * Plugin that integrates Dear ImGui (immediate mode GUI) into Ceramic.
 * 
 * Dear ImGui is a bloat-free graphical user interface library for C++.
 * It outputs optimized vertex buffers that you can render anytime in your
 * 3D-pipeline enabled application. It is fast, portable, renderer agnostic
 * and self-contained (no external dependencies).
 * 
 * This plugin provides:
 * - Automatic initialization of ImGui context
 * - Platform-specific backends (C++/OpenGL for native, JavaScript/WebGL for web)
 * - Optional custom font loading via `imgui_font` define
 * - Frame lifecycle management through ImGuiSystem
 * 
 * Usage:
 * ```haxe
 * // In ceramic.yml:
 * plugins:
 *   - imgui
 * 
 * // Optionally specify a custom font:
 * defines:
 *   imgui_font: "assets/fonts/MyFont.ttf"
 * 
 * // In your code:
 * import imguicpp.ImGui; // or imguijs.ImGui for web
 * 
 * // ImGui calls are made between newFrame() and endFrame()
 * // which are handled automatically by ImGuiSystem
 * override function update(delta:Float):Void {
 *     ImGui.begin("My Window");
 *     ImGui.text("Hello from ImGui!");
 *     ImGui.end();
 * }
 * ```
 * 
 * @see ImGuiSystem
 * @see https://github.com/ocornut/imgui
 */
@:access(ceramic.App)
class ImGuiPlugin {

    /**
     * Plugin initialization entry point.
     * Called automatically when the plugin is loaded.
     * Sets up font loading (if specified) and registers the ImGui loader.
     */
    static function pluginInit() {

        App.oncePreInit(function() {

            log.info('Init imgui plugin');

            #if imgui_font
            // Load font for dear imgui
            ceramic.App.app.onceDefaultAssetsLoad(null, function(assets) {
                assets.add('binary:' + ceramic.macros.DefinesMacro.getDefine('imgui_font'));
            });
            #end

            app.loaders.push(initImGui);
            
        });

    }

    /**
     * Initializes the ImGui system.
     * This is registered as a loader to ensure ImGui is ready before the app starts.
     * @param done Callback to invoke when ImGui is fully initialized
     */
    static function initImGui(done:Void->Void):Void {

        ImGuiSystem.shared.start(done);

    }

}
