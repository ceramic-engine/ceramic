package npm;

@:jsRequire('detect-port')
extern class DetectPort {

    inline static function detect(port:String, callback:Dynamic->String->Void):Void {
        js.Node.require('detect-port')(port, callback);
    }

} //DetectPort
