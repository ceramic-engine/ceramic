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

    } //main

/// Tools

    public function new() {}

    public function init(context:Context):Void {

        // Use same context as parent
        Helpers.context = context;

    } //init

    public function extendProject(project:Project):Void {

        var app = project.app;
        
        app.paths.push(Path.join([context.plugins.get('Spine').path, 'runtime/src']));

    } //extendProject

} //ToolsPlugin
