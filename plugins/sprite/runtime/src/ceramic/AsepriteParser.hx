package ceramic;

import ase.Ase;
import ase.chunks.CelChunk;
import ase.chunks.LayerChunk;
import ase.chunks.SliceChunk;
import ase.chunks.TagsChunk;
import ceramic.AsepriteJson;
import ceramic.Shortcuts.*;
import haxe.crypto.Hmac;
import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import haxe.io.BytesInput;

using ceramic.Extensions;

/**
 * Utility class to parse sprite sheet json data exported by aseprite
 */
class AsepriteParser {

    static var didLogHashWarning:Bool = false;

    public static function isAsepriteJson(json:Dynamic):Bool {

        if (json != null && json.frames != null) {
            // Aseprite JSON
            if (Std.isOfType(json.frames, Array)) {
                return true;
            }
            else {
                if (!didLogHashWarning) {
                    didLogHashWarning = true;
                    log.warning('Aseprite JSON format with frames as hash is not supported. Please export using array.');
                }
            }
        }

        return false;

    }

    public static function parseAtlasFromJson(data:AsepriteJson):TextureAtlas {

        var page:TextureAtlasPage = new TextureAtlasPage(
            data.meta.image,
            data.meta.size.w,
            data.meta.size.h,
            NEAREST
        );

        var atlas = new TextureAtlas();
        atlas.pages.push(page);

        for (frame in data.frames) {

            var region = new TextureAtlasRegion(
                frame.filename, atlas, 0
            );

            region.x = Math.round(frame.frame.x + (frame.frame.w - frame.spriteSourceSize.w) * 0.5);
            region.y = Math.round(frame.frame.y + (frame.frame.h - frame.spriteSourceSize.h) * 0.5);
            region.originalWidth = Std.int(frame.sourceSize.w);
            region.originalHeight = Std.int(frame.sourceSize.h);
            region.width = Std.int(frame.spriteSourceSize.w);
            region.height = Std.int(frame.spriteSourceSize.h);
            region.offsetX = Std.int(frame.spriteSourceSize.x);
            region.offsetY = Std.int(frame.spriteSourceSize.y);

            region.rotateFrame = frame.rotated;
            if (region.rotateFrame) {
                region.packedWidth = region.height;
                region.packedHeight = region.width;
            } else {
                region.packedWidth = region.width;
                region.packedHeight = region.height;
            }

        }

        return atlas;

    }

    public static function parseSheetFromJson(data:AsepriteJson, atlas:TextureAtlas):SpriteSheet {

        var sheet = new SpriteSheet();

        sheet.atlas = atlas;

        var animations:Array<SpriteSheetAnimation> = [];

        for (frameTag in data.meta.frameTags) {

            var animation = new SpriteSheetAnimation();
            animation.name = frameTag.name;

            var from:Int = Std.int(frameTag.from);
            var to:Int = Std.int(frameTag.to);

            var frames:Array<SpriteSheetFrame> = [];

            inline function addFrame(index:Int) {

                var region = atlas.regions[index];
                var frame = new SpriteSheetFrame(atlas, region.name, 0, region);
                frame.duration = data.frames[index].duration * 0.001;
                frames.push(frame);

            }

            switch frameTag.direction {

                case FORWARD:
                    var i = from;
                    while (i <= to) {
                        addFrame(i);
                        i++;
                    }

                case REVERSE:
                    var i = to;
                    while (i >= from) {
                        addFrame(i);
                        i--;
                    }

                case PINGPONG:
                    var i = from;
                    while (i <= to) {
                        addFrame(i);
                        i++;
                    }
                    i = to - 1;
                    while (i > from) {
                        addFrame(i);
                        i--;
                    }
            }

            animation.frames = frames;
            animations.push(animation);
        }

        sheet.animations = animations;

        return sheet;

    }

