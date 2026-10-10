package ceramic;

import ceramic.Shortcuts.*;
import tracker.Autorun;

/**
 * A filter configured to display pixel art content with high-quality upscaling.
 *
 * PixelArt scales pixel art without blurriness or artifacts, providing better results
 * than standard NEAREST or LINEAR filtering. It preserves the crisp edges of pixels
 * while keeping sub-pixel motion smooth.
 *
 * It has two modes (see `mode`):
 * - `SHARP` (default): the original PixelArt shader, with sharp scaling, optional grid,
 *   sine scanlines, vertical mask, glow and chromatic aberration.
 * - `CRT`: a CRT and LCD display simulation (Gaussian beam, phosphor masks, halo,
 *   curvature, vignette, gamma and color matrix), driven by presets.
 *
 * ```haxe
 * // Basic pixel art scaling
 * var pixelArt = new PixelArt();
 * pixelArt.size(320, 240); // Original pixel art size
 * pixelArt.content.add(myPixelSprite);
 * pixelArt.scale(3); // Scale up 3x with clean pixels
 * screen.add(pixelArt);
 *
 * // A consumer television
 * pixelArt.applyPreset(PixelArtPreset.crtTv());
 *
 * // A Game Boy Advance screen
 * pixelArt.applyPreset(PixelArtPreset.gba());
 *
 * // Your own settings
 * pixelArt.applyPreset({
 *     mode: CRT,
 *     sampling: BEAM,
 *     scanlineStrength: 0.8,
 *     maskType: APERTURE
 * });
 * ```
 *
 * Sharp mode based on techniques from: https://colececil.io/blog/2017/scaling-pixel-art-without-destroying-it/
 * CRT mode sources are listed in `shaders.PixelArtCrt`.
 *
 * @see Filter
 * @see PixelArtPreset
 */
class PixelArt extends Filter {

/// Mode

    /**
     * Which shader upscales the content. Switching mode loads the corresponding
     * shader if needed and pushes the settings of that mode to it.
     */
    public var mode(default,set):PixelArtMode = SHARP;
    function set_mode(mode:PixelArtMode):PixelArtMode {
        if (this.mode != mode) {
            this.mode = mode;
            bindShader();
            updateBloom();
        }
        return mode;
    }

/// SHARP mode settings

    /**
     * Sharpness of the pixels (`SHARP` mode).
     * - 1.0 = Soft/blurry edges
     * - 8.0 = Sharp pixels (default)
     * - Higher values = Even sharper transitions
     *
     * Adjust based on your art style and scaling factor.
     * In `CRT` mode, see `sharpBand` instead.
     */
    public var sharpness(default,set):Float = 8.0;
    function set_sharpness(sharpness:Float):Float {
        if (this.sharpness != sharpness) {
            this.sharpness = sharpness;
            if (mode == SHARP && shader != null) shader.setFloat('sharpness', sharpness);
        }
        return sharpness;
    }

    /**
     * Chromatic aberration: max offset for red/blue channel split (`SHARP` mode).
     * Creates color fringing effects like old CRT monitors or lenses.
     *
     * - 0.0 = No effect (default)
     * - 0.5 = Subtle color separation
     * - 1.0 = Strong RGB channel split
     *
     * Range: 0.0 to 1.0. Ignored in `CRT` mode.
     */
    public var chromaticAberration(default,set):Float = 0;
    function set_chromaticAberration(chromaticAberration:Float):Float {
        if (this.chromaticAberration != chromaticAberration) {
            this.chromaticAberration = chromaticAberration;
            if (mode == SHARP && shader != null) shader.setFloat('chromaticAberration', chromaticAberration * 0.01);
        }
        return chromaticAberration;
    }

    /**
     * Thickness of the pixel grid lines (`SHARP` mode).
     * Set above 0.0 to display a grid overlay.
     *
     * Perfect for simulating:
     * - Game Boy LCD screens
     * - Old monitor pixel grids
     * - Tile-based displays
     *
     * Typical values: 0.05 - 0.2. In `CRT` mode, see the `LCD` mask instead.
     */
    public var gridThickness(default,set):Float = 0.0;
    function set_gridThickness(gridThickness:Float):Float {
        if (this.gridThickness != gridThickness) {
            this.gridThickness = gridThickness;
            if (mode == SHARP && shader != null) shader.setFloat('gridThickness', gridThickness);
        }
        return gridThickness;
    }

    /**
     * When using a grid, this is the color of the grid (`SHARP` mode)
     */
    public var gridColor(default,set):Color = Color.BLACK;
    function set_gridColor(gridColor:Color):Color {
        if (this.gridColor != gridColor) {
            this.gridColor = gridColor;
            if (mode == SHARP && shader != null) shader.setVec3('gridColor', gridColor.redFloat, gridColor.greenFloat, gridColor.blueFloat);
        }
        return gridColor;
    }

