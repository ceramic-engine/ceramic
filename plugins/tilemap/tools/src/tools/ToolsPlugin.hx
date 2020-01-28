package tools;

import tools.Context;
import tools.Helpers;
import tools.Helpers.*;
import haxe.io.Path;

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
        
        if (app.tilemap) {
            app.paths.push(Path.join([context.plugins.get('Tilemap').path, 'runtime/src']));
            app.editable.push('ceramic.Tilemap');
        }

    }

}
