package ceramic;

class DynamicData extends Entity implements Component {

    @:noCompletion var _data:Dynamic = null;

    public var hasData(get,never):Bool;
    inline function get_hasData():Bool {
        return _data != null;
    }

    public var data(get,set):Dynamic;
    function get_data():Dynamic {
        if (_data == null) _data = {};
        return _data;
    }
    function set_data(data:Dynamic):Dynamic {
        return _data = data;
    }

    public function new(?data:Dynamic) {
        super();
        if (data != null) this.data = data;
    }

    function bindAsComponent() {
        //
    }

}