    /**
     * When using a grid, this is the alpha of the grid (`SHARP` mode)
     */
    public var gridAlpha(default,set):Float = 0.0;
    function set_gridAlpha(gridAlpha:Float):Float {
        if (this.gridAlpha != gridAlpha) {
            this.gridAlpha = gridAlpha;
            if (mode == SHARP && shader != null) shader.setFloat('gridAlpha', gridAlpha);
        }
        return gridAlpha;
    }

    /**
     * Number of horizontal scanlines (`SHARP` mode).
     * Set to your display's vertical resolution for authentic CRT effect.
     *
     * Examples:
     * - 240 for retro consoles
     * - 480 for SD CRT TVs
     * - 0 to disable scanlines (default)
     *
     * In `CRT` mode, scanlines follow the source rows: see `scanlineStrength` and `hardScan`.
     */
    public var scanlineCount(default,set):Float = 0;
    function set_scanlineCount(scanlineCount:Float):Float {
        if (this.scanlineCount != scanlineCount) {
            this.scanlineCount = scanlineCount;
            if (mode == SHARP && shader != null) shader.setFloat('scanlineCount', scanlineCount);
        }
        return scanlineCount;
    }

    /**
     * Scanline vertical offset in pixels (`SHARP` mode).
     * Useful when scanline count doesn't match pixel rows exactly.
     * Helps align scanlines with your pixel art.
     */
    public var scanlineOffset(default,set):Float = 0;
    function set_scanlineOffset(scanlineOffset:Float):Float {
        if (this.scanlineOffset != scanlineOffset) {
            this.scanlineOffset = scanlineOffset;
            if (mode == SHARP && shader != null) shader.setFloat('scanlineOffset', scanlineOffset);
        }
        return scanlineOffset;
    }

    /**
     * Darkness between scanlines (`SHARP` mode).
     * Controls how visible the horizontal lines are.
     *
     * - 0.0 = No darkening (invisible scanlines)
     * - 0.25 = Subtle effect (default)
     * - 0.5 = Medium darkness
     * - 1.0 = Black lines between scanlines
     *
     * Range: 0.0 to 1.0
     */
    public var scanlineIntensity(default,set):Float = 0.25;
    function set_scanlineIntensity(scanlineIntensity:Float):Float {
        if (this.scanlineIntensity != scanlineIntensity) {
            this.scanlineIntensity = scanlineIntensity;
            if (mode == SHARP && shader != null) shader.setFloat('scanlineIntensity', 1.0 - scanlineIntensity);
        }
        return scanlineIntensity;
    }

    /**
     * Controls scanline sharpness/thickness (`SHARP` mode).
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
            if (mode == SHARP && shader != null) shader.setFloat('scanlineShape', scanlineShape);
        }
        return scanlineShape;
    }

    /**
     * Number of vertical RGB phosphor mask lines (`SHARP` mode).
     * Simulates the RGB subpixel structure of CRT monitors.
     *
     * Set to your horizontal resolution divided by 3 for
     * authentic RGB triads, or 0 to disable (default).
     * In `CRT` mode, see `maskType`.
     */
    public var verticalMaskCount(default,set):Float = 0;
    function set_verticalMaskCount(verticalMaskCount:Float):Float {
        if (this.verticalMaskCount != verticalMaskCount) {
            this.verticalMaskCount = verticalMaskCount;
            if (mode == SHARP && shader != null) shader.setFloat('verticalMaskCount', verticalMaskCount);
        }
        return verticalMaskCount;
    }

    /**
     * Vertical mask horizontal offset in pixels (`SHARP` mode).
     * Useful when mask count doesn't match pixel columns exactly.
     * Helps align the RGB mask with your pixel grid.
     */
    public var verticalMaskOffset(default,set):Float = 0;
    function set_verticalMaskOffset(verticalMaskOffset:Float):Float {
        if (this.verticalMaskOffset != verticalMaskOffset) {
            this.verticalMaskOffset = verticalMaskOffset;
            if (mode == SHARP && shader != null) shader.setFloat('verticalMaskOffset', verticalMaskOffset);
        }
        return verticalMaskOffset;
    }

    /**
     * Darkness of vertical RGB mask lines (`SHARP` mode).
     * Controls the visibility of the phosphor mask effect.
     *
     * - 0.0 = No mask visible (default)
     * - 0.1 = Subtle RGB stripes
     * - 0.3 = Visible phosphor structure
     * - 1.0 = Strong RGB separation
     *
     * Range: 0.0 to 1.0
     */
    public var verticalMaskIntensity(default,set):Float = 0;
    function set_verticalMaskIntensity(verticalMaskIntensity:Float):Float {
        if (this.verticalMaskIntensity != verticalMaskIntensity) {
            this.verticalMaskIntensity = verticalMaskIntensity;
            if (mode == SHARP && shader != null) shader.setFloat('verticalMaskIntensity', 1.0 - verticalMaskIntensity);
        }
        return verticalMaskIntensity;
    }

