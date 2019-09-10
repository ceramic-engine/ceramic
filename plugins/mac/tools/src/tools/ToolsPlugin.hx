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

        // Add tasks
        var tasks = context.tasks;
        tasks.set('mac app', new tools.tasks.mac.Mac());

    } //init

    public function extendProject(project:Project):Void {

        var app = project.app;
        
        // Could be useful later
        /*if (app.mac) {
            app.paths.push(Path.join([context.plugins.get('Mac').path, 'runtime/src']));
        }*/

    } //extendProject

} //ToolsPlugin
