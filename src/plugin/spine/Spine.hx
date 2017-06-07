package plugin.spine;

import spine.atlas.*;
import spine.animation.*;
import spine.attachments.*;
import spine.*;

import ceramic.Visual;
import ceramic.Quad;
import ceramic.Mesh;
import ceramic.Texture;
import ceramic.Transform;
import ceramic.Color;
import ceramic.Blending;
import ceramic.Shortcuts.*;

using ceramic.Extensions;

class Spine extends Visual {

/// Internal

    static var _matrix:Transform = new Transform();

    static var _worldVertices:Array<Float> = [0,0,0,0,0,0,0,0];

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
#if spinehaxe
            var tracks = state.tracks;
#else //spine-hx
            var tracks = @:privateAccess state._tracks;
#end
            for (track in tracks) {

                if (track.animation != null) {

                    toResume.push([
                        track.animation.name,
                        track.timeScale,
                        track.loop,
#if spinehaxe
                        track.trackTime,
#else //spine-hx
                        track.time,
#end
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
#if spinehaxe
                    track.trackTime = trackTime;
#else //spine-hx
                    track.time = trackTime;
#end
                    track.timeScale = timeScale;
                }

                i++;
            }

        }

        return spineData;
    }

    public var animations(default,null):AnimationState;

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

        state.onStart.add(function(track) {

            // Reset skeleton at the start of each animation, before next update
            reset();

        });

        state.onComplete.add(function(track, count) {
            
            emitComplete();

        });

        state.onEnd.add(function(track) {
            
        });

        state.onEvent.add(function(track, event) {
            
        });

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
            renderWithQuads();
        }

    } //update

    var animQuads:Array<Quad> = [];

    function renderWithQuads() {

		var drawOrder:Array<Slot> = skeleton.drawOrder;
		var len:Int = drawOrder.length;
        var vertices = new Array<Float>();

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

        var usedQuads = 0;

		for (i in 0...len)
		{
			var slot:Slot = drawOrder[i];
			if (slot.attachment != null)
			{
				if (Std.is(slot.attachment, RegionAttachment))
				{
                    var region:RegionAttachment = cast slot.attachment;
					var atlasRegion:AtlasRegion = cast region.rendererObject;
					var texture:Texture = cast atlasRegion.page.rendererObject;
                    var bone:Bone = slot.bone;

                    r = skeleton.r * slot.r * region.r;
                    g = skeleton.g * slot.g * region.g;
                    b = skeleton.b * slot.b * region.b;
                    a = skeleton.a * slot.a * region.a * alpha;

#if spinehaxe
                    isAdditive = slot.data.blendMode == BlendMode.additive;
#else //spine-hx
                    isAdditive = slot.data.blendMode == BlendMode.Additive;
#end
                    
                    // Reuse or create quad
                    var quad:Quad = usedQuads < animQuads.length ? animQuads[usedQuads] : null;
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

                    offsetX = region.offset[2];
                    offsetY = region.offset[3];
                    tx = skeleton.x + offsetX * bone.a + offsetY * bone.b + bone.worldX;
                    ty = skeleton.y - (offsetX * bone.c + offsetY * bone.d + bone.worldY);

#if spinehaxe
                    quad.transform.setTo(
                        bone.a,
                        bone.b * flip,
                        bone.c * flip,
                        bone.d,
                        tx,
                        ty
                    );
#else //spine-hx
                    quad.transform.setTo(
                        bone.a,
                        bone.b * flip,
                        bone.c * flip,
                        bone.d,
                        tx,
                        ty
                    );
#end

                    quad.anchor(0, 0);
                    quad.color = Color.fromRGBFloat(r, g, b);
                    quad.alpha = a;
                    quad.blending = isAdditive ? Blending.ADD : Blending.NORMAL;
                    quad.depth = z++;
                    quad.texture = texture;
                    quad.frameX = atlasRegion.x / texture.density;
                    quad.frameY = atlasRegion.y / texture.density;
                    if (atlasRegion.rotate) {
                        quad.frameWidth = atlasRegion.height / texture.density;
                        quad.frameHeight = atlasRegion.width / texture.density;
                        quad.rotation = 90;
                        quad.x = quad.frameHeight;
                    } else {
                        quad.frameWidth = atlasRegion.width / texture.density;
                        quad.frameHeight = atlasRegion.height / texture.density;
                        quad.rotation = 0;
                        quad.x = 0;
                    }

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
