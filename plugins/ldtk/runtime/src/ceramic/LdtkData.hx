package ceramic;

/**
 * This is a hierarchy of classes following LDtk project JSON structure slightly adapted for Ceramic
 * and optimized to reduce memory footprint and dynamic access costs.
 *
 * It resolves entity, layer and field instances from data referencing Uids.
 * Used internally but also accessible to user code.
 *
 * Its usage is preferred over directly using ldtk.Json.ProjectJson, especially on static targets
 * like C# or C++ because the memory footprint of this LdtkData class is much lower than a plain
 * JSON hierarchy (static access instead of dynamic access, much fewer allocated strings etc...).
 *
 * That said, you can also use ldtk-haxe-api to read fully statically typed project data:
 * https://ldtk.io/docs/game-dev/haxe-in-game-api/usage/,
 * although it is completely optional and not needed by Ceramic itself.
 */

import ceramic.Color;
import ceramic.Shortcuts.*;
import haxe.DynamicAccess;

using StringTools;

/**
 * Root class representing an LDtk project data structure.
 *
 * This is the main entry point for working with LDtk level data in Ceramic.
 * It contains all the project definitions, worlds, and levels from an LDtk file.
 *
 * The data structure is optimized for performance on static targets and provides
 * easy access to all LDtk entities, layers, and tilesets.
 *
 * @see https://ldtk.io/ for more information about LDtk
 */
class LdtkData extends Entity {

    /**
     * File format version
     */
    public var version:String;

    /**
     * Unique project identifier
     */
    public var iid:String;

    /**
     * Project background color
     */
    public var bgColor:Color;

    /**
     * A structure containing all the definitions of this project
     */
    public var defs:LdtkDefinitions;

    /**
     * If `true`, one file will be saved for the project (incl. all its definitions) and one file in a sub-folder for each level.
     */
    public var externalLevels:Bool;

    /**
     * All instances of entities that have their exportToToc flag enabled are listed by def identifier here.
     */
    public var toc:Array<LdtkTocEntry>;

    /**
     * All worlds of this LDtk project
     */
    public var worlds:Array<LdtkWorld>;

    /**
     * The related asset (if any)
     */
    public var asset:TilemapAsset;

    /**
     * Used to load external level data
     */
    @:allow(ceramic.LdtkLevel)
    private var loadExternalLevelData:(relPath:String, callback:(levelData:DynamicAccess<Dynamic>)->Void)->Void;

    /**
     * When loading external levels, we also need
     * a funtion to load the Ceramic tilemap from it.
     * This is it.
     */
    @:allow(ceramic.LdtkLevel)
    private var loadLevelCeramicTilemap:(level:LdtkLevel)->Void;

    /**
     * Internal reference to the json currently being parsed
     */
    private static var _rootJson:DynamicAccess<Dynamic> = null;

    private static var _entityInstances:Array<LdtkEntityInstance> = null;

    /**
     * Creates a new LdtkData instance from JSON data.
     * @param json The parsed LDtk project JSON data
     * @param loadExternalLevelData Optional callback to load external level data when using multi-file projects
     * @param loadLevelCeramicTilemap Optional callback to load Ceramic tilemap for a level
     */
    public function new(?json:DynamicAccess<Dynamic>, ?loadExternalLevelData:(relPath:String, callback:(levelData:DynamicAccess<Dynamic>)->Void)->Void, ?loadLevelCeramicTilemap:(level:LdtkLevel)->Void) {

        super();

        this.loadExternalLevelData = loadExternalLevelData;
        this.loadLevelCeramicTilemap = loadLevelCeramicTilemap;

        if (json != null) {

            _rootJson = json;
            _entityInstances = [];

            var tocJson:Array<Dynamic> = json.get('toc');
            toc = tocJson != null ? [for (i in 0...tocJson.length) {
                new LdtkTocEntry(this, tocJson[i]);
            }] : [];

            version = json.get('jsonVersion');
            iid = json.get('iid');
            bgColor = Color.fromString(json.get('bgColor'));
            defs = new LdtkDefinitions(this, json.get('defs'));
            externalLevels = json.get('externalLevels');

            worlds = [];
            var levelsJson:Array<Dynamic> = json.get('levels');
            if (levelsJson != null && levelsJson.length > 0) {
                var mainWorld:DynamicAccess<Dynamic> = {};
                mainWorld.set('iid', json.get('dummyWorldIid'));
                mainWorld.set('identifier', 'World');
                mainWorld.set('levels', levelsJson);
                mainWorld.set('worldGridWidth', json.get('worldGridWidth'));
                mainWorld.set('worldGridHeight', json.get('worldGridHeight'));
                mainWorld.set('worldLayout', json.get('worldLayout'));
                worlds.push(new LdtkWorld(this, mainWorld));
            }
            var worldsJson:Array<Dynamic> = json.get('worlds');
            if (worldsJson != null && worldsJson.length > 0) {
                for (i in 0...worldsJson.length) {
                    worlds.push(new LdtkWorld(this, worldsJson[i]));
                }
            }

            _rootJson = null;
            _entityInstances = null;
        }

    }

    override public function destroy():Void {

        // Destroy linked ceramic tilesets
        if (defs != null && defs.tilesets != null) {
            var tilesetDefs = defs.tilesets;
            for (i in 0...tilesetDefs.length) {
                var tileset = tilesetDefs[i];
                if (tileset.ceramicTileset != null) {
                    var ceramicTileset = tileset.ceramicTileset;
                    tileset.ceramicTileset = null;
                    ceramicTileset.destroy();
                }
            }
        }

        // Destroy linked ceramic tilemaps
        if (worlds != null) {
            for (i in 0...worlds.length) {
                var world = worlds[i];
                if (world.levels != null) {
                    var levels = world.levels;
                    for (j in 0...levels.length) {
                        var level = levels[j];
                        if (level.ceramicTilemap != null) {
                            var ceramicTilemap = level.ceramicTilemap;
                            level.ceramicTilemap = null;
                            ceramicTilemap.destroy();
                        }
                    }
                }
            }
        }

        if (asset != null) asset.destroy();

        super.destroy();

    }

    /**
     * Gets a world by its identifier.
     * @param identifier The world identifier to search for
     * @return The matching LdtkWorld, or null if not found
     */
    public function world(identifier:String):LdtkWorld {

        if (this.worlds != null) {
            for (i in 0...this.worlds.length) {
                var world = this.worlds[i];
                if (world.identifier == identifier) {
                    return world;
                }
            }
        }

        return null;

    }

    /**
     * Gets a world by its unique instance identifier (IID).
     * @param iid The world IID to search for
     * @return The matching LdtkWorld, or null if not found
     */
    public function worldByIid(iid:String):LdtkWorld {

        if (this.worlds != null) {
            for (i in 0...this.worlds.length) {
                var world = this.worlds[i];
                trace('world=$world');
                if (world.iid == iid) {
                    return world;
                }
            }
        }

        return null;

    }

    public function tocEntry(identifier:String):LdtkTocEntry {

        if (toc != null) {
            for (i in 0...toc.length) {
                final entry = toc[i];
                if (entry.identifier == identifier) {
                    return entry;
                }
            }
        }

        return null;

    }

    public extern inline overload function findLayerDef(identifier:String):LdtkLayerDefinition {
        return _findLayerDefWithIdentifier(identifier);
    }

    private function _findLayerDefWithIdentifier(identifier:String):LdtkLayerDefinition {

        var layers = defs.layers;
        for (i in 0...layers.length) {
            var layer = layers[i];
            if (layer.identifier == identifier) {
                return layer;
            }
        }

        return null;

    }

    public extern inline overload function findLayerDef(uid:Int):LdtkLayerDefinition {
        return _findLayerDefWithUid(uid);
    }

    private function _findLayerDefWithUid(uid:Int):LdtkLayerDefinition {

        var layers = defs.layers;
        for (i in 0...layers.length) {
            var layer = layers[i];
            if (layer.uid == uid) {
                return layer;
            }
        }

        return null;

    }

    public extern inline overload function findTilesetDef(identifier:String):LdtkTilesetDefinition {
        return _findTilesetDefWithIdentifier(identifier);
    }

    private function _findTilesetDefWithIdentifier(identifier:String):LdtkTilesetDefinition {

        var tilesets = defs.tilesets;
        for (i in 0...tilesets.length) {
            var tileset = tilesets[i];
            if (tileset.identifier == identifier) {
                return tileset;
            }
        }

        return null;

    }

    public extern inline overload function findTilesetDef(uid:Int):LdtkTilesetDefinition {
        return _findTilesetDefWithUid(uid);
    }

    private function _findTilesetDefWithUid(uid:Int):LdtkTilesetDefinition {

        var tilesets = defs.tilesets;
        for (i in 0...tilesets.length) {
            var tileset = tilesets[i];
            if (tileset.uid == uid) {
                return tileset;
            }
        }

        return null;

    }

    public extern inline overload function findEntityDef(identifier:String):LdtkEntityDefinition {
        return _findEntityDefWithIdentifier(identifier);
    }

    private function _findEntityDefWithIdentifier(identifier:String):LdtkEntityDefinition {

        var entitys = defs.entities;
        for (i in 0...entitys.length) {
            var entity = entitys[i];
            if (entity.identifier == identifier) {
                return entity;
            }
        }

        return null;

    }

    public extern inline overload function findEntityDef(uid:Int):LdtkEntityDefinition {
        return _findEntityDefWithUid(uid);
    }

    private function _findEntityDefWithUid(uid:Int):LdtkEntityDefinition {

        var entitys = defs.entities;
        for (i in 0...entitys.length) {
            var entity = entitys[i];
            if (entity.uid == uid) {
                return entity;
            }
        }

        return null;

    }

    @:allow(ceramic.LdtkFieldInstance)
    @:allow(ceramic.LdtkLayerInstance)
    private function _resolveEntityInstance(json:DynamicAccess<Dynamic>, ?ldtkWorld:LdtkWorld, ?ldtkLayerInstance:LdtkLayerInstance):LdtkEntityInstance {

        var iid:String = null;

        if (_entityInstances != null) {
            if (json.get('iid') != null) {
                iid = json.get('iid');
                for (i in 0..._entityInstances.length) {
                    if (_entityInstances[i].iid == iid) {
                        return _entityInstances[i];
                    }
                }

                var entityInstance = new LdtkEntityInstance(this, ldtkWorld, json, _registerEntity);
                if (ldtkLayerInstance != null)
                    entityInstance.layerInstance = ldtkLayerInstance;
                return entityInstance;
            }
            else if (_rootJson != null && json.get('entityIid') != null) {
                iid = json.get('entityIid');
                for (i in 0..._entityInstances.length) {
                    if (_entityInstances[i].iid == iid) {
                        if (ldtkLayerInstance != null)
                            _entityInstances[i].layerInstance = ldtkLayerInstance;
                        return _entityInstances[i];
                    }
                }

                var levelsJson:Array<Dynamic> = _rootJson.get('levels');
                if (ldtkWorld != null && (levelsJson == null || levelsJson.length == 0)) {
                    var worldsJson:Array<Dynamic> = _rootJson.get('worlds');
                    if (worldsJson != null) {
                        for (i in 0...worldsJson.length) {
                            var worldJson:DynamicAccess<Dynamic> = worldsJson[i];
                            if (worldJson.get('iid') == ldtkWorld.iid) {
                                levelsJson = worldJson.get('levels');
                                break;
                            }
                        }
                    }
                }
                for (i in 0...levelsJson.length) {
                    var levelJson:DynamicAccess<Dynamic> = levelsJson[i];
                    var layerInstancesJson:Array<Dynamic> = levelJson.get('layerInstances');
                    for (j in 0...layerInstancesJson.length) {
                        var layerInstanceJson:DynamicAccess<Dynamic> = layerInstancesJson[j];
                        var entityInstancesJson:Array<Dynamic> = layerInstanceJson.get('entityInstances');
                        for (k in 0...entityInstancesJson.length) {
                            var entityInstanceJson:DynamicAccess<Dynamic> = entityInstancesJson[k];
                            if (entityInstanceJson.get('iid') == iid) {
                                var entityInstance = new LdtkEntityInstance(this, ldtkWorld, entityInstanceJson, _registerEntity);
                                if (ldtkLayerInstance != null)
                                    entityInstance.layerInstance = ldtkLayerInstance;
                                return entityInstance;
                            }
                        }
                    }
                }
            }
        }

        return null;

    }

