package ceramic;

import ceramic.Quad;
import ceramic.RenderTexture;
import ceramic.Shortcuts.*;
import ceramic.Visual;
import tracker.Observable;

/**
 * A visual container that renders its children to a texture for post-processing effects.
 * 
 * Filter renders its children to a RenderTexture, allowing you to:
 * - Apply shader effects to groups of visuals
 * - Add blur, glow, or other post-processing effects
 * - Blend or transform rendered results as a single texture
 * - Create complex visual effects like reflections or distortions
 * - Improve performance by caching complex visuals
 * 
 * The filter process:
 * 1. Children are rendered to an internal RenderTexture
 * 2. The texture can be processed with shaders or effects
 * 3. The result is displayed as a single quad/mesh
 * 
 * Features:
 * - Automatic render texture management
 * - Optional custom mesh for advanced effects
 * - Toggle effects without changing hierarchy
 * - Explicit render control for performance
 * - Support for texture atlases via TextureTilePacker
 * 
 * @example
 * ```haxe
 * // Create a blur filter
 * var blurFilter = new Filter();
 * blurFilter.size(400, 300);
 * blurFilter.shader = assets.shader('blur');
 * 
 * // Add content to be blurred
 * var text = new Text();
 * text.content = 'Blurred Text';
 * blurFilter.content.add(text);
 * 
 * // Toggle effect
 * blurFilter.enabled = false; // Disable blur
 * ```
 * 
 * @see RenderTexture
 * @see Shader
 * @see Layer
 */
class Filter extends Layer implements Observable {

/// Internal

    static var _matrix:Transform = Visual._matrix;

/// Public properties

    /**
     * Optional ID assigned to the internal render texture.
     * Useful for debugging or identifying textures in tools.
     */
    public var textureId(default, set):String = null;
    function set_textureId(textureId:String):String {
        this.textureId = textureId;
        if (renderTexture != null) {
            renderTexture.id = textureId;
        }
        return textureId;
    }

    /**
     * Optional mesh for advanced rendering effects.
     * 
     * By default, the filter renders as a simple quad. Providing a custom mesh
     * allows for advanced effects like:
     * - Distortion effects with deformed vertices
     * - Multi-pass rendering with custom UVs
     * - Complex shader effects requiring custom attributes
     * 
     * The mesh will be added as a child and the render texture assigned to it.
     */
    public var mesh(default,set):Mesh = null;
    function set_mesh(mesh:Mesh):Mesh {
        if (this.mesh != mesh) {
            if (this.mesh != null) {
                if (destroyMeshOnRemove) {
                    var prevMesh = this.mesh;
                    this.mesh = null;
                    prevMesh.destroy();
                }
                else {
                    remove(this.mesh);
                }
            }
            this.mesh = mesh;
            if (this.mesh != null) {
                add(this.mesh);
            }
            meshDirty = true;
            contentDirty = true;
        }
        return mesh;
    }

    var meshDirty:Bool = false;

    var neverEmptyQuad:Quad = null;

    /**
     * If set to `true`, when assigning `null` or
     * a new mesh intance to the `mesh` field will destroy
     * any existing mesh previously assigned.
     */
    public var destroyMeshOnRemove:Bool = true;

    /**
     * The container for visuals to be rendered through this filter.
     * Add your visuals as children of this content quad.
     * Everything added here will be rendered to the filter's texture
     * and processed according to the filter's settings.
     */
    public var content(default,null):Quad;

    /**
     * If provided, visuals in content will react to hit tests
     * and touch events as if they were inside this hit visual.
     * By default, `hitVisual` is the `Filter` instance itself.
     */
    public var hitVisual(default, set):Visual = null;
    function set_hitVisual(hitVisual:Visual):Visual {
        if (this.hitVisual == hitVisual) return hitVisual;
        if (this.hitVisual != null) {
            screen.removeHitVisual(this.hitVisual);
        }
        this.hitVisual = hitVisual;
        if (this.hitVisual != null) {
            screen.addHitVisual(this.hitVisual);
        }
        return hitVisual;
    }

