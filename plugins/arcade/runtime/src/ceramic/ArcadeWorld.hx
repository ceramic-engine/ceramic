package ceramic;

#if plugin_arcade
import arcade.Body;
import arcade.Collidable;
import arcade.SortDirection;
import arcade.Tile;
import ceramic.ArcadeSortGroup;
import ceramic.Group;
#end

using ceramic.Extensions;

class ArcadeWorld #if plugin_arcade extends arcade.World #end {

#if plugin_arcade

    public function new(boundsX:Float, boundsY:Float, boundsWidth:Float, boundsHeight:Float) {

        super(boundsX, boundsY, boundsWidth, boundsHeight);

    }

    override function getCollidableType(element:Collidable):Class<Dynamic> {

        #if js
        var clazz:Class<Collidable> = untyped element.__class__;
        #else
        var clazz = Type.getClass(element);
        #end
        switch clazz {
            case Visual | Quad | Mesh: return Visual;
            case Group: return Group;
            case Body: return Body;
            #if plugin_tilemap
            case Tilemap: return Tilemap;
            case TilemapLayer: return TilemapLayer;
            #end
            case arcade.Group: return arcade.Group;
            default:
                if (Std.isOfType(element, Visual)) {
                    #if plugin_tilemap
                    if (Std.isOfType(element, Tilemap))
                        return Tilemap;
                    if (Std.isOfType(element, TilemapLayer))
                        return TilemapLayer;
                    #end
                    return Visual;
                }
                if (Std.isOfType(element, Group))
                    return Group;
                if (Std.isOfType(element, Body))
                    return Body;
                if (Std.isOfType(element, arcade.Group))
                    return arcade.Group;
                return clazz;
        }

    }

    override function overlap(element1:Collidable, ?element2:Collidable, ?overlapCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (element2 == null) {
            return switch getCollidableType(element1) {
                case Group: overlapCeramicGroupVsItself(cast element1, overlapCallback, processCallback);
                default: false;
            }
        }
        else {
            switch getCollidableType(element1) {
                default:
                case Visual:
                    switch getCollidableType(element2) {
                        default:
                        case Visual:
                            var visual1:Visual = cast element1;
                            var visual2:Visual = cast element2;
                            return overlapBodyVsBody(visual1.body, visual2.body, overlapCallback, processCallback);
                        case Group:
                            var visual1:Visual = cast element1;
                            return overlapBodyVsCeramicGroup(visual1.body, cast element2, overlapCallback, processCallback);
                        case arcade.Group:
                            var visual1:Visual = cast element1;
                            return overlapBodyVsGroup(visual1.body, cast element2, overlapCallback, processCallback);
                        case Body:
                            var visual1:Visual = cast element1;
                            return overlapBodyVsBody(visual1.body, cast element2, overlapCallback, processCallback);
                        #if plugin_tilemap
                        case Tilemap:
                            var visual1:Visual = cast element1;
                            return overlapBodyVsTilemap(visual1.body, cast element2, overlapCallback, processCallback);
                        case TilemapLayer:
                            var visual1:Visual = cast element1;
                            return overlapBodyVsTilemapLayer(visual1.body, cast element2, overlapCallback, processCallback);
                        #end
                    }
                case Group:
                    switch getCollidableType(element2) {
                        default:
                        case Visual:
                            var visual2:Visual = cast element2;
                            return overlapBodyVsCeramicGroup(visual2.body, cast element1, overlapCallback, processCallback);
                        case Group:
                            return overlapCeramicGroupVsCeramicGroup(cast element1, cast element2, overlapCallback, processCallback);
                        case arcade.Group:
                            return overlapCeramicGroupVsArcadeGroup(cast element1, cast element2, overlapCallback, processCallback);
                        case Body:
                            return overlapBodyVsCeramicGroup(cast element2, cast element1, overlapCallback, processCallback);
                        #if plugin_tilemap
                        case Tilemap:
                            return overlapCeramicGroupVsTilemap(cast element1, cast element2, overlapCallback, processCallback);
                        case TilemapLayer:
                            return overlapCeramicGroupVsTilemapLayer(cast element1, cast element2, overlapCallback, processCallback);
                        #end
                    }
                case arcade.Group:
                    switch getCollidableType(element2) {
                        default:
                        case Visual:
                            var visual2:Visual = cast element2;
                            return overlapBodyVsGroup(visual2.body, cast element1, overlapCallback, processCallback);
                        case Group:
                            return overlapCeramicGroupVsArcadeGroup(cast element2, cast element1, overlapCallback, processCallback);
                        case arcade.Group:
                            return overlapGroupVsGroup(cast element1, cast element2, overlapCallback, processCallback);
                        case Body:
                            return overlapBodyVsGroup(cast element2, cast element1, overlapCallback, processCallback);
                        #if plugin_tilemap
                        case Tilemap:
                            return overlapArcadeGroupVsTilemap(cast element1, cast element2, overlapCallback, processCallback);
                        case TilemapLayer:
                            return overlapArcadeGroupVsTilemapLayer(cast element1, cast element2, overlapCallback, processCallback);
                        #end
                    }
                case Body:
                    switch getCollidableType(element2) {
                        default:
                        case Visual:
                            var visual2:Visual = cast element2;
                            return overlapBodyVsBody(cast element1, visual2.body, overlapCallback, processCallback);
                        case Group:
                            return overlapBodyVsCeramicGroup(cast element1, cast element2, overlapCallback, processCallback);
                        case arcade.Group:
                            return overlapBodyVsGroup(cast element1, cast element2, overlapCallback, processCallback);
                        case Body:
                            return overlapBodyVsBody(cast element1, cast element2, overlapCallback, processCallback);
                        #if plugin_tilemap
                        case Tilemap:
                            return overlapBodyVsTilemap(cast element1, cast element2, overlapCallback, processCallback);
                        case TilemapLayer:
                            return overlapBodyVsTilemapLayer(cast element1, cast element2, overlapCallback, processCallback);
                        #end
                    }
                #if plugin_tilemap
                case Tilemap:
                    switch getCollidableType(element2) {
                        default:
                        case Visual:
                            var visual2:Visual = cast element2;
                            return overlapBodyVsTilemap(visual2.body, cast element1, overlapCallback, processCallback);
                        case Group:
                            return overlapCeramicGroupVsTilemap(cast element2, cast element1, overlapCallback, processCallback);
                        case arcade.Group:
                            return overlapArcadeGroupVsTilemap(cast element2, cast element1, overlapCallback, processCallback);
                        case Body:
                            return overlapBodyVsTilemap(cast element2, cast element1, overlapCallback, processCallback);
                    }
                case TilemapLayer:
                    switch getCollidableType(element2) {
                        default:
                        case Visual:
                            var visual2:Visual = cast element2;
                            return overlapBodyVsTilemapLayer(visual2.body, cast element1, overlapCallback, processCallback);
                        case Group:
                            return overlapCeramicGroupVsTilemapLayer(cast element2, cast element1, overlapCallback, processCallback);
                        case arcade.Group:
                            return overlapArcadeGroupVsTilemapLayer(cast element2, cast element1, overlapCallback, processCallback);
                        case Body:
                            return overlapBodyVsTilemapLayer(cast element2, cast element1, overlapCallback, processCallback);
                    }
                #end
            }
            return super.overlap(element1, element2, overlapCallback, processCallback);
        }

    }

    function overlapCeramicGroupVsCeramicGroup(group1:Group<Visual>, group2:Group<Visual>, ?overlapCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group1.sortDirection != NONE && (group1.sortDirection != INHERIT || sortDirection != NONE)) {
            sortCeramicGroup(group1);
        }
        if (group2.sortDirection != NONE && (group2.sortDirection != INHERIT || sortDirection != NONE)) {
            sortCeramicGroup(group2);
        }

        _total = 0;

        var objects1 = group1.items;
        var objects2 = group2.items;
        for (i in 0...objects1.length) {
            var body1 = objects1[i].body;
            if (body1 != null) {
                for (j in 0...objects2.length) {
                    var body2 = objects2[j].body;

                    if (body1 != body2 && body2 != null && separate(body1, body2, processCallback, true))
                    {
                        if (overlapCallback != null)
                        {
                            overlapCallback(body1, body2);
                        }

                        _total++;
                    }
                }
            }
        }

        return (_total > 0);

    }

    function overlapCeramicGroupVsArcadeGroup(group1:Group<Visual>, group2:arcade.Group, ?overlapCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group1.sortDirection != NONE && (group1.sortDirection != INHERIT || sortDirection != NONE)) {
            sortCeramicGroup(group1);
        }
        if (group2.sortDirection != NONE && (group2.sortDirection != INHERIT || sortDirection != NONE)) {
            sort(group2);
        }

        _total = 0;

        var objects1 = group1.items;
        var objects2 = group2.objects;
        for (i in 0...objects1.length) {
            var body1 = objects1[i].body;
            if (body1 != null) {
                for (j in 0...objects2.length) {
                    var body2 = objects2[j];

                    if (body1 != body2 && body2 != null && separate(body1, body2, processCallback, true))
                    {
                        if (overlapCallback != null)
                        {
                            overlapCallback(body1, body2);
                        }

                        _total++;
                    }
                }
            }
        }

        return (_total > 0);

    }

    public function overlapCeramicGroupVsItself(group:Group<Visual>, ?overlapCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group.sortDirection != NONE && (group.sortDirection != INHERIT || sortDirection != NONE)) {
            sortCeramicGroup(group);
        }

        _total = 0;

        var objects = group.items;
        for (i in 0...objects.length) {
            var body1 = objects[i].body;
            if (body1 != null) {
                for (j in 0...objects.length) {
                    var body2 = objects[j].body;

                    if (body1 != body2 && body2 != null) {
                        if (separate(body1, body2, processCallback, true))
                        {
                            if (overlapCallback != null)
                            {
                                overlapCallback(body1, body2);
                            }

                            _total++;
                        }
                    }
                }
            }
        }

        return (_total > 0);

    }

    public function overlapBodyVsCeramicGroup(body:Body, group:Group<Visual>, ?overlapCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group.sortDirection != NONE && (group.sortDirection != INHERIT || sortDirection != NONE)) {
            sortCeramicGroup(group);
        }

        _total = 0;

        var objects = group.items;
        var filteredObjects = null;

        var quadTree:arcade.QuadTree = null;
        if (!skipQuadTree && objects.length > maxObjectsWithoutQuadTree) {
            quadTree = getQuadTree();
            for (i in 0...objects.length) {
                var object = objects.unsafeGet(i);
                var aBody = object.body;
                if (aBody != null) {
                    quadTree.insert(aBody);
                }
            }
            filteredObjects = quadTree.retrieve(body.left, body.top, body.right, body.bottom);
        }

        for (i in 0...objects.length) {
            var body2 = filteredObjects != null ? filteredObjects.unsafeGet(i) : objects[i].body;

            if (body != body2 && body2 != null && separate(body, body2, processCallback, true))
            {
                if (overlapCallback != null)
                {
                    overlapCallback(body, body2);
                }

                _total++;
            }
        }

        if (quadTree != null)
            releaseQuadTree(quadTree);

        return (_total > 0);

    }

    // TODO use haxe 4.2 overloads to resolve collidable types
    // at compile time instead of runtime

    // TODO collide with tilemap layers

    override function collide(
        element1:Collidable, ?element2:Collidable,
        ?collideCallback:Body->Body->Void,
        ?processCallback:Body->Body->Bool
        ):Bool {

        // TODO collide ceramic elements with arcade groups

        if (element2 == null) {
            return switch getCollidableType(element1) {
                case Group: collideCeramicGroupVsItself(cast element1, collideCallback, processCallback);
                case arcade.Group: collideGroupVsItself(cast element1, collideCallback, processCallback);
                default: false;
            }
        }
        else {
            switch getCollidableType(element1) {
                default:
                case Visual:
                    switch getCollidableType(element2) {
                        default:
                        case Visual:
                            var visual1:Visual = cast element1;
                            var visual2:Visual = cast element2;
                            return collideBodyVsBody(visual1.body, visual2.body, collideCallback, processCallback);
                        case Group:
                            var visual1:Visual = cast element1;
                            return collideBodyVsCeramicGroup(visual1.body, cast element2, collideCallback, processCallback);
                        case arcade.Group:
                            var visual1:Visual = cast element1;
                            return collideBodyVsGroup(cast element1, cast element2, collideCallback, processCallback);
                        case Body:
                            var visual1:Visual = cast element1;
                            return collideBodyVsBody(visual1.body, cast element2, collideCallback, processCallback);
                        #if plugin_tilemap
                        case Tilemap:
                            var visual1:Visual = cast element1;
                            return collideBodyVsTilemap(visual1.body, cast element2, collideCallback, processCallback);
                        case TilemapLayer:
                            var visual1:Visual = cast element1;
                            return collideBodyVsTilemapLayer(visual1.body, cast element2, collideCallback, processCallback);
                        #end
                    }
                case Group:
                    switch getCollidableType(element2) {
                        default:
                        case Visual:
                            var visual2:Visual = cast element2;
                            return collideBodyVsCeramicGroup(visual2.body, cast element1, collideCallback, processCallback);
                        case Group:
                            return collideCeramicGroupVsCeramicGroup(cast element1, cast element2, collideCallback, processCallback);
                        case arcade.Group:
                            return collideCeramicGroupVsArcadeGroup(cast element1, cast element2, collideCallback, processCallback);
                        case Body:
                            return collideBodyVsCeramicGroup(cast element2, cast element1, collideCallback, processCallback);
                        #if plugin_tilemap
                        case Tilemap:
                            return collideCeramicGroupVsTilemap(cast element1, cast element2, collideCallback, processCallback);
                        case TilemapLayer:
                            return collideCeramicGroupVsTilemapLayer(cast element1, cast element2, collideCallback, processCallback);
                        #end
                    }
                case arcade.Group:
                    switch getCollidableType(element2) {
                        default:
                        case Visual:
                            var visual2:Visual = cast element2;
                            return collideBodyVsGroup(visual2.body, cast element1, collideCallback, processCallback);
                        case Group:
                            return collideCeramicGroupVsArcadeGroup(cast element2, cast element1, collideCallback, processCallback);
                        case arcade.Group:
                            return collideGroupVsGroup(cast element1, cast element2, collideCallback, processCallback);
                        case Body:
                            return collideBodyVsGroup(cast element2, cast element1, collideCallback, processCallback);
                        #if plugin_tilemap
                        case Tilemap:
                            return collideArcadeGroupVsTilemap(cast element1, cast element2, collideCallback, processCallback);
                        case TilemapLayer:
                            return collideArcadeGroupVsTilemapLayer(cast element1, cast element2, collideCallback, processCallback);
                        #end
                    }
                case Body:
                    switch getCollidableType(element2) {
                        default:
                        case Visual:
                            var visual2:Visual = cast element2;
                            return collideBodyVsBody(cast element1, visual2.body, collideCallback, processCallback);
                        case Group:
                            return collideBodyVsCeramicGroup(cast element1, cast element2, collideCallback, processCallback);
                        case arcade.Group:
                            return collideBodyVsGroup(cast element1, cast element2, collideCallback, processCallback);
                        case Body:
                            return collideBodyVsBody(cast element1, cast element2, collideCallback, processCallback);
                        #if plugin_tilemap
                        case Tilemap:
                            return collideBodyVsTilemap(cast element1, cast element2, collideCallback, processCallback);
                        case TilemapLayer:
                            return collideBodyVsTilemapLayer(cast element1, cast element2, collideCallback, processCallback);
                        #end
                    }
                #if plugin_tilemap
                case Tilemap:
                    switch getCollidableType(element2) {
                        default:
                        case Visual:
                            var visual2:Visual = cast element2;
                            return collideBodyVsTilemap(visual2.body, cast element1, collideCallback, processCallback);
                        case Group:
                            return collideCeramicGroupVsTilemap(cast element2, cast element1, collideCallback, processCallback);
                        case arcade.Group:
                            return collideArcadeGroupVsTilemap(cast element2, cast element1, collideCallback, processCallback);
                        case Body:
                            return collideBodyVsTilemap(cast element2, cast element1, collideCallback, processCallback);
                    }
                case TilemapLayer:
                    switch getCollidableType(element2) {
                        default:
                        case Visual:
                            var visual2:Visual = cast element2;
                            return collideBodyVsTilemapLayer(visual2.body, cast element1, collideCallback, processCallback);
                        case Group:
                            return collideCeramicGroupVsTilemapLayer(cast element2, cast element1, collideCallback, processCallback);
                        case arcade.Group:
                            return collideArcadeGroupVsTilemapLayer(cast element2, cast element1, collideCallback, processCallback);
                        case Body:
                            return collideBodyVsTilemapLayer(cast element2, cast element1, collideCallback, processCallback);
                    }
                #end
            }
            return super.collide(element1, element2, collideCallback, processCallback);
        }

    }

    function collideCeramicGroupVsCeramicGroup(group1:Group<Visual>, group2:Group<Visual>, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group1.sortDirection != NONE && (group1.sortDirection != INHERIT || sortDirection != NONE)) {
            sortCeramicGroup(group1);
        }
        if (group2.sortDirection != NONE && (group2.sortDirection != INHERIT || sortDirection != NONE)) {
            sortCeramicGroup(group2);
        }

        _total = 0;

        var objects1 = group1.items;
        var objects2 = group2.items;
        for (i in 0...objects1.length) {
            var body1 = objects1[i].body;
            if (body1 != null) {
                for (j in 0...objects2.length) {
                    var body2 = objects2[j].body;

                    if (body1 != body2 && body2 != null && separate(body1, body2, processCallback, false))
                    {
                        if (collideCallback != null)
                        {
                            collideCallback(body1, body2);
                        }

                        _total++;
                    }
                }
            }
        }

        return (_total > 0);

    }

    function collideCeramicGroupVsArcadeGroup(group1:Group<Visual>, group2:arcade.Group, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group1.sortDirection != NONE && (group1.sortDirection != INHERIT || sortDirection != NONE)) {
            sortCeramicGroup(group1);
        }
        if (group2.sortDirection != NONE && (group2.sortDirection != INHERIT || sortDirection != NONE)) {
            sort(group2);
        }

        _total = 0;

        var objects1 = group1.items;
        var objects2 = group2.objects;
        for (i in 0...objects1.length) {
            var body1 = objects1[i].body;
            if (body1 != null) {
                for (j in 0...objects2.length) {
                    var body2 = objects2[j];

                    if (body1 != body2 && body2 != null && separate(body1, body2, processCallback, false))
                    {
                        if (collideCallback != null)
                        {
                            collideCallback(body1, body2);
                        }

                        _total++;
                    }
                }
            }
        }

        return (_total > 0);

    }

    public function collideCeramicGroupVsItself(group:Group<Visual>, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group.sortDirection != NONE && (group.sortDirection != INHERIT || sortDirection != NONE)) {
            sortCeramicGroup(group);
        }

        _total = 0;

        var objects = group.items;
        for (i in 0...objects.length) {
            var body1 = objects[i].body;
            if (body1 != null) {
                for (j in 0...objects.length) {
                    var body2 = objects[j].body;

                    if (body1 != body2 && body1 != null && body2 != null) {
                        if (separate(body1, body2, processCallback, false))
                        {
                            if (collideCallback != null)
                            {
                                collideCallback(body1, body2);
                            }

                            _total++;
                        }
                    }
                }
            }
        }

        return (_total > 0);

    }

    public function collideBodyVsCeramicGroup(body:Body, group:Group<Visual>, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group.sortDirection != NONE && (group.sortDirection != INHERIT || sortDirection != NONE)) {
            sortCeramicGroup(group);
        }

        _total = 0;

        var objects = group.items;
        var filteredObjects = null;

        var quadTree:arcade.QuadTree = null;
        if (!skipQuadTree && objects.length > maxObjectsWithoutQuadTree) {
            quadTree = getQuadTree();
            for (i in 0...objects.length) {
                var object = objects.unsafeGet(i);
                var aBody = object.body;
                if (aBody != null) {
                    quadTree.insert(aBody);
                }
            }
            filteredObjects = quadTree.retrieve(body.left, body.top, body.right, body.bottom);
        }

        for (i in 0...objects.length) {
            var body2 = filteredObjects != null ? filteredObjects.unsafeGet(i) : objects[i].body;

            if (body != body2 && body2 != null && separate(body, body2, processCallback, false))
            {
                if (collideCallback != null)
                {
                    collideCallback(body, body2);
                }

                _total++;
            }
        }

        if (quadTree != null)
            releaseQuadTree(quadTree);

        return (_total > 0);

    }

