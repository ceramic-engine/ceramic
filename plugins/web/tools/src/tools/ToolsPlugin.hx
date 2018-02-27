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
        tasks.set('web project', new tools.tasks.web.Web());

    } //init

    public function extendProject(project:Project):Void {

        var app = project.app;
        
        if (app.web) {
            // Do web stuff
        }

    } //extendProject

} //ToolsPlugin
