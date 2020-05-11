package ceramic;

import earcut.Earcut;

import poly2tri.Sweep;
import poly2tri.SweepContext;
import poly2tri.Point as Poly2TriPoint;

using ceramic.Extensions;

/** An utility to triangulate indices from a set of vertices */
class Triangulate {

    static var poly2triPointsPoolIndex:Int = -1;
    static var poly2triPointsPool:Array<Poly2TriPoint> = [];
    static var poly2triPoints:Array<Poly2TriPoint> = [];

    /** Triangulate the given vertices and fills the indices array accordingly */
    public static function triangulate(vertices:Array<Float>, indices:Array<Int>, ?holes:Array<Int>, fast:Bool = true):Void {

        // Empty indices data
        if (indices.length > 0) {
            indices.setArrayLength(0);
        }

        if (fast) {
            // Perform triangulation with earcut (approximative but fast)
            Earcut.earcut(vertices, holes, 2, indices);
        }
        else {
            // Perform triangulation with poly2tri (precise but less optimized)
            // TODO optimize! (very slow and gc unfriendly at the moment)
		    var sweepContext = new SweepContext();
            var sweep = new Sweep(sweepContext);
            
            var i = 0;
            var n = 0;
            var len = vertices.length;
            poly2triPoints = [];
            while (i < len) {
                var p = new Poly2TriPoint(vertices[i], vertices[i+1]);
                p.id = n++;
                poly2triPoints.push(p);
                i += 2;
            }
            sweepContext.addPolyline(poly2triPoints);
            sweep.triangulate();

            for (t in sweepContext.triangles)
            {
                for (i in 0...3) 
                {
                    indices.push(t.points[i].id);
                }
            }
        }

    }

}
