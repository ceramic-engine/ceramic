package ceramic;

/**
 * Cost of the beam reconstruction (`beamAmount`) of a `PixelArt` filter in `CRT` mode
 * (texture reads per screen pixel).
 */
enum abstract PixelArtQuality(Int) to Int {

    /**
     * Two source rows, 3 taps each
     */
    var LITE = 0;

    /**
     * Three source rows, 3 taps each
     */
    var NORMAL = 1;

    /**
     * Three source rows, 3 + 5 + 3 taps (the original crt-lottes layout)
     */
    var HIGH = 2;

}
