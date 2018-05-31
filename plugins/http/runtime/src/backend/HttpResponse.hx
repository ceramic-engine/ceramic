package backend;

@:structInit
class HttpResponse {

    public var status:Int;

    public var content:String;

    public var error:String = null;

    public var headers:Map<String,String>;

    function toString() {
        return '' + {
            status: status,
            content: content,
            headers: headers,
            error: error
        };
    }

} //HttpResponse
