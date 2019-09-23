package npm;

@:jsRequire('detect-port')
extern class DetectPort {

    inline static function detect(port:Int, callback:Dynamic->Int->Void):Void {
        js.Node.require('detect-port')(port, callback);
    }

} //DetectPort
