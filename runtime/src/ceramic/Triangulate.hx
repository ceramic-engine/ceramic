package ceramic;

import earcut.Earcut;

/** An utility to triangulate indices from a set of vertices */
class Triangulate {

    /** Triangulate the given vertices and fills the indices array accordingly */
    public static function triangulate(vertices:Array<Float>, indices:Array<Int>, ?holes:Array<Int>):Void {

        // Empty indices data
        if (indices.length > 0) {
            #if cpp
            untyped indices.__SetSize(0);
            #else
            indices.splice(0, indices.length);
            #end
        }

        // Perform triangulation
        Earcut.earcut(vertices, holes, 2, indices);

    }

}
