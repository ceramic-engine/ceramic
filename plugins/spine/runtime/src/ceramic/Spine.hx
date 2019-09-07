package ceramic;

import spine.utils.SkeletonClipping;
import spine.support.graphics.TextureAtlas;
import spine.AnimationState;
import spine.attachments.*;
import spine.*;

import ceramic.Visual;
import ceramic.Mesh;
import ceramic.MeshColorMapping;
import ceramic.Texture;
import ceramic.Transform;
import ceramic.Color;
import ceramic.AlphaColor;
import ceramic.Blending;
import ceramic.Collection;
import ceramic.CollectionEntry;
import ceramic.Collections;
import ceramic.Shader;
import ceramic.Shaders;
import ceramic.Triangulate;
import ceramic.Shortcuts.*;

using ceramic.SpinePlugin;
using ceramic.Extensions;

using StringTools;

@editable
class Spine extends Visual {

/// Internal

    static var _degRad:Float = Math.PI / 180.0;

    static var _matrix:Transform = new Transform();

    static var _quadTriangles:Array<Int> = [0,1,2,2,3,0];

    static var _trackTimes:Array<Float> = [];

    static var _globalBindDepthRange:Float = 100;

    static var _tintBlackShader:Shader = null;

/// Spine Animation State listener

    var listener:SpineListener;

    var slotMeshes:IntMap<Mesh> = new IntMap(16, 0.5, true); // TODO This could be an array or vector

    var slotInfo:SlotInfo = new SlotInfo();

    var subSpines:Array<Spine> = null;

    var boundParentSlots:IntMap<Array<BindSlot>> = null;

    var boundChildSlots:IntMap<BindSlot> = null;

    var boundChildSlotsDirty:Bool = false;

    var globalBoundParentSlotGlobalIndex:Int = -1;

    var globalBoundParentSlot:Slot = null;

    var globalBoundParentSlotDepth:Float = 0.0;

    var globalBoundParentSlotVisible:Bool = false;

    var setupBoneTransforms:IntMap<Transform> = null;

    var firstBoundingBoxSlotIndex:Int = -1;

    var clipper:SkeletonClipping = new SkeletonClipping();

    var muteEvents:Bool = false;

/// Events

    /** When a spine animation has completed/finished. */
    @event function complete();

    /** When a render begins. */
    @event function beginRender();

    /** When a render ends. */
    @event function endRender();

    /** When a slot is about to be updated. */
    @event function updateSlot(info:SlotInfo);

    /** When a visible slot is about to be updated. */
    @event function updateVisibleSlot(info:SlotInfo);

    /** When the skeleton is going to be updated. */
    @event function updateSkeleton();

    /** When the world transform is going to be updated.
        Hook into this event to set custom bone transforms. */
    @event function updateWorldTransform();

    /** When the current animation chain finishes. If the chain is interrupted
        (by setting another animation), this event is canceled. */
    @event function finishCurrentAnimationChain();

    /** When a next animation is applied and assigned as main animation. */
    @event function applyNextAnimation(animation:String);

    /** When a spine animation event is triggered. */
    @event function spineEvent(entry:TrackEntry, event:Event);

/// Render status

    var renderScheduled:Bool = false;

    // Not sure this is needed, but it may prevent some unnecessary allocation
    function runScheduledRender():Void {
        renderScheduled = false;
        if (renderDirtyBecauseSkinChanged) {
            if (visible || renderWhenInvisible) {
                forceRender();
            }
            else {
                renderDirty = false;
            }
        }
        else if (renderDirty) {
            if (visible || renderWhenInvisible) {
                render(0, 0, false);
            }
            else {
                renderDirty = false;
            }
        }
    }
    var runScheduledRenderDyn:Void->Void = null;

    /** Internal flag to know if render became dirty because of a skin change. */
    var renderDirtyBecauseSkinChanged(default,set):Bool = false;
    inline function set_renderDirtyBecauseSkinChanged(renderDirtyBecauseSkinChanged:Bool):Bool {
        if (renderDirtyBecauseSkinChanged && pausedOrFrozen && !renderScheduled && (visible || renderWhenInvisible)) {
            renderScheduled = true;
            if (runScheduledRenderDyn == null) runScheduledRenderDyn = runScheduledRender;
            app.onceImmediate(runScheduledRenderDyn);
        }
        return (this.renderDirtyBecauseSkinChanged = renderDirtyBecauseSkinChanged);
    }

    public var renderDirty(default,set):Bool = false;
    inline function set_renderDirty(renderDirty:Bool):Bool {
        if (renderDirty && pausedOrFrozen && !renderScheduled && (visible || renderWhenInvisible)) {
            renderScheduled = true;
            if (runScheduledRenderDyn == null) runScheduledRenderDyn = runScheduledRender;
            app.onceImmediate(runScheduledRenderDyn);
        }
        return (this.renderDirty = renderDirty);
    }

/// Properties

    /** Skeleton origin X */
    @editable
    public var skeletonOriginX(default,set):Float = 0.5;
    function set_skeletonOriginX(skeletonOriginX:Float):Float {
        if (this.skeletonOriginX == skeletonOriginX) return skeletonOriginX;
        this.skeletonOriginX = skeletonOriginX;
        renderDirty = true;
        return skeletonOriginX;
    }

    /** Skeleton origin Y */
    @editable
    public var skeletonOriginY(default,set):Float = 0.5;
    function set_skeletonOriginY(skeletonOriginY:Float):Float {
        if (this.skeletonOriginY == skeletonOriginY) return skeletonOriginY;
        this.skeletonOriginY = skeletonOriginY;
        renderDirty = true;
        return skeletonOriginY;
    }

    /** Skeleton scale */
    @editable
    public var skeletonScale(default,set):Float = 1.0;
    function set_skeletonScale(skeletonScale:Float):Float {
        if (this.skeletonScale == skeletonScale) return skeletonScale;
        this.skeletonScale = skeletonScale;
        renderDirty = true;
        return skeletonScale;
    }

    /** Force tint black even if skeleton doesn't need it */
    @editable
    public var forceTintBlack(default,set):Bool = false;
    function set_forceTintBlack(forceTintBlack:Bool):Bool {
        if (this.forceTintBlack == forceTintBlack) return forceTintBlack;
        this.forceTintBlack = forceTintBlack;
        renderDirty = true;
        return forceTintBlack;
    }

    /** Hidden slots (slot blacklist) */
    @editable
    public var hiddenSlots(default,set):IntBoolMap = null;
    function set_hiddenSlots(hiddenSlots:IntBoolMap):IntBoolMap {
        if (this.hiddenSlots == hiddenSlots) return hiddenSlots;
        this.hiddenSlots = hiddenSlots;
        renderDirty = true;
        return hiddenSlots;
    }

    /** Visible slots (slot whitelist) */
    @editable
    public var visibleSlots(default,set):IntBoolMap = null;
    function set_visibleSlots(visibleSlots:IntBoolMap):IntBoolMap {
        if (this.visibleSlots == visibleSlots) return visibleSlots;
        this.visibleSlots = visibleSlots;
        renderDirty = true;
        return visibleSlots;
    }