    @:allow(ceramic.LdtkLevel)
    private function _cleanUnusedEntityInstances():Void {

        if (_entityInstances != null && _entityInstances.length > 0) {

            var used:Array<LdtkEntityInstance> = null;
            if (worlds != null) {
                for (w in 0...worlds.length) {
                    var world = worlds[w];
                    if (world.levels != null) {
                        var levels = world.levels;
                        for (l in 0...levels.length) {
                            var level = levels[l];
                            if (level.fieldInstances != null) {
                                used = _markEntityInstancesUsedInFieldInstances(used, level.fieldInstances);
                            }
                            if (level.layerInstances != null) {
                                used = _markEntityInstancesUsedInLayerInstances(used, level.layerInstances);
                            }
                        }
                    }
                }
            }

            var toRemove:Array<Int> = null;
            if (used != null) {
                for (e in 0..._entityInstances.length) {
                    var entityInstance = _entityInstances[e];
                    if (!used.contains(entityInstance)) {
                        if (toRemove == null)
                            toRemove = [];
                        toRemove.push(e);
                    }
                }
                if (toRemove != null) {
                    var i = toRemove.length - 1;
                    while (i >= 0) {
                        _entityInstances.splice(toRemove[i], 1);
                        i--;
                    }
                }
            }
        }

    }

    private function _markEntityInstancesUsedInFieldInstances(used:Array<LdtkEntityInstance>, fieldInstances:Array<LdtkFieldInstance>):Array<LdtkEntityInstance> {

        if (fieldInstances != null) {
            for (f in 0...fieldInstances.length) {
                var fieldInstance = fieldInstances[f];
                if (fieldInstance.def.type == 'EntityRef') {
                    used = _markEntityInstanceUsed(used, fieldInstance.value);
                }
                else if (fieldInstance.def.type == 'Array<EntityRef>') {
                    var array:Array<LdtkEntityInstance> = fieldInstance.value;
                    for (e in 0...array.length) {
                        used = _markEntityInstanceUsed(used, array[e]);
                    }
                }
            }
        }

        return used;

    }

    private function _markEntityInstancesUsedInLayerInstances(used:Array<LdtkEntityInstance>, layerInstances:Array<LdtkLayerInstance>):Array<LdtkEntityInstance> {

        if (layerInstances != null) {
            for (l in 0...layerInstances.length) {
                var layerInstance = layerInstances[l];
                if (layerInstance.entityInstances != null) {
                    var entityInstances = layerInstance.entityInstances;
                    for (e in 0...entityInstances.length) {
                        used = _markEntityInstanceUsed(used, entityInstances[e]);
                    }
                }
            }
        }

        return used;

    }

    private function _markEntityInstanceUsed(used:Array<LdtkEntityInstance>, entityInstance:LdtkEntityInstance):Array<LdtkEntityInstance> {

        if (entityInstance == null)
            return used;

        if (used == null)
            used = [];

        if (!used.contains(entityInstance)) {
            used.push(entityInstance);

            if (entityInstance.fieldInstances != null) {
                used = _markEntityInstancesUsedInFieldInstances(used, entityInstance.fieldInstances);
            }
        }

        return used;

    }

    private function _registerEntity(entityInstance:LdtkEntityInstance, json:DynamicAccess<Dynamic>) {

        _entityInstances.push(entityInstance);

    }

    override function toString() {

        if (LdtkDataHelpers.beginObjectToString(this)) {
            var res = 'LdtkData' + LdtkDataHelpers.objectToString({
                version: ''+version,
                iid: ''+iid,
                bgColor: ''+bgColor,
                defs: ''+defs,
                externalLevels: ''+externalLevels,
                worlds: ''+worlds
            });
            LdtkDataHelpers.endObjectToString();
            return res;
        }
        return LdtkDataHelpers.HIDDEN_VALUE;

    }

}

/**
 * Represents a Table of Contents entry for entities marked with exportToToc.
 * Provides quick access to all instances of a specific entity type across the project.
 */
class LdtkTocEntry {

    /**
     * The `LdtkData` object this toc entry belongs to
     */
    public var ldtkData:LdtkData;

    /**
     * Entity definition identifier
     */
    public var identifier:String;

    /**
     * All instances of entities that have their `exportToToc` flag enabled
     * are listed in this array.
     */
    public var instancesData:Array<LdtkTocInstanceData>;

    /**
     * Creates a new table of contents entry.
     * @param ldtkData The parent LdtkData object
     * @param json The JSON data for this entry
     */
    public function new(?ldtkData:LdtkData, ?json:DynamicAccess<Dynamic>) {

        this.ldtkData = ldtkData;

        if (json != null) {
            this.identifier = json.get('identifier');

            var instancesDataJson:Array<Dynamic> = json.get('instancesData');
            instancesData = instancesDataJson != null ? [for (i in 0...instancesDataJson.length) {
                new LdtkTocInstanceData(this, instancesDataJson[i]);
            }] : [];
        }

    }

    public function toString() {

        if (LdtkDataHelpers.beginObjectToString(this)) {
            var res = 'LdtkTocEntry' + LdtkDataHelpers.objectToString({
                identifier: ''+identifier,
                instancesData: ''+instancesData
            });
            LdtkDataHelpers.endObjectToString();
            return res;
        }
        return LdtkDataHelpers.HIDDEN_VALUE;

    }

}

/**
 * Contains instance data for an entity referenced in the table of contents.
 * Includes location information to quickly find entities across levels.
 */
class LdtkTocInstanceData {

    /**
     * The `LdtkTocEntry` object this instance data belongs to
     */
    public var tocEntry:LdtkTocEntry;

    /**
     * An object containing the values of all entity fields with the `exportToDoc` option enabled.
     */
    public var fields:DynamicAccess<Dynamic>;

    /**
     * Entity width in pixels as it appears in the LDtk editor
     */
    public var widPx:Int;

    /**
     * Entity height in pixels as it appears in the LDtk editor
     */
    public var heiPx:Int;

    /**
     * Entity X coordinate in world pixels (across all levels)
     */
    public var worldX:Int;

    /**
     * Entity Y coordinate in world pixels (across all levels)
     */
    public var worldY:Int;

    /**
     * Unique instance identifier for the world containing this entity
     */
    public var worldIid:String;

    /**
     * Unique instance identifier for the level containing this entity
     */
    public var levelIid:String;

    /**
     * Unique instance identifier for the layer containing this entity
     */
    public var layerIid:String;

    /**
     * Unique instance identifier for this entity instance
     */
    public var entityIid:String;

    public function new(?tocEntry:LdtkTocEntry, ?json:DynamicAccess<Dynamic>) {

        this.tocEntry = tocEntry;

        if (json != null) {
            this.fields = json.get('fields');
            this.widPx = Std.int(json.get('widPx'));
            this.heiPx = Std.int(json.get('heiPx'));
            this.worldX = Std.int(json.get('worldX'));
            this.worldY = Std.int(json.get('worldY'));
            if (json.exists('iids')) {
                final iids:DynamicAccess<Dynamic> = json.get('iids');
                this.worldIid = iids.get('worldIid');
                this.levelIid = iids.get('levelIid');
                this.layerIid = iids.get('layerIid');
                this.entityIid = iids.get('entityIid');
            }
        }

    }

    public function toString() {

        if (LdtkDataHelpers.beginObjectToString(this)) {
            var res = 'LdtkTocInstanceData' + LdtkDataHelpers.objectToString({
                fields: ''+fields,
                widPx: ''+widPx,
                heiPx: ''+heiPx,
                worldX: ''+worldX,
                worldY: ''+worldY,
                worldIid: ''+worldIid,
                levelIid: ''+levelIid,
                layerIid: ''+layerIid,
                entityIid: ''+entityIid
            });
            LdtkDataHelpers.endObjectToString();
            return res;
        }
        return LdtkDataHelpers.HIDDEN_VALUE;

    }

}

/**
 * Represents a world in an LDtk project.
 *
 * A world contains multiple levels arranged according to a specific layout
 * (Free, GridVania, LinearHorizontal, or LinearVertical).
 *
 * In multi-world projects, each world acts as a separate game area or chapter.
 * Single-world projects will have one default world containing all levels.
 */
class LdtkWorld {

    /**
     * The `LdtkData` object this world belongs to
     */
    public var ldtkData:LdtkData;

    /**
     * User defined unique identifier
     */
    public var identifier:String;

    /**
     * Unique instance identifer
     */
    public var iid:String;

    /**
     * All levels from this world. The order of this array is only relevant in `LinearHorizontal` and `LinearVertical` world layouts (see `worldLayout` value).
     * Otherwise, you should refer to the `worldX`,`worldY` coordinates of each Level.
     */
    public var levels:Array<LdtkLevel>;

    /**
     * Width of the world grid in pixels.
     */
    public var worldGridWidth:Int;

    /**
     * Height of the world grid in pixels.
     */
    public var worldGridHeight:Int;

    /**
     * An enum that describes how levels are organized in this project (ie. linearly or in a 2D space).
     */
    public var worldLayout:LdtkWorldLayout;

    public function new(?ldtkData:LdtkData, ?json:DynamicAccess<Dynamic>) {

        this.ldtkData = ldtkData;

        if (json != null) {

            identifier = json.get('identifier');
            iid = json.get('iid');

            var levelsJson:Array<Dynamic> = json.get('levels');
            levels = levelsJson != null ? [for (i in 0...levelsJson.length) {
                new LdtkLevel(ldtkData, this, levelsJson[i]);
            }] : [];

            worldGridWidth = json.get('worldGridWidth') != null ? json.get('worldGridWidth') : -1;
            worldGridHeight = json.get('worldGridHeight') != null ? json.get('worldGridHeight') : -1;
            worldLayout = json.get('worldLayout') != null ? LdtkWorldLayout.fromString(json.get('worldLayout')) : None;
        }

    }

    public function level(identifier:String):LdtkLevel {

        if (this.levels != null) {
            for (i in 0...this.levels.length) {
                var level = this.levels[i];
                if (level.identifier == identifier) {
                    return level;
                }
            }
        }

        return null;

    }

    public function levelByIid(iid:String):LdtkLevel {

        if (this.levels != null) {
            for (i in 0...this.levels.length) {
                var level = this.levels[i];
                if (level.iid == iid) {
                    return level;
                }
            }
        }

        return null;

    }

    public function toString() {

        if (LdtkDataHelpers.beginObjectToString(this)) {
            var res = 'LdtkWorld' + LdtkDataHelpers.objectToString({
                identifier: ''+identifier,
                iid: ''+iid,
                levels: ''+levels,
                worldGridWidth: ''+worldGridWidth,
                worldGridHeight: ''+worldGridHeight,
                worldLayout: ''+worldLayout
            });
            LdtkDataHelpers.endObjectToString();
            return res;
        }
        return LdtkDataHelpers.HIDDEN_VALUE;

    }

}

enum abstract LdtkWorldLayout(Int) from Int to Int {

    /**
     * No specific world layout - levels are not arranged in any particular structure
     */
    var None = 0;

    /**
     * Free positioning - levels can be placed freely in 2D space without constraints
     */
    var Free = 1;

    /**
     * Grid-based layout similar to Metroidvania games - levels snap to a grid for interconnected world structure
     */
    var GridVania = 2;

    /**
     * Linear horizontal layout - levels are arranged in a single row from left to right
     */
    var LinearHorizontal = 3;

    /**
     * Linear vertical layout - levels are arranged in a single column from top to bottom
     */
    var LinearVertical = 4;

    public static function fromString(str:String):LdtkWorldLayout {

        return switch str {
            case 'None': None;
            case 'Free': Free;
            case 'GridVania': GridVania;
            case 'LinearHorizontal': LinearHorizontal;
            case 'LinearVertical': LinearVertical;
            case _: 0;
        }

    }

    public function toString() {

        var value:LdtkWorldLayout = this;
        return 'LdtkWorldLayout.' + switch value {
            case None: 'None';
            case Free: 'Free';
            case GridVania: 'GridVania';
            case LinearHorizontal: 'LinearHorizontal';
            case LinearVertical: 'LinearVertical';
            case _: '_';
        }

    }

}

/**
 * A structure containing all the definitions of an LDtk project
 */
/**
 * Contains all the definitions used in an LDtk project.
 *
 * This includes:
 * - Entity definitions
 * - Layer definitions
 * - Tileset definitions
 * - Enum definitions
 *
 * These definitions describe the structure and rules that levels follow.
 */
class LdtkDefinitions {

    /**
     * The `LdtkData` object these definitions belong to
     */
    public var ldtkData:LdtkData;

    /**
     * All entities definitions, including their custom fields
     */
    public var entities:Array<LdtkEntityDefinition>;

    /**
     * All internal enums
     */
    public var enums:Array<LdtkEnumDefinition>;

    /**
     * Note: external enums are exactly the same as enums,
     * except they have a relPath to point to an external source file.
     */
    public var externalEnums:Array<LdtkEnumDefinition>;

    /**
     * All layer definitions
     */
    public var layers:Array<LdtkLayerDefinition>;

    /**
     * All custom fields available to all levels.
     */
    public var levelFields:Array<LdtkFieldDefinition>;

    /**
     * All tilesets
     */
    public var tilesets:Array<LdtkTilesetDefinition>;

