package ceramic;

/**
 * A Visual whose rendering is delegated to a custom `render()` callback.
 *
 * `Renderable` participates naturally in Ceramic's render texture dependency
 * ordering via the existing topological sort in `App.computeRenderTexturesPriority()`.
 *
 * Subclasses (e.g. `Renderer3D` in the Star plugin) override `computeUsedTextures()`
 * to populate `usedTextures` with the textures they sample from, and `render()`
 * to perform their custom draw calls via `backend.Draw` (2D) and/or the 3D backend.
 *
 * Like Quad and Mesh, Renderable can optionally render off-screen by setting
 * `this.renderTarget`. If not set, it renders directly to the current framebuffer.
 *
 * @see ceramic.Visual
 * @see ceramic.Renderer
 */
class Renderable extends Visual {

    /**
     * Read-only view of the textures this Renderable samples from during `render()`.
     * Populated by `computeUsedTextures()`. Access `.original` to manipulate from subclasses.
     */
    public var usedTextures(default, null): ReadOnlyArray<Texture> = [];

    /**
     * Set to `true` when the set of textures used by this Renderable has changed
     * (e.g. a new material was assigned, a model was loaded).
     *
     * When `true`, the render target dependency registration in `App.updateVisuals()`
     * will call `computeUsedTextures()` to refresh `usedTextures`.
     */
    public var usedTexturesDirty: Bool = true;

    public function new() {
        super();
    }

    /**
     * Called by `Renderer.hx` during the draw pass. At this point:
     * - The render target is bound (if `this.renderTarget` is set)
     * - Blending, clip, and stencil state have been applied
     * - Any render textures this Renderable depends on have already been rendered
     *
     * The `draw` parameter is the CONCRETE low-level 2D backend (`backend.Draw`,
     * not the `spec.Draw` interface), like the rest of `Renderer.hx`, this bypasses
     * interface dispatch so the backend's inline methods stay inlined.
     */
    public function render(draw: backend.Draw): Void {
        // Override in subclasses
    }

    /**
     * (Re)populate `this.usedTextures` with all textures this Renderable will
     * sample from during `render()`. Called when `usedTexturesDirty` is `true`.
     *
     * Subclasses MUST override this if they use textures:
     * - Clear the existing array: `usedTextures.original.resize(0)`
     * - Push textures: `usedTextures.original.push(myTexture)`
     * - Do NOT replace the array reference
     * - Set `usedTexturesDirty = true` whenever the texture set changes
     */
    public function computeUsedTextures(): Void {
        // Override in subclasses
    }

}