    /** Disabled slots */
    @editable
    public var disabledSlots(default,set):IntBoolMap = null;
    function set_disabledSlots(disabledSlots:IntBoolMap):IntBoolMap {
        if (this.disabledSlots == disabledSlots) return disabledSlots;
        this.disabledSlots = disabledSlots;
        renderDirty = true;
        return disabledSlots;
    }

    /** Animation triggers */
    @editable
    public var animationTriggers(default,set):Map<String,String> = null;
    function set_animationTriggers(animationTriggers:Map<String,String>):Map<String,String> {
        if (this.animationTriggers == animationTriggers) return animationTriggers;
        this.animationTriggers = animationTriggers;
        renderDirty = true;
        return animationTriggers;
    }

    /** Specify which slot to use to hit this visual or `-1` (default) is not using any. */
    @editable
    public var hitWithSlotIndex(default,set):Int = -1;
    function set_hitWithSlotIndex(hitWithSlotIndex:Int):Int {
        if (this.hitWithSlotIndex == hitWithSlotIndex) return hitWithSlotIndex;
        this.hitWithSlotIndex = hitWithSlotIndex;
        return hitWithSlotIndex;
    }

    /** Use first bounding box to hit this visual.
        When this is set to `true`, `hitWithSlotIndex` value is ignored. */
    @editable
    public var hitWithFirstBoundingBox(default,set):Bool = false;
    function set_hitWithFirstBoundingBox(hitWithFirstBoundingBox:Bool):Bool {
        if (this.hitWithFirstBoundingBox == hitWithFirstBoundingBox) return hitWithFirstBoundingBox;
        this.hitWithFirstBoundingBox = hitWithFirstBoundingBox;
        return hitWithFirstBoundingBox;
    }

    override function set_visible(visible:Bool):Bool {
        if (this.visible == visible) return visible;
        this.visible = visible;
        visibilityDirty = true;
        // When changing from invisible to visible, we should render
        if (visible && !renderWhenInvisible) renderDirty = true;
        return visible;
    }

    @editable
    public var renderWhenInvisible(default,set):Bool = false;
    function set_renderWhenInvisible(renderWhenInvisible:Bool):Bool {
        if (this.renderWhenInvisible == renderWhenInvisible) return renderWhenInvisible;
        this.renderWhenInvisible = renderWhenInvisible;
        if (!visible && renderWhenInvisible) {
            renderDirty = true;
        }
        return renderWhenInvisible;
    }

    /** Is `true` if this spine animation has a parent animation. */
    public var hasParentSpine(default,null):Bool = false;

    /** Tint color */
    @editable
    public var color(default,set):Color = Color.WHITE;
    function set_color(color:Color):Color {
        if (this.color == color) return color;
        this.color = color;
        renderDirty = true;
        return color;
    }

    /** The Spine data used to animate this animation. */
    @editable
    public var spineData(default,set):SpineData = null;
    function set_spineData(spineData:SpineData):SpineData {
        if (this.spineData == spineData) return spineData;

        // Render will be updated from skeleton change anyway
        renderDirtyBecauseSkinChanged = false;
        
        // Save animation info
        var prevSpineData = this.spineData;

        if (prevSpineData != null) {
            if (prevSpineData.asset != null) {
                prevSpineData.asset.release();
            }
        }

        var toResume:Array<Dynamic> = null;
        if (!destroyed && prevSpineData != null && animation == null && state != null) {
            toResume = [];

            var tracks = state.getTracks();

            for (i in 0...tracks.length) {

                var track = tracks[i];

                if (track != null && track.animation != null) {

                    toResume.push([
                        track.animation.name,
                        track.timeScale,
                        track.loop,
                        track.trackTime
                    ]);
                }
            }

        }

        this.spineData = spineData;

        if (this.spineData != null) {
            if (this.spineData.asset != null) {
                this.spineData.asset.retain();
            }
        }

#if editor
        computeAnimationList();
#end

        contentDirty = true;
        computeContent();

        // Restore animation info (if any)
        if (toResume != null && toResume.length > 0) {

            for (i in 0...toResume.length) {

                // TODO remove dynamic access here

                var entry:Dynamic = toResume[i];

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
            }

        }

        // Restore explicit animation name
        if (!destroyed && animation != null && skeletonData != null && skeletonData.findAnimation(animation) != null) {
            animate(animation, loop, 0);
        }

        // Restore explicit skin name
        if (!destroyed && skin != null && skeleton != null) {
            var spineSkin:Skin = skeletonData.findSkin(skin == null ? 'default' : skin);
            if (spineSkin == null) {
                warning('Skin not found: ' + (skin == null ? 'default' : skin) + ' (skeleton: ' + skeletonData.name + ')');
            } else {
                skeleton.setSkin(spineSkin);
            }
        }

        return spineData;
    }

    public var skin(default,set):String = null;
    function set_skin(skin:String):String {
        if (this.skin == skin) return skin;
        this.skin = skin;
        if (skeleton != null) {
            var spineSkin:Skin = skeletonData.findSkin(skin == null ? 'default' : skin);
            if (spineSkin == null) {
                warning('Skin not found: ' + (skin == null ? 'default' : skin) + ' (skeleton: ' + skeletonData.name + ')');
            } else {
                skeleton.setSkin(spineSkin);
            }
        }
        if (animation != null) {
            // If there is an animation running, render needs to be updated
            // more eagerly to use the new skin. Keep that info in a flag.
            renderDirtyBecauseSkinChanged = true;
        }
        return skin;
    }

    var _settingNextAnimation = false;

    @editable({ localCollection: 'animationList', empty: 0 })
    public var animation(default,set):String = null;
    function set_animation(animation:String):String {
        if (!_settingNextAnimation) {
            if (nextAnimations != null) nextAnimations = null;
            offFinishCurrentAnimationChain();
        }
        if (this.animation == animation) return animation;
        this.animation = animation;

        // Render will be updated from animation change anyway
        renderDirtyBecauseSkinChanged = false;

        if (spineData != null) animate(animation, loop, 0);
        return animation;
    }

    public var nextAnimations(default,set):Array<String> = null;
    function set_nextAnimations(nextAnimations:Array<String>) {
        if (this.nextAnimations == nextAnimations) return nextAnimations;
        this.nextAnimations = nextAnimations;
        return nextAnimations;
    }

    @editable
    public var loop(default,set):Bool = true;
    function set_loop(loop:Bool):Bool {
        if (this.loop == loop) return loop;
        this.loop = loop;
        if (spineData != null && animation != null) animate(animation, loop, 0);
        return loop;
    }

    /** The current pose for a skeleton. */
    public var skeleton(default,null):Skeleton;

    /** The setup pose and all of the stateless data for a skeleton. */
    public var skeletonData(default, null):SkeletonData;

    /** Applies animations over time, queues animations for later playback, mixes (crossfading) between animations, and applies. */
    public var state(default, null):AnimationState;

    /** Stores mix (crossfade) durations to be applied when animations are changed. */
    public var stateData(default, null):AnimationStateData;