    /**
     * Amount of glow/bloom effect on bright pixels (`SHARP` mode).
     * Simulates phosphor glow on CRT displays.
     *
     * - 0.0 = No glow (default)
     * - 0.2 = Subtle bloom
     * - 0.5 = Medium glow
     * - 1.0 = Strong bloom effect
     *
     * Range: 0.0 to 1.0. In `CRT` mode, see `bloomAmount`.
     */
    public var glowStrength(default,set):Float = 0;
    function set_glowStrength(glowStrength:Float):Float {
        if (this.glowStrength != glowStrength) {
            this.glowStrength = glowStrength;
            if (mode == SHARP && shader != null) shader.setFloat('glowStrength', glowStrength);
        }
        return glowStrength;
    }

    /**
     * Minimum brightness threshold for glow effect (`SHARP` mode).
     * Pixels darker than this won't glow.
     *
     * - 0.0 = All pixels glow
     * - 0.6 = Only bright pixels glow (default)
     * - 1.0 = No pixels glow
     *
     * Range: 0.0 to 1.0
     */
    public var glowThresholdMin(default,set):Float = 0.6;
    function set_glowThresholdMin(glowThresholdMin:Float):Float {
        if (this.glowThresholdMin != glowThresholdMin) {
            this.glowThresholdMin = glowThresholdMin;
            if (mode == SHARP && shader != null) shader.setFloat('glowThresholdMin', glowThresholdMin);
        }
        return glowThresholdMin;
    }

    /**
     * Brightness level for maximum glow intensity (`SHARP` mode).
     * Pixels at or above this brightness glow at full strength.
     *
     * - Should be higher than glowThresholdMin
     * - 0.85 = Very bright pixels glow fully (default)
     * - 1.0 = Only pure white glows fully
     *
     * Range: 0.0 to 1.0
     */
    public var glowThresholdMax(default,set):Float = 0.85;
    function set_glowThresholdMax(glowThresholdMax:Float):Float {
        if (this.glowThresholdMax != glowThresholdMax) {
            this.glowThresholdMax = glowThresholdMax;
            if (mode == SHARP && shader != null) shader.setFloat('glowThresholdMax', glowThresholdMax);
        }
        return glowThresholdMax;
    }

/// CRT mode: geometry

    /**
     * Screen pixels per source pixel (`CRT` mode), used to size the sharp sampling band
     * and the LCD grid. The default `-1` computes it every frame from the filter's
     * transform and the screen density, which covers scaling and zooming. Set it
     * explicitly when the filter is rendered somewhere this does not apply.
     */
    public var outputScale(default,set):Float = -1;
    function set_outputScale(outputScale:Float):Float {
        if (this.outputScale != outputScale) {
            this.outputScale = outputScale;
            updateOutputScale();
        }
        return outputScale;
    }

/// CRT mode: reconstruction

    /**
     * How each source pixel is reconstructed (`CRT` mode): `SHARP` pixels, or the
     * Gaussian `BEAM` of crt-lottes. Default: `SHARP`.
     */
    public var sampling(default,set):PixelArtSampling = SHARP;
    function set_sampling(sampling:PixelArtSampling):PixelArtSampling {
        if (this.sampling != sampling) {
            this.sampling = sampling;
            if (mode == CRT && shader != null) shader.setFloat('sampling', sampling == BEAM ? 1 : 0);
        }
        return sampling;
    }

    /**
     * Horizontal spread of the beam (`CRT` mode, `BEAM` sampling), a negative Gaussian
     * scale as in crt-lottes: `-3.0` soft (default), `-2.0` softer, `-4.0` sharper.
     */
    public var hardPix(default,set):Float = -3.0;
    function set_hardPix(hardPix:Float):Float {
        if (this.hardPix != hardPix) {
            this.hardPix = hardPix;
            if (mode == CRT && shader != null) shader.setFloat('hardPix', hardPix);
        }
        return hardPix;
    }

    /**
     * Width, in screen pixels, of the band around texel edges where `SHARP` sampling
     * interpolates (`CRT` mode). `1.0` (default) keeps sub-pixel scrolling smooth
     * without visible blur; smaller values are sharper but shimmer when scrolling.
     */
    public var sharpBand(default,set):Float = 1.0;
    function set_sharpBand(sharpBand:Float):Float {
        if (this.sharpBand != sharpBand) {
            this.sharpBand = sharpBand;
            if (mode == CRT && shader != null) shader.setFloat('sharpBand', sharpBand);
        }
        return sharpBand;
    }

/// CRT mode: scanlines

    /**
     * Vertical spread of the beam, which shapes the scanlines (`CRT` mode), a negative
     * Gaussian scale as in crt-lottes: `-8.0` (default), `-16.0` thinner lines, `-4.0` wider.
     */
    public var hardScan(default,set):Float = -8.0;
    function set_hardScan(hardScan:Float):Float {
        if (this.hardScan != hardScan) {
            this.hardScan = hardScan;
            if (mode == CRT && shader != null) shader.setFloat('hardScan', hardScan);
        }
        return hardScan;
    }

