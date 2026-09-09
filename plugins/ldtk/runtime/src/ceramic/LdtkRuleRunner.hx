package ceramic;

import ceramic.LdtkData;
import ldtk.rules.ArrayRuleSource;
import ldtk.rules.AutoTileSink;
import ldtk.rules.RuleDef;
import ldtk.rules.RuleEngine;
import ldtk.rules.RuleTarget;
import ldtk.rules.RuleTileset;

/**
 * Recomputes the auto tiles of an LDtk layer instance at runtime, with the same rule engine as the LDtk editor
 * (`ldtk.rules`), so that a modified IntGrid produces exactly the tiles the editor would produce.
 *
 * One runner per layer instance, kept on `LdtkLayerInstance.ruleRunner`. The engine, the IntGrid source,
 * the tile store and the rule list are created once and reused: recomputing does not allocate.
 *
 * When `incremental` is `true` (default), `compute()` only recomputes the cells around the IntGrid changes
 * made since the previous compute (the dirty rect tracked by `LdtkLayerInstance.setIntGrid()`, expanded by the
 * maximum rule radius), which gives exactly the same tiles as a full recompute. A full recompute happens when the
 * rules, the seed or the killing layer changed, or when the dirty rect cannot be trusted: several runners may read
 * the same IntGrid, so the rect is only cleared by `refreshAutoLayersUsingSource()` once every reader was refreshed.
 *
 * Typical use:
 * ```haxe
 * intGridLayer.setIntGrid(cx, cy, 1);
 * LdtkRuleRunner.refreshAutoLayersUsingSource(level, intGridLayer, tilemapVisual);
 * ```
 */
class LdtkRuleRunner implements RuleTarget {

    /**
     * The auto layer computed by this runner
     */
    public var layer(default, null):LdtkLayerInstance;

    /**
     * The layer providing the IntGrid values (the layer itself, or its auto source layer)
     */
    public var sourceLayer(default, null):LdtkLayerInstance;

    /**
     * Last computed tiles, indexed by cell (`ldtk.rules.CellTileBuffer`)
     */
    public var store(default, null):CellTileBuffer;

    /**
     * When `true`, `compute()` recomputes only the area of the IntGrid modified since the previous compute when possible
     */
    public var incremental:Bool = true;

    /**
     * `true` if the last `compute()` was a partial recompute (`false` after a full one)
     */
    public var lastComputeWasPartial(default, null):Bool = false;

    /**
     * Number of cells evaluated by the last `compute()` (0 when nothing had changed)
     */
    public var lastComputeCells(default, null):Int = 0;

    var engine:RuleEngine;
    var source:ArrayRuleSource;
    var tileset:LdtkRuleTileset;
    var rulesEval:Array<RuleDef> = [];
    var rulesDirty:Bool = true;
    var optionalRules:Map<Int,Bool> = new Map();
    var lastIntGridVersion:Int = -1;
    var lastSeed:Int = 0;
    var killedDirty:Bool = false;
    var computedOnce:Bool = false;

    var killerLayer:LdtkLayerInstance = null;
    var killed:haxe.ds.Vector<Bool> = null;

    /**
     * Get (or create) the runner of a layer
     */
    public static function get(layer:LdtkLayerInstance):LdtkRuleRunner {

        if (layer.ruleRunner == null) {
            layer.ruleRunner = new LdtkRuleRunner(layer);
        }
        return layer.ruleRunner;

    }

    /**
     * `true` if this layer has rules that can be computed at runtime
     */
    public static function canRun(layer:LdtkLayerInstance):Bool {

        var def = layer.def;
        if (def == null || def.ruleLayerDef == null || !def.ruleLayerDef.rulesCanBeUsed())
            return false;
        if (layer.tileset == null || layer.level == null)
            return false;
        var sourceLayer = resolveSourceLayer(layer);
        return sourceLayer != null && sourceLayer.intGrid != null && sourceLayer.def != null && sourceLayer.def.ruleLayerDef != null;

    }

    static function resolveSourceLayer(layer:LdtkLayerInstance):LdtkLayerInstance {

        if (layer.def.autoSourceLayerDefUid == -1)
            return layer;
        return findLayerByDefUid(layer.level, layer.def.autoSourceLayerDefUid);

    }

    static function findLayerByDefUid(level:LdtkLevel, defUid:Int):LdtkLayerInstance {

        if (level == null || level.layerInstances == null)
            return null;
        for (i in 0...level.layerInstances.length) {
            var li = level.layerInstances[i];
            if (li.def != null && li.def.uid == defUid)
                return li;
        }
        return null;

    }

