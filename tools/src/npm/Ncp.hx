package npm;

typedef NcpOptions = {
    @:optional var filter:String->Bool;
}

@:jsRequire('ncp', 'ncp')
extern class Ncp {

    static function ncp(source:String, destination:String, options:NcpOptions, callback:Dynamic->Void):Void;

} //Ncp
