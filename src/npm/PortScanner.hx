package npm;

@:jsRequire('portscanner')
extern class PortScanner {

    static function checkPortStatus(port:Int, ip:String, callback:Dynamic->String->Void):Void;

} //PortScanner
