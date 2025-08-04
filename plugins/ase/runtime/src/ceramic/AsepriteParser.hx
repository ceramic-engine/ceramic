package ceramic;

import ase.Ase;
import ase.chunks.CelChunk;
import ase.chunks.LayerChunk;
import ase.chunks.SliceChunk;
import ase.chunks.TagsChunk;
import ceramic.Shortcuts.*;
import haxe.crypto.Hmac;
import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import haxe.io.BytesInput;

using ceramic.Extensions;

/**
 * Parser for Aseprite (.ase/.aseprite) animation files.
 * 
 * This class provides utilities to parse Aseprite files and convert them into
 * formats usable by the Ceramic engine. It handles layer compositing, frame
 * extraction, texture atlas packing, and sprite sheet generation.
 * 
 * Key features:
 * - Parses all Aseprite data including frames, layers, tags, slices, and palettes
 * - Composites layers with proper blend modes and opacity
 * - Detects and deduplicates identical frames to save memory
 * - Packs frames into texture atlases for efficient rendering
 * - Generates sprite sheets for animation playback (when sprite plugin is enabled)
 * - Supports indexed color mode with palette lookups
 * - Handles premultiplied alpha for correct blending
 * 
 * The parser supports all standard Aseprite blend modes including:
 * Normal, Multiply, Screen, Overlay, Darken, Lighten, Color Dodge,
 * Color Burn, Hard Light, Soft Light, Difference, Exclusion,
 * Hue, Saturation, Color, Luminosity, Addition, Subtract, and Divide.
 * 
 * @see AsepriteData for the parsed data structure
 * @see AsepriteBlendFuncs for blend mode implementations
 */
class AsepriteParser {