    /**
     * Beam width factor for black rows (`CRT` mode). With `beamMax`, makes bright rows
     * draw a wider beam than dark ones, as on a real tube. `1.0` by default.
     */
    public var beamMin(default,set):Float = 1.0;
    function set_beamMin(beamMin:Float):Float {
        if (this.beamMin != beamMin) {
            this.beamMin = beamMin;
            if (mode == CRT && shader != null) shader.setFloat('beamMin', beamMin);
        }
        return beamMin;
    }

    /**
     * Beam width factor for white rows (`CRT` mode). `1.0` by default (same as `beamMin`:
     * constant width); `1.4` gives bright rows a visibly thicker beam.
     */
    public var beamMax(default,set):Float = 1.0;
    function set_beamMax(beamMax:Float):Float {
        if (this.beamMax != beamMax) {
            this.beamMax = beamMax;
            if (mode == CRT && shader != null) shader.setFloat('beamMax', beamMax);
        }
        return beamMax;
    }

    /**
     * Visibility of the scanlines (`CRT` mode), from `0.0` (none, default) to `1.0`
     * (the raw crt-lottes profile). Scanlines follow the source rows, one per pixel row.
     */
    public var scanlineStrength(default,set):Float = 0.0;
    function set_scanlineStrength(scanlineStrength:Float):Float {
        if (this.scanlineStrength != scanlineStrength) {
            this.scanlineStrength = scanlineStrength;
            if (mode == CRT && shader != null) shader.setFloat('scanlineStrength', scanlineStrength);
        }
        return scanlineStrength;
    }

/// CRT mode: mask

    /**
     * Phosphor or LCD mask (`CRT` mode). Phosphor masks are fixed on the screen pixels,
     * the `LCD` mask follows the source pixels. Default: `NONE`.
     */
    public var maskType(default,set):PixelArtMask = NONE;
    function set_maskType(maskType:PixelArtMask):PixelArtMask {
        if (this.maskType != maskType) {
            this.maskType = maskType;
            if (mode == CRT && shader != null) shader.setFloat('maskType', maskType);
        }
        return maskType;
    }

    /**
     * Brightness of the mask cells that do not match a channel (`CRT` mode, phosphor masks).
     * `0.5` by default, as in crt-lottes.
     */
    public var maskDark(default,set):Float = 0.5;
    function set_maskDark(maskDark:Float):Float {
        if (this.maskDark != maskDark) {
            this.maskDark = maskDark;
            if (mode == CRT && shader != null) shader.setFloat('maskDark', maskDark);
        }
        return maskDark;
    }

    /**
     * Brightness of the mask cells that match a channel (`CRT` mode, phosphor masks).
     * `1.5` by default, as in crt-lottes: above 1 to compensate for the dark cells.
     */
    public var maskLight(default,set):Float = 1.5;
    function set_maskLight(maskLight:Float):Float {
        if (this.maskLight != maskLight) {
            this.maskLight = maskLight;
            if (mode == CRT && shader != null) shader.setFloat('maskLight', maskLight);
        }
        return maskLight;
    }

    /**
     * Size of a mask cell in screen pixels (`CRT` mode, phosphor masks). `1.0` by default;
     * use `2.0` on high density screens so the triads stay visible.
     */
    public var maskScale(default,set):Float = 1.0;
    function set_maskScale(maskScale:Float):Float {
        if (this.maskScale != maskScale) {
            this.maskScale = maskScale;
            if (mode == CRT && shader != null) shader.setFloat('maskScale', maskScale);
        }
        return maskScale;
    }

    /**
     * Darkness of the grid between pixels of the `LCD` mask (`CRT` mode), `0.0` (none,
     * default) to `1.0` (black).
     */
    public var lcdGridStrength(default,set):Float = 0.0;
    function set_lcdGridStrength(lcdGridStrength:Float):Float {
        if (this.lcdGridStrength != lcdGridStrength) {
            this.lcdGridStrength = lcdGridStrength;
            if (mode == CRT && shader != null) shader.setFloat('lcdGridStrength', lcdGridStrength);
        }
        return lcdGridStrength;
    }

    /**
     * Brightness of a channel outside its own subpixel in the `LCD` mask (`CRT` mode):
     * `1.0` hides the subpixels, `0.0` shows pure RGB stripes. `0.65` by default.
     */
    public var lcdSubpixelLow(default,set):Float = 0.65;
    function set_lcdSubpixelLow(lcdSubpixelLow:Float):Float {
        if (this.lcdSubpixelLow != lcdSubpixelLow) {
            this.lcdSubpixelLow = lcdSubpixelLow;
            if (mode == CRT && shader != null) shader.setFloat('lcdSubpixelLow', lcdSubpixelLow);
        }
        return lcdSubpixelLow;
    }

/// CRT mode: halo

