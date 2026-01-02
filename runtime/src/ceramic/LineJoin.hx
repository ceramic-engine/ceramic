package ceramic;

/**
 * Defines how line segments are joined at corners.
 *
 * - MITER: Creates sharp, pointed corners (limited by miterLimit)
 * - BEVEL: Creates flat, cut-off corners
 * - ROUND: Creates smooth circular arcs at corners
 *
 * Used by the Line class to control corner rendering.
 *
 * @see Line.join
 * @see Line.miterLimit
 */
enum abstract LineJoin(Int) {
    var MITER = 0;
    var BEVEL = 1;
    var ROUND = 2;
}
