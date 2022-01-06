package ceramic;

/**
 * A container to display visuals at low resolution,
 * with the possibility to use antialiasing (supersampling).
 */
class LowRes extends Layer {

    /**
     * Pixel art container to display nice and sharp pixels at any size
     */
    var pixelArt:PixelArt;

    /**
     * Filter used to create supersampled content
     */
    var filter:Filter;

    /**
     * Sharpness of the pixels (from 1.0 to above)
     */
    public var sharpness(get,set):Float;
    inline function get_sharpness():Float {
        return pixelArt.sharpness;
    }
    inline function set_sharpness(sharpness:Float):Float {
        return pixelArt.sharpness = sharpness;
    }

    /**
     * Explicit render?
     */
    public var explicitRender(get,set):Bool;
    inline function get_explicitRender():Bool {
        return pixelArt.explicitRender;
    }
    inline function set_explicitRender(explicitRender:Bool):Bool {
        return pixelArt.explicitRender = explicitRender;
    }

    /**
     * Auto render?
     */
    public var autoRender(get,set):Bool;
    inline function get_autoRender():Bool {
        return pixelArt.autoRender;
    }
    inline function set_autoRender(autoRender:Bool):Bool {
        return pixelArt.autoRender = autoRender;
    }

    /**
     * Density value used for supersampled content.
     * A density of 1 means no supersampling (thus no antialiasing).
     * Any value above (2 or more) will increase the supersampled content size and generate antialiasing.
     * Use a power of two and not a too high value (2 is recommended if result is nice enough).
     */
    public var density(default,set):Float = 1;
    function set_density(density:Float):Float {
        if (this.density != density) {
            this.density = density;
            filter.density = density >= 1 ? density : 1;
        }
        return density;
    }

    /**
     * The visual containing what should be displayed
     */
    public var content(default,null):Quad;

    public function new() {

        super();

        pixelArt = new PixelArt();
        pixelArt.density = 1;
        add(pixelArt);

        filter = new Filter();
        filter.density = density;
        pixelArt.content.add(filter);

        content = filter.content;

        onResize(this, handleResize);

    }

    function handleResize(width:Float, height:Float):Void {

        pixelArt.size(
            width,
            height
        );

        filter.size(
            width,
            height
        );

    }

}