package ceramic;

/**
 * Defines how line ends are rendered.
 *
 * - BUTT: Line ends exactly at the endpoint
 * - SQUARE: Line extends past the endpoint by half the line thickness
 * - ROUND: Semicircular cap at the endpoint
 *
 * Used by the Line class to control line end rendering.
 *
 * @see Line.cap
 */
enum abstract LineCap(Int) {
    var BUTT = 0;
    var SQUARE = 1;
    var ROUND = 2;
}