    /**
     * Amount of halo added around bright pixels (`CRT` mode), `0.0` (none, default) to
     * `1.0`. The halo is a blur of the source at its own resolution, so it stays cheap.
     */
    public var bloomAmount(default,set):Float = 0.0;
    function set_bloomAmount(bloomAmount:Float):Float {
        if (this.bloomAmount != bloomAmount) {
            this.bloomAmount = bloomAmount;
            if (mode == CRT && shader != null) shader.setFloat('bloomAmount', bloomAmount);
            updateBloom();
        }
        return bloomAmount;
    }

    /**
     * Radius of the halo blur in source pixels (`CRT` mode). `2.0` by default.
     */
    public var bloomSize(default,set):Float = 2.0;
    function set_bloomSize(bloomSize:Float):Float {
        if (this.bloomSize != bloomSize) {
            this.bloomSize = bloomSize;
            pushBloomUniforms();
        }
        return bloomSize;
    }

/// CRT mode: shape

    /**
     * Horizontal curvature of the screen (`CRT` mode), as in crt-lottes: `0.0` flat
     * (default), `1/32` a typical television.
     */
    public var warpX(default,set):Float = 0.0;
    function set_warpX(warpX:Float):Float {
        if (this.warpX != warpX) {
            this.warpX = warpX;
            if (mode == CRT && shader != null) shader.setFloat('warpX', warpX);
        }
        return warpX;
    }

    /**
     * Vertical curvature of the screen (`CRT` mode), as in crt-lottes: `0.0` flat
     * (default), `1/24` a typical television.
     */
    public var warpY(default,set):Float = 0.0;
    function set_warpY(warpY:Float):Float {
        if (this.warpY != warpY) {
            this.warpY = warpY;
            if (mode == CRT && shader != null) shader.setFloat('warpY', warpY);
        }
        return warpY;
    }

    /**
     * Radius of the rounded corners of the screen, in source pixels (`CRT` mode). `0.0` by default.
     */
    public var cornerRadius(default,set):Float = 0.0;
    function set_cornerRadius(cornerRadius:Float):Float {
        if (this.cornerRadius != cornerRadius) {
            this.cornerRadius = cornerRadius;
            if (mode == CRT && shader != null) shader.setFloat('cornerRadius', cornerRadius);
        }
        return cornerRadius;
    }

    /**
     * Softness of the screen edge, in source pixels (`CRT` mode). `0.0` by default (hard edge).
     */
    public var cornerSmooth(default,set):Float = 0.0;
    function set_cornerSmooth(cornerSmooth:Float):Float {
        if (this.cornerSmooth != cornerSmooth) {
            this.cornerSmooth = cornerSmooth;
            if (mode == CRT && shader != null) shader.setFloat('cornerSmooth', cornerSmooth);
        }
        return cornerSmooth;
    }

    /**
     * Darkening of the edges of the screen (`CRT` mode), `0.0` (none, default) to `1.0`.
     */
    public var vignetteStrength(default,set):Float = 0.0;
    function set_vignetteStrength(vignetteStrength:Float):Float {
        if (this.vignetteStrength != vignetteStrength) {
            this.vignetteStrength = vignetteStrength;
            if (mode == CRT && shader != null) shader.setFloat('vignetteStrength', vignetteStrength);
        }
        return vignetteStrength;
    }

/// CRT mode: color

    /**
     * Display gamma (`CRT` mode). When above `0.0`, the beam, halo and mask are composed
     * in linear light (`2.2` is the usual value); `0.0` (default) skips the conversion,
     * which is cheaper and keeps colors untouched.
     */
    public var gamma(default,set):Float = 0.0;
    function set_gamma(gamma:Float):Float {
        if (this.gamma != gamma) {
            this.gamma = gamma;
            if (mode == CRT && shader != null) shader.setFloat('gamma', gamma);
        }
        return gamma;
    }

    /**
     * Brightness multiplier applied after the mask (`CRT` mode), to compensate for the
     * light lost in scanlines and mask cells. `1.0` by default.
     */
    public var brightness(default,set):Float = 1.0;
    function set_brightness(brightness:Float):Float {
        if (this.brightness != brightness) {
            this.brightness = brightness;
            if (mode == CRT && shader != null) shader.setFloat('brightness', brightness);
        }
        return brightness;
    }

    /**
     * 3 x 3 color matrix (`CRT` mode), row by row: the first three values give the output
     * red from the input red, green and blue, and so on. Identity by default; see
     * `PixelArtPreset.gba()` for the gba-color values.
     */
    public var colorMatrix(default,set):Array<Float> = [1, 0, 0, 0, 1, 0, 0, 0, 1];
    function set_colorMatrix(colorMatrix:Array<Float>):Array<Float> {
        this.colorMatrix = colorMatrix;
        pushColorMatrix();
        return colorMatrix;
    }