    public function new(?ldtkData:LdtkData, ?json:DynamicAccess<Dynamic>) {

        if (ldtkData != null) {
            this.ldtkData = ldtkData;
            ldtkData.defs = this;
        }

        if (json != null) {
            var tilesetsJson:Array<Dynamic> = json.get('tilesets');
            tilesets = tilesetsJson != null ? [for (i in 0...tilesetsJson.length) {
                new LdtkTilesetDefinition(this, tilesetsJson[i]);
            }] : [];

            var entitiesJson:Array<Dynamic> = json.get('entities');
            entities = entitiesJson != null ? [for (i in 0...entitiesJson.length) {
                new LdtkEntityDefinition(this, entitiesJson[i]);
            }] : [];

            var enumsJson:Array<Dynamic> = json.get('enums');
            enums = enumsJson != null ? [for (i in 0...enumsJson.length) {
                new LdtkEnumDefinition(this, enumsJson[i]);
            }] : [];

            var externalEnumsJson:Array<Dynamic> = json.get('externalEnums');
            externalEnums = externalEnumsJson != null ? [for (i in 0...externalEnumsJson.length) {
                new LdtkEnumDefinition(this, externalEnumsJson[i]);
            }] : [];

            var layersJson:Array<Dynamic> = json.get('layers');
            layers = layersJson != null ? [for (i in 0...layersJson.length) {
                new LdtkLayerDefinition(this, layersJson[i]);
            }] : [];

            var levelFieldsJson:Array<Dynamic> = json.get('levelFields');
            levelFields = levelFieldsJson != null ? [for (i in 0...levelFieldsJson.length) {
                new LdtkFieldDefinition(this, levelFieldsJson[i]);
            }] : [];
        }

    }

    public function entity(identifier:String):LdtkEntityDefinition {

        if (this.entities != null) {
            for (i in 0...this.entities.length) {
                var entity = this.entities[i];
                if (entity.identifier == identifier) {
                    return entity;
                }
            }
        }

        return null;

    }

    public function layer(identifier:String):LdtkLayerDefinition {

        if (this.layers != null) {
            for (i in 0...this.layers.length) {
                var layer = this.layers[i];
                if (layer.identifier == identifier) {
                    return layer;
                }
            }
        }

        return null;

    }

    public function tileset(identifier:String):LdtkTilesetDefinition {

        if (this.tilesets != null) {
            for (i in 0...this.tilesets.length) {
                var tileset = this.tilesets[i];
                if (tileset.identifier == identifier) {
                    return tileset;
                }
            }
        }

        return null;

    }

    public function levelField(identifier:String):LdtkFieldDefinition {

        if (this.levelFields != null) {
            for (i in 0...this.levelFields.length) {
                var levelField = this.levelFields[i];
                if (levelField.identifier == identifier) {
                    return levelField;
                }
            }
        }

        return null;

    }

    public function enumDef(identifier:String):LdtkEnumDefinition {

        if (this.enums != null) {
            for (i in 0...this.enums.length) {
                var enumDef = this.enums[i];
                if (enumDef.identifier == identifier) {
                    return enumDef;
                }
            }
        }

        return null;

    }

    public function externalEnumDef(identifier:String):LdtkEnumDefinition {

        if (this.externalEnums != null) {
            for (i in 0...this.externalEnums.length) {
                var enumDef = this.externalEnums[i];
                if (enumDef.identifier == identifier) {
                    return enumDef;
                }
            }
        }

        return null;

    }

    public function toString() {

        if (LdtkDataHelpers.beginObjectToString(this)) {
            var res = 'LdtkDefinitions' + LdtkDataHelpers.objectToString({
                entities: ''+entities,
                enums: ''+enums,
                externalEnums: ''+externalEnums,
                layers: ''+layers,
                levelFields: ''+levelFields,
                tilesets: ''+tilesets
            });
            LdtkDataHelpers.endObjectToString();
            return res;
        }
        return LdtkDataHelpers.HIDDEN_VALUE;

    }

}

/**
 * An LDtk entity definition
 */
/**
 * Defines an entity type that can be placed in levels.
 *
 * Entities are game objects like players, enemies, items, triggers, etc.
 * This definition describes the entity's appearance, fields, and behavior rules.
 */
class LdtkEntityDefinition {

    /**
     * The `LdtkDefinitions` object this entity def belongs to
     */
    public var defs:LdtkDefinitions;

    /**
     * Base entity color
     */
    public var color:Color;

    /**
     * Pixel width
     */
    public var width:Int;

    /**
     * Pixel height
     */
    public var height:Int;

    /**
     * User defined unique identifier
     */
    public var identifier:String;

    /**
     * An array of 4 dimensions for the up/right/down/left borders (in this order) when using 9-slice mode for `tileRenderMode`.
     * If the tileRenderMode is not NineSlice, then this array is empty.
     * @see https://en.wikipedia.org/wiki/9-slice_scaling
     */
    public var nineSliceBorders:Array<Int>;

    /**
     * Pivot X coordinate (from 0 to 1.0)
     */
    public var pivotX:Float;

    /**
     * Pivot Y coordinate (from 0 to 1.0)
     */
    public var pivotY:Float;

    /**
     * Render mode
     */
    public var renderMode:LdtkRenderMode;

    /**
     * An object representing a rectangle from an existing Tileset (can be `null`)
     */
    public var tileRect:LdtkTilesetRectangle;

    /**
     * An enum describing how the the Entity tile is rendered inside the Entity bounds.
     */
    public var tileRenderMode:LdtkTileRenderMode;

    /**
     * The corresponding Tileset definition, if any, for optional tile display
     */
    public var tileset:LdtkTilesetDefinition = null;

    /**
     * Unique Int identifier
     */
    public var uid:Int;

    /**
     * An array of strings that classifies this entity
     */
    public var tags:Array<String>;

    /**
     * An array of field definitions that belong to this entity definition
     */
    public var fieldDefs:Array<LdtkFieldDefinition>;

    public function new(?defs:LdtkDefinitions, ?json:DynamicAccess<Dynamic>) {

        this.defs = defs;

        if (json != null) {
            color = Color.fromString(json.get('color'));
            width = Std.int(json.get('width'));
            height = Std.int(json.get('height'));
            identifier = json.get('identifier');
            nineSliceBorders = LdtkDataHelpers.toIntArray(json.get('nineSliceBorders'));
            pivotX = json.get('pivotX');
            pivotY = json.get('pivotY');
            renderMode = LdtkRenderMode.fromString(json.get('renderMode'));
            tileRect = new LdtkTilesetRectangle(
                defs != null ? defs.ldtkData : null,
                json.get('tileRect')
            );
            tileRenderMode = LdtkTileRenderMode.fromString(json.get('tileRenderMode'));
            if (defs != null && defs.ldtkData != null)
                tileset = defs.ldtkData.findTilesetDef(Std.int(json.get('tilesetId')));
            uid = Std.int(json.get('uid'));
            tags = LdtkDataHelpers.toStringArray(json.get('tags'));
            var fieldDefsJson:Array<Dynamic> = json.get('fieldDefs');
            fieldDefs = fieldDefsJson != null ? [for (i in 0...fieldDefsJson.length) {
                new LdtkFieldDefinition(defs, fieldDefsJson[i]);
            }] : [];
        }

    }

    /**
     * Returns `true` if entities instances having this entity definition
     * can be rendered with the given `renderMode`. Will also check that
     * the definition is not using internal icons as well, as they should not be rendered anyway.
     * @param renderMode The render mode we want to test
     * @return Bool
     */
    public function isRenderable(renderMode:LdtkRenderMode):Bool {

        var result = false;
        if (this.renderMode == renderMode) {
            if (tileset != null) {
                var ceramicTileset = tileset.ceramicTileset;
                if (ceramicTileset != null) {
                    var texture = ceramicTileset.texture;
                    if (texture != null) {
                        result = true;
                    }
                }
            }
        }

        return result;

    }

    public function toString() {

        if (LdtkDataHelpers.beginObjectToString(this)) {
            var res = 'LdtkEntityDefinition' + LdtkDataHelpers.objectToString({
                color: ''+color,
                width: ''+width,
                height: ''+height,
                identifier: ''+identifier,
                nineSliceBorders: ''+nineSliceBorders,
                pivotX: ''+pivotX,
                pivotY: ''+pivotY,
                tileRect: ''+tileRect,
                tileRenderMode: ''+tileRenderMode,
                tileset: ''+tileset,
                uid: ''+uid
            });
            LdtkDataHelpers.endObjectToString();
            return res;
        }
        return LdtkDataHelpers.HIDDEN_VALUE;

    }

    public function fieldDef(identifier:String):LdtkFieldDefinition {

        if (this.fieldDefs != null) {
            for (i in 0...this.fieldDefs.length) {
                var fieldDef = this.fieldDefs[i];
                if (fieldDef.identifier == identifier) {
                    return fieldDef;
                }
            }
        }

        return null;

    }

}

/**
 * This object represents a custom sub rectangle in a Tileset image.
 */
class LdtkTilesetRectangle {

    /**
     * The related tileset
     */
    public var tileset:LdtkTilesetDefinition = null;

    /**
     * X pixels coordinate of the top-left corner in the Tileset image
     */
    public var x:Int;

    /**
     * Y pixels coordinate of the top-left corner in the Tileset image
     */
    public var y:Int;

    /**
     * Width in pixels
     */
    public var w:Int;

    /**
     * Height in pixels
     */
    public var h:Int;

    /**
     * Get a Ceramic texture tile from this tileset rectangle.
     */
    public var ceramicTile(get, null):TextureTile;
    function get_ceramicTile():TextureTile {
        if (this.ceramicTile == null && tileset != null && tileset.ceramicTileset != null) {
            this.ceramicTile = {
                texture: tileset.ceramicTileset.texture,
                frameX: x, frameY: y,
                frameWidth: w, frameHeight: h
            };
        }
        return this.ceramicTile;
    }

    public function new(?ldtkData:LdtkData, ?json:DynamicAccess<Dynamic>) {

        if (json != null) {
            if (ldtkData != null) {
                tileset = ldtkData.findTilesetDef(Std.int(json.get('tilesetUid')));
            }
            x = json.get('x');
            y = json.get('y');
            w = json.get('w');
            h = json.get('h');
        }

    }

    public function toString() {

        if (LdtkDataHelpers.beginObjectToString(this)) {
            var res = 'LdtkTilesetRectangle' + LdtkDataHelpers.objectToString({
                tileset: ''+tileset,
                x: ''+x,
                y: ''+y,
                w: ''+w,
                h: ''+h
            });
            LdtkDataHelpers.endObjectToString();
            return res;
        }
        else {
            return LdtkDataHelpers.HIDDEN_VALUE;
        }
    }

}

enum abstract LdtkRenderMode(Int) from Int to Int {

    /**
     * Entity is rendered as a filled rectangle
     */
    var Rectangle = 1;

    /**
     * Entity is rendered as a filled ellipse/circle
     */
    var Ellipse = 2;

    /**
     * Entity is rendered using a tile/sprite from a tileset
     */
    var Tile = 3;

    /**
     * Entity is rendered as a cross/plus sign shape for debugging or placeholder purposes
     */
    var Cross = 4;

    public static function fromString(str:String):LdtkRenderMode {

        return switch str {
            case 'Rectangle': Rectangle;
            case 'Ellipse': Ellipse;
            case 'Tile': Tile;
            case 'Cross': Cross;
            case _: 0;
        }

    }

    public function toString() {

        var value:LdtkRenderMode = this;
        return 'LdtkTileRenderMode.' + switch value {
            case Rectangle: 'Rectangle';
            case Ellipse: 'Ellipse';
            case Tile: 'Tile';
            case Cross: 'Cross';
            case _: '_';
        }

    }

}

enum abstract LdtkTileRenderMode(Int) from Int to Int {

    /**
     * Tile is scaled proportionally to cover the entire entity bounds, potentially cropping parts that extend beyond
     */
    var Cover = 1;

    /**
     * Tile is scaled proportionally to fit entirely within the entity bounds, potentially leaving empty space
     */
    var FitInside = 2;

    /**
     * Tile is repeated/tiled to fill the entity bounds at its original size
     */
    var Repeat = 3;

    /**
     * Tile is stretched non-proportionally to exactly fill the entity bounds, potentially distorting the image
     */
    var Stretch = 4;

    /**
     * Tile is displayed at its original size, cropped to fit within the entity bounds
     */
    var FullSizeCropped = 5;

    /**
     * Tile is displayed at its original size without cropping, potentially extending beyond entity bounds
     */
    var FullSizeUncropped = 6;

    /**
     * Tile is rendered using nine-slice scaling for scalable UI elements with preserved corners and borders
     */
    var NineSlice = 7;

    public static function fromString(str:String):LdtkTileRenderMode {

        return switch str {
            case 'Cover': Cover;
            case 'FitInside': FitInside;
            case 'Repeat': Repeat;
            case 'Stretch': Stretch;
            case 'FullSizeCropped': FullSizeCropped;
            case 'FullSizeUncropped': FullSizeUncropped;
            case 'NineSlice': NineSlice;
            case _: 0;
        }

    }

