package ceramic;

import ceramic.AlphaColor;
import ceramic.Blending;
import ceramic.Collection;
import ceramic.CollectionEntry;
import ceramic.Color;
import ceramic.Mesh;
import ceramic.MeshColorMapping;
import ceramic.Shader;
import ceramic.Shortcuts.*;
import ceramic.Texture;
import ceramic.Transform;
import ceramic.Triangulate;
import ceramic.Visual;
import spine.*;
import spine.AnimationState;
import spine.attachments.*;
import spine.support.graphics.TextureAtlas;
import spine.support.utils.FloatArray;
import spine.utils.SkeletonClipping;

using StringTools;
using ceramic.Extensions;
using ceramic.SpinePlugin;

/**
 * Spine animation runtime for Ceramic engine.
 * 
 * This class provides full support for Spine 2D skeletal animations, including:
 * - Animation playback with mixing and blending
 * - Skin switching at runtime
 * - Slot customization and visibility control
 * - Hierarchical Spine composition (Spine within Spine)
 * - Attachment rendering (regions, meshes, clipping)
 * - Event handling and animation completion callbacks
 * - Tint black support for advanced coloring
 * - Bounding box hit testing
 * 
 * ## Basic Usage
 * 
 * ```haxe
 * var spine = new Spine();
 * spine.spineData = assets.spine('hero');
 * spine.animation = 'walk';
 * spine.loop = true;
 * add(spine);
 * ```
 * 
 * ## Advanced Features
 * 
 * - **Slot Control**: Hide/show specific slots, or use slot whitelists
 * - **Spine Binding**: Attach child Spine animations to parent slots
 * - **Custom Rendering**: Hook into slot update events for custom drawing
 * - **Performance**: Automatic freezing when animations complete
 * 
 * @see SpineData
 * @see SpineAsset
 * @see SpineSystem
 */
class Spine extends Visual {

/// Internal

    static var _degRad:Float = Math.PI / 180.0;

    static var _matrix:Transform = new Transform();

    static var _quadTriangles:Array<Int> = [0,1,2,2,3,0];

    static var _trackTimes:Array<Float> = [];

    static var _globalBindDepthRange:Float = 1000;

    static var _tintBlackShader:Shader = null;

/// Spine Animation State listener

    /**
     * Internal listener that handles Spine animation state events.
     * Forwards animation callbacks to the appropriate event handlers.
     */
    var listener:SpineListener;

    /**
     * Maps slot indices to their corresponding mesh objects.
     * Each slot that renders geometry gets a Mesh for efficient GPU rendering.
     */
    var slotMeshes:IntMap<Mesh> = new IntMap(16, 0.5, true); // TODO This could be an array or vector

    /**
     * Reusable SlotInfo object for slot update events.
     * Avoids creating new objects each frame for performance.
     */
    var slotInfo:SlotInfo = new SlotInfo();

    /**
     * Array of child Spine animations attached to this parent.
     * Enables hierarchical animation composition where child animations follow parent slots.
     */
    var subSpines:Array<Spine> = null;

    /**
     * Depth increment between sub-animations to prevent z-fighting.
     * Each child slot gets a slightly different depth for proper layering.
     */
    var subDepthStep:Float = 0.01;

    /**
     * Maps parent slot indices to arrays of child slot binding information.
     * Used for Spine-in-Spine composition where child animations follow parent slots.
     */
    var boundParentSlots:IntMap<Array<BindSlot>> = null;

    /**
     * Maps child slot indices to their parent binding information.
     * Computed from boundParentSlots for efficient lookup during rendering.
     */
    var boundChildSlots:IntMap<BindSlot> = null;

    /**
     * Flag indicating that boundChildSlots needs to be recomputed.
     * Set when parent slot bindings are modified.
     */
    var boundChildSlotsDirty:Bool = false;

    /**
     * Global index of the parent slot that this entire Spine follows.
     * When set, all child slots transform relative to this parent slot.
     */
    var globalBoundParentSlotGlobalIndex:Int = -1;

    /**
     * Reference to the actual parent slot object being followed.
     * Updated during rendering to track the parent slot's current state.
     */
    var globalBoundParentSlot:Slot = null;

    /**
     * Rendering depth of the global parent slot.
     * Child animations render relative to this depth.
     */
    var globalBoundParentSlotDepth:Float = 0.0;

    /**
     * Whether the global parent slot is currently visible.
     * Child animations are hidden when their parent slot is not visible.
     */
    var globalBoundParentSlotVisible:Bool = false;

    /**
     * Stores the setup pose transforms for each bone.
     * Used for accurate child animation positioning relative to parent slots.
     */
    var setupBoneTransforms:IntMap<Transform> = null;

    /**
     * Index of the first slot with a bounding box attachment found during rendering.
     * Used for hitWithFirstBoundingBox functionality.
     */
    var firstBoundingBoxSlotIndex:Int = -1;

    /**
     * Handles clipping attachment processing for rendering masked regions.
     * Clips slot geometry to defined shapes for visual effects.
     */
    var clipper:SkeletonClipping = new SkeletonClipping();

    /**
     * Current clipping shape being applied during rendering.
     * Generated from clipping attachments in the skeleton.
     */
    var clipShape:Shape = null;

    /**
     * Maps slot indices to their clipping shapes.
     * Caches clipping geometry for performance.
     */
    var slotClips:IntMap<Shape> = new IntMap(16, 0.5, true);

    /**
     * When true, suppresses animation events from being fired.
     * Used during forced rendering to prevent unwanted event callbacks.
     */
    var muteEvents:Bool = false;

    /**
     * When true, defers event emission until the next frame.
     * Prevents issues with events fired during rendering.
     */
    var deferEvents:Bool = false;

/// Events

    /**
     * Emitted when a Spine animation completes a full cycle.
     * For looped animations, this is fired at the end of each loop.
     * For non-looped animations, this is fired when the animation reaches its end.
     */
    @event function complete();

