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

        //

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