    public function toString() {

        var value:LdtkTileRenderMode = this;
        return 'LdtkTileRenderMode.' + switch value {
            case Cover: 'Cover';
            case FitInside: 'FitInside';
            case Repeat: 'Repeat';
            case Stretch: 'Stretch';
            case FullSizeCropped: 'FullSizeCropped';
            case FullSizeUncropped: 'FullSizeUncropped';
            case NineSlice: 'NineSlice';
            case _: '_';
        }

    }

}

class LdtkEnumDefinition {

    /**
     * The `LdtkDefinitions` object this enum def belongs to
     */
    public var defs:LdtkDefinitions;

    /**
     * Relative path to the external file providing this Enum (can be `null`)
     */
    public var externalRelPath:String;

    /**
     * Tileset UID if provided
     */
    public var iconTilesetUid:Int;

    /**
     * User defined unique identifier
     */
    public var identifier:String;

    /**
     * An array of user-defined tags to organize the Enums
     */
    public var tags:Array<String>;

    /**
     * Unique Int identifier
     */
    public var uid:Int;

    /**
     * All possible enum values, with their optional Tile infos.
     */
    public var values:Array<LdtkEnumValueDefinition>;

    public function new(?defs:LdtkDefinitions, ?json:DynamicAccess<Dynamic>) {

        this.defs = defs;

        if (json != null) {
            externalRelPath = json.get('externalRelPath');
            iconTilesetUid = json.get('iconTilesetUid') != null ? Std.int(json.get('iconTilesetUid')) : -1;
            identifier = json.get('identifier');
            tags = LdtkDataHelpers.toStringArray(json.get('tags'));
            uid = Std.int(json.get('uid'));

            var valuesJson:Array<Dynamic> = json.get('values');
            values = valuesJson != null ? [for (i in 0...valuesJson.length) {
                new LdtkEnumValueDefinition(defs, valuesJson[i]);
            }] : [];
        }

    }

    public function value(id:String):LdtkEnumValueDefinition {

        if (this.values != null) {
            for (i in 0...this.values.length) {
                var value = this.values[i];
                if (value.id == id) {
                    return value;
                }
            }
        }

        return null;

    }

    public function toString() {

        if (LdtkDataHelpers.beginObjectToString(this)) {
            var res = 'LdtkEnumDefinition' + LdtkDataHelpers.objectToString({
                externalRelPath: ''+externalRelPath,
                iconTilesetUid: ''+iconTilesetUid,
                identifier: ''+identifier,
                tags: ''+tags,
                uid: ''+uid,
                values: ''+values
            });
            LdtkDataHelpers.endObjectToString();
            return res;
        }
        else {
            return LdtkDataHelpers.HIDDEN_VALUE;
        }

    }

}

class LdtkEnumValueDefinition {

    /**
     * The `LdtkDefinitions` object this enum value def belongs to
     */
    public var defs:LdtkDefinitions;

    /**
     * An array of 4 Int values that refers to the tile in the tileset image: `[ x, y, width, height ]` (can be `null`)
     */
    public var tileSrcRect:Array<Int>;

    /**
     * Optional color
     */
    public var color:Color;

    /**
     * Enum value
     */
    public var id:String;

    /**
     * The optional ID of the tile
     */
    public var tileId:Null<Int>;

    public function new(?defs:LdtkDefinitions, ?json:DynamicAccess<Dynamic>) {

        this.defs = defs;

        if (json != null) {
            tileSrcRect = json.get('__tileSrcRect') != null ? LdtkDataHelpers.toIntArray(json.get('__tileSrcRect')) : null;
            color = Std.int(json.get('color'));
            id = json.get('id');
            tileId = json.get('tileId') != null ? json.get('tileId') : -1;
        }

    }

    public function toString() {

        if (LdtkDataHelpers.beginObjectToString(this)) {
            var res = 'LdtkEnumValueDefinition' + LdtkDataHelpers.objectToString({
                tileSrcRect: ''+tileSrcRect,
                color: ''+color,
                id: ''+id,
                tileId: ''+tileId
            });
            LdtkDataHelpers.endObjectToString();
            return res;
        }
        else {
            return LdtkDataHelpers.HIDDEN_VALUE;
        }

    }

}

enum abstract LdtkLayerType(Int) from Int to Int {

    /**
     * Integer grid layer for collision detection, zones, or level structure data
     */
    var IntGrid = 1;

    /**
     * Entity layer containing instances of entity definitions for game objects, NPCs, items, etc.
     */
    var Entities = 2;

    /**
     * Tile layer for manual placement of visual tiles from tilesets
     */
    var Tiles = 3;

    /**
     * Auto layer with rule-based automatic tile placement based on IntGrid values or other conditions
     */
    var AutoLayer = 4;

    public static function fromString(str:String):LdtkLayerType {

        return switch str {
            case 'IntGrid': IntGrid;
            case 'Entities': Entities;
            case 'Tiles': Tiles;
            case 'AutoLayer': AutoLayer;
            case _: 0;
        }

    }

    public function toString() {

        var value:LdtkLayerType = this;
        return 'LdtkLayerType.' + switch value {
            case IntGrid: 'IntGrid';
            case Entities: 'Entities';
            case Tiles: 'Tiles';
            case AutoLayer: 'AutoLayer';
            case _: '_';
        }

    }

}

/**
 * Defines a layer type that can be used in levels.
 *
 * Layers can be:
 * - IntGrid: Integer grid for collision maps, zones, etc.
 * - Entities: Container for entity instances
 * - Tiles: Manual tile placement
 * - AutoLayer: Rule-based automatic tile placement
 */
class LdtkLayerDefinition {

    /**
     * The `LdtkDefinitions` object this layer def belongs to
     */
    public var defs:LdtkDefinitions;

    /**
     * Type of the layer (IntGrid, Entities, Tiles or AutoLayer)
     */
    public var type:LdtkLayerType;

    /**
     * Only auto-layers
     */
    public var autoSourceLayerDefUid:Int;

    /**
     * Opacity of the layer (0 to 1.0)
     */
    public var displayOpacity:Float;

    /**
     * Width and height of the grid in pixels
     */
    public var gridSize:Int;

    /**
     * User defined unique identifier
     */
    public var identifier:String;

    /**
     * An array that defines extra optional info for each IntGrid value.
     * WARNING: the array order is not related to actual IntGrid values!
     * As user can re-order IntGrid values freely, you may value "2" before value "1" in this array.
     */
    public var intGridValues:Array<LdtkIntGridValue>;

    /**
     * Parallax horizontal factor (from -1 to 1, defaults to 0) which affects the scrolling speed of this layer, creating a fake 3D (parallax) effect.
     */
    public var parallaxFactorX:Float = 0;

    /**
     * Parallax vertical factor (from -1 to 1, defaults to 0) which affects the scrolling speed of this layer, creating a fake 3D (parallax) effect.
     */
    public var parallaxFactorY:Float = 0;

    /**
     * If true (default), a layer with a parallax factor will also be scaled up/down accordingly.
     */
    public var parallaxScaling:Bool = true;

    /**
     * X offset of the layer, in pixels (IMPORTANT: this should be added to the `LdtkLayerInstance` optional offset)
     */
    public var pxOffsetX:Int;

    /**
     * Y offset of the layer, in pixels (IMPORTANT: this should be added to the `LdtkLayerInstance` optional offset)
     */
    public var pxOffsetY:Int;

    /**
     * Reference to the default Tileset UID being used by this layer definition.
     * WARNING: some layer instances might use a different tileset. So most of the time, you should probably use the `tilesetDefUid` value found in layer instances.
     * Note: since version 1.0.0, the old `autoTilesetDefUid` was removed and merged into this value.
     */
    public var tilesetDefUid:Int;

    /**
     * Unique Int identifier
     */
    public var uid:Int;

    /**
     * Contains all the auto-layer rule definitions.
     */
    public var autoRuleGroups:Array<LdtkAutoRuleGroup>;

    /**
     * If the tiles are smaller or larger than the layer grid,
     * the pivot value will be used to position the tile relatively its grid cell.
     */
    public var tilePivotX:Float;

    /**
     * If the tiles are smaller or larger than the layer grid,
     * the pivot value will be used to position the tile relatively its grid cell.
     */
    public var tilePivotY:Float;

    public function new(?defs:LdtkDefinitions, ?json:DynamicAccess<Dynamic>) {

        this.defs = defs;

        if (json != null) {
            type = LdtkLayerType.fromString(json.get('__type'));
            autoSourceLayerDefUid = json.get('autoSourceLayerDefUid') != null ? Std.int(json.get('autoSourceLayerDefUid')) : -1;
            displayOpacity = json.get('displayOpacity');
            gridSize = Std.int(json.get('gridSize'));
            identifier = json.get('identifier');

            var intGridValuesJson:Array<Dynamic> = json.get('intGridValues');
            intGridValues = intGridValuesJson != null ? [for (i in 0...intGridValuesJson.length) {
                new LdtkIntGridValue(intGridValuesJson[i]);
            }] : [];

            parallaxFactorX = json.get('parallaxFactorX');
            parallaxFactorY = json.get('parallaxFactorY');
            parallaxScaling = json.get('parallaxScaling');
            pxOffsetX = Std.int(json.get('pxOffsetX'));
            pxOffsetY = Std.int(json.get('pxOffsetY'));
            tilesetDefUid = json.get('tilesetDefUid') != null ? Std.int(json.get('tilesetDefUid')) : -1;
            uid = Std.int(json.get('uid'));

            var autoRuleGroupsJson:Array<Dynamic> = json.get('autoRuleGroups');
            autoRuleGroups = autoRuleGroupsJson != null ? [for (i in 0...autoRuleGroupsJson.length) {
                new LdtkAutoRuleGroup(autoRuleGroupsJson[i]);
            }] : [];

            tilePivotX = json.get('tilePivotX');
            tilePivotY = json.get('tilePivotY');
        }

    }

    public function autoRuleGroup(name:String):LdtkAutoRuleGroup {

        if (this.autoRuleGroups != null) {
            for (i in 0...this.autoRuleGroups.length) {
                var autoRuleGroup = this.autoRuleGroups[i];
                if (autoRuleGroup.name == name) {
                    return autoRuleGroup;
                }
            }
        }

        return null;

    }

    public function findRule(uid:Int):LdtkAutoLayerRuleDefinition {

        var ruleGroups = this.autoRuleGroups;
        if (ruleGroups != null) {
            for (i in 0...ruleGroups.length) {
                var ruleGroup = ruleGroups[i];
                if (ruleGroup != null && ruleGroup.rules != null) {
                    var rules = ruleGroup.rules;
                    for (j in 0...rules.length) {
                        var rule = rules[j];
                        if (rule.uid == uid) {
                            return rule;
                        }
                    }
                }
            }
        }

        return null;

    }

    public function toString() {

        if (LdtkDataHelpers.beginObjectToString(this)) {
            var res = 'LdtkLayerDefinition' + LdtkDataHelpers.objectToString({
                type: ''+type,
                autoSourceLayerDefUid: ''+autoSourceLayerDefUid,
                displayOpacity: ''+displayOpacity,
                gridSize: ''+gridSize,
                identifier: ''+identifier,
                intGridValues: ''+intGridValues,
                parallaxFactorX: ''+parallaxFactorX,
                parallaxFactorY: ''+parallaxFactorY,
                parallaxScaling: ''+parallaxScaling,
                pxOffsetX: ''+pxOffsetX,
                pxOffsetY: ''+pxOffsetY,
                autoRuleGroups: ''+autoRuleGroups,
                tilePivotX: ''+tilePivotX,
                tilePivotY: ''+tilePivotY
            });
            LdtkDataHelpers.endObjectToString();
            return res;
        }
        else {
            return LdtkDataHelpers.HIDDEN_VALUE;
        }

    }

}

class LdtkFieldDefinition {

    /**
     * The `LdtkDefinitions` object this field def belongs to
     */
    public var defs:LdtkDefinitions;

    /**
     * Human readable value type. Possible values: `Int, Float, String, Bool, Color, ExternEnum.XXX, LocalEnum.XXX, Point, FilePath`
     */
    public var type:String;

    /**
     * User defined unique identifier
     */
    public var identifier:String;

    /**
     * Unique Int identifier
     */
    public var uid:Int;

    /**
     * `true` if the value is an array of multiple values
     */
    public var isArray:Bool;

    public function new(?defs:LdtkDefinitions, ?json:DynamicAccess<Dynamic>) {

        this.defs = defs;

        if (json != null) {
            type = json.get('__type');
            identifier = json.get('identifier');
            uid = Std.int(json.get('uid'));
            isArray = json.get('isArray');
        }

    }

    public function toString() {

        if (LdtkDataHelpers.beginObjectToString(this)) {
            var res = 'LdtkFieldDefinition' + LdtkDataHelpers.objectToString({
                type: ''+type,
                identifier: ''+identifier,
                uid: ''+uid,
                isArray: ''+isArray
            });
            LdtkDataHelpers.endObjectToString();
            return res;
        }
        else {
            return LdtkDataHelpers.HIDDEN_VALUE;
        }

    }

}

class LdtkTilesetDefinition {

    /**
     * The `LdtkDefinitions` object this tileset belongs to
     */
    public var defs:LdtkDefinitions;

