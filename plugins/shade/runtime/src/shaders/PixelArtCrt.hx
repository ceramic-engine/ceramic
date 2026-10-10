package shaders;

/**
 * CRT and LCD display simulation for pixel art. Runs once per screen pixel over a low
 * resolution render texture (see `ceramic.PixelArt` in `CRT` mode, which owns the
 * parameters and their documentation).
 *
 * Techniques borrowed, with their origin:
 * - crt-lottes by Timothy Lottes (public domain): Gaussian pixel reconstruction (`gaus`,
 *   `horz3`, `horz5`), scanline weights (`scan` and the three-row sum in `main`), the four
 *   phosphor masks (`maskTv`, `maskAperture`, `maskVgaStretched`, `maskVga`), the `warp`
 *   curvature and the halo + mask composition in linear light.
 * - crtemu by Mattias Gustavsson (MIT or public domain): low resolution pre-blur for the halo
 *   (rendered by `ceramic.PixelArt`, sampled here as `bloomTex`), the `vignette` formula,
 *   grain and flicker.
 * - gba-color by Pokefan531, after hunterk's Color Mangler (public domain): color matrix and
 *   luminance applied in linear light; the GBA values live in `ceramic.PixelArtPreset`.
 * - SameBoy LCD shader by LIJI32 (MIT): the idea of splitting a pixel in three RGB subpixels
 *   with darker gaps (`maskLcd`), rewritten.
 * - crt-geom by cgwg, Themaister and DOLLS (GPL, no code taken): the idea that the beam
 *   widens with brightness (`beamScale`).
 * - Pixel art antialiasing as described by Inigo Quilez, Themaister, Claudio Fernandes and
 *   Ben Golus: bilinear interpolation limited to a band one output pixel wide around texel
 *   edges (`sharpTexel`).
 */

class PixelArtCrt extends Shader<PixelArtCrt_Vert, PixelArtCrt_Frag> {}

class PixelArtCrt_Vert extends Vert {

    @param var projectionMatrix:Mat4;
    @param var modelViewMatrix:Mat4;

    /**
     * Size of the framebuffer in pixels, to give the fragment its screen position
     */
    @param var viewport:Vec2;

    @in var vertexPosition:Vec3;
    @in var vertexTCoord:Vec2;
    @in var vertexColor:Vec4;

    @out var tcoord:Vec2;
    @out var color:Vec4;
    @out var screenPos:Vec2;

    function main():Vec4 {

        tcoord = vertexTCoord;
        color = vertexColor;

        var clip:Vec4 = projectionMatrix * modelViewMatrix * vec4(vertexPosition, 1.0);

        // Position in framebuffer pixels: phosphor masks stay fixed on the screen,
        // like the glass of a real tube, whatever the content does
        screenPos = (clip.xy / clip.w * 0.5 + 0.5) * viewport;

        return clip;

    }

}

/**
 * `precision: 'highp'`: screen positions reach the thousands, which a mediump float
 * (10 bit mantissa) cannot resolve to the pixel.
 */
@shade({ precision: 'highp' })
class PixelArtCrt_Frag extends Frag {

    @param var mainTex:Sampler2D;
    @param var bloomTex:Sampler2D;
    @param var resolution:Vec2;
    @param var outputScale:Float;

    @param var beamAmount:Float;
    @param var hardPix:Float;
    @param var sharpBand:Float;

    @param var hardScan:Float;
    @param var beamMin:Float;
    @param var beamMax:Float;
    @param var scanlineStrength:Float;

    @param var maskType:Float;
    @param var maskDark:Float;
    @param var maskLight:Float;
    @param var maskScale:Float;
    @param var lcdGridStrength:Float;
    @param var lcdSubpixelLow:Float;

    @param var bloomAmount:Float;

    @param var warpX:Float;
    @param var warpY:Float;
    @param var cornerRadius:Float;
    @param var cornerSmooth:Float;
    @param var vignetteStrength:Float;

    @param var gamma:Float;
    @param var brightness:Float;
    @param var colorMatrix:Mat3;
    @param var luminance:Float;

    @param var time:Float;
    @param var noiseStrength:Float;
    @param var flickerStrength:Float;