    public var pausedOrFrozen(default, set):Bool = false;
    function set_pausedOrFrozen(pausedOrFrozen:Bool):Bool {
        if (this.pausedOrFrozen == pausedOrFrozen) return pausedOrFrozen;

        this.pausedOrFrozen = pausedOrFrozen;
        if (pausedOrFrozen) {
            ceramic.App.app.offUpdate(update);
        } else {
            ceramic.App.app.onUpdate(this, update);
        }

        return pausedOrFrozen;
    }

    public var autoFreeze(default,set):Bool = true;
    function set_autoFreeze(autoFreeze:Bool):Bool {
        if (this.autoFreeze == autoFreeze) return autoFreeze;
        this.autoFreeze = autoFreeze;
        if (frozen && !canFreeze()) {
            frozen = false;
        }
        return autoFreeze;
    }

    /** Is this animation paused? */
    public var paused(default,set):Bool = #if editor true #else false #end;
    function set_paused(paused:Bool):Bool {
        if (this.paused == paused) return paused;

        this.paused = paused;
        pausedOrFrozen = paused || frozen;

        return paused;
    }

    /** Is this animation frozen? **/
    public var frozen(default,set):Bool = false;
    function set_frozen(frozen:Bool):Bool {
        if (this.frozen == frozen) return frozen;

        this.frozen = frozen;
        pausedOrFrozen = paused || frozen;

        return frozen;
    }

    /** Reset at change */
    public var resetAtChange:Bool = true;

/// Editor collections

#if editor

    public var animationList:Collection<CollectionEntry> = new Collection();

#end

/// Properties (internal)

    var resetSkeleton:Bool = false;

/// Lifecycle

    public function new() {

        super();

        if (_tintBlackShader == null) _tintBlackShader = ceramic.App.app.assets.shader(Shaders.TINT_BLACK);

        if (!pausedOrFrozen) ceramic.App.app.onUpdate(this, update);

#if editor

        function render(delta:Float) {
            editor.render();
        }

        ceramic.App.app.onceUpdate(this, function(delta) {

            // Do nothing if this is not the object being edited
            if (!edited) return;

            onPointerDown(this, function(info) {

                app.onUpdate(this, render);
                paused = false;

                screen.oncePointerUp(this, function(info) {
                    app.offUpdate(render);
                    paused = true;
                });
            });
        });

#end

    } //new

    inline function clearMeshes():Void {

        var keys = slotMeshes.iterableKeys;
        var foundMeshes = [];
        var foundKeys = [];
        for (i in 0...keys.length) {
            var key = keys.unsafeGet(i);
            var mesh = slotMeshes.getInline(key);
            if (mesh != null) {
                foundKeys.push(key);
                foundMeshes.push(mesh);
                mesh.indices = null;
                mesh.uvs = null;
                if (mesh.transform != null) {
                    TransformPool.recycle(mesh.transform);
                    mesh.transform = null;
                }
                MeshPool.recycle(mesh);
                if (!destroyed) {
                    slotMeshes.set(key, null);
                }
            }
        }

        if (destroyed) {
            slotMeshes = null;
        }

    } //clearMeshes

    override function clear():Void {

        clearMeshes();

        super.clear();

    } //clear

/// Content

    override function computeContent():Void {

        if (destroyed) return;

        if (state != null && listener != null) {
            state.removeListener(listener);
        }

        clearMeshes();

        // Handle empty spine data
        if (spineData == null) {
            skeletonData = null;
            stateData = null;
            state = null;
            skeleton = null;
            listener = null;

            contentDirty = false;
            return;
        }

        // Normal init
        //
        skeletonData = spineData.skeletonData;

        updateSlotIndexMappings();

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
            
            if (!muteEvents) emitComplete();

        };

        listener.onEnd = function(track) {
            
        };

        listener.onEvent = function(track, event) {
            
            if (!muteEvents) emitSpineEvent(track, event);

        };
        
        state.addListener(listener);

        contentDirty = false;

        // Perform setup render to gather required information
        resetSkeleton = true;
        updateSkeleton(0);
        render(0, 0, true);

        renderDirty = true;

    } //computeContent

    inline function willEmitComplete() {

        // Chain with the next animations, if any
        if (nextAnimations != null && nextAnimations.length > 0) {
            _settingNextAnimation = true;
            animation = nextAnimations.shift();
            emitApplyNextAnimation(animation);
            _settingNextAnimation = false;
        }
        else {
            emitFinishCurrentAnimationChain();
            if (canFreeze()) {
                frozen = true;
            }
        }

    } //willEmitComplete

/// Size

    override function set_width(width:Float):Float {
        if (_width == width) return width;
        super.set_width(width);
        renderDirty = true;
        return width;
    }

    override function set_height(height:Float):Float {
        if (_height == height) return height;
        super.set_height(height);
        renderDirty = true;
        return height;
    }
    
    override function computeBounds():Void {
        super.computeBounds();
        skeletonOriginX = anchorX;
        skeletonOriginY = anchorY;
    }

/// Public API

    /** Start running an animation available in the skeleton. **/
    public function animate(animationName:String, loop:Bool = false, trackIndex:Int = 0, trackTime:Float = -1):Void {
        if (destroyed) return;

        var track;

        if (animationName == null) {
            track = state.setEmptyAnimation(trackIndex, 0);
        } else {
            var _animation = skeletonData.findAnimation(animationName);
            if (_animation != null) {
                track = state.setAnimation(trackIndex, _animation, loop);
                if (trackTime >= 0) {
                    track.trackTime = trackTime;
                }
            } else {
                warning('Animation not found: ' + animationName + ' (skeleton: ' + skeletonData.name + ')');
                track = state.setEmptyAnimation(trackIndex, 0);
            }
        }

        if (autoFreeze) {
            if (canFreeze()) {
                frozen = true;
                app.onceImmediate(function() {
                    if (!muteEvents) emitComplete();
                });
            } else {
                frozen = false;
            }
        } else {
            frozen = false;
        }

        // Ensure animation gets rendered once to prevent 1-frame glitches
        forceRender();

    } //animate

    public function forceRender():Void {

        if (state == null) return;

        // Forced rendering will update skin display anyway
        renderDirtyBecauseSkinChanged = false;

        var prevPaused = paused;
        var prevFrozen = frozen;
        var prevMuteEvents = muteEvents;
        paused = false;
        frozen = false;
        muteEvents = true;

        /*var tracks = state.tracks;
        for (i in 0...tracks.length) {
            var aTrack = tracks[i];
            if (aTrack == null) break;
            _trackTimes[i] = aTrack.trackTime;
        }
        
        var i = tracks.length;
        update(0.1);
        while (i-- > 0) {
            var track = tracks[i];
            if (track != null) {
                track.trackTime = _trackTimes[i];
            }
        }*/

        // This ensure every track will be updated
        var tracks = state.tracks;
        for (i in 0...tracks.length) {
            var aTrack = tracks[i];
            if (aTrack == null) continue;
            aTrack.delay = 0;
        }
        
        updateSkeleton(0);
        render(0, 0, false);

        paused = prevPaused;
        frozen = prevFrozen;
        muteEvents = prevMuteEvents;

    } //forceRender

    /** Reset the animation (set to setup pose). */
    public function reset():Void {
        if (destroyed) return;

        resetSkeleton = true;

    } //reset