    /**
     * Toggle the filter effect on/off.
     * 
     * When false:
     * - No render texture is used
     * - Children render directly to screen
     * - No performance overhead from filtering
     * - Useful for toggling effects without changing hierarchy
     * 
     * Default is true (filter enabled).
     */
    public var enabled(default,set):Bool = true;
    function set_enabled(enabled:Bool):Bool {
        if (this.enabled == enabled) return enabled;
        this.enabled = enabled;
        transparent = !enabled;
        contentDirty = true;
        return enabled;
    }

    /**
     * The filtering mode for the render texture.
     * - LINEAR: Smooth filtering (default, good for most effects)
     * - NEAREST: No filtering (good for pixel art)
     */
    public var textureFilter(default,set):TextureFilter = LINEAR;
    function set_textureFilter(textureFilter:TextureFilter):TextureFilter {
        if (this.textureFilter == textureFilter) return textureFilter;
        this.textureFilter = textureFilter;
        if (renderTexture != null) renderTexture.filter = textureFilter;
        return textureFilter;
    }

    /**
     * Texture depth
     */
    /**
     * Whether to use a depth buffer for the render texture.
     * Enable when rendering 3D content or when precise depth testing is needed.
     * Default is true.
     */
    public var depthBuffer(default,set):Bool = true;
    function set_depthBuffer(depthBuffer:Bool):Bool {
        if (this.depthBuffer == depthBuffer) return depthBuffer;
        this.depthBuffer = depthBuffer;
        contentDirty = true;
        return depthBuffer;
    }

    /**
     * Texture stencil
     */
    /**
     * Whether to use a stencil buffer for the render texture.
     * Enable for masking effects or when using stencil-based rendering techniques.
     * Default is true.
     */
    public var stencil(default,set):Bool = true;
    function set_stencil(stencil:Bool):Bool {
        if (this.stencil == stencil) return stencil;
        this.stencil = stencil;
        contentDirty = true;
        return stencil;
    }

    /**
     * Texture antialiasing
     */
    /**
     * Antialiasing level for the render texture.
     * 0 = no antialiasing (default)
     * 2, 4, 8, etc. = multisampling levels
     * Higher values provide smoother edges but use more GPU resources.
     */
    public var antialiasing(default,set):Int = 0;
    function set_antialiasing(antialiasing:Int):Int {
        if (this.antialiasing == antialiasing) return antialiasing;
        this.antialiasing = antialiasing;
        contentDirty = true;
        return antialiasing;
    }

    /**
     * Auto render?
     */
    /**
     * Whether the render texture updates automatically.
     * Set to false for manual control over when rendering happens.
     * Useful for static content that doesn't need continuous updates.
     * Default is true.
     */
    public var autoRender(default,set):Bool = true;
    function set_autoRender(autoRender:Bool):Bool {
        if (this.autoRender == autoRender) return autoRender;
        this.autoRender = autoRender;
        if (renderTexture != null) renderTexture.autoRender = autoRender;
        return autoRender;
    }

    /**
     * Enable manual control over when the filter renders.
     * 
     * When true:
     * - Children don't render automatically
     * - Use render() method to trigger rendering
     * - Filter manages children's active state
     * - Useful for performance optimization
     * 
     * Default is false (automatic rendering).
     */
    public var explicitRender(default,set):Bool = false;
    function set_explicitRender(explicitRender:Bool):Bool {
        if (this.explicitRender == explicitRender) return explicitRender;
        this.explicitRender = explicitRender;
        content.active = !explicitRender;
        return explicitRender;
    }

    /**
     * Optional texture tile packer for efficient texture atlas usage.
     * When set, the filter will allocate tiles from the packer's texture atlas
     * instead of creating dedicated render textures.
     * Useful for optimizing many small filters.
     */
    public var textureTilePacker(default,set):TextureTilePacker = null;
    function set_textureTilePacker(textureTilePacker:TextureTilePacker):TextureTilePacker {
        if (this.textureTilePacker == textureTilePacker) return textureTilePacker;

        if (textureTile != null && this.textureTilePacker != null) {
            this.textureTilePacker.releaseTile(textureTile);
            textureTile = null;
            tile = null;
            this.tile = null;
            content.renderTarget = null;
        }

        this.textureTilePacker = textureTilePacker;
        contentDirty = true;
        return textureTilePacker;
    }