    @param var quality:Float;

    @in var tcoord:Vec2;
    @in var color:Vec4;
    @in var screenPos:Vec2;

    /**
     * Flicker frequency, in radians per second
     */
    inline static final FLICKER_RATE:Float = 120.0;

    /**
     * Rec. 709 luma weights
     */
    function luma(c:Vec3):Float {

        return dot(c, vec3(0.2126, 0.7152, 0.0722));

    }

    /**
     * Display to linear light (no-op when `gamma` is 0)
     */
    function toLinear(c:Vec3):Vec3 {

        var result:Vec3 = c;
        if (gamma > 0.0) {
            result = pow(max(c, 0.0), vec3(gamma));
        }
        return result;

    }

    /**
     * Linear light back to display (no-op when `gamma` is 0)
     */
    function toDisplay(c:Vec3):Vec3 {

        var result:Vec3 = c;
        if (gamma > 0.0) {
            result = pow(max(c, 0.0), vec3(1.0 / gamma));
        }
        return result;

    }

    /**
     * Lottes `Fetch`: the texel `off` texels away from the one under `pos`, in linear light
     */
    function fetch(pos:Vec2, off:Vec2):Vec3 {

        var p:Vec2 = (floor(pos * resolution + off) + 0.5) / resolution;
        return toLinear(texture(mainTex, p).rgb);

    }

    /**
     * Lottes `Dist`: distance from the center of the texel under `pos`, in texels (-0.5 to 0.5)
     */
    function dist(pos:Vec2):Vec2 {

        var p:Vec2 = pos * resolution;
        return -((p - floor(p)) - 0.5);

    }

    /**
     * Lottes `Gaus`: 1D Gaussian, `scale` is negative (`hardPix`, `hardScan`)
     */
    function gaus(pos:Float, scale:Float):Float {

        return exp2(scale * pos * pos);

    }

    /**
     * Lottes `Horz3`: 3-tap Gaussian reconstruction along x of the source row `off`
     */
    function horz3(pos:Vec2, off:Float):Vec3 {

        var b:Vec3 = fetch(pos, vec2(-1.0, off));
        var c:Vec3 = fetch(pos, vec2(0.0, off));
        var d:Vec3 = fetch(pos, vec2(1.0, off));
        var dst:Float = dist(pos).x;
        var wb:Float = gaus(dst - 1.0, hardPix);
        var wc:Float = gaus(dst, hardPix);
        var wd:Float = gaus(dst + 1.0, hardPix);
        return (b * wb + c * wc + d * wd) / (wb + wc + wd);

    }

    /**
     * Lottes `Horz5`: 5-tap Gaussian reconstruction along x of the source row `off`
     */
    function horz5(pos:Vec2, off:Float):Vec3 {

        var a:Vec3 = fetch(pos, vec2(-2.0, off));
        var b:Vec3 = fetch(pos, vec2(-1.0, off));
        var c:Vec3 = fetch(pos, vec2(0.0, off));
        var d:Vec3 = fetch(pos, vec2(1.0, off));
        var e:Vec3 = fetch(pos, vec2(2.0, off));
        var dst:Float = dist(pos).x;
        var wa:Float = gaus(dst - 2.0, hardPix);
        var wb:Float = gaus(dst - 1.0, hardPix);
        var wc:Float = gaus(dst, hardPix);
        var wd:Float = gaus(dst + 1.0, hardPix);
        var we:Float = gaus(dst + 2.0, hardPix);
        return (a * wa + b * wb + c * wc + d * wd + e * we) / (wa + wb + wc + wd + we);

    }

    /**
     * Width of the beam drawing a row of the given color: the crt-geom idea
     * (brighter rows draw a wider beam), applied to the Lottes scanline Gaussian
     */
    function beamScale(c:Vec3):Float {

        var lum:Float = clamp(luma(c), 0.0, 1.0);
        return hardScan / max(mix(beamMin, beamMax, lum), 0.001);

    }

    /**
     * Lottes `Scan`: weight of the source row `off` at this position, for a beam of width `scale`
     */
    function scan(pos:Vec2, off:Float, scale:Float):Float {

        var dst:Float = dist(pos).y;
        return gaus(dst + off, scale);

    }

