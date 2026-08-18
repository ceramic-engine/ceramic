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
 * // Optionally specify a custom font (raw TTF bytes; use a `.bin` suffix
 * // so the font plugin does not transform the file into a bitmap font):
 * defines:
 *   imgui_font: "MyFont.ttf.bin"
 *   imgui_font_fallback: "MyFallbackFont.ttf.bin" # optional, merged glyphs (e.g. CJK)
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
            // Custom font specified by the project through the `imgui_font` define
            ceramic.App.app.onceDefaultAssetsLoad(null, function(assets) {
                assets.add('binary:' + ceramic.macros.DefinesMacro.getDefine('imgui_font'));
                #if imgui_font_fallback
                // Optional fallback font merged into the main one (e.g. CJK coverage)
                assets.add('binary:' + ceramic.macros.DefinesMacro.getDefine('imgui_font_fallback'));
                #end
            });
            #elseif !imgui_no_default_font
            // Batteries-included default fonts bundled with the plugin
            // (Roboto-Medium + Kosugi CJK fallback). See ImGuiSystem for loading.
            ceramic.App.app.onceDefaultAssetsLoad(null, function(assets) {
                assets.add('binary:' + ImGuiSystem.DEFAULT_FONT);
                assets.add('binary:' + ImGuiSystem.DEFAULT_FONT_FALLBACK);
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
