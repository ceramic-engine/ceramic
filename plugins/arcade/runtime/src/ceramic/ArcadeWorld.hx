package ceramic;

#if plugin_arcade
import arcade.Body;
import arcade.Collidable;
import arcade.QuadTree;
import arcade.SortDirection;
import arcade.Tile;
import ceramic.ArcadeSortGroup;
import ceramic.Group;
#end

using ceramic.Extensions;

/**
 * Extended physics world that integrates Arcade physics with Ceramic's visual system.
 * 
 * This class extends the base arcade.World to provide seamless collision detection
 * between Ceramic visuals, groups, bodies, and tilemaps. It handles the complex
 * type resolution needed to make different Ceramic object types work with the
 * physics engine.
 * 
 * Key features:
 * - Automatic type detection for Visual, Group, Body, and Tilemap objects
 * - Optimized collision detection with quadtree spatial partitioning
 * - Support for both overlap (trigger) and collide (solid) interactions
 * - Integration with tilemap plugin for tile-based collisions
 * - Specialized sorting algorithms for broad-phase optimization
 * 
 * Usage example:
 * ```haxe
 * var world = arcade.world;
 * world.gravity.y = 800;
 * 
 * // Collide two visuals
 * world.collide(player, enemy, (body1, body2) -> {
 *     trace("Player hit enemy!");
 * });
 * 
 * // Check overlaps with a group
 * world.overlap(player, collectibles, (body1, body2) -> {
 *     // Collect the item
 * });
 * ```
 * 
 * @see arcade.World for base physics world functionality
 * @see ArcadeSystem for the system that manages worlds
 */
class ArcadeWorld #if plugin_arcade extends arcade.World #end {

