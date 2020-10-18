package ceramic;

/**
 * A filter configured to display pixel art content.
 * Uses a shader to get a nicer rendering of upscaled pixel art.
 * Better than NEAREST or LINEAR texture filtering.
 * (see https://colececil.io/blog/2017/scaling-pixel-art-without-destroying-it/)
 */
class PixelArt extends Filter {

    /**
     * Sharpness of the pixels (from 1.0 to above)
     */
    public var sharpness(default,set):Float = 8.0;
    function set_sharpness(sharpness:Float):Float {
        if (this.sharpness != sharpness) {
            this.sharpness = sharpness;
            shader.setFloat('sharpness', sharpness);
        }
        return sharpness;
    }

    override function set_density(density:Float):Float {
        if (this.density == density) return density;
        super.set_density(density);
        updateResolution();
        return density;
    }

    public function new() {

        super();

        density = 1;

        shader = ceramic.App.app.assets.shader('shader:pixelArt').clone();
        shader.setFloat('sharpness', sharpness);

        onResize(this, handleResize);

    }

    function handleResize(width:Float, height:Float):Void {

        updateResolution();

    }

    function updateResolution() {

        if (width > 0 && height > 0) {
            shader.setVec2('resolution',
                width * density,
                height * density
            );
        }

    }

    override function destroy() {

        if (shader != null) {
            shader.destroy();
            shader = null;
        }

        super.destroy();

    }

}