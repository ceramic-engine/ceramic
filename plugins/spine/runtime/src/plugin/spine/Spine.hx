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

    var slotInfo:SlotInfo = new SlotInfo();

    var subSpines:Array<Spine> = null;

    var boundParentSlots:Map<String,Array<BindSlot>> = null;

    /** Computed from `boundParentSlots` */
    var boundChildSlots:Map<String,BindSlot> = null;

    var boundChildSlotsDirty:Bool = false;

/// Events

    /** When a spine animation has completed/finished. */
    @event function complete();

    /** When a slot is about to be updated. */
    @event function updateSlot(info:SlotInfo);

/// Properties

    /** Is `true` if this spine animation has a parent animation. */
    public var hasParentSpine(default,null):Bool = false;

    /** The Spine data used to animate this animation. */
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

    /** The current pose for a skeleton. */
    public var skeleton(default,null):Skeleton;

    /** The setup pose and all of the stateless data for a skeleton. */
    public var skeletonData(default, null):SkeletonData;

    /** Applies animations over time, queues animations for later playback, mixes (crossfading) between animations, and applies. */
    public var state(default, null):AnimationState;

    /** Stores mix (crossfade) durations to be applied when animations are changed. */
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

    /** Reset at change */
    public var resetAtChange:Bool = true;

/// Properties (internal)

    var resetSkeleton:Bool = false;