#if plugin_arcade

    /**
     * Whether a body moving a lot in one frame is tested against tilemaps in several
     * steps along its displacement, so that it can't go through a tile without ever
     * overlapping it (see `separateBodyVsTilemapLayersSwept()`).
     */
    public var sweepTilemaps:Bool = true;

    /**
     * Whether a body still overlapping a full tile after the regular separation is
     * pushed out through one of the tile's exposed faces (see `escapeFromTile()`).
     */
    public var escapeFullTiles:Bool = true;

    /**
     * Creates a new ArcadeWorld with the specified bounds.
     * 
     * The world bounds define the area where physics simulation occurs.
     * Bodies outside these bounds may not collide properly.
     * 
     * @param boundsX Left edge of the world
     * @param boundsY Top edge of the world
     * @param boundsWidth Width of the world
     * @param boundsHeight Height of the world
     */
    public function new(boundsX:Float, boundsY:Float, boundsWidth:Float, boundsHeight:Float) {

        super(boundsX, boundsY, boundsWidth, boundsHeight);

    }

    /**
     * Determines the actual type of a collidable element for proper collision routing.
     * 
     * This method resolves Ceramic's visual types to their base classes so the
     * collision system can handle them appropriately. For example, all Visual
     * subclasses (Quad, Mesh, etc.) are treated as Visual for collision purposes.
     * 
     * @param element The collidable element to identify
     * @return The base class type for collision handling
     */
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

    /**
     * Checks for overlaps between collidable elements without separating them.
     * 
     * Overlaps are useful for triggers, collectibles, and other non-solid interactions.
     * The overlap callback is called for each pair of overlapping bodies.
     * 
     * Supports all combinations of:
     * - Visual vs Visual
     * - Visual/Body vs Group
     * - Group vs Group
     * - Any vs Tilemap/TilemapLayer (with tilemap plugin)
     * 
     * @param element1 First element to check
     * @param element2 Second element to check (or null to check element1 against itself)
     * @param overlapCallback Called for each overlapping pair (body1, body2)
     * @param processCallback Optional filter to exclude certain pairs from overlap
     * @return True if any overlaps occurred
     */
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

    /**
     * Checks for overlaps between all bodies in two arcade groups.
     * 
     * This optimized implementation uses temporary arrays to avoid modification
     * during iteration and applies sorting for broad-phase optimization.
     * 
     * @param group1 First group of bodies
     * @param group2 Second group of bodies
     * @param overlapCallback Called for each overlapping pair
     * @param processCallback Optional filter callback
     * @return True if any overlaps occurred
     */
    override public function overlapGroupVsGroup(group1:arcade.Group, group2:arcade.Group, ?overlapCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group1.sortDirection != NONE && (group1.sortDirection != INHERIT || sortDirection != NONE)) {
            sort(group1);
        }
        if (group2.sortDirection != NONE && (group2.sortDirection != INHERIT || sortDirection != NONE)) {
            sort(group2);
        }

        _total = 0;

        final objects1 = group1.objects;
        final numObjects1 = objects1.length;

        final pool1 = ArrayPool.pool(numObjects1);
        final tmpObjects1 = pool1.get();

        for (i in 0...numObjects1) {
            tmpObjects1.set(i, objects1.unsafeGet(i));
        }

        final objects2 = group2.objects;
        final numObjects2 = objects2.length;

        final pool2 = ArrayPool.pool(numObjects2);
        final tmpObjects2 = pool2.get();

        for (i in 0...numObjects2) {
            tmpObjects2.set(i, objects2.unsafeGet(i));
        }

        for (i in 0...numObjects1) {
            var body1 = tmpObjects1.get(i);
            if (body1 != null) {
                for (j in 0...numObjects2) {
                    var body2 = tmpObjects2.get(j);

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

        pool1.release(tmpObjects1);
        pool2.release(tmpObjects2);

        return (_total > 0);

    }

    override public function overlapGroupVsItself(group:arcade.Group, ?overlapCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group.sortDirection != NONE && (group.sortDirection != INHERIT || sortDirection != NONE)) {
            sort(group);
        }

        _total = 0;

        var objects = group.objects;
        for (i in 0...objects.length) {
            var body1 = objects[i];
            if (body1 != null) {
                for (j in 0...objects.length) {
                    var body2 = objects[j];

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

    /**
     * Checks for overlaps between a single body and all bodies in a group.
     * 
     * Uses quadtree spatial partitioning for large groups to improve performance.
     * Only bodies near the target body are checked for overlap.
     * 
     * @param body The body to check
     * @param group The group of bodies to check against
     * @param overlapCallback Called for each overlap
     * @param processCallback Optional filter callback
     * @return True if any overlaps occurred
     */
    override public function overlapBodyVsGroup(body:Body, group:arcade.Group, ?overlapCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group.sortDirection != NONE && (group.sortDirection != INHERIT || sortDirection != NONE)) {
            sort(group);
        }

        _total = 0;

        var objects = group.objects;
        var numObjects = objects.length;

        if (!skipQuadTree && numObjects > maxObjectsWithoutQuadTree) {
            final quadTree = getQuadTree();

            for (i in 0...numObjects) {
                var aBody = objects.unsafeGet(i);
                if (aBody != null) {
                    quadTree.insert(aBody);
                }
            }
            final filteredObjects = quadTree.retrieve(body.left, body.top, body.right, body.bottom);
            numObjects = filteredObjects.length;

            for (i in 0...numObjects) {
                final body2:Body = filteredObjects.unsafeGet(i);

                if (body != body2 && body2 != null && separate(body, body2, processCallback, true))
                {
                    if (overlapCallback != null)
                    {
                        overlapCallback(body, body2);
                    }

                    _total++;
                }
            }

            releaseQuadTree(quadTree);
        }
        else if (numObjects > 0) {
            final pool = ArrayPool.pool(numObjects);
            final tmpObjects = pool.get();

            for (i in 0...numObjects) {
                tmpObjects.set(i, objects.unsafeGet(i));
            }

            for (i in 0...numObjects) {
                final body2:Body = tmpObjects.get(i);

                if (body != body2 && body2 != null && separate(body, body2, processCallback, true))
                {
                    if (overlapCallback != null)
                    {
                        overlapCallback(body, body2);
                    }

                    _total++;
                }
            }

            pool.release(tmpObjects);
        }

        return (_total > 0);

    }

    /**
     * Checks for overlaps between all visuals in two Ceramic groups.
     * 
     * Extracts physics bodies from visuals and performs overlap checks.
     * Handles null bodies gracefully.
     * 
     * @param group1 First group of visuals
     * @param group2 Second group of visuals
     * @param overlapCallback Called for each overlapping pair
     * @param processCallback Optional filter callback
     * @return True if any overlaps occurred
     */
    function overlapCeramicGroupVsCeramicGroup(group1:Group<Visual>, group2:Group<Visual>, ?overlapCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group1.sortDirection != NONE && (group1.sortDirection != INHERIT || sortDirection != NONE)) {
            sortCeramicGroup(group1);
        }
        if (group2.sortDirection != NONE && (group2.sortDirection != INHERIT || sortDirection != NONE)) {
            sortCeramicGroup(group2);
        }

        _total = 0;

        final objects1 = group1.items;
        final numObjects1 = objects1.length;

        final pool1 = ArrayPool.pool(numObjects1);
        final tmpObjects1 = pool1.get();

        for (i in 0...numObjects1) {
            tmpObjects1.set(i, objects1.unsafeGet(i).body);
        }

        final objects2 = group2.items;
        final numObjects2 = objects2.length;

        final pool2 = ArrayPool.pool(numObjects2);
        final tmpObjects2 = pool2.get();

        for (i in 0...numObjects2) {
            tmpObjects2.set(i, objects2.unsafeGet(i).body);
        }

        for (i in 0...numObjects1) {
            var body1 = tmpObjects1.get(i);
            if (body1 != null) {
                for (j in 0...numObjects2) {
                    var body2 = tmpObjects2.get(j);

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

        pool1.release(tmpObjects1);
        pool2.release(tmpObjects2);

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

        final objects1 = group1.items;
        final numObjects1 = objects1.length;

        final pool1 = ArrayPool.pool(numObjects1);
        final tmpObjects1 = pool1.get();

        for (i in 0...numObjects1) {
            tmpObjects1.set(i, objects1.unsafeGet(i).body);
        }

        final objects2 = group2.objects;
        final numObjects2 = objects2.length;

        final pool2 = ArrayPool.pool(numObjects2);
        final tmpObjects2 = pool2.get();

        for (i in 0...numObjects2) {
            tmpObjects2.set(i, objects2.unsafeGet(i));
        }

        for (i in 0...numObjects1) {
            var body1 = tmpObjects1.get(i);
            if (body1 != null) {
                for (j in 0...numObjects2) {
                    var body2 = tmpObjects2.get(j);

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

        pool1.release(tmpObjects1);
        pool2.release(tmpObjects2);

        return (_total > 0);

    }

    public function overlapCeramicGroupVsItself(group:Group<Visual>, ?overlapCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group.sortDirection != NONE && (group.sortDirection != INHERIT || sortDirection != NONE)) {
            sortCeramicGroup(group);
        }

        _total = 0;

        final objects = group.items;
        final numObjects = objects.length;

        final pool = ArrayPool.pool(numObjects);
        final tmpObjects = pool.get();

        for (i in 0...numObjects) {
            tmpObjects.set(i, objects.unsafeGet(i).body);
        }

        for (i in 0...numObjects) {
            final body1 = tmpObjects.get(i);

            if (body1 != null) {
                for (j in 0...objects.length) {
                    final body2 = tmpObjects.get(j);

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

        pool.release(tmpObjects);

        return (_total > 0);

    }

    public function overlapBodyVsCeramicGroup(body:Body, group:Group<Visual>, ?overlapCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group.sortDirection != NONE && (group.sortDirection != INHERIT || sortDirection != NONE)) {
            sortCeramicGroup(group);
        }

        _total = 0;

        var objects = group.items;
        var numObjects = objects.length;

        if (!skipQuadTree && numObjects > maxObjectsWithoutQuadTree) {
            final quadTree = getQuadTree();

            for (i in 0...numObjects) {
                var object = objects.unsafeGet(i);
                var aBody = object.body;
                if (aBody != null) {
                    quadTree.insert(aBody);
                }
            }
            final filteredObjects = quadTree.retrieve(body.left, body.top, body.right, body.bottom);
            numObjects = filteredObjects.length;

            for (i in 0...numObjects) {
                final body2:Body = filteredObjects.unsafeGet(i);

                if (body != body2 && body2 != null && separate(body, body2, processCallback, true))
                {
                    if (overlapCallback != null)
                    {
                        overlapCallback(body, body2);
                    }

                    _total++;
                }
            }

            releaseQuadTree(quadTree);
        }
        else if (numObjects > 0) {
            final pool = ArrayPool.pool(numObjects);
            final tmpObjects = pool.get();

            for (i in 0...numObjects) {
                tmpObjects.set(i, objects.unsafeGet(i).body);
            }

            for (i in 0...numObjects) {
                final body2:Body = tmpObjects.get(i);

                if (body != body2 && body2 != null && separate(body, body2, processCallback, true))
                {
                    if (overlapCallback != null)
                    {
                        overlapCallback(body, body2);
                    }

                    _total++;
                }
            }

            pool.release(tmpObjects);
        }

        return (_total > 0);

    }

    /**
     * Checks for collisions between collidable elements and separates them.
     * 
     * Collisions prevent objects from overlapping by pushing them apart.
     * The collide callback is called for each pair of colliding bodies after separation.
     * 
     * Supports all combinations of:
     * - Visual vs Visual
     * - Visual/Body vs Group  
     * - Group vs Group
     * - Any vs Tilemap/TilemapLayer (with tilemap plugin)
     * 
     * @param element1 First element to check
     * @param element2 Second element to check (or null to check element1 against itself)
     * @param collideCallback Called for each colliding pair after separation (body1, body2)
     * @param processCallback Optional filter to exclude certain pairs from collision
     * @return True if any collisions occurred
     */
    // TODO use haxe 4.2 overloads to resolve collidable types
    // at compile time instead of runtime

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

    override public function collideGroupVsGroup(group1:arcade.Group, group2:arcade.Group, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group1.sortDirection != NONE && (group1.sortDirection != INHERIT || sortDirection != NONE)) {
            sort(group1);
        }
        if (group2.sortDirection != NONE && (group2.sortDirection != INHERIT || sortDirection != NONE)) {
            sort(group2);
        }

        _total = 0;

        final objects1 = group1.objects;
        final numObjects1 = objects1.length;

        final pool1 = ArrayPool.pool(numObjects1);
        final tmpObjects1 = pool1.get();

        for (i in 0...numObjects1) {
            tmpObjects1.set(i, objects1.unsafeGet(i));
        }

        final objects2 = group2.objects;
        final numObjects2 = objects2.length;

        final pool2 = ArrayPool.pool(numObjects2);
        final tmpObjects2 = pool2.get();

        for (i in 0...numObjects2) {
            tmpObjects2.set(i, objects2.unsafeGet(i));
        }

        for (i in 0...numObjects1) {
            var body1 = tmpObjects1.get(i);
            if (body1 != null) {
                for (j in 0...numObjects2) {
                    var body2 = tmpObjects2.get(j);

                    if (body1 != body2 && body2 != null) {
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

        pool1.release(tmpObjects1);
        pool2.release(tmpObjects2);

        return (_total > 0);

    }

    override public function collideGroupVsItself(group:arcade.Group, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group.sortDirection != NONE && (group.sortDirection != INHERIT || sortDirection != NONE)) {
            sort(group);
        }

        _total = 0;

        var objects = group.objects;
        for (i in 0...objects.length) {
            var body1 = objects[i];
            if (body1 != null) {
                for (j in 0...objects.length) {
                    var body2 = objects[j];

                    if (body1 != body2 && body2 != null) {
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

    override public function collideBodyVsGroup(body:Body, group:arcade.Group, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group.sortDirection != NONE && (group.sortDirection != INHERIT || sortDirection != NONE)) {
            sort(group);
        }

        _total = 0;

        var objects = group.objects;
        var numObjects = objects.length;

        if (!skipQuadTree && numObjects > maxObjectsWithoutQuadTree) {
            final quadTree = getQuadTree();

            for (i in 0...numObjects) {
                var aBody = objects.unsafeGet(i);
                if (aBody != null) {
                    quadTree.insert(aBody);
                }
            }
            final filteredObjects = quadTree.retrieve(body.left, body.top, body.right, body.bottom);
            numObjects = filteredObjects.length;

            for (i in 0...numObjects) {
                final body2:Body = filteredObjects.unsafeGet(i);

                if (body != body2 && body2 != null && separate(body, body2, processCallback, false))
                {
                    if (collideCallback != null)
                    {
                        collideCallback(body, body2);
                    }

                    _total++;
                }
            }

            releaseQuadTree(quadTree);
        }
        else if (numObjects > 0) {
            final pool = ArrayPool.pool(numObjects);
            final tmpObjects = pool.get();

            for (i in 0...numObjects) {
                tmpObjects.set(i, objects.unsafeGet(i));
            }

            for (i in 0...numObjects) {
                final body2:Body = tmpObjects.get(i);

                if (body != body2 && body2 != null && separate(body, body2, processCallback, false))
                {
                    if (collideCallback != null)
                    {
                        collideCallback(body, body2);
                    }

                    _total++;
                }
            }

            pool.release(tmpObjects);
        }

        return (_total > 0);

    }

    function collideCeramicGroupVsCeramicGroup(group1:Group<Visual>, group2:Group<Visual>, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group1.sortDirection != NONE && (group1.sortDirection != INHERIT || sortDirection != NONE)) {
            sortCeramicGroup(group1);
        }
        if (group2.sortDirection != NONE && (group2.sortDirection != INHERIT || sortDirection != NONE)) {
            sortCeramicGroup(group2);
        }

        _total = 0;

        final objects1 = group1.items;
        final numObjects1 = objects1.length;

        final pool1 = ArrayPool.pool(numObjects1);
        final tmpObjects1 = pool1.get();

        for (i in 0...numObjects1) {
            tmpObjects1.set(i, objects1.unsafeGet(i).body);
        }

        final objects2 = group2.items;
        final numObjects2 = objects2.length;

        final pool2 = ArrayPool.pool(numObjects2);
        final tmpObjects2 = pool2.get();

        for (i in 0...numObjects2) {
            tmpObjects2.set(i, objects2.unsafeGet(i).body);
        }

        for (i in 0...numObjects1) {
            var body1 = tmpObjects1.get(i);
            if (body1 != null) {
                for (j in 0...numObjects2) {
                    var body2 = tmpObjects2.get(j);

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

        pool1.release(tmpObjects1);
        pool2.release(tmpObjects2);

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

        final objects1 = group1.items;
        final numObjects1 = objects1.length;

        final pool1 = ArrayPool.pool(numObjects1);
        final tmpObjects1 = pool1.get();

        for (i in 0...numObjects1) {
            tmpObjects1.set(i, objects1.unsafeGet(i).body);
        }

        final objects2 = group2.objects;
        final numObjects2 = objects2.length;

        final pool2 = ArrayPool.pool(numObjects2);
        final tmpObjects2 = pool2.get();

        for (i in 0...numObjects2) {
            tmpObjects2.set(i, objects2.unsafeGet(i));
        }

        for (i in 0...numObjects1) {
            var body1 = tmpObjects1.get(i);
            if (body1 != null) {
                for (j in 0...numObjects2) {
                    var body2 = tmpObjects2.get(j);

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

        pool1.release(tmpObjects1);
        pool2.release(tmpObjects2);

        return (_total > 0);

    }

    public function collideCeramicGroupVsItself(group:Group<Visual>, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group.sortDirection != NONE && (group.sortDirection != INHERIT || sortDirection != NONE)) {
            sortCeramicGroup(group);
        }

        _total = 0;

        final objects = group.items;
        final numObjects = objects.length;

        final pool = ArrayPool.pool(numObjects);
        final tmpObjects = pool.get();

        for (i in 0...numObjects) {
            tmpObjects.set(i, objects.unsafeGet(i).body);
        }

        for (i in 0...numObjects) {
            final body1 = tmpObjects.get(i);

            if (body1 != null) {
                for (j in 0...objects.length) {
                    final body2 = tmpObjects.get(j);

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

        pool.release(tmpObjects);

        return (_total > 0);

    }

    public function collideBodyVsCeramicGroup(body:Body, group:Group<Visual>, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group.sortDirection != NONE && (group.sortDirection != INHERIT || sortDirection != NONE)) {
            sortCeramicGroup(group);
        }

        _total = 0;

        var objects = group.items;
        var numObjects = objects.length;

        if (!skipQuadTree && numObjects > maxObjectsWithoutQuadTree) {
            final quadTree = getQuadTree();

            for (i in 0...numObjects) {
                var object = objects.unsafeGet(i);
                var aBody = object.body;
                if (aBody != null) {
                    quadTree.insert(aBody);
                }
            }
            final filteredObjects = quadTree.retrieve(body.left, body.top, body.right, body.bottom);
            numObjects = filteredObjects.length;

            for (i in 0...numObjects) {
                final body2:Body = filteredObjects.unsafeGet(i);

                if (body != body2 && body2 != null && separate(body, body2, processCallback, false))
                {
                    if (collideCallback != null)
                    {
                        collideCallback(body, body2);
                    }

                    _total++;
                }
            }

            releaseQuadTree(quadTree);
        }
        else if (numObjects > 0) {
            final pool = ArrayPool.pool(numObjects);
            final tmpObjects = pool.get();

            for (i in 0...numObjects) {
                tmpObjects.set(i, objects.unsafeGet(i).body);
            }

            for (i in 0...numObjects) {
                final body2:Body = tmpObjects.get(i);

                if (body != body2 && body2 != null && separate(body, body2, processCallback, false))
                {
                    if (collideCallback != null)
                    {
                        collideCallback(body, body2);
                    }

                    _total++;
                }
            }

            pool.release(tmpObjects);
        }

        return (_total > 0);

    }

#if plugin_tilemap

    /**
     * Performs collision detection and separation between a body and a tilemap.
     * 
     * Only checks tiles that the body overlaps with for efficiency.
     * Each colliding tile is treated as a solid immovable body.
     * 
     * @param body The physics body to collide
     * @param tilemap The tilemap to collide against
     * @param collideCallback Called for each tile collision
     * @param processCallback Optional filter for specific tiles
     * @return True if any collisions occurred
     */
    @:plugin('tilemap')
    public function collideBodyVsTilemap(body:Body, tilemap:Tilemap, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        return #if !debug inline #end separateBodyVsTilemap(body, tilemap, collideCallback, processCallback, false);

    }

    @:plugin('tilemap')
    public function overlapBodyVsTilemap(body:Body, tilemap:Tilemap, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        return #if !debug inline #end separateBodyVsTilemap(body, tilemap, collideCallback, processCallback, true);

    }

    @:plugin('tilemap')
    public function collideBodyVsTilemapLayer(body:Body, layer:TilemapLayer, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        return #if !debug inline #end separateBodyVsTilemapLayersSwept(body, null, layer, collideCallback, processCallback, false);

    }

    @:plugin('tilemap')
    public function overlapBodyVsTilemapLayer(body:Body, layer:TilemapLayer, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        return #if !debug inline #end separateBodyVsTilemapLayer(body, layer, collideCallback, processCallback, true);

    }

    /**
     * Reusable body instance for tilemap collisions.
     * 
     * Instead of creating a new body for each tile collision, we reuse
     * this single instance for performance. The body is configured as
     * immovable and its position/size is updated for each tile.
     */
    var tileBody:Body = null;

    function separateBodyVsTilemap(body:Body, tilemap:Tilemap, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool, overlapOnly:Bool = false):Bool {

        if (tilemap.collidableLayersDirty) {
            tilemap.computeCollidableLayers();
        }

        var layers = tilemap.computedCollidableLayers;
        if (layers == null || layers.length == 0) {
            return false;
        }

        return #if !debug inline #end separateBodyVsTilemapLayersSwept(body, layers, null, collideCallback, processCallback, overlapOnly);

    }

    /**
     * Separates a body against tilemap layers (`layers`, or the single `layer` if given),
     * moving the body along its displacement in several steps when it moved a lot this frame.
     *
     * A body is only tested against the tiles it overlaps at its current position, so a body
     * moving more than its own size in one frame could end up past a tile without ever
     * overlapping it. Stepping by at most half the body size on each axis makes sure the
     * first tile on the path is met. The steps only concern the collision test: velocity and
     * gravity were integrated once, for the whole frame, before this is called.
     */
    function separateBodyVsTilemapLayersSwept(body:Body, layers:Array<TilemapLayer>, layer:TilemapLayer, collideCallback:Body->Body->Void, processCallback:Body->Body->Bool, overlapOnly:Bool):Bool {

        var steps = 1;
        var startX = body.prevX;
        var startY = body.prevY;
        var dx = body.x - startX;
        var dy = body.y - startY;

        if (sweepTilemaps && !overlapOnly && body.enable && body.moves && !body.immovable && !body.isCircle) {
            var halfWidth = body.width * 0.5;
            var halfHeight = body.height * 0.5;
            if (halfWidth > 0 && halfHeight > 0) {
                var stepsX = Math.abs(dx) / halfWidth;
                var stepsY = Math.abs(dy) / halfHeight;
                var neededSteps = stepsX > stepsY ? stepsX : stepsY;
                if (neededSteps > 1) {
                    steps = Math.ceil(neededSteps);
                    if (steps > MAX_SWEEP_STEPS) {
                        steps = MAX_SWEEP_STEPS;
                    }
                }
            }
        }

        if (steps == 1) {
            // The body moved less than half its size: test it where it is
            return #if !debug inline #end separateBodyVsTilemapLayers(body, layers, layer, collideCallback, processCallback, overlapOnly);
        }

        var result = false;
        var stepX = dx / steps;
        var stepY = dy / steps;

        body.x = startX;
        body.y = startY;

        for (i in 0...steps) {
            // Each step is a small displacement of its own, so the overlap limits
            // of the separation reason on the step rather than on the whole frame
            body.prevX = body.x;
            body.prevY = body.y;
            if (!(stepX > 0 && body.blockedRight) && !(stepX < 0 && body.blockedLeft)) {
                body.x += stepX;
            }
            if (!(stepY > 0 && body.blockedDown) && !(stepY < 0 && body.blockedUp)) {
                body.y += stepY;
            }
            if (#if !debug inline #end separateBodyVsTilemapLayers(body, layers, layer, collideCallback, processCallback, overlapOnly)) {
                result = true;
            }
        }

        // Restore the frame's starting position: the body's displacement
        // for the frame is read from it afterwards
        body.prevX = startX;
        body.prevY = startY;

        return result;

    }

    static inline final MAX_SWEEP_STEPS:Int = 16;

    function separateBodyVsTilemapLayers(body:Body, layers:Array<TilemapLayer>, layer:TilemapLayer, collideCallback:Body->Body->Void, processCallback:Body->Body->Bool, overlapOnly:Bool):Bool {

        var total = 0;

        if (layer != null) {
            inline separateBodyVsTilemapLayer(body, layer, collideCallback, processCallback, overlapOnly);
            total = _total;
        }
        else {
            for (i in 0...layers.length) {
                var aLayer = layers.unsafeGet(i);
                inline separateBodyVsTilemapLayer(body, aLayer, collideCallback, processCallback, overlapOnly);
                total += _total;
            }
        }

        return (total > 0);

    }

    /**
     * Pushes `body` out of `tile`, a full tile it is still overlapping after the regular
     * separation, through one of the tile's exposed faces. The face the body came through
     * is preferred when the body moved on that axis this step and is not deeper through
     * that face than its displacement, otherwise the nearest exposed face is used: a body
     * resting a few pixels inside a wall is pushed sideways, never lifted onto the wall.
     * Returns `false` when no face is exposed (the body is inside a thick wall).
     */
    function escapeFromTile(body:Body, tile:Body, topExposed:Bool, bottomExposed:Bool, leftExposed:Bool, rightExposed:Bool):Bool {

        // Distance to move the body to get it out through each face
        var throughTop = body.bottom - tile.top;
        var throughBottom = tile.bottom - body.top;
        var throughLeft = body.right - tile.left;
        var throughRight = tile.right - body.left;

        var dx = body.deltaX();
        var dy = body.deltaY();
        var bias = this.overlapBias;

        var face = -1; // 0 top, 1 bottom, 2 left, 3 right
        if (dy > 0 && topExposed && throughTop <= dy + bias) {
            face = 0;
        }
        else if (dy < 0 && bottomExposed && throughBottom <= -dy + bias) {
            face = 1;
        }
        else if (dx > 0 && leftExposed && throughLeft <= dx + bias) {
            face = 2;
        }
        else if (dx < 0 && rightExposed && throughRight <= -dx + bias) {
            face = 3;
        }
        else {
            var best = Math.POSITIVE_INFINITY;
            if (topExposed && throughTop < best) { best = throughTop; face = 0; }
            if (bottomExposed && throughBottom < best) { best = throughBottom; face = 1; }
            if (leftExposed && throughLeft < best) { best = throughLeft; face = 2; }
            if (rightExposed && throughRight < best) { best = throughRight; face = 3; }
        }

        #if arcade_debug_escape
        if (face != -1) {
            final moved = switch face { case 0: throughTop; case 1: throughBottom; case 2: throughLeft; case _: throughRight; };
            if (moved >= overlapBias) {
                ceramic.Shortcuts.log.warning(
                    'ARCADE ESCAPE face=' + (switch face { case 0: 'top'; case 1: 'bottom'; case 2: 'left'; case _: 'right'; })
                    + ' moved=' + moved + ' body=' + body.x + ',' + body.y + ' ' + body.width + 'x' + body.height
                    + ' prev=' + body.prevX + ',' + body.prevY + ' delta=' + dx + ',' + dy
                    + ' tile=' + tile.x + ',' + tile.y + ' ' + tile.width + 'x' + tile.height
                    + ' through top=' + throughTop + ' bottom=' + throughBottom + ' left=' + throughLeft + ' right=' + throughRight
                    + ' exposed top=' + topExposed + ' bottom=' + bottomExposed + ' left=' + leftExposed + ' right=' + rightExposed
                );
            }
        }
        #end

        switch face {
            case 0:
                body.y -= throughTop;
                if (body.velocityY > 0) body.velocityY = 0;
                body.blockedDown = true;
                body.touchingDown = true;
            case 1:
                body.y += throughBottom;
                if (body.velocityY < 0) body.velocityY = 0;
                body.blockedUp = true;
                body.touchingUp = true;
            case 2:
                body.x -= throughLeft;
                if (body.velocityX > 0) body.velocityX = 0;
                body.blockedRight = true;
                body.touchingRight = true;
            case 3:
                body.x += throughRight;
                if (body.velocityX < 0) body.velocityX = 0;
                body.blockedLeft = true;
                body.touchingLeft = true;
            case _:
                return false;
        }
        body.blockedNone = false;
        body.touchingNone = false;
        return true;

    }

    /**
     * Core tilemap collision implementation for a single layer.
     * 
     * This method:
     * 1. Calculates which tiles the body overlaps
     * 2. Creates a temporary immovable body for each solid tile
     * 3. Performs collision/overlap detection
     * 4. Handles special cases like connected tiles and slopes
     * 
     * @param body The body to check
     * @param layer The tilemap layer
     * @param collideCallback Called for each collision
     * @param processCallback Optional filter
     * @param overlapOnly If true, only detect overlaps without separation
     */
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

            Assert.assert(tileWidth > 0 && tileHeight > 0, 'Cannot collide or overlap with tilemap layer because tile size $tileWidth x $tileHeight is invalid');

            var tiles = layer.checkCollisionWithComputedTiles ? layerData.computedTiles : layerData.tiles;
            // Need to check again as it can be null if needing computed tiles but there is only tiles and vice versa
            if (tiles != null) {

                var checkCollisionValues = layer.checkCollisionValues;

                // A layer that collides on its four sides is made of full tiles,
                // as opposed to one-way platforms
                var fullLayer = layer.checkCollisionUp && layer.checkCollisionRight && layer.checkCollisionDown && layer.checkCollisionLeft;

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

                // tileBody.checkCollisionUp = layer.checkCollisionUp;
                // tileBody.checkCollisionRight = layer.checkCollisionRight;
                // tileBody.checkCollisionDown = layer.checkCollisionDown;
                // tileBody.checkCollisionLeft = layer.checkCollisionLeft;
                // tileBody.checkCollisionNone = !layer.checkCollisionUp && !layer.checkCollisionRight && !layer.checkCollisionDown && !layer.checkCollisionLeft;

                var column = minColumn;
                while (column <= maxColumn) {
                    var row = minRow;
                    while (row <= maxRow) {
                        var index = row * layerData.columns + column;
                        var tile = tiles.unsafeGet(index);
                        var gid = tile.gid;

                        tileBody.checkCollisionUp = layer.checkCollisionUp;
                        tileBody.checkCollisionRight = layer.checkCollisionRight;
                        tileBody.checkCollisionDown = layer.checkCollisionDown;
                        tileBody.checkCollisionLeft = layer.checkCollisionLeft;

                        var tileExtraY:Float = 0;
                        var tileExtraHeight:Float = 0;
                        var forceX:Bool = false;

                        // Rows covered by the tile body once merged with its solid neighbours
                        var topRow = row;
                        var bottomRow = row;

                        if (row > minRow) {
                            var indexPrevRow = (row - 1) * layerData.columns + column;
                            var tilePrevRow = tiles.unsafeGet(indexPrevRow);
                            var gidPrevRow = tilePrevRow.gid;

                            if ((checkCollisionValues != null) ? checkCollisionValues.contains(gidPrevRow) : gidPrevRow > 0) {
                                tileBody.checkCollisionUp = false;
                                tileExtraY -= tileHeight;
                                tileExtraHeight += tileHeight;
                                topRow = row - 1;
                            }

                            forceX = true;
                        }

                        if (row < maxRow) {
                            var indexNextRow = (row + 1) * layerData.columns + column;
                            var tileNextRow = tiles.unsafeGet(indexNextRow);
                            var gidNextRow = tileNextRow.gid;

                            if ((checkCollisionValues != null) ? checkCollisionValues.contains(gidNextRow) : gidNextRow > 0) {
                                tileBody.checkCollisionDown = false;
                                tileExtraHeight += tileHeight;
                                bottomRow = row + 1;
                            }

                            forceX = true;
                        }

                        tileBody.forceX = false;//forceX;

                        tileBody.checkCollisionNone = !layer.checkCollisionUp && !layer.checkCollisionRight && !layer.checkCollisionDown && !layer.checkCollisionLeft;

                        if ((checkCollisionValues != null) ? checkCollisionValues.contains(gid) : gid > 0) {

                            // Check if there is a slope assigned to this tile
                            var tileset = tilemapData.tilesetForGid(gid);
                            var slope = tileset.slope(gid);

                            // We reuse the same body for every tile collision
                            tileBody.reset(
                                offsetX + column * tileWidth,
                                offsetY + row * tileHeight + tileExtraY,
                                tileWidth,
                                tileHeight + tileExtraHeight
                            );
                            tileBody.index = index;

                            // // When being blocked by a wall, prioritize X over Y separation
                            // if (body.velocityY < 0 && !body.blockedDown) {
                            //     var indexBelow = index + layerData.columns;
                            //     var tileBelow = 0;
                            //     var foundCollidingTileBelow = false;
                            //     if (layers != null) {
                            //         for (n in 0...layers.length) {
                            //             var layer = layers.unsafeGet(n);
                            //             var layerData = layer.layerData;
                            //             if (layerData != null) {
                            //                 tileBelow = indexBelow < tiles.length ? tiles.unsafeGet(indexBelow).gid : 0;
                            //                 if (checkCollisionValues != null) {
                            //                     if (checkCollisionValues.contains(tileBelow)) {
                            //                         foundCollidingTileBelow = true;
                            //                         break;
                            //                     }
                            //                 }
                            //                 else {
                            //                     if (tileBelow > 0) {
                            //                         foundCollidingTileBelow = true;
                            //                         break;
                            //                     }
                            //                 }
                            //             }
                            //         }
                            //     }

                            //     if (foundCollidingTileBelow) {
                            //         tileBody.forceX = true;
                            //     }
                            //     else if (!body.isCircle && intersects(tileBody, body)) {
                            //         var diffX = Math.max(
                            //             Math.abs(tileBody.right - body.left),
                            //             Math.abs(tileBody.left - body.right)
                            //         );
                            //         var diffY = Math.max(
                            //             Math.abs(tileBody.bottom - body.top),
                            //             Math.abs(tileBody.top - body.bottom)
                            //         );
                            //         tileBody.forceX = diffX > diffY;
                            //     }
                            //     else {
                            //         tileBody.forceX = false;
                            //     }
                            // }
                            // else {
                            //     tileBody.forceX = false;
                            // }

                            var collided = separate(body, tileBody, processCallback, overlapOnly);

                            // The regular separation refuses to move a body that is deeper inside a
                            // tile than what it moved this frame (plus a small bias), which fits two
                            // moving bodies but leaves a body stuck inside a wall. A full tile never
                            // lets a body stay inside: push it out through its nearest exposed face.
                            if (escapeFullTiles && !overlapOnly && fullLayer && body.enable && body.moves && !body.immovable && !body.isCircle && intersects(body, tileBody)) {
                                // A face is exposed when no solid tile lies beyond it, along the
                                // whole tile body (the collision flags only know about the rows
                                // the body overlaps, so they cannot tell this for its top row)
                                var columns = layerData.columns;
                                var topExposed = true;
                                var bottomExposed = true;
                                var leftExposed = true;
                                var rightExposed = true;
                                if (topRow > 0) {
                                    var gidAbove = tiles.unsafeGet((topRow - 1) * columns + column).gid;
                                    topExposed = !((checkCollisionValues != null) ? checkCollisionValues.contains(gidAbove) : gidAbove > 0);
                                }
                                if (bottomRow < layerData.rows - 1) {
                                    var gidBelow = tiles.unsafeGet((bottomRow + 1) * columns + column).gid;
                                    bottomExposed = !((checkCollisionValues != null) ? checkCollisionValues.contains(gidBelow) : gidBelow > 0);
                                }
                                // A side is exposed along the rows the body really overlaps. A row
                                // the body only grazes (resting on the floor next to a wall, sunk a
                                // fraction of a pixel by gravity) is a contact the regular separation
                                // settles: counting it would close the side and push the body out
                                // through the top of the wall, up to a whole tile
                                var sideTolerance = Math.min(overlapBias, body.height * 0.5);
                                var sideRow = topRow;
                                while (sideRow <= bottomRow) {
                                    var sideTop = offsetY + sideRow * tileHeight;
                                    var sideOverlap = Math.min(body.bottom, sideTop + tileHeight) - Math.max(body.top, sideTop);
                                    if (sideOverlap > sideTolerance) {
                                        var sideIndex = sideRow * columns + column;
                                        if (column > 0) {
                                            var gidLeft = tiles.unsafeGet(sideIndex - 1).gid;
                                            if ((checkCollisionValues != null) ? checkCollisionValues.contains(gidLeft) : gidLeft > 0) {
                                                leftExposed = false;
                                            }
                                        }
                                        if (column < columns - 1) {
                                            var gidRight = tiles.unsafeGet(sideIndex + 1).gid;
                                            if ((checkCollisionValues != null) ? checkCollisionValues.contains(gidRight) : gidRight > 0) {
                                                rightExposed = false;
                                            }
                                        }
                                    }
                                    sideRow++;
                                }
                                if (escapeFromTile(body, tileBody, topExposed, bottomExposed, leftExposed, rightExposed)) {
                                    collided = true;
                                }
                            }

                            if (collided) {

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
        }

        return (_total > 0);

    }

    @:plugin('tilemap')
    public function collideCeramicGroupVsTilemap(group:Group<Visual>, tilemap:Tilemap, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group.sortDirection != NONE && (group.sortDirection != INHERIT || sortDirection != NONE)) {
            sortCeramicGroup(group);
        }

        _total = 0;

        final objects = group.items;
        final numObjects = objects.length;

        final pool = ArrayPool.pool(numObjects);
        final tmpObjects = pool.get();

        for (i in 0...numObjects) {
            tmpObjects.set(i, objects.unsafeGet(i).body);
        }

        for (i in 0...numObjects) {
            final body = tmpObjects.get(i);

            if (body != null) {
                var total = _total;
                separateBodyVsTilemap(body, tilemap, collideCallback, processCallback, false);
                _total += total;
            }
        }

        pool.release(tmpObjects);

        return (_total > 0);

    }

    @:plugin('tilemap')
    public function collideCeramicGroupVsTilemapLayer(group:Group<Visual>, layer:TilemapLayer, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group.sortDirection != NONE && (group.sortDirection != INHERIT || sortDirection != NONE)) {
            sortCeramicGroup(group);
        }

        _total = 0;

        final objects = group.items;
        final numObjects = objects.length;

        final pool = ArrayPool.pool(numObjects);
        final tmpObjects = pool.get();

        for (i in 0...numObjects) {
            tmpObjects.set(i, objects.unsafeGet(i).body);
        }

        for (i in 0...numObjects) {
            final body = tmpObjects.get(i);

            if (body != null) {
                var total = _total;
                separateBodyVsTilemapLayer(body, layer, collideCallback, processCallback, false);
                _total += total;
            }
        }

        pool.release(tmpObjects);

        return (_total > 0);

    }

    @:plugin('tilemap')
    public function collideArcadeGroupVsTilemap(group:arcade.Group, tilemap:Tilemap, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group.sortDirection != NONE && (group.sortDirection != INHERIT || sortDirection != NONE)) {
            sort(group);
        }

        _total = 0;

        final objects = group.objects;
        final numObjects = objects.length;

        final pool = ArrayPool.pool(numObjects);
        final tmpObjects = pool.get();

        for (i in 0...numObjects) {
            tmpObjects.set(i, objects.unsafeGet(i));
        }

        for (i in 0...numObjects) {
            final body = tmpObjects.get(i);

            var total = _total;
            separateBodyVsTilemap(body, tilemap, collideCallback, processCallback, false);
            _total += total;
        }

        pool.release(tmpObjects);

        return (_total > 0);

    }

    @:plugin('tilemap')
    public function collideArcadeGroupVsTilemapLayer(group:arcade.Group, layer:TilemapLayer, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group.sortDirection != NONE && (group.sortDirection != INHERIT || sortDirection != NONE)) {
            sort(group);
        }

        _total = 0;

        final objects = group.objects;
        final numObjects = objects.length;

        final pool = ArrayPool.pool(numObjects);
        final tmpObjects = pool.get();

        for (i in 0...numObjects) {
            tmpObjects.set(i, objects.unsafeGet(i));
        }

        for (i in 0...numObjects) {
            final body = tmpObjects.get(i);

            var total = _total;
            separateBodyVsTilemapLayer(body, layer, collideCallback, processCallback, false);
            _total += total;
        }

        pool.release(tmpObjects);

        return (_total > 0);

    }

    @:plugin('tilemap')
    public function overlapCeramicGroupVsTilemap(group:Group<Visual>, tilemap:Tilemap, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group.sortDirection != NONE && (group.sortDirection != INHERIT || sortDirection != NONE)) {
            sortCeramicGroup(group);
        }

        _total = 0;

        final objects = group.items;
        final numObjects = objects.length;

        final pool = ArrayPool.pool(numObjects);
        final tmpObjects = pool.get();

        for (i in 0...numObjects) {
            tmpObjects.set(i, objects.unsafeGet(i).body);
        }

        for (i in 0...numObjects) {
            final body = tmpObjects.get(i);

            if (body != null) {
                var total = _total;
                separateBodyVsTilemap(body, tilemap, collideCallback, processCallback, true);
                _total += total;
            }
        }

        pool.release(tmpObjects);

        return (_total > 0);

    }

    @:plugin('tilemap')
    public function overlapCeramicGroupVsTilemapLayer(group:Group<Visual>, layer:TilemapLayer, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group.sortDirection != NONE && (group.sortDirection != INHERIT || sortDirection != NONE)) {
            sortCeramicGroup(group);
        }

        _total = 0;

        final objects = group.items;
        final numObjects = objects.length;

        final pool = ArrayPool.pool(numObjects);
        final tmpObjects = pool.get();

        for (i in 0...numObjects) {
            tmpObjects.set(i, objects.unsafeGet(i).body);
        }

        for (i in 0...numObjects) {
            final body = tmpObjects.get(i);

            if (body != null) {
                var total = _total;
                separateBodyVsTilemapLayer(body, layer, collideCallback, processCallback, true);
                _total += total;
            }
        }

        pool.release(tmpObjects);

        return (_total > 0);

    }

    @:plugin('tilemap')
    public function overlapArcadeGroupVsTilemap(group:arcade.Group, tilemap:Tilemap, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group.sortDirection != NONE && (group.sortDirection != INHERIT || sortDirection != NONE)) {
            sort(group);
        }

        _total = 0;

        final objects = group.objects;
        final numObjects = objects.length;

        final pool = ArrayPool.pool(numObjects);
        final tmpObjects = pool.get();

        for (i in 0...numObjects) {
            tmpObjects.set(i, objects.unsafeGet(i));
        }

        for (i in 0...numObjects) {
            final body = tmpObjects.get(i);

            var total = _total;
            separateBodyVsTilemap(body, tilemap, collideCallback, processCallback, true);
            _total += total;
        }

        pool.release(tmpObjects);

        return (_total > 0);

    }

    @:plugin('tilemap')
    public function overlapArcadeGroupVsTilemapLayer(group:arcade.Group, layer:TilemapLayer, ?collideCallback:Body->Body->Void, ?processCallback:Body->Body->Bool):Bool {

        if (group.sortDirection != NONE && (group.sortDirection != INHERIT || sortDirection != NONE)) {
            sort(group);
        }

        _total = 0;

        final objects = group.objects;
        final numObjects = objects.length;

        final pool = ArrayPool.pool(numObjects);
        final tmpObjects = pool.get();

        for (i in 0...numObjects) {
            tmpObjects.set(i, objects.unsafeGet(i));
        }

        for (i in 0...numObjects) {
            final body = tmpObjects.get(i);

            var total = _total;
            separateBodyVsTilemapLayer(body, layer, collideCallback, processCallback, true);
            _total += total;
        }

        pool.release(tmpObjects);

        return (_total > 0);

    }

#end

    /**
     * Sorts a Ceramic visual group for optimized collision detection.
     * 
     * Sorting bodies by position allows the collision system to exit early
     * when checking pairs, significantly improving performance for large groups.
     * 
     * Uses specialized merge sort implementations optimized for each direction.
     * 
     * @param group The group to sort
     * @param sortDirection The direction to sort (or INHERIT to use group/world setting)
     */
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