    /**
     * Emitted when the Spine instance begins rendering its slots.
     * Use this to perform setup before slot rendering begins.
     */
    @event function beginRender();

    /**
     * Emitted when the Spine instance finishes rendering all slots.
     * Use this to perform cleanup or post-processing after rendering.
     */
    @event function endRender();

    /**
     * Emitted for each slot that is about to be rendered.
     * This includes both visible and invisible slots.
     * Modify the `info` parameter to customize slot rendering.
     * 
     * @param info Contains slot data and transform information
     */
    @event function updateSlot(info:SlotInfo);

    /**
     * Emitted only for visible slots that will be rendered.
     * This is a filtered version of `updateSlot` that excludes hidden slots.
     * 
     * @param info Contains slot data and transform information
     */
    @event function updateVisibleSlot(info:SlotInfo);

    /**
     * Emitted before the skeleton's animation state is updated.
     * Use this to modify skeleton properties before animation is applied.
     */
    @event function updateSkeleton();

    /**
     * Emitted before world transforms are calculated for all bones.
     * Hook into this event to apply custom bone transformations.
     */
    @event function updateWorldTransform();

    /**
     * Emitted when a chain of animations completes without interruption.
     * This is fired when all animations in `nextAnimations` have finished.
     * If the animation chain is interrupted, this event is not fired.
     */
    @event function finishCurrentAnimationChain();

    /**
     * Emitted when an animation from `nextAnimations` is applied.
     * This allows tracking of animation transitions in a chain.
     * 
     * @param animation The name of the animation being applied
     */
    @event function applyNextAnimation(animation:String);

    /**
     * Emitted when a Spine event keyframe is triggered during animation.
     * Spine events are defined in the Spine editor and triggered at specific times.
     * 
     * @param entry The track entry that triggered the event
     * @param event The Spine event data
     */
    @event function spineEvent(entry:TrackEntry, event:Event);

/// Render status

    /**
     * Flag indicating whether a render operation is already scheduled.
     * Prevents multiple render operations from being queued.
     */
    var renderScheduled:Bool = false;

    // Not sure this is needed, but it may prevent some unnecessary allocation
    function runScheduledRender():Void {
        if (destroyed) {
            // Could happen when called as immediate callback
            return;
        }
        renderScheduled = false;
        if (renderDirtyAgressive) {
            if (!renderWhenInvisible && visibilityDirty) {
                spineComputeVisibility();
            }
            if (computedVisible || renderWhenInvisible) {
                forceRender();
            }
            else {
                renderDirty = false;
            }
        }
        else if (renderDirty) {
            if (!renderWhenInvisible && visibilityDirty) {
                spineComputeVisibility();
            }
            if (computedVisible || renderWhenInvisible) {
                render(0, 0, false);
            }
            else {
                renderDirty = false;
            }
        }
    }
    /**
     * Dynamic reference to the scheduled render function.
     * Cached to avoid creating new closures each time.
     */
    var runScheduledRenderDyn:Void->Void = null;

    /**
     * Internal flag to know if render became dirty because of a skin change or a new animation was set.
     */
    public var renderDirtyAgressive(default, set):Bool = false;
    function set_renderDirtyAgressive(renderDirtyAgressive:Bool):Bool {
        if (renderDirtyAgressive && parent != null && Std.isOfType(parent, Spine)) {
            var parentSpine:Spine = cast parent;
            parentSpine.renderDirty = true;
        }
        if (renderDirtyAgressive && !renderScheduled) {
            if (!renderWhenInvisible && visibilityDirty) {
                spineComputeVisibility();
            }
            if (computedVisible || renderWhenInvisible) {
                renderScheduled = true;
                if (runScheduledRenderDyn == null) runScheduledRenderDyn = runScheduledRender;
                app.oncePostFlushImmediate(runScheduledRenderDyn);
            }
        }
        return (this.renderDirtyAgressive = renderDirtyAgressive);
    }

    public var renderDirty(default, set):Bool = false;
    function set_renderDirty(renderDirty:Bool):Bool {
        if (renderDirty && parent != null && Std.isOfType(parent, Spine)) {
            var parentSpine:Spine = cast parent;
            parentSpine.renderDirty = true;
        }
        if (renderDirty && !renderScheduled) {
            if (!renderWhenInvisible && visibilityDirty) {
                spineComputeVisibility();
            }
            if (computedVisible || renderWhenInvisible) {
                renderScheduled = true;
                if (runScheduledRenderDyn == null) runScheduledRenderDyn = runScheduledRender;
                app.oncePostFlushImmediate(runScheduledRenderDyn);
            }
        }
        return (this.renderDirty = renderDirty);
    }

    /**
     * Indicates whether any slot in the skeleton uses tint black coloring.
     * This is automatically detected when the skeleton data is loaded.
     * When true, a special shader is used to support dark tinting.
     */
    public var hasSlotsWithTintBlack(default,null):Bool = false;

/// Properties

    /**
     * Sets the skeleton's origin point for positioning.
     * Values are normalized (0-1) where 0.5 is center.
     * 
     * @param skeletonOriginX Horizontal origin (0=left, 0.5=center, 1=right)
     * @param skeletonOriginY Vertical origin (0=top, 0.5=center, 1=bottom)
     */
    inline public function skeletonOrigin(skeletonOriginX:Float, skeletonOriginY:Float):Void {
        this.skeletonOriginX = skeletonOriginX;
        this.skeletonOriginY = skeletonOriginY;
    }

    /**
     * The horizontal origin point of the skeleton (0-1).
     * Determines the pivot point for positioning and transformations.
     * Default is 0.5 (center).
     */
    public var skeletonOriginX(default, set):Float = 0.5;
    function set_skeletonOriginX(skeletonOriginX:Float):Float {
        if (this.skeletonOriginX == skeletonOriginX) return skeletonOriginX;
        this.skeletonOriginX = skeletonOriginX;
        renderDirty = true;
        return skeletonOriginX;
    }

