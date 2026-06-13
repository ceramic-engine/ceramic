package ceramic;

/**
 * How a `Visual` renders itself, used by the renderer to dispatch each visual
 * to the right draw path without a runtime type check.
 *
 * Every `Visual` carries a `rendering` tag set by its type (Quad → QUAD,
 * Mesh → MESH, Renderable → RENDERABLE; plain visuals that render nothing
 * directly stay NONE). The renderer hot loop switches on this `Int` instead of
 * reading per-type fields and testing `visual is Renderable`, and the
 * `Visual.asQuad` / `Visual.asMesh` helpers use it to cast safely.
 *
 * @see Visual.rendering
 */
enum abstract VisualRendering(Int) from Int to Int {

    /**
     * The visual renders nothing on its own (e.g. a plain container, a Text
     * whose glyph quads are its children, a Filter compositing through a child
     * quad). Only its children produce draws.
     */
    var NONE = 0;

    /** The visual is a `Quad` (or a subclass): drawn through the quad path. */
    var QUAD = 1;

    /** The visual is a `Mesh` (or a subclass): drawn through the mesh path. */
    var MESH = 2;

    /** The visual is a `Renderable`: it emits its own draw commands via `render()`. */
    var RENDERABLE = 3;

}
