package tools;

import haxe.io.Path;
import tools.Context;
import tools.Helpers.*;
import tools.Helpers;

@:keep
class ToolsPlugin {

    static function main():Void {

        var module:Dynamic = js.Node.module;
        module.exports = new ToolsPlugin();

    }

/// Tools

    public function new() {}

    public function init(context:Context):Void {

        // Use same context as parent
        Helpers.context = context;

        // Add tasks
        var tasks = context.tasks;
        //tasks.set('tilemap export', new tools.tasks.tilemap.ExportTilemap());

    }

    public function extendProject(project:Project):Void {

        var app = project.app;

        if (app.plugins != null && Std.isOfType(app.plugins, Array)) {
            var plugins:Array<String> = app.plugins;
            if (plugins.indexOf('tilemap') != -1) {
                app.paths.push(Path.join([context.plugins.get('Tilemap').path, 'runtime/src']));
                app.editable.push('ceramic.Tilemap');
            }
        }

    }

}