    /**
     * The Ceramic tileset generated from this tileset
     */
    public var ceramicTileset:Tileset = null;

    /**
     * Grid-based height
     */
    public var cHei:Int;

    /**
     * Grid-based width
     */
    public var cWid:Int;

    /**
     * An array of custom tile metadata
     */
    public var customData:Array<LdtkTileCustomData>;

    /**
     * If this value isn't `None`, then it means that this atlas uses an internal LDtk atlas image instead of a loaded one.
     */
    public var embedAtlas:LdtkEmbedAtlas;

    /**
     * Tileset tags using Enum values specified by tagsSourceEnumId. This array contains 1 element per Enum value, which contains an array of all Tile IDs that are tagged with it.
     */
    public var enumTags:Array<LdtkEnumTag>;

    /**
     * User defined unique identifier
     */
    public var identifier:String;

    /**
     * Distance in pixels from image borders
     */
    public var padding:Int;

    /**
     * Image height in pixels
     */
    public var pxHei:Int;

    /**
     * Image width in pixels
     */
    public var pxWid:Int;

    /**
     * Path to the source file, relative to the current project JSON file
     * It can be null if no image was provided, or when using an embed atlas.
     */
    public var relPath:String;

    /**
     * Space in pixels between all tiles
     */
    public var spacing:Int;

    /**
     * An array of user-defined tags to organize the Tilesets
     */
    public var tags:Array<String>;

    /**
     * Optional Enum definition UID used for this tileset meta-data
     */
    public var tagsSourceEnumUid:Int;

    /**
     * The size of a tile in this tileset
     */
    public var tileGridSize:Int;

    /**
     * Unique Int identifier
     */
    public var uid:Int;

    /**
     * Array of colors (with alpha) for this tileset tiles.
     * Can be useful to know if a tile is opaque or not.
     */
    public var averageColors:Array<AlphaColor> = null;

    public function new(?defs:LdtkDefinitions, ?json:DynamicAccess<Dynamic>) {

        this.defs = defs;

        if (json != null) {
            cHei = Std.int(json.get('__cHei'));
            cWid = Std.int(json.get('__cWid'));

            var customDataJson:Array<Dynamic> = json.get('customData');
            customData = customDataJson != null ? [for (i in 0...customDataJson.length) {
                new LdtkTileCustomData(customDataJson[i]);
            }] : [];

            embedAtlas = LdtkEmbedAtlas.fromString(json.get('embedAtlas'));

            var enumTagsJson:Array<Dynamic> = json.get('enumTags');
            enumTags = enumTagsJson != null ? [for (i in 0...enumTagsJson.length) {
                new LdtkEnumTag(enumTagsJson[i]);
            }] : [];

            identifier = json.get('identifier');
            padding = Std.int(json.get('padding'));
            pxHei = Std.int(json.get('pxHei'));
            pxWid = Std.int(json.get('pxWid'));
            relPath = json.get('relPath');
            spacing = Std.int(json.get('spacing'));
            tags = LdtkDataHelpers.toStringArray(json.get('tags'));
            tagsSourceEnumUid = json.get('tagsSourceEnumUid') != null ? Std.int(json.get('tagsSourceEnumUid')) : -1;
            tileGridSize = Std.int(json.get('tileGridSize'));
            uid = Std.int(json.get('uid'));

            if (json.get('cachedPixelData') != null) {
                var cachedPixelDataJson:DynamicAccess<Dynamic> = json.get('cachedPixelData');
                if (cachedPixelDataJson.get('averageColors') != null) {
                    var averageColorsStr:String = cachedPixelDataJson.get('averageColors');
                    var c:Int = 0;
                    var len:Int = averageColorsStr.length;
                    averageColors = [];
                    while (c < len) {

                        var a = LdtkDataHelpers.colorValueFromCharCode(averageColorsStr.charCodeAt(c));
                        c++;
                        var r = LdtkDataHelpers.colorValueFromCharCode(averageColorsStr.charCodeAt(c));
                        c++;
                        var g = LdtkDataHelpers.colorValueFromCharCode(averageColorsStr.charCodeAt(c));
                        c++;
                        var b = LdtkDataHelpers.colorValueFromCharCode(averageColorsStr.charCodeAt(c));
                        c++;

                        var color = AlphaColor.fromRGBA(r, g, b, a);
                        averageColors.push(color);
                    }
                }
            }
        }

    }

    public function tileIdByCustomData(data:String):Int {

        if (this.customData != null) {
            for (i in 0...this.customData.length) {
                var aData = this.customData[i];
                if (aData.data == data) {
                    return aData.tileId;
                }
            }
        }

        return -1;

    }

    inline public function averageColor(tileId:Int):AlphaColor {

        return averageColors != null && averageColors.length > tileId ? averageColors[tileId] : AlphaColor.NONE;

    }

    public function toString() {

        if (LdtkDataHelpers.beginObjectToString(this)) {
            var res = 'LdtkTilesetDefinition' + LdtkDataHelpers.objectToString({
                cHei: ''+cHei,
                cWid: ''+cWid,
                embedAtlas: ''+embedAtlas,
                enumTags: ''+enumTags,
                identifier: ''+identifier,
                padding: ''+padding,
                pxHei: ''+pxHei,
                pxWid: ''+pxWid,
                relPath: ''+relPath,
                spacing: ''+spacing,
                tags: ''+tags,
                tagsSourceEnumUid: ''+tagsSourceEnumUid,
                tileGridSize: ''+tileGridSize,
                uid: ''+uid
            });
            LdtkDataHelpers.endObjectToString();
            return res;
        }
        else {
            return LdtkDataHelpers.HIDDEN_VALUE;
        }

    }

}

class LdtkTileCustomData {

    public var data:String;

    public var tileId:Int;

    public function new(?json:DynamicAccess<Dynamic>) {

        if (json != null) {
            data = json.get('data');
            tileId = Std.int(json.get('tileId'));
        }

    }

    public function toString() {

        if (LdtkDataHelpers.beginObjectToString(this)) {
            var res = 'LdtkTileCustomData' + LdtkDataHelpers.objectToString({
                data: ''+data,
                tileId: ''+tileId
            });
            LdtkDataHelpers.endObjectToString();
            return res;
        }
        else {
            return LdtkDataHelpers.HIDDEN_VALUE;
        }

    }

}

enum abstract LdtkEmbedAtlas(Int) from Int to Int {

    /**
     * No embedded atlas - external image files are used for tilesets
     */
    var None = 0;

    /**
     * Uses LDtk's internal embedded atlas containing built-in icons and sprites
     */
    var LdtkIcons = 1;

    public static function fromString(str:String):LdtkEmbedAtlas {

        return switch str {
            case 'None': None;
            case 'LdtkIcons': LdtkIcons;
            case _: 0;
        }

    }

    public function toString() {

        var value:LdtkEmbedAtlas = this;
        return 'LdtkEmbedAtlas.' + switch value {
            case None: 'None';
            case LdtkIcons: 'LdtkIcons';
            case _: '_';
        }

    }

}

class LdtkEnumTag {

    public var enumValueId:String;

    public var tileIds:Array<Int>;

    public function new(?json:DynamicAccess<Dynamic>) {

        if (json != null) {
            enumValueId = json.get('enumValueId');
            tileIds = LdtkDataHelpers.toIntArray(json.get('tileIds'));
        }

    }

    public function toString() {

        if (LdtkDataHelpers.beginObjectToString(this)) {
            var res = 'LdtkEnumTag' + LdtkDataHelpers.objectToString({
                enumValueId: ''+enumValueId,
                tileIds: ''+tileIds
            });
            LdtkDataHelpers.endObjectToString();
            return res;
        }
        else {
            return LdtkDataHelpers.HIDDEN_VALUE;
        }

    }

}

class LdtkAutoRuleGroup {

    public var active:Bool;

    public var isOptional:Bool;

    public var name:String;

    public var rules:Array<LdtkAutoLayerRuleDefinition>;

    public var uid:Int;

    public var usesWizard:Bool;

    public function new(?json:DynamicAccess<Dynamic>) {

        if (json != null) {
            active = json.get('active');
            isOptional = json.get('isOptional');
            name = json.get('name');

            var rulesJson:Array<Dynamic> = json.get('rules');
            rules = rulesJson != null ? [for (i in 0...rulesJson.length) {
                new LdtkAutoLayerRuleDefinition(rulesJson[i]);
            }] : [];

            uid = Std.int(json.get('uid'));
            usesWizard = json.get('usesWizard');
        }

    }

    public function toString() {

        if (LdtkDataHelpers.beginObjectToString(this)) {
            var res = 'LdtkAutoRuleGroup' + LdtkDataHelpers.objectToString({
                active: ''+active,
                isOptional: ''+isOptional,
                name: ''+name,
                rules: ''+rules,
                uid: ''+uid,
                usesWizard: ''+usesWizard
            });
            LdtkDataHelpers.endObjectToString();
            return res;
        }
        else {
            return LdtkDataHelpers.HIDDEN_VALUE;
        }

    }

}

/**
 * This complex section isn't meant to be used by game devs according to LDtk documentation,
 * but Ceramic auto-tiling rules can be generated from these so they may still be useful for us
 * if we want to edit a map in game while still fully working auto-layer rules from LDtk.
 * The use of this is opt-in. Default map loading is using already resolved tiles.
 */
class LdtkAutoLayerRuleDefinition {

    /**
     * If `false`, the rule effect isn't applied, and no tiles are generated.
     */
    public var active:Bool;

    /**
     * When `true`, the rule will prevent other rules to be applied in the same cell if it matches (`true` by default).
     */
    public var breakOnMatch:Bool = true;

    /**
     * Chances for this rule to be applied (0 to 1)
     */
    public var chance:Float;

    /**
     * Checker mode
     */
    public var checker:LdtkCheckerMode;

    /**
     * If `true`, allow rule to be matched by flipping its pattern horizontally
     */
    public var flipX:Bool;

    /**
     * If `true`, allow rule to be matched by flipping its pattern vertically
     */
    public var flipY:Bool;

    /**
     * Default IntGrid value when checking cells outside of level bounds
     */
    public var outOfBoundsValue:Int;

    /**
     * Rule pattern (size x size)
     */
    public var pattern:Array<Int>;

    /**
     * If `true`, enable Perlin filtering to only apply rule on specific random area
     */
    public var perlinActive:Bool;

    public var perlinOctaves:Float;

    public var perlinScale:Float;

    public var perlinSeed:Float;

    /**
     * X pivot of a tile stamp (0-1)
     */
    public var pivotX:Float;

    /**
     * Y pivot of a tile stamp (0-1)
     */
    public var pivotY:Float;

    /**
     * Pattern width & height. Should only be 1,3,5 or 7.
     */
    public var size:Int;

    /**
     * Array of all the tile IDs. They are used randomly or as stamps, based on `tileMode` value.
     */
    public var tileIds:Array<Int>;

    /**
     * Defines how `tileIds` array is used
     */
    public var tileMode:LdtkTileMode;

    /**
     * Unique Int identifier
     */
    public var uid:Int;

    /**
     * X cell coord modulo
     */
    public var xModulo:Int;

    /**
     * X cell start offset
     */
    public var xOffset:Int;

    /**
     * Y cell coord modulo
     */
    public var yModulo:Int;

    /**
     * Y cell start offset
     */
    public var yOffset:Int;

    public function new(?json:DynamicAccess<Dynamic>) {

        if (json != null) {
            active = json.get('active');
            breakOnMatch = json.get('breakOnMatch');
            chance = json.get('chance');
            checker = LdtkCheckerMode.fromString(json.get('checker'));
            flipX = json.get('flipX');
            flipY = json.get('flipY');
            outOfBoundsValue = json.get('outOfBoundsValue') != null ? Std.int(json.get('outOfBoundsValue')) : -1;
            pattern = LdtkDataHelpers.toIntArray(json.get('pattern'));
            perlinActive = json.get('perlinActive');
            perlinOctaves = json.get('perlinOctaves');
            perlinScale = json.get('perlinScale');
            perlinSeed = json.get('perlinSeed');
            pivotX = json.get('pivotX');
            pivotY = json.get('pivotY');
            size = Std.int(json.get('size'));
            tileIds = LdtkDataHelpers.toIntArray(json.get('tileIds'));
            tileMode = LdtkTileMode.fromString(json.get('tileMode'));
            uid = Std.int(json.get('uid'));
            xModulo = Std.int(json.get('xModulo'));
            xOffset = Std.int(json.get('xOffset'));
            yModulo = Std.int(json.get('yModulo'));
            yOffset = Std.int(json.get('yOffset'));
        }

    }