    function new(layer:LdtkLayerInstance) {

        this.layer = layer;
        sourceLayer = resolveSourceLayer(layer);
        source = new ArrayRuleSource(sourceLayer.intGrid, sourceLayer.cWid, sourceLayer.cHei, sourceLayer.def.ruleLayerDef.valueGroupUids);
        lastIntGridVersion = sourceLayer.intGridVersion;
        tileset = new LdtkRuleTileset(layer.tileset);
        engine = new RuleEngine(source, this, tileset);
        store = new CellTileBuffer();
        lastSeed = layer.seed;

        if (layer.def.autoTilesKilledByOtherLayerUid != -1) {
            killerLayer = findLayerByDefUid(layer.level, layer.def.autoTilesKilledByOtherLayerUid);
            updateKilledCells();
        }

    }

    /**
     * Call this when the optional rule groups of the layer or the level biome field changed
     */
    public function invalidateRules():Void {

        rulesDirty = true;

    }

    /**
     * Call this when the tiles of the layer killing auto tiles changed
     */
    public function updateKilledCells():Void {

        killedDirty = true;
        if (killerLayer == null || killerLayer.gridTiles == null) {
            killed = null;
            return;
        }
        var n = killerLayer.cWid * killerLayer.cHei;
        if (killed == null || killed.length != n)
            killed = new haxe.ds.Vector(n);
        for (i in 0...n)
            killed[i] = false;
        var gridSize = killerLayer.def.gridSize;
        var tiles = killerLayer.gridTiles;
        var i = 0;
        while (i + 6 < tiles.length) {
            var cx = Std.int(tiles[i + 2] / gridSize);
            var cy = Std.int(tiles[i + 3] / gridSize);
            if (cx >= 0 && cy >= 0 && cx < killerLayer.cWid && cy < killerLayer.cHei)
                killed[cx + cy * killerLayer.cWid] = true;
            i += 7;
        }

    }

    function updateRules():Void {

        optionalRules.clear();
        if (layer.optionalRules != null) {
            for (i in 0...layer.optionalRules.length)
                optionalRules.set(layer.optionalRules[i], true);
        }
        layer.def.ruleLayerDef.rulesInEvalOrder(biomeValues(), optionalRules, rulesEval);
        rulesDirty = false;

    }

    function biomeValues():Null<Array<String>> {

        var uid = layer.def.biomeFieldUid;
        if (uid == -1 || layer.level == null || layer.level.fieldInstances == null)
            return null;
        for (i in 0...layer.level.fieldInstances.length) {
            var fi = layer.level.fieldInstances[i];
            if (fi.defUid == uid) {
                var v:Dynamic = fi.value;
                if (v == null)
                    return null;
                if (Std.isOfType(v, Array)) {
                    var arr:Array<Dynamic> = v;
                    return [for (k in 0...arr.length) arr[k] == null ? null : Std.string(arr[k])];
                }
                return [Std.string(v)];
            }
        }
        return null;

    }

    /**
     * Compute the tiles of the layer into `store`: everything, or only the cells around the IntGrid changes made
     * since the previous compute when `incremental` is `true` and the dirty rect of the source layer can be used.
     * Does nothing if nothing changed since the previous compute.
     */
    public function compute():CellTileBuffer {

        var seed = layer.seed;
        var versionChanged = (sourceLayer.intGridVersion != lastIntGridVersion);
        var needFull = !computedOnce || !incremental || rulesDirty || killedDirty || seed != lastSeed;

        if (rulesDirty)
            updateRules();

        if (!needFull && !versionChanged) {
            lastComputeCells = 0;
            lastComputeWasPartial = true;
            return store;
        }

        var partial = !needFull
            && sourceLayer.intGridDirtyLeft >= 0
            && sourceLayer.intGridDirtySinceVersion <= lastIntGridVersion;

        if (partial) {
            var left = sourceLayer.intGridDirtyLeft;
            var top = sourceLayer.intGridDirtyTop;
            var wid = sourceLayer.intGridDirtyRight - left + 1;
            var hei = sourceLayer.intGridDirtyBottom - top + 1;
            source.recountRect(left, top, wid, hei);
            lastComputeCells = engine.computeRect(store, rulesEval, left, top, wid, hei);
        }
        else {
            if (versionChanged)
                source.recount();
            lastComputeCells = engine.computeFull(store, rulesEval);
        }

        lastComputeWasPartial = partial;
        lastIntGridVersion = sourceLayer.intGridVersion;
        lastSeed = seed;
        killedDirty = false;
        computedOnce = true;
        return store;

    }