    /**
     * The vertical origin point of the skeleton (0-1).
     * Determines the pivot point for positioning and transformations.
     * Default is 0.5 (center).
     */
    public var skeletonOriginY(default, set):Float = 0.5;
    function set_skeletonOriginY(skeletonOriginY:Float):Float {
        if (this.skeletonOriginY == skeletonOriginY) return skeletonOriginY;
        this.skeletonOriginY = skeletonOriginY;
        renderDirty = true;
        return skeletonOriginY;
    }

    /**
     * Uniform scale factor applied to the entire skeleton.
     * Use this to resize the skeleton without affecting individual bone scales.
     * Default is 1.0 (original size).
     */
    public var skeletonScale(default, set):Float = 1.0;
    function set_skeletonScale(skeletonScale:Float):Float {
        if (this.skeletonScale == skeletonScale) return skeletonScale;
        this.skeletonScale = skeletonScale;
        renderDirty = true;
        return skeletonScale;
    }

    /**
     * Forces the use of tint black shader even if the skeleton doesn't require it.
     * Enable this if you need dark tinting support for dynamically created attachments.
     */
    public var forceTintBlack(default, set):Bool = false;
    function set_forceTintBlack(forceTintBlack:Bool):Bool {
        if (this.forceTintBlack == forceTintBlack) return forceTintBlack;
        this.forceTintBlack = forceTintBlack;
        renderDirty = true;
        return forceTintBlack;
    }

    /**
     * Map of slot indices to hide (blacklist).
     * Slots in this map will not be rendered.
     * Use `Spine.globalSlotIndexForName()` to get slot indices.
     */
    public var hiddenSlots(default, set):IntBoolMap = null;
    function set_hiddenSlots(hiddenSlots:IntBoolMap):IntBoolMap {
        if (this.hiddenSlots == hiddenSlots) return hiddenSlots;
        this.hiddenSlots = hiddenSlots;
        renderDirty = true;
        return hiddenSlots;
    }

    /**
     * Map of slot indices to show (whitelist).
     * When set, only slots in this map will be rendered.
     * Use `Spine.globalSlotIndexForName()` to get slot indices.
     */
    public var visibleSlots(default, set):IntBoolMap = null;
    function set_visibleSlots(visibleSlots:IntBoolMap):IntBoolMap {
        if (this.visibleSlots == visibleSlots) return visibleSlots;
        this.visibleSlots = visibleSlots;
        renderDirty = true;
        return visibleSlots;
    }

    /**
     * Map of slot indices that are completely disabled.
     * Disabled slots are skipped entirely during rendering.
     * Use `Spine.globalSlotIndexForName()` to get slot indices.
     */
    public var disabledSlots(default, set):IntBoolMap = null;
    function set_disabledSlots(disabledSlots:IntBoolMap):IntBoolMap {
        if (this.disabledSlots == disabledSlots) return disabledSlots;
        this.disabledSlots = disabledSlots;
        renderDirty = true;
        return disabledSlots;
    }

    /**
     * Map of animation names to trigger animations.
     * When an animation event matches a key in this map,
     * the corresponding animation will be triggered.
     */
    public var animationTriggers(default, set):Map<String,String> = null;
    function set_animationTriggers(animationTriggers:Map<String,String>):Map<String,String> {
        if (this.animationTriggers == animationTriggers) return animationTriggers;
        this.animationTriggers = animationTriggers;
        renderDirty = true;
        return animationTriggers;
    }

    /**
     * Specifies which slot index to use for hit testing.
     * Set to -1 (default) to use the visual's bounds instead.
     * This allows precise hit detection using a specific slot's attachment.
     */
    public var hitWithSlotIndex(default, set):Int = -1;
    function set_hitWithSlotIndex(hitWithSlotIndex:Int):Int {
        if (this.hitWithSlotIndex == hitWithSlotIndex) return hitWithSlotIndex;
        this.hitWithSlotIndex = hitWithSlotIndex;
        return hitWithSlotIndex;
    }

    /**
     * When true, uses the first bounding box attachment for hit testing.
     * This provides accurate collision detection for complex shapes.
     * Overrides `hitWithSlotIndex` when enabled.
     */
    public var hitWithFirstBoundingBox(default, set):Bool = false;
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

    /**
     * When true, forces rendering even when the visual is not visible.
     * Useful for animations that need to continue updating off-screen.
     */
    public var renderWhenInvisible(default, set):Bool = false;
    function set_renderWhenInvisible(renderWhenInvisible:Bool):Bool {
        if (this.renderWhenInvisible == renderWhenInvisible) return renderWhenInvisible;
        this.renderWhenInvisible = renderWhenInvisible;
        if (visibilityDirty) {
            spineComputeVisibility();
        }
        if (!computedVisible && renderWhenInvisible) {
            renderDirty = true;
        }
        return renderWhenInvisible;
    }

    /**
     * Indicates whether this Spine instance is a child of another Spine animation.
     * Child animations are managed and rendered by their parent.
     */
    public var hasParentSpine(default,null):Bool = false;

    /**
     * Global tint color applied to the entire skeleton.
     * Multiplied with individual slot and attachment colors.
     * Default is WHITE (no tinting).
     */
    public var color(default, set):Color = Color.WHITE;
    function set_color(color:Color):Color {
        if (this.color == color) return color;
        this.color = color;
        renderDirty = true;
        return color;
    }

    /**
     * When true, forces an immediate render after calling `animate()`.
     * Useful for ensuring the first frame is displayed immediately.
     */
    public var autoRenderOnAnimate:Bool = false;

