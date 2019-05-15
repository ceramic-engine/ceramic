package backend;

import haxe.io.Bytes;

@:structInit
class HttpResponse {

    public var status:Int;

    public var content:String;

    public var binaryContent:Bytes = null;

    public var error:String = null;

    public var headers:Map<String,String>;

    function toString() {
        return '' + {
            status: status,
            content: content,
            binaryContent: (binaryContent != null ? binaryContent.length : null),
            headers: headers,
            error: error
        };
    }

} //HttpResponse
