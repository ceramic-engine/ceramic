package ceramic;

using ceramic.Extensions;

@:allow(ceramic.Sprite)
class SpriteSystem extends System {

    /**
     * Shared sprite system
     */
    @lazy public static var shared = new SpriteSystem();

    var sprites:Array<Sprite<Any>> = [];

    var _updatingSprites:Array<Sprite<Any>> = [];

    override function new() {

        super();

        lateUpdateOrder = 3000;

    }

    override function lateUpdate(delta:Float):Void {

        // Work on a copy of list, to ensure nothing bad happens
        // if a new item is created or destroyed during iteration
        var len = sprites.length;
        for (i in 0...len) {
            _updatingSprites[i] = sprites.unsafeGet(i);
        }

        // Call
        for (i in 0...len) {
            var sprite = _updatingSprites.unsafeGet(i);
            if (!sprite.paused && sprite.autoUpdate) {
                sprite.update(delta);
            }
        }

        // Cleanup array
        for (i in 0...len) {
            _updatingSprites.unsafeSet(i, null);
        }

    }

}
