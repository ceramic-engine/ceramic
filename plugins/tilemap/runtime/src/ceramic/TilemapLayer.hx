package ceramic;

using ceramic.Extensions;

/**
 * Visual representation of a single layer within a tilemap.
 *
 * A TilemapLayer renders tiles from a TilemapLayerData structure, handling tile placement,
 * clipping, rendering order, and optional collision detection. Each layer consists of a grid
 * of TilemapQuad instances that display individual tiles from the tilemap's tilesets.
 *
 * ## Features
 *
 * - **Tile Rendering**: Automatically creates and manages TilemapQuad instances for visible tiles
 * - **Clipping Support**: Can render only a subset of tiles based on clip bounds
 * - **Render Order**: Respects the tilemap's render order (RIGHT_DOWN, LEFT_UP, etc.)
 * - **Tile Filtering**: Supports applying visual filters to all tiles in the layer
 * - **Collision Detection**: When using the arcade physics plugin, supports tile-based collisions
 * - **Tile Transformations**: Handles horizontal/vertical/diagonal flipping of tiles
 *
 * ## Usage Example
 *
 * ```haxe
 * // Layers are typically created automatically by Tilemap
 * var tilemap = new Tilemap();
 * tilemap.tilemapData = myTilemapData;
 *
 * // Access a specific layer
 * var layer = tilemap.layer('collision');
 *
 * // Apply a filter to all tiles in the layer
 * var blur = new Filter();
 * blur.shader = assets.shader('blur');
 * layer.tilesFilter = blur;
 *
 * // Configure collision (requires arcade plugin)
 * layer.checkCollision(true, true); // Enable up/down and left/right collisions
 * ```
 *
 * @see Tilemap
 * @see TilemapLayerData
 * @see TilemapQuad
 */
class TilemapLayer extends Visual {

    /**
     * Event emitted when the tile quads array changes.
     * This happens when tiles are added, removed, or when the layer is re-rendered.
     */
    @event function tileQuadsChange();

    /**
     * Event emitted when the tile meshes change.
     * This happens when tiles are rendered using meshes instead of quads.
     */
    @event function tileMeshesChange();

    #if plugin_arcade

    /**
     * Shorthand to set `checkCollisionUp`, `checkCollisionRight`, `checkCollisionDown`, `checkCollisionLeft`
     */
    @:plugin('arcade')
    public extern inline overload function checkCollision(upDown:Bool, rightLeft:Bool) {
        _checkCollision(upDown, rightLeft, upDown, rightLeft);
    }

    /**
     * Shorthand to set `checkCollisionUp`, `checkCollisionRight`, `checkCollisionDown`, `checkCollisionLeft`
     */
    @:plugin('arcade')
    public extern inline overload function checkCollision(up:Bool, right:Bool, down:Bool, left:Bool) {
        _checkCollision(up, right, down, left);
    }

    @:plugin('arcade')
    private function _checkCollision(up:Bool, right:Bool, down:Bool, left:Bool) {
        checkCollisionUp = up;
        checkCollisionRight = right;
        checkCollisionDown = down;
        checkCollisionLeft = left;
    }

    /**
     * If this layer is collidable, this determines if it will collide `up`.
     * (when a body is going `downward` torward the tile)
     */
    @:plugin('arcade')
    public var checkCollisionUp:Bool = true;

    /**
     * If this layer is collidable, this determines if it will collide `down`.
     * (when a body is going `upward` toward a tile)
     */
    @:plugin('arcade')
    public var checkCollisionDown:Bool = true;

    /**
     * If this layer is collidable, this determines if it will collide `left`.
     * (when a body is going `rightward` toward the tile)
     */
    @:plugin('arcade')
    public var checkCollisionLeft:Bool = true;

    /**
     * If this layer is collidable, this determines if it will collide `right`.
     * (when a body is going `leftward` toward the tile)
     */
    @:plugin('arcade')
    public var checkCollisionRight:Bool = true;

    /**
     * If this layer is collidable, this determines if it will collide
     * using `tiles` or `computedTiles`
     */
    @:plugin('arcade')
    public var checkCollisionWithComputedTiles:Bool = false;

    /**
     * If this layer is collidable, it collides with any tiles
     * that have a value != 0, unless `checkCollisionValues` is provided.
     * In that case, it will collide when matching any value of the array.
     */
    @:plugin('arcade')
    public var checkCollisionValues:Array<Int> = null;

    /**
     * Internal flag used when walking through layers
     */
    @:allow(ceramic.Tilemap)
    @:plugin('arcade')
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

