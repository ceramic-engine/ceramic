package ceramic;

import ceramic.Shortcuts.*;

/** Incremental texture tile packer that allows to alloc, release and reuse tiles as needed. */
class TextureTilePacker extends Entity {

    public var texture(default,null):RenderTexture;

    public var padWidth(default,null):Int;

    public var padHeight(default,null):Int;

    public var margin(default,null):Int;

    public var nextPacker:TextureTilePacker = null;

    var areas:Array<TextureTile>;

    var numCols:Int = 0;

    var numRows:Int = 0;
    
    var maxPixelTextureWidth:Int = 0;

    var maxPixelTextureHeight:Int = 0;

    public function new(autoRender:Bool, maxPixelTextureWidth:Int = -1, maxPixelTextureHeight:Int = -1, padWidth:Int = 16, padHeight:Int = 16, margin:Int = 1) {

        this.padWidth = padWidth;
        this.padHeight = padHeight;
        this.margin = margin;

        this.maxPixelTextureWidth = maxPixelTextureWidth;
        this.maxPixelTextureHeight = maxPixelTextureHeight;

        if (maxPixelTextureWidth == -1) {
            maxPixelTextureWidth = Std.int(2048 / screen.texturesDensity);
        }
        if (maxPixelTextureHeight == -1) {
            maxPixelTextureHeight = Std.int(2048 / screen.texturesDensity);
        }

        var textureWidth = Std.int(Math.min(maxPixelTextureWidth, 2048 / screen.texturesDensity));
        var textureHeight = Std.int(Math.min(maxPixelTextureHeight, 2048 / screen.texturesDensity));
        texture = new RenderTexture(textureWidth, textureHeight);

        if (autoRender) {
            texture.autoRender = true;
            texture.clearOnRender = true;
        }
        else {
            texture.autoRender = false;
            texture.clearOnRender = false;
        }

        areas = [];
        var texWidth = texture.width;
        var texHeight = texture.height;

        var x = margin;
        var y = margin;
        while (y + padHeight < texHeight) {
            while (x + padWidth < texWidth) {
                areas.push(null);
                x += padWidth + margin * 2;
                if (numRows == 0) numCols++;
            }
            x = 0;
            y += padHeight + margin * 2;
            numRows++;

        }

    } //new

    override function destroy() {

        super.destroy();

        if (nextPacker != null) {
            nextPacker.destroy();
            nextPacker = null;
        }

        texture.destroy();
        texture = null;

        areas = null;

    } //destroy

    inline function getTileAtPosition(col:Int, row:Int):TextureTile {

        return areas[row * numCols + col];

    } //getTileAtPosition

    inline function setTileAtPosition(col:Int, row:Int, tile:TextureTile):Void {

        areas[row * numCols + col] = tile;

    } //setTileAtPosition

/// Public API

    public function allocTile(width:Int, height:Int):TextureTile {

        var texWidth = texture.width;
        var texHeight = texture.height;

        var padWidthWithMargin = padWidth + margin * 2;
        var padHeightWithMargin = padHeight + margin * 2;

        var maxWidth = padWidthWithMargin * numCols - margin * 2;
        var maxHeight = padHeightWithMargin * numRows - margin * 2;

        if (width > maxWidth || height > maxHeight) {
            warning('Cannot alloc tile of $width x $height because this is bigger than $maxWidth x $maxHeight');
            return null;
        }

        // TODO proper texture filling

        var widthInCols = padWidth;
        var requiredCols = 1;
        while (widthInCols < width) {
            requiredCols++;
            widthInCols += padWidth + margin * 2; // Margin between areas of a same tile can be used
        }

        var heightInRows = padHeight;
        var requiredRows = 1;
        while (heightInRows < height) {
            requiredRows++;
            heightInRows += padHeight + margin * 2; // Margin between areas of a same tile can be used
        }

        // Find an area available
        for (row in 0...(numRows - requiredRows + 1)) {
            for (col in 0...(numCols - requiredCols + 1)) {

                var areaAvailable = true;
                for (r in row...row+requiredRows) {
                    for (c in col...col+requiredCols) {
                        if (getTileAtPosition(c, r) != null) {
                            areaAvailable = false;
                            break;
                        }
                    }
                    if (!areaAvailable) break;
                }

                if (areaAvailable) {

                    // Yay! found an available area, alloc tile!

                    var tile = new PackedTextureTile(
                        texture,
                        col * padWidthWithMargin,
                        row * padHeightWithMargin,
                        width,
                        height
                    );

                    tile.col = col;
                    tile.row = row;
                    tile.usedCols = requiredCols;
                    tile.usedRows = requiredRows;

                    // Mark every used area as used by this tile
                    for (r in row...row+requiredRows) {
                        for (c in col...col+requiredCols) {
                            setTileAtPosition(c, r, tile);
                        }
                    }

                    return tile;
                }

            }
        }

        // No space available, use another packer (with another texture)
        if (nextPacker == null) {
            nextPacker = new TextureTilePacker(texture.autoRender, maxPixelTextureWidth, maxPixelTextureHeight, padWidth, padHeight, margin);
        }
        return nextPacker.allocTile(width, height);

    } //allocTile

