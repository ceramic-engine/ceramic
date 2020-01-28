package backend;

import ceramic.RotateFrame;

using ceramic.Extensions;

@:allow(backend.Backend)
class Draw #if !completion implements spec.Draw #end {

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

    }

    public function draw(visuals:Array<ceramic.Visual>):Void {

        // Unused in headless

    }

    public function swap():Void {

        // Unused in headless

    }

    public function stamp(visuals:Array<ceramic.Visual>):Void {

        // Unused in headless

    }

    inline public function transformForRenderTarget(matrix:ceramic.Transform, renderTarget:ceramic.RenderTexture):Void {

        // Unused in headless

    }

}
