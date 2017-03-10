package ceramic;

class Frame extends Entity {

/// Properties

    public var texture:Texture;

    public var x:Float;

    public var y:Float;

    public var width:Float;

    public var height:Float;

/// Lifecycle

    public function new(texture:Texture, ?x:Float, ?y:Float, ?width:Float, ?height:Float) {

        this.texture = texture;
        this.x = x != null ? x : 0;
        this.y = y != null ? y : 0;
        this.width = width != null ? width : texture.width;
        this.height = height != null ? height : texture.height;

    } //new

}
