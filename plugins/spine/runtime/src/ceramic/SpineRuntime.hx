package ceramic;

import spine.Bone;
import spine.BoneData;
import spine.Skeleton;
import spine.Slot;
import spine.SlotData;
import spine.attachments.Attachment;
import spine.attachments.RegionAttachment;

#if spine_legacy

/** Color type of the spine runtime in use */
typedef SpineColor = spine.support.graphics.Color;

/** Texture atlas type of the spine runtime in use */
typedef SpineAtlas = spine.support.graphics.TextureAtlas;

/** Texture atlas page type of the spine runtime in use */
typedef SpineAtlasPage = spine.support.graphics.TextureAtlas.AtlasPage;

/** Texture atlas region type of the spine runtime in use */
typedef SpineAtlasRegion = spine.support.graphics.TextureAtlas.AtlasRegion;

/** Texture loader interface of the spine runtime in use */
typedef SpineAtlasTextureLoader = spine.support.graphics.TextureLoader;

/** Animation state track entry type of the spine runtime in use */
typedef SpineTrackEntry = spine.AnimationState.TrackEntry;

/** Animation state type of the spine runtime in use */
typedef SpineAnimationState = spine.AnimationState;

/** Animation state data type of the spine runtime in use */
typedef SpineAnimationStateData = spine.AnimationStateData;

/** Animation type of the spine runtime in use */
typedef SpineAnimation = spine.Animation;

#else

/** Color type of the spine runtime in use */
typedef SpineColor = spine.Color;

/** Texture atlas type of the spine runtime in use */
typedef SpineAtlas = spine.atlas.TextureAtlas;

/** Texture atlas page type of the spine runtime in use */
typedef SpineAtlasPage = spine.atlas.TextureAtlasPage;

/** Texture atlas region type of the spine runtime in use */
typedef SpineAtlasRegion = spine.atlas.TextureAtlasRegion;

/** Texture loader interface of the spine runtime in use */
typedef SpineAtlasTextureLoader = spine.atlas.TextureLoader;

/** Animation state track entry type of the spine runtime in use */
typedef SpineTrackEntry = spine.animation.TrackEntry;

/** Animation state type of the spine runtime in use */
typedef SpineAnimationState = spine.animation.AnimationState;

/** Animation state data type of the spine runtime in use */
typedef SpineAnimationStateData = spine.animation.AnimationStateData;

/** Animation type of the spine runtime in use */
typedef SpineAnimation = spine.animation.Animation;

#end

/**
 * Access to the spine runtime that works with both runtimes supported by the plugin:
 * the official spine-haxe runtime (Spine 4.3, default) and spine-hx (Spine 4.0,
 * `spine_legacy` define).
 *
 * Spine 4.3 splits bones and slots into a data object and poses (`pose`,
 * `appliedPose`...). These helpers always read the applied pose, which is the one
 * to render. Every helper is inlined: there is no cost compared to reading the
 * runtime fields directly.
 */
class SpineRuntime {

    /** `true` when the plugin uses the legacy spine-hx runtime (Spine 4.0) */
    public static inline final LEGACY:Bool = #if spine_legacy true #else false #end;

    /** Spine version of the data the runtime in use can read (major.minor) */
    public static inline final DATA_VERSION:String = #if spine_legacy '4.0' #else '4.3' #end;

/// Slots

    /** Color of the slot (applied pose) */
    public static inline function slotColor(slot:Slot):SpineColor {
        return #if spine_legacy slot.color #else slot.appliedPose.color #end;
    }

    /** Dark color (tint black) of the slot (applied pose), or `null` if the slot doesn't use tint black */
    public static inline function slotDarkColor(slot:Slot):SpineColor {
        return #if spine_legacy slot.darkColor #else slot.appliedPose.darkColor #end;
    }

    /** Current attachment of the slot (applied pose) */
    public static inline function slotAttachment(slot:Slot):Attachment {
        return #if spine_legacy slot.attachment #else slot.appliedPose.attachment #end;
    }

    /** Whether the slot data uses tint black */
    public static inline function slotDataHasDarkColor(slotData:SlotData):Bool {
        return #if spine_legacy slotData.darkColor != null #else slotData.setupPose.darkColor != null #end;
    }