    /**
     * The allocated texture tile when using a TextureTilePacker.
     * Read-only. Automatically managed when textureTilePacker is set.
     */
    public var textureTile(default,null):TextureTile = null;

    /**
     * The render texture used for this filter.
     * Read-only. Automatically created based on filter size and settings.
     * Can be observed for changes using the @observe attribute.
     */
    @observe public var renderTexture(default,null):RenderTexture = null;

    /**
     * Texture density/resolution multiplier.
     * -1 = use screen density (default)
     * 1.0 = normal density
     * 2.0 = double density (retina)
     * Affects the internal resolution of the render texture.
     */
    public var density(default,set):Float = -1;
    function set_density(density:Float):Float {
        if (this.density == density) return density;
        this.density = density;
        contentDirty = true;
        return density;
    }

    /**
     * Force the filter to render even when content is empty.
     * 
     * By default, empty filters don't render (optimization).
     * Set to true when you need the filter to process even without content,
     * such as for time-based shader effects or render passes that don't
     * depend on input visuals.
     * 
     * Adds a hidden 1x1 quad to ensure rendering occurs.
     */
    public var neverEmpty(default,set):Bool = false;
    function set_neverEmpty(neverEmpty:Bool):Bool {
        if (this.neverEmpty == neverEmpty) return neverEmpty;
        this.neverEmpty = neverEmpty;
        if (neverEmpty) {
            if (neverEmptyQuad == null) {
                neverEmptyQuad = new Quad();
                neverEmptyQuad.size(1, 1);
                neverEmptyQuad.pos(-999999999, -999999999);
                content.add(neverEmptyQuad);
            }
        }
        else {
            if (neverEmptyQuad != null) {
                neverEmptyQuad.destroy();
                neverEmptyQuad = null;
            }
        }
        return neverEmpty;
    }

    /**
     * Internal flag used to keep track of current explicit render state
     */
    var explicitRenderState:Int = 0;

    /**
     * Used internally when concurrent renders are trigerred
     */
    var explicitRenderPendingResultCallbacks:Array<Void->Void> = null;

/// Lifecycle

