package plugin.spine;

import spine.support.graphics.TextureAtlas;
import spine.Animation;
import spine.AnimationState;
import spine.attachments.*;
import spine.*;

import ceramic.Visual;
import ceramic.Quad;
import ceramic.Mesh;
import ceramic.Texture;
import ceramic.Transform;
import ceramic.Color;
import ceramic.AlphaColor;
import ceramic.Blending;
import ceramic.RotateFrame;
import ceramic.Shortcuts.*;

using ceramic.Extensions;

class Spine extends Visual {

/// Internal

    static var _degRad:Float = Math.PI / 180.0;

    static var _matrix:Transform = new Transform();

    static var _worldVertices:Array<Float> = [0,0,0,0,0,0,0,0];

/// Spine Animation State listener

    var listener:SpineListener;

    var slotMeshes:Map<Int,Mesh> = new Map();

/// Events

    /** Event: when a spine animation has completed/finished. */
    @event function complete();

/// Properties

    public var spineData(default,set):SpineData = null;
    function set_spineData(spineData:SpineData):SpineData {
        if (this.spineData == spineData) return spineData;
        
        // Save animation info
        var prevSpineData = this.spineData;
        var toResume:Array<Dynamic> = null;
        if (prevSpineData != null) {
            toResume = [];

            var i = 0;
            var tracks = state.getTracks();

            for (track in tracks) {

                if (track.animation != null) {

                    toResume.push([
                        track.animation.name,
                        track.timeScale,
                        track.loop,
                        track.trackTime
                    ]);
                }

                i++;
            }

        }

        this.spineData = spineData;

        contentDirty = true;
        computeContent();

        // Restore animation info (if any)
        if (toResume != null && toResume.length > 0) {

            var i = 0;
            for (entry in toResume) {

                var animationName:String = entry[0];
                var timeScale:Float = entry[1];
                var loop:Bool = entry[2];
                var trackTime:Float = entry[3];

                var animation = skeletonData.findAnimation(animationName);
                if (animation != null) {
                    var track = state.setAnimationByName(i, animationName, loop);
                    track.trackTime = trackTime;
                    track.timeScale = timeScale;
                }

                i++;
            }

        }

        return spineData;
    }

    public var skeleton(default,null):Skeleton;

    public var skeletonData(default, null):SkeletonData;

    public var state(default, null):AnimationState;

    public var stateData(default, null):AnimationStateData;

    /** Is this animation paused? Default is `false`. */
    public var paused(default, set):Bool = false;
    function set_paused(paused:Bool):Bool {
        if (this.paused == paused) return paused;

        this.paused = paused;
        if (paused) {
            app.offUpdate(update);
        } else {
            app.onUpdate(this, update);
        }

        return paused;
    }

/// Properties (internal)

    var resetSkeleton:Bool = false;

/// Lifecycle

    public function new() {

        super();

        childrenDepthRange = 0.999;

        app.onUpdate(this, update);

    } //new

/// Content

    override function computeContent():Void {

        skeletonData = spineData.skeletonData;

        stateData = new AnimationStateData(skeletonData);
        state = new AnimationState(stateData);

        skeleton = new Skeleton(skeletonData);

        // Bind events
        listener = new SpineListener();

        listener.onStart = function(track) {

            // Reset skeleton at the start of each animation, before next update
            reset();

        };

        listener.onComplete = function(track) {
            
            emitComplete();

        };

        listener.onEnd = function(track) {
            
        };

        listener.onEvent = function(track, event) {
            
        };
        
        state.addListener(listener);

        contentDirty = false;

    } //computeContent

/// Public API

    public function animate(animationName:String, loop:Bool = false):Void {
        if (destroyed) return;

        state.setAnimationByName(0, animationName, loop);

    } //animate

    /** Reset the animation (set to setup pose). */
    public function reset():Void {
        if (destroyed) return;

        resetSkeleton = true;

    } //reset

/// Cleanup

    function destroy() {

        for (mesh in slotMeshes) {
            if (mesh != null) mesh.destroy();
        }
        slotMeshes = null;

    } //destroy

/// Internal

