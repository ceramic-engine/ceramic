package ceramic;

/**
 * A filter configured to display pixel art content with high-quality upscaling.
 *
 * PixelArt uses advanced shader techniques to scale pixel art without blurriness
 * or artifacts, providing better results than standard NEAREST or LINEAR filtering.
 * It preserves the crisp edges of pixels while smoothing the overall appearance.
 *
 * Features:
 * - Sharp pixel scaling with configurable sharpness
 * - CRT/retro display effects (scanlines, RGB mask, grid)
 * - Chromatic aberration for color fringing
 * - Glow effects for bright pixels
 * - LCD grid simulation
 *
 * This is ideal for:
 * - Retro-style games that need clean scaling
 * - Pixel art that needs to scale to different resolutions
 * - Creating authentic CRT/LCD display effects
 * - Adding subtle visual enhancements to pixel graphics
 *
 * ```haxe
 * // Basic pixel art scaling
 * var pixelArt = new PixelArt();
 * pixelArt.size(320, 240); // Original pixel art size
 * pixelArt.content.add(myPixelSprite);
 * pixelArt.scale(3); // Scale up 3x with clean pixels
 *
 * // CRT monitor effect
 * var crt = new PixelArt();
 * crt.scanlineCount = 240; // Number of visible scanlines
 * crt.scanlineIntensity = 0.3; // Darkness between lines
 * crt.verticalMaskCount = 320; // RGB phosphor mask
 * crt.verticalMaskIntensity = 0.1;
 * crt.glowStrength = 0.2; // Slight glow on bright pixels
 *
 * // Game Boy style LCD grid
 * var lcd = new PixelArt();
 * lcd.gridThickness = 0.1;
 * lcd.gridColor = Color.fromRgb(0x9BBC0F); // GB green
 * lcd.gridAlpha = 0.15;
 * ```
 *
 * Based on techniques from: https://colececil.io/blog/2017/scaling-pixel-art-without-destroying-it/
 *
 * @see Filter
 */
class PixelArt extends Filter {

    /**
     * Sharpness of the pixels.
     * - 1.0 = Soft/blurry edges
     * - 8.0 = Sharp pixels (default)
     * - Higher values = Even sharper transitions
     *
     * Adjust based on your art style and scaling factor.
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
     * Creates color fringing effects like old CRT monitors or lenses.
     *
     * - 0.0 = No effect (default)
     * - 0.5 = Subtle color separation
     * - 1.0 = Strong RGB channel split
     *
     * Range: 0.0 – 1.0
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
     * Thickness of the pixel grid lines.
     * Set above 0.0 to display a grid overlay.
     *
     * Perfect for simulating:
     * - Game Boy LCD screens
     * - Old monitor pixel grids
     * - Tile-based displays
     *
     * Typical values: 0.05 - 0.2
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
     * Number of horizontal scanlines.
     * Set to your display's vertical resolution for authentic CRT effect.
     *
     * Examples:
     * - 240 for retro consoles
     * - 480 for SD CRT TVs
     * - 0 to disable scanlines (default)
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
     * Scanline vertical offset in pixels.
     * Useful when scanline count doesn't match pixel rows exactly.
     * Helps align scanlines with your pixel art.
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
     * Darkness between scanlines.
     * Controls how visible the horizontal lines are.
     *
     * - 0.0 = No darkening (invisible scanlines)
     * - 0.25 = Subtle effect (default)
     * - 0.5 = Medium darkness
     * - 1.0 = Black lines between scanlines
     *
     * Range: 0.0 – 1.0
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
     * Controls scanline sharpness/thickness.
     *
     * - 0.25 = Very wide/soft scanlines
     * - 1.0 = Normal sharpness (default)
     * - 4.0 = Very thin/sharp scanlines
     *
     * Common values: 0.25, 0.5, 1.0, 2.0, 4.0
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
     * Number of vertical RGB phosphor mask lines.
     * Simulates the RGB subpixel structure of CRT monitors.
     *
     * Set to your horizontal resolution divided by 3 for
     * authentic RGB triads, or 0 to disable (default).
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
     * Vertical mask horizontal offset in pixels.
     * Useful when mask count doesn't match pixel columns exactly.
     * Helps align the RGB mask with your pixel grid.
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
     * Darkness of vertical RGB mask lines.
     * Controls the visibility of the phosphor mask effect.
     *
     * - 0.0 = No mask visible (default)
     * - 0.1 = Subtle RGB stripes
     * - 0.3 = Visible phosphor structure
     * - 1.0 = Strong RGB separation
     *
     * Range: 0.0 – 1.0
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
     * Amount of glow/bloom effect on bright pixels.
     * Simulates phosphor glow on CRT displays.
     *
     * - 0.0 = No glow (default)
     * - 0.2 = Subtle bloom
     * - 0.5 = Medium glow
     * - 1.0 = Strong bloom effect
     *
     * Range: 0.0 – 1.0
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
     * Minimum brightness threshold for glow effect.
     * Pixels darker than this won't glow.
     *
     * - 0.0 = All pixels glow
     * - 0.6 = Only bright pixels glow (default)
     * - 1.0 = No pixels glow
     *
     * Range: 0.0 – 1.0
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
     * Brightness level for maximum glow intensity.
     * Pixels at or above this brightness glow at full strength.
     *
     * - Should be higher than glowThresholdMin
     * - 0.85 = Very bright pixels glow fully (default)
     * - 1.0 = Only pure white glows fully
     *
     * Range: 0.0 – 1.0
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

        shader = ceramic.App.app.assets.shader(shaders.PixelArt).clone();

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