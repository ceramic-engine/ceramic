package ceramic;

import haxe.io.Bytes;

@:structInit
class HttpResponse {

    public var status:Int;

    public var content:String;

    public var binaryContent:Bytes;

    public var error:String = null;

    public var headers:Map<String,String>;

    function toString() {
        return '' + {
            status: status,
            content: content,
            binaryContent: binaryContent,
            headers: headers,
            error: error
        };
    }

}
