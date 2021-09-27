package ceramic;

using ceramic.Extensions;

class TilemapLayer extends Visual {

    @event function tileQuadsChange();

    #if plugin_arcade

    /**
     * Internal flag used when walking through layers
     */
    @:allow(ceramic.Tilemap)
    public var collidable(default, null):Bool = false;

    @:allow(ceramic.Tilemap)
    function clearArcadeTiles():Void {

        for (i in 0...tileQuads.length) {
            var quad = tileQuads.unsafeGet(i);
            if (quad.arcade != null) {
                var arcade = quad.arcade;
                arcade.destroy();
                quad.arcade = null;
            }
        }

    }

    #end

    @:allow(ceramic.Tilemap)
    public var tilemap(default, null):Tilemap = null;

    public var layerData(default,set):TilemapLayerData = null;
    function set_layerData(layerData:TilemapLayerData):TilemapLayerData {
        if (this.layerData == layerData) return layerData;
        this.layerData = layerData;
        contentDirty = true;
        return layerData;
    }

    public var tileScale(default,set):Float = 1.0;
    function set_tileScale(tileScale:Float):Float {
        if (this.tileScale == tileScale) return tileScale;
        this.tileScale = tileScale;
        contentDirty = true;
        return tileScale;
    }

    /*
    public var clipTilesX(default,set):Float = -1;
    function set_clipTilesX(clipTilesX:Float):Float {
        if (this.clipTilesX == clipTilesX) return clipTilesX;
        this.clipTilesX = clipTilesX;
        contentDirty = true;
        return clipTilesX;
    }

    public var clipTilesY(default,set):Float = -1;
    function set_clipTilesY(clipTilesY:Float):Float {
        if (this.clipTilesY == clipTilesY) return clipTilesY;
        this.clipTilesY = clipTilesY;
        contentDirty = true;
        return clipTilesY;
    }

    public var clipTilesWidth(default,set):Float = -1;
    function set_clipTilesWidth(clipTilesWidth:Float):Float {
        if (this.clipTilesWidth == clipTilesWidth) return clipTilesWidth;
        this.clipTilesWidth = clipTilesWidth;
        contentDirty = true;
        return clipTilesWidth;
    }

    public var clipTilesHeight(default,set):Float = -1;
    function set_clipTilesHeight(clipTilesHeight:Float):Float {
        if (this.clipTilesHeight == clipTilesHeight) return clipTilesHeight;
        this.clipTilesHeight = clipTilesHeight;
        contentDirty = true;
        return clipTilesHeight;
    }
    */

    public var tileQuads(default,null):Array<TilemapQuad> = [];

    public var tilesColor(default,set):Color = Color.WHITE;
    function set_tilesColor(tilesColor:Color):Color {
        if (this.tilesColor != tilesColor) {
            this.tilesColor = tilesColor;
            var layerColor = layerData != null ? layerData.color : Color.WHITE;
            var mergedColor = Color.multiply(tilesColor, layerColor);
            for (i in 0...tileQuads.length) {
                var tileQuad = tileQuads.unsafeGet(i);
                tileQuad.color = mergedColor;
            }
        }
        return tilesColor;
    }

    /**
     * If `true`, removing (assign null) or replacing a tilesFilter will destroy it.
     * Note that a tilesFilter will be destroyed if assigned when
     * (parent) layer is destroyed, regardless of this setting.
     */
    public var destroyTilesFilterOnRemove:Bool = true;

    /**
     * Set to `false` if you need to assign a tiles filter but want to keep control
     * on how it is layouted (size, position...)
     */
    public var autoSizeTilesFilter:Bool = true;

    /**
     * A filter that will be applied to every tile of this layer.
     * If `autoSizeTilesFilter` is `true` (default), filter size will be set to layer content size.
     * Existing filter is automatically destroyed if `tilesFilter` is set to `null` or the layer destroyed,
     * unless you set `destroyTilesFilterOnRemove` to `false`.
     */
    public var tilesFilter(default,set):Filter = null;
    function set_tilesFilter(tilesFilter:Filter):Filter {
        if (this.tilesFilter == tilesFilter) return tilesFilter;
        if (this.tilesFilter != null) {
            var tilesFilterContent = this.tilesFilter.content;
            for (i in 0...tileQuads.length) {
                var tileQuad = tileQuads.unsafeGet(i);
                if (tileQuad.parent == tilesFilterContent) {
                    tilesFilterContent.remove(tileQuad);
                }
            }
            if (destroyTilesFilterOnRemove) {
                this.tilesFilter.destroy();
            }
            this.tilesFilter = null;
        }
        this.tilesFilter = tilesFilter;
        if (tilesFilter != null) {
            // TODO use smaller tiles filter if coupled with clip tiles
            var tilesFilterContent = tilesFilter.content;
            for (i in 0...tileQuads.length) {
                var tileQuad = tileQuads.unsafeGet(i);
                tilesFilterContent.add(tileQuad);
            }

            // TODO update these when recomputing tiles
            tilesFilter.pos(0, 0);
            if (autoSizeTilesFilter)
                tilesFilter.size(width, height);

            add(tilesFilter);
        }
        else {
            for (i in 0...tileQuads.length) {
                var tileQuad = tileQuads.unsafeGet(i);
                add(tileQuad);
            }
        }
        contentDirty = true;
        return tilesFilter;
    }