    public function toString() {

        if (LdtkDataHelpers.beginObjectToString(this)) {
            var res = 'LdtkAutoLayerRuleDefinition' + LdtkDataHelpers.objectToString({
                active: ''+active,
                breakOnMatch: ''+breakOnMatch,
                chance: ''+chance,
                checker: ''+checker,
                flipX: ''+flipX,
                flipY: ''+flipY,
                outOfBoundsValue: ''+outOfBoundsValue,
                pattern: ''+pattern,
                perlinActive: ''+perlinActive,
                perlinOctaves: ''+perlinOctaves,
                perlinScale: ''+perlinScale,
                perlinSeed: ''+perlinSeed,
                pivotX: ''+pivotX,
                pivotY: ''+pivotY,
                size: ''+size,
                tileIds: ''+tileIds,
                tileMode: ''+tileMode,
                uid: ''+uid,
                xModulo: ''+xModulo,
                xOffset: ''+xOffset,
                yModulo: ''+yModulo,
                yOffset: ''+yOffset
            });
            LdtkDataHelpers.endObjectToString();
            return res;
        }
        else {
            return LdtkDataHelpers.HIDDEN_VALUE;
        }

    }

}

enum abstract LdtkCheckerMode(Int) from Int to Int {

    /**
     * No checker pattern applied to auto layer rule tiles
     */
    var None = 0;

    /**
     * Horizontal checker pattern for alternating tiles in auto layer rules
     */
    var Horizontal = 1;

    /**
     * Vertical checker pattern for alternating tiles in auto layer rules
     */
    var Vertical = 2;

    public static function fromString(str:String):LdtkCheckerMode {

        return switch str {
            case 'None': None;
            case 'Horizontal': Horizontal;
            case 'Vertical': Vertical;
            case _: 0;
        }

    }

    public function toString() {

        var value:LdtkCheckerMode = this;
        return 'LdtkCheckerMode.' + switch value {
            case None: 'None';
            case Horizontal: 'Horizontal';
            case Vertical: 'Vertical';
            case _: '_';
        }

    }

}

enum abstract LdtkTileMode(Int) from Int to Int {

    /**
     * Single tile mode - uses only one tile ID from the tileIds array
     */
    var Single = 1;

    /**
     * Stamp mode - uses multiple tile IDs from the tileIds array to create a pattern or group
     */
    var Stamp = 2;

    public static function fromString(str:String):LdtkTileMode {

        return switch str {
            case 'Single': Single;
            case 'Stamp': Stamp;
            case _: 0;
        }

    }

    public function toString() {

        var value:LdtkTileMode = this;
        return 'LdtkTileMode.' + switch value {
            case Single: 'Single';
            case Stamp: 'Stamp';
            case _: '_';
        }

    }

}

class LdtkIntGridValue {

    /**
     * Color
     */
    public var color:Color;

    /**
     * User defined unique identifier
     */
    public var identifier:String;

    /**
     * The IntGrid value itself
     */
    public var value:Int;

    public function new(?json:DynamicAccess<Dynamic>) {

        if (json != null) {
            color = Color.fromString(json.get('color'));
            identifier = json.get('identifier');
            value = Std.int(json.get('value'));
        }

    }

    public function toString() {

        if (LdtkDataHelpers.beginObjectToString(this)) {
            var res = 'LdtkIntGridValue' + LdtkDataHelpers.objectToString({
                color: ''+color,
                identifier: ''+identifier,
                value: ''+value
            });
            LdtkDataHelpers.endObjectToString();
            return res;
        }
        else {
            return LdtkDataHelpers.HIDDEN_VALUE;
        }

    }

}

/**
 * Represents a single level in an LDtk world.
 *
 * Contains all the layer instances, entities, and properties for one game level.
 * Levels can reference external data files in multi-file projects.
 *
 * Each level has:
 * - Position in world coordinates
 * - Background settings
 * - Layer instances with tiles and entities
 * - Custom field values
 */
class LdtkLevel {

    /**
     * The `LdtkWorld` object this level belong to
     */
    public var world:LdtkWorld;

    /**
     * The Ceramic tilemap generated from this level
     */
    public var ceramicTilemap:TilemapData = null;

    /**
     * Background color of the level
     */
    public var bgColor:Color;

    /**
     * Position informations of the background image, if there is one. (can be `null`)
     */
    public var bgPos:LdtkBackgroundPosition;

    /**
     * The _optional_ relative path to the level background image. (can be null)
     */
    public var bgRelPath:String;

    /**
     * An array listing all other levels touching this one on the world map.
     * Only relevant for world layouts where level spatial positioning is manual (ie. GridVania, Free). For Horizontal and Vertical layouts, this array is always empty.
     */
    public var neighbours:Array<LdtkLevelNeighbour>;

    /**
     * This value is not null if the project option "Save levels separately" is enabled. In this case, this relative path points to the level Json file.
     */
    public var externalRelPath:String;

    /**
     * An array containing this level custom field values.
     */
    public var fieldInstances:Array<LdtkFieldInstance>;

    /**
     * User defined unique identifier
     */
    public var identifier:String;

    /**
     * Unique instance identifier
     */
    public var iid:String;

    /**
     * An array containing all Layer instances. IMPORTANT: if the project option "Save levels separately" is enabled, this field will be `null`.
     * This array is sorted in display order: the 1st layer is the top-most and the last is behind.
     */
    public var layerInstances:Array<LdtkLayerInstance>;

    /**
     * Width of the level in pixels
     */
    public var pxWid:Int;

    /**
     * Height of the level in pixels
     */
    public var pxHei:Int;

    /**
     * Unique Int identifier
     */
    public var uid:Int;

    /**
     * Index that represents the "depth" of the level in the world. Default is 0, greater means "above", lower means "below".
     * This value is mostly used for display only and is intended to make stacking of levels easier to manage.
     */
    public var worldDepth:Int;

    /**
     * World X coordinate in pixels.
     * Only relevant for world layouts where level spatial positioning is manual (ie. GridVania, Free). For Horizontal and Vertical layouts, the value is always -1 here.
     */
    public var worldX:Int;

    /**
     * World Y coordinate in pixels.
     * Only relevant for world layouts where level spatial positioning is manual (ie. GridVania, Free). For Horizontal and Vertical layouts, the value is always -1 here.
     */
    public var worldY:Int;

    public function new(?ldtkData:LdtkData, ?world:LdtkWorld, ?json:DynamicAccess<Dynamic>) {

        this.world = world;

        if (json != null) {

            bgColor = Color.fromString(json.get('__bgColor'));
            bgPos = json.get('__bgPos') != null ? new LdtkBackgroundPosition(json.get('__bgPos')) : null;
            bgRelPath = json.get('bgRelPath');

            var neighboursJson:Array<Dynamic> = json.get('__neighbours');
            neighbours = neighboursJson != null ? [for (i in 0...neighboursJson.length) {
                new LdtkLevelNeighbour(neighboursJson[i]);
            }] : [];

            externalRelPath = json.get('externalRelPath');

            var fieldInstancesJson:Array<Dynamic> = json.get('fieldInstances');
            fieldInstances = fieldInstancesJson != null ? [for (i in 0...fieldInstancesJson.length) {
                new LdtkFieldInstance(ldtkData, world, fieldInstancesJson[i]);
            }] : [];

            iid = json.get('iid');
            identifier = json.get('identifier');

            pxWid = Std.int(json.get('pxWid'));
            pxHei = Std.int(json.get('pxHei'));
            uid = Std.int(json.get('uid'));
            worldDepth = Std.int(json.get('worldDepth'));
            worldX = Std.int(json.get('worldX'));
            worldY = Std.int(json.get('worldY'));

            var layerInstancesJson:Array<Dynamic> = json.get('layerInstances');
            layerInstances = layerInstancesJson != null ? [for (i in 0...layerInstancesJson.length) {
                new LdtkLayerInstance(this, ldtkData, world, layerInstancesJson[i]);
            }] : null;

        }

    }

    public function ensureLoaded(done:()->Void):Void {

        if (externalRelPath != null && layerInstances == null) {
            if (world != null && world.ldtkData != null && world.ldtkData.loadExternalLevelData != null) {
                world.ldtkData.loadExternalLevelData(externalRelPath, json -> {

                    if (json != null) {

                        var layerInstancesJson:Array<Dynamic> = json.get('layerInstances');
                        layerInstances = layerInstancesJson != null ? [for (i in 0...layerInstancesJson.length) {
                            new LdtkLayerInstance(this, world.ldtkData, world, layerInstancesJson[i]);
                        }] : null;

                        if (world.ldtkData.loadLevelCeramicTilemap != null) {
                            world.ldtkData.loadLevelCeramicTilemap(this);
                        }
                    }
                    else{
                        log.error('Failed to read external level JSON data');
                    }

                    done();

                });
            }
            else {
                log.error('Cannot load external level data because there is no way to load it.');
                done();
            }
        }
        else if (ceramicTilemap == null) {
            if (world.ldtkData.loadLevelCeramicTilemap != null) {
                world.ldtkData.loadLevelCeramicTilemap(this);
            }
            done();
        }
        else {
            done();
        }

    }

    public function unload():Void {

        if (externalRelPath != null && layerInstances != null) {

            layerInstances = null;

            if (ceramicTilemap != null) {
                var _ceramicTilemap = ceramicTilemap;
                ceramicTilemap = null;
                _ceramicTilemap.destroy();
            }

            if (world != null && world.ldtkData != null) {
                world.ldtkData._cleanUnusedEntityInstances();
            }
        }
        else {
            if (ceramicTilemap != null) {
                var _ceramicTilemap = ceramicTilemap;
                ceramicTilemap = null;
                _ceramicTilemap.destroy();
            }
        }

    }

    public function layerInstance(identifier:String):LdtkLayerInstance {

        if (this.layerInstances != null) {
            for (i in 0...this.layerInstances.length) {
                var layerInstance = this.layerInstances[i];
                if (layerInstance.def.identifier == identifier) {
                    return layerInstance;
                }
            }
        }

        return null;

    }

    public function fieldInstance(identifier:String):LdtkFieldInstance {

        if (this.fieldInstances != null) {
            for (i in 0...this.fieldInstances.length) {
                var fieldInstance = this.fieldInstances[i];
                if (fieldInstance.def.identifier == identifier) {
                    return fieldInstance;
                }
            }
        }

        return null;

    }

    /**
     * Walk through every entity instance in the level.
     * Optionally filter by `identifier`. The `callback` will be
     * called for each matching entity instance.
     */
    public extern inline overload function mapEntities(identifier:String, callback:(entity:LdtkEntityInstance)->Void) {
        _mapEntities(identifier, callback);
    }

    /**
     * Walk through every entity instance in the level.
     * Optionally filter by `identifier`. The `callback` will be
     * called for each matching entity instance.
     */
    public extern inline overload function mapEntities(callback:(entity:LdtkEntityInstance)->Void) {
        _mapEntities(null, callback);
    }

    private function _mapEntities(identifier:String, callback:(entity:LdtkEntityInstance)->Void) {

        for (layer in this.layerInstances) {
            if (layer.entityInstances != null) {
                for (entity in layer.entityInstances) {
                    if (identifier == null || entity.def.identifier == identifier) {
                        callback(entity);
                    }
                }
            }
        }

    }

    /**
     * Create visuals for every entity instance in the level.
     * Optionally filter by `identifier`. If provided, the `createVisual` callback
     * will be called for every entity, and this callback can either return a `Visual`
     * instance or `null`.
     *
     * If a visual is created, it will be added at the correct depth
     * in the `tilemap` object, inside the correct `layer`.
     *
     * If `createVisual` is not provided, this method will create instances of `LdtkVisual`,
     * which are built-in visuals that will display entities that are renderable.
     */
    public function createVisualsForEntities(tilemap:Tilemap, ?identifier:String, ?createVisual:(entity:LdtkEntityInstance)->Visual) {

        for (layer in this.layerInstances) {
            var depth:Float = 0;
            if (layer.ceramicLayer != null) {
                var ceramicLayer = tilemap.layer(layer.ceramicLayer.name);
                if (ceramicLayer != null) {
                    if (layer.autoLayerTiles != null) {
                        depth = Math.max(depth, layer.autoLayerTiles.length / 7);
                    }
                    if (layer.gridTiles != null) {
                        depth = Math.max(depth, layer.gridTiles.length / 7);
                    }
                    if (layer.entityInstances != null) {
                        for (entity in layer.entityInstances) {
                            if (identifier == null || entity.def.identifier == identifier) {
                                var visual:Visual = null;
                                if (createVisual == null) {
                                    if (entity.def.isRenderable(Tile)) {
                                        visual = new LdtkVisual(entity);
                                    }
                                }
                                else {
                                    visual = createVisual(entity);
                                }
                                if (visual != null) {
                                    visual.depth = depth++;
                                    ceramicLayer.add(visual);
                                }
                            }
                        }
                    }
                }
                else {
                    log.warning('Cannot create visuals for layer ${layer.ceramicLayer.name} because there is no matching layer visual');
                }
            }
            else {
                log.warning('Cannot create visuals because there is no ceramic layer for LDtk layer ${layer.def.identifier}');
            }
        }

    }

