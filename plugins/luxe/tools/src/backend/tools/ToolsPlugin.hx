package tools;

import tools.Tools.*;
import tools.Tools;
import tools.Project;

@:keep
class ToolsPlugin {

    public var backendName = 'luxe';

    static function main():Void {
        
        var module:Dynamic = js.Node.module;
        module.exports = new ToolsPlugin();

    } //main

/// Tools

    public function new() {}

    public function init(tools:Tools):Void {

        // Extend tools here
        var tasks = shared.tasks;
        
        tasks.set('$backendName targets', new tools.tasks.Targets());
        tasks.set('$backendName setup', new tools.tasks.Setup());
        tasks.set('$backendName hxml', new tools.tasks.Hxml());
        tasks.set('$backendName build', new tools.tasks.Build('Build'));
        tasks.set('$backendName run', new tools.tasks.Build('Run'));
        tasks.set('$backendName clean', new tools.tasks.Build('Clean'));
        tasks.set('$backendName assets', new tools.tasks.Assets());
        tasks.set('$backendName icons', new tools.tasks.Icons());
        tasks.set('$backendName update', new tools.tasks.Update());

        tasks.set('$backendName info', new tools.tasks.Info());
        tasks.set('$backendName libs', new tools.tasks.Libs());

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
