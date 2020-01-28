package npm;

@:jsRequire('colors/safe')
extern class Colors {

    static function black(str:String):String;
    static function red(str:String):String;
    static function green(str:String):String;
    static function yellow(str:String):String;
    static function blue(str:String):String;
    static function magenta(str:String):String;
    static function cyan(str:String):String;
    static function white(str:String):String;
    static function gray(str:String):String;
    static function grey(str:String):String;

    static function bgBlack(str:String):String;
    static function bgRed(str:String):String;
    static function bgGreen(str:String):String;
    static function bgYellow(str:String):String;
    static function bgBlue(str:String):String;
    static function bgMagenta(str:String):String;
    static function bgCyan(str:String):String;
    static function bgWhite(str:String):String;

    static function reset(str:String):String;
    static function bold(str:String):String;
    static function dim(str:String):String;
    static function italic(str:String):String;
    static function underline(str:String):String;
    static function inverse(str:String):String;
    static function hidden(str:String):String;
    static function strikethrough(str:String):String;

    static function rainbow(str:String):String;
    static function zebra(str:String):String;
    static function america(str:String):String;
    static function trap(str:String):String;
    static function random(str:String):String;

}
