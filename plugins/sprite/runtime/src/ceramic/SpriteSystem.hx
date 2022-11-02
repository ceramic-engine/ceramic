package ceramic;

using ceramic.Extensions;

@:allow(ceramic.SpriteBase)
class SpriteSystem extends System {

    /**
     * Shared sprite system
     */
    @lazy public static var shared = new SpriteSystem();

    #if cs
    var sprites:Array<Dynamic> = [];

    var _updatingSprites:Array<Dynamic> = [];
    #else
    var sprites:Array<SpriteBase<Any>> = [];

    var _updatingSprites:Array<SpriteBase<Any>> = [];
    #end

    override function new() {

        super();

        lateUpdateOrder = 3000;

    }

    override function lateUpdate(delta:Float):Void {

        // Work on a copy of list, to ensure nothing bad happens
        // if a new item is created or destroyed during iteration
        var len = sprites.length;
        for (i in 0...len) {
            #if cs
            _updatingSprites[i] = sprites[i];
            #else
            _updatingSprites[i] = sprites.unsafeGet(i);
            #end
        }

        // Call
        for (i in 0...len) {
            #if cs
            var sprite:SpriteBase<Dynamic> = _updatingSprites.unsafeGet(i);
            @:privateAccess sprite._updateIfNotPausedAndAutoUpdating(delta);
            #else
            var sprite = _updatingSprites.unsafeGet(i);
            if (!sprite.paused && sprite.autoUpdate) {
                sprite.update(delta);
            }
            #end
        }

        // Cleanup array
        for (i in 0...len) {
            #if cs
            _updatingSprites[i] = null;
            #else
            _updatingSprites.unsafeSet(i, null);
            #end
        }

    }

}
