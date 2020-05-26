package ceramic;

import earcut.Earcut;

import poly2tri.Sweep;
import poly2tri.SweepContext;
import poly2tri.Point as Poly2TriPoint;

import ceramic.Shortcuts.*;

using ceramic.Extensions;

/** An utility to triangulate indices from a set of vertices */
class Triangulate {

    static var poly2triPointsPool:Array<Poly2TriPoint> = [];
    static var poly2triPoints:Array<Poly2TriPoint> = [];
    static var poly2triSweepContext:SweepContext;
    static var poly2triSweep:Sweep;

    /** Triangulate the given vertices and fills the indices array accordingly */
    public static function triangulate(vertices:Array<Float>, indices:Array<Int>, ?holes:Array<Int>, method:TriangulateMethod = POLY2TRI):Void {

        // Empty indices data
        if (indices.length > 0) {
            indices.setArrayLength(0);
        }

        switch method {
            case EARCUT:
                // Perform triangulation with earcut (approximative but fast)
                Earcut.earcut(vertices, holes, 2, indices);
            
            case POLY2TRI: try {
                // Perform triangulation with poly2tri (precise but maybe slightly slower)
                if (poly2triSweepContext == null) {
                    poly2triSweepContext = new SweepContext();
                    poly2triSweep = new Sweep(poly2triSweepContext);
                }
                else {
                    poly2triSweepContext.reset();
                }
                
                var i = 0;
                var n = 0;
                var len = vertices.length;
                var prevX = 0.0;
                var prevY = 0.0;
                while (i < len) {
                    var p = poly2triPointsPool[n];
                    if (p == null) {
                        p = new Poly2TriPoint(vertices[i], vertices[i+1]);
                        p.id = n;
                    }
                    else {
                        p.x = vertices[i];
                        p.y = vertices[i+1];
                    }
                    if (i > 0 && prevX == p.x && prevY == p.y) {
                        log.warning('Skip triangulation because two adjacent points are identical');
                        return;
                    }
                    prevX = p.x;
                    prevY = p.y;
                    poly2triPoints[n] = p;
                    n++;
                    i += 2;
                }
                var numPoints = Std.int(len / 2);
                if (poly2triPoints.length > numPoints)
                    poly2triPoints.setArrayLength(numPoints);
                poly2triSweepContext.addPolyline(poly2triPoints);
                poly2triSweep.triangulate();
    
                var triangles = poly2triSweepContext.triangles;
                for (t in 0...triangles.length)
                {
                    var points = triangles[t].points;
                    for (i in 0...3) 
                    {
                        indices.push(points[i].id);
                    }
                }
            }
            catch (e:Dynamic) {
                log.warning('Failed to triangulate with poly2tri: $e');
            }

            poly2tri.Pool.recycleAll();
        }

    }

}
