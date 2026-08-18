package tools;

import haxe.io.Path;
import tools.Context;
import tools.Helpers.*;
import tools.Helpers;

@:keep
class ImGuiPlugin {

/// Tools

    public function new() {}

    public function init(context:Context):Void {

        // Add tasks
        context.addTask('imgui setup web', new tools.tasks.imgui.SetupJS());
        context.addTask('imgui setup unity', new tools.tasks.imgui.SetupUnity());

    }

    public function extendProject(project:Project):Void {

        // Exported projects are kept in sync with the imgui-hx artifacts
        // through build hooks declared in this plugin's ceramic.yml
        // (web: copy dcimgui.js at begin build; unity: copy the DCImGui C#
        // shim + native libs at end build).

    }

}
