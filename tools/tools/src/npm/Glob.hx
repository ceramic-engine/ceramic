package npm;

@:jsRequire('glob')
extern class Glob {

    static function sync(pattern:String, ?options:Dynamic):Array<String>;

} //Glob
