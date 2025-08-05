package ceramic;

/**
 * A container that displays visuals at low resolution with optional antialiasing through supersampling.
 * 
 * LowRes combines PixelArt and Filter components to create a low-resolution rendering effect
 * with customizable antialiasing. This is useful for creating retro-style graphics or
 * performance-optimized rendering while maintaining visual quality through supersampling.
 * 
 * Key features:
 * - Renders content at a lower resolution than display resolution
 * - Optional antialiasing through supersampling (density > 1)
 * - Sharp pixel rendering with adjustable sharpness
 * - Automatic or manual render control
 * 
 * ```haxe
 * // Create a low-res container for retro graphics
 * var lowRes = new LowRes();
 * lowRes.size(320, 240); // Low internal resolution
 * lowRes.density = 2; // 2x supersampling for antialiasing
 * lowRes.sharpness = 2.0; // Sharp pixels
 * 
 * // Add content to the low-res container
 * var sprite = new Quad();
 * sprite.texture = assets.texture('pixel-art');
 * lowRes.content.add(sprite);
 * 
 * // Scale up the container to fill screen
 * lowRes.scale(3); // 3x scale for 960x720 display
 * ```
 * 
 * @see PixelArt For the pixel-perfect rendering component
 * @see Filter For the supersampling filter component
 */
class LowRes extends Layer {

    /**
     * Internal pixel art container that handles pixel-perfect rendering.
     * Ensures pixels remain sharp and crisp regardless of scaling.
     */
    var pixelArt:PixelArt;

    /**
     * Internal filter used to create supersampled content.
     * Applies antialiasing when density is greater than 1.
     */
    var filter:Filter;

    /**
     * Controls the sharpness of the pixels.
     * Higher values create sharper, more defined pixel edges.
     * 
     * Common values:
     * - 1.0: Soft pixels (some blur)
     * - 2.0: Sharp pixels (recommended for pixel art)
     * - 4.0: Very sharp pixels
     * 
     * @see PixelArt.sharpness
     */
    public var sharpness(get,set):Float;
    inline function get_sharpness():Float {
        return pixelArt.sharpness;
    }
    inline function set_sharpness(sharpness:Float):Float {
        return pixelArt.sharpness = sharpness;
    }

    /**
     * When true, the content must be manually rendered by calling render().
     * When false, rendering happens automatically.
     * Useful for controlling when expensive render operations occur.
     * 
     * @see PixelArt.explicitRender
     */
    public var explicitRender(get,set):Bool;
    inline function get_explicitRender():Bool {
        return pixelArt.explicitRender;
    }
    inline function set_explicitRender(explicitRender:Bool):Bool {
        return pixelArt.explicitRender = explicitRender;
    }

    /**
     * When true, content is automatically rendered when changes occur.
     * When false, you must manually trigger rendering.
     * This is the inverse of explicitRender.
     * 
     * @see PixelArt.autoRender
     */
    public var autoRender(get,set):Bool;
    inline function get_autoRender():Bool {
        return pixelArt.autoRender;
    }
    inline function set_autoRender(autoRender:Bool):Bool {
        return pixelArt.autoRender = autoRender;
    }

    /**
     * Density value used for supersampling antialiasing.
     * Controls the internal render resolution multiplier.
     * 
     * - 1.0: No supersampling (fastest, no antialiasing)
     * - 2.0: 2x supersampling (4x pixels, good quality/performance balance)
     * - 4.0: 4x supersampling (16x pixels, high quality, slower)
     * 
     * Higher values produce smoother edges but require more GPU memory and processing.
     * Use power of 2 values for best results (1, 2, 4).
     * 
     * ```haxe
     * lowRes.density = 2; // Recommended for most cases
     * ```
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
     * The container where you add your low-resolution content.
     * All visuals added to this container will be rendered at low resolution.
     * 
     * ```haxe
     * var sprite = new Quad();
     * lowRes.content.add(sprite); // Add to low-res rendering
     * ```
     */
    public var content(default,null):Quad;

    /**
     * Creates a new low-resolution container.
     * Sets up the internal PixelArt and Filter components with default settings.
     * The container automatically resizes its internal components when resized.
     */
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

    /**
     * Internal handler that resizes the pixel art and filter components
     * when the container size changes.
     * 
     * @param width New width in pixels
     * @param height New height in pixels
     */
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