package backend;

typedef HttpRequestOptions = {

    var url:String;

    @:optional var method:HttpMethod;

    @:optional var headers:Map<String,String>;

    @:optional var content:String;

} //HttpRequestOptions