/// Cleanup

    override function destroy() {

        super.destroy();

        // Will update reference counting
        spineData = null;

        if (state != null && listener != null) {
            state.removeListener(listener);
        }
        
        if (updateSlotWithNameDispatchersAsList != null) {
            for (i in 0...updateSlotWithNameDispatchersAsList.length) {
                var dispatch = updateSlotWithNameDispatchersAsList.unsafeGet(i);
                dispatch.destroy();
            }
            updateSlotWithNameDispatchers = null;
            updateSlotWithNameDispatchersAsList = null;
        }
        
        if (updateVisibleSlotWithNameDispatchersAsList != null) {
            for (i in 0...updateVisibleSlotWithNameDispatchersAsList.length) {
                var dispatch = updateVisibleSlotWithNameDispatchersAsList.unsafeGet(i);
                dispatch.destroy();
            }
            updateVisibleSlotWithNameDispatchers = null;
            updateVisibleSlotWithNameDispatchersAsList = null;
        }
        
        skeletonData = null;
        stateData = null;
        state = null;
        skeleton = null;
        listener = null;

    } //destroy

    public function update(delta:Float):Void {

        if (hasParentSpine) {
            // Our parent is a spine animation and is responsible
            // of updating our own data and rendering it.
            return;
        }

        // No spine data? Then nothing to animate
        if (spineData == null) return;

        // Update skeleton
        updateSkeleton(delta);

        if (visible || renderWhenInvisible) {
            // We are visible and are root spine animation, let's render
            render(delta, 0, false);
        }

    } //update

    /** Returns `true` if the current instance doesn't move
        and doesn't need to get updated at every frame. */
    inline public function canFreeze():Bool {

        if (!autoFreeze) return false;

        var result = true;

        if (state != null) {
            var tracks = state.tracks;
            for (i in 0...tracks.length) {
                var track = tracks[i];
                if (track != null && track.animation != null && track.animation.duration > 0) {
                    if (track.loop || track.trackTime < track.animation.duration) {
                        result = false;
                        break;
                    }
                }
            }
        }
        else {
            result = false;
        }

        return result;

    } //canFreeze

