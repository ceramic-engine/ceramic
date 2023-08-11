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

    /**
     * If set above 0.0, a grid will be displayed.
     * Can be used to simulate GBA-style LCD displays.
     */
    public var gridThickness(default,set):Float = 0.0;
    function set_gridThickness(gridThickness:Float):Float {
        if (this.gridThickness != gridThickness) {
            this.gridThickness = gridThickness;
            shader.setFloat('gridThickness', gridThickness);
        }
        return gridThickness;
    }

    /**
     * When using a grid, this is the color of the grid
     */
    public var gridColor(default,set):Color = Color.BLACK;
    function set_gridColor(gridColor:Color):Color {
        if (this.gridColor != gridColor) {
            this.gridColor = gridColor;
            shader.setVec3('gridColor', gridColor.redFloat, gridColor.greenFloat, gridColor.blueFloat);
        }
        return gridColor;
    }

    /**
     * When using a grid, this is the alpha of the grid
     */
    public var gridAlpha(default,set):Float = 0.0;
    function set_gridAlpha(gridAlpha:Float):Float {
        if (this.gridAlpha != gridAlpha) {
            this.gridAlpha = gridAlpha;
            shader.setFloat('gridAlpha', gridAlpha);
        }
        return gridAlpha;
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
        shader.setFloat('gridThickness', 0);
        shader.setFloat('gridAlpha', 1);
        shader.setVec3('gridColor', 0, 0, 0);

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