    /**
     * The Spine skeleton data containing all animations, bones, and slots.
     * Setting this property loads a new skeleton and resets the animation state.
     */
    public var spineData(default, set):SpineData = null;
    function set_spineData(spineData:SpineData):SpineData {
        if (this.spineData == spineData) return spineData;

        // Render will be updated from skeleton change anyway
        renderDirtyAgressive = false;

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

        // Restore explicit skin name
        if (!destroyed && skin != null && skeleton != null) {
            var spineSkin:Skin = skeletonData.findSkin(skin == null ? 'default' : skin);
            if (spineSkin == null) {
                log.warning('Skin not found: ' + (skin == null ? 'default' : skin) + ' (skeleton: ' + skeletonData.name + ')');
            } else {
                skeleton.setSkin(spineSkin);
                skeleton.setSlotsToSetupPose();
            }
        }

        // Restore explicit animation name
        if (!destroyed && animation != null && skeletonData != null && skeletonData.findAnimation(animation) != null) {
            animate(animation, loop, 0);
        }

        return spineData;
    }

    /**
     * The current skin applied to the skeleton.
     * Skins allow swapping attachment sets at runtime (e.g., different armor sets).
     * Set to null to use the default skin.
     */
    public var skin(default, set):String = null;
    function set_skin(skin:String):String {
        if (this.skin == skin) return skin;
        this.skin = skin;
        if (skeleton != null) {
            var spineSkin:Skin = skeletonData.findSkin(skin == null ? 'default' : skin);
            if (spineSkin == null) {
                log.warning('Skin not found: ' + (skin == null ? 'default' : skin) + ' (skeleton: ' + skeletonData.name + ')');
            } else {
                skeleton.setSkin(spineSkin);
                skeleton.setSlotsToSetupPose();
            }
        }
        if (animation != null) {
            // If there is an animation running, render needs to be updated
            // more eagerly to use the new skin. Keep that info in a flag.
            renderDirtyAgressive = true;
        }
        return skin;
    }

    /**
     * Internal flag to prevent clearing nextAnimations when setting animation programmatically.
     * Used during animation chaining to maintain the queue.
     */
    var _settingNextAnimation = false;

    /**
     * The name of the currently playing animation.
     * Setting this property starts the animation immediately.
     * Set to null to clear the animation.
     */
    public var animation(default, set):String = null;
    function set_animation(animation:String):String {
        if (!_settingNextAnimation) {
            if (nextAnimations != null) nextAnimations = null;
            offFinishCurrentAnimationChain();
        }
        if (this.animation == animation) return animation;
        this.animation = animation;

        // Render will be updated from animation change anyway
        renderDirtyAgressive = false;

        if (spineData != null) animate(animation, loop, 0);
        return animation;
    }

    /**
     * Array of animation names to play sequentially after the current animation.
     * Each animation in the chain will play once before moving to the next.
     * The `finishCurrentAnimationChain` event fires when all animations complete.
     */
    public var nextAnimations(default, set):Array<String> = null;
    function set_nextAnimations(nextAnimations:Array<String>) {
        if (this.nextAnimations == nextAnimations) return nextAnimations;
        this.nextAnimations = nextAnimations;
        return nextAnimations;
    }

    /**
     * Whether the current animation should loop continuously.
     * Only applies to the main animation, not animations in `nextAnimations`.
     */
    public var loop(default, set):Bool = true;
    function set_loop(loop:Bool):Bool {
        if (this.loop == loop) return loop;
        this.loop = loop;
        if (spineData != null && animation != null) animate(animation, loop, 0);
        return loop;
    }

    /**
     * The Spine skeleton instance containing the current pose.
     * Provides access to bones, slots, and attachments for runtime manipulation.
     */
    public var skeleton(default,null):Skeleton;

    /**
     * The skeleton data containing all setup pose information.
     * This includes bones, slots, animations, and skins definitions.
     */
    public var skeletonData(default, null):SkeletonData;

    /**
     * The animation state managing animation playback and mixing.
     * Use this for advanced animation control like layering multiple animations.
     */
    public var state(default, null):AnimationState;

    /**
     * Configuration for animation mixing (crossfading) durations.
     * Defines how long transitions between animations should take.
     */
    public var stateData(default, null):AnimationStateData;

    /**
     * Controls automatic animation updates each frame.
     * Set to false if you need manual control over update timing.
     * Note: Use `paused` to pause animations, not this property.
     */
    public var autoUpdate:Bool = true;

    /**
     * Indicates whether the animation is currently paused or frozen.
     * This is a combination of the `paused` and `frozen` states.
     */
    public var pausedOrFrozen(default, null):Bool = false;

    /**
     * Enables automatic freezing when animations complete.
     * Frozen animations stop updating to improve performance.
     * The animation resumes when a new animation is set.
     */
    public var autoFreeze(default, set):Bool = true;
    function set_autoFreeze(autoFreeze:Bool):Bool {
        if (this.autoFreeze == autoFreeze) return autoFreeze;
        this.autoFreeze = autoFreeze;
        if (frozen && !canFreeze()) {
            frozen = false;
        }
        return autoFreeze;
    }

    /**
     * Pauses the animation at its current frame.
     * The animation can be resumed by setting this to false.
     */
    public var paused(default, set):Bool = false;
    function set_paused(paused:Bool):Bool {
        if (this.paused == paused) return paused;

        this.paused = paused;
        pausedOrFrozen = paused || frozen;

        return paused;
    }

    /**
     * Indicates whether the animation is frozen (auto-paused after completion).
     * Frozen animations automatically resume when a new animation is set.
     */
    public var frozen(default, set):Bool = false;
    function set_frozen(frozen:Bool):Bool {
        if (this.frozen == frozen) return frozen;

        this.frozen = frozen;
        pausedOrFrozen = paused || frozen;

        return frozen;
    }

    /**
     * When true, resets the skeleton to setup pose when animations change.
     * This ensures clean transitions between animations.
     */
    public var resetAtChange:Bool = true;

/// Properties (internal)

    /**
     * Flag indicating that the skeleton should be reset to setup pose on next update.
     * Set when resetAtChange is true and a new animation starts.
     */
    var resetSkeleton:Bool = false;

/// Lifecycle

