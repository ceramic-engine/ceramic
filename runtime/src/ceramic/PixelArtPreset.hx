package ceramic;

/**
 * A complete set of `PixelArt` settings, as data: every property of the filter, with the
 * defaults of the filter itself. Apply one with `PixelArt.applyPreset()`, read the current
 * settings back with `PixelArt.toPreset()`, and paste the result of `toHaxe()` in code to
 * keep a look that was tuned at runtime.
 *
 * Built-in presets: `sharp`, `clean`, `crtTv`, `crtMonitor`, `gba`, `lite` (see `byName()`).
 */
@:structInit
class PixelArtPreset {

    /**
     * Names of the built-in presets accepted by `byName()`
     */
    public static final NAMES:ReadOnlyArray<String> = ['sharp', 'clean', 'crtTv', 'crtMonitor', 'gba', 'lite'];

    public var mode:PixelArtMode = SHARP;

    // SHARP mode

    public var sharpness:Float = 8.0;
    public var chromaticAberration:Float = 0.0;
    public var gridThickness:Float = 0.0;
    public var gridColor:Color = Color.BLACK;
    public var gridAlpha:Float = 0.0;
    public var scanlineCount:Float = 0.0;
    public var scanlineIntensity:Float = 0.25;
    public var scanlineShape:Float = 1.0;
    public var verticalMaskCount:Float = 0.0;
    public var verticalMaskIntensity:Float = 0.0;
    public var glowStrength:Float = 0.0;
    public var glowThresholdMin:Float = 0.6;
    public var glowThresholdMax:Float = 0.85;

    // CRT mode

    public var sampling:PixelArtSampling = SHARP;
    public var hardPix:Float = -3.0;
    public var sharpBand:Float = 1.0;
    public var hardScan:Float = -8.0;
    public var beamMin:Float = 1.0;
    public var beamMax:Float = 1.0;
    public var scanlineStrength:Float = 0.0;
    public var maskType:PixelArtMask = NONE;
    public var maskDark:Float = 0.5;
    public var maskLight:Float = 1.5;
    public var maskScale:Float = 1.0;
    public var lcdGridStrength:Float = 0.0;
    public var lcdSubpixelLow:Float = 0.65;
    public var bloomAmount:Float = 0.0;
    public var bloomSize:Float = 2.0;
    public var warpX:Float = 0.0;
    public var warpY:Float = 0.0;
    public var cornerRadius:Float = 0.0;
    public var cornerSmooth:Float = 0.0;
    public var vignetteStrength:Float = 0.0;
    public var gamma:Float = 0.0;
    public var brightness:Float = 1.0;
    /**
     * 3 x 3 color matrix, row by row: the first three values give the output red from the
     * input red, green and blue, and so on.
     */
    public var colorMatrix:Array<Float> = [1, 0, 0, 0, 1, 0, 0, 0, 1];
    public var luminance:Float = 1.0;
    public var noiseStrength:Float = 0.0;
    public var flickerStrength:Float = 0.0;
    public var quality:PixelArtQuality = NORMAL;

    /**
     * The original `PixelArt` look: `SHARP` mode with its defaults
     */
    public static function sharp():PixelArtPreset {

        return {};

    }

    /**
     * `CRT` mode with no effect at all: the reference to compare the CRT shader against `sharp`
     */
    public static function clean():PixelArtPreset {

        return { mode: CRT };

    }

    /**
     * A consumer television: soft beam, marked scanlines, TV shadow mask, halo,
     * slight curvature, rounded corners, vignette and a little grain
     */
    public static function crtTv():PixelArtPreset {

        return {
            mode: CRT,
            sampling: BEAM,
            hardPix: -3.0,
            hardScan: -8.0,
            beamMin: 1.0,
            beamMax: 1.4,
            scanlineStrength: 1.0,
            maskType: TV,
            maskDark: 0.5,
            maskLight: 1.5,
            bloomAmount: 0.15,
            bloomSize: 2.0,
            warpX: 1.0 / 32.0,
            warpY: 1.0 / 24.0,
            cornerRadius: 8.0,
            cornerSmooth: 1.0,
            vignetteStrength: 0.3,
            gamma: 2.2,
            brightness: 1.1,
            noiseStrength: 0.03,
            quality: NORMAL
        };

    }

    /**
     * A computer monitor: sharper beam, thin scanlines, aperture grille, faint halo, flat screen
     */
    public static function crtMonitor():PixelArtPreset {

        return {
            mode: CRT,
            sampling: BEAM,
            hardPix: -4.0,
            hardScan: -10.0,
            beamMin: 1.0,
            beamMax: 1.2,
            scanlineStrength: 0.7,
            maskType: APERTURE,
            maskDark: 0.6,
            maskLight: 1.4,
            bloomAmount: 0.08,
            bloomSize: 1.5,
            vignetteStrength: 0.1,
            gamma: 2.2,
            brightness: 1.05,
            quality: NORMAL
        };

    }

    /**
     * Game Boy Advance LCD: sharp pixels, RGB subpixels and grid, and the gba-color
     * (Pokefan531, hunterk) gamma, luminance and color matrix
     */
    public static function gba():PixelArtPreset {

        return {
            mode: CRT,
            sampling: SHARP,
            maskType: LCD,
            lcdGridStrength: 0.4,
            lcdSubpixelLow: 0.65,
            gamma: 2.2,
            luminance: 0.94,
            colorMatrix: [
                0.82, 0.24, -0.06,
                0.125, 0.665, 0.21,
                0.195, 0.075, 0.73
            ]
        };

    }

    /**
     * `crtTv` for weak GPUs: lite quality, no halo, no grain
     */
    public static function lite():PixelArtPreset {

        final preset = crtTv();
        preset.quality = LITE;
        preset.bloomAmount = 0.0;
        preset.noiseStrength = 0.0;
        return preset;

    }

