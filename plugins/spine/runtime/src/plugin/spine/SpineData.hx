package plugin.spine;

import ceramic.Entity;

import spine.support.graphics.TextureAtlas;
import spine.support.files.FileHandle;
import spine.attachments.*;
import spine.*;

import plugin.SpinePlugin;

using StringTools;

class SpineData extends Entity {

    public var skeletonData(default,null):SkeletonData;

    public var atlas(default,null):TextureAtlas;

    public var asset:SpineAsset;

    public function new(
        atlas:TextureAtlas,
        json:FileHandle,
        scale:Float = 1.0
    ) {

        this.atlas = atlas;

        var spineJson:SkeletonJson = new SkeletonJson(
            new AtlasAttachmentLoader(atlas)
        );
        spineJson.setScale(scale);

        skeletonData = spineJson.readSkeletonData(
            json
        );

    } //new

    override public function destroy():Void {

        if (asset != null) asset.destroy();

        atlas.dispose();
        atlas = null;

    } //destroy

} //SpineData
