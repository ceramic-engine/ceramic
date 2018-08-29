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
        tasks.set('ios bind', new tools.tasks.ios.Bind());
        tasks.set('ios xcode', new tools.tasks.ios.Xcode());
        tasks.set('ios export ipa', new tools.tasks.ios.ExportIPA());
        tasks.set('ios pod install', new tools.tasks.ios.InstallPods());

    } //init

    public function extendProject(project:Project):Void {

        var app = project.app;
        
        if (app.ios) {
            // Do ios stuff
        }

    } //extendProject

} //ToolsPlugin