    /** Whether the slot uses additive blending */
    public static inline function slotIsAdditive(slot:Slot):Bool {
        return slot.data.blendMode == spine.BlendMode.additive;
    }

/// Bones

    /** World X position of the bone (applied pose) */
    public static inline function boneWorldX(bone:Bone):Float {
        return #if spine_legacy bone.worldX #else bone.appliedPose.worldX #end;
    }

    /** World Y position of the bone (applied pose) */
    public static inline function boneWorldY(bone:Bone):Float {
        return #if spine_legacy bone.worldY #else bone.appliedPose.worldY #end;
    }

    /** `a` component of the bone world transform (applied pose) */
    public static inline function boneA(bone:Bone):Float {
        return #if spine_legacy bone.a #else bone.appliedPose.a #end;
    }

    /** `b` component of the bone world transform (applied pose) */
    public static inline function boneB(bone:Bone):Float {
        return #if spine_legacy bone.b #else bone.appliedPose.b #end;
    }

    /** `c` component of the bone world transform (applied pose) */
    public static inline function boneC(bone:Bone):Float {
        return #if spine_legacy bone.c #else bone.appliedPose.c #end;
    }

    /** `d` component of the bone world transform (applied pose) */
    public static inline function boneD(bone:Bone):Float {
        return #if spine_legacy bone.d #else bone.appliedPose.d #end;
    }

    /** Local X scale of the bone (applied pose) */
    public static inline function boneScaleX(bone:Bone):Float {
        return #if spine_legacy bone.scaleX #else bone.appliedPose.scaleX #end;
    }

    /** Local Y scale of the bone (applied pose) */
    public static inline function boneScaleY(bone:Bone):Float {
        return #if spine_legacy bone.scaleY #else bone.appliedPose.scaleY #end;
    }

    /** Whether the bone is active (bones that belong to a skin are inactive when that skin is not used) */
    public static inline function boneActive(bone:Bone):Bool {
        return bone.active;
    }

    /** Setup pose rotation of the bone data */
    public static inline function boneDataRotation(boneData:BoneData):Float {
        return #if spine_legacy boneData.getRotation() #else boneData.setupPose.rotation #end;
    }

    /** Parent of the bone data, or `null` for the root bone */
    public static inline function boneDataParent(boneData:BoneData):BoneData {
        return #if spine_legacy boneData.getParent() #else boneData.parent #end;
    }

/// Attachments

    /** Rotation of a region attachment, in degrees */
    public static inline function regionRotation(region:RegionAttachment):Float {
        return #if spine_legacy region.getRotation() #else region.rotation #end;
    }

/// Skeleton

    /** Slots in draw order (applied pose) */
    public static inline function drawOrder(skeleton:Skeleton):Array<Slot> {
        return #if spine_legacy skeleton.drawOrder #else skeleton.drawOrder.appliedPose #end;
    }

    /** Reset bones, constraints and slots to the setup pose */
    public static inline function setupPose(skeleton:Skeleton):Void {
        #if spine_legacy
        skeleton.setToSetupPose();
        #else
        skeleton.setupPose();
        #end
    }

    /** Reset slots to the setup pose */
    public static inline function setupPoseSlots(skeleton:Skeleton):Void {
        #if spine_legacy
        skeleton.setSlotsToSetupPose();
        #else
        skeleton.setupPoseSlots();
        #end
    }

    /** Change the skin of the skeleton */
    public static inline function setSkin(skeleton:Skeleton, skin:spine.Skin):Void {
        #if spine_legacy
        skeleton.setSkin(skin);
        #else
        skeleton.skin = skin;
        #end
    }

/// Animation state

    /** Track entry currently playing on the given track, or `null` */
    public static inline function currentTrack(state:SpineAnimationState, trackIndex:Int):SpineTrackEntry {
        return #if spine_legacy state.getCurrent(trackIndex) #else state.getTrack(trackIndex) #end;
    }

/// Events

    /** Name of a spine event */
    public static inline function eventName(event:spine.Event):String {
        return #if spine_legacy event.getData().name #else event.data.name #end;
    }

}
