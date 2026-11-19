package ceramic;

using ceramic.Extensions;

/**
 * System that manages automatic updates for all Sprite instances.
 * Handles animation frame progression and timing for sprites with autoUpdate enabled.
 * 
 * This system is automatically created as a singleton and runs during the
 * late update phase to ensure sprites are updated after all other logic.
 * 
 * Sprites are automatically registered/unregistered when created/destroyed.
 */
@:allow(ceramic.Sprite)
class SpriteSystem extends System {

    /**
     * Shared sprite system singleton.
     * Automatically created on first access.
     */
    @lazy public static var shared = new SpriteSystem();

    /**
     * Internal array of all active sprites.
     */
    var sprites:Array<Sprite<Any>> = [];

    var _updatingSprites:Array<Sprite<Any>> = [];

    override function new() {

        super();

        // Run during late update to ensure sprites update after game logic
        lateUpdateOrder = 3000;

    }

    /**
     * Update all sprites that have autoUpdate enabled and are not paused.
     * Works on a copy of the sprite list to avoid issues if sprites are
     * created or destroyed during iteration.
     * @param delta Time elapsed since last frame in seconds
     */
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
