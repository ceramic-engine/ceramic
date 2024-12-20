package tools.spec;

import tools.Ide;

typedef ToolsPlugin = {

    var path:String;

    var id:String;

    var name:String;

    var runtime:Dynamic;

    var instance:ToolsPluginInstance;

}

typedef ToolsPluginInstance = {

    var backend:BackendTools;

    function init(context:Context):Void;

    @:optional function extendProject(project:Project):Void;

    @:optional function extendIdeInfo(targets:Array<IdeInfoTargetItem>, variants:Array<IdeInfoVariantItem>, hxmlOutput:String):Void;

    @:optional function extendCompletionHxml(hxml:String):Void;

}