/// Internal

    /** Update skeleton with the given delta time. */
    function updateSkeleton(delta:Float):Void {

        if (contentDirty) {
            computeContent();
        }

        if (destroyed) {
            return;
        }

        emitUpdateSkeleton();

        if (resetSkeleton) {
            resetSkeleton = false;
            if (skeleton != null) skeleton.setToSetupPose();
        }

        if (skeleton != null) {

            skeleton.update(delta);

            if (state != null) {
                state.update(delta);
                state.apply(skeleton);
            }

            // Could be destroyed by bound events
            // triggered when updating state
            if (destroyed) return;

            emitUpdateWorldTransform();

            skeleton.updateWorldTransform();
        }

    } //updateSkeleton

    /** Process spine draw order and output quads and meshes. */
    function render(delta:Float, z:Float, setup:Bool) {

        if (skeleton == null) return;

        if (boundChildSlotsDirty) {
            computeBoundChildSlots();
        }

        var drawOrder:Array<Slot> = skeleton.drawOrder;
        var numElements:Int = drawOrder.length;

        var r:Float;
        var g:Float;
        var b:Float;
        var a:Float;
        var n:Int;
        var k:Int;
        var len:Int;
        var tx:Float;
        var ty:Float;
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
        var slot:Slot;
        var meshAttachment:MeshAttachment;
        var mesh:Mesh;
        var boundingBoxAttachment:BoundingBoxAttachment;
        var verticesLength:Int;
        var clipAttachment:ClippingAttachment = null;
        var colors:Array<AlphaColor>;
        var alphaColor:AlphaColor;
        var emptySlotMesh:Bool = false;
        var slotName:String = null;
        var slotGlobalIndex:Int = -1;
        var boundSlot:BindSlot = null;
        var microDepth:Float = 0.0001;
        var boneData:BoneData = null;
        var setupRotation:Float = 0;
        var boneSetupTransform:Transform = null;
        var regularRender:Bool = !setup;
        var didFlipX:Bool = false;
        var didFlipY:Bool = false;
        var vertexSize:Int = 0;
        var count:Int = 0;
        var tintBlack:Bool = false;
        var vertices:Array<Float>;
        var firstBoundingBoxSlotIndex = -1;

        var diffX:Float = width * skeletonOriginX;
        var diffY:Float = height * skeletonOriginY;

        if (regularRender) {
            emitBeginRender();
        }

        if (setup && setupBoneTransforms == null) {
            setupBoneTransforms = new IntMap();
        }

        // Set flip
        #if spine_36
        flipX = skeleton.flipX ? -1 : 1;
        flipY = skeleton.flipY ? -1 : 1;
        #else
        flipX = skeleton.scaleX < 0 ? -1 : 1;
        flipY = skeleton.scaleY < 0 ? -1 : 1;
        #end
        flip = flipX * flipY;

        for (i in 0...numElements)
        {
            slot = drawOrder[i];
            bone = slot.bone;
            slotName = slot.data.name;
            slotGlobalIndex = globalSlotIndexFromSkeletonSlotIndex.unsafeGet(slot.data.index);

            if (disabledSlots != null && disabledSlots.getInline(slotGlobalIndex)) {
                continue;
            }

            boundSlot = null;
            tintBlack = slot.data.darkColor != null || forceTintBlack;
            // /!\ TODO clipping
            vertexSize = clipper != null && clipper.isClipping() ? 5 : 2;
            if (tintBlack) vertexSize += 4;

            // Emit event and allow to override drawing of this slot
            slotInfo.customTransform = null;
            slotInfo.depth = z;
            slotInfo.globalSlotIndex = slotGlobalIndex;
            slotInfo.drawDefault = (hiddenSlots == null || !hiddenSlots.getInline(slotGlobalIndex)) && (visibleSlots == null || visibleSlots.getInline(slotGlobalIndex));
            slotInfo.slot = slot;

            offsetX = 0;
            offsetY = 0;

            emptySlotMesh = true;
            if (slot.attachment != null)
            {
                if (boundChildSlots != null) {
                    boundSlot = boundChildSlots.getInline(slotGlobalIndex);
                } else {
                    boundSlot = null;
                }

                regionAttachment = Std.is(slot.attachment, RegionAttachment) ? cast slot.attachment : null;
                meshAttachment = Std.is(slot.attachment, MeshAttachment) ? cast slot.attachment : null;
                boundingBoxAttachment = regionAttachment == null && meshAttachment == null && Std.is(slot.attachment, BoundingBoxAttachment) ? cast slot.attachment : null;
                if (regionAttachment != null || meshAttachment != null || boundingBoxAttachment != null) {

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

                    if (setup && setupBoneTransforms.getInline(bone.data.index) == null) {
                        boneSetupTransform = TransformPool.get();
                        boneSetupTransform.setToTransform(slotInfo.transform);
                        setupBoneTransforms.set(bone.data.index, boneSetupTransform);
                    }

                    if (regularRender) {
                        
                        emitUpdateSlot(slotInfo);
                        if (slotInfo.drawDefault) {
                            emitUpdateVisibleSlot(slotInfo);
                        }

                        mesh = slotMeshes.getInline(slot.data.index);

                        if (boundSlot == null || boundSlot.parentVisible) {

                            emptySlotMesh = false;
                            
                            if (boundingBoxAttachment != null) {
                                if (firstBoundingBoxSlotIndex == -1) {
                                    firstBoundingBoxSlotIndex = slot.data.index;
                                }
                                atlasRegion = null;
                                texture = null;
                            }
                            else {
                                atlasRegion = cast (meshAttachment != null ? meshAttachment.getRegion() : regionAttachment.getRegion());
                                texture = cast atlasRegion.page.rendererObject;
                            }

                            if (mesh == null)
                            {
                                mesh = MeshPool.get();

                                // Indices and UVs arrays are created by spine runtime,
                                // no need to use default ones.
                                MeshPool.recycleIntArray(mesh.indices);
                                MeshPool.recycleFloatArray(mesh.uvs);

                                mesh.indices = null;
                                mesh.uvs = null;
                                mesh.touchable = false;
                                mesh.transform = new Transform();
                                add(mesh);
                                slotMeshes.set(slot.data.index, mesh);
                            }
                            
                            mesh.texture = texture;

                            if (boundingBoxAttachment != null) {
                                count = boundingBoxAttachment.getWorldVerticesLength();
                                verticesLength = count;
                            }
                            else if (meshAttachment != null) {
                                count = meshAttachment.getWorldVerticesLength();
                                verticesLength = (count >> 1) * vertexSize;
                            } else {
                                count = 4;
                                verticesLength = vertexSize << 2;
                            }
                            
                            if (verticesLength == 0) {
                                mesh.visible = false;
                            }
                            else if (boundingBoxAttachment != null) {
                                #if ceramic_debug_spine_bounding_boxes
                                mesh.visible = true;
                                #else
                                mesh.visible = false;
                                #end
                                mesh.depth = 999;
                                mesh.colorMapping = MeshColorMapping.MESH;
                                mesh.color = Color.LIME;
                                mesh.alpha = 0.7;
                                mesh.shader = null;
                                boundingBoxAttachment.computeWorldVertices(slot, 0, count, mesh.vertices, 0, 2);
                                Triangulate.triangulate(mesh.vertices, mesh.indices);

                                if (mesh.vertices.length > verticesLength) {
                                    #if cpp
                                    untyped mesh.vertices.__SetSize(verticesLength);
                                    #else
                                    mesh.vertices.splice(verticesLength, mesh.vertices.length - verticesLength);
                                    #end
                                }
                            }
                            else {
                                if (slotInfo.drawDefault) {
                                    mesh.visible = true;
                                    mesh.shader = tintBlack ? _tintBlackShader : null;
                                    mesh.colorMapping = MeshColorMapping.MESH;
                                    if (meshAttachment != null) {

                                        meshAttachment.computeWorldVertices(slot, 0, count, mesh.vertices, 0, vertexSize);
                                        mesh.uvs = meshAttachment.getUVs();
                                        mesh.indices = meshAttachment.getTriangles();

                                        if (tintBlack) {
                                            a = skeleton.color.a * slot.color.a * meshAttachment.getColor().a * alpha;
                                            if (slot.darkColor != null) {
                                                r = skeleton.color.r * slot.darkColor.r * meshAttachment.getColor().r * a;
                                                g = skeleton.color.g * slot.darkColor.g * meshAttachment.getColor().g * a;
                                                b = skeleton.color.b * slot.darkColor.b * meshAttachment.getColor().b * a;
                                                a = slot.darkColor.a;
                                            }
                                            else {
                                                r = 0;
                                                g = 0;
                                                b = 0;
                                                a = 1;
                                            }

                                            if (color != Color.WHITE) {
                                                r *= color.redFloat;
                                                g *= color.greenFloat;
                                                b *= color.blueFloat;
                                            }

                                            n = 0;
                                            vertices = mesh.vertices;
                                            len = vertices.length;
                                            while (n < len) {
                                                k = n + vertexSize - 1;
                                                vertices[k] = a;
                                                k -= 3;
                                                vertices.unsafeSet(k, r);
                                                k++;
                                                vertices.unsafeSet(k, g);
                                                k++;
                                                vertices.unsafeSet(k, b);
                                                n += vertexSize;
                                            }
                                        }

                                        r = skeleton.color.r * slot.color.r * meshAttachment.getColor().r;
                                        g = skeleton.color.g * slot.color.g * meshAttachment.getColor().g;
                                        b = skeleton.color.b * slot.color.b * meshAttachment.getColor().b;
                                        a = skeleton.color.a * slot.color.a * meshAttachment.getColor().a * alpha;

                                        if (color != Color.WHITE) {
                                            r *= color.redFloat;
                                            g *= color.greenFloat;
                                            b *= color.blueFloat;
                                        }

                                        if (mesh.vertices.length > verticesLength) {
                                            #if cpp
                                            untyped mesh.vertices.__SetSize(verticesLength);
                                            #else
                                            mesh.vertices.splice(verticesLength, mesh.vertices.length - verticesLength);
                                            #end
                                        }

                                    } else {
                                        var tmpVertices = [];
                                        regionAttachment.computeWorldVertices(slot.bone, mesh.vertices, 0, vertexSize);
                                        mesh.uvs = regionAttachment.getUVs();
                                        mesh.indices = _quadTriangles;

                                        if (tintBlack) {
                                            a = skeleton.color.a * slot.color.a * regionAttachment.getColor().a * alpha;
                                            if (slot.darkColor != null) {
                                                r = skeleton.color.r * slot.darkColor.r * regionAttachment.getColor().r * a;
                                                g = skeleton.color.g * slot.darkColor.g * regionAttachment.getColor().g * a;
                                                b = skeleton.color.b * slot.darkColor.b * regionAttachment.getColor().b * a;
                                                a = slot.darkColor.a;
                                            }
                                            else {
                                                r = 0;
                                                g = 0;
                                                b = 0;
                                                a = 1;
                                            }

                                            if (color != Color.WHITE) {
                                                r *= color.redFloat;
                                                g *= color.greenFloat;
                                                b *= color.blueFloat;
                                            }

                                            n = 0;
                                            vertices = mesh.vertices;
                                            len = vertices.length;
                                            while (n < len) {
                                                k = n + vertexSize - 1;
                                                vertices[k] = a;
                                                k -= 3;
                                                mesh.vertices.unsafeSet(k, r);
                                                k++;
                                                mesh.vertices.unsafeSet(k, g);
                                                k++;
                                                mesh.vertices.unsafeSet(k, b);
                                                n += vertexSize;
                                            }
                                        }

                                        r = skeleton.color.r * slot.color.r * regionAttachment.getColor().r;
                                        g = skeleton.color.g * slot.color.g * regionAttachment.getColor().g;
                                        b = skeleton.color.b * slot.color.b * regionAttachment.getColor().b;
                                        a = skeleton.color.a * slot.color.a * regionAttachment.getColor().a * alpha;

                                        if (color != Color.WHITE) {
                                            r *= color.redFloat;
                                            g *= color.greenFloat;
                                            b *= color.blueFloat;
                                        }

                                    }

                                    isAdditive = slot.data.blendMode == BlendMode.additive;

                                    alphaColor = new AlphaColor(Color.fromRGBFloat(r, g, b), Math.round(a * 255));
                                    if (mesh.colors == null) mesh.colors = [alphaColor];
                                    else mesh.colors[0] = alphaColor;

                                    if (clipper.isClipping()) {
                                        clipper.clipTriangles(mesh.vertices, verticesLength, mesh.indices, mesh.indices.length, mesh.uvs, alphaColor, 0, false);
                                        var clippedVertices = clipper.getClippedVertices();
                                        var clippedTriangles = clipper.getClippedTriangles();
                                        var verticeItems = clippedVertices.items;

                                        for (i in 0...verticeItems.length) {
                                            mesh.vertices[i] = verticeItems.unsafeGet(i);
                                        }
                                        if (mesh.vertices.length > verticeItems.length) {
                                            #if cpp
                                            untyped mesh.vertices.__SetSize(verticeItems.length);
                                            #else
                                            mesh.vertices.splice(verticeItems.length, mesh.vertices.length - verticeItems.length);
                                            #end
                                        }

                                        mesh.indices = clippedTriangles.items;
                                    }

                                    mesh.blending = isAdditive ? Blending.ADD : Blending.NORMAL;
                                    mesh.depth = slotInfo.depth;
                                    mesh.scaleY = -1;

                                }
                                else {
                                    mesh.visible = false;
                                }
                            }

                            if (boundSlot != null) {

                                setupRotation = 0.0;
                                boneData = bone.getData();
                                while (boneData != null) {
                                    setupRotation += boneData.getRotation();
                                    boneData = boneData.getParent();
                                }

                                mesh.transform.identity();

                                boneSetupTransform = setupBoneTransforms.getInline(bone.data.index);
                                if (boneSetupTransform != null) {
                                    mesh.transform.translate(
                                        -boneSetupTransform.tx,
                                        -boneSetupTransform.ty
                                    );
                                } else {
                                    mesh.transform.translate(
                                        -slotInfo.transform.tx,
                                        -slotInfo.transform.ty
                                    );
                                }

                                mesh.transform.scale(
                                    bone.scaleX < 0 ? -1 : 1,
                                    bone.scaleY < 0 ? -1 : 1
                                );
                                if (bone.scaleY < 0 && boundSlot.parentSlot.bone.scaleY < 0) {
                                    mesh.transform.scale(
                                        -1,
                                        -1
                                    );
                                }

                                mesh.transform.rotate(Math.round(setupRotation / 90.0) * 90.0 * _degRad);

                                didFlipX = false;
                                didFlipY = false;
                                if (boundSlot.flipXOnConcat) {
                                    didFlipX = true;
                                    mesh.transform.scale(-1, 1);
                                    boundSlot.parentTransform.scale(-1, 1);
                                }
                                if (boundSlot.flipYOnConcat) {
                                    didFlipY = true;
                                    mesh.transform.scale(1, -1);
                                    boundSlot.parentTransform.scale(1, -1);
                                }
                                mesh.transform.concat(boundSlot.parentTransform);
                                if (didFlipX) {
                                    mesh.transform.scale(-1, 1);
                                    boundSlot.parentTransform.scale(-1, 1);
                                }
                                if (didFlipY) {
                                    mesh.transform.scale(1, -1);
                                    boundSlot.parentTransform.scale(1, -1);
                                }

                                if (slotInfo.customTransform != null) {
                                    mesh.transform.concat(slotInfo.customTransform);
                                }

                                slotInfo.transform.concat(mesh.transform);

                                mesh.depth = boundSlot.parentDepth + microDepth + slotInfo.depth - z;
                                slotInfo.depth = mesh.depth;
                                microDepth += 0.0001;
                            }
                            else {
                                if (slotInfo.customTransform != null) {
                                    mesh.transform.setToTransform(slotInfo.customTransform);
                                }
                                else {
                                    mesh.transform.identity();
                                }
                            }

                            if (boundingBoxAttachment != null) {
                                // Not sure why this is needed, but that makes it work
                                mesh.transform.scale(1, -1);
                            }

                            if (skeletonScale != 1.0) mesh.transform.scale(skeletonScale, skeletonScale);
                            mesh.transform.translate(diffX, diffY);
                        }
                        else {
                            if (mesh != null) {
                                // If the mesh was visible before during the animation,
                                // Let's not destroy it and just make it not visible.
                                mesh.visible = false;
                            }
                        }
                    }
                }
                else if (Std.is(slot.attachment, ClippingAttachment)) {

                    clipAttachment = cast slot.attachment;
                    clipper.clipStart(slot, clipAttachment);
                    continue;

                }

                z++;
            }

            if (regularRender) {
                if (emptySlotMesh) {
                    mesh = slotMeshes.getInline(slot.data.index);
                    if (mesh != null) {
                        mesh.visible = false;
                    }
                }

                // Gather information for child animations if needed
                if (subSpines != null) {
                    for (s in 0...subSpines.length) {
                        var sub = subSpines.unsafeGet(s);

                        // Skip invisible sub spines by default
                        if (sub.visible || sub.renderWhenInvisible) {

                            // Parent slot to child slot
                            if (sub.boundParentSlots != null && sub.boundParentSlots.getInline(slotGlobalIndex) != null) {
                                var bindList = sub.boundParentSlots.getInline(slotGlobalIndex);
                                for (bi in 0...bindList.length) {
                                    var bindInfo = bindList.unsafeGet(bi);
                                    
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
                                        bindInfo.parentSlot = slotInfo.slot;
                                    }

                                }
                            }

                            // Parent slot to every children
                            if (sub.globalBoundParentSlotGlobalIndex == slotGlobalIndex) {

                                // Keep parent info
                                if (slot.attachment == null) {
                                    sub.globalBoundParentSlotVisible = false;
                                }
                                else {

                                    sub.globalBoundParentSlotVisible = true;
                                    sub.globalBoundParentSlotDepth = slotInfo.depth;
                                    sub.globalBoundParentSlot = slotInfo.slot;
                                    sub.transform.setTo(
                                        slotInfo.transform.a,
                                        slotInfo.transform.b,
                                        slotInfo.transform.c,
                                        slotInfo.transform.d,
                                        slotInfo.transform.tx,
                                        slotInfo.transform.ty
                                    );
                                    sub.depth = z;
                                    sub.depthRange = _globalBindDepthRange;

                                }

                                // Increase z to give more precise depth 'space' in sub animation
                                z += _globalBindDepthRange;

                            }
                        }
                    }
                }
            }

            clipper.clipEndWithSlot(slot);

        }
        clipper.clipEnd();

        this.firstBoundingBoxSlotIndex = firstBoundingBoxSlotIndex;

        if (regularRender) {
            emitEndRender();
        }

        renderDirty = false;

        // Render children (if any)
        if (!setup && subSpines != null) {
            for (s in 0...subSpines.length) {
                var sub = subSpines.unsafeGet(s);
                
                // Skip rendering of sub spines if they are not visible, by default
                if (sub.visible || sub.renderWhenInvisible) {
                    sub.updateSkeleton(delta);
                    sub.render(delta, z, false);
                }
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
            var item:Spine = cast visual;
            item.hasParentSpine = true;
            subSpines.push(item);
        }

    } //add

    override public function remove(visual:Visual):Void {

        // Default behavior
        super.remove(visual);

        // Spine case
        if (Std.is(visual, Spine)) {
            var item:Spine = cast visual;
            item.hasParentSpine = false;
            subSpines.remove(item);
        }

    } //add

    var globalSlotIndexFromSkeletonSlotIndex:Array<Int> = [];

    var updateSlotWithNameDispatchers:IntMap<DispatchSlotInfo> = null;

    var updateSlotWithNameDispatchersAsList:Array<DispatchSlotInfo> = null;

    var updateVisibleSlotWithNameDispatchers:IntMap<DispatchSlotInfo> = null;

    var updateVisibleSlotWithNameDispatchersAsList:Array<DispatchSlotInfo> = null;

    inline function updateSlotIndexMappings():Void {

        var skeletonSlots = skeletonData.slots;
        for (i in 0...skeletonSlots.length) {
            var slot = skeletonSlots.unsafeGet(i);
            var slotName = slot.name;
            var slotIndex = slot.index;
            
            var globalIndex = globalSlotIndexForName(slotName);
            globalSlotIndexFromSkeletonSlotIndex[slotIndex] = globalIndex;
        }

    } //updateSlotIndexMappings

    /** A more optimal way of listening to updated slots.
        With this method, we are targeting a specific slot by its name (global index internally).
        This allows the spine object to skip calls to the handler for every other slots we don't care about. */
    inline public function onUpdateSlotWithName(?owner:Entity, slotName:String, handleInfo:SlotInfo->Void):Void {

        onUpdateSlotWithGlobalIndex(owner, globalSlotIndexForName(slotName), handleInfo);

    } //onUpdateSlotWithName

    /** A more optimal way of listening to updated slots.
        With this method, we are targeting a specific slot by its global index.
        This allows the spine object to skip calls to the handler for every other slots we don't care about. */
    public function onUpdateSlotWithGlobalIndex(?owner:Entity, index:Int, handleInfo:SlotInfo->Void):Void {

        // Create update slot binding map if needed
        if (updateSlotWithNameDispatchers == null) {
            updateSlotWithNameDispatchers = new IntMap();
            updateSlotWithNameDispatchersAsList = [];
        }

        // Get or create dispatcher for this index
        var dispatch = updateSlotWithNameDispatchers.getInline(index);
        if (dispatch == null) {
            dispatch = new DispatchSlotInfo();
            updateSlotWithNameDispatchers.set(index, dispatch);
            updateSlotWithNameDispatchersAsList.push(dispatch);
        }

        // Bind handler
        dispatch.onDispatch(owner, handleInfo);

    } //onUpdateSlotWithGlobalIndex

    inline public function offUpdateSlotWithName(slotName:String, ?handleInfo:SlotInfo->Void):Void {

        offUpdateSlotWithGlobalIndex(globalSlotIndexForName(slotName), handleInfo);

    } //offUpdateSlotWithName

    public function offUpdateSlotWithGlobalIndex(index:Int, ?handleInfo:SlotInfo->Void):Void {

        // No binding map? Nothing to unbind
        if (updateSlotWithNameDispatchers == null) {
            return;
        }

        // Get dispatcher for this index
        var dispatch = updateSlotWithNameDispatchers.get(index);
        if (dispatch == null) {
            // No dispatcher, nothing to unbind
            return;
        }

        // Unbind handler (or every handler if handleInfo is null)
        dispatch.offDispatch(handleInfo);

    } //offUpdateSlotWithGlobalIndex

    /** Same as `onUpdateSlotWithName`, but fired only for visible slots (`drawDefault=true`) */
    inline public function onUpdateVisibleSlotWithName(?owner:Entity, slotName:String, handleInfo:SlotInfo->Void):Void {

        onUpdateVisibleSlotWithGlobalIndex(owner, globalSlotIndexForName(slotName), handleInfo);

    } //onUpdateVisibleSlotWithName

    /** Same as `onUpdateSlotWithGlobalIndex`, but fired only for visible slots (`drawDefault=true`) */
    public function onUpdateVisibleSlotWithGlobalIndex(?owner:Entity, index:Int, handleInfo:SlotInfo->Void):Void {

        // Create update slot binding map if needed
        if (updateVisibleSlotWithNameDispatchers == null) {
            updateVisibleSlotWithNameDispatchers = new IntMap();
            updateVisibleSlotWithNameDispatchersAsList = [];
        }

        // Get or create dispatcher for this index
        var dispatch = updateVisibleSlotWithNameDispatchers.get(index);
        if (dispatch == null) {
            dispatch = new DispatchSlotInfo();
            updateVisibleSlotWithNameDispatchers.set(index, dispatch);
            updateVisibleSlotWithNameDispatchersAsList.push(dispatch);
        }

        // Bind handler
        dispatch.onDispatch(owner, handleInfo);

    } //onUpdateVisibleSlotWithGlobalIndex

    inline public function offUpdateVisibleSlotWithName(slotName:String, ?handleInfo:SlotInfo->Void):Void {

        offUpdateVisibleSlotWithGlobalIndex(globalSlotIndexForName(slotName), handleInfo);

    } //offUpdateVisibleSlotWithName

    public function offUpdateVisibleSlotWithGlobalIndex(index:Int, ?handleInfo:SlotInfo->Void):Void {

        // No binding map? Nothing to unbind
        if (updateVisibleSlotWithNameDispatchers == null) {
            return;
        }

        // Get dispatcher for this index
        var dispatch = updateVisibleSlotWithNameDispatchers.get(index);
        if (dispatch == null) {
            // No dispatcher, nothing to unbind
            return;
        }

        // Unbind handler (or every handler if handleInfo is null)
        dispatch.offDispatch(handleInfo);

    } //offUpdateVisibleSlotWithGlobalIndex

    inline function willEmitUpdateSlot(info:SlotInfo):Void {

        // Dispatch to handlers specifically listening to this slot index
        if (updateSlotWithNameDispatchers != null) {
            var index:Int = globalSlotIndexFromSkeletonSlotIndex[info.slot.data.index];
            if (index > 0) {
                var dispatch = updateSlotWithNameDispatchers.getInline(index);
                if (dispatch != null) {
                    dispatch.emitDispatch(info);
                }
            }
        }

    } //willEmitUpdateSlot

    inline function willEmitUpdateVisibleSlot(info:SlotInfo):Void {

        // Dispatch to handlers specifically listening to this slot index
        if (updateVisibleSlotWithNameDispatchers != null) {
            var index:Int = globalSlotIndexFromSkeletonSlotIndex[info.slot.data.index];
            if (index > 0) {
                var dispatch = updateVisibleSlotWithNameDispatchers.getInline(index);
                if (dispatch != null) {
                    dispatch.emitDispatch(info);
                }
            }
        }

    } //willEmitUpdateVisibleSlot

    /** Bind a slot of parent animation to one of our local slots or bones. */
    public function bindParentSlot(parentSlot:String, ?options:BindSlotOptions) {

        var parentSlotGlobalIndex = globalSlotIndexForName(parentSlot);
        
        if (options != null) {

            var info = new BindSlot();
            info.fromParentSlot = parentSlotGlobalIndex;

            // Bind parent slot to child slot
            //
            if (options.toLocalSlot != null) {
                info.toLocalSlot = globalSlotIndexForName(options.toLocalSlot);
                boundChildSlotsDirty = true;
            }

            if (options.flipXOnConcat != null) info.flipXOnConcat = options.flipXOnConcat;
            if (options.flipYOnConcat != null) info.flipYOnConcat = options.flipYOnConcat;

            if (boundParentSlots == null) boundParentSlots = new IntMap();
            var bindList = boundParentSlots.get(parentSlotGlobalIndex);
            if (bindList == null) {
                bindList = [];
                boundParentSlots.set(parentSlotGlobalIndex, bindList);
            }

            bindList.push(info);
        }
        else {

            // Bind parent slot to every children
            //
            globalBoundParentSlotGlobalIndex = parentSlotGlobalIndex;
            if (transform == null) transform = new Transform();

        }

    } //bindParentSlot

    /** Compute `boundChildSlots` from `boundParentSlots` to make it more efficient
        to gather parent slot transformations when drawing child animation. */
    function computeBoundChildSlots() {

        boundChildSlots = new IntMap();

        var values = boundParentSlots.values;
        for (i in 0...values.length) {
            var bindList = values.get(i);
            if (bindList != null) {
                for (b in 0...bindList.length) {
                    var bindItem = bindList.unsafeGet(b);
                    if (bindItem.toLocalSlot > 0 && boundChildSlots.get(bindItem.toLocalSlot) == null) {
                        boundChildSlots.set(bindItem.toLocalSlot, bindItem);
                    }
                }
            }
        }

        boundChildSlotsDirty = false;

    } //computeBoundChildSlots

