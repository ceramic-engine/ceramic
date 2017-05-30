package ceramic;

/** Draw anything composed of triangles/vertices. */
class Mesh extends Visual {

    /** An array of floats where each pair of numbers is treated as a coordinate location (x,y) */
    public var vertices:Array<Float> = [];

    /** An array of integers or indexes, where every three indexes define a triangle. */
    public var indices:Array<Int> = [];

    /** An array of normalized coordinates used to apply texture mapping. */
    public var uvs:Array<Int> = [];

    /** An array of colors for each vertex. */
    public var colors:Array<Int> = [];

} //Mesh
