package plugin.spine;

import ceramic.Entity;

import spine.atlas.*;
import spine.attachments.*;
import spine.*;

import plugin.SpinePlugin;

using StringTools;

class SpineData extends Entity {

    public var skeletonData(default,null):SkeletonData;

    public var atlas(default,null):Atlas;

    public var asset:SpineAsset;

    public function new(
        atlas:Atlas,
        json:String,
        name:String,
        scale:Float = 1.0
    ) {

        this.atlas = atlas;
        this.name = name;

        var spineJson:SkeletonJson = new SkeletonJson(
            new AtlasAttachmentLoader(atlas)
        );
        spineJson.scale = scale;

        skeletonData = spineJson.readSkeletonData(
            json,
            name
        );

    } //new

    public function destroy():Void {

        if (asset != null) asset.destroy();

        atlas.dispose();
        atlas = null;

        

    } //destroy

} //SpineData
