package ceramic;

using ceramic.Extensions;

/**
 * Renders tilemap data.
 * Note: only ORTHOGONAL is supported
 */
class Tilemap extends Quad {

    /**
     * Fired when a layer is created on this tilemap
     * @param tilemap The tilemap creating the layer
     * @param layer The layer being created
     */
    @event function createLayer(tilemap:Tilemap, layer:TilemapLayer);

/// Properties

    public var tilemapData(default,set):TilemapData = null;
    function set_tilemapData(tilemapData:TilemapData):TilemapData {
        if (this.tilemapData == tilemapData) return tilemapData;
        this.tilemapData = tilemapData;
        contentDirty = true;
        for (i in 0...layers.length) {
            var layer = layers.unsafeGet(i);
            layer.contentDirty = true;
        }
        return tilemapData;
    }

    public var tileScale(default,set):Float = 1.0;
    function set_tileScale(tileScale:Float):Float {
        if (this.tileScale == tileScale) return tileScale;
        this.tileScale = tileScale;
        if (tileScale != -1) {
            for (i in 0...layers.length) {
                layers.unsafeGet(i).tileScale = tileScale;
            }
        }
        return tileScale;
    }

    public var clipTilesX(default,set):Float = -1;
    function set_clipTilesX(clipTilesX:Float):Float {
        if (this.clipTilesX == clipTilesX) return clipTilesX;
        this.clipTilesX = clipTilesX;
        contentDirty = true;
        for (i in 0...layers.length) {
            var layer = layers.unsafeGet(i);
            layer.contentDirty = true;
        }
        return clipTilesX;
    }

    public var clipTilesY(default,set):Float = -1;
    function set_clipTilesY(clipTilesY:Float):Float {
        if (this.clipTilesY == clipTilesY) return clipTilesY;
        this.clipTilesY = clipTilesY;
        contentDirty = true;
        for (i in 0...layers.length) {
            var layer = layers.unsafeGet(i);
            layer.contentDirty = true;
        }
        return clipTilesY;
    }

    public var clipTilesWidth(default,set):Float = -1;
    function set_clipTilesWidth(clipTilesWidth:Float):Float {
        if (this.clipTilesWidth == clipTilesWidth) return clipTilesWidth;
        this.clipTilesWidth = clipTilesWidth;
        contentDirty = true;
        for (i in 0...layers.length) {
            var layer = layers.unsafeGet(i);
            layer.contentDirty = true;
        }
        return clipTilesWidth;
    }

    public var clipTilesHeight(default,set):Float = -1;
    function set_clipTilesHeight(clipTilesHeight:Float):Float {
        if (this.clipTilesHeight == clipTilesHeight) return clipTilesHeight;
        this.clipTilesHeight = clipTilesHeight;
        contentDirty = true;
        for (i in 0...layers.length) {
            var layer = layers.unsafeGet(i);
            layer.contentDirty = true;
        }
        return clipTilesHeight;
    }

    public var layers:Array<TilemapLayer> = [];

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

        transparent = true;

    }

    override function destroy() {

        var layers = this.layers;
        if (layers != null) {
            layers = [].concat(layers);
            for (i in 0...layers.length) {
                var layer = layers.unsafeGet(i);
                layer.destroy();
            }
        }

        super.destroy();

    }

/// Display

    override function computeContent() {

        if (tilemapData == null) {
            width = 0;
            height = 0;
            contentDirty = false;
            return;
        }

        // Update size
        size(
            tilemapData.width * tilemapData.tileWidth,
            tilemapData.height * tilemapData.tileHeight
        );

        computeLayers();

        contentDirty = false;

    }

    function computeLayers() {

        var usedLayers = 0;
        var tileScale = this.tileScale;

        for (l in 0...tilemapData.layers.length) {
            var layerData = tilemapData.layers.unsafeGet(l);
            var isNew = false;

            var layer:TilemapLayer = usedLayers < layers.length ? layers[usedLayers] : null;
            if (layer == null) {
                isNew = true;
                layer = new TilemapLayer();
                layer.tilemap = this;
                if (tileScale != -1) layer.tileScale = tileScale;
                layer.depthRange = 1;
                layers.push(layer);
                add(layer);
            }
            usedLayers++;

            layer.depth = l + 1;
            layer.layerData = layerData;

            if (isNew)
                emitCreateLayer(this, layer);
        }

        // Remove unused layers
        while (usedLayers < layers.length) {
            var layer = layers.pop();
            layer.destroy();
        }

    }

