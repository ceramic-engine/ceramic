package ceramic;

/**
 * How a `PixelArt` filter in `CRT` mode reconstructs each source pixel.
 */
enum abstract PixelArtSampling(Int) to Int {

    /**
     * Nearest texel, with interpolation only within a band of `sharpBand` output pixels
     * around texel edges: crisp pixels that still scroll smoothly.
     */
    var SHARP = 0;

    /**
     * Gaussian beam (crt-lottes): each source pixel bleeds into its neighbours along x
     * (`hardPix`) and the rows are drawn as scanlines (`hardScan`).
     */
    var BEAM = 1;

}
