package tools;

import tools.Tools;

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

} //SpineTools
