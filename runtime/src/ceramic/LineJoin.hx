package ceramic;

/**
 * Defines how line segments are joined at corners.
 * 
 * This is a typedef to polyline.StrokeJoin with the following values:
 * - MITER: Creates sharp, pointed corners
 * - BEVEL: Creates flat, cut-off corners
 * 
 * Used by the Line class to control corner rendering.
 * 
 * @see Line.join
 * @see Line.miterLimit
 */
typedef LineJoin = polyline.StrokeJoin;
