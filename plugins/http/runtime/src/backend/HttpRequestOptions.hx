package backend;

typedef HttpRequestOptions = {

    var url:String;

    @:optional var method:ceramic.HttpMethod;

    @:optional var headers:Map<String,String>;

    @:optional var content:String;

    @:optional var timeout:Int;

}