/// Clip

    public function clipTiles(clipTilesX, clipTilesY, clipTilesWidth, clipTilesHeight) {

        this.clipTilesX = clipTilesX;
        this.clipTilesY = clipTilesY;
        this.clipTilesWidth = clipTilesWidth;
        this.clipTilesHeight = clipTilesHeight;

    }

/// Helpers

    public function layer(name:String):TilemapLayer {

        if (contentDirty)
            computeContent();

        for (i in 0...layers.length) {
            var layer = layers.unsafeGet(i);
            var layerData = layer.layerData;
            if (layerData != null && layerData.name == name)
                return layer;
        }

        return null;

    }

#if plugin_arcade

/// Arcade physics

    static var _layers:Array<TilemapLayer> = [];

    public var collidableLayers(default, set):ReadOnlyArray<String> = null;
    function set_collidableLayers(collidableLayers:ReadOnlyArray<String>):ReadOnlyArray<String> {
        if (this.collidableLayers == collidableLayers) return collidableLayers;
        this.collidableLayers = collidableLayers;
        collidableLayersDirty = true;
        return collidableLayers;
    }

    public var computedCollidableLayers(default, null):ReadOnlyArray<TilemapLayer> = null;

    public var collidableLayersDirty:Bool = false;

    public var destroyUnusedBodies(default, set):Bool = false;
    function set_destroyUnusedBodies(destroyUnusedBodies:Bool):Bool {
        if (this.destroyUnusedBodies != destroyUnusedBodies) {
            this.destroyUnusedBodies = destroyUnusedBodies;
            collidableLayersDirty = true;
        }
        return destroyUnusedBodies;
    }

    @:allow(ceramic.ArcadeWorld)
    function computeCollidableLayers():Void {
        
        if (contentDirty)
            computeContent();

        var result:Array<TilemapLayer> = null;
        var len = layers.length;

        // Keep track of layers already collidable if needed
        if (destroyUnusedBodies) {
            for (i in 0...len) {
                var layer = layers.unsafeGet(i);
                if (layer.collidable) {
                    // Layer already collidable, keep it in array so that
                    // we clean it if not collidable anymore afterwards
                    _layers[i] = layer;
                    // Temporary mark layer as non collidable, if will be re-marked as collidable
                    // if still relevant in the next loop
                    layer.collidable = false;
                }
                else {
                    // No need to check this layer after as it was not collidable before
                    _layers[i] = null;
                }
            }
        }

        if (layers != null && layers.length > 0 && collidableLayers != null && collidableLayers.length > 0) {
            for (i in 0...collidableLayers.length) {
                var name = collidableLayers.unsafeGet(i);
                for (l in 0...layers.length) {
                    var layer = layers.unsafeGet(l);
                    var layerData = layer.layerData;
                    if (layerData != null && layerData.name == name) {
                        // Mark layer as collidable
                        layer.collidable = true;
                        if (result == null) {
                            result = [];
                        }
                        result.push(layer);
                    }
                }
            }
        }

        // Destroy arcade tiles on layers that are not collidable anymore, if any
        if (destroyUnusedBodies) {
            for (i in 0...len) {
                var layer = _layers.unsafeGet(i);
                if (layer != null && !layer.collidable) {
                    // Layer not collidable anymore, cleanup arcade tiles
                    layer.clearArcadeTiles();
                }
                _layers.unsafeSet(i, null);
            }
        }

        computedCollidableLayers = result;
        collidableLayersDirty = false;

    }

#end

}