    public function new(#if ceramic_debug_entity_allocs ?pos:haxe.PosInfos #end) {

        super(#if ceramic_debug_entity_allocs pos #end);

        if (_tintBlackShader == null) _tintBlackShader = ceramic.App.app.assets.shader('shader:tintBlack');

        SpineSystem.shared.spines.push(this);

    }

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
                mesh.clip = null;
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

        keys = slotClips.iterableKeys;
        for (i in 0...keys.length) {
            var key = keys.unsafeGet(i);
            var clip = slotClips.getInline(key);
            if (clip != null) {
                clip.points = null;
                clip.destroy();
                if (!destroyed) {
                    slotClips.set(key, null);
                }
            }
        }

        if (destroyed) {
            slotMeshes = null;
            slotClips = null;
        }

    }

    override function clear():Void {

        clearMeshes();

        super.clear();

    }

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

            if (!muteEvents) {
                if (deferEvents) {
                    app.onceImmediate(emitCompleteIfNotDestroyed);
                }
                else {
                    emitComplete();
                }
            }

        };

        listener.onEnd = function(track) {

        };

        listener.onEvent = function(track, event) {

            if (!muteEvents) {
                if (deferEvents) {
                    app.onceImmediate(() -> {
                        if (!destroyed) {
                            emitSpineEvent(track, event);
                        }
                    });
                }
                else {
                    emitSpineEvent(track, event);
                }
            }

        };

        state.addListener(listener);

        // Check if some slots use tint black
        var slotData = skeletonData.slots;
        var hasSlotsWithTintBlack = false;
        for (i in 0...slotData.length) {
            var slot = slotData.unsafeGet(i);
            if (slot.darkColor != null) {
                hasSlotsWithTintBlack = true;
                break;
            }
        }
        this.hasSlotsWithTintBlack = hasSlotsWithTintBlack;

        contentDirty = false;

        // Perform setup render to gather required information
        resetSkeleton = true;
        updateSkeleton(0);
        render(0, 0, true);

        renderDirty = true;

    }

    function emitCompleteIfNotDestroyed() {

        if (!destroyed) {
            emitComplete();
        }

    }

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

    }

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

    /**
     * Starts playing an animation on the specified track.
     * 
     * This is the main method for controlling animation playback. Animations can be
     * played on multiple tracks for layering effects (e.g., walk + shoot).
     * 
     * @param animationName Name of the animation to play, or null for empty animation
     * @param loop Whether the animation should repeat continuously
     * @param trackIndex The track to play the animation on (default 0)
     * @param trackTime Starting time of the animation in seconds (default -1 for beginning)
     */
    public function animate(animationName:String, loop:Bool = false, trackIndex:Int = 0, trackTime:Float = -1 #if ceramic_debug_spine_animate , ?pos:haxe.PosInfos #end):Void {
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
                log.warning('Animation not found: ' + animationName + ' (skeleton: ' + skeletonData.name + ')' #if ceramic_debug_spine_animate , pos #end);
                track = state.setEmptyAnimation(trackIndex, 0);
            }
        }

        if (autoFreeze) {
            if (canFreeze()) {
                frozen = true;
                app.onceImmediate(function() {
                    if (!destroyed && !muteEvents) {
                        emitComplete();
                    }
                });
            } else {
                frozen = false;
            }
        } else {
            frozen = false;
        }

        if (autoRenderOnAnimate) {
            deferEvents = true;
            forceRender(false);
            deferEvents = false;
        }
        else {
            renderDirtyAgressive = true;
        }

    }

    /**
     * Forces an immediate render of the current animation state.
     * 
     * This bypasses normal update cycles and renders the skeleton immediately.
     * Useful for capturing specific animation frames or ensuring visual updates.
     * 
     * @param muteEvents Whether to suppress animation events during rendering
     */
    public function forceRender(muteEvents:Bool = true):Void {

        if (state == null) return;

        // Forced rendering will update skin display anyway
        renderDirtyAgressive = false;

        var prevPaused = this.paused;
        var prevFrozen = this.frozen;
        var prevMuteEvents = this.muteEvents;
        this.paused = false;
        this.frozen = false;
        this.muteEvents = muteEvents;

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

        this.paused = prevPaused;
        this.frozen = prevFrozen;
        this.muteEvents = prevMuteEvents;

    }

    /**
     * Resets the skeleton to its setup pose.
     * 
     * This clears all animation data and returns bones and slots to their
     * default positions and values as defined in the Spine project.
     */
    public function reset():Void {
        if (destroyed) return;

        resetSkeleton = true;

    }

/// Cleanup

    override function destroy() {

        super.destroy();

        SpineSystem.shared.spines.remove(this);

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

    }

    /**
     * Updates the Spine animation by the given delta time.
     * 
     * This method is called automatically each frame if `autoUpdate` is true.
     * It updates the animation state, applies it to the skeleton, and renders
     * the result. Child Spine instances are updated by their parent.
     * 
     * @param delta Time elapsed since last update in seconds
     */
    public function update(delta:Float):Void {

        if (hasParentSpine) {
            // Our parent is a spine animation and is responsible
            // of updating our own data and rendering it.
            return;
        }

        // No spine data? Then nothing to animate
        if (spineData == null) return;

        if (!renderWhenInvisible && visibilityDirty) {
            spineComputeVisibility();
        }
        if (computedVisible || renderWhenInvisible) {

            // Update skeleton
            updateSkeleton(delta);

            // We are visible and are root spine animation, let's render
            render(delta, 0, false);
        }

    }

    /**
     * Checks if the animation can be frozen for performance optimization.
     * 
     * An animation can freeze when all tracks have completed their non-looping
     * animations. Frozen animations stop updating until a new animation is set.
     * 
     * @return True if the animation has no active tracks that need updating
     */
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

    }