    public static function parseAse(ase:Ase, prefix:String, ?atlasPacker:TextureAtlasPacker):AsepriteData {

        var sheet = new SpriteSheet();
        var palette:AsepritePalette = null;
        var tags:Map<String,AsepriteTag> = new Map();
        var slices:Map<String,SliceChunk> = new Map();
        var layers:Array<LayerChunk> = [];
        var duration:Float = 0.0;
        var frames:Array<AsepriteFrame> = [];

        // Just a hash key to compute hash of every frame pixels.
        // This can be anything as long as we use the same for each frame.
        var hashKey:Bytes = Bytes.ofHex('BFC5Ef3C3658436E836E89DA70186280');
        var hmac = new Hmac(SHA1);
        var nextHashIndex:Int = 0;

        // Extract general info
        var aseFrame = ase.frames[0];
        for (c in 0...aseFrame.chunks.length) {
            var chunk = aseFrame.chunks[c];
            switch chunk.header.type {
                case LAYER:
                    layers.push(cast chunk);
                case PALETTE:
                    palette = AsepritePalette.fromChunk(cast chunk);
                case TAGS:
                    var frameTags:TagsChunk = cast chunk;

                    for (frameTagData in frameTags.tags) {
                        var tag = AsepriteTag.fromChunk(frameTagData);

                        if (tags.exists(tag.name)) {
                            var num:Int = 1;
                            var newName:String = '${tag.name}_$num';
                            while (tags.exists(newName)) {
                                num++;
                                newName = '${tag.name}_$num';
                            }
                            log.warning('Duplicate "${tag.name}" tag. Rename it to "$newName"');
                            tags.set(newName, tag);
                        }
                        else {
                            tags.set(frameTagData.tagName, tag);
                        }
                    }
                case SLICE:
                    var sliceChunk:SliceChunk = cast chunk;
                    slices[sliceChunk.name] = sliceChunk;
                case _:
            }
        }

        // Extract frame data
        for (f in 0...ase.frames.length) {
            var aseFrame = ase.frames[f];
            var frame:AsepriteFrame = {
                aseFrame: aseFrame,
                index: f,
                duration: (aseFrame.header.duration / 1000.0)
            };
            duration += frame.duration;
            frames.push(frame);
        }

        // Add tags to the frames
        for (tag in tags) {
            for (i in tag.fromFrame...tag.toFrame+1) {
                frames[i].tags.push(tag.name);
            }
        }

        // Prepare frame layers data structure
        var allFrameLayers:Array<Array<AsepriteFrameLayer>> = [];

        // Create atlas packer if needed
        if (atlasPacker == null) {
            atlasPacker = new TextureAtlasPacker();
            atlasPacker.spacing = 0;
            atlasPacker.filter = NEAREST;
        }

        // Extract each frame's pixels,
        // and create an atlas
        for (f in 0...frames.length) {
            var frame = frames[f];
            parseAseFramePixels(ase, palette, layers, frame, allFrameLayers);

            // Compute hash to detect duplicate pixels
            frame.hash = hmac.make(hashKey, frame.pixels.toBytes());
            for (ff in 0...f) {
                var otherFrame = frames[ff];
                if (otherFrame.duplicateOfIndex < 0 &&
                    frame.packedWidth == otherFrame.packedWidth &&
                    frame.packedHeight == otherFrame.packedHeight &&
                    frame.hash.compare(otherFrame.hash) == 0 &&
                    frame.pixels.toBytes().compare(otherFrame.pixels.toBytes()) == 0) {

                    frame.hashIndex = otherFrame.hashIndex;
                    frame.duplicateOfIndex = ff;
                    frame.duplicateSameOffset = (frame.offsetX == otherFrame.offsetX && frame.offsetY == otherFrame.offsetY);
                    break;
                }
            }

            if (frame.duplicateOfIndex < 0) {
                // Pixels that are not duplicates, store them
                frame.hashIndex = nextHashIndex++;
                atlasPacker.add(
                    prefix+'#'+f, frame.pixels, ase.width, ase.height,
                    frame.packedWidth, frame.packedHeight, frame.offsetX, frame.offsetY
                );
            }
            else if (!frame.duplicateSameOffset) {
                // Pixels duplicate, but different offsets, add a region without pixels
                atlasPacker.add(
                    prefix+'#'+f, prefix+'#'+frame.duplicateOfIndex, ase.width, ase.height,
                    frame.offsetX, frame.offsetY
                );
            }
        }

        var asepriteData:AsepriteData = {
            ase: ase,
            palette: palette,
            tags: tags,
            slices: slices,
            layers: layers,
            duration: duration,
            frames: frames,
            atlasPacker: atlasPacker,
            prefix: prefix
        };

        return asepriteData;

    }

