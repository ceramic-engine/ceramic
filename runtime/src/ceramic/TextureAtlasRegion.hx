package ceramic;

import ceramic.Shortcuts.*;

/**
 * A texture atlas region is part of a texture atlas.
 * It is also a `TextureTile` subclass so that it can be assigned
 * to `Quad`'s `tile` property.
 */
class TextureAtlasRegion extends TextureTile {

    public var name:String = null;

    public var atlas:TextureAtlas = null;

    public var page:Int = 0;

    /**
     * Width in actual pixels after rotation (if any)
     */
    public var packedWidth:Int = 0;

    /**
     * Height in actual pixels after rotation (if any)
     */
    public var packedHeight:Int = 0;

    public var x:Int = 0;

    public var y:Int = 0;

    public var width:Int = 0;

    public var height:Int = 0;

    public var offsetX:Float = 0;

    public var offsetY:Float = 0;

    /**
     * Original width, white margins included
     */
    public var originalWidth:Int = 0;

    /**
     * Original height, white margins included
     */
    public var originalHeight:Int = 0;

    public function new(name:String, atlas:TextureAtlas, page:Int) {

        this.name = name;
        this.atlas = atlas;
        this.page = page;

        var pageInfo = atlas.pages[page];
        super(
            pageInfo != null ? pageInfo.texture : null,
            0, 0, 0, 0, false, 0
        );

        atlas.regions.push(this);

    }

/// Helpers

    public function computeFrame():Void {

        var pageInfo = atlas.pages[page];
        if (pageInfo != null) {
            texture = pageInfo.texture;
            if (texture != null) {
                var pageWidth = pageInfo.width;
                var pageHeight = pageInfo.height;
                var ratioX = texture.width / pageWidth;
                var ratioY = texture.height / pageHeight;

                this.frameX = x * ratioX;
                this.frameY = y * ratioY;
                this.frameWidth = width * ratioX;
                this.frameHeight = height * ratioY;
            }
            else {
                log.warning('Failed to compute region frame because there is no texture at page $page');
            }
        }
        else {
            log.warning('Failed to compute region frame because there is no page $page');
        }

    }

    override function toString() {

        return '' + {
            name: name,
            page: page,
            texture: texture,
            packedWidth: packedWidth,
            packedHeight: packedHeight,
            originalWidth: originalWidth,
            originalHeight: originalHeight,
            width: width,
            height: height,
            offsetX: offsetX,
            offsetY: offsetY,
            frameX: frameX,
            frameY: frameY,
            frameWidth: frameWidth,
            frameHeight: frameHeight
        };

    }

}
