package npm;

@:jsRequire('yamljs')
extern class Yaml {

    static function parse(str:String):Dynamic;

    static function load(path:String, ?callback:String->Void):Dynamic;

    static function stringify(obj:Dynamic, ?inlineAt:Int, ?spaces:Int):String;

}