/// Lifecycle

    public function new() {

        super();

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
            if (resetAtChange) reset();

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

    /** Start running an animation available in the skeleton. **/
    public function animate(animationName:String, loop:Bool = false):Void {
        if (destroyed) return;

        var track;

        if (animationName == null) {
            track = state.setEmptyAnimation(0, 0);
        } else {
            track = state.setAnimationByName(0, animationName, loop);
        }

        // If we are paused, ensure new anim gets rendered once
        if (paused) {
            update(0.1);
            track.trackTime = 0;
        }

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

    public function update(delta:Float):Void {

        if (hasParentSpine) {
            // Our parent is a spine animation and is responsible
            // of updating our own data and rendering it.
            return;
        }

        // Update skeleton
        updateSkeleton(delta);

        if (visible) {
            // We are visible and are root spine animation, let's render
            render(delta, 0);
        }

    } //update

/// Internal

    /** Update skeleton with the given delta time. */
    function updateSkeleton(delta:Float):Void {

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

    } //updateSkeleton

    var animQuads:Array<Quad> = [];

    /** Process spine draw order and output quads and meshes. */
    function render(delta:Float, z:Float) {

        if (boundChildSlotsDirty) {
            computeBoundChildSlots();
        }

        var drawOrder:Array<Slot> = skeleton.drawOrder;
        var len:Int = drawOrder.length;

        var r:Float;
        var g:Float;
        var b:Float;
        var a:Float;
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
        var slotName:String = null;
        var boundSlot:BindSlot = null;
        var microDepth:Float = 0.0001;
        var flipRegion:Bool = false;
        var flipBone:Bool = false;
        var boneData:BoneData = null;
        var setupRotation:Float = 0;

        // Set flip
        flipX = skeleton.flipX ? -1 : 1;
        flipY = skeleton.flipY ? -1 : 1;
        flip = flipX * flipY;

        for (i in 0...len)
        {
            slot = drawOrder[i];
            bone = slot.bone;
            slotName = slot.data.name;
            boundSlot = null;

            // Emit event and allow to override drawing of this slot
            slotInfo.customTransform = null;
            slotInfo.depth = z;
            slotInfo.drawDefault = true;
            slotInfo.slot = slot;

            offsetX = 0;
            offsetY = 0;

            emptySlotMesh = true;
            if (slot.attachment != null)
            {
                if (boundChildSlots != null) {
                    boundSlot = boundChildSlots.get(slotName);
                } else {
                    boundSlot = null;
                }

                if (Std.is(slot.attachment, RegionAttachment))
                {
                    regionAttachment = cast slot.attachment;
                    atlasRegion = cast(regionAttachment.getRegion(), AtlasRegion);
                    texture = cast atlasRegion.page.rendererObject;

                    offsetX = regionAttachment.getOffset().unsafeGet(2);
                    offsetY = regionAttachment.getOffset().unsafeGet(3);

                    tx = skeleton.x + offsetX * bone.a + offsetY * bone.b + bone.worldX;
                    ty = skeleton.y - (offsetX * bone.c + offsetY * bone.d + bone.worldY);

                    _matrix.setTo(
                        bone.a,
                        bone.c * flip * -1,
                        bone.b * flip * -1,
                        bone.d,
                        tx,
                        ty
                    );
                    slotInfo.transform.setTo(
                        _matrix.a,
                        _matrix.b,
                        _matrix.c,
                        _matrix.d,
                        skeleton.x + bone.worldX,
                        skeleton.y - bone.worldY
                    );

                    emitUpdateSlot(slotInfo);

                    if (slotInfo.drawDefault && (boundSlot == null || boundSlot.parentVisible)) {

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

                        quad.anchor(0, 0);
                        quad.color = Color.fromRGBFloat(r, g, b);
                        quad.alpha = a;
                        quad.blending = isAdditive ? Blending.ADD : Blending.NORMAL;
                        quad.depth = z;
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

                        flipRegion = regionAttachment.getScaleX() * regionAttachment.getScaleY() < 0;
                        flipBone = bone.scaleX * bone.scaleY < 0;

                        quad.transform.rotate(-regionAttachment.getRotation() * _degRad);

                        quad.transform.concat(_matrix);

                        if (boundSlot != null) {

                            setupRotation = 0.0;
                            boneData = bone.getData();
                            while (boneData != null) {
                                setupRotation += boneData.getRotation();
                                boneData = boneData.getParent();
                            }

                            quad.transform.translate(-slotInfo.transform.tx, -slotInfo.transform.ty);

                            quad.transform.translate(
                                -(offsetX * bone.a + offsetY * bone.b),
                                (offsetX * bone.c + offsetY * bone.d)
                            );

                            quad.transform.scale(
                                bone.scaleX < 0 ? -1 : 1,
                                bone.scaleY < 0 ? -1 : 1
                            );
                            
                            quad.transform.translate(
                                bone.scaleX < 0 ? -(offsetX * bone.a + offsetY * bone.b) : (offsetX * bone.a + offsetY * bone.b),
                                bone.scaleY < 0 ? (offsetX * bone.c + offsetY * bone.d) : -(offsetX * bone.c + offsetY * bone.d)
                            );

                            if (setupRotation != 0.0) quad.transform.rotate(90 * _degRad);

                            if (slotInfo.customTransform != null) {
                                quad.transform.concat(slotInfo.customTransform);
                            }

                            quad.transform.concat(boundSlot.parentTransform);

                            quad.depth = boundSlot.parentDepth + microDepth;
                            microDepth += 0.0001;
                        }
                        else {
                            if (slotInfo.customTransform != null) {
                                quad.transform.concat(slotInfo.customTransform);
                            }
                        }
                    }

                }
                else if (Std.is(slot.attachment, MeshAttachment)) {

                    meshAttachment = cast slot.attachment;

                    tx = skeleton.x + bone.worldX;
                    ty = skeleton.y - bone.worldY;
                    
                    slotInfo.transform.setTo(
                        bone.a,
                        bone.c * flip * -1,
                        bone.b * flip * -1,
                        bone.d,
                        tx,
                        ty
                    );

                    emitUpdateSlot(slotInfo);

                    mesh = slotMeshes.get(slot.data.index);

                    if (slotInfo.drawDefault && (boundSlot == null || boundSlot.parentVisible)) {

                        emptySlotMesh = false;

                        if (mesh == null)
                        {
                            atlasRegion = cast(meshAttachment.getRegion(), AtlasRegion);
                            texture = cast atlasRegion.page.rendererObject;
                            mesh = new Mesh();
                            mesh.transform = new Transform();
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
                            mesh.depth = z;
                            mesh.scaleY = -1;
                        }

                        if (boundSlot != null) {

                            setupRotation = 0.0;
                            boneData = bone.getData();
                            while (boneData != null) {
                                setupRotation += boneData.getRotation();
                                boneData = boneData.getParent();
                            }

                            mesh.transform.identity();
                            mesh.transform.translate(-slotInfo.slot.data.boneData.x, slotInfo.slot.data.boneData.y);
                            mesh.transform.scale(
                                bone.scaleX < 0 ? -1 : 1,
                                bone.scaleY < 0 ? -1 : 1
                            );
                            if (setupRotation != 0.0) mesh.transform.rotate(90 * _degRad);
                            mesh.transform.concat(boundSlot.parentTransform);

                            mesh.depth = boundSlot.parentDepth + microDepth;
                            microDepth += 0.0001;

                            if (slotInfo.customTransform != null) {
                                mesh.transform.concat(slotInfo.customTransform);
                            }
                        }
                        else {
                            if (slotInfo.customTransform != null) {
                                mesh.transform.setToTransform(slotInfo.customTransform);
                            }
                            else {
                                mesh.transform.identity();
                            }
                        }
                    }
                    else {
                        if (mesh != null) {
                            // If the mesh was visible before during the animation,
                            // Let's not destroy it and just make it not visible.
                            mesh.visible = false;
                        }
                    }

                }

                z++;
            }

            if (emptySlotMesh) {
                mesh = slotMeshes.get(slot.data.index);
                if (mesh != null) {
                    mesh.destroy();
                    slotMeshes.remove(slot.data.index);
                }
            }

            // Gather information for child animations if needed
            if (subSpines != null) {
                for (sub in subSpines) {
                    if (sub.boundParentSlots != null && sub.boundParentSlots.exists(slotName)) {
                        for (bindInfo in sub.boundParentSlots.get(slotName)) {
                            
                            // Keep parent info
                            if (slot.attachment == null) {
                                bindInfo.parentVisible = false;
                            }
                            else {
                                bindInfo.parentVisible = true;
                                bindInfo.parentDepth = slotInfo.depth;
                                bindInfo.parentTransform.setTo(
                                    slotInfo.transform.a,
                                    slotInfo.transform.b,
                                    slotInfo.transform.c,
                                    slotInfo.transform.d,
                                    slotInfo.transform.tx,
                                    slotInfo.transform.ty
                                );
                            }

                        }
                    }
                }
            }

        }

        // Remove unused quads
        while (usedQuads < animQuads.length) {
            var quad = animQuads.pop();
            quad.destroy();
        }

        // Render children (if any)
        if (subSpines != null) {
            for (sub in subSpines) {
                sub.updateSkeleton(delta);
                sub.render(delta, z);
            }
        }

    } //render

/// Spine animations compositing

    /** Add a child visual. If the child is a spine animation,
        it will be managed by its parent and compositing becomes possible. */
    override public function add(visual:Visual):Void {

        // Default behavior
        super.add(visual);

        // Spine case
        if (Std.is(visual, Spine)) {
            if (subSpines == null) subSpines = [];
            var item = cast(visual, Spine);
            item.hasParentSpine = true;
            subSpines.push(item);
        }

    } //add

    override public function remove(visual:Visual):Void {

        // Default behavior
        super.remove(visual);

        // Spine case
        if (Std.is(visual, Spine)) {
            var item = cast(visual, Spine);
            item.hasParentSpine = false;
            subSpines.remove(item);
        }

    } //add

    /** Bind a slot of parent animation to one of our local slots or bones. */
    public function bindParentSlot(parentSlot:String, options:BindSlotOptions) {

        var info = new BindSlot();
        info.fromParentSlot = parentSlot;

        if (options.toLocalBone != null) info.toLocalBone = options.toLocalBone;
        if (options.toLocalSlot != null) info.toLocalSlot = options.toLocalSlot;

        if (boundParentSlots == null) boundParentSlots = new Map();
        var bindList = boundParentSlots.get(parentSlot);
        if (bindList == null) {
            bindList = [];
            boundParentSlots.set(parentSlot, bindList);
        }
        bindList.push(info);

        boundChildSlotsDirty = true;

    } //bindParentSlot

    /** Compute `boundChildSlots` from `boundParentSlots` to make it more efficient
        to gather parent slot transformations when drawing child animation. */
    function computeBoundChildSlots() {

        boundChildSlots = new Map();

        for (parentSlot in boundParentSlots.keys()) {
            var bindList = boundParentSlots.get(parentSlot);
            for (bindItem in bindList) {
                if (bindItem.toLocalSlot != null && !boundChildSlots.exists(bindItem.toLocalSlot)) {
                    boundChildSlots.set(bindItem.toLocalSlot, bindItem);
                }
            }
        }

    } //computeBoundChildSlots

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

typedef BindSlotOptions = {

    @:optional var toLocalBone:String;

    @:optional var toLocalSlot:String;

} //BindSlotOptions

@:allow(plugin.spine.Spine)
private class BindSlot {

    public var fromParentSlot:String = null;

    public var toLocalBone:String = null;

    public var toLocalSlot:String = null;

    public var parentDepth:Float = 0;

    public var parentVisible:Bool = false;

    public var parentTransform:Transform = new Transform();

    public function new() {}

    function toString() {
        var props:Dynamic = {};
        if (fromParentSlot != null) props.fromParentSlot = fromParentSlot;
        if (toLocalBone != null) props.toLocalBone = toLocalBone;
        if (toLocalSlot != null) props.toLocalSlot = toLocalSlot;
        props.parentDepth = parentDepth;
        if (parentTransform != null) props.parentTransform = parentTransform;
        if (parentVisible != null) props.parentVisible = parentVisible;
        return '' + props;
    }

} //BindSlot

/** An object to hold every needed info about updating a slot. */
class SlotInfo {

    /** The slot that is about to have its attachment drawn (if any). */
    public var slot:spine.Slot = null;

    /** A custom transform applied to this slot (defaults to identity). */
    public var customTransform:Transform = null;

    /** The bone transform, applied to this slot. */
    public var transform(default,null):Transform = new Transform();

    /** Set this to `false` if you want to disable drawing of this slot attachment. */
    public var drawDefault:Bool = true;

    /** The depth in which the slot attachment should be drawn. */
    public var depth:Float = 0;

    public function new() {}

} //SlotInfo