    public static function parseSheetFromAsepriteData(asepriteData:AsepriteData):SpriteSheet {

        var sheet = new SpriteSheet();

        var atlas = asepriteData.atlas;
        sheet.atlas = atlas;

        var animations:Array<SpriteSheetAnimation> = [];

        for (tag in asepriteData.tags) {

            var animation = new SpriteSheetAnimation();
            animation.name = tag.name;

            var frames:Array<SpriteSheetFrame> = [];

            #if !debug inline #end function addFrame(index:Int) {

                var asepriteFrame = asepriteData.frames[index];
                while (asepriteFrame.duplicateOfIndex >= 0 && asepriteFrame.duplicateSameOffset)
                    asepriteFrame = asepriteData.frames[asepriteFrame.duplicateOfIndex];
                var region = atlas.region(asepriteData.prefix + '#' + asepriteFrame.index);
                var frame = new SpriteSheetFrame(atlas, region.name, region.page, region);
                frame.duration = asepriteData.frames[index].duration;
                frames.push(frame);

            }

            switch tag.direction {

                case 0: // FORWARD
                    var i = tag.fromFrame;
                    while (i <= tag.toFrame) {
                        addFrame(i);
                        i++;
                    }

                case 1: // REVERSE
                    var i = tag.toFrame;
                    while (i >= tag.fromFrame) {
                        addFrame(i);
                        i--;
                    }

                case 2: // PINGPONG
                    var i = tag.fromFrame;
                    while (i <= tag.toFrame) {
                        addFrame(i);
                        i++;
                    }
                    i = tag.toFrame - 1;
                    while (i > tag.fromFrame) {
                        addFrame(i);
                        i--;
                    }

                case _:
            }

            animation.frames = frames;
            animations.push(animation);
        }

        sheet.animations = animations;

