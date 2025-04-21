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
     * Chromatic aberration: max offset for red/blue channel split.
     *
     * Range `0.0 – 1.0`
     */
    public var chromaticAberration(default,set):Float = 0;
    function set_chromaticAberration(chromaticAberration:Float):Float {
        if (this.chromaticAberration != chromaticAberration) {
            this.chromaticAberration = chromaticAberration;
            shader.setFloat('chromaticAberration', chromaticAberration * 0.01);
        }
        return chromaticAberration;
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

    /**
     * Number of horizontal scanlines
     */
    public var scanlineCount(default,set):Float = 0;
    function set_scanlineCount(scanlineCount:Float):Float {
        if (this.scanlineCount != scanlineCount) {
            this.scanlineCount = scanlineCount;
            shader.setFloat('scanlineCount', scanlineCount);
        }
        return scanlineCount;
    }

    /**
     * Scanline offset: useful to offset the scanlines, in case scanline count != pixel rows
     */
    public var scanlineOffset(default,set):Float = 0;
    function set_scanlineOffset(scanlineOffset:Float):Float {
        if (this.scanlineOffset != scanlineOffset) {
            this.scanlineOffset = scanlineOffset;
            shader.setFloat('scanlineOffset', scanlineOffset);
        }
        return scanlineOffset;
    }

    /**
     * Scanlines: darkness between scanlines (0 = no dim)
     *
     * Range `0.0 – 1.0`
     */
    public var scanlineIntensity(default,set):Float = 0.25;
    function set_scanlineIntensity(scanlineIntensity:Float):Float {
        if (this.scanlineIntensity != scanlineIntensity) {
            this.scanlineIntensity = scanlineIntensity;
            shader.setFloat('scanlineIntensity', 1.0 - scanlineIntensity);
        }
        return scanlineIntensity;
    }

    /**
     * Scanlines: controls how sharp or thick the dip is
     *
     * Range `0.25, 0.5, 1.0, 2.0, 4.0...`
     */
    public var scanlineShape(default,set):Float = 1;
    function set_scanlineShape(scanlineShape:Float):Float {
        if (this.scanlineShape != scanlineShape) {
            this.scanlineShape = scanlineShape;
            shader.setFloat('scanlineShape', scanlineShape);
        }
        return scanlineShape;
    }

    /**
     * Enables vertical shadow mask (subtle bars).
     */
    public var verticalMaskCount(default,set):Float = 0;
    function set_verticalMaskCount(verticalMaskCount:Float):Float {
        if (this.verticalMaskCount != verticalMaskCount) {
            this.verticalMaskCount = verticalMaskCount;
            shader.setFloat('verticalMaskCount', verticalMaskCount);
        }
        return verticalMaskCount;
    }

    /**
     * Vertical mask offset: useful to offset the vertical mas, in case mask count != pixel columns
     */
    public var verticalMaskOffset(default,set):Float = 0;
    function set_verticalMaskOffset(verticalMaskOffset:Float):Float {
        if (this.verticalMaskOffset != verticalMaskOffset) {
            this.verticalMaskOffset = verticalMaskOffset;
            shader.setFloat('verticalMaskOffset', verticalMaskOffset);
        }
        return verticalMaskOffset;
    }

    /**
     * Mask: darkness of vertical RGB mask lines
     *
     * Range `0.0 – 1.0
     */
    public var verticalMaskIntensity(default,set):Float = 0;
    function set_verticalMaskIntensity(verticalMaskIntensity:Float):Float {
        if (this.verticalMaskIntensity != verticalMaskIntensity) {
            this.verticalMaskIntensity = verticalMaskIntensity;
            shader.setFloat('verticalMaskIntensity', 1.0 - verticalMaskIntensity);
        }
        return verticalMaskIntensity;
    }

    /**
     * Glow: Amount of glow blend.
     *
     * Range `0.0 – 1.0`
     */
    public var glowStrength(default,set):Float = 0;
    function set_glowStrength(glowStrength:Float):Float {
        if (this.glowStrength != glowStrength) {
            this.glowStrength = glowStrength;
            shader.setFloat('glowStrength', glowStrength);
        }
        return glowStrength;
    }

    /**
     * Glow: Minimum brightness before glow starts.
     *
     * Range `0.0 – 1.0`
     */
    public var glowThresholdMin(default,set):Float = 0.6;
    function set_glowThresholdMin(glowThresholdMin:Float):Float {
        if (this.glowThresholdMin != glowThresholdMin) {
            this.glowThresholdMin = glowThresholdMin;
            shader.setFloat('glowThresholdMin', glowThresholdMin);
        }
        return glowThresholdMin;
    }

    /**
     * Glow: Full glow at this brightness.
     *
     * Range `0.0 – 1.0`
     */
    public var glowThresholdMax(default,set):Float = 0.85;
    function set_glowThresholdMax(glowThresholdMax:Float):Float {
        if (this.glowThresholdMax != glowThresholdMax) {
            this.glowThresholdMax = glowThresholdMax;
            shader.setFloat('glowThresholdMax', glowThresholdMax);
        }
        return glowThresholdMax;
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

        shader.setFloat('chromaticAberration', chromaticAberration * 0.01);

        shader.setFloat('gridThickness', 0);
        shader.setFloat('gridAlpha', 1);
        shader.setVec3('gridColor', 0, 0, 0);

        shader.setFloat('scanlineCount', scanlineCount);
        shader.setFloat('scanlineIntensity', 1.0 - scanlineIntensity);
        shader.setFloat('scanlineOffset', scanlineOffset);
        shader.setFloat('scanlineShape', scanlineShape);

        shader.setFloat('verticalMaskCount', verticalMaskCount);
        shader.setFloat('verticalMaskIntensity', 1.0 - verticalMaskIntensity);
        shader.setFloat('verticalMaskOffset', verticalMaskOffset);

        shader.setFloat('glowStrength', glowStrength);
        shader.setFloat('glowThresholdMin', glowThresholdMin);
        shader.setFloat('glowThresholdMax', glowThresholdMax);

        onResize(this, handleResize);

    }

    function handleResize(width:Float, height:Float):Void {

        updateResolution();

    }

    function updateResolution() {

        if (width > 0 && height > 0) {
            if (shader != null) {
                shader.setVec2('resolution',
                    width * density,
                    height * density
                );
            }
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