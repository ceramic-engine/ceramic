package ceramic.scriptable;

/**
 * Scriptable wrapper for LineJoin to expose line join modes to scripts.
 *
 * This class provides constants that define how line segments are joined
 * at corners. In scripts, this type is exposed as `LineJoin` (without the
 * Scriptable prefix).
 *
 * @see ceramic.LineJoin The actual implementation
 * @see ceramic.Line For using joins with lines
 */
class ScriptableLineJoin {
    /**
     * Creates sharp, pointed corners (limited by miterLimit).
     */
    public static var MITER:Int = 0;
    /**
     * Creates flat, cut-off corners.
     */
    public static var BEVEL:Int = 1;
    /**
     * Creates smooth circular arcs at corners.
     */
    public static var ROUND:Int = 2;
}