    /**
     * A mapping to retrieve an existing tileQuad from its index
     */
    var tileQuadMapping:IntIntMap = new IntIntMap();

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

    }

/// Display

    override function computeContent() {

        if (layerData == null) {
            width = 0;
            height = 0;
            contentDirty = false;
            return;
        }

        var tilemap:Tilemap = this.tilemap;
        var tilemapData:TilemapData = tilemap.tilemapData;

        computePosAndSize(tilemap, tilemapData);
        computeTileQuads(tilemap, tilemapData);

        contentDirty = false;

    }

    function computePosAndSize(tilemap:Tilemap, tilemapData:TilemapData) {

        pos(
            layerData.x * tilemapData.tileWidth + layerData.offsetX,
            layerData.y * tilemapData.tileHeight + layerData.offsetY
        );

        size(
            layerData.width * tilemapData.tileWidth,
            layerData.height * tilemapData.tileHeight
        );

        if (autoSizeTilesFilter && tilesFilter != null) {
            tilesFilter.size(
                layerData.width * tilemapData.tileWidth,
                layerData.height * tilemapData.tileHeight
            );
        }

    }

    function computeTileQuads(tilemap:Tilemap, tilemapData:TilemapData) {

        var usedQuads = 0;

        var hasClipping = false;
        var clipTilesX = tilemap.clipTilesX;
        var clipTilesY = tilemap.clipTilesY;
        var clipTilesWidth = tilemap.clipTilesWidth;
        var clipTilesHeight = tilemap.clipTilesHeight;
        if (clipTilesX != -1 || clipTilesY != -1 || clipTilesWidth != -1 || clipTilesHeight != -1) {
            hasClipping = true;
        }

        // Computing depth from render order
        var startDepthX = 0;
        var startDepthY = 0;
        var depthXStep = 1;
        var depthYStep = layerData.width;
        switch (tilemapData.renderOrder) {
            case RIGHT_DOWN:
            case RIGHT_UP:
                startDepthY = layerData.width * (layerData.height - 1);
                depthYStep = -layerData.width;
            case LEFT_DOWN:
                startDepthX = layerData.width - 1;
                depthXStep = -1;
            case LEFT_UP:
                startDepthX = layerData.width - 1;
                depthXStep = -1;
                startDepthY = layerData.width * (layerData.height - 1);
                depthYStep = -layerData.width;
        }

        var offsetX = layerData.offsetX + layerData.x * tilemapData.tileWidth;
        var offsetY = layerData.offsetY + layerData.y * tilemapData.tileHeight;

        if (layerData.visible) {
            var tiles = layerData.computedTiles;
            if (tiles == null)
                tiles = layerData.tiles;
            if (tiles != null) {
                for (t in 0...tiles.length) {
                    var tile = tiles.unsafeGet(t);

                    if (tile == 0)
                        continue;

                    var gid = tile.gid;

                    var tileset = tilemapData.tilesetForGid(gid);

                    if (tileset != null && tileset.image != null && tileset.columns > 0) {
                        var index = gid - tileset.firstGid;

                        var column = (t % layerData.width);
                        var row = Math.floor(t / layerData.width);
                        var depthExtra = 0.0;
                        var color = Color.multiply(layerData.color, tilesColor);
                        var alpha = layerData.opacity;
                        var blending = layerData.blending;
                        if (row >= layerData.height) {
                            row -= layerData.height;
                            depthExtra += 0.1;
                            blending = layerData.extraBlending;
                            alpha = layerData.extraOpacity;
                        }
                        while (row >= layerData.height) {
                            row -= layerData.height;
                            depthExtra += 0.1;
                        }

                        var tileLeft = column * tileset.tileWidth;
                        var tileTop = row * tileset.tileWidth;
                        var tileWidth = tileset.tileWidth;
                        var tileHeight = tileset.tileHeight;
                        var tileRight = tileLeft + tileWidth;
                        var tileBottom = tileTop + tileHeight;

                        var doesClip = false;
                        if (hasClipping) {
                            if (tileRight + offsetX < clipTilesX || tileBottom + offsetY < clipTilesY || tileLeft + offsetX >= clipTilesX + clipTilesWidth || tileTop + offsetY >= clipTilesY + clipTilesHeight) {
                                doesClip = true;
                            }
                        }

                        if (!doesClip) {

                            var quad:TilemapQuad = usedQuads < tileQuads.length ? tileQuads[usedQuads] : null;
                            if (quad == null) {
                                quad = new TilemapQuad();
                                quad.anchor(0.5, 0.5);
                                quad.inheritAlpha = true;
                                tileQuads.push(quad);
                                if (tilesFilter != null) {
                                    tilesFilter.content.add(quad);
                                }
                                else {
                                    add(quad);
                                }
                            }
                            usedQuads++;
                            tileQuadMapping.set(t, usedQuads);

                            quad.tilemapTile = tile;
                            quad.color = color;
                            quad.index = t;
                            quad.column = column;
                            quad.row = row;
                            quad.alpha = alpha;
                            quad.blending = blending;
                            quad.visible = true;
                            quad.texture = tileset.image.texture;
                            quad.frameX = (index % tileset.columns) * (tileset.tileWidth + tileset.margin * 2 + tileset.spacing) + tileset.margin;
                            quad.frameY = Math.floor(index / tileset.columns) * (tileset.tileHeight + tileset.margin * 2) + tileset.spacing;
                            quad.frameWidth = tileset.tileWidth;
                            quad.frameHeight = tileset.tileHeight;
                            quad.depth = startDepthX + column * depthXStep + startDepthY + row * depthYStep + depthExtra;
                            quad.x = tileWidth * 0.5 + tileLeft;
                            quad.y = tileHeight * 0.5 + tileTop;

                            if (tile.diagonalFlip) {

                                if (tile.verticalFlip)
                                    quad.scaleX = -1.0 * tileScale;
                                else
                                    quad.scaleX = tileScale;

                                if (tile.horizontalFlip)
                                    quad.scaleY = tileScale;
                                else
                                    quad.scaleY = -1.0 * tileScale;

                                quad.rotation = 90;
                            }
                            else {

                                if (tile.horizontalFlip)
                                    quad.scaleX = -1.0 * tileScale;
                                else
                                    quad.scaleX = tileScale;

                                if (tile.verticalFlip)
                                    quad.scaleY = -1.0 * tileScale;
                                else
                                    quad.scaleY = tileScale;

                                quad.rotation = 0;
                            }
                        }
                        else {
                            tileQuadMapping.set(t, 0);
                        }

                    }

                }
            }
        }

        // Remove unused quads
        while (usedQuads < tileQuads.length) {
            // TODO find a way to recycle this quads on the whole tilemap
            var quad = tileQuads.pop();
            quad.destroy();
        }

        emitTileQuadsChange();

    }

