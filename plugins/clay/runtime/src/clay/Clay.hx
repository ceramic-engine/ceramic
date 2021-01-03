package clay;

class Clay {

    public static var app(default, null):Clay;

    public var runtime(default, null):Runtime;

    function new() {

        Clay.app = this;

        @:privateAccess runtime = new Runtime();

    }

}
