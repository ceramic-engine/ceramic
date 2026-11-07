package tools;

import tools.Context;

@:keep
class GpuiPlugin {

/// Tools

    public function new() {}

    public function init(context:Context):Void {

        // Add tasks
        context.addTask('gpui setup onig-wasm', new tools.tasks.gpui.SetupOnigWasm());

    }

    public function extendProject(project:Project):Void {

        // Web exports get onig.wasm and its JavaScript binding (or lose them)
        // through build hooks declared in this plugin's ceramic.yml, depending
        // on the `gpui_onig_wasm` define.

    }

}
