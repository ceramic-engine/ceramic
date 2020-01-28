package npm;

@:jsRequire('handlebars')
extern class Handlebars {

    /** Compiles the given template into a reusable function */
    static function compile(source:String):Dynamic->String;

}
