package backend;

import ceramic.RotateFrame;

using ceramic.Extensions;

enum VisualItem {
    NONE;
    QUAD;
    MESH;
}

@:allow(backend.Backend)
class Draw implements spec.Draw {

/// Public API

    public function new() {}

    inline public function getItem(visual:ceramic.Visual):VisualItem {

        // The backend decides how each visual should be drawn.
        // Instead of checking instance type at each draw iteration,
        // The backend provides/computes a VisualItem object when
        // a visual is instanciated that it can later re-use
        // at each draw iteration to read/store per visual data.

        if (Std.is(visual, ceramic.Quad)) {
            return QUAD;
        }
        else if (Std.is(visual, ceramic.Mesh)) {
            return MESH;
        }
        else {
            return NONE;
        }

    } //getItem

    public function draw(visuals:Array<ceramic.Visual>):Void {

        // Headless doesn't draw anything

    } //draw

} //Draw