/// Internal

    /**
     * Update skeleton with the given delta time.
     */
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

    }

    /**
     * Process spine draw order and output quads and meshes.
     */
    function render(delta:Float, z:Float, setup:Bool) {

        if (skeleton == null || destroyed) return;

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
        var microDepth:Float = subDepthStep;
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
        var useTintBlack:Bool = forceTintBlack || hasSlotsWithTintBlack;

        var diffX:Float = width * skeletonOriginX;
        var diffY:Float = height * skeletonOriginY;

        if (regularRender) {
            emitBeginRender();
            if (destroyed)
                return;
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
            tintBlack = slot.data.darkColor != null || useTintBlack;
            vertexSize = 2;
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

                regionAttachment = Std.isOfType(slot.attachment, RegionAttachment) ? cast slot.attachment : null;
                meshAttachment = Std.isOfType(slot.attachment, MeshAttachment) ? cast slot.attachment : null;
                boundingBoxAttachment = regionAttachment == null && meshAttachment == null && Std.isOfType(slot.attachment, BoundingBoxAttachment) ? cast slot.attachment : null;
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
                        if (destroyed)
                            return;

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
                                mesh.customFloatAttributesSize = 0;
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
                                    if (tintBlack) {
                                        mesh.shader = _tintBlackShader;
                                        mesh.customFloatAttributesSize = _tintBlackShader.customFloatAttributesSize;
                                    }
                                    else {
                                        mesh.shader = null;
                                        mesh.customFloatAttributesSize = 0;
                                    }
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
                                        mesh.clip = clipShape;
                                    } else {
                                        mesh.clip = null;
                                    }

                                    mesh.blending = isAdditive ? Blending.ADD : Blending.AUTO;
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
                                microDepth += subDepthStep;
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
                } else if (Std.isOfType(slot.attachment, ClippingAttachment)) {
                    clipAttachment = cast slot.attachment;
                    clipper.clipStart(slot, clipAttachment);

                    clipShape = slotClips.getInline(slot.data.index);

                    if (clipShape == null) {
                        clipShape = new Shape();
                        clipShape.visible = false;
                        add(clipShape);
                        slotClips.set(slot.data.index, clipShape);
                    }

                    @:privateAccess var points:Array<Float> = cast clipper.clippingPolygon;
                    clipShape.points = points.slice(0);
                    clipShape.scaleX = skeletonScale;
                    clipShape.scaleY = -skeletonScale;
                    clipShape.computeContent();

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
                        if (!sub.renderWhenInvisible && sub.visibilityDirty) {
                            sub.spineComputeVisibility();
                        }
                        if (sub.computedVisible || sub.renderWhenInvisible) {

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
            if (destroyed)
                return;
        }

        renderDirty = false;

        // Render children (if any)
        if (!setup && subSpines != null) {
            for (s in 0...subSpines.length) {
                var sub = subSpines.unsafeGet(s);

                // Skip rendering of sub spines if they are not visible, by default
                if (!sub.renderWhenInvisible && sub.visibilityDirty) {
                    sub.spineComputeVisibility();
                }
                if (sub.computedVisible || sub.renderWhenInvisible) {
                    sub.updateSkeleton(delta);
                    sub.render(delta, z, false);
                }
            }
        }

    }