    /**
     * Luminance multiplier applied before the color matrix (`CRT` mode). `1.0` by default,
     * `0.94` in gba-color.
     */
    public var luminance(default,set):Float = 1.0;
    function set_luminance(luminance:Float):Float {
        if (this.luminance != luminance) {
            this.luminance = luminance;
            if (mode == CRT && shader != null) shader.setFloat('luminance', luminance);
        }
        return luminance;
    }

/// CRT mode: time

    /**
     * Amplitude of the animated grain (`CRT` mode), `0.0` (none, default) to `1.0`.
     */
    public var noiseStrength(default,set):Float = 0.0;
    function set_noiseStrength(noiseStrength:Float):Float {
        if (this.noiseStrength != noiseStrength) {
            this.noiseStrength = noiseStrength;
            if (mode == CRT && shader != null) shader.setFloat('noiseStrength', noiseStrength);
        }
        return noiseStrength;
    }

    /**
     * Amplitude of the brightness flicker (`CRT` mode), `0.0` (none, default) to `1.0`.
     */
    public var flickerStrength(default,set):Float = 0.0;
    function set_flickerStrength(flickerStrength:Float):Float {
        if (this.flickerStrength != flickerStrength) {
            this.flickerStrength = flickerStrength;
            if (mode == CRT && shader != null) shader.setFloat('flickerStrength', flickerStrength);
        }
        return flickerStrength;
    }

/// CRT mode: quality

    /**
     * Cost of the `BEAM` reconstruction (`CRT` mode). `NORMAL` by default.
     */
    public var quality(default,set):PixelArtQuality = NORMAL;
    function set_quality(quality:PixelArtQuality):PixelArtQuality {
        if (this.quality != quality) {
            this.quality = quality;
            if (mode == CRT && shader != null) shader.setFloat('quality', quality);
        }
        return quality;
    }

/// Internal

    /**
     * Re-binds the shader when its asset is reloaded (shade hot reload)
     */
    var shaderAutorun:Autorun = null;

    /**
     * Draws the source into `bloomRenderTexture` through the blur shader (`CRT` mode, halo)
     */
    var bloomQuad:Quad = null;

    var bloomRenderTexture:RenderTexture = null;

    var bloomShader:Shader = null;

    var bloomShaderAutorun:Autorun = null;

    var bloomTextureAutorun:Autorun = null;

    /**
     * Value last pushed as `outputScale` uniform
     */
    var currentOutputScale:Float = 1;

    var time:Float = 0;

    override function set_density(density:Float):Float {
        if (this.density == density) return density;
        super.set_density(density);
        updateResolution();
        return density;
    }

    public function new() {

        super();

        density = 1;

        bindShader();

        onResize(this, handleResize);
        screen.onResize(this, updateViewport);
        app.onPostUpdate(this, handlePostUpdate);

    }

    /**
     * Apply every setting of the given preset, mode included
     */
    public function applyPreset(preset:PixelArtPreset):Void {

        mode = preset.mode;

        sharpness = preset.sharpness;
        chromaticAberration = preset.chromaticAberration;
        gridThickness = preset.gridThickness;
        gridColor = preset.gridColor;
        gridAlpha = preset.gridAlpha;
        scanlineCount = preset.scanlineCount;
        scanlineIntensity = preset.scanlineIntensity;
        scanlineShape = preset.scanlineShape;
        verticalMaskCount = preset.verticalMaskCount;
        verticalMaskIntensity = preset.verticalMaskIntensity;
        glowStrength = preset.glowStrength;
        glowThresholdMin = preset.glowThresholdMin;
        glowThresholdMax = preset.glowThresholdMax;

        sampling = preset.sampling;
        hardPix = preset.hardPix;
        sharpBand = preset.sharpBand;
        hardScan = preset.hardScan;
        beamMin = preset.beamMin;
        beamMax = preset.beamMax;
        scanlineStrength = preset.scanlineStrength;
        maskType = preset.maskType;
        maskDark = preset.maskDark;
        maskLight = preset.maskLight;
        maskScale = preset.maskScale;
        lcdGridStrength = preset.lcdGridStrength;
        lcdSubpixelLow = preset.lcdSubpixelLow;
        bloomAmount = preset.bloomAmount;
        bloomSize = preset.bloomSize;
        warpX = preset.warpX;
        warpY = preset.warpY;
        cornerRadius = preset.cornerRadius;
        cornerSmooth = preset.cornerSmooth;
        vignetteStrength = preset.vignetteStrength;
        gamma = preset.gamma;
        brightness = preset.brightness;
        colorMatrix = preset.colorMatrix.copy();
        luminance = preset.luminance;
        noiseStrength = preset.noiseStrength;
        flickerStrength = preset.flickerStrength;
        quality = preset.quality;

    }