    /**
     * Pixel art antialiasing (Quilez, Themaister, Fernandes, Golus): nearest texel, with
     * bilinear interpolation only within a band of `sharpBand` output pixels around texel
     * edges, so that sub-pixel scrolling stays smooth without blurring the pixels
     */
    function sharpTexel(pos:Vec2):Vec3 {

        var p:Vec2 = pos * resolution + 0.5;
        var fl:Vec2 = floor(p);
        var fr:Vec2 = p - fl;
        var band:Float = max(sharpBand, 0.001) / outputScale;
        fr = clamp((fr - 0.5) / band + 0.5, 0.0, 1.0);
        return toLinear(texture(mainTex, (fl + fr - 0.5) / resolution).rgb);

    }

    /**
     * Lottes: one RGB triad per three cells along `x` (in cells)
     */
    function maskTriad(x:Float):Vec3 {

        var m:Vec3 = vec3(maskDark);
        var f:Float = fract(x);
        if (f < 0.333) {
            m.r = maskLight;
        }
        else if (f < 0.666) {
            m.g = maskLight;
        }
        else {
            m.b = maskLight;
        }
        return m;

    }

    /**
     * Lottes mask 1: compressed TV style shadow mask, triads offset every other line
     */
    function maskTv(pos:Vec2):Vec3 {

        var line:Float = maskLight;
        var odd:Float = 0.0;
        if (fract(pos.x / 6.0) < 0.5) {
            odd = 1.0;
        }
        if (fract((pos.y + odd) * 0.5) < 0.5) {
            line = maskDark;
        }
        return maskTriad(pos.x / 3.0) * line;

    }

    /**
     * Lottes mask 2: aperture grille
     */
    function maskAperture(pos:Vec2):Vec3 {

        return maskTriad(pos.x / 3.0);

    }

    /**
     * Lottes mask 3: stretched VGA style shadow mask
     */
    function maskVgaStretched(pos:Vec2):Vec3 {

        return maskTriad((pos.x + pos.y * 3.0) / 6.0);

    }

    /**
     * Lottes mask 4: VGA style shadow mask
     */
    function maskVga(pos:Vec2):Vec3 {

        var p:Vec2 = floor(pos * vec2(1.0, 0.5));
        return maskTriad((p.x + p.y * 3.0) / 6.0);

    }

