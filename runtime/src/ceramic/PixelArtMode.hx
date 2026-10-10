package ceramic;

/**
 * Which shader a `PixelArt` filter upscales its content with.
 */
enum abstract PixelArtMode(Int) to Int {

    /**
     * `shaders.PixelArt`: sharp upscaling, with optional grid, sine scanlines,
     * vertical mask, glow and chromatic aberration. The original PixelArt look.
     */
    var SHARP = 0;

    /**
     * `shaders.PixelArtCrt`: CRT and LCD display simulation (Gaussian beam, phosphor
     * masks, halo, curvature, vignette, color matrix...), configured through presets.
     */
    var CRT = 1;

}