    public function toString() {

        if (LdtkDataHelpers.beginObjectToString(this)) {
            var res = 'LdtkLevel' + LdtkDataHelpers.objectToString({
                bgColor: ''+bgColor,
                bgPos: ''+bgPos,
                bgRelPath: ''+bgRelPath,
                neighbours: ''+neighbours,
                externalRelPath: ''+externalRelPath,
                fieldInstances: ''+fieldInstances,
                identifier: ''+identifier,
                layerInstances: ''+layerInstances,
                pxWid: ''+pxWid,
                pxHei: ''+pxHei,
                uid: ''+uid,
                worldDepth: ''+worldDepth,
                worldX: ''+worldX,
                worldY: ''+worldY
            });
            LdtkDataHelpers.endObjectToString();
            return res;
        }
        else {
            return LdtkDataHelpers.HIDDEN_VALUE;
        }

    }

}

class LdtkBackgroundPosition {

    /**
     * One of 4 float values describing the cropped sub-rectangle of the displayed background image.
     * This cropping happens when original is larger than the level bounds.
     */
    public var cropX:Float;

    /**
     * One of 4 float values describing the cropped sub-rectangle of the displayed background image.
     * This cropping happens when original is larger than the level bounds.
     */
    public var cropY:Float;

    /**
     * One of 4 float values describing the cropped sub-rectangle of the displayed background image.
     * This cropping happens when original is larger than the level bounds.
     */
    public var cropWidth:Float;

    /**
     * One of 4 float values describing the cropped sub-rectangle of the displayed background image.
     * This cropping happens when original is larger than the level bounds.
     */
    public var cropHeight:Float;

    /**
     * Scale X value of the cropped background image, depending on `bgPos` option.
     */
    public var scaleX:Float;

    /**
     * Scale Y value of the cropped background image, depending on `bgPos` option.
     */
    public var scaleY:Float;

    /**
     * X pixel coordinate of the top-left corner of the cropped background image, depending on `bgPos` option.
     */
    public var pxLeft:Int;

    /**
     * Y pixel coordinate of the top-left corner of the cropped background image, depending on `bgPos` option.
     */
    public var pxTop:Int;

    public function new(?json:DynamicAccess<Dynamic>) {

        if (json != null) {
            var cropRect:Array<Float> = json.get('cropRect');
            cropX = cropRect[0];
            cropY = cropRect[1];
            cropWidth = cropRect[2];
            cropHeight = cropRect[3];
            var scale:Array<Float> = json.get('scale');
            scaleX = scale[0];
            scaleY = scale[1];
            var topLeftPx:Array<Int> = LdtkDataHelpers.toIntArray(json.get('topLeftPx'));
            pxLeft = topLeftPx[0];
            pxTop = topLeftPx[1];
        }

    }

    public function toString() {

        if (LdtkDataHelpers.beginObjectToString(this)) {
            var res = 'LdtkBackgroundPosition' + LdtkDataHelpers.objectToString({
                cropX: ''+cropX,
                cropY: ''+cropY,
                cropWidth: ''+cropWidth,
                cropHeight: ''+cropHeight,
                scaleX: ''+scaleX,
                scaleY: ''+scaleY,
                pxLeft: ''+pxLeft,
                pxTop: ''+pxTop
            });
            LdtkDataHelpers.endObjectToString();
            return res;
        }
        else {
            return LdtkDataHelpers.HIDDEN_VALUE;
        }

    }

}

class LdtkLevelNeighbour {

    /**
     * The level location (North, South, West, East).
     */
    public var dir:LdtkLevelLocation;

    /**
     * Neighbour Instance Identifier
     */
    public var levelIid:String;

    public function new(?json:DynamicAccess<Dynamic>) {

        if (json != null) {
            dir = LdtkLevelLocation.fromString(json.get('dir'));
            levelIid = json.get('levelIid');
        }

    }

    public function toString() {

        if (LdtkDataHelpers.beginObjectToString(this)) {
            var res = 'LdtkLevelNeighbour' + LdtkDataHelpers.objectToString({
                dir: ''+dir,
                levelIid: ''+levelIid
            });
            LdtkDataHelpers.endObjectToString();
            return res;
        }
        else {
            return LdtkDataHelpers.HIDDEN_VALUE;
        }

    }

}

enum abstract LdtkLevelLocation(Int) from Int to Int {

    /**
     * Level is located to the north (above) of another level
     */
    var North = 1;

    /**
     * Level is located to the west (left) of another level
     */
    var West = 2;

    /**
     * Level is located to the south (below) of another level
     */
    var South = 3;

    /**
     * Level is located to the east (right) of another level
     */
    var East = 4;

    /**
     * Level is located to the northeast (upper-right) of another level
     */
    var NorthEast = 5;

    /**
     * Level is located to the northwest (upper-left) of another level
     */
    var NorthWest = 6;

    /**
     * Level is located to the southeast (lower-right) of another level
     */
    var SouthEast = 7;

    /**
     * Level is located to the southwest (lower-left) of another level
     */
    var SouthWest = 8;

    public static function fromString(str:String):LdtkLevelLocation {

        return switch str {
            case 'North' | 'n': North;
            case 'ne': NorthEast;
            case 'nw': NorthWest;
            case 'West' | 'w': West;
            case 'South' | 's': South;
            case 'se': SouthEast;
            case 'sw': SouthWest;
            case 'East' | 'e': East;
            case _: 0;
        }

    }

    public function toString() {

        var value:LdtkLevelLocation = this;
        return 'LdtkLevelLocation.' + switch value {
            case North: 'North';
            case West: 'West';
            case South: 'South';
            case East: 'East';
            case _: '_';
        }

    }

}

/**
 * An instance of a custom field value.
 *
 * Represents the actual value of a custom field for an entity or level instance.
 * The value can be of various types: Int, Float, String, Bool, Color, Enum, etc.
 */
class LdtkFieldInstance {

    /**
     * The related field definition
     */
    public var def:LdtkFieldDefinition = null;

    /**
     * Actual value of the field instance. The value type varies, depending on `type`.
     * - For classic types (ie. Integer, Float, Boolean, String, Text and FilePath), you just get the actual value with the expected type.
     * - For Color, the value is an int value using `0xRRGGBB` format (a `ceramic.Color` value).
     * - For Enum, the value is a String representing the selected enum value.
     * - For Point, the value is a `ceramic.Point` object.
     * - For Tile, the value is a `LdtkTilesetRectangle` object.
     * - For EntityRef, the value is a corresponding `LdtkEntityInstance` object.
     * If the field is an array, then this value will also be an array.
     */
    public var value:Any;

    /**
     * Optional tileset rectangle used to display this field (this can be the field own Tile, or some other Tile guessed from the value, like an Enum). (can be `null`)
     */
    public var tile:LdtkTilesetRectangle;

    public function new(?ldtkData:LdtkData, ?ldtkWorld:LdtkWorld, ?json:DynamicAccess<Dynamic>, ?def:LdtkFieldDefinition) {

        this.def = def;

        if (json != null) {
            var defUid:Int = Std.int(json.get('defUid'));

            if (ldtkData != null) {
                var fields = ldtkData.defs.levelFields;
                for (i in 0...fields.length) {
                    var field = fields[i];
                    if (field.uid == defUid) {
                        def = field;
                        break;
                    }
                }
            }

            tile = json.get('tile') != null ? new LdtkTilesetRectangle(ldtkData, json.get('tile')) : null;

            var rawValue:Any = json.get('__value');
            var type:String = json.get('__type');
            var isArray = type.startsWith('Array<');

            if (isArray) {
                type = type.substring(6, type.length - 1);
                value = rawValue is Array ? [for (v in cast (rawValue, Array<Dynamic>)) {
                    rawValueToValue(ldtkData, ldtkWorld, v, type);
                }] : null;
            } else {
                value = rawValueToValue(ldtkData, ldtkWorld, rawValue, type);
            }
        }

    }

    static function rawValueToValue(?ldtkData:LdtkData, ?ldtkWorld:LdtkWorld, ?rawValue:Any, ?type:String):Any {
        if (rawValue == null) {
            return null;
        }

        switch type {
            case 'Int' | 'Integer':
                return Std.int(rawValue);
            case 'Float' | 'Bool' | 'Boolean' | 'String' | 'Text' | 'FilePath' | 'Multilines':
                return rawValue;
            case 'Color':
                return Color.fromString(rawValue);
            case 'Point':
                return new Point(Std.int(Reflect.field(rawValue, 'cx')), Std.int(Reflect.field(rawValue, 'cy')));
            case 'Tile':
                return new LdtkTilesetRectangle(ldtkData, rawValue);
            case 'EntityRef':
                return ldtkData != null ? ldtkData._resolveEntityInstance(rawValue, ldtkWorld) : null;
            default:
                return rawValue;
        }
    }

    public function toString() {

        if (LdtkDataHelpers.beginObjectToString(this)) {
            var res = 'LdtkFieldInstance' + LdtkDataHelpers.objectToString({
                identifier: ''+(def != null ? def.identifier : null),
                value: ''+value,
                tile: ''+tile
            });
            LdtkDataHelpers.endObjectToString();
            return res;
        }
        else {
            return LdtkDataHelpers.HIDDEN_VALUE;
        }

    }

}

/**
 * An instance of a layer in a level.
 *
 * Contains the actual tile data, entity instances, and int grid values
 * for this specific layer in this specific level.
 */
class LdtkLayerInstance {

    /**
     * The Ceramic layer generated from this level
     */
    public var ceramicLayer:TilemapLayerData = null;

    /**
     * The LDtk level this layer instance belongs to
     */
    public var level:LdtkLevel = null;

    /**
     * The related layer definition
     */
    public var def:LdtkLayerDefinition = null;

    /**
     * Layer opacity as Float [0-1]
     */
    public var opacity:Float;

    /**
     * Grid-based width
     */
    public var cWid:Int;

    /**
     * Grid-based height
     */
    public var cHei:Int;

    /**
     * Total layer X pixel offset, including both instance and definition offsets.
     */
    public var pxTotalOffsetX:Int;

    /**
     * Total layer Y pixel offset, including both instance and definition offsets.
     */
    public var pxTotalOffsetY:Int;

    /**
     * The corresponding Tileset definition, if any.
     */
    public var tileset:LdtkTilesetDefinition = null;

    /**
     * An array containing all tile info generated by Auto-layer rules. The array is already sorted in display order (ie. 1st tile is beneath 2nd, which is beneath 3rd etc.).
     * Note: if multiple tiles are stacked in the same cell as the result of different rules, all tiles behind opaque ones will be discarded.
     * One tile is stored into 7 int values:
     *
     * [0] The Tile ID in the corresponding tileset.
     *
     * [1] "Flip bits", a 2-bits integer to represent the mirror transformations of the tile.
     *    - Bit 0 = X flip
     *    - Bit 1 = Y flip
     *
     *  Examples: f=0 (no flip), f=1 (X flip only), f=2 (Y flip only), f=3 (both flips)
     *
     * [2] Pixel X coordinate of the tile in the layer. Don't forget optional layer offsets, if they exist!
     *
     * [3] Pixel Y coordinate of the tile in the layer. Don't forget optional layer offsets, if they exist!
     *
     * [4] Pixel X coordinate of the tile in the tileset.
     *
     * [5] Pixel Y coordinate of the tile in the tileset.
     *
     * [6] Pixel alpha [0-4096].
     */
    public var autoLayerTiles:Array<Int>;

    /**
     * Entity instances (only on Entity layers)
     */
    public var entityInstances:Array<LdtkEntityInstance>;

    /**
     * Tile instances (only on Tile layers)
     *
     * One tile is stored into 7 int values:
     *
     * [0] The Tile ID in the corresponding tileset.
     *
     * [1] "Flip bits", a 2-bits integer to represent the mirror transformations of the tile.
     *    - Bit 0 = X flip
     *    - Bit 1 = Y flip
     *
     *  Examples: f=0 (no flip), f=1 (X flip only), f=2 (Y flip only), f=3 (both flips)
     *
     * [2] Pixel X coordinate of the tile in the layer. Don't forget optional layer offsets, if they exist!
     *
     * [3] Pixel Y coordinate of the tile in the layer. Don't forget optional layer offsets, if they exist!
     *
     * [4] Pixel X coordinate of the tile in the tileset.
     *
     * [5] Pixel Y coordinate of the tile in the tileset.
     *
     * [6] Pixel alpha [0-4096].
     */
    public var gridTiles:Array<Int>;

    /**
     * Unique layer instance identifier
     */
    public var iid:String;

    /**
     * A list of all values in the IntGrid layer
     * Order is from left to right, and top to bottom (ie. first row from left to right, followed by second row, etc).
     * 0 means "empty cell" and IntGrid values start at 1.
     * The array size is cWid x cHei cells.
     * (only IntGrid layers)
     */
    public var intGrid:Array<Int>;

    /**
     * Reference to the UID of the level containing this layer instance
     */
    public var levelId:Int;

    /**
     * X offset in pixels to render this layer, usually 0
     * (IMPORTANT: this should be added to the LayerDef optional offset, so you should probably prefer using `pxTotalOffsetX` which contains the total offset value)
     */
    public var pxOffsetX:Int;