    /**
     * A built-in preset by name (see `NAMES`), or `null`
     */
    public static function byName(name:String):PixelArtPreset {

        return switch name {
            case 'sharp': sharp();
            case 'clean': clean();
            case 'crtTv': crtTv();
            case 'crtMonitor': crtMonitor();
            case 'gba': gba();
            case 'lite': lite();
            case _: null;
        }

    }

    /**
     * This preset as a Haxe struct literal, ready to paste in code
     */
    public function toHaxe():String {

        final lines:Array<String> = [];
        final defaults:PixelArtPreset = {};

        inline function add(name:String, value:String) {
            lines.push('    $name: $value');
        }

        if (mode != defaults.mode) add('mode', mode == CRT ? 'CRT' : 'SHARP');

        if (sharpness != defaults.sharpness) add('sharpness', Std.string(sharpness));
        if (chromaticAberration != defaults.chromaticAberration) add('chromaticAberration', Std.string(chromaticAberration));
        if (gridThickness != defaults.gridThickness) add('gridThickness', Std.string(gridThickness));
        if (gridColor != defaults.gridColor) add('gridColor', '0x' + gridColor.toHexString(false));
        if (gridAlpha != defaults.gridAlpha) add('gridAlpha', Std.string(gridAlpha));
        if (scanlineCount != defaults.scanlineCount) add('scanlineCount', Std.string(scanlineCount));
        if (scanlineIntensity != defaults.scanlineIntensity) add('scanlineIntensity', Std.string(scanlineIntensity));
        if (scanlineShape != defaults.scanlineShape) add('scanlineShape', Std.string(scanlineShape));
        if (verticalMaskCount != defaults.verticalMaskCount) add('verticalMaskCount', Std.string(verticalMaskCount));
        if (verticalMaskIntensity != defaults.verticalMaskIntensity) add('verticalMaskIntensity', Std.string(verticalMaskIntensity));
        if (glowStrength != defaults.glowStrength) add('glowStrength', Std.string(glowStrength));
        if (glowThresholdMin != defaults.glowThresholdMin) add('glowThresholdMin', Std.string(glowThresholdMin));
        if (glowThresholdMax != defaults.glowThresholdMax) add('glowThresholdMax', Std.string(glowThresholdMax));

        if (sampling != defaults.sampling) add('sampling', sampling == BEAM ? 'BEAM' : 'SHARP');
        if (hardPix != defaults.hardPix) add('hardPix', Std.string(hardPix));
        if (sharpBand != defaults.sharpBand) add('sharpBand', Std.string(sharpBand));
        if (hardScan != defaults.hardScan) add('hardScan', Std.string(hardScan));
        if (beamMin != defaults.beamMin) add('beamMin', Std.string(beamMin));
        if (beamMax != defaults.beamMax) add('beamMax', Std.string(beamMax));
        if (scanlineStrength != defaults.scanlineStrength) add('scanlineStrength', Std.string(scanlineStrength));
        if (maskType != defaults.maskType) add('maskType', switch maskType {
            case TV: 'TV';
            case APERTURE: 'APERTURE';
            case VGA_STRETCHED: 'VGA_STRETCHED';
            case VGA: 'VGA';
            case LCD: 'LCD';
            case _: 'NONE';
        });
        if (maskDark != defaults.maskDark) add('maskDark', Std.string(maskDark));
        if (maskLight != defaults.maskLight) add('maskLight', Std.string(maskLight));
        if (maskScale != defaults.maskScale) add('maskScale', Std.string(maskScale));
        if (lcdGridStrength != defaults.lcdGridStrength) add('lcdGridStrength', Std.string(lcdGridStrength));
        if (lcdSubpixelLow != defaults.lcdSubpixelLow) add('lcdSubpixelLow', Std.string(lcdSubpixelLow));
        if (bloomAmount != defaults.bloomAmount) add('bloomAmount', Std.string(bloomAmount));
        if (bloomSize != defaults.bloomSize) add('bloomSize', Std.string(bloomSize));
        if (warpX != defaults.warpX) add('warpX', Std.string(warpX));
        if (warpY != defaults.warpY) add('warpY', Std.string(warpY));
        if (cornerRadius != defaults.cornerRadius) add('cornerRadius', Std.string(cornerRadius));
        if (cornerSmooth != defaults.cornerSmooth) add('cornerSmooth', Std.string(cornerSmooth));
        if (vignetteStrength != defaults.vignetteStrength) add('vignetteStrength', Std.string(vignetteStrength));
        if (gamma != defaults.gamma) add('gamma', Std.string(gamma));
        if (brightness != defaults.brightness) add('brightness', Std.string(brightness));
        if (!sameMatrix(colorMatrix, defaults.colorMatrix)) add('colorMatrix', '[' + colorMatrix.join(', ') + ']');
        if (luminance != defaults.luminance) add('luminance', Std.string(luminance));
        if (noiseStrength != defaults.noiseStrength) add('noiseStrength', Std.string(noiseStrength));
        if (flickerStrength != defaults.flickerStrength) add('flickerStrength', Std.string(flickerStrength));
        if (quality != defaults.quality) add('quality', switch quality {
            case LITE: 'LITE';
            case HIGH: 'HIGH';
            case _: 'NORMAL';
        });

        return '{\n' + lines.join(',\n') + '\n}';

    }

    static function sameMatrix(a:Array<Float>, b:Array<Float>):Bool {

        if (a == b) return true;
        if (a == null || b == null || a.length != b.length) return false;
        for (i in 0...a.length) {
            if (a[i] != b[i]) return false;
        }
        return true;

    }

}