    /**
     * LCD (after SameBoy): each source pixel split in three RGB subpixels, with a dark grid
     * between pixels. Tied to source pixels, not screen pixels: one game pixel is one LCD pixel
     */
    function maskLcd(uv:Vec2):Vec3 {

        var f:Vec2 = fract(uv * resolution);
        var m:Vec3 = vec3(lcdSubpixelLow);
        if (f.x < 0.333) {
            m.r = 1.0;
        }
        else if (f.x < 0.666) {
            m.g = 1.0;
        }
        else {
            m.b = 1.0;
        }
        // Grid: the first output pixel along each pixel edge
        var edge:Float = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)) * outputScale;
        m *= mix(1.0 - lcdGridStrength, 1.0, clamp(edge, 0.0, 1.0));
        return m;

    }

    function mask(uv:Vec2):Vec3 {

        var m:Vec3 = vec3(1.0);
        var pos:Vec2 = screenPos / maskScale;
        if (maskType < 1.5) {
            m = maskTv(pos);
        }
        else if (maskType < 2.5) {
            m = maskAperture(pos);
        }
        else if (maskType < 3.5) {
            m = maskVgaStretched(pos);
        }
        else if (maskType < 4.5) {
            m = maskVga(pos);
        }
        else {
            m = maskLcd(uv);
        }
        return m;

    }

    /**
     * Lottes `Warp`: barrel distortion of the image coordinates
     */
    function warp(pos:Vec2):Vec2 {

        var p:Vec2 = pos * 2.0 - 1.0;
        p *= vec2(1.0 + (p.y * p.y) * warpX, 1.0 + (p.x * p.x) * warpY);
        return p * 0.5 + 0.5;

    }

    /**
     * Rounded rectangle in source pixels: 1 inside, 0 outside. Also hides what the
     * curvature pushed outside the image
     */
    function cornerMask(uv:Vec2):Float {

        var halfSize:Vec2 = resolution * 0.5;
        var q:Vec2 = abs((uv - 0.5) * resolution) - (halfSize - cornerRadius);
        var d:Float = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - cornerRadius;
        return clamp(-d / max(cornerSmooth, 0.001), 0.0, 1.0);

    }

    /**
     * crtemu vignette: 1 at the center, darker towards the edges
     */
    function vignette(uv:Vec2):Float {

        return sqrt(16.0 * uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y));

    }

    /**
     * The usual one-line GLSL hash
     */
    function hash(p:Vec2):Float {

        return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);

    }

    function main():Vec4 {

        var uv:Vec2 = tcoord;
        if (warpX > 0.0 || warpY > 0.0) {
            uv = warp(uv);
        }

        var frame:Float = cornerMask(uv);

        // Reconstruction, in linear light: `sharp` and `beam` are the two normalized
        // reconstructions blended by `beamAmount`, `scanSharp` and `scanBeam` the matching
        // Lottes scanline profiles (un-normalized sums of row weights, below 1 between rows)
        var sharp:Vec3 = vec3(0.0);
        var beam:Vec3 = vec3(0.0);
        var scanSharp:Float = 1.0;
        var scanBeam:Float = 1.0;

        if (beamAmount < 1.0) {
            sharp = sharpTexel(uv);
            if (scanlineStrength > 0.0) {
                var scale:Float = beamScale(sharp);
                scanSharp = scan(uv, -1.0, scale) + scan(uv, 0.0, scale) + scan(uv, 1.0, scale);
            }
        }

        if (beamAmount > 0.0) {
            var b:Vec3 = vec3(0.0);
            if (quality < 1.5) {
                b = horz3(uv, 0.0);
            }
            else {
                b = horz5(uv, 0.0);
            }
            var wb:Float = scan(uv, 0.0, beamScale(b));

            if (quality < 0.5) {
                // Lite: the row under the pixel and its nearest neighbour
                var offA:Float = 1.0;
                if (dist(uv).y > 0.0) {
                    offA = -1.0;
                }
                var a:Vec3 = horz3(uv, offA);
                var wa:Float = scan(uv, offA, beamScale(a));
                beam = (a * wa + b * wb) / (wa + wb);
                scanBeam = wa + wb;
            }
            else {
                // Lottes `Tri`: three source rows
                var a:Vec3 = horz3(uv, -1.0);
                var c:Vec3 = horz3(uv, 1.0);
                var wa:Float = scan(uv, -1.0, beamScale(a));
                var wc:Float = scan(uv, 1.0, beamScale(c));
                beam = (a * wa + b * wb + c * wc) / (wa + wb + wc);
                scanBeam = wa + wb + wc;
            }
        }

        var rgb:Vec3 = mix(sharp, beam, beamAmount);
        var scanSum:Float = mix(scanSharp, scanBeam, beamAmount);

        rgb *= mix(1.0, scanSum, scanlineStrength);

        // Halo, blurred at source resolution by `ceramic.PixelArt`
        if (bloomAmount > 0.0) {
            rgb += toLinear(texture(bloomTex, uv).rgb) * bloomAmount;
        }

        if (maskType > 0.5) {
            rgb *= mask(uv);
        }

        rgb *= brightness;

        if (vignetteStrength > 0.0) {
            rgb *= mix(1.0, vignette(uv), vignetteStrength);
        }

        // gba-color: luminance then color matrix, in linear light
        rgb = colorMatrix * (rgb * luminance);

        rgb = toDisplay(rgb);

        if (noiseStrength > 0.0) {
            rgb += (hash(screenPos + fract(time) * 100.0) - 0.5) * noiseStrength;
        }

        if (flickerStrength > 0.0) {
            rgb *= 1.0 + flickerStrength * sin(time * FLICKER_RATE);
        }

        rgb *= frame;

        return color * vec4(clamp(rgb, 0.0, 1.0), 1.0);

    }

}