/// Helpers

    public function tileQuadByColumnAndRow(column:Int, row:Int):TilemapQuad {

        var index = row * layerData.width + column;
        return inline tileQuadByIndex(index);

    }

    public function tileQuadByIndex(index:Int):TilemapQuad {

        var arrayIndex = tileQuadMapping.get(index);
        return arrayIndex != -1 ? tileQuads[arrayIndex - 1] : null;

    }

    /**
     * Retrieve surrounding tile quads (that could collide within the given area).
     * The area is relative to this layer and does not take into account any offset or layer position.
     * @param left
     * @param top
     * @param right
     * @param bottom
     * @param result
     * @return Array<TilemapQuad>
     */
    public function surroundingTileQuads(left:Float, top:Float, right:Float, bottom:Float, ?result:Array<TilemapQuad>):Array<TilemapQuad> {

        if (result == null) {
            result = [];
        }

        if (parent != null) {

            var tilemap:Tilemap = this.tilemap;
            var tilemapData:TilemapData = tilemap.tilemapData;
            var tileWidth = tilemapData.tileWidth;
            var tileHeight = tilemapData.tileHeight;

            var minColumn = Math.floor(left / tileWidth);
            var maxColumn = Math.ceil(right / tileWidth);
            var minRow = Math.floor(top / tileHeight);
            var maxRow = Math.ceil(bottom / tileHeight);

            //trace('surrounding minColumn=$minColumn maxColumn=$maxColumn minRow=$minRow maxRow=$maxRow');

            var column = minColumn;
            while (column <= maxColumn) {
                var row = minRow;
                while (row <= maxRow) {
                    var tileQuad = inline tileQuadByColumnAndRow(column, row);
                    //trace('$column,$row -> $tileQuad');
                    if (tileQuad != null) {
                        result.push(tileQuad);
                    }
                    row++;
                }
                column++;
            }
        }

        return result;

    }

}
