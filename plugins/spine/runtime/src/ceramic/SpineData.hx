package ceramic;

import ceramic.Entity;

import spine.support.graphics.TextureAtlas;
import spine.support.files.FileHandle;
import spine.attachments.*;
import spine.*;

import ceramic.SpinePlugin;

using StringTools;
using ceramic.Extensions;

class SpineData extends Entity {

    public var skeletonData(default,null):SkeletonData;

    public var atlas(default,null):TextureAtlas;

    public var asset:SpineAsset;

    public function new(
        atlas:TextureAtlas,
        json:FileHandle,
        scale:Float = 1.0
    ) {

        super();

        this.atlas = atlas;

        var spineJson:SkeletonJson = new SkeletonJson(
            new AtlasAttachmentLoader(atlas)
        );
        spineJson.setScale(scale);

        skeletonData = spineJson.readSkeletonData(
            json
        );

    } //new

    /** Find a slot index from its name */
    public function findSlotIndex(slotName:String):Int {

        // TODO cache this info

        if (slotName == null || skeletonData == null) {
            return -1;
        }
        else {
            var allSlots = skeletonData.slots;
            for (i in 0...allSlots.length) {
                var slot = allSlots.unsafeGet(i);
                if (slot.name == slotName) {
                    return i;
                }
            }
            return -1;
        }

    } //findSlotIndex

    override public function destroy():Void {

        super.destroy();

        if (asset != null) asset.destroy();

        atlas.dispose();
        atlas = null;

    } //destroy

} //SpineData
