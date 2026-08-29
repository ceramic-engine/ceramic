package ceramic.scriptable;

/**
 * Scriptable wrapper for LineCap to expose line cap modes to scripts.
 *
 * This class provides constants that define how line ends are rendered.
 * In scripts, this type is exposed as `LineCap` (without the Scriptable prefix).
 *
 * @see ceramic.LineCap The actual implementation
 * @see ceramic.Line For using caps with lines
 */
class ScriptableLineCap {
    /**
     * Line ends exactly at the endpoint.
     */
    public static var BUTT:Int = 0;
    /**
     * Line extends past the endpoint by half the line thickness.
     */
    public static var SQUARE:Int = 1;
    /**
     * Semicircular cap at the endpoint.
     */
    public static var ROUND:Int = 2;
}