    /**
     * Parses an Aseprite file and returns structured data for use in Ceramic.
     * 
     * This method processes all frames, composites layers, detects duplicates,
     * and optionally packs frames into a texture atlas.
     * 
     * @param ase The raw Aseprite file data to parse
     * @param prefix Prefix for naming texture regions in the atlas (e.g., "player")
     * @param atlasPacker Optional texture atlas packer to add frames to
     * @param singleFrame If >= 0, only parse up to this frame number (for partial loading)
     * @param premultiplyAlpha Whether to premultiply alpha for correct GPU blending (default: true)
     * @param options Optional parsing options:
     *                - layers: Array of layer names to include (null = all visible layers)
     * @return Parsed AsepriteData containing frames, tags, layers, and atlas references
     */
    public static function parseAse(ase:Ase, prefix:String, ?atlasPacker:TextureAtlasPacker, singleFrame:Int = -1, premultiplyAlpha:Bool = true, ?options:{?layers:Array<String>}):AsepriteData {

        var palette:AsepritePalette = null;
        var tags:Map<String,AsepriteTag> = new Map();
        var slices:Map<String,SliceChunk> = new Map();
        var layers:Array<LayerChunk> = [];
        var duration:Float = 0.0;
        var frames:Array<AsepriteFrame> = [];

        var filterLayers:Array<String> = options?.layers;

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
            if (singleFrame >= 0 && f > singleFrame)
                break;

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
                if (singleFrame >= 0 && i > singleFrame)
                    break;
                frames[i].tags.push(tag.name);
            }
        }

        // Prepare frame layers data structure
        var allFrameLayers:Array<Array<AsepriteFrameLayer>> = [];

        // Extract each frame's pixels,
        // and create an atlas
        for (f in 0...frames.length) {
            if (singleFrame >= 0 && f > singleFrame)
                break;

            var frame = frames[f];
            parseAseFramePixels(ase, palette, layers, frame, allFrameLayers, filterLayers);

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
                if (atlasPacker != null) {
                    atlasPacker.add(
                        prefix+'#'+f, frame.pixels, ase.width, ase.height,
                        frame.packedWidth, frame.packedHeight, frame.offsetX, frame.offsetY
                    );
                }
            }
            else if (!frame.duplicateSameOffset) {
                // Pixels duplicate, but different offsets, add a region without pixels
                if (atlasPacker != null) {
                    atlasPacker.add(
                        prefix+'#'+f, prefix+'#'+frame.duplicateOfIndex, ase.width, ase.height,
                        frame.offsetX, frame.offsetY
                    );
                }
            }
        }

        if (premultiplyAlpha) {
            for (i in 0...frames.length) {
                PremultiplyAlpha.premultiplyAlpha(frames.unsafeGet(i).pixels);
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

    /**
     * Creates a texture from a specific frame in parsed Aseprite data.
     * 
     * This method is useful when you need a standalone texture from a single frame
     * rather than using the texture atlas. It handles frame deduplication and
     * proper positioning of trimmed frames.
     * 
     * @param asepriteData The parsed Aseprite data
     * @param frame Frame index to extract (0-based)
     * @param density Texture density for high-DPI displays (default: 1)
     * @return A new Texture containing the frame's pixels, or null if frame not found
     */
    public static function parseTextureFromAsepriteData(asepriteData:AsepriteData, frame:Int, density:Float = 1):Texture {

        var asepriteFrame = asepriteData.frames[frame];
        if (asepriteFrame != null) {
            var actualFrame = asepriteFrame;
            while (actualFrame.duplicateOfIndex >= 0)
                actualFrame = asepriteData.frames[actualFrame.duplicateOfIndex];

            if (actualFrame.pixels != null) {
                if (actualFrame.packedWidth == asepriteData.ase.width &&
                    actualFrame.packedHeight == asepriteData.ase.height &&
                    asepriteFrame.offsetX == 0 && asepriteFrame.offsetY == 0) {

                    return Texture.fromPixels(
                        asepriteData.ase.width,
                        asepriteData.ase.height,
                        actualFrame.pixels, density
                    );
                }
                else {
                    var pixels = Pixels.create(
                        asepriteData.ase.width,
                        asepriteData.ase.height,
                        AlphaColor.TRANSPARENT
                    );
                    Pixels.copy(
                        actualFrame.pixels, actualFrame.packedWidth,
                        pixels, asepriteData.ase.width,
                        0, 0, actualFrame.packedWidth, actualFrame.packedHeight,
                        asepriteFrame.offsetX, asepriteFrame.offsetY
                    );
                    return Texture.fromPixels(
                        asepriteData.ase.width,
                        asepriteData.ase.height,
                        pixels, density
                    );
                }
            }
        }

        return null;

    }

    /**
     * Creates a grid texture containing multiple frames from Aseprite data.
     * 
     * This method arranges frames in a grid layout within a single texture,
     * useful for sprite sheets or tile sets that need a specific layout.
     * Frames are arranged left-to-right, top-to-bottom with configurable spacing.
     * 
     * @param asepriteData The parsed Aseprite data
     * @param frameStart First frame index to include (0-based)
     * @param frameEnd Last frame index to include (inclusive)
     * @param texWidth Width of the output texture
     * @param texHeight Height of the output texture
     * @param spacing Pixels between frames (default: 0)
     * @param padding Pixels of padding around the entire grid (default: 0)
     * @param density Texture density for high-DPI displays (default: 1)
     * @return A new Texture containing the frame grid
     * @throws String if frame size won't fit in the specified texture dimensions
     */
    public static function parseGridTextureFromAsepriteData(asepriteData:AsepriteData, frameStart:Int, frameEnd:Int, texWidth:Int, texHeight:Int, spacing:Int = 0, padding:Int = 0, density:Float = 1):Texture {

        if (asepriteData.ase.width + padding > texWidth || asepriteData.ase.height + padding > texHeight) {
            throw 'Cannot create grid texture of size $texWidth x $texHeight because ase frame size (${asepriteData.ase.width + padding} x ${asepriteData.ase.height + padding}) won\'t fit';
        }

        var gridPixels = Pixels.create(texWidth, texHeight, AlphaColor.TRANSPARENT);

        var x = padding;
        var y = padding;

        for (frame in frameStart...frameEnd+1) {
            var asepriteFrame = asepriteData.frames[frame];
            if (asepriteFrame != null) {
                var actualFrame = asepriteFrame;
                while (actualFrame.duplicateOfIndex >= 0)
                    actualFrame = asepriteData.frames[actualFrame.duplicateOfIndex];

                if (actualFrame.pixels != null) {
                    if (actualFrame.packedWidth == asepriteData.ase.width &&
                        actualFrame.packedHeight == asepriteData.ase.height &&
                        asepriteFrame.offsetX == 0 && asepriteFrame.offsetY == 0) {

                        Pixels.copy(
                            actualFrame.pixels,
                            actualFrame.packedWidth,
                            gridPixels,
                            texWidth,
                            0, 0,
                            actualFrame.packedWidth,
                            actualFrame.packedHeight,
                            x, y
                        );
                    }
                    else {
                        Pixels.copy(
                            actualFrame.pixels,
                            actualFrame.packedWidth,
                            gridPixels,
                            texWidth,
                            0, 0,
                            actualFrame.packedWidth,
                            actualFrame.packedHeight,
                            x + asepriteFrame.offsetX, y + asepriteFrame.offsetY
                        );
                    }
                }
            }

            x += asepriteData.ase.width + spacing;
            if (x + asepriteData.ase.width > texWidth) {
                x = padding;
                y += asepriteData.ase.height + spacing;
                if (y + asepriteData.ase.height > texHeight) {
                    break;
                }
            }
        }

        return Texture.fromPixels(texWidth, texHeight, gridPixels, density);

    }

    #if plugin_sprite

    /**
     * Creates a sprite sheet from parsed Aseprite data.
     * 
     * This method generates a SpriteSheet with animations based on the tags
     * defined in the Aseprite file. Each tag becomes an animation with proper
     * frame sequencing, durations, and loop settings.
     * 
     * The sprite sheet uses the texture atlas from the AsepriteData for
     * efficient rendering of animations.
     * 
     * Only available when the sprite plugin is enabled.
     * 
     * @param asepriteData The parsed Aseprite data containing frames and tags
     * @return A new SpriteSheet ready for animation playback
     */
    @:plugin('sprite')
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

    #end

    /**
     * Parses and composites pixel data for a single frame.
     * 
     * This internal method handles the complex task of:
     * - Extracting cel data from each layer
     * - Handling linked cels that reference other frames
     * - Computing the packed bounds by trimming transparent pixels
     * - Compositing layers with blend modes and opacity
     * 
     * @param ase The Aseprite file data
     * @param palette Color palette for indexed color mode
     * @param layers Array of layer definitions
     * @param frame The frame to parse pixels for
     * @param allFrameLayers Accumulated frame layer data for linked cel lookups
     * @param filterLayers Optional array of layer names to include (null = all visible)
     */
    static function parseAseFramePixels(ase:Ase, palette:AsepritePalette, layers:Array<LayerChunk>, frame:AsepriteFrame, allFrameLayers:Array<Array<AsepriteFrameLayer>>, filterLayers:Array<String>):Void {

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

                if (frameLayer != null && (
                    (filterLayers == null && (frameLayer.layer.flags & LayerFlags.Visible) == LayerFlags.Visible)) ||
                    (filterLayers != null && filterLayers.contains(frameLayer.layer.name)
                )) {
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
            if (frameLayer.pixels != null && (
                (filterLayers == null && (frameLayer.layer.flags & LayerFlags.Visible) == LayerFlags.Visible)) ||
                (filterLayers != null && filterLayers.contains(frameLayer.layer.name)
            )) {
                var frameCelChunk = frameLayer.celChunk;
                if (frameCelChunk != null) {
                    var srcX:Int = 0;
                    var srcY:Int = 0;
                    var relX:Int = frameCelChunk.xPosition - left;
                    var relY:Int = frameCelChunk.yPosition - top;
                    var celW:Int = frameCelChunk.width;
                    var celH:Int = frameCelChunk.height;

                    // Trim left
                    if (relX < 0) {
                        srcX -= relX;
                        celW += relX;
                        relX = 0;
                    }

                    // Trim top
                    if (relY < 0) {
                        srcY -= relY;
                        celH += relY;
                        relY = 0;
                    }

                    // Trim right
                    if (relX + celW > packedWidth) {
                        celW = packedWidth - relX;
                    }

                    // Trim bottom
                    if (relY + celH > packedHeight) {
                        celH = packedHeight - relY;
                    }

                    if (celW > 0 && celH > 0) {
                        blendAseFrameLayerPixels(
                            frameLayer.pixels, frameCelChunk.width,
                            frame.pixels, packedWidth,
                            srcX, srcY, celW, celH,
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

    /**
     * Extracts pixel data from a cel chunk.
     * 
     * Handles different color depths:
     * - 32-bit RGBA: Direct pixel data
     * - 16-bit Grayscale+Alpha: Converted to RGBA
     * - 8-bit Indexed: Palette lookup to RGBA
     * 
     * @param ase The Aseprite file data for color depth info
     * @param palette Color palette for indexed color mode
     * @param celChunk The cel containing compressed pixel data
     * @return RGBA pixel data as UInt8Array
     */
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