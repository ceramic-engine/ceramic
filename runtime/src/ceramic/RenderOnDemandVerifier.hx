package ceramic;

#if ceramic_verify_render_on_demand

import ceramic.Shortcuts.*;
import haxe.io.FPHelper;

using ceramic.Extensions;

/**
 * Debug check of `settings.renderOnDemand` (define `ceramic_verify_render_on_demand`),
 * against frozen screens: the app forgot to call `app.requestRender()` after changing
 * something that raises no dirty flag.
 *
 * After each drawn frame, a signature of the visuals is kept (`capture()`). When a frame
 * is about to be skipped, the signature of the visuals is computed again and compared
 * (`check()`): a difference means that something changed without a render request. A
 * warning names the first visual that differs and what kind of change it is, and the
 * frame is drawn.
 *
 * The signature holds, for each visible visual of the app, in drawing order (the visuals
 * that are not visible are not drawn, and their order is not kept from a frame to the
 * next): its matrix, depth, size, alpha, blending, shader, render target and clip; for a `Quad` its
 * color, texture and frame; for a `Mesh` its color mapping, texture, and the length and
 * a hash of its `vertices`, `indices`, `colors` and `uvs`.
 *
 * Limits: the check does not see what a custom `Renderable` draws (it has no generic
 * content to compare), shader uniforms, the pixels of a texture (a texture updated in
 * place, a `RenderTexture` with `autoRender` changing by itself), the float attributes
 * of quads and meshes, or the `vertices32` / `floatColors` buffers of a `Mesh`.
 *
 * This costs a pass over every visual and every mesh array at each frame: debug only.
 */
class RenderOnDemandVerifier {

    /** Hashes kept per visual: transform, color, material, geometry */
    static inline final HASHES:Int = 4;

    /** Objects kept per visual: texture, shader, render target, clip */
    static inline final REFS:Int = 4;

    static final KINDS:Array<String> = ['transform, size or depth', 'color or alpha', 'blending', 'mesh vertices, indices or uvs'];

    static final REF_KINDS:Array<String> = ['texture', 'shader', 'render target', 'clip'];

    /** Warnings logged at most (the count in `warnings` keeps growing) */
    public static var maxLoggedWarnings:Int = 50;

    /** Number of skipped frames that were drawn because a visual had changed without a request */
    public var warnings(default, null):Int = 0;

    /** Message of the last warning */
    public var lastWarning(default, null):String = null;

    /** Called with the message of each warning, if set (tests) */
    public var onWarning:(message:String) -> Void = null;

    /** Number of visible visuals of the last drawn frame, -1 before the first one */
    var count:Int = -1;

    var visuals:Array<Visual> = [];

    var hashes:Array<Int> = [];

    var refs:Array<Entity> = [];

    var tmpHashes:Array<Int> = [0, 0, 0, 0];

    var tmpRefs:Array<Entity> = [null, null, null, null];

    public function new() {}

    /**
     * Keeps the signature of `visuals`, the visuals of a frame that was just drawn.
     */
    public function capture(visuals:Array<Visual>):Void {

        var n = 0;
        for (i in 0...visuals.length) {
            final visual = visuals.unsafeGet(i);
            if (visual.destroyed || !visual.computedVisible)
                continue;
            this.visuals[n] = visual;
            compute(visual);
            for (h in 0...HASHES) hashes[n * HASHES + h] = tmpHashes[h];
            for (r in 0...REFS) refs[n * REFS + r] = tmpRefs[r];
            n++;
        }
        for (r in 0...REFS) tmpRefs[r] = null;
        if (this.visuals.length > n) {
            // Nothing kept alive by the check
            this.visuals.resize(n);
            hashes.resize(n * HASHES);
            refs.resize(n * REFS);
        }
        count = n;

    }