        return sheet;

    }

    static function parseAseFramePixels(ase:Ase, palette:AsepritePalette, layers:Array<LayerChunk>, frame:AsepriteFrame, allFrameLayers:Array<Array<AsepriteFrameLayer>>):Void {

        var packedWidth:Int = ase.width;
        var packedHeight:Int = ase.height;
        var left:Int = ase.width;
        var top:Int = ase.height;
        var right:Int = 0;
        var bottom:Int = 0;

        var frameLayers:Array<AsepriteFrameLayer> = [];
        for (l in 0...layers.length) {
            frameLayers.push({
                layer: layers[l]
            });
        }
        allFrameLayers.push(frameLayers);
        var aseFrame = frame.aseFrame;
        for (c in 0...aseFrame.chunks.length) {
            var chunk = aseFrame.chunks[c];
            // Parse all the cel chunks
            // either get new pixels or create links to
            // prior cel chunks (for linked cel animations)
            if (chunk.header.type == CEL) {
                var celChunk:CelChunk = cast chunk;
                var frameLayer = null;
                if (celChunk.celType == Linked) {
                    frameLayer = frameLayers[celChunk.layerIndex];
                    frameLayer.celChunk = allFrameLayers[celChunk.linkedFrame][celChunk.layerIndex].celChunk;
                    frameLayer.pixels = allFrameLayers[celChunk.linkedFrame][celChunk.layerIndex].pixels;
                }
                else {
                    frameLayer = frameLayers[celChunk.layerIndex];
                    frameLayer.celChunk = celChunk;
                    frameLayer.pixels = parseAseCelPixels(ase, palette, celChunk);
                }

                if (frameLayer != null && (frameLayer.layer.flags & LayerFlags.Visible) == LayerFlags.Visible) {
                    var frameCelChunk = frameLayer.celChunk;
                    if (frameCelChunk.xPosition < left)
                        left = frameCelChunk.xPosition;
                    if (frameCelChunk.yPosition < top)
                        top = frameCelChunk.yPosition;
                    if (frameCelChunk.xPosition + frameCelChunk.width > right)
                        right = frameCelChunk.xPosition + frameCelChunk.width;
                    if (frameCelChunk.yPosition + frameCelChunk.height > bottom)
                        bottom = frameCelChunk.yPosition + frameCelChunk.height;
                }
            }
        }

        // Compute packed size
        if (left < 0)
            left = 0;
        if (top < 0)
            top = 0;
        if (right > ase.width)
            right = ase.width;
        if (bottom > ase.height)
            bottom = ase.height;

        packedWidth = right - left;
        packedHeight = bottom - top;

        // Create pixels buffer
        frame.pixels = Pixels.create(packedWidth, packedHeight, AlphaColor.TRANSPARENT);
        frame.offsetX = left;
        frame.offsetY = top;
        frame.packedWidth = packedWidth;
        frame.packedHeight = packedHeight;

        // Blend each layer one by one
        // var l:Int = frameLayers.length - 1;
        // while (l >= 0) {
        var l:Int = 0;
        while (l < frameLayers.length) {
            var frameLayer = frameLayers[l];
            if (frameLayer.pixels != null && (frameLayer.layer.flags & LayerFlags.Visible) == LayerFlags.Visible) {
                var frameCelChunk = frameLayer.celChunk;
                if (frameCelChunk != null) {
                    var srcX:Int = 0;
                    var srcY:Int = 0;
                    var relX:Int = frameCelChunk.xPosition - left;
                    var relY:Int = frameCelChunk.yPosition - top;
                    var celW:Int = frameCelChunk.width;
                    var celH:Int = frameCelChunk.height;
                    if (relX < 0) {
                        srcX -= relX;
                        celW += relX;
                        relX = 0;
                    }
                    if (relY < 0) {
                        srcY -= relY;
                        celH += relY;
                        relY = 0;
                    }
                    if (celW > 0 && celH > 0) {
                        blendAseFrameLayerPixels(
                            frameLayer.pixels, frameCelChunk.width,
                            frame.pixels, packedWidth,
                            0, 0, celW, celH,
                            relX, relY, frameLayer.layer.blendMode, frameLayer.layer.opacity
                        );
                    }
                }
            }
            l++;
        }

    }

    static function blendAseFrameLayerPixels(
        srcBuffer:UInt8Array, srcBufferWidth:Int,
        dstBuffer:UInt8Array, dstBufferWidth:Int,
        srcX:Int, srcY:Int, srcWidth:Int, srcHeight:Int,
        dstX:Int, dstY:Int, blendMode:LayerBlendMode, opacity:Int
    ):Void {

        switch blendMode {
            case Normal: blendAseFrameLayerPixelsNormal(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, opacity);
            case Multiply: blendAseFrameLayerPixelsMultiply(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, opacity);
            case Screen: blendAseFrameLayerPixelsScreen(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, opacity);
            case Overlay: blendAseFrameLayerPixelsOverlay(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, opacity);
            case Darken: blendAseFrameLayerPixelsDarken(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, opacity);
            case Lighten: blendAseFrameLayerPixelsLighten(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, opacity);
            case ColorDodge: blendAseFrameLayerPixelsColorDodge(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, opacity);
            case ColorBurn: blendAseFrameLayerPixelsColorBurn(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, opacity);
            case HardLight: blendAseFrameLayerPixelsHardLight(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, opacity);
            case SoftLight: blendAseFrameLayerPixelsSoftLight(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, opacity);
            case Difference: blendAseFrameLayerPixelsDifference(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, opacity);
            case Exclusion: blendAseFrameLayerPixelsExclusion(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, opacity);
            case Hue: blendAseFrameLayerPixelsHue(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, opacity);
            case Saturation: blendAseFrameLayerPixelsSaturation(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, opacity);
            case Color: blendAseFrameLayerPixelsColor(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, opacity);
            case Luminosity: blendAseFrameLayerPixelsLuminosity(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, opacity);
            case Addition: blendAseFrameLayerPixelsAddition(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, opacity);
            case Subtract: blendAseFrameLayerPixelsSubtract(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, opacity);
            case Divide: blendAseFrameLayerPixelsDivide(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, opacity);
        }

    }

    static function blendAseFrameLayerPixelsNormal(srcBuffer:UInt8Array, srcBufferWidth:Int, dstBuffer:UInt8Array, dstBufferWidth:Int,
        srcX:Int, srcY:Int, srcWidth:Int, srcHeight:Int, dstX:Int, dstY:Int, opacity:Int):Void {
        _blendAseFrameLayerPixels(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, 0, opacity);
    }

    static function blendAseFrameLayerPixelsMultiply(srcBuffer:UInt8Array, srcBufferWidth:Int, dstBuffer:UInt8Array, dstBufferWidth:Int,
        srcX:Int, srcY:Int, srcWidth:Int, srcHeight:Int, dstX:Int, dstY:Int, opacity:Int):Void {
        _blendAseFrameLayerPixels(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, 1, opacity);
    }

    static function blendAseFrameLayerPixelsScreen(srcBuffer:UInt8Array, srcBufferWidth:Int, dstBuffer:UInt8Array, dstBufferWidth:Int,
        srcX:Int, srcY:Int, srcWidth:Int, srcHeight:Int, dstX:Int, dstY:Int, opacity:Int):Void {
        _blendAseFrameLayerPixels(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, 2, opacity);
    }

    static function blendAseFrameLayerPixelsOverlay(srcBuffer:UInt8Array, srcBufferWidth:Int, dstBuffer:UInt8Array, dstBufferWidth:Int,
        srcX:Int, srcY:Int, srcWidth:Int, srcHeight:Int, dstX:Int, dstY:Int, opacity:Int):Void {
        _blendAseFrameLayerPixels(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, 3, opacity);
    }

    static function blendAseFrameLayerPixelsDarken(srcBuffer:UInt8Array, srcBufferWidth:Int, dstBuffer:UInt8Array, dstBufferWidth:Int,
        srcX:Int, srcY:Int, srcWidth:Int, srcHeight:Int, dstX:Int, dstY:Int, opacity:Int):Void {
        _blendAseFrameLayerPixels(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, 4, opacity);
    }

    static function blendAseFrameLayerPixelsLighten(srcBuffer:UInt8Array, srcBufferWidth:Int, dstBuffer:UInt8Array, dstBufferWidth:Int,
        srcX:Int, srcY:Int, srcWidth:Int, srcHeight:Int, dstX:Int, dstY:Int, opacity:Int):Void {
        _blendAseFrameLayerPixels(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, 5, opacity);
    }

    static function blendAseFrameLayerPixelsColorDodge(srcBuffer:UInt8Array, srcBufferWidth:Int, dstBuffer:UInt8Array, dstBufferWidth:Int,
        srcX:Int, srcY:Int, srcWidth:Int, srcHeight:Int, dstX:Int, dstY:Int, opacity:Int):Void {
        _blendAseFrameLayerPixels(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, 6, opacity);
    }

    static function blendAseFrameLayerPixelsColorBurn(srcBuffer:UInt8Array, srcBufferWidth:Int, dstBuffer:UInt8Array, dstBufferWidth:Int,
        srcX:Int, srcY:Int, srcWidth:Int, srcHeight:Int, dstX:Int, dstY:Int, opacity:Int):Void {
        _blendAseFrameLayerPixels(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, 7, opacity);
    }

    static function blendAseFrameLayerPixelsHardLight(srcBuffer:UInt8Array, srcBufferWidth:Int, dstBuffer:UInt8Array, dstBufferWidth:Int,
        srcX:Int, srcY:Int, srcWidth:Int, srcHeight:Int, dstX:Int, dstY:Int, opacity:Int):Void {
        _blendAseFrameLayerPixels(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, 8, opacity);
    }

    static function blendAseFrameLayerPixelsSoftLight(srcBuffer:UInt8Array, srcBufferWidth:Int, dstBuffer:UInt8Array, dstBufferWidth:Int,
        srcX:Int, srcY:Int, srcWidth:Int, srcHeight:Int, dstX:Int, dstY:Int, opacity:Int):Void {
        _blendAseFrameLayerPixels(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, 9, opacity);
    }

    static function blendAseFrameLayerPixelsDifference(srcBuffer:UInt8Array, srcBufferWidth:Int, dstBuffer:UInt8Array, dstBufferWidth:Int,
        srcX:Int, srcY:Int, srcWidth:Int, srcHeight:Int, dstX:Int, dstY:Int, opacity:Int):Void {
        _blendAseFrameLayerPixels(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, 10, opacity);
    }

    static function blendAseFrameLayerPixelsExclusion(srcBuffer:UInt8Array, srcBufferWidth:Int, dstBuffer:UInt8Array, dstBufferWidth:Int,
        srcX:Int, srcY:Int, srcWidth:Int, srcHeight:Int, dstX:Int, dstY:Int, opacity:Int):Void {
        _blendAseFrameLayerPixels(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, 11, opacity);
    }

    static function blendAseFrameLayerPixelsHue(srcBuffer:UInt8Array, srcBufferWidth:Int, dstBuffer:UInt8Array, dstBufferWidth:Int,
        srcX:Int, srcY:Int, srcWidth:Int, srcHeight:Int, dstX:Int, dstY:Int, opacity:Int):Void {
        _blendAseFrameLayerPixels(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, 12, opacity);
    }

    static function blendAseFrameLayerPixelsSaturation(srcBuffer:UInt8Array, srcBufferWidth:Int, dstBuffer:UInt8Array, dstBufferWidth:Int,
        srcX:Int, srcY:Int, srcWidth:Int, srcHeight:Int, dstX:Int, dstY:Int, opacity:Int):Void {
        _blendAseFrameLayerPixels(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, 13, opacity);
    }

    static function blendAseFrameLayerPixelsColor(srcBuffer:UInt8Array, srcBufferWidth:Int, dstBuffer:UInt8Array, dstBufferWidth:Int,
        srcX:Int, srcY:Int, srcWidth:Int, srcHeight:Int, dstX:Int, dstY:Int, opacity:Int):Void {
        _blendAseFrameLayerPixels(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, 14, opacity);
    }

    static function blendAseFrameLayerPixelsLuminosity(srcBuffer:UInt8Array, srcBufferWidth:Int, dstBuffer:UInt8Array, dstBufferWidth:Int,
        srcX:Int, srcY:Int, srcWidth:Int, srcHeight:Int, dstX:Int, dstY:Int, opacity:Int):Void {
        _blendAseFrameLayerPixels(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, 15, opacity);
    }

    static function blendAseFrameLayerPixelsAddition(srcBuffer:UInt8Array, srcBufferWidth:Int, dstBuffer:UInt8Array, dstBufferWidth:Int,
        srcX:Int, srcY:Int, srcWidth:Int, srcHeight:Int, dstX:Int, dstY:Int, opacity:Int):Void {
        _blendAseFrameLayerPixels(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, 16, opacity);
    }

    static function blendAseFrameLayerPixelsSubtract(srcBuffer:UInt8Array, srcBufferWidth:Int, dstBuffer:UInt8Array, dstBufferWidth:Int,
        srcX:Int, srcY:Int, srcWidth:Int, srcHeight:Int, dstX:Int, dstY:Int, opacity:Int):Void {
        _blendAseFrameLayerPixels(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, 17, opacity);
    }

    static function blendAseFrameLayerPixelsDivide(srcBuffer:UInt8Array, srcBufferWidth:Int, dstBuffer:UInt8Array, dstBufferWidth:Int,
        srcX:Int, srcY:Int, srcWidth:Int, srcHeight:Int, dstX:Int, dstY:Int, opacity:Int):Void {
        _blendAseFrameLayerPixels(srcBuffer, srcBufferWidth, dstBuffer, dstBufferWidth, srcX, srcY, srcWidth, srcHeight, dstX, dstY, 18, opacity);
    }

    // Nice trick: as we never plan to use this method in a non-inline way,
    // using `extern inline overload` instead of just `inline` ensures the original
    // method is removed from code base!
    private static extern inline overload function _blendAseFrameLayerPixels(
        srcBuffer:UInt8Array, srcBufferWidth:Int,
        dstBuffer:UInt8Array, dstBufferWidth:Int,
        srcX:Int, srcY:Int, srcWidth:Int, srcHeight:Int,
        dstX:Int, dstY:Int, blendMode:Int, opacity:Int
    ):Void {

        var right:Int = srcX + srcWidth;
        var bottom:Int = srcY + srcHeight;

        var x0:Int = srcX;
        var y0:Int = srcY;
        var x1:Int = dstX;
        var y1:Int = dstY;

        while (y0 < bottom) {
            var yIndex0:Int = y0 * srcBufferWidth;
            var yIndex1:Int = y1 * dstBufferWidth;

            while (x0 < right) {
                var index0:Int = (yIndex0 + x0) * 4;
                var index1:Int = (yIndex1 + x1) * 4;

                var srcColor = AlphaColor.fromRGBA(
                    srcBuffer[index0], srcBuffer[index0+1], srcBuffer[index0+2], srcBuffer[index0+3]
                );
                var dstColor = AlphaColor.fromRGBA(
                    dstBuffer[index1], dstBuffer[index1+1], dstBuffer[index1+2], dstBuffer[index1+3]
                );

                // Because _blendAseFrameLayerPixels is inline,
                // only the condition matching our blend mode will be actually kept
                if (blendMode == 0)
                    dstColor = #if !ceramic_soft_inline inline #end AsepriteBlendFuncs.rgbaBlenderNormal(dstColor, srcColor, opacity);
                else if (blendMode == 1)
                    dstColor = #if !ceramic_soft_inline inline #end AsepriteBlendFuncs.rgbaBlenderMultiply(dstColor, srcColor, opacity);
                else if (blendMode == 2)
                    dstColor = #if !ceramic_soft_inline inline #end AsepriteBlendFuncs.rgbaBlenderScreen(dstColor, srcColor, opacity);
                else if (blendMode == 3)
                    dstColor = #if !ceramic_soft_inline inline #end AsepriteBlendFuncs.rgbaBlenderOverlay(dstColor, srcColor, opacity);
                else if (blendMode == 4)
                    dstColor = #if !ceramic_soft_inline inline #end AsepriteBlendFuncs.rgbaBlenderDarken(dstColor, srcColor, opacity);
                else if (blendMode == 5)
                    dstColor = #if !ceramic_soft_inline inline #end AsepriteBlendFuncs.rgbaBlenderLighten(dstColor, srcColor, opacity);
                else if (blendMode == 6)
                    dstColor = #if !ceramic_soft_inline inline #end AsepriteBlendFuncs.rgbaBlenderColorDodge(dstColor, srcColor, opacity);
                else if (blendMode == 7)
                    dstColor = #if !ceramic_soft_inline inline #end AsepriteBlendFuncs.rgbaBlenderColorBurn(dstColor, srcColor, opacity);
                else if (blendMode == 8)
                    dstColor = #if !ceramic_soft_inline inline #end AsepriteBlendFuncs.rgbaBlenderHardLight(dstColor, srcColor, opacity);
                else if (blendMode == 9)
                    dstColor = #if !ceramic_soft_inline inline #end AsepriteBlendFuncs.rgbaBlenderSoftLight(dstColor, srcColor, opacity);
                else if (blendMode == 10)
                    dstColor = #if !ceramic_soft_inline inline #end AsepriteBlendFuncs.rgbaBlenderDifference(dstColor, srcColor, opacity);
                else if (blendMode == 11)
                    dstColor = #if !ceramic_soft_inline inline #end AsepriteBlendFuncs.rgbaBlenderExclusion(dstColor, srcColor, opacity);
                else if (blendMode == 12)
                    dstColor = #if !ceramic_soft_inline inline #end AsepriteBlendFuncs.rgbaBlenderHslHue(dstColor, srcColor, opacity);
                else if (blendMode == 13)
                    dstColor = #if !ceramic_soft_inline inline #end AsepriteBlendFuncs.rgbaBlenderHslSaturation(dstColor, srcColor, opacity);
                else if (blendMode == 14)
                    dstColor = #if !ceramic_soft_inline inline #end AsepriteBlendFuncs.rgbaBlenderHslColor(dstColor, srcColor, opacity);
                else if (blendMode == 15)
                    dstColor = #if !ceramic_soft_inline inline #end AsepriteBlendFuncs.rgbaBlenderHslLuminosity(dstColor, srcColor, opacity);
                else if (blendMode == 16)
                    dstColor = #if !ceramic_soft_inline inline #end AsepriteBlendFuncs.rgbaBlenderAddition(dstColor, srcColor, opacity);
                else if (blendMode == 17)
                    dstColor = #if !ceramic_soft_inline inline #end AsepriteBlendFuncs.rgbaBlenderSubtract(dstColor, srcColor, opacity);
                else if (blendMode == 18)
                    dstColor = #if !ceramic_soft_inline inline #end AsepriteBlendFuncs.rgbaBlenderDivide(dstColor, srcColor, opacity);

                dstBuffer[index1] = dstColor.red;
                dstBuffer[index1+1] = dstColor.green;
                dstBuffer[index1+2] = dstColor.blue;
                dstBuffer[index1+3] = dstColor.alpha;

                // Next column
                x0++;
                x1++;
            }

            // Next row
            y0++;
            y1++;
            x0 = srcX;
            x1 = dstX;
        }

    }

    static function parseAseCelPixels(ase:Ase, palette:AsepritePalette, celChunk:CelChunk):UInt8Array {

        if (ase.header.colorDepth == 32) {
            return Pixels.fromBytes(celChunk.rawData);
        }
        else {
            var bytesInput:BytesInput = new BytesInput(celChunk.rawData);
            var bytesBuffer:BytesBuffer = new BytesBuffer();

            switch (ase.header.colorDepth) {
                case BPP16:
                    var rgba = Bytes.alloc(4);
                    for (y in 0...celChunk.height) for (x in 0...celChunk.width) {
                        var bytes = bytesInput.read(2);
                        var c = bytes.get(0);
                        rgba.set(0, c);
                        rgba.set(1, c);
                        rgba.set(2, c);
                        rgba.set(3, bytes.get(1));
                        bytesBuffer.addInt32(rgba.getInt32(0));
                    }

                case INDEXED: {
                    var paletteEntry = ase.header.paletteEntry;
                    for (y in 0...celChunk.height) for (x in 0...celChunk.width) {
                        var index:Int = bytesInput.readByte();
                        if (index == paletteEntry) {
                            bytesBuffer.addInt32(0x00000000);
                        }
                        else if (palette.entries.exists(index)) {
                            bytesBuffer.addInt32(palette.entries.get(index));
                        }
                        else {
                            bytesBuffer.addInt32(0x00000000);
                        }

                    }
                }
                case _:
            }

            bytesInput.close();
            return Pixels.fromBytes(bytesBuffer.getBytes());
        }

    }

}