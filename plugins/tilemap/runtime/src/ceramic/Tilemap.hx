package ceramic;

using ceramic.Extensions;

class Tilemap extends Quad {

/// Properties

    public var tilemapData(default,set):TilemapData = null;
    function set_tilemapData(tilemapData:TilemapData):TilemapData {
        if (this.tilemapData == tilemapData) return tilemapData;
        this.tilemapData = tilemapData;
        contentDirty = true;
        return tilemapData;
    }

    public var tileScale(default,set):Float = 1.0;
    function set_tileScale(tileScale:Float):Float {
        if (this.tileScale == tileScale) return tileScale;
        this.tileScale = tileScale;
        contentDirty = true;
        return tileScale;
    }

    public var tileQuads(default,null):Array<Quad> = [];

/// Overrides

    override function get_width():Float {
        if (contentDirty) computeContent();
        return super.get_width();
    }

    override function get_height():Float {
        if (contentDirty) computeContent();
        return super.get_height();
    }

/// Lifecycle

    public function new() {

        super();

    } //new

/// Display

    override function computeContent() {

        if (tilemapData == null) {
            width = 0;
            height = 0;
            contentDirty = false;
            return;
        }

        computeTileQuads();

        contentDirty = false;

    } //computeContent

    function computeTileQuads() {

        var usedQuads = 0;
        var tileScale = this.tileScale;
        
        // TODO
        /*switch (tilemapData.renderOrder) {
            case RIGHT_DOWN:
            case RIGHT_UP:
            case LEFT_DOWN:
            case LEFT_UP:
        }*/

        for (l in 0...tilemapData.layers.length) {
            var layer = tilemapData.layers.unsafeGet(l);

            if (layer.visible && layer.tiles != null) {
                for (t in 0...layer.tiles.length) {
                    var tile = layer.tiles.unsafeGet(t);
                    var gid = tile.gid;
                    
                    var tileset = tilemapData.tilesetForGid(gid);

                    if (tileset != null && tileset.image != null && tileset.columns > 0) {
                        var index = gid - tileset.firstGid;

                        var quad:Quad = usedQuads < tileQuads.length ? tileQuads[usedQuads] : null;
                        if (quad == null) {
                            quad = new Quad();
                            quad.inheritAlpha = true;
                            tileQuads.push(quad);
                            add(quad);
                        }
                        usedQuads++;

                        quad.visible = true;
                        quad.texture = tileset.image.texture;
                        quad.frameX = (index % tileset.columns) * (tileset.tileWidth + tileset.margin * 2 + tileset.spacing) + tileset.margin;
                        quad.frameY = Math.floor(index / tileset.columns) * (tileset.tileHeight + tileset.margin * 2) + tileset.spacing;
                        quad.frameWidth = tileset.tileWidth;
                        quad.frameHeight = tileset.tileHeight;
                        quad.depth = l; // TODO
                        quad.x = ((t % layer.width) + layer.x) * tileset.tileWidth + layer.offsetX;
                        quad.y = (Math.floor(t / layer.width) + layer.y) * tileset.tileWidth + layer.offsetY;
                        quad.scaleX = (tile.horizontalFlip ? -1 : 1) * tileScale;
                        quad.scaleY = (tile.verticalFlip ? -1 : 1) * tileScale;
                        quad.rotation = tile.diagonalFlip ? -90 : 0; // Not sure about this, need to test

                    }

                }
            }
        }

    } //computeTileQuads

} //Tilemap
