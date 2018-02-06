package npm;

@:jsRequire('strip-ansi')
extern class StripAnsi {

    inline static function stripAnsi(input:String):String {
        return js.Node.require('strip-ansi')(input);
    }

} //StripAnsi