    /**
     * Y offset in pixels to render this layer, usually 0
     * (IMPORTANT: this should be added to the LayerDef optional offset, so you should probably prefer using `pxTotalOffsetY` which contains the total offset value)
     */
    public var pxOffsetY:Int;

    /**
     * Layer instance visibility
     */
    public var visible:Bool;

    /**
     * An Array containing the UIDs of optional rules that were enabled in this specific layer instance.
     */
    public var optionalRules:Array<Int>;

    /**
     * Random seed used for Auto-Layers rendering
     */
    public var seed:Int;

    public function new(?level:LdtkLevel, ?ldtkData:LdtkData, ?ldtkWorld:LdtkWorld, ?json:DynamicAccess<Dynamic>) {

        if (json != null) {

            if (level != null)
                this.level = null;

            var uid:Int = Std.int(json.get('layerDefUid'));
            var tilesetDefUid:Int = json.get('__tilesetDefUid') != null ? Std.int(json.get('__tilesetDefUid')) : -1;

            if (ldtkData != null) {
                def = ldtkData.findLayerDef(uid);
                tileset = tilesetDefUid != -1 ? ldtkData.findTilesetDef(tilesetDefUid) : null;

                var entityInstancesJson:Array<Dynamic> = json.get('entityInstances');
                entityInstances = entityInstancesJson != null ? [for (i in 0...entityInstancesJson.length) {
                    ldtkData._resolveEntityInstance(entityInstancesJson[i], ldtkWorld, this);
                }] : null;
            }

            if (def == null)
                log.warning('Missing definition for layer instance with identifier: ${json.get('__identifier')}');

            opacity = json.get('__opacity');
            cWid = Std.int(json.get('__cWid'));
            cHei = Std.int(json.get('__cHei'));
            pxTotalOffsetX = Std.int(json.get('__pxTotalOffsetX'));
            pxTotalOffsetY = Std.int(json.get('__pxTotalOffsetY'));

            var rawAutoLayerTiles:Array<{f:Int,px:Array<Int>,src:Array<Int>,t:Int,d:Array<Int>,a:Float}> = json.get('autoLayerTiles');
            if (rawAutoLayerTiles != null) {
                autoLayerTiles = [];
                for (i in 0...rawAutoLayerTiles.length) {
                    var tile = rawAutoLayerTiles[i];
                    autoLayerTiles.push(Std.int(tile.t));
                    autoLayerTiles.push(Std.int(tile.f));
                    autoLayerTiles.push(Std.int(tile.px[0]));
                    autoLayerTiles.push(Std.int(tile.px[1]));
                    autoLayerTiles.push(Std.int(tile.src[0]));
                    autoLayerTiles.push(Std.int(tile.src[1]));
                    autoLayerTiles.push(Math.round((tile.a ?? 1.0) * 4096));
                }
            }
            else {
                autoLayerTiles = null;
            }

            var rawGridTiles:Array<{f:Int,px:Array<Int>,src:Array<Int>,t:Int,a:Float}> = json.get('gridTiles');
            if (rawGridTiles != null) {
                gridTiles = [];
                for (i in 0...rawGridTiles.length) {
                    var tile = rawGridTiles[i];
                    gridTiles.push(Std.int(tile.t));
                    gridTiles.push(Std.int(tile.f));
                    gridTiles.push(Std.int(tile.px[0]));
                    gridTiles.push(Std.int(tile.px[1]));
                    gridTiles.push(Std.int(tile.src[0]));
                    gridTiles.push(Std.int(tile.src[1]));
                    gridTiles.push(Math.round((tile.a ?? 1.0) * 4096));
                }
            }
            else {
                gridTiles = null;
            }

            iid = json.get('iid');
            intGrid = json.get('intGridCsv') != null ? LdtkDataHelpers.toIntArray(json.get('intGridCsv')) : null;
            levelId = Std.int(json.get('levelId'));
            pxOffsetX = Std.int(json.get('pxOffsetX'));
            pxOffsetY = Std.int(json.get('pxOffsetY'));
            visible = json.get('visible');
            optionalRules = json.get('optionalRules') != null ? LdtkDataHelpers.toIntArray(json.get('optionalRules')) : null;
            seed = Std.int(json.get('seed'));
        }

    }

    public function toString() {

        if (LdtkDataHelpers.beginObjectToString(this)) {
            var res = 'LdtkLayerInstance' + LdtkDataHelpers.objectToString({
                def: ''+def,
                tileset: ''+tileset,
                opacity: ''+opacity,
                pxTotalOffsetX: ''+pxTotalOffsetX,
                pxTotalOffsetY: ''+pxTotalOffsetY,
                autoLayerTiles: ''+autoLayerTiles,
                gridTiles: ''+gridTiles,
                iid: ''+iid,
                intGrid: ''+intGrid,
                levelId: ''+levelId,
                pxOffsetX: ''+pxOffsetX,
                pxOffsetY: ''+pxOffsetY,
                visible: ''+visible,
                optionalRules: ''+optionalRules,
                seed: ''+seed
            });
            LdtkDataHelpers.endObjectToString();
            return res;
        }
        else {
            return LdtkDataHelpers.HIDDEN_VALUE;
        }

    }

}

/**
 * An instance of an entity placed in a level.
 *
 * Contains the entity's position, size, field values, and tile information.
 * This is the actual game object data as opposed to the entity definition.
 */
class LdtkEntityInstance {

    /**
     * The related entity definition
     */
    public var def:LdtkEntityDefinition = null;

    /**
     * The layer instance this entity instance belongs to
     */
    public var layerInstance:LdtkLayerInstance = null;

    /**
     * Grid-based X coordinate
     */
    public var gridX:Int;

    /**
     * Grid-based Y coordinate
     */
    public var gridY:Int;

    /**
     * Pixel X coordinate
     */
    public var pxX:Int;

    /**
     * Pixel Y coordinate
     */
    public var pxY:Int;

    /**
     * An array of all custom fields and their values.
     */
    public var fieldInstances:Array<LdtkFieldInstance>;

    /**
     * Entity width in pixels. For non-resizable entities, it will be the same as Entity definition.
     */
    public var width:Int;

    /**
     * Entity height in pixels. For non-resizable entities, it will be the same as Entity definition.
     */
    public var height:Int;

    /**
     * Unique instance identifier
     */
    public var iid:String;

    public function new(?ldtkData:LdtkData, ?ldtkWorld:LdtkWorld, ?json:DynamicAccess<Dynamic>, ?register:(entity:LdtkEntityInstance, json:DynamicAccess<Dynamic>)->Void) {

        if (register != null) {
            register(this, json);
        }

        if (json != null) {

            width = Std.int(json.get('width'));
            height = Std.int(json.get('height'));
            iid = json.get('iid');

            var uid:Int = Std.int(json.get('defUid'));

            if (ldtkData != null) {
                def = ldtkData.findEntityDef(uid);
            }

            if (def == null)
                log.warning('Missing definition for entity instance with identifier: ${json.get('__identifier')} / ldtkData null? ${ldtkData == null}');

            var grid = LdtkDataHelpers.toIntArray(json.get('__grid'));
            gridX = Std.int(grid[0]);
            gridY = Std.int(grid[1]);

            var px = LdtkDataHelpers.toIntArray(json.get('px'));
            pxX = Std.int(px[0]);
            pxY = Std.int(px[1]);

            var fieldInstancesJson:Array<Dynamic> = json.get('fieldInstances');
            fieldInstances = fieldInstancesJson != null ? [for (i in 0...fieldInstancesJson.length) {
                var fieldInstanceJson:haxe.DynamicAccess<Dynamic> = fieldInstancesJson[i];
                var identifier = fieldInstanceJson.get('__identifier');
                new LdtkFieldInstance(ldtkData, ldtkWorld, fieldInstanceJson, def.fieldDef(identifier));
            }] : [];
        }

    }

    public function fieldInstance(identifier:String):Null<LdtkFieldInstance> {

        if (this.fieldInstances != null) {
            for (i in 0...this.fieldInstances.length) {
                var inst = this.fieldInstances[i];
                if (inst.def.identifier == identifier) {
                    return inst;
                }
            }
        }

        return null;

    }

    public function toString() {

        if (LdtkDataHelpers.beginObjectToString(this)) {
            var res = 'LdtkEntityInstance' + LdtkDataHelpers.objectToString({
                identifier: def != null && def.identifier != null ? def.identifier : '',
                def: ''+def,
                gridX: ''+gridX,
                gridY: ''+gridY,
                pxX: ''+pxX,
                pxY: ''+pxY,
                fieldInstances: ''+fieldInstances,
                width: ''+width,
                height: ''+height,
                iid: ''+iid,
            });
            LdtkDataHelpers.endObjectToString();
            return res;
        }
        else {
            return LdtkDataHelpers.HIDDEN_VALUE;
        }

    }

}

// class LdtkEntityReference {

//     /**
//      * IID of the refered LdtkEntityInstance
//      */
//     public var entityIid:String;

//     /**
//      * IID of the LayerInstance containing the refered LdtkEntityInstance
//      */
//     public var layerIid:String;

//     /**
//      * IID of the Level containing the refered LdtkEntityInstance
//      */
//     public var levelIid:String;

//     /**
//      * IID of the World containing the refered EntityInstance
//      */
//     public var worldIid:String;

//     public function new(?ldtkData:LdtkData, ?json:DynamicAccess<Dynamic>) {

//         if (json != null) {
//             entityIid = json.get('entityIid');
//             layerIid = json.get('layerIid');
//             levelIid = json.get('levelIid');
//             worldIid = json.get('worldIid');
//         }

//     }

//     public function toString() {

//         return 'LdtkEntityReference' + LdtkDataHelpers.objectToString({
//             entityIid: ''+entityIid,
//             layerIid: ''+layerIid,
//             levelIid: ''+levelIid,
//             worldIid: ''+worldIid
//         });

//     }

// }

@:noCompletion
/**
 * Helper utilities for LDtk data manipulation.
 *
 * Provides methods for:
 * - Converting colors between formats
 * - Managing circular reference detection in toString methods
 * - Other utility functions
 */
class LdtkDataHelpers {

    public static var TO_STRING_MAX_ITEM_LENGTH:Int = 128;

    public static final HIDDEN_VALUE:String = '...';

    public static function toIntArray(raw:Dynamic) {
        var value:Array<Dynamic> = raw;
        var result:Array<Int> = [];
        if (value != null) {
            for (i in 0...value.length) {
                result.push(Std.int(value[i]));
            }
        }
        return result;
    }

    public static function toFloatArray(raw:Dynamic) {
        var value:Array<Dynamic> = raw;
        var result:Array<Float> = [];
        if (value != null) {
            for (i in 0...value.length) {
                result.push(value[i]);
            }
        }
        return result;
    }

    public static function toStringArray(raw:Dynamic) {
        var value:Array<Dynamic> = raw;
        var result:Array<String> = [];
        if (value != null) {
            for (i in 0...value.length) {
                result.push(value[i]);
            }
        }
        return result;
    }

    static var _objectToStringList:Array<Any> = null;

    static var _objectToStringCount:Int = 0;

    public static function beginObjectToString(obj:Any):Bool {

        var alreadyUsed:Bool = false;

        if (_objectToStringCount == 0) {
            _objectToStringList = [];
        }
        else {
            alreadyUsed = (_objectToStringList.indexOf(obj) != -1);
        }

        if (alreadyUsed) {
            return false;
        }
        else {
            _objectToStringCount++;
            return true;
        }

    }

    public static function endObjectToString() {
        _objectToStringCount--;
        if (_objectToStringCount == 0) {
            _objectToStringList = null;
        }
    }

    public static function objectToString(raw:Dynamic<String>) {
        var result = new StringBuf();
        var numItems = 0;
        result.add('(');
        for (key in Reflect.fields(raw)) {
            if (numItems++ > 0)
                result.add(' ');
            var val:String = Reflect.field(raw, key);
            if (val.length <= TO_STRING_MAX_ITEM_LENGTH) {
                result.add(key);
                result.add('=');
                result.add(val);
            }
            else {
                result.add(key);
                result.add('=');
                result.add(HIDDEN_VALUE);
            }
        }
        result.add(')');
        return result.toString();
    }

    #if !ceramic_soft_inline inline #end public static function colorValueFromCharCode(code:Int):Int {
        return switch code {
            case '0'.code: 0x00;
            case '1'.code: 0x11;
            case '2'.code: 0x22;
            case '3'.code: 0x33;
            case '4'.code: 0x44;
            case '5'.code: 0x55;
            case '6'.code: 0x66;
            case '7'.code: 0x77;
            case '8'.code: 0x88;
            case '9'.code: 0x99;
            case 'a'.code | 'A'.code: 0xAA;
            case 'b'.code | 'B'.code: 0xBB;
            case 'c'.code | 'C'.code: 0xCC;
            case 'd'.code | 'D'.code: 0xDD;
            case 'e'.code | 'E'.code: 0xEE;
            case 'f'.code | 'F'.code: 0xFF;
            case _: 0x00;
        }
    }

}

