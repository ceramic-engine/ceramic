package tools;

import tools.Context;
import tools.Helpers;
import tools.Helpers.*;

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

        // Set backend
        var prevBackend = context.backend;
        context.backend = new backend.tools.BackendTools();

        // Add tasks
        var tasks = context.tasks;
        tasks.set('luxe targets', new tools.tasks.Targets());
        tasks.set('luxe setup', new tools.tasks.Setup());
        tasks.set('luxe hxml', new tools.tasks.Hxml());
        tasks.set('luxe build', new tools.tasks.Build('Build'));
        tasks.set('luxe run', new tools.tasks.Build('Run'));
        tasks.set('luxe clean', new tools.tasks.Build('Clean'));
        tasks.set('luxe assets', new tools.tasks.Assets());
        tasks.set('luxe icons', new tools.tasks.Icons());
        tasks.set('luxe update', new tools.tasks.Update());
        tasks.set('luxe info', new tools.tasks.Info());
        tasks.set('luxe libs', new tools.tasks.Libs());

        // Restore default backend
        context.backend = prevBackend;

    } //init

    /**
    public function extendProject(project:Project):Void {

        var hxml = '';
        var app = project.app;
        
        var hasSpineHaxe = false;
        var appLibs:Array<Dynamic> = app.libs;
        for (lib in appLibs) {
            var libName:String = null;
            var libVersion:String = "*";
            if (Std.is(lib, String)) {
                libName = lib;
            } else {
                for (k in Reflect.fields(lib)) {
                    libName = k;
                    libVersion = Reflect.field(lib, k);
                    break;
                }
            }
            if (libName == 'spinehaxe') {
                hasSpineHaxe = true;
                break;
            }
        }
        if (hasSpineHaxe) {
            hxml += "\n"+'--remap spine:spinehaxe';
        }

    } //extendProject
    **/

} //ToolsPlugin
