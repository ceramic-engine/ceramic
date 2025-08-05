package ceramic;

import ceramic.Assets;
import ceramic.Shortcuts.*;

using StringTools;

#if !ceramic_no_rendertexture_initial_clear
import ceramic.Quad;
#end

/**
 * A texture that can be rendered to, allowing off-screen rendering.
 * 
 * RenderTexture enables rendering visuals to a texture instead of the screen.
 * This is essential for many advanced graphics techniques and effects.
 * 
 * Key features:
 * - Off-screen rendering for post-processing effects
 * - Render-to-texture for reflections, shadows, minimaps
 * - Texture composition and layering
 * - Dynamic texture generation
 * - Render dependency management
 * 
 * Common uses:
 * - Post-processing filters (blur, glow, distortion)
 * - Dynamic texture generation (procedural textures)
 * - Render passes for complex effects
 * - UI rendering to texture
 * - Reflection/refraction effects
 * - Shadow mapping
 * 
 * RenderTextures are automatically managed by Ceramic's rendering system,
 * which handles render order based on texture dependencies.
 * 
 * ```haxe
 * // Create a render texture
 * var rt = new RenderTexture(512, 512);
 * 
 * // Render visuals to it
 * myVisual.renderTarget = rt;
 * 
 * // Use as a regular texture
 * var quad = new Quad();
 * quad.texture = rt;
 * 
 * // Manual rendering with stamp
 * rt.autoRender = false;
 * rt.stamp(myVisual, () -> {
 *     trace('Rendering complete');
 * });
 * 
 * // Clear with color
 * rt.clear(Color.BLUE, 0.5, 0, 0, 100, 100, () -> {
 *     trace('Clear complete');
 * });
 * ```
 * 
 * @see Texture
 * @see Visual.renderTarget
 * @see Filter
 */
@:allow(ceramic.App)
class RenderTexture extends Texture {

    static var _clearQuad:Quad = null;

    /**
     * Whether this texture automatically renders when visuals target it.
     * - true: Renders automatically when needed (default)
     * - false: Manual control via stamp() or renderDirty flag
     */
    public var autoRender:Bool = true;

    /**
     * Whether to clear the texture before each render.
     * - true: Clears to transparent before rendering (default)
     * - false: Preserves previous contents (for accumulation effects)
     */
    public var clearOnRender:Bool = true;

    /**
     * Marks the texture as needing to be rendered.
     * Set to true to trigger a render in the next frame.
     * Automatically set when visuals targeting this texture change.
     */
    public var renderDirty:Bool = false;

    /**
     * Whether this render texture has a depth buffer.
     * Required for proper depth testing and 3D rendering.
     */
    public var depth(default, null):Bool = true;

    /**
     * Whether this render texture has a stencil buffer.
     * Required for stencil-based masking effects.
     */
    public var stencil(default, null):Bool = true;

    /**
     * Antialiasing level (multisampling).
     * - 0 = No antialiasing (default)
     * - 2, 4, 8, etc. = Number of samples
     * Higher values provide smoother edges but use more GPU resources.
     */
    public var antialiasing(default, null):Int = 0;

    #if ceramic_rendertexture_priority_use_haxe_map
    @:noCompletion public var dependingTextures:Map<Int,Int> = null;
    #else
    @:noCompletion public var dependingTextures:IntIntMap = null;
    #end

    /**
     * Render priority for dependency sorting.
     * Used internally to determine render order when textures depend on each other.
     * Higher priority textures render first.
     */
    public var priority(default, null):Float = 0;

    @:noCompletion public var incomingEdges:Int = 0;

    #if ceramic_texture_first_stamp_prerender
    var _didStampOnce:Bool = false;
    #end

    @:allow(ceramic.Renderer)
    var _usedInRendering:Bool = false;

    @:allow(ceramic.Renderer)
    var _renderedOnce(default, set):Bool = false;
    function set__renderedOnce(_renderedOnce:Bool):Bool {
        this._renderedOnce = _renderedOnce;
        #if !ceramic_no_rendertexture_initial_clear
        if (_renderedOnce && _initialClearQuad != null) {
            _initialClearQuad.destroy();
            _initialClearQuad = null;
        }
        #end
        return _renderedOnce;
    }

    #if !ceramic_no_rendertexture_initial_clear
    var _initialClearQuad:Quad = null;
    #end

/// Lifecycle

