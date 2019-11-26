package ceramic;

import ceramic.RenderTexture;
import ceramic.Quad;
import ceramic.Visual;

import ceramic.Shortcuts.*;

/** A visuals that displays its children through a filter. A filter draws its children into a `RenderTexture`
    allowing to process the result through a shader, apply blending or alpha on the final result... */
class Filter extends Quad {

/// Internal

    static var _matrix:Transform = Visual._matrix;

/// Public properties

    /** If provided, this id will be assigned to `renderTexture.id`. */
    public var textureId(default, set):String = null;
    function set_textureId(textureId:String):String {
        this.textureId = textureId;
        if (renderTexture != null) {
            renderTexture.id = textureId;
        }
        return textureId;
    }

    public var content(default,null):Quad;

    /** If provided, visuals in content will react to hit tests
        and touch events as if they were inside this hit visual.
        By default, `hitVisual` is the `Filter` instance itself. */
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

    /** If `enabled` is set to `false`, no render texture will be used.
        The children will be displayed on screen directly.
        Useful to toggle a filter without touching visuals hierarchy. */
    public var enabled(default,set):Bool = true;
    function set_enabled(enabled:Bool):Bool {
        if (this.enabled == enabled) return enabled;
        this.enabled = enabled;
        contentDirty = true;
        return enabled;
    }

    /** Texture filter */
    public var textureFilter(default,set):TextureFilter = LINEAR;
    function set_textureFilter(textureFilter:TextureFilter):TextureFilter {
        if (this.textureFilter == textureFilter) return textureFilter;
        this.textureFilter = textureFilter;
        if (renderTexture != null) renderTexture.filter = textureFilter;
        return textureFilter;
    }

    /** Auto render? */
    public var autoRender(default,set):Bool = true;
    function set_autoRender(autoRender:Bool):Bool {
        if (this.autoRender == autoRender) return autoRender;
        this.autoRender = autoRender;
        if (renderTexture != null) renderTexture.autoRender = autoRender;
        return autoRender;
    }

    /** If set to true, this filter will not render automatically its children.
        It will instead set their `active` state to `false` unless explicitly rendered.
        Note that when using explicit render, `active` property on children is managed
        by this filter. */
    public var explicitRender(default,set):Bool = false;
    function set_explicitRender(explicitRender:Bool):Bool {
        if (this.explicitRender == explicitRender) return explicitRender;
        this.explicitRender = explicitRender;
        content.active = !explicitRender;
        return explicitRender;
    }

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

    public var textureTile(default,null):TextureTile = null;

    public var renderTexture(default,null):RenderTexture = null;

    public var density(default,set):Float = -1;
    function set_density(density:Float):Float {
        if (this.density == density) return density;
        this.density = density;
        contentDirty = true;
        return density;
    }

    /** Internal flag used to keep track of current explicit render state */
    var explicitRenderState:Int = 0;

    /** Used internally when concurrent renders are trigerred */
    var explicitRenderPendingResultCallbacks:Array<Void->Void> = null;

/// Lifecycle

    public function new(#if ceramic_debug_entity_allocs ?pos:haxe.PosInfos #end) {

        super(#if ceramic_debug_entity_allocs pos #end);

        content = new Quad();
        content.transparent = true;
        content.color = Color.WHITE;
        add(content);

        hitVisual = this;

    } //new

/// Internal

    function filterSize(filterWidth:Int, filterHeight:Int, density:Float):Void {

        if (enabled) {
            if (renderTexture == null ||
                ((textureTilePacker == null || !textureTilePacker.managesTexture(renderTexture)) && (renderTexture.width != filterWidth || renderTexture.height != filterHeight)) ||
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
                        renderTexture = new RenderTexture(filterWidth, filterHeight, density);
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

    } //filterSize

/// Public API

    public function render(requestFullUpdate:Bool = false, ?done:Void->Void):Void {

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
                    render(requestFullUpdate, done);
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

        if (requestFullUpdate) {
            app.requestFullUpdateAndDrawInFrame();
        }

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

    } //render

/// Hitting visuals in content

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
                            if (parent.asQuad != null && Std.is(parent, Filter)) {
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

    } //visualInContentHits

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
        filterSize(Math.ceil(width), Math.ceil(height), density);
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

        explicitRenderPendingResultCallbacks = null;

        content = null;

        super.destroy();
    }

} //Filter
