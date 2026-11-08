package tools;

import haxe.Json;
import haxe.io.Path;
import tools.Context;

@:keep
class GlazePlugin {

/// Tools

    public function new() {}

    public function init(context:Context):Void {

        // Add tasks
        context.addTask('glaze setup onig-wasm', new tools.tasks.glaze.SetupOnigWasm());

    }

    public function extendProject(project:Project):Void {

        // Web exports get onig.wasm and its JavaScript binding (or lose them)
        // through build hooks declared in this plugin's ceramic.yml, depending
        // on the `glaze_onig_wasm` define.

        var app = project.app;
        if (app.plugins == null || !Std.isOfType(app.plugins, Array))
            return;
        var plugins:Array<String> = app.plugins;
        if (plugins.indexOf('glaze') == -1)
            return;

        // The project's icon directories, embedded in the code by IconNameMacro:
        // resources/glaze/icons, then the ones listed in `glaze.icons`
        //
        //   glaze:
        //       icons:
        //           - path/to/more/icons
        var projectDir = Path.directory(app.path);
        var iconPaths = [Path.join([projectDir, 'resources/glaze/icons'])];
        var config:Dynamic = Reflect.field(app, 'glaze');
        if (config != null && Std.isOfType(config.icons, Array)) {
            var icons:Array<Dynamic> = config.icons;
            for (icon in icons) {
                var path = '' + icon;
                iconPaths.push(Path.normalize(Path.isAbsolute(path) ? path : Path.join([projectDir, path])));
            }
        }
        Reflect.setField(app.defines, 'glaze_icons_paths', Json.stringify(Json.stringify(iconPaths)));

    }

}
