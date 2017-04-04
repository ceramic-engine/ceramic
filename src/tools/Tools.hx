package tools;

class Tools {

/// Global

    public static var tools(default,null):Tools;

    static function main():Void {

        tools = new Tools(Sys.getCwd(), Sys.args());

    } //main

/// Properties

    public var cwd:String;

    public var args:Array<String>;

/// Lifecycle

    function new(cwd:String, args:Array<String>) {

        this.cwd = cwd;
        this.args = args;

        trace('cwd=$cwd args=$args');

    } //new

} //Tools