    public function releaseTile(tile:TextureTile):Void {

        log('release tile $tile');

        if (!(Std.is(tile, PackedTextureTile))) {
            throw 'Cannot release tile: $tile.';
        }

        var packedTile:PackedTextureTile = cast tile;

        // Find related packer (could be a chained packer)
        var packer = this;
        while (packer != null && packer.texture != packedTile.texture) {
            packer = packer.nextPacker;
        }

        if (packer == null) {
            warning('Failed to release tile: ' + packedTile + ' (it doesn\'t belong to this packer)');
            return;
        }

        app.onceUpdate(this, function(_) {
            app.onceUpdate(this, function(_) {
                var didRelease = false;
            
                // Free up packer areas
                for (r in packedTile.row...packedTile.row+packedTile.usedRows) {
                    for (c in packedTile.col...packedTile.col+packedTile.usedCols) {
                        if (packer.getTileAtPosition(c, r) == packedTile) {
                            didRelease = true;
                            packer.setTileAtPosition(c, r, null);
                        }
                    }
                }

                packedTile.texture = null;

                if (!didRelease) {
                    warning('Failed to release tile: ' + packedTile + ' (did not find it)');
                }
            });
        });

    } //releaseTile

    public function stamp(tile:TextureTile, visual:Visual, done:Void->Void):Void {

        var stampVisual = new Quad();
        stampVisual.anchor(0, 0);
        stampVisual.size(tile.frameWidth + margin * 2, tile.frameHeight + margin * 2);
        stampVisual.pos(tile.frameX - margin, tile.frameY - margin);
        stampVisual.blending = Blending.SET;
        stampVisual.inheritAlpha = false;
        stampVisual.alpha = 0;
        stampVisual.color = Color.WHITE;

        var prevParent = visual.parent;
        if (prevParent != null) {
            prevParent.remove(visual);
        }
        stampVisual.add(visual);

        var dynTexture:RenderTexture = cast tile.texture;

        dynTexture.stamp(stampVisual, function() {

            stampVisual.remove(visual);
            if (prevParent != null) {
                prevParent.add(visual);
            }
            stampVisual.destroy();

            done();

        });

    } //stamp

    public function managesTexture(texture:Texture):Bool {

        return this.texture == texture || (nextPacker != null && nextPacker.managesTexture(texture));

    } //managesTexture

} //TextureTilePacker

/** Private class used internally to store additional texture tile data. */
@:allow(ceramic.TextureTilePacker)
private class PackedTextureTile extends TextureTile {

    /** The column index of this tile */
    public var col:Int = -1;

    /** The row index of this tile */
    public var row:Int = -1;

    /** The number of column blocks used by this packed texture tile (starting from column index) */
    public var usedCols:Int = 1;

    /** The number of row blocks used by this packed texture tile (starting from row index) */
    public var usedRows:Int = 1;

    public function new(texture:Texture, frameX:Float, frameY:Float, frameWidth:Float, frameHeight:Float) {

        super(texture, frameX, frameY, frameWidth, frameHeight);

    } //new

} //PackedTextureTile