/// Helpers

    /** Encodes the ABGR int color as a float. The high bits are masked to avoid using floats in the NaN range, which unfortunately
	 * means the full range of alpha cannot be used. */
    inline static function intToFloatColor(value:Int):Float {

        return 1.0 * (value & 0xFEFFFFFF);

    } //intToFloatColor

/// Hit test

    override function hits(x:Float, y:Float):Bool {

        if (hitWithFirstBoundingBox) {
            if (firstBoundingBoxSlotIndex != -1) {
                var mesh = slotMeshes.getInline(firstBoundingBoxSlotIndex);
                if (mesh != null) {
                    mesh.complexHit = true;
                    return mesh.hits(x, y);
                }
                else {
                    return false;
                }
            }
            else {
                return false;
            }
        }
        else if (hitWithSlotIndex != -1) {
            var mesh = slotMeshes.getInline(hitWithSlotIndex);
            if (mesh != null) {
                mesh.complexHit = true;
                return mesh.hits(x, y);
            }
            else {
                return false;
            }
        }
        else {
            return super.hits(x, y);
        }
    }

/// Editor stuff

#if editor

    function computeAnimationList():Void {

        // If not edited, nothing to do
        if (!edited) return;

        // Clear previous
        animationList.splice(0, animationList.length);

        // Create initial list
        var collectionData = [{
            id: null,
            name: 'none'
        }];

        // Fill list
        if (spineData != null) {

            // Compute content
            var anims = spineData.skeletonData.animations;
            for (a in 0...anims.length) {
                var animation = anims[a];
                animationList.push({
                    id: animation.name,
                    name: animation.name
                });
            }

            // Send to editor
            for (e in 0...animationList.length) {
                var entry = animationList[e];
                collectionData.push(entry.getEditableData());
            }
        }

        // Send
        editor.send({
            type: 'collections/local',
            value: {
                owner: id,
                name: 'animationList',
                data: collectionData
            }
        });

    } //computeAnimationList