    /**
     * The current settings as a preset (see `PixelArtPreset.toHaxe()` to paste them in code)
     */
    public function toPreset():PixelArtPreset {

        return {
            mode: mode,
            sharpness: sharpness,
            chromaticAberration: chromaticAberration,
            gridThickness: gridThickness,
            gridColor: gridColor,
            gridAlpha: gridAlpha,
            scanlineCount: scanlineCount,
            scanlineIntensity: scanlineIntensity,
            scanlineShape: scanlineShape,
            verticalMaskCount: verticalMaskCount,
            verticalMaskIntensity: verticalMaskIntensity,
            glowStrength: glowStrength,
            glowThresholdMin: glowThresholdMin,
            glowThresholdMax: glowThresholdMax,
            sampling: sampling,
            hardPix: hardPix,
            sharpBand: sharpBand,
            hardScan: hardScan,
            beamMin: beamMin,
            beamMax: beamMax,
            scanlineStrength: scanlineStrength,
            maskType: maskType,
            maskDark: maskDark,
            maskLight: maskLight,
            maskScale: maskScale,
            lcdGridStrength: lcdGridStrength,
            lcdSubpixelLow: lcdSubpixelLow,
            bloomAmount: bloomAmount,
            bloomSize: bloomSize,
            warpX: warpX,
            warpY: warpY,
            cornerRadius: cornerRadius,
            cornerSmooth: cornerSmooth,
            vignetteStrength: vignetteStrength,
            gamma: gamma,
            brightness: brightness,
            colorMatrix: colorMatrix.copy(),
            luminance: luminance,
            noiseStrength: noiseStrength,
            flickerStrength: flickerStrength,
            quality: quality
        };

    }

/// Shader binding

    /**
     * Load (if needed) and bind the shader of the current mode. The shader asset is
     * observed so that a shade hot reload re-binds a fresh clone.
     */
    function bindShader():Void {

        if (shaderAutorun != null) {
            shaderAutorun.destroy();
            shaderAutorun = null;
        }
        if (shader != null) {
            shader.destroy();
            shader = null;
        }

        final bindMode = mode;
        final shaderClass:Class<shade.Shader> = bindMode == CRT ? shaders.PixelArtCrt : shaders.PixelArt;
        final assets = app.assets;

        if (assets.shaderAsset(shaderClass) == null) {
            assets.add(shaderClass);
        }

        assets.ensureShader(shaderClass, null, asset -> {
            if (destroyed || mode != bindMode || asset == null) return;
            shaderAutorun = autorun(() -> {
                final loaded = assets.shader(shaderClass);
                Autorun.unobserve();
                if (loaded == null) return;
                if (shader != null) {
                    shader.destroy();
                }
                shader = loaded.clone();
                pushUniforms();
            });
        });

    }

    /**
     * Push every setting of the current mode to the shader
     */
    function pushUniforms():Void {

        if (shader == null) return;

        updateResolution();

        if (mode == SHARP) {
            shader.setFloat('sharpness', sharpness);

            shader.setFloat('chromaticAberration', chromaticAberration * 0.01);

            shader.setFloat('gridThickness', gridThickness);
            shader.setFloat('gridAlpha', gridAlpha);
            shader.setVec3('gridColor', gridColor.redFloat, gridColor.greenFloat, gridColor.blueFloat);

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
        }
        else {
            updateViewport();
            shader.setFloat('outputScale', currentOutputScale);

            shader.setFloat('sampling', sampling == BEAM ? 1 : 0);
            shader.setFloat('hardPix', hardPix);
            shader.setFloat('sharpBand', sharpBand);

            shader.setFloat('hardScan', hardScan);
            shader.setFloat('beamMin', beamMin);
            shader.setFloat('beamMax', beamMax);
            shader.setFloat('scanlineStrength', scanlineStrength);

            shader.setFloat('maskType', maskType);
            shader.setFloat('maskDark', maskDark);
            shader.setFloat('maskLight', maskLight);
            shader.setFloat('maskScale', maskScale);
            shader.setFloat('lcdGridStrength', lcdGridStrength);
            shader.setFloat('lcdSubpixelLow', lcdSubpixelLow);

            shader.setFloat('bloomAmount', bloomAmount);
            if (bloomRenderTexture != null) {
                shader.setTexture('bloomTex', 1, bloomRenderTexture);
            }

            shader.setFloat('warpX', warpX);
            shader.setFloat('warpY', warpY);
            shader.setFloat('cornerRadius', cornerRadius);
            shader.setFloat('cornerSmooth', cornerSmooth);
            shader.setFloat('vignetteStrength', vignetteStrength);

            shader.setFloat('gamma', gamma);
            shader.setFloat('brightness', brightness);
            pushColorMatrix();
            shader.setFloat('luminance', luminance);

            shader.setFloat('time', time);
            shader.setFloat('noiseStrength', noiseStrength);
            shader.setFloat('flickerStrength', flickerStrength);

            shader.setFloat('quality', quality);
        }

    }

