package ceramic;

class Closure {

    public var method:Any;

    public var args:Array<Any>;

    public function new(method:Any, ?args:Array<Any>):Void {

        this.method = method;
        this.args = args != null ? args : [];

    }

    public function call():Dynamic {

        var method:Dynamic = this.method;
        var args:Array<Dynamic> = cast this.args;
        return Reflect.callMethod(null, method, args);

    }

}