    /**
     * The parent tilemap that owns this layer.
     * Set automatically when the layer is created by a Tilemap.
     */
    @:allow(ceramic.Tilemap)
    public var tilemap(default, null):Tilemap = null;

    /**
     * The layer data that defines the tiles and properties for this layer.
     * Changing this will trigger a complete re-render of the layer.
     */
    public var layerData(default,set):TilemapLayerData = null;
    function set_layerData(layerData:TilemapLayerData):TilemapLayerData {
        if (this.layerData == layerData) return layerData;
        this.layerData = layerData;
        contentDirty = true;
        return layerData;
    }

    /**
     * Scale factor applied to all tiles in this layer.
     * Default is 1.0 (no scaling). Useful for creating zoom effects or different tile sizes.
     */
    public var tileScale(default,set):Float = 1.0;
    function set_tileScale(tileScale:Float):Float {
        if (this.tileScale == tileScale) return tileScale;
        this.tileScale = tileScale;
        contentDirty = true;
        return tileScale;
    }

    /**
     * Array of TilemapQuad instances representing visible tiles in this layer.
     * This array is automatically managed and updated when the layer re-renders.
     * Use `tileQuadByIndex()` or `tileQuadByColumnAndRow()` to access specific tiles.
     */
    public var tileQuads(default,null):Array<TilemapQuad> = [];