    public function update(delta:Float):Void {

        if (contentDirty) {
            computeContent();
        }

        if (destroyed) {
            return;
        }

        if (resetSkeleton) {
            resetSkeleton = false;
            if (skeleton != null) skeleton.setToSetupPose();
        }

        if (skeleton != null) skeleton.update(delta);
        if (state != null) state.update(delta);
        if (state != null && skeleton != null) state.apply(skeleton);
        if (skeleton != null) skeleton.updateWorldTransform();

        if (visible) {
            render();
        }

    } //update

    var animQuads:Array<Quad> = [];

    function render() {

        var drawOrder:Array<Slot> = skeleton.drawOrder;
        var len:Int = drawOrder.length;

        var r:Float;
        var g:Float;
        var b:Float;
        var a:Float;
        var z:Float = 0;
        var flip:Float;
        var flipX:Float;
        var flipY:Float;
        var offsetX:Float;
        var offsetY:Float;
        var isAdditive:Bool;
        var regionAttachment:RegionAttachment;
        var atlasRegion:AtlasRegion;
        var texture:Texture;
        var bone:Bone;
        var quad:Quad;
        var slot:Slot;
        var usedQuads = 0;
        var meshAttachment:MeshAttachment;
        var mesh:Mesh;
        var verticesLength:Int;
        var colors:Array<AlphaColor>;
        var alphaColor:AlphaColor;
        var emptySlotMesh:Bool = false;

        for (i in 0...len)
        {
            slot = drawOrder[i];
            emptySlotMesh = true;
            if (slot.attachment != null)
            {
                if (Std.is(slot.attachment, RegionAttachment))
                {
                    regionAttachment = cast slot.attachment;
                    atlasRegion = cast(regionAttachment.getRegion(), AtlasRegion);
                    texture = cast atlasRegion.page.rendererObject;
                    bone = slot.bone;

                    r = skeleton.color.r * slot.color.r * regionAttachment.getColor().r;
                    g = skeleton.color.g * slot.color.g * regionAttachment.getColor().g;
                    b = skeleton.color.b * slot.color.b * regionAttachment.getColor().b;
                    a = skeleton.color.a * slot.color.a * regionAttachment.getColor().a * alpha;

                    isAdditive = slot.data.blendMode == BlendMode.additive;
                    
                    // Reuse or create quad
                    quad = usedQuads < animQuads.length ? animQuads[usedQuads] : null;
                    if (quad == null) {
                        quad = new Quad();
                        quad.transform = new Transform();
                        animQuads.push(quad);
                        add(quad);
                    }
                    usedQuads++;

                    // Set quad values
                    //
                    flipX = skeleton.flipX ? -1 : 1;
                    flipY = skeleton.flipY ? -1 : 1;

                    flip = flipX * flipY;

                    offsetX = regionAttachment.getOffset().unsafeGet(2);
                    offsetY = regionAttachment.getOffset().unsafeGet(3);

                    tx = skeleton.x + offsetX * bone.a + offsetY * bone.b + bone.worldX;
                    ty = skeleton.y - (offsetX * bone.c + offsetY * bone.d + bone.worldY);

                    quad.anchor(0, 0);
                    quad.color = Color.fromRGBFloat(r, g, b);
                    quad.alpha = a;
                    quad.blending = isAdditive ? Blending.ADD : Blending.NORMAL;
                    quad.depth = z++;
                    quad.texture = texture;
                    quad.frameX = atlasRegion.x / texture.density;
                    quad.frameY = atlasRegion.y / texture.density;
                    quad.frameWidth = atlasRegion.width / texture.density;
                    quad.frameHeight = atlasRegion.height / texture.density;
                    quad.scaleX = regionAttachment.getWidth() / quad.frameWidth;
                    quad.scaleY = regionAttachment.getHeight() / quad.frameHeight;
                    quad.scaleX *= regionAttachment.getScaleX();
                    quad.scaleY *= regionAttachment.getScaleY();
                    quad.rotateFrame = atlasRegion.rotate ? RotateFrame.ROTATE_90 : RotateFrame.NONE;

                    quad.transform.identity();

                    if (regionAttachment.getScaleX() * regionAttachment.getScaleY() < 0) {
                        quad.transform.rotate((180 + regionAttachment.getRotation()) * _degRad);
                    } else {
                        quad.transform.rotate(-regionAttachment.getRotation() * _degRad);
                    }

                    _matrix.setTo(
                        bone.a,
                        bone.c * flip * -1,
                        bone.b * flip * -1,
                        bone.d,
                        tx,
                        ty
                    );

                    quad.transform.concat(_matrix);

                }
                else if (Std.is(slot.attachment, MeshAttachment)) {

                    emptySlotMesh = false;

                    meshAttachment = cast slot.attachment;

                    mesh = slotMeshes.get(slot.data.index);
                    if (mesh == null)
                    {
                        atlasRegion = cast(meshAttachment.getRegion(), AtlasRegion);
                        texture = cast atlasRegion.page.rendererObject;
                        mesh = new Mesh();
                        add(mesh);
                        slotMeshes.set(slot.data.index, mesh);
                        mesh.texture = texture;
                    }

                    verticesLength = meshAttachment.vertices.length;
                    if (verticesLength == 0) {
                        mesh.visible = false;
                    }
                    else {
                        mesh.visible = true;

                        meshAttachment.computeWorldVertices(slot, 0, verticesLength * 2, mesh.vertices, 0, 2);
                        if (mesh.vertices.length > verticesLength) {
                            mesh.vertices.splice(verticesLength, mesh.vertices.length - verticesLength);
                        }
                        mesh.uvs = meshAttachment.getUVs();
                        mesh.indices = meshAttachment.getTriangles();

                        isAdditive = slot.data.blendMode == BlendMode.additive;

                        r = skeleton.color.r * slot.color.r * meshAttachment.getColor().r;
                        g = skeleton.color.g * slot.color.g * meshAttachment.getColor().g;
                        b = skeleton.color.b * slot.color.b * meshAttachment.getColor().b;
                        a = skeleton.color.a * slot.color.a * meshAttachment.getColor().a * alpha;

                        alphaColor = new AlphaColor(Color.fromRGBFloat(r, g, b), Math.round(a * 255));
                        colors = mesh.colors;
                        if (colors.length < verticesLength) {
                            for (j in 0...verticesLength) {
                                colors[j] = alphaColor;
                            }
                        } else {
                            for (j in 0...verticesLength) {
                                colors.unsafeSet(j, alphaColor);
                            }
                            if (colors.length > verticesLength) {
                                colors.splice(verticesLength, colors.length - verticesLength);
                            }
                        }
                        mesh.blending = isAdditive ? Blending.ADD : Blending.NORMAL;
                        mesh.depth = z++;
                        mesh.scaleY = -1;
                    }

                }
            }

            if (emptySlotMesh) {
                mesh = slotMeshes.get(slot.data.index);
                if (mesh != null) {
                    mesh.destroy();
                    slotMeshes.remove(slot.data.index);
                }
            }
        }

        // Remove unused quads
        while (usedQuads < animQuads.length) {
            var quad = animQuads.pop();
            quad.destroy();
        }

    } //render

} //Visual