/// Spine animations compositing

    /**
     * Add a child visual. If the child is a spine animation,
     * it will be managed by its parent and compositing becomes possible.
     */
    override public function add(visual:Visual):Void {

        // Default behavior
        super.add(visual);

        // Spine case
        if (Std.isOfType(visual, Spine)) {
            if (subSpines == null) subSpines = [];
            var item:Spine = cast visual;
            item.hasParentSpine = true;
            subSpines.push(item);
        }

    }

    override public function remove(visual:Visual):Void {

        // Default behavior
        super.remove(visual);

        // Spine case
        if (Std.isOfType(visual, Spine)) {
            var item:Spine = cast visual;
            item.hasParentSpine = false;
            subSpines.remove(item);
        }

    }

    /**
     * Maps skeleton-specific slot indices to global slot indices.
     * Enables efficient slot operations across different skeleton structures.
     */
    var globalSlotIndexFromSkeletonSlotIndex:Array<Int> = [];

    /**
     * Maps global slot indices to their event dispatchers for slot updates.
     * Enables efficient per-slot event handling without checking all slots.
     */
    var updateSlotWithNameDispatchers:IntMap<DispatchSlotInfo> = null;

    /**
     * Array version of updateSlotWithNameDispatchers for efficient iteration.
     * Kept in sync with the map for cleanup operations.
     */
    var updateSlotWithNameDispatchersAsList:Array<DispatchSlotInfo> = null;

    /**
     * Maps global slot indices to their event dispatchers for visible slot updates.
     * Only fires for slots that are actually being rendered.
     */
    var updateVisibleSlotWithNameDispatchers:IntMap<DispatchSlotInfo> = null;

    /**
     * Array version of updateVisibleSlotWithNameDispatchers for efficient iteration.
     * Kept in sync with the map for cleanup operations.
     */
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

    }

    /**
     * Registers a handler for updates to a specific slot by name.
     * 
     * This is more efficient than the general `updateSlot` event as it only
     * fires for the specified slot, reducing overhead for complex skeletons.
     * 
     * @param owner Optional owner entity for automatic cleanup
     * @param slotName Name of the slot to monitor
     * @param handleInfo Handler function called when the slot updates
     */
    inline public function onUpdateSlotWithName(#if ceramic_optional_owner ?owner:Entity #else owner:Null<Entity> #end, slotName:String, handleInfo:SlotInfo->Void):Void {

        onUpdateSlotWithGlobalIndex(owner, globalSlotIndexForName(slotName), handleInfo);

    }

    /**
     * Registers a handler for updates to a specific slot by global index.
     * 
     * This is the most efficient way to monitor specific slots, using
     * pre-computed global indices for direct lookup.
     * 
     * @param owner Optional owner entity for automatic cleanup
     * @param index Global slot index (use `globalSlotIndexForName()`)
     * @param handleInfo Handler function called when the slot updates
     */
    public function onUpdateSlotWithGlobalIndex(#if ceramic_optional_owner ?owner:Entity #else owner:Null<Entity> #end, index:Int, handleInfo:SlotInfo->Void):Void {

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

    }

    inline public function offUpdateSlotWithName(slotName:String, ?handleInfo:SlotInfo->Void):Void {

        offUpdateSlotWithGlobalIndex(globalSlotIndexForName(slotName), handleInfo);

    }

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

    }

    /**
     * Same as `onUpdateSlotWithName`, but fired only for visible slots (`drawDefault=true`)
     */
    inline public function onUpdateVisibleSlotWithName(#if ceramic_optional_owner ?owner:Entity #else owner:Null<Entity> #end, slotName:String, handleInfo:SlotInfo->Void):Void {

        onUpdateVisibleSlotWithGlobalIndex(owner, globalSlotIndexForName(slotName), handleInfo);

    }

    /**
     * Same as `onUpdateSlotWithGlobalIndex`, but fired only for visible slots (`drawDefault=true`)
     */
    public function onUpdateVisibleSlotWithGlobalIndex(#if ceramic_optional_owner ?owner:Entity #else owner:Null<Entity> #end, index:Int, handleInfo:SlotInfo->Void):Void {

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

    }

    inline public function offUpdateVisibleSlotWithName(slotName:String, ?handleInfo:SlotInfo->Void):Void {

        offUpdateVisibleSlotWithGlobalIndex(globalSlotIndexForName(slotName), handleInfo);

    }

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

    }

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

    }

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

    }

    /**
     * Binds a parent Spine slot to this child Spine instance.
     * 
     * This enables Spine-in-Spine composition, where child animations follow
     * parent slot transformations. Common uses include:
     * - Weapons attached to hands
     * - Armor pieces following body parts
     * - Modular character systems
     * 
     * @param parentSlot Name of the parent slot to bind to
     * @param options Optional binding configuration (local slot, flipping)
     */
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

    }

    /**
     * Removes a parent slot binding.
     * 
     * This disconnects the child Spine from following the specified parent slot.
     * 
     * @param parentSlot Name of the parent slot to unbind from
     */
    public function unbindParentSlot(parentSlot:String) {

        var parentSlotGlobalIndex = globalSlotIndexForName(parentSlot);
        var bindList = boundParentSlots.get(parentSlotGlobalIndex);
        if (bindList != null) {
            boundChildSlotsDirty = true;
            boundParentSlots.remove(parentSlotGlobalIndex);
        }

    }

    /**
     * Compute `boundChildSlots` from `boundParentSlots` to make it more efficient
     * to gather parent slot transformations when drawing child animation.
     */
    function computeBoundChildSlots() {

        boundChildSlots = new IntMap();

        var values = boundParentSlots.values;
        for (i in 0...values.length) {
            var bindList:Array<BindSlot> = values.get(i);
            if (bindList != null) {
                for (b in 0...bindList.length) {
                    var bindItem:BindSlot = bindList.unsafeGet(b);
                    if (bindItem.toLocalSlot > 0 && boundChildSlots.get(bindItem.toLocalSlot) == null) {
                        boundChildSlots.set(bindItem.toLocalSlot, bindItem);
                    }
                }
            }
        }

        boundChildSlotsDirty = false;

    }

/// Helpers

    /**
     * Encodes the ABGR int color as a float. The high bits are masked to avoid using floats in the NaN range, which unfortunately
     *  * means the full range of alpha cannot be used.
     */
    inline static function intToFloatColor(value:Int):Float {

        return 1.0 * (value & 0xFEFFFFFF);

    }

/// Visibility

    function spineComputeVisibility():Void {

        super.computeVisibility();

    }

    override function computeVisibility():Void {

        var wasVisible = computedVisible;

        super.computeVisibility();

        if (computedVisible && !wasVisible && !renderWhenInvisible) {
            renderDirtyAgressive = true;
            /*if (!renderScheduled) {
                renderScheduled = true;
                if (runScheduledRenderDyn == null) runScheduledRenderDyn = runScheduledRender;
                app.onceImmediate(runScheduledRenderDyn);
            }*/
        }

    }

/// Hit test

    override function hitTest(x:Float, y:Float, matrix:Transform):Bool {

        if (hitWithFirstBoundingBox) {

            var testX = matrix.transformX(x, y);
            var testY = matrix.transformY(x, y);

            if (firstBoundingBoxSlotIndex != -1) {
                var mesh = slotMeshes.getInline(firstBoundingBoxSlotIndex);
                if (mesh != null) {
                    mesh.complexHit = true;
                    var result = mesh.hits(x, y);
                    mesh.complexHit = false;
                    return result;
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
                var result = mesh.hits(x, y);
                mesh.complexHit = false;
                return result;
            }
            else {
                return false;
            }
        }
        else {
            return super.hitTest(x, y, matrix);
        }
    }

    static var _globalSlotIndexes:Map<String,Int> = new Map();
    static var _nextGlobalSlotIndex:Int = 1;

    /**
     * Gets a globally unique slot index for the given slot name.
     * 
     * Global slot indices are consistent across all skeletons, unlike regular
     * slot indices which vary by skeleton structure. This enables efficient
     * slot operations across different Spine instances.
     * 
     * The same slot name always returns the same global index, making it
     * ideal for slot blacklists, whitelists, and cross-skeleton references.
     * 
     * @param slotName The name of the slot
     * @return A unique global index for this slot name
     */
    inline static public function globalSlotIndexForName(slotName:String):Int {

        // Retrieve global slot index (an index that works with any skeleton)
        if (!_globalSlotIndexes.exists(slotName)) {
            _globalSlotIndexes.set(slotName, _nextGlobalSlotIndex++);
        }
        return _globalSlotIndexes.get(slotName);

    }

}