    function pushColorMatrix():Void {

        if (mode != CRT || shader == null) return;

        final m = colorMatrix;
        if (m == null || m.length != 9) {
            log.warning('PixelArt colorMatrix needs 9 values, got ' + (m != null ? m.length : 0));
            shader.setMat3('colorMatrix', 1, 0, 0, 0, 1, 0, 0, 0, 1);
            return;
        }

        // Rows in the array, columns for the shader
        shader.setMat3('colorMatrix',
            m[0], m[3], m[6],
            m[1], m[4], m[7],
            m[2], m[5], m[8]
        );

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

    function updateViewport():Void {

        if (mode == CRT && shader != null) {
            shader.setVec2('viewport',
                screen.nativeWidth * screen.nativeDensity,
                screen.nativeHeight * screen.nativeDensity
            );
        }

    }

    function updateOutputScale():Void {

        var value = outputScale;
        if (value < 0) {
            if (matrixDirty) computeMatrix();
            value = Math.sqrt(matA * matA + matB * matB) * screen.density;
        }
        if (value != currentOutputScale) {
            currentOutputScale = value;
            if (mode == CRT && shader != null) shader.setFloat('outputScale', value);
        }

    }

    function handlePostUpdate(delta:Float):Void {

        if (mode != CRT) return;

        updateOutputScale();

        if (noiseStrength > 0 || flickerStrength > 0) {
            time += delta;
            if (shader != null) shader.setFloat('time', time);
        }

    }

/// Halo

    /**
     * Create or destroy the halo pass depending on the mode and `bloomAmount`
     */
    function updateBloom():Void {

        final wantBloom = mode == CRT && bloomAmount > 0;

        if (wantBloom && bloomQuad == null) {

            // A child of the filter with its own render target: drawn at source
            // resolution, not through the filter's transform
            bloomQuad = new Quad();
            bloomQuad.active = false;
            add(bloomQuad);

            final assets = app.assets;
            if (assets.shaderAsset(shaders.GaussianBlur) == null) {
                assets.add(shaders.GaussianBlur);
            }
            assets.ensureShader(shaders.GaussianBlur, null, asset -> {
                if (destroyed || bloomQuad == null || asset == null) return;
                bloomShaderAutorun = autorun(() -> {
                    final loaded = assets.shader(shaders.GaussianBlur);
                    Autorun.unobserve();
                    if (loaded == null) return;
                    if (bloomShader != null) {
                        bloomShader.destroy();
                    }
                    bloomShader = loaded.clone();
                    bloomQuad.shader = bloomShader;
                    bloomQuad.active = bloomRenderTexture != null;
                    pushBloomUniforms();
                });
            });

            // Follow the source render texture (recreated on resize)
            bloomTextureAutorun = autorun(() -> {
                final source = this.renderTexture;
                Autorun.unobserve();
                updateBloomTexture(source);
            });
        }
        else if (!wantBloom && bloomQuad != null) {
            destroyBloom();
            if (mode == CRT && shader != null) {
                shader.setTexture('bloomTex', 1, null);
            }
        }

    }

    function updateBloomTexture(source:RenderTexture):Void {

        if (bloomRenderTexture != null) {
            bloomRenderTexture.destroy();
            bloomRenderTexture = null;
        }

        if (source == null) {
            bloomQuad.active = false;
            return;
        }

        bloomRenderTexture = new RenderTexture(source.width, source.height, 1, false, false, 0);
        bloomRenderTexture.filter = LINEAR;

        bloomQuad.texture = source;
        bloomQuad.size(source.width, source.height);
        bloomQuad.renderTarget = bloomRenderTexture;
        bloomQuad.active = bloomShader != null;

        if (mode == CRT && shader != null) {
            shader.setTexture('bloomTex', 1, bloomRenderTexture);
        }

        pushBloomUniforms();

    }

    function pushBloomUniforms():Void {

        if (bloomShader == null || bloomRenderTexture == null) return;

        bloomShader.setVec2('resolution', bloomRenderTexture.width, bloomRenderTexture.height);
        bloomShader.setVec2('blurSize', bloomSize, bloomSize);

    }

    function destroyBloom():Void {

        if (bloomShaderAutorun != null) {
            bloomShaderAutorun.destroy();
            bloomShaderAutorun = null;
        }
        if (bloomTextureAutorun != null) {
            bloomTextureAutorun.destroy();
            bloomTextureAutorun = null;
        }
        if (bloomQuad != null) {
            bloomQuad.destroy();
            bloomQuad = null;
        }
        if (bloomShader != null) {
            bloomShader.destroy();
            bloomShader = null;
        }
        if (bloomRenderTexture != null) {
            bloomRenderTexture.destroy();
            bloomRenderTexture = null;
        }

    }

    override function destroy() {

        destroyBloom();

        if (shaderAutorun != null) {
            shaderAutorun.destroy();
            shaderAutorun = null;
        }

        if (shader != null) {
            shader.destroy();
            shader = null;
        }

        super.destroy();

    }

}
