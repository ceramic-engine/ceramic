package ceramic;

/**
 * Phosphor or LCD mask of a `PixelArt` filter in `CRT` mode.
 * Values match the `maskType` uniform of `shaders.PixelArtCrt`.
 */
enum abstract PixelArtMask(Int) to Int {

    var NONE = 0;

    /**
     * Compressed TV style shadow mask (crt-lottes mask 1)
     */
    var TV = 1;

    /**
     * Aperture grille, vertical RGB stripes (crt-lottes mask 2)
     */
    var APERTURE = 2;

    /**
     * Stretched VGA style shadow mask (crt-lottes mask 3)
     */
    var VGA_STRETCHED = 3;

    /**
     * VGA style shadow mask (crt-lottes mask 4)
     */
    var VGA = 4;

    /**
     * LCD: three RGB subpixels per source pixel and a dark grid between pixels
     */
    var LCD = 5;

}
