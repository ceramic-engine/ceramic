package ceramic;

@:allow(ceramic.CollectionView)
class CollectionViewItemFrame {

    public var x:Float;

    public var y:Float;

    public var width:Float;

    public var height:Float;

    public var visible(default,null):Bool = false;

    public var view(default,null):View = null;

    public function new(x:Float, y:Float, width:Float, height:Float) {

        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;

    }

/// Print

    function toString() {
        return 'Frame(x=$x y=$y w=$width h=$height)';
    }

}
