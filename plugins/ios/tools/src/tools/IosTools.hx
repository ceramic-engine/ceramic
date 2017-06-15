package tools;

import tools.Tools;
import tools.Project;

@:keep
class IosTools implements ToolsPlugin {

/// Init tools

    static function __init__():Void {
        
        Tools.addPlugin(new IosTools());

    } //__init__

/// Tools

    public function new() {}

    public function init(tools:Tools):Void {

        // Extend tools here

    } //init

    public function extendProject(project:Project):Void {

        // Extend project here

    } //extendProject

} //IosTools