    /**
     * Color tint applied to all tiles in this layer.
     * This is multiplied with the layer's base color from layerData.
     * Default is WHITE (no tint).
     */
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
            if (tileMeshes != null) {
                for (i in 0...tileMeshes.length) {
                    var tileMesh = tileMeshes.unsafeGet(i);
                    if (tileMesh.parent == tilesFilterContent) {
                        tilesFilterContent.remove(tileMesh);
                    }
                }
            }
            if (destroyTilesFilterOnRemove) {
                this.tilesFilter.destroy();
            }
            else if (this.tilesFilter.parent == this) {
                remove(this.tilesFilter);
            }
            this.tilesFilter = null;
        }
        this.tilesFilter = tilesFilter;
        if (tilesFilter != null) {

            var tilesFilterContent = tilesFilter.content;
            for (i in 0...tileQuads.length) {
                var tileQuad = tileQuads.unsafeGet(i);
                tilesFilterContent.add(tileQuad);
            }
            if (tileMeshes != null) {
                for (i in 0...tileMeshes.length) {
                    var tileMesh = tileMeshes.unsafeGet(i);
                    tilesFilterContent.add(tileMesh);
                }
            }

            add(tilesFilter);
        }
        else {
            for (i in 0...tileQuads.length) {
                var tileQuad = tileQuads.unsafeGet(i);
                add(tileQuad);
            }
            if (tileMeshes != null) {
                for (i in 0...tileMeshes.length) {
                    var tileMesh = tileMeshes.unsafeGet(i);
                    add(tileMesh);
                }
            }
        }
        contentDirty = true;
        return tilesFilter;
    }

    /**
     * Set this tilemap's render type (`QUAD` (default), `MESH` or `NONE`)
     */
    public var renderType(default,set):TilemapRenderType = QUAD;
    function set_renderType(renderType:TilemapRenderType):TilemapRenderType {
        if (this.renderType == renderType) return renderType;
        this.renderType = renderType;
        contentDirty = true;
        return renderType;
    }

    /**
     * Array of Mesh instances (one per texture) used to render tiles when renderType is MESH.
     * These are reused across re-renders to avoid allocation overhead.
     * Read-only access from outside the class.
     */
    public var tileMeshes(default, null):Array<TilemapMesh> = null;

    /**
     * Internal mapping to retrieve an existing tileQuad from its tile index.
     * Maps from tile index to array position in tileQuads (1-based).
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

    /**
     * Computes the visual content of this layer based on the current layer data.
     * This method is called automatically when contentDirty is true.
     * It calculates layer dimensions and generates/updates all tile quads.
     */
    override function computeContent() {

        if (layerData == null) {
            width = 0;
            height = 0;
            contentDirty = false;
            return;
        }

        var tilemap:Tilemap = this.tilemap;
        var tilemapData:TilemapData = tilemap.tilemapData;

        computePosAndSize();

        final layerData = this.layerData;
        final hasTiles = layerData != null && layerData.shouldRenderTiles && layerData.hasTiles;
        switch renderType {
            case MESH if (hasTiles):
                clearQuads();
                computeTileMeshes(tilemap, tilemapData);
            case QUAD if (hasTiles):
                clearMeshes();
                computeTileQuads(tilemap, tilemapData);
            case NONE | _:
                clearQuads();
                clearMeshes();
        }

        contentDirty = false;

    }

    inline function clearQuads() {

        // Clear existing tile quads if any
        while (tileQuads.length > 0) {
            var quad = tileQuads.pop();
            quad.recycle();
        }

    }

    inline function clearMeshes() {

        // Clear existing tile meshes if any
        if (tileMeshes != null) {
            for (i in 0...tileMeshes.length) {
                final mesh = tileMeshes.pop();
                mesh.recycle();
            }
        }

    }

    /**
     * Computes and sets the position and size of this layer based on layer data.
     * Takes into account tile dimensions and layer offsets.
     */
    function computePosAndSize() {

        var layerData = this.layerData;

        pos(
            layerData.x * layerData.tileWidth + layerData.offsetX,
            layerData.y * layerData.tileHeight + layerData.offsetY
        );

        size(
            layerData.columns * layerData.tileWidth,
            layerData.rows * layerData.tileHeight
        );

    }

    /**
     * Generates and updates TilemapQuad instances for all visible tiles in this layer.
     * Handles tile clipping, render order, transformations, and pooling of quad instances.
     * @param tilemap The parent tilemap
     * @param tilemapData The tilemap data containing tileset information
     */
    function computeTileQuads(tilemap:Tilemap, tilemapData:TilemapData) {

        var usedQuads = 0;
        var roundTilesTranslation = tilemap.roundTilesTranslation;
        var layerData = this.layerData;

        var width = _width;
        var height = _height;
        var layerColumns = layerData.columns;
        var layerRows = layerData.rows;

        var hasClipping = false;
        var clipTilesX = tilemap.clipTilesX;
        var clipTilesY = tilemap.clipTilesY;
        var clipTilesWidth = tilemap.clipTilesWidth;
        var clipTilesHeight = tilemap.clipTilesHeight;
        if (clipTilesX != -1 || clipTilesY != -1 || clipTilesWidth != -1 || clipTilesHeight != -1) {
            hasClipping = true;
        }

        var offsetX = layerData.offsetX + layerData.x * layerData.tileWidth;
        var offsetY = layerData.offsetY + layerData.y * layerData.tileHeight;

        var filterX:Float = 0.0;
        var filterY:Float = 0.0;
        if (tilesFilter != null) {
            var filterWidth = width;
            var filterHeight = height;
            if (hasClipping) {
                filterX = Math.floor(clipTilesX / layerData.tileWidth) * layerData.tileWidth - offsetX;
                filterY = Math.floor(clipTilesY / layerData.tileHeight) * layerData.tileHeight - offsetY;
                tilesFilter.pos(
                    filterX,
                    filterY
                );
                filterWidth = Math.ceil(clipTilesWidth / layerData.tileWidth) * layerData.tileWidth + layerData.tileWidth;
                filterHeight = Math.ceil(clipTilesHeight / layerData.tileHeight) * layerData.tileHeight + layerData.tileHeight;
            }
            else {
                tilesFilter.pos(0, 0);
            }
            if (autoSizeTilesFilter && filterWidth > 0 && filterHeight > 0) {
                tilesFilter.size(filterWidth, filterHeight);
            }
        }

        if (layerData.visible) {

            // Computing depth from render order
            var startDepthX = 0;
            var startDepthY = 0;
            var depthXStep = 1;
            var depthYStep = layerColumns;
            switch (tilemapData.renderOrder) {
                case RIGHT_DOWN:
                case RIGHT_UP:
                    startDepthY = layerColumns * (layerRows - 1);
                    depthYStep = -layerColumns;
                case LEFT_DOWN:
                    startDepthX = layerColumns - 1;
                    depthXStep = -1;
                case LEFT_UP:
                    startDepthX = layerColumns - 1;
                    depthXStep = -1;
                    startDepthY = layerColumns * (layerRows - 1);
                    depthYStep = -layerColumns;
            }

            var tiles = layerData.computedTiles;
            var tilesAlpha = layerData.computedTilesAlpha;
            var tilesOffsetX = layerData.computedTilesOffsetX;
            var tilesOffsetY = layerData.computedTilesOffsetY;
            if (tiles == null) {
                tiles = layerData.tiles;
                tilesAlpha = layerData.tilesAlpha;
                tilesOffsetX = layerData.tilesOffsetX;
                tilesOffsetY = layerData.tilesOffsetY;
            }
            if (tiles != null) {

                var minColumn = 0;
                var maxColumn = layerColumns - 1;
                var minRow = 0;
                var maxRow = layerRows - 1;
                var tilesPerLayer = layerColumns * layerRows;

                if (hasClipping) {
                    minColumn = Math.floor((clipTilesX - offsetX) / layerData.tileWidth);
                    maxColumn = Math.ceil((clipTilesX + clipTilesWidth - offsetX) / layerData.tileWidth);
                    minRow = Math.floor((clipTilesY - offsetY) / layerData.tileHeight);
                    maxRow = Math.ceil((clipTilesY + clipTilesHeight - offsetY) / layerData.tileHeight);
                }

                var numTiles = tiles.length;
                var c = minColumn;
                while (c <= maxColumn) {
                    var r = minRow;
                    while (r <= maxRow) {
                        var t = r * layerColumns + c;

                        if (t < 0 || t >= numTiles) {
                            r++;
                            continue;
                        }

                        while (t < numTiles) {

                            var tile = tiles.unsafeGet(t);

                            if (tile == 0) {
                                t += tilesPerLayer;
                                continue;
                            }

                            var gid = tile.gid;

                            var tileset = tilemapData.tilesetForGid(gid);

                            if (tileset != null && tileset.image != null && tileset.columns > 0) {
                                var index = gid - tileset.firstGid;

                                var column = (t % layerColumns);
                                var row = Math.floor(t / layerColumns);
                                var depthExtra = 0.0;
                                var color = Color.multiply(layerData.color, tilesColor);
                                var alpha = layerData.opacity;
                                var blending = layerData.blending;
                                if (row >= layerRows) {
                                    row -= layerRows;
                                    depthExtra += 0.1;
                                    blending = layerData.extraBlending;
                                    alpha = layerData.extraOpacity;
                                }
                                while (row >= layerRows) {
                                    row -= layerRows;
                                    depthExtra += 0.1;
                                }
                                if (tilesAlpha != null) {
                                    alpha *= tilesAlpha.unsafeGet(t);
                                }

                                var tileLeft = column * tileset.tileWidth;
                                if (tilesOffsetX != null) {
                                    tileLeft += tilesOffsetX.unsafeGet(t);
                                }

                                var tileTop = row * tileset.tileWidth;
                                if (tilesOffsetY != null) {
                                    tileTop += tilesOffsetY.unsafeGet(t);
                                }

                                var tileWidth = tileset.tileWidth;
                                var tileHeight = tileset.tileHeight;

                                var quad:TilemapQuad = usedQuads < tileQuads.length ? tileQuads[usedQuads] : null;
                                if (quad == null) {
                                    quad = TilemapQuad.get();
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

                                if (quad.index != -1 && quad.index != t && tileQuadMapping.get(quad.index) == usedQuads) {
                                    tileQuadMapping.set(quad.index, 0);
                                }
                                tileQuadMapping.set(t, usedQuads);

                                quad.tilemapTile = tile;
                                quad.roundTranslation = roundTilesTranslation;
                                quad.color = color;
                                quad.index = t;
                                quad.column = column;
                                quad.row = row;
                                quad.alpha = alpha;
                                quad.blending = blending;
                                quad.visible = true;
                                quad.texture = tileset.image.texture;
                                quad.frameX = (index % tileset.columns) * (tileset.tileWidth + tileset.margin * 2 + tileset.spacing) + tileset.margin;
                                quad.frameY = Math.floor(index / tileset.columns) * (tileset.tileHeight + tileset.margin * 2 + tileset.spacing) + tileset.margin;
                                quad.frameWidth = tileset.tileWidth;
                                quad.frameHeight = tileset.tileHeight;
                                quad.depth = startDepthX + column * depthXStep + startDepthY + row * depthYStep + depthExtra;
                                quad.x = tileWidth * 0.5 + tileLeft - filterX;
                                quad.y = tileHeight * 0.5 + tileTop - filterY;

                                if (tile.diagonalFlip) {

                                    if (tile.verticalFlip)
                                        quad.scaleX = -1.0 * tileScale;
                                    else
                                        quad.scaleX = tileScale;

                                    if (tile.horizontalFlip)
                                        quad.scaleY = tileScale;
                                    else
                                        quad.scaleY = -1.0 * tileScale;

                                    quad.rotateFrame = true;
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

                                    quad.rotateFrame = false;
                                }

                            }

                            t += tilesPerLayer;
                        }

                        r++;
                    }
                    c++;
                }
            }
        }

        // Remove unused quads
        while (usedQuads < tileQuads.length) {
            var quad = tileQuads.pop();
            quad.recycle();
        }

        emitTileQuadsChange();

    }

    /**
     * Generates and updates Mesh instances (one per texture) for all visible tiles in this layer.
     * This is more memory-efficient than using individual quads for large tilemaps.
     * @param tilemap The parent tilemap
     * @param tilemapData The tilemap data containing tileset information
     */
    function computeTileMeshes(tilemap:Tilemap, tilemapData:TilemapData) {

        var layerData = this.layerData;

        // Initialize tile meshes if needed
        if (tileMeshes == null) {
            tileMeshes = [];
        }

        // Start counting used meshes
        var usedMeshes:Int = 0;

        var roundTilesTranslation = tilemap.roundTilesTranslation;
        var width = _width;
        var height = _height;
        var layerColumns = layerData.columns;
        var layerRows = layerData.rows;

        var hasClipping = false;
        var clipTilesX = tilemap.clipTilesX;
        var clipTilesY = tilemap.clipTilesY;
        var clipTilesWidth = tilemap.clipTilesWidth;
        var clipTilesHeight = tilemap.clipTilesHeight;
        if (clipTilesX != -1 || clipTilesY != -1 || clipTilesWidth != -1 || clipTilesHeight != -1) {
            hasClipping = true;
        }

        var offsetX = layerData.offsetX + layerData.x * layerData.tileWidth;
        var offsetY = layerData.offsetY + layerData.y * layerData.tileHeight;

        // Setup filter position
        var filterX:Float = 0.0;
        var filterY:Float = 0.0;
        if (tilesFilter != null) {
            var filterWidth = width;
            var filterHeight = height;
            if (hasClipping) {
                filterX = Math.floor(clipTilesX / layerData.tileWidth) * layerData.tileWidth - offsetX;
                filterY = Math.floor(clipTilesY / layerData.tileHeight) * layerData.tileHeight - offsetY;
                tilesFilter.pos(filterX, filterY);
                filterWidth = Math.ceil(clipTilesWidth / layerData.tileWidth) * layerData.tileWidth + layerData.tileWidth;
                filterHeight = Math.ceil(clipTilesHeight / layerData.tileHeight) * layerData.tileHeight + layerData.tileHeight;
            }
            else {
                tilesFilter.pos(0, 0);
            }
            if (autoSizeTilesFilter && filterWidth > 0 && filterHeight > 0) {
                tilesFilter.size(filterWidth, filterHeight);
            }
        }

        if (layerData.visible) {

            var tiles = layerData.computedTiles;
            var tilesAlpha = layerData.computedTilesAlpha;
            var tilesOffsetX = layerData.computedTilesOffsetX;
            var tilesOffsetY = layerData.computedTilesOffsetY;
            if (tiles == null) {
                tiles = layerData.tiles;
                tilesAlpha = layerData.tilesAlpha;
                tilesOffsetX = layerData.tilesOffsetX;
                tilesOffsetY = layerData.tilesOffsetY;
            }

            if (tiles != null) {

                var minColumn = 0;
                var maxColumn = layerColumns - 1;
                var minRow = 0;
                var maxRow = layerRows - 1;
                var tilesPerLayer = layerColumns * layerRows;
                var numTiles = tiles.length;

                if (hasClipping) {
                    minColumn = Math.floor((clipTilesX - offsetX) / layerData.tileWidth);
                    maxColumn = Math.ceil((clipTilesX + clipTilesWidth - offsetX) / layerData.tileWidth);
                    minRow = Math.floor((clipTilesY - offsetY) / layerData.tileHeight);
                    maxRow = Math.ceil((clipTilesY + clipTilesHeight - offsetY) / layerData.tileHeight);
                }

                var layerColor = Color.multiply(layerData.color, tilesColor);
                var layerAlpha = layerData.opacity;

                // Process all tiles and create/populate meshes as needed
                var currentMesh:TilemapMesh = null;
                var c = minColumn;
                while (c <= maxColumn) {
                    var r = minRow;
                    while (r <= maxRow) {
                        var t = r * layerColumns + c;

                        if (t >= 0 && t < numTiles) {
                            while (t < numTiles) {
                                var tile = tiles.unsafeGet(t);

                                if (tile != 0) {
                                    var gid = tile.gid;
                                    var tileset = tilemapData.tilesetForGid(gid);

                                    if (tileset != null && tileset.image != null && tileset.columns > 0) {
                                        var texture = tileset.image.texture;
                                        if (texture != null) {
                                            var textureIndex = texture.index;

                                            var index = gid - tileset.firstGid;

                                            var column = (t % layerColumns);
                                            var row = Math.floor(t / layerColumns);
                                            var alpha = layerAlpha;
                                            var layerIndex = 0;
                                            var depthExtra = 0.0;
                                            var blending = layerData.blending;

                                            if (row >= layerRows) {
                                                layerIndex = Math.floor(row / layerRows);
                                                row -= layerRows * layerIndex;
                                                depthExtra = layerIndex * 0.1;
                                                blending = layerData.extraBlending;
                                                alpha = layerData.extraOpacity;
                                            }
                                            while (row >= layerRows) {
                                                row -= layerRows;
                                                depthExtra += 0.1;
                                            }

                                            // Create a combined key from texture index and layer index
                                            // We use textureIndex * 1000 + layerIndex to create a unique key
                                            var mesh:TilemapMesh = null;
                                            if (currentMesh != null && textureIndex == currentMesh.textureIndex && layerIndex == currentMesh.layerIndex) {
                                                mesh = currentMesh;
                                            }
                                            else {
                                                for (m in 0...usedMeshes) {
                                                    final aMesh = tileMeshes.unsafeGet(m);
                                                    if (aMesh.layerIndex == layerIndex && aMesh.textureIndex == textureIndex) {
                                                        mesh = aMesh;
                                                        break;
                                                    }
                                                }
                                                if (mesh == null) {
                                                    mesh = usedMeshes < tileMeshes.length ? tileMeshes[usedMeshes] : null;

                                                    if (mesh == null) {
                                                        mesh = TilemapMesh.get();
                                                        mesh.inheritAlpha = true;
                                                        mesh.anchor(0, 0);
                                                        if (mesh.vertices == null) mesh.vertices = [];
                                                        if (mesh.uvs == null) mesh.uvs = [];
                                                        if (mesh.indices == null) mesh.indices = [];
                                                        if (mesh.colors == null) mesh.colors = [];
                                                        tileMeshes.push(mesh);
                                                        if (tilesFilter != null) {
                                                            tilesFilter.content.add(mesh);
                                                        }
                                                        else {
                                                            add(mesh);
                                                        }
                                                    }
                                                    usedMeshes++;

                                                    // Created or retrieved a reusable mesh, configure it
                                                    mesh.texture = texture;
                                                    mesh.colorMapping = MeshColorMapping.VERTICES;
                                                    mesh.active = true;
                                                    mesh.roundTranslation = roundTilesTranslation;
                                                    mesh.blending = blending;
                                                    mesh.depth = depthExtra;
                                                    mesh.layerIndex = layerIndex;
                                                    mesh.textureIndex = textureIndex;
                                                    mesh.nextVertexIndice = 0;
                                                    mesh.nextIndexIndice = 0;
                                                    mesh.nextColorIndice = 0;
                                                    mesh.nextQuadIndice = 0;
                                                }
                                            }

                                            var vertexIndex = mesh.nextVertexIndice;
                                            var indexIndex = mesh.nextIndexIndice;
                                            var colorIndex = mesh.nextColorIndice;
                                            var quadIndex = mesh.nextQuadIndice;

                                            if (tilesAlpha != null) {
                                                alpha *= tilesAlpha.unsafeGet(t);
                                            }

                                            var tileLeft = column * tileset.tileWidth;
                                            if (tilesOffsetX != null) {
                                                tileLeft += tilesOffsetX.unsafeGet(t);
                                            }

                                            var tileTop = row * tileset.tileHeight;
                                            if (tilesOffsetY != null) {
                                                tileTop += tilesOffsetY.unsafeGet(t);
                                            }

                                            var tileWidth = tileset.tileWidth;
                                            var tileHeight = tileset.tileHeight;

                                            // Calculate texture coordinates
                                            var frameX = (index % tileset.columns) * (tileset.tileWidth + tileset.margin * 2 + tileset.spacing) + tileset.margin;
                                            var frameY = Math.floor(index / tileset.columns) * (tileset.tileHeight + tileset.margin * 2 + tileset.spacing) + tileset.margin;

                                            var textureWidth = tileset.image.width;
                                            var textureHeight = tileset.image.height;

                                            var u1 = frameX / textureWidth;
                                            var v1 = frameY / textureHeight;
                                            var u2 = (frameX + tileset.tileWidth) / textureWidth;
                                            var v2 = (frameY + tileset.tileHeight) / textureHeight;

                                            // Create base UV coordinates for top-left, top-right, bottom-right, bottom-left
                                            var tlU = u1;
                                            var tlV = v1;
                                            var trU = u2;
                                            var trV = v1;
                                            var brU = u2;
                                            var brV = v2;
                                            var blU = u1;
                                            var blV = v2;

                                            // Handle flipping and rotation
                                            if (tile.diagonalFlip) {
                                                // When rotateFrame is true in the renderer, with swapped uvW/uvH:
                                                // br position gets (uvX + uvW, uvY) where uvW = frameHeight/texWidth
                                                // bl position gets (uvX + uvW, uvY + uvH) where uvH = frameWidth/texHeight
                                                // tl position gets (uvX, uvY + uvH)
                                                // tr position gets (uvX, uvY)

                                                // Since uvW and uvH are swapped, this means:
                                                // br position → top-right of rotated texture (u2, v1)
                                                // bl position → bottom-right of rotated texture (u2, v2)
                                                // tl position → bottom-left of rotated texture (u1, v2)
                                                // tr position → top-left of rotated texture (u1, v1)

                                                // This is a 90° clockwise rotation
                                                var newTlU = u1;  // tl vertex gets bottom-left after rotation
                                                var newTlV = v2;
                                                var newTrU = u1;  // tr vertex gets top-left after rotation
                                                var newTrV = v1;
                                                var newBrU = u2;  // br vertex gets top-right after rotation
                                                var newBrV = v1;
                                                var newBlU = u2;  // bl vertex gets bottom-right after rotation
                                                var newBlV = v2;

                                                tlU = newTlU;
                                                tlV = newTlV;
                                                trU = newTrU;
                                                trV = newTrV;
                                                brU = newBrU;
                                                brV = newBrV;
                                                blU = newBlU;
                                                blV = newBlV;

                                                // After rotation, apply flips - but the meanings are swapped
                                                // From computeTileQuads when diagonalFlip is true:
                                                // - tile.verticalFlip = true → scaleX = -1 (horizontal flip)
                                                // - tile.horizontalFlip = true → scaleY = 1 (no vertical flip)
                                                // - tile.horizontalFlip = false → scaleY = -1 (vertical flip)

                                                if (tile.verticalFlip) {
                                                    // This causes horizontal flip
                                                    var tmpU = tlU;
                                                    var tmpV = tlV;
                                                    tlU = trU;
                                                    tlV = trV;
                                                    trU = tmpU;
                                                    trV = tmpV;

                                                    tmpU = blU;
                                                    tmpV = blV;
                                                    blU = brU;
                                                    blV = brV;
                                                    brU = tmpU;
                                                    brV = tmpV;
                                                }
                                                if (!tile.horizontalFlip) {
                                                    // horizontalFlip = false causes vertical flip
                                                    var tmpU = tlU;
                                                    var tmpV = tlV;
                                                    tlU = blU;
                                                    tlV = blV;
                                                    blU = tmpU;
                                                    blV = tmpV;

                                                    tmpU = trU;
                                                    tmpV = trV;
                                                    trU = brU;
                                                    trV = brV;
                                                    brU = tmpU;
                                                    brV = tmpV;
                                                }
                                            } else {
                                                // No rotation, just apply flips normally
                                                if (tile.horizontalFlip) {
                                                    var tmpU = tlU;
                                                    var tmpV = tlV;
                                                    tlU = trU;
                                                    tlV = trV;
                                                    trU = tmpU;
                                                    trV = tmpV;

                                                    tmpU = blU;
                                                    tmpV = blV;
                                                    blU = brU;
                                                    blV = brV;
                                                    brU = tmpU;
                                                    brV = tmpV;
                                                }
                                                if (tile.verticalFlip) {
                                                    var tmpU = tlU;
                                                    var tmpV = tlV;
                                                    tlU = blU;
                                                    tlV = blV;
                                                    blU = tmpU;
                                                    blV = tmpV;

                                                    tmpU = trU;
                                                    tmpV = trV;
                                                    trU = brU;
                                                    trV = brV;
                                                    brU = tmpU;
                                                    brV = tmpV;
                                                }
                                            }

                                            // Set vertex positions (scaled)
                                            var scale = tileScale;
                                            var scaledWidth = tileWidth * scale;
                                            var scaledHeight = tileHeight * scale;
                                            var centerX = tileLeft + tileWidth * 0.5 - filterX;
                                            var centerY = tileTop + tileHeight * 0.5 - filterY;

                                            // Calculate corners from center (like Quad with anchor 0.5, 0.5)
                                            var halfWidth = scaledWidth * 0.5;
                                            var halfHeight = scaledHeight * 0.5;

                                            var x1 = centerX - halfWidth;
                                            var y1 = centerY - halfHeight;
                                            var x2 = centerX + halfWidth;
                                            var y2 = centerY + halfHeight;

                                            var vertices = mesh.vertices;
                                            var uvs = mesh.uvs;
                                            var indices = mesh.indices;
                                            var colors = mesh.colors;

                                            // Top-left vertex
                                            vertices[vertexIndex] = x1;
                                            vertices[vertexIndex + 1] = y1;
                                            uvs[vertexIndex] = tlU;
                                            uvs[vertexIndex + 1] = tlV;

                                            // Top-right vertex
                                            vertices[vertexIndex + 2] = x2;
                                            vertices[vertexIndex + 3] = y1;
                                            uvs[vertexIndex + 2] = trU;
                                            uvs[vertexIndex + 3] = trV;

                                            // Bottom-right vertex
                                            vertices[vertexIndex + 4] = x2;
                                            vertices[vertexIndex + 5] = y2;
                                            uvs[vertexIndex + 4] = brU;
                                            uvs[vertexIndex + 5] = brV;

                                            // Bottom-left vertex
                                            vertices[vertexIndex + 6] = x1;
                                            vertices[vertexIndex + 7] = y2;
                                            uvs[vertexIndex + 6] = blU;
                                            uvs[vertexIndex + 7] = blV;

                                            // Set indices for two triangles
                                            var baseVertex = quadIndex * 4;
                                            indices[indexIndex] = baseVertex;
                                            indices[indexIndex + 1] = baseVertex + 1;
                                            indices[indexIndex + 2] = baseVertex + 2;
                                            indices[indexIndex + 3] = baseVertex;
                                            indices[indexIndex + 4] = baseVertex + 2;
                                            indices[indexIndex + 5] = baseVertex + 3;

                                            // Set colors for all 4 vertices
                                            var alphaColor = new AlphaColor(layerColor, Math.round(alpha * 255));
                                            colors[colorIndex] = alphaColor;
                                            colors[colorIndex + 1] = alphaColor;
                                            colors[colorIndex + 2] = alphaColor;
                                            colors[colorIndex + 3] = alphaColor;

                                            // Update indices
                                            mesh.nextVertexIndice = vertexIndex + 8;
                                            mesh.nextIndexIndice = indexIndex + 6;
                                            mesh.nextColorIndice = colorIndex + 4;
                                            mesh.nextQuadIndice = quadIndex + 1;
                                        }
                                    }
                                }

                                t += tilesPerLayer;
                            }
                        }
                        r++;
                    }
                    c++;
                }
            }
        }

        // Resize mesh arrays to actual used size and deactivate unused meshes
        // We need to iterate through textureLayerToMeshIndex to find the correct keys
        for (i in 0...usedMeshes) {
            final mesh = tileMeshes[i];

            var finalVertexCount = mesh.nextVertexIndice;
            var finalIndexCount = mesh.nextIndexIndice;
            var finalColorCount = mesh.nextColorIndice;

            // Resize arrays down to actual used size
            if (mesh.vertices != null && mesh.vertices.length > finalVertexCount) {
                mesh.vertices.setArrayLength(finalVertexCount);
            }
            if (mesh.uvs != null && mesh.uvs.length > finalVertexCount) {
                mesh.uvs.setArrayLength(finalVertexCount);
            }
            if (mesh.indices != null && mesh.indices.length > finalIndexCount) {
                mesh.indices.setArrayLength(finalIndexCount);
            }
            if (mesh.colors != null && mesh.colors.length > finalColorCount) {
                mesh.colors.setArrayLength(finalColorCount);
            }
        }

        // Remove unused meshes
        while (usedMeshes < tileMeshes.length) {
            var mesh = tileMeshes.pop();
            mesh.recycle();
        }

        emitTileMeshesChange();

    }

/// Helpers

    /**
     * Retrieves the TilemapQuad at the specified column and row position.
     * @param column The column index (0-based)
     * @param row The row index (0-based)
     * @return The TilemapQuad at the position, or null if no tile exists there
     */
    public function tileQuadByColumnAndRow(column:Int, row:Int):TilemapQuad {

        var index = row * layerData.columns + column;
        return inline tileQuadByIndex(index);

    }

    /**
     * Retrieves the TilemapQuad at the specified tile index.
     * @param index The tile index in the layer's tile array
     * @return The TilemapQuad at the index, or null if no tile exists there
     */
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

            var layerData = this.layerData;
            var tileWidth = layerData.tileWidth;
            var tileHeight = layerData.tileHeight;

            var minColumn = Math.floor(left / tileWidth);
            var maxColumn = Math.ceil(right / tileWidth);
            var minRow = Math.floor(top / tileHeight);
            var maxRow = Math.ceil(bottom / tileHeight);

            var column = minColumn;
            while (column <= maxColumn) {
                var row = minRow;
                while (row <= maxRow) {
                    var tileQuad = inline tileQuadByColumnAndRow(column, row);
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