#end

    static var _globalSlotIndexes:Map<String,Int> = new Map();
    static var _nextGlobalSlotIndex:Int = 1;

    /** Retrieve a slot index that works with any skeleton.
        In other words, for a given slot name, its global index will always be identical
        regardless of which skeleton is used. This is not the case with regular slot
        indexes that depend on their skeleton structure.
        A global slot index is a prefered solution over strings to identify a slot. */
    inline static public function globalSlotIndexForName(slotName:String):Int {

        // Retrieve global slot index (an index that works with any skeleton)
        if (!_globalSlotIndexes.exists(slotName)) {
            _globalSlotIndexes.set(slotName, _nextGlobalSlotIndex++);
        }
        return _globalSlotIndexes.get(slotName);

    } //globalSlotIndexForName

} //Spine

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

    @:optional var toLocalSlot:String;

    @:optional var flipXOnConcat:Bool;

    @:optional var flipYOnConcat:Bool;

} //BindSlotOptions

@:allow(ceramic.Spine)
private class BindSlot {

    public var fromParentSlot:Int = -1;

    public var toLocalSlot:Int = -1;

    public var parentDepth:Float = 0;

    public var parentVisible:Bool = false;

    public var parentTransform:Transform = new Transform();

    public var parentSlot:Slot = null;

    public var flipXOnConcat:Bool = false;

    public var flipYOnConcat:Bool = false;

    public function new() {}

    function toString() {
        var props:Dynamic = {};
        props.fromParentSlot = fromParentSlot;
        props.toLocalSlot = toLocalSlot;
        props.parentDepth = parentDepth;
        if (parentTransform != null) props.parentTransform = parentTransform;
        if (parentVisible) props.parentVisible = parentVisible;
        if (flipXOnConcat) props.flipXOnConcat = flipXOnConcat;
        if (flipYOnConcat) props.flipYOnConcat = flipYOnConcat;
        return '' + props;
    }

} //BindSlot

/** An object to hold every needed info about updating a slot. */
class SlotInfo {

    /** The slot that is about to have its attachment drawn (if any). */
    public var slot:spine.Slot = null;

    /** The global index matching with this current slot name. */
    public var globalSlotIndex:Int = -1;

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

@:allow(ceramic.Spine)
private class DispatchSlotInfo extends Entity {

    @event function dispatch(info:SlotInfo);

    public function new() {}

} //DispatchSlotInfo