    public function new(#if ceramic_debug_entity_allocs ?pos:haxe.PosInfos #end) {

        super(#if ceramic_debug_entity_allocs pos #end);

        transparent = false;

        content = new Quad();
        content.transparent = true;
        content.color = Color.WHITE;
        add(content);

        hitVisual = this;

        screen.onTexturesDensityChange(this, handleTexturesDensityChange);

    }

/// Internal

    function handleTexturesDensityChange(density:Float, prevDensity:Float):Void {

        if (density != prevDensity && this.density == -1) {
            updateRenderTextureAndContent(Math.ceil(width), Math.ceil(height), density, depthBuffer, stencil, antialiasing);
            contentDirty = false;
        }

    }

    function updateRenderTextureAndContent(filterWidth:Int, filterHeight:Int, density:Float, depthBuffer:Bool, stencil:Bool, antialiasing:Int):Void {

        var texture = mesh != null ? mesh.texture : this.texture;

        if (enabled) {
            if (meshDirty || renderTexture == null ||
                ((textureTilePacker == null || !textureTilePacker.managesTexture(renderTexture)) && (renderTexture.width != filterWidth || renderTexture.height != filterHeight || (density != -1 && renderTexture.density != density) || renderTexture.depth != depthBuffer || renderTexture.stencil != stencil || renderTexture.antialiasing != antialiasing)) ||
                (textureTilePacker != null && !textureTilePacker.managesTexture(renderTexture)) ||
                (textureTile != null && (textureTile.frameWidth != filterWidth || textureTile.frameHeight != filterHeight))
                ) {

                // Destroy any invalid texture managed by this filter
                if (renderTexture != null && (textureTilePacker == null || !textureTilePacker.managesTexture(renderTexture))) {
                    texture = null;
                    renderTexture.destroy();
                    renderTexture = null;
                }

                // Release any texture tile
                if (textureTile != null && textureTilePacker != null) {
                    textureTilePacker.releaseTile(textureTile);
                    textureTile = null;
                }

                // Instanciate a new texture or tile to match constraints
                if (filterWidth > 0 && filterHeight > 0) {
                    if (textureTilePacker != null) {
                        renderTexture = textureTilePacker.texture;
                        textureTile = textureTilePacker.allocTile(filterWidth, filterHeight);
                        tile = textureTile;
                    }
                    else {
                        renderTexture = new RenderTexture(filterWidth, filterHeight, density, depthBuffer, stencil, antialiasing);
                        renderTexture.id = textureId;
                        renderTexture.filter = textureFilter;
                        renderTexture.autoRender = autoRender;
                        tile = null;
                        texture = renderTexture;
                    }
                }
            }
        }
        else {
            // Disabled, remove any texture/tile
            if (renderTexture != null && (textureTilePacker == null || !textureTilePacker.managesTexture(renderTexture))) {
                tile = null;
                texture = null;
                renderTexture.destroy();
                renderTexture = null;
            }
        }

        if (mesh != null) {
            mesh.texture = texture;
            this.texture = null;
        }
        else {
            this.texture = texture;
        }
        meshDirty = false;

        content.size(filterWidth, filterHeight);
        content.renderTarget = renderTexture;

        // When using a texture tile, move content to match its position with tile position
        if (textureTile != null) {
            content.pos(textureTile.frameX, textureTile.frameY);
        }
        else {
            content.pos(0, 0);
        }

        if (content.contentDirty) {
            content.computeContent();
        }

    }

/// Public API

    /**
     * Manually trigger rendering when explicitRender is true.
     * 
     * This method:
     * 1. Activates content for rendering
     * 2. Waits for the render pass
     * 3. Updates the render texture
     * 4. Deactivates content
     * 5. Calls the done callback
     * 
     * Handles concurrent render calls gracefully by queuing callbacks.
     * 
     * @param done Optional callback invoked when rendering completes
     */
    public function render(?done:Void->Void):Void {

        if (!explicitRender) {
            log.warning('Explicit render is disabled on this filter. Ignoring render() call.');
            return;
        }

        // Handle concurrent renders
        if (explicitRenderState == 1) {
            if (done != null) {
                if (explicitRenderPendingResultCallbacks == null) {
                    explicitRenderPendingResultCallbacks = [];
                }
                explicitRenderPendingResultCallbacks.push(done);
                done = null;
            }
            return;
        }
        else if (explicitRenderState == 2) {
            if (done != null) {
                if (explicitRenderPendingResultCallbacks == null) {
                    explicitRenderPendingResultCallbacks = [];
                }
                explicitRenderPendingResultCallbacks.push(() -> {
                    render(done);
                    done = null;
                });
            }
            return;
        }

        // First step of render
        explicitRenderState = 1;

        if (contentDirty) {
            computeContent();
        }

        if (renderTexture == null) {
            explicitRenderState = 0;
            var callbacks = explicitRenderPendingResultCallbacks;
            explicitRenderPendingResultCallbacks = null;
            if (done != null) {
                done();
                done = null;
            }
            if (callbacks != null) {
                for (i in 0...callbacks.length) {
                    var cb = callbacks[i];
                    callbacks[i] = null;
                    cb();
                    cb = null;
                }
            }
            return;
        }

        content.active = true;

        app.onceUpdate(null, function(_) {
            if (destroyed) {
                done = null;
                return;
            }

            explicitRenderState = 2;

            if (contentDirty) {
                computeContent();
            }

            if (renderTexture == null) {
                content.active = false;
                explicitRenderState = 0;
                var callbacks = explicitRenderPendingResultCallbacks;
                explicitRenderPendingResultCallbacks = null;
                if (done != null) {
                    done();
                    done = null;
                }
                if (callbacks != null) {
                    for (i in 0...callbacks.length) {
                        var cb = callbacks[i];
                        callbacks[i] = null;
                        cb();
                        cb = null;
                    }
                }
                return;
            }

            renderTexture.renderDirty = true;

            app.onceFinishDraw(null, function() {
                if (destroyed) {
                    done = null;
                    return;
                }

                content.active = false;
                explicitRenderState = 0;
                var callbacks = explicitRenderPendingResultCallbacks;
                explicitRenderPendingResultCallbacks = null;
                if (done != null) {
                    done();
                    done = null;
                }
                if (callbacks != null) {
                    for (i in 0...callbacks.length) {
                        var cb = callbacks[i];
                        callbacks[i] = null;
                        cb();
                        cb = null;
                    }
                }
                return;

            });
        });

    }

/// Hitting visuals in content

    /**
     * Test if a visual inside the filter's content is hit at the given coordinates.
     * 
     * This method handles the coordinate transformation from screen space
     * through the filter's render texture to the visual's local space.
     * Used internally for touch/mouse hit testing on filtered content.
     * 
     * @param visual The visual to test
     * @param x Screen x coordinate
     * @param y Screen y coordinate
     * @return True if the visual is hit at the given coordinates
     */
    public function visualInContentHits(visual:Visual, x:Float, y:Float):Bool {

        var matchedHitVisual = Screen.matchedHitVisual;
        Screen.matchedHitVisual = null;

        if (hitVisual.hits(x, y)) {

            Screen.matchedHitVisual = matchedHitVisual;

            // Set matrix to tested visual
            if (visual.matrixDirty) {
                visual.computeMatrix();
            }
            _matrix.setTo(visual.matA, visual.matB, visual.matC, visual.matD, visual.matTX, visual.matTY);

            var hv = hitVisual;
            do {
                // Then concat hit visual's matrix
                //
                if (hv.matrixDirty) {
                    hv.computeMatrix();
                }

                var a1 = _matrix.a * hv.matA + _matrix.b * hv.matC;
                _matrix.b = _matrix.a * hv.matB + _matrix.b * hv.matD;
                _matrix.a = a1;
                var c1 = _matrix.c * hv.matA + _matrix.d * hv.matC;
                _matrix.d = _matrix.c * hv.matB + _matrix.d * hv.matD;
                _matrix.c = c1;
                var tx1 = _matrix.tx * hv.matA + _matrix.ty * hv.matC + hv.matTX;
                _matrix.ty = _matrix.tx * hv.matB + _matrix.ty * hv.matD + hv.matTY;
                _matrix.tx = tx1;

                // Is there another hit visual to look for?
                if (hv.computedRenderTarget != null) {
                    // Probably
                    var didFindParentHitVisual = false;
                    var parent = hv.parent;
                    if (parent != null) {
                        do {
                            if (parent.asQuad != null && Std.isOfType(parent, Filter)) {
                                var filter:Filter = cast parent;
                                if (filter.renderTexture == hv.computedRenderTarget) {
                                    // Yes
                                    hv = filter.hitVisual;
                                    didFindParentHitVisual = true;
                                    break;
                                }
                            }
                            parent = parent.parent;
                        }
                        while (parent != null);
                    }
                    if (!didFindParentHitVisual) {
                        // No, after all
                        return false;
                    }
                }
                else {
                    // Nope
                    hv = null;
                }
            }
            while (hv != null);

            // Invert and test
            _matrix.invert();
            return visual.hitTest(x, y, _matrix);

        }

        Screen.matchedHitVisual = matchedHitVisual;

        return false;

    }

/// Overrides

    override function set_width(width:Float):Float {
        if (this.width == width) return width;
        contentDirty = true;
        return super.set_width(width);
    }

    override function set_height(height:Float):Float {
        if (this.height == height) return height;
        contentDirty = true;
        return super.set_height(height);
    }

    override function computeContent() {
        updateRenderTextureAndContent(Math.ceil(width), Math.ceil(height), density, depthBuffer, stencil, antialiasing);
        contentDirty = false;
    }

    override function destroy() {

        // Will unbind touch if needed
        hitVisual = null;

        texture = null;
        if (renderTexture != null && (textureTilePacker == null || !textureTilePacker.managesTexture(renderTexture))) {
            renderTexture.destroy();
            renderTexture = null;
        }
        textureTilePacker = null;
        renderTexture = null;

        if (mesh != null) {
            var _mesh = mesh;
            mesh = null;
            _mesh.destroy();
        }

        neverEmpty = false;

        explicitRenderPendingResultCallbacks = null;

        content = null;

        super.destroy();
    }

}
