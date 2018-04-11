package ceramic;

@:structInit
class ShaderAttribute {

    public var size:Int;

    public var name:String;

    public function new(size:Int, name:String) {

        this.size = size;
        this.name = name;

    } //new

/// Print

    function toString():String {

        return '' + {
            size: size,
            name: name
        };

    } //toString

} //ShaderAttribute