    /**
     * Write the last computed tiles into `layer.autoLayerTiles` (same stride 7 layout as when loaded from LDtk:
     * tile id, flip bits, x, y, source x, source y, alpha * 4096), reusing the existing array.
     */
    public function writeAutoLayerTiles():Array<Int> {

        var out = layer.autoLayerTiles;
        if (out == null) {
            out = [];
            layer.autoLayerTiles = out;
        }
        store.writeDisplayOrder(out);
        return out;

    }

    /**
     * Recompute the auto tiles of a layer from its current IntGrid, update `autoLayerTiles`, refresh the
     * `TilemapLayerData` and mark the layers of `tilemap` displaying it as dirty.
     * Returns `false` if the layer has no usable rules.
     */
    public static function refreshAutoLayer(layer:LdtkLayerInstance, ?tilemap:Tilemap):Bool {

        if (!canRun(layer))
            return false;

        var runner = get(layer);
        runner.compute();
        runner.writeAutoLayerTiles();

        if (layer.ceramicLayer != null) {
            TilemapLdtkParser.refreshAutoLayerData(layer);
            if (tilemap != null) {
                for (i in 0...tilemap.layers.length) {
                    var tilemapLayer = tilemap.layers[i];
                    if (tilemapLayer.layerData == layer.ceramicLayer)
                        tilemapLayer.contentDirty = true;
                }
            }
        }
        return true;

    }

    /**
     * Refresh every auto layer of `level` that reads the IntGrid of `intGridLayer` (including itself if it is an auto layer),
     * then forget the pending IntGrid changes of `intGridLayer` (every reader has seen them).
     * Returns the number of refreshed layers.
     */
    public static function refreshAutoLayersUsingSource(level:LdtkLevel, intGridLayer:LdtkLayerInstance, ?tilemap:Tilemap):Int {

        if (level == null || level.layerInstances == null)
            return 0;
        var n = 0;
        for (i in 0...level.layerInstances.length) {
            var li = level.layerInstances[i];
            if (li.def == null)
                continue;
            var readsSource = (li == intGridLayer) || (intGridLayer.def != null && li.def.autoSourceLayerDefUid == intGridLayer.def.uid);
            if (readsSource && refreshAutoLayer(li, tilemap))
                n++;
        }
        intGridLayer.clearIntGridDirtyRect();
        return n;

    }

    // RuleTarget implementation

    public function getSeed():Int return layer.seed;
    public function getGridSize():Int return layer.def.gridSize;
    public function getTilePivotX():Float return layer.def.tilePivotX;
    public function getTilePivotY():Float return layer.def.tilePivotY;
    public function getWidth():Int return layer.cWid;
    public function getHeight():Int return layer.cHei;

    public function isCellKilled(cx:Int, cy:Int):Bool {

        return killed != null && cx >= 0 && cy >= 0 && cx < killerLayer.cWid && cy < killerLayer.cHei && killed[cx + cy * killerLayer.cWid];

    }

}

/**
 * `ldtk.rules.RuleTileset` over an LDtk tileset definition.
 * Opacity uses the LDtk cached pixel data when available, for parity with the editor's break-on-match results.
 */
class LdtkRuleTileset implements RuleTileset {

    public var tileset:LdtkTilesetDefinition;

    public function new(tileset:LdtkTilesetDefinition) {

        this.tileset = tileset;

    }

    public function getTileCx(tileId:Int):Int return tileId - tileset.cWid * Std.int(tileId / tileset.cWid);
    public function getTileCy(tileId:Int):Int return Std.int(tileId / tileset.cWid);
    public function getTileSourceX(tileId:Int):Int return tileset.padding + getTileCx(tileId) * (tileset.tileGridSize + tileset.spacing);
    public function getTileSourceY(tileId:Int):Int return tileset.padding + getTileCy(tileId) * (tileset.tileGridSize + tileset.spacing);

    public function isTileOpaque(tileId:Int):Bool {

        var opaqueTiles = tileset.opaqueTiles;
        if (opaqueTiles != null)
            return tileId >= 0 && tileId < opaqueTiles.length && opaqueTiles.charCodeAt(tileId) == '1'.code;
        return tileset.isTileOpaque(tileId);

    }

}
