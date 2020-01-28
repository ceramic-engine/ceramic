package npm;

import js.node.Buffer;

@:jsRequire('istextorbinary')
extern class IsTextOrBinary {

    static function isTextSync(filename:String, buffer:Buffer):Bool;

    static function isText(filename:String, buffer:Buffer, callback:String->Bool->Void):Bool;

}
