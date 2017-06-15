package tools;

import tools.Tools;
import tools.Project;

@:keep
class SpineTools implements ToolsPlugin {

/// Init tools

    static function __init__():Void {
        
        Tools.addPlugin(new SpineTools());

    } //__init__

/// Tools

    public function new() {}

    public function init(tools:Tools):Void {

        // Extend tools here

    } //init

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

} //SpineTools