    /**
     * Creates a new render texture.
     * 
     * @param width Width in logical pixels
     * @param height Height in logical pixels
     * @param density Pixel density multiplier (-1 = use screen density)
     * @param depth Enable depth buffer (default: true)
     * @param stencil Enable stencil buffer (default: true)
     * @param antialiasing Multisampling level (default: 0)
     */
    public function new(width:Float, height:Float, density:Float = -1, depth:Bool = true, stencil:Bool = true, antialiasing:Int = 0 #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end) {

        if (density == -1) density = screen.texturesDensity;

        this.depth = depth;
        this.stencil = stencil;
        this.antialiasing = antialiasing;

        var backendItem = app.backend.textures.createRenderTarget(
            Math.round(width * density),
            Math.round(height * density),
            depth, stencil, antialiasing
        );

        super(backendItem, density #if ceramic_debug_entity_allocs , pos #end);

        isRenderTexture = true;
        asRenderTexture = this;

        app.renderTextures.push(this);

        #if !ceramic_no_rendertexture_initial_clear
        // We use an empty quad just to trigger an initial draw from the renderer
        // and ensure that this render texture is cleared properly and looks transparent by default.
        // Done only once per render texture. The quad is destroyed right after.
        _initialClearQuad = new Quad();
        _initialClearQuad.pos(0, 0);
        _initialClearQuad.size(0, 0);
        _initialClearQuad.transparent = false;
        _initialClearQuad.renderTarget = this;
        renderDirty = true;
        #end

    }

    override function destroy() {

        super.destroy();

        if (_initialClearQuad != null) {
            _initialClearQuad.destroy();
            _initialClearQuad = null;
        }

        app.renderTextures.remove(this);

    }

/// Public API / Utilities

    /**
     * Draws the given visual onto the render texture.
     * 
     * The drawing operation is asynchronous - it happens during the next
     * render frame. The visual is temporarily assigned to this render texture,
     * rendered, then restored to its original state.
     * 
     * This is typically used with autoRender set to false for manual control.
     * 
     * @param visual The visual to render onto this texture
     * @param done Callback invoked after rendering completes
     */
    public function stamp(visual:Visual, done:Void->Void) {

        #if ceramic_texture_first_stamp_prerender
        if (_didStampOnce) {
            _stamp(visual, done);
        }
        else {
            var q = new Quad();
            q.size(1, 1);
            q.alpha = 0.001;
            q.pos(-2, -2);
            _stamp(q, function() {
                q.destroy();
                q = null;
                _didStampOnce = true;
                _stamp(visual, done);
            });
        }
        #else
        _stamp(visual, done);
        #end

    }

    function _stamp(visual:Visual, done:Void->Void) {

        // Keep original values as needed
        var visualParent = visual.parent;
        var visualRenderTarget = visual.renderTarget;
        var visualVisible = visual.visible;

        // Set new values
        if (visualParent != null) visualParent.remove(visual);
        visual.renderTarget = this;
        visual.visible = true;

        // Running post-update code allows to ensure this is executed after visuals
        // have been prepared for update, but before this is applied
        app.oncePreUpdate(this, function(_) {

        // On some backends, we need to wait one more frame to get stamp result
        #if ceramic_texture_stamp_delayed
        app.oncePreUpdate(this, function(_) {
        #end

        renderDirty = true;

        app.onceFinishDraw(this, function() {

            // Restore visual state
            visual.visible = visualVisible;
            visual.renderTarget = visualRenderTarget;
            if (visualParent != null) {
                visualParent.add(visual);
                visualParent = null;
            }
            visual = null;
            visualRenderTarget = null;

            done();
            done = null;

        });

        #if ceramic_texture_stamp_delayed
        });
        #end

        });

    }

    /**
     * Clears the texture or a specific area with a color.
     * 
     * The clear operation is asynchronous - it happens during the next
     * render frame. Use -1 for clip parameters to clear the entire texture.
     * 
     * This is typically used with autoRender set to false for manual control.
     * 
     * @param color Fill color (default: white)
     * @param alpha Fill alpha (default: 0 = transparent)
     * @param clipX X position of area to clear (-1 = full texture)
     * @param clipY Y position of area to clear (-1 = full texture)
     * @param clipWidth Width of area to clear (-1 = full texture)
     * @param clipHeight Height of area to clear (-1 = full texture)
     * @param done Callback invoked after clearing completes
     */
    public function clear(color:Color = 0xFFFFFF, alpha:Float = 0, clipX:Float = -1, clipY:Float = -1, clipWidth:Float = -1, clipHeight:Float = -1, done:Void->Void) {

        if (_clearQuad == null) {
            _clearQuad = new Quad();
            _clearQuad.active = false;
            _clearQuad.blending = SET;
            _clearQuad.anchor(0, 0);
        }

        _clearQuad.color = color;
        _clearQuad.alpha = alpha;
        _clearQuad.depth = -1;

        if (clipX != -1 && clipY != -1 && clipWidth != -1 && clipHeight != -1) {
            _clearQuad.size(clipWidth, clipHeight);
            _clearQuad.pos(clipX, clipY);
        }
        else {
            _clearQuad.size(width, height);
            _clearQuad.pos(0, 0);
        }

        stamp(_clearQuad, done);

    }

    @:noCompletion inline public function dependsOnTexture(texture:Texture):Bool {

        #if ceramic_rendertexture_priority_use_haxe_map
        return dependingTextures != null && dependingTextures.exists(texture.index) && dependingTextures.get(texture.index) > 0;
        #else
        return dependingTextures != null && dependingTextures.get(texture.index) > 0;
        #end

    }

    @:noCompletion inline public function dependsOnTextureCount(texture:Texture):Int {

        #if ceramic_rendertexture_priority_use_haxe_map
        return dependingTextures != null && dependingTextures.exists(texture.index) ? dependingTextures.get(texture.index) : 0;
        #else
        return dependingTextures != null ? dependingTextures.get(texture.index) : 0;
        #end

    }

    @:noCompletion inline public function incrementDependingTextureCount(texture:Texture):Void {

        if (dependingTextures == null) {
            #if ceramic_rendertexture_priority_use_haxe_map
            dependingTextures = new Map<Int,Int>();
            #else
            dependingTextures = new IntIntMap();
            #end
        }

        #if ceramic_rendertexture_priority_use_haxe_map
        var prevValue = dependingTextures.exists(texture.index) ? dependingTextures.get(texture.index) : 0;
        #else
        var prevValue = dependingTextures.get(texture.index);
        #end

        dependingTextures.set(texture.index, prevValue + 1);

    }

    @:noCompletion inline public function resetDependingTextureCounts():Void {

        if (dependingTextures != null) {
            dependingTextures.clear();
        }

    }

/// Print

    override function toString():String {

        if (id != null) {
            var name = id;
            if (name.startsWith('texture:')) name = name.substr(8);
            return 'RenderTexture($name $width $height $density #$index/$priority)';
        } else {
            return 'RenderTexture($width $height $density #$index/$priority)';
        }

    }

}
