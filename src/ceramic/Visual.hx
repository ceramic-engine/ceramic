package ceramic;

class Visual extends Entity {

/// Events

    @event function down();

    @event function up();

    @event function click();

    @event function over();

    @event function out();

/// Properties

    /** Setting this to true will force the visual to be re-rendered */
    public var dirty:Bool = true;

    public var background(default,set):Color = -1;
    function set_background(background:Color):Color {
        if (this.background == background) return background;
        this.background = background;
        dirty = true;
        return background;
    }

    public var x(default,set):Float = 0;
    function set_x(x:Float):Float {
        if (this.x == x) return x;
        this.x = x;
        dirty = true;
        return x;
    }

    public var y(default,set):Float = 0;
    function set_y(y:Float):Float {
        if (this.y == y) return y;
        this.y = y;
        dirty = true;
        return y;
    }

    public var scaleX(default,set):Float = 1;
    function set_scaleX(scaleX:Float):Float {
        if (this.scaleX == scaleX) return scaleX;
        this.scaleX = scaleX;
        dirty = true;
        return scaleX;
    }

    public var scaleY(default,set):Float = 1;
    function set_scaleY(scaleY:Float):Float {
        if (this.scaleY == scaleY) return scaleY;
        this.scaleY = scaleY;
        dirty = true;
        return scaleY;
    }

    public var anchorX(default,set):Float = 1;
    function set_anchorX(anchorX:Float):Float {
        if (this.anchorX == anchorX) return anchorX;
        this.anchorX = anchorX;
        dirty = true;
        return anchorX;
    }

    public var anchorY(default,set):Float = 1;
    function set_anchorY(anchorY:Float):Float {
        if (this.anchorY == anchorY) return anchorY;
        this.anchorY = anchorY;
        dirty = true;
        return anchorY;
    }

    private var realWidth:Float = -1;
    public var width(get,set):Float;
    function get_width():Float {
        return realWidth == -1 ? 0 : realWidth * scaleX;
    }
    function set_width(width:Float):Float {
        if (this.width == width) return width;
        realWidth = width / scaleX;
        dirty = true;
        return width;
    }

    private var realHeight:Float = -1;
    public var height(get,set):Float;
    function get_height():Float {
        return realHeight == -1 ? 0 : realHeight * scaleY;
    }
    function set_height(height:Float):Float {
        if (this.height == height) return height;
        realHeight = height / scaleY;
        dirty = true;
        return height;
    }

/// Lifecycle

    public function new() {

    } //new

    public function update() {

    } //update

    public function render() {

    } //render

}
