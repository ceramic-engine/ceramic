package npm;

@:jsRequire('shell-quote')
extern class ShellQuote {

    static function parse(input:String):Array<String>;

}