    /**
     * Compares `visuals` with the signature of the last drawn frame. Returns `true`,
     * after a warning, if they differ: the frame must be drawn.
     */
    public function check(visuals:Array<Visual>):Bool {

        if (count == -1)
            return false;

        var message:String = null;

        var n = 0;
        for (i in 0...visuals.length) {
            final visual = visuals.unsafeGet(i);
            if (visual.destroyed || !visual.computedVisible)
                continue;
            if (n >= count) {
                n++;
                continue;
            }
            if (visual != this.visuals[n]) {
                message = 'the visible visuals changed or were sorted differently (at index ' + n + ': ' + visual + ')';
                break;
            }
            compute(visual);
            for (h in 0...HASHES) {
                if (hashes[n * HASHES + h] != tmpHashes[h]) {
                    message = visual + ' changed (' + KINDS[h] + ')';
                    break;
                }
            }
            if (message == null) {
                for (r in 0...REFS) {
                    if (refs[n * REFS + r] != tmpRefs[r]) {
                        message = visual + ' changed (' + REF_KINDS[r] + ')';
                        break;
                    }
                }
            }
            if (message != null)
                break;
            n++;
        }
        for (r in 0...REFS) tmpRefs[r] = null;
        if (message == null && n != count) {
            message = 'the number of visible visuals changed (' + count + ' -> ' + n + ')';
        }

        if (message == null)
            return false;

        message = 'Render on demand: ' + message + ' without a render request. The frame is drawn anyway (ceramic_verify_render_on_demand); call app.requestRender() after such a change, see Settings.renderOnDemand';
        warnings++;
        lastWarning = message;
        if (warnings <= maxLoggedWarnings) {
            log.warning(message);
            if (warnings == maxLoggedWarnings) {
                log.warning('Render on demand: no more warnings of this kind are logged');
            }
        }
        if (onWarning != null) {
            onWarning(message);
        }
        return true;

    }

    inline function mix(hash:Int, value:Int):Int {

        return (hash * 31 + value) | 0;

    }

    inline function mixFloat(hash:Int, value:Float):Int {

        return (hash * 31 + FPHelper.floatToI32(value)) | 0;

    }

    /**
     * Computes the signature of `visual` into `tmpHashes` and `tmpRefs`.
     */
    function compute(visual:Visual):Void {

        var transform = 17;
        var color = 17;
        var material = 17;
        var geometry = 17;
        var texture:Entity = null;
        var shader:Entity = null;
        var renderTarget:Entity = null;
        var clip:Entity = null;

        {
            transform = mixFloat(transform, visual.matA);
            transform = mixFloat(transform, visual.matB);
            transform = mixFloat(transform, visual.matC);
            transform = mixFloat(transform, visual.matD);
            transform = mixFloat(transform, visual.matTX);
            transform = mixFloat(transform, visual.matTY);
            transform = mixFloat(transform, visual.computedDepth);
            transform = mixFloat(transform, @:privateAccess visual._width);
            transform = mixFloat(transform, @:privateAccess visual._height);

            color = mixFloat(color, visual.computedAlpha);

            material = mix(material, cast visual.blending);
            shader = visual.shader;
            renderTarget = visual.computedRenderTargetTexture;
            clip = visual.computedClip;

            final quad = visual.asQuad;
            final mesh = visual.asMesh;
            if (quad != null) {
                transform = mixFloat(transform, quad.frameX);
                transform = mixFloat(transform, quad.frameY);
                transform = mixFloat(transform, quad.frameWidth);
                transform = mixFloat(transform, quad.frameHeight);
                transform = mix(transform, quad.rotateFrame ? 1 : 0);
                color = mix(color, quad.color);
                color = mix(color, quad.transparent ? 1 : 0);
                texture = quad.texture;
            }
            else if (mesh != null) {
                color = mix(color, cast mesh.colorMapping);
                final colors = mesh.colors;
                if (colors != null) {
                    color = mix(color, colors.length);
                    for (i in 0...colors.length) {
                        color = mix(color, colors.unsafeGet(i));
                    }
                }
                final vertices = mesh.vertices;
                if (vertices != null) {
                    geometry = mix(geometry, vertices.length);
                    for (i in 0...vertices.length) {
                        geometry = mixFloat(geometry, vertices.unsafeGet(i));
                    }
                }
                final indices = mesh.indices;
                if (indices != null) {
                    geometry = mix(geometry, indices.length);
                    for (i in 0...indices.length) {
                        geometry = mix(geometry, indices.unsafeGet(i));
                    }
                }
                final uvs = mesh.uvs;
                if (uvs != null) {
                    geometry = mix(geometry, uvs.length);
                    for (i in 0...uvs.length) {
                        geometry = mixFloat(geometry, uvs.unsafeGet(i));
                    }
                }
                texture = mesh.texture;
            }
        }

        tmpHashes[0] = transform;
        tmpHashes[1] = color;
        tmpHashes[2] = material;
        tmpHashes[3] = geometry;
        tmpRefs[0] = texture;
        tmpRefs[1] = shader;
        tmpRefs[2] = renderTarget;
        tmpRefs[3] = clip;

    }

}

#end
