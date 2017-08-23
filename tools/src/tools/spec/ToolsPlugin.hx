package tools.spec;

typedef ToolsPlugin = {

    function init(context:Context):Void;

    @:optional function extendProject(project:Project):Void;

} //ToolsPlugin
