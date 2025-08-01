package ceramic;

/**
 * Defines how line ends are rendered.
 * 
 * This is a typedef to polyline.StrokeCap with the following values:
 * - BUTT: Line ends exactly at the endpoint
 * - SQUARE: Line extends past the endpoint by half the line thickness
 * 
 * Used by the Line class to control line end rendering.
 * 
 * @see Line.cap
 */
typedef LineCap = polyline.StrokeCap;