/**
 * Internal listener for Spine animation state events.
 * 
 * This class implements the AnimationStateListener interface and forwards
 * events to dynamic function properties for flexible event handling.
 */
class SpineListener implements AnimationStateListener {

    public function new() {}

    /**
     * Called when an animation starts playing on a track.
     * @param entry The track entry that started
     */
    public dynamic function onStart(entry:TrackEntry):Void {};
    public function start(entry:TrackEntry):Void {
        if (onStart != null) onStart(entry);
    }

    /**
     * Called when an animation is interrupted by another animation.
     * The interrupted animation may continue mixing.
     * @param entry The track entry that was interrupted
     */
    public dynamic function onInterrupt(entry:TrackEntry):Void {}
    public function interrupt(entry:TrackEntry):Void {
        if (onInterrupt != null) onInterrupt(entry);
    }

    /**
     * Called when an animation ends and will no longer be applied.
     * @param entry The track entry that ended
     */
    public dynamic function onEnd(entry:TrackEntry):Void {}
    public function end(entry:TrackEntry):Void {
        if (onEnd != null) onEnd(entry);
    }

    /**
     * Called when a track entry is about to be disposed.
     * Do not keep references to the entry after this call.
     * @param entry The track entry being disposed
     */
    public dynamic function onDispose(entry:TrackEntry):Void {}
    public function dispose(entry:TrackEntry):Void {
        if (onDispose != null) onDispose(entry);
    }

    /**
     * Called each time an animation completes a full loop.
     * @param entry The track entry that completed
     */
    public dynamic function onComplete(entry:TrackEntry):Void {}
    public function complete(entry:TrackEntry):Void {
        if (onComplete != null) onComplete(entry);
    }

    /**
     * Called when an animation triggers a user-defined event.
     * @param entry The track entry that triggered the event
     * @param event The event data
     */
    public dynamic function onEvent(entry:TrackEntry, event:Event) {}
    public function event(entry:TrackEntry, event:Event) {
        if (onEvent != null) onEvent(entry, event);
    }

}

/**
 * Configuration options for binding Spine slots together.
 * 
 * Used with `bindParentSlot()` to control how child slots follow parent slots.
 */
typedef BindSlotOptions = {

    /**
     * Name of the local slot to bind to the parent slot.
     * If not specified, the entire child Spine follows the parent slot.
     */
    @:optional var toLocalSlot:String;

    /**
     * Whether to flip horizontally when concatenating transforms.
     * Useful for mirroring attachments.
     */
    @:optional var flipXOnConcat:Bool;

    /**
     * Whether to flip vertically when concatenating transforms.
     * Useful for inverting attachments.
     */
    @:optional var flipYOnConcat:Bool;

}

@:allow(ceramic.Spine)
private class BindSlot {

    /**
     * Global index of the parent slot that this binding follows.
     */
    public var fromParentSlot:Int = -1;

    /**
     * Global index of the local child slot being bound to the parent.
     * -1 means the entire child Spine follows the parent slot.
     */
    public var toLocalSlot:Int = -1;

    /**
     * Rendering depth of the parent slot during the last update.
     * Used to position child elements at the correct depth.
     */
    public var parentDepth:Float = 0;

    /**
     * Whether the parent slot was visible during the last update.
     * Child elements are hidden when their parent is not visible.
     */
    public var parentVisible:Bool = false;

    /**
     * World transform of the parent slot.
     * Child elements apply this transform to follow the parent.
     */
    public var parentTransform:Transform = new Transform();

    /**
     * Reference to the actual parent slot object.
     * Provides access to parent slot properties like color and attachment.
     */
    public var parentSlot:Slot = null;

    /**
     * Whether to apply horizontal flipping when concatenating transforms.
     * Useful for mirroring child animations relative to parent orientation.
     */
    public var flipXOnConcat:Bool = false;

    /**
     * Whether to apply vertical flipping when concatenating transforms.
     * Useful for inverting child animations relative to parent orientation.
     */
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

}

/**
 * Information about a slot being updated during rendering.
 * 
 * This class is passed to slot update handlers and contains all the data
 * needed to customize or override slot rendering. You can modify properties
 * to affect how the slot is drawn.
 * 
 * ## Usage Example
 * 
 * ```haxe
 * spine.onUpdateSlotWithName(this, "weapon", function(info) {
 *     // Apply custom transform to weapon slot
 *     info.customTransform = new Transform();
 *     info.customTransform.rotate(Math.PI * 0.25);
 *     
 *     // Or disable rendering
 *     info.drawDefault = false;
 * });
 * ```
 */
class SlotInfo {

    /**
     * The Spine slot being updated.
     * Contains attachment, color, and bone information.
     */
    public var slot:spine.Slot = null;

    /**
     * Global index for this slot name.
     * Use this for efficient slot identification across skeletons.
     */
    public var globalSlotIndex:Int = -1;

    /**
     * Optional custom transform to apply to this slot.
     * Set this to override the slot's normal positioning.
     * Defaults to null (no custom transform).
     */
    public var customTransform:Transform = null;

    /**
     * The computed world transform for this slot.
     * Includes bone transforms and parent hierarchy.
     * Read-only - modify customTransform instead.
     */
    public var transform(default,null):Transform = new Transform();

    /**
     * Controls whether this slot's attachment should be rendered.
     * Set to false to hide the slot while still processing it.
     * Useful for custom rendering or selective visibility.
     */
    public var drawDefault:Bool = true;

    /**
     * The rendering depth (z-order) for this slot.
     * Higher values render on top of lower values.
     * Can be modified to change rendering order.
     */
    public var depth:Float = 0;

    public function new() {}

}

@:allow(ceramic.Spine)
private class DispatchSlotInfo extends Entity {

    @event function dispatch(info:SlotInfo);

}
