package tools;

class Tools {

/// Global

    public static var tools(default,null):Tools;

    static function main():Void {

        // Expose new Tools(cwd, args).run()
        var module:Dynamic = js.Node.module;
        module.exports = boot;

    } //main

    static function boot(cwd:String, args:Array<String>):Void {

        tools = new Tools(Sys.getCwd(), Sys.args());
        tools.run();

    } //boot

/// Properties

    public var cwd:String;

    public var args:Array<String>;

/// Lifecycle

    function new(cwd:String, args:Array<String>) {

        this.cwd = cwd;
        this.args = args;

    } //new

    function run():Void {

        trace('run with cwd=$cwd args=$args');
        
    } //run

} //Tools