#if plugin_tilemap

    public function collideBodyVsTilemap(body:Body, tilemap:Tilemap, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        return inline separateBodyVsTilemap(body, tilemap, collideCallback, processCallback, false);

    }

    public function overlapBodyVsTilemap(body:Body, tilemap:Tilemap, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        return inline separateBodyVsTilemap(body, tilemap, collideCallback, processCallback, true);

    }

    public function collideBodyVsTilemapLayer(body:Body, layer:TilemapLayer, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        return inline separateBodyVsTilemapLayer(body, layer, collideCallback, processCallback, false);

    }

    public function overlapBodyVsTilemapLayer(body:Body, layer:TilemapLayer, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        return inline separateBodyVsTilemapLayer(body, layer, collideCallback, processCallback, true);

    }

    /**
     * A body instance used internally to perform tilemap collisions
     */
    var tileBody:Body = null;

    function separateBodyVsTilemap(body:Body, tilemap:Tilemap, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool, overlapOnly:Bool = false):Bool {

        _total = 0;

        if (tilemap.collidableLayersDirty) {
            tilemap.computeCollidableLayers();
        }

        var layers = tilemap.computedCollidableLayers;
        if (layers != null && layers.length > 0) {

            for (i in 0...layers.length) {
                var layer = layers.unsafeGet(i);

                var total = _total;
                inline separateBodyVsTilemapLayer(body, layer, collideCallback, processCallback, overlapOnly);
                _total += total;
            }
        }

        return (_total > 0);

    }

    function separateBodyVsTilemapLayer(body:Body, layer:TilemapLayer, collideCallback:Body->Body->Void, processCallback:Body->Body->Bool, overlapOnly:Bool) {

        _total = 0;

        if (tileBody == null) {
            tileBody = new Body(0, 0, 1, 1);
            tileBody.immovable = true;
        }

        var layerData = layer.layerData;
        if (layerData != null && layerData.hasTiles) {

            var tilemap:Tilemap = layer.tilemap;

            if (tilemap.collidableLayersDirty) {
                tilemap.computeCollidableLayers();
            }

            var tilemapData:TilemapData = tilemap.tilemapData;
            var layers = tilemap.computedCollidableLayers;
            var tileWidth = layerData.tileWidth;
            var tileHeight = layerData.tileHeight;
            var offsetX = layerData.offsetX + layerData.x * tileWidth;
            var offsetY = layerData.offsetY + layerData.y * tileHeight;

            var minColumn = Math.floor((body.left - offsetX) / tileWidth);
            var maxColumn = Math.ceil((body.right - offsetX) / tileWidth);
            var minRow = Math.floor((body.top - offsetY) / tileHeight);
            var maxRow = Math.ceil((body.bottom - offsetY) / tileHeight);

            if (minColumn < 0)
                minColumn = 0;
            if (maxColumn >= layerData.columns)
                maxColumn = layerData.columns - 1;
            if (minRow < 0)
                minRow = 0;
            if (maxRow >= layerData.rows)
                maxRow = layerData.rows - 1;

            tileBody.checkCollisionUp = layer.checkCollisionUp;
            tileBody.checkCollisionRight = layer.checkCollisionRight;
            tileBody.checkCollisionDown = layer.checkCollisionDown;
            tileBody.checkCollisionLeft = layer.checkCollisionLeft;
            tileBody.checkCollisionNone = !layer.checkCollisionUp && !layer.checkCollisionRight && !layer.checkCollisionDown && !layer.checkCollisionLeft;

            var column = minColumn;
            while (column <= maxColumn) {
                var row = minRow;
                while (row <= maxRow) {
                    var index = row * layerData.columns + column;
                    var tile = layerData.tiles.unsafeGet(index);
                    var gid = tile.gid;
                    if (gid > 0) {

                        // Check if there is a slop assigned to this tile
                        var tileset = tilemapData.tilesetForGid(gid);
                        var slope = tileset.slope(gid);

                        // We reuse the same body for every tile collision
                        tileBody.reset(
                            offsetX + column * tileWidth,
                            offsetY + row * tileHeight,
                            tileWidth,
                            tileHeight
                        );
                        tileBody.index = index;

                        // When being blocked by a wall, prioritize X over Y separation
                        if (body.velocityY < 0 && !body.blockedDown) {
                            var indexBelow = index + layerData.columns;
                            var tileBelow = 0;
                            if (layers != null) {
                                for (n in 0...layers.length) {
                                    var layer = layers.unsafeGet(n);
                                    var layerData = layer.layerData;
                                    if (layerData != null) {
                                        tileBelow = indexBelow < layerData.tiles.length ? layerData.tiles.unsafeGet(indexBelow).gid : 0;
                                        if (tileBelow > 0) {
                                            break;
                                        }
                                    }
                                }
                            }

                            if (tileBelow > 0) {
                                tileBody.forceX = true;
                            }
                            else if (!body.isCircle && intersects(tileBody, body)) {
                                var diffX = Math.max(
                                    Math.abs(tileBody.right - body.left),
                                    Math.abs(tileBody.left - body.right)
                                );
                                var diffY = Math.max(
                                    Math.abs(tileBody.bottom - body.top),
                                    Math.abs(tileBody.top - body.bottom)
                                );
                                tileBody.forceX = diffX > diffY;
                            }
                            else {
                                tileBody.forceX = false;
                            }
                        }
                        else {
                            tileBody.forceX = false;
                        }

                        if (separate(body, tileBody, processCallback, overlapOnly)) {

                            if (collideCallback != null) {
                                collideCallback(body, tileBody);
                            }

                            _total++;
                        }
                    }
                    row++;
                }
                column++;
            }
        }

        return (_total > 0);

    }

    public function collideCeramicGroupVsTilemap(group:Group<Visual>, tilemap:Tilemap, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group.sortDirection != NONE && (group.sortDirection != INHERIT || sortDirection != NONE)) {
            sortCeramicGroup(group);
        }

        _total = 0;

        var objects = group.items;
        for (i in 0...objects.length) {
            var body = objects[i].body;
            if (body != null) {
                var total = _total;
                separateBodyVsTilemap(body, tilemap, collideCallback, processCallback, false);
                _total += total;
            }
        }

        return (_total > 0);

    }

    public function collideCeramicGroupVsTilemapLayer(group:Group<Visual>, layer:TilemapLayer, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group.sortDirection != NONE && (group.sortDirection != INHERIT || sortDirection != NONE)) {
            sortCeramicGroup(group);
        }

        _total = 0;

        var objects = group.items;
        for (i in 0...objects.length) {
            var body = objects[i].body;
            if (body != null) {
                var total = _total;
                separateBodyVsTilemapLayer(body, layer, collideCallback, processCallback, false);
                _total += total;
            }
        }

        return (_total > 0);

    }

    public function collideArcadeGroupVsTilemap(group:arcade.Group, tilemap:Tilemap, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group.sortDirection != NONE && (group.sortDirection != INHERIT || sortDirection != NONE)) {
            sort(group);
        }

        _total = 0;

        var objects = group.objects;
        for (i in 0...objects.length) {
            var body = objects[i];
            var total = _total;
            separateBodyVsTilemap(body, tilemap, collideCallback, processCallback, false);
            _total += total;
        }

        return (_total > 0);

    }

    public function collideArcadeGroupVsTilemapLayer(group:arcade.Group, layer:TilemapLayer, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group.sortDirection != NONE && (group.sortDirection != INHERIT || sortDirection != NONE)) {
            sort(group);
        }

        _total = 0;

        var objects = group.objects;
        for (i in 0...objects.length) {
            var body = objects[i];
            var total = _total;
            separateBodyVsTilemapLayer(body, layer, collideCallback, processCallback, false);
            _total += total;
        }

        return (_total > 0);

    }

    public function overlapCeramicGroupVsTilemap(group:Group<Visual>, tilemap:Tilemap, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group.sortDirection != NONE && (group.sortDirection != INHERIT || sortDirection != NONE)) {
            sortCeramicGroup(group);
        }

        _total = 0;

        var objects = group.items;
        for (i in 0...objects.length) {
            var body = objects[i].body;
            if (body != null) {
                var total = _total;
                separateBodyVsTilemap(body, tilemap, collideCallback, processCallback, true);
                _total += total;
            }
        }

        return (_total > 0);

    }

    public function overlapCeramicGroupVsTilemapLayer(group:Group<Visual>, layer:TilemapLayer, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group.sortDirection != NONE && (group.sortDirection != INHERIT || sortDirection != NONE)) {
            sortCeramicGroup(group);
        }

        _total = 0;

        var objects = group.items;
        for (i in 0...objects.length) {
            var body = objects[i].body;
            if (body != null) {
                var total = _total;
                separateBodyVsTilemapLayer(body, layer, collideCallback, processCallback, true);
                _total += total;
            }
        }

        return (_total > 0);

    }

    public function overlapArcadeGroupVsTilemap(group:arcade.Group, tilemap:Tilemap, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group.sortDirection != NONE && (group.sortDirection != INHERIT || sortDirection != NONE)) {
            sort(group);
        }

        _total = 0;

        var objects = group.objects;
        for (i in 0...objects.length) {
            var body = objects[i];
            var total = _total;
            separateBodyVsTilemap(body, tilemap, collideCallback, processCallback, true);
            _total += total;
        }

        return (_total > 0);

    }

    public function overlapArcadeGroupVsTilemapLayer(group:arcade.Group, layer:TilemapLayer, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group.sortDirection != NONE && (group.sortDirection != INHERIT || sortDirection != NONE)) {
            sort(group);
        }

        _total = 0;

        var objects = group.objects;
        for (i in 0...objects.length) {
            var body = objects[i];
            var total = _total;
            separateBodyVsTilemapLayer(body, layer, collideCallback, processCallback, true);
            _total += total;
        }

        return (_total > 0);

    }

#end

    public function sortCeramicGroup(group:Group<Visual>, sortDirection:SortDirection = SortDirection.INHERIT) {

        if (group.sortDirection != SortDirection.INHERIT) {
            sortDirection = group.sortDirection;
        }
        else if (sortDirection == SortDirection.INHERIT) {
            sortDirection = this.sortDirection;
        }

        if (sortDirection == SortDirection.LEFT_RIGHT) {
            // Game world is say 2000x600 and you start at 0
            ArcadeSortGroupLeftRight.sort(cast group.items);
        }
        else if (sortDirection == SortDirection.RIGHT_LEFT) {
            // Game world is say 2000x600 and you start at 2000
            ArcadeSortGroupRightLeft.sort(cast group.items);
        }
        else if (sortDirection == SortDirection.TOP_BOTTOM) {
            // Game world is say 800x2000 and you start at 0
            ArcadeSortGroupTopBottom.sort(cast group.items);
        }
        else if (sortDirection == SortDirection.BOTTOM_TOP) {
            // Game world is say 800x2000 and you start at 2000
            ArcadeSortGroupBottomTop.sort(cast group.items);
        }

    }

#end

}