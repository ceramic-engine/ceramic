package tools.spec;

import tools.Ide;
import tools.Vscode;

typedef ToolsPlugin = {

    var path:String;

    var backend:BackendTools;

    var name:String;

    var runtime:Dynamic;

    function init(context:Context):Void;

    @:optional function extendProject(project:Project):Void;

    @:optional function extendIdeInfo(targets:Array<IdeInfoTargetItem>, variants:Array<IdeInfoVariantItem>):Void;

    @:optional function extendCompletionHxml(hxml:String):Void;

}