class SpineListener implements AnimationStateListener {

    public function new() {}
    
    /** Invoked when this entry has been set as the current entry. */
    public dynamic function onStart(entry:TrackEntry):Void {};
    public function start(entry:TrackEntry):Void {
        if (onStart != null) onStart(entry);
    }

    /** Invoked when another entry has replaced this entry as the current entry. This entry may continue being applied for
     * mixing. */
    public dynamic function onInterrupt(entry:TrackEntry):Void {}
    public function interrupt(entry:TrackEntry):Void {
        if (onInterrupt != null) onInterrupt(entry);
    }

    /** Invoked when this entry is no longer the current entry and will never be applied again. */
    public dynamic function onEnd(entry:TrackEntry):Void {}
    public function end(entry:TrackEntry):Void {
        if (onEnd != null) onEnd(entry);
    }

    /** Invoked when this entry will be disposed. This may occur without the entry ever being set as the current entry.
     * References to the entry should not be kept after <code>dispose</code> is called, as it may be destroyed or reused. */
    public dynamic function onDispose(entry:TrackEntry):Void {}
    public function dispose(entry:TrackEntry):Void {
        if (onDispose != null) onDispose(entry);
    }

    /** Invoked every time this entry's animation completes a loop. */
    public dynamic function onComplete(entry:TrackEntry):Void {}
    public function complete(entry:TrackEntry):Void {
        if (onComplete != null) onComplete(entry);
    }

    /** Invoked when this entry's animation triggers an event. */
    public dynamic function onEvent(entry:TrackEntry, event:Event) {}
    public function event(entry:TrackEntry, event:Event) {
        if (onEvent != null) onEvent(entry, event);
    }

}
