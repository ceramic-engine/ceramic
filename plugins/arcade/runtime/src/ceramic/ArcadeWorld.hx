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
            #end
            case arcade.Group: return arcade.Group;
            default:
                #if plugin_tilemap
                if (Std.isOfType(element, Tilemap))
                    return Tilemap;
                #end
                if (Std.isOfType(element, Visual))
                    return Visual;
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
                        case Body:
                            var visual1:Visual = cast element1;
                            return overlapBodyVsBody(visual1.body, cast element2, overlapCallback, processCallback);
                    }
                case Group:
                    switch getCollidableType(element2) {
                        default:
                        case Visual:
                            var visual2:Visual = cast element2;
                            return overlapBodyVsCeramicGroup(visual2.body, cast element1, overlapCallback, processCallback);
                        case Group:
                            return overlapCeramicGroupVsCeramicGroup(cast element1, cast element2, overlapCallback, processCallback);
                        case Body:
                            return overlapBodyVsCeramicGroup(cast element2, cast element1, overlapCallback, processCallback);
                    }
                case Body:
                    switch getCollidableType(element2) {
                        default:
                        case Visual:
                            var visual2:Visual = cast element2;
                            return overlapBodyVsBody(cast element1, visual2.body, overlapCallback, processCallback);
                        case Group:
                            return overlapBodyVsCeramicGroup(cast element1, cast element2, overlapCallback, processCallback);
                        case Body:
                            return overlapBodyVsBody(cast element1, cast element2, overlapCallback, processCallback);
                    }
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
            for (j in 0...objects2.length) {
                var body2 = objects2[j].body;

                if (body1 != null && body2 != null && separate(body1, body2, processCallback, true))
                {
                    if (overlapCallback != null)
                    {
                        overlapCallback(body1, body2);
                    }
        
                    _total++;
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
            for (j in 0...objects.length) {
                var body2 = objects[j].body;

                if (body1 != body2 && body1 != null && body2 != null) {
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

        return (_total > 0);

    }

    public function overlapBodyVsCeramicGroup(body:Body, group:Group<Visual>, ?overlapCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group.sortDirection != NONE && (group.sortDirection != INHERIT || sortDirection != NONE)) {
            sortCeramicGroup(group);
        }

        _total = 0;

        var objects = group.items;
        for (i in 0...objects.length) {
            var body2 = objects[i].body;

            if (body2 != null && separate(body, body2, processCallback, true))
            {
                if (overlapCallback != null)
                {
                    overlapCallback(body, body2);
                }
    
                _total++;
            }
        }

        return (_total > 0);

    }
    
    override function collide(
        element1:Collidable, ?element2:Collidable,
        ?collideCallback:Body->Body->Void,
        ?processCallback:Body->Body->Bool
        ):Bool {

        // TODO collide ceramic elements with arcade groups

        if (element2 == null) {
            return switch getCollidableType(element1) {
                case Group: collideCeramicGroupVsItself(cast element1, collideCallback, processCallback);
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
                        case Body:
                            var visual1:Visual = cast element1;
                            return collideBodyVsBody(visual1.body, cast element2, collideCallback, processCallback);
                        #if plugin_tilemap
                        case Tilemap:
                            var visual1:Visual = cast element1;
                            return collideBodyVsTilemap(visual1.body, cast element2, collideCallback, processCallback);
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
                        case Body:
                            return collideBodyVsCeramicGroup(cast element2, cast element1, collideCallback, processCallback);
                        #if plugin_tilemap
                        case Tilemap:
                            return collideCeramicGroupVsTilemap(cast element1, cast element2, collideCallback, processCallback);
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
                        case Body:
                            return collideBodyVsBody(cast element1, cast element2, collideCallback, processCallback);
                        #if plugin_tilemap
                        case Tilemap:
                            return collideBodyVsTilemap(cast element1, cast element2, collideCallback, processCallback);
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
                        case Body:
                            return collideBodyVsTilemap(cast element2, cast element1, collideCallback, processCallback);
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
            for (j in 0...objects2.length) {
                var body2 = objects2[j].body;

                if (body1 != null && body2 != null && separate(body1, body2, processCallback, false))
                {
                    if (collideCallback != null)
                    {
                        collideCallback(body1, body2);
                    }
        
                    _total++;
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

        return (_total > 0);

    }

    public function collideBodyVsCeramicGroup(body:Body, group:Group<Visual>, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group.sortDirection != NONE && (group.sortDirection != INHERIT || sortDirection != NONE)) {
            sortCeramicGroup(group);
        }

        _total = 0;

        var objects = group.items;
        for (i in 0...objects.length) {
            var body2 = objects[i].body;

            if (body2 != null && separate(body, body2, processCallback, false))
            {
                if (collideCallback != null)
                {
                    collideCallback(body, body2);
                }
    
                _total++;
            }
        }

        return (_total > 0);

    }

#if plugin_tilemap

    // /**
    //  * A cache of tilemap tile bodies.
    //  * Key is `tileWidth * 10000 + tileHeight` and value is an array of bodies by tile index
    //  */
    // var tileBodies:IntMap<Array<Body>> = new IntMap();

    public function collideBodyVsTilemap(body:Body, tilemap:Tilemap, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        return inline separateBodyVsTilemap(body, tilemap, collideCallback, processCallback, false);

    }

    public function overlapBodyVsTilemap(body:Body, tilemap:Tilemap, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        return inline separateBodyVsTilemap(body, tilemap, collideCallback, processCallback, true);

    }

    /**
     * A body instance used internally to perform tilemap collisions
     */
    var tileBody:Body = null;

    function separateBodyVsTilemap(body:Body, tilemap:Tilemap, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool, overlapOnly:Bool = false):Bool {

        // TODO handle layer offset & position

        _total = 0;

        if (tileBody == null) {
            tileBody = new Body(0, 0, 1, 1);
            tileBody.immovable = true;
        }

        if (tilemap.collidableLayersDirty) {
            tilemap.computeCollidableLayers();
        }

        var layers = tilemap.computedCollidableLayers;
        if (layers != null && layers.length > 0) {

            for (i in 0...layers.length) {
                var layer = layers.unsafeGet(i);
                var layerData = layer.layerData;
                if (layerData == null)
                    continue;
                ///*
                var tilemapData:TilemapData = tilemap.tilemapData;
                var tileWidth = tilemapData.tileWidth;
                var tileHeight = tilemapData.tileHeight;
                var offsetX = layerData.offsetX + layerData.x * tileWidth;
                var offsetY = layerData.offsetY + layerData.y * tileHeight;

                var minColumn = Math.floor((body.left - offsetX) / tileWidth);
                var maxColumn = Math.ceil((body.right - offsetX) / tileWidth);
                var minRow = Math.floor((body.top - offsetY) / tileHeight);
                var maxRow = Math.ceil((body.bottom - offsetY) / tileHeight);

                if (minColumn < 0)
                    minColumn = 0;
                if (maxColumn >= layerData.width)
                    maxColumn = layerData.width - 1;
                if (minRow < 0)
                    minRow = 0;
                if (maxRow >= layerData.height)
                    maxRow = layerData.height - 1;

                var column = minColumn;
                while (column <= maxColumn) {
                    var row = minRow;
                    while (row <= maxRow) {
                        var index = row * layerData.width + column;
                        var tile = layerData.tiles.unsafeGet(index);
                        if (tile.gid > 0) {
                            // We reuse the same body for every tile collision
                            tileBody.reset(
                                offsetX + column * tileWidth,
                                offsetY + row * tileHeight,
                                tileWidth,
                                tileHeight
                            );
                            tileBody.index = index;
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
                //*/

                
                /*
                var tileQuads = layer.surroundingTileQuads(body.left, body.top, body.right, body.bottom);

                for (index in 0...tileQuads.length) {
                    var tileQuad = tileQuads.unsafeGet(index);

                    // Only collide with tiles gid > 0
                    if (tileQuad.tilemapTile.gid > 0) {
                        
                        // Init tile physics if needed
                        if (tileQuad.arcade == null) {
                            tileQuad.initArcadePhysics();
                            tileQuad.immovable = true;
                        }

                        var tileBody = tileQuad.arcade.body;
                        if (separate(body, tileBody, processCallback, overlapOnly)) {
            
                            if (collideCallback != null) {
                                collideCallback(body, tileBody);
                            }
                
                            _total++;
                        }
    
                        // var tileBody = tileQuad.arcade.body;
                        // quadTree.insert(tileBody);
                        // numInserted++;
                    }
                }
                //*/
                
            }

            //var items = quadTree.retrieve(body.left, body.top, body.right, body.bottom);
            //trace('RETRIEVED ITEMS: ${items.length} (inserted=$numInserted)');

            // for (i in 0...items.length)
            // {
            //     var item = items.unsafeGet(i);
    
            //     if (separate(body, item, processCallback, overlapOnly)) {
    
            //         if (collideCallback != null) {
            //             collideCallback(body, item);
            //         }
        
            //         _total++;
            //     }
            // }
        }
        //trace('--- end separate --');

        return (_total > 0);

    }

    public function collideCeramicGroupVsTilemap(group:Group<Visual>, tilemap:Tilemap, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        // TODO optimize! (no need to iterate over every tile)

        _total = 0;

        // TODO
        
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