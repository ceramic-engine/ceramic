package unityengine;

/**
 * Unity GameObject class extern binding for Ceramic.
 * The fundamental object in Unity scenes representing entities
 * that can have components attached.
 * 
 * This is a minimal binding exposing properties used by
 * the Ceramic Unity backend for scene management.
 */
@:native('UnityEngine.GameObject')
extern class GameObject extends Object {

    /**
     * Checks if the GameObject is active in the scene hierarchy.
     * Returns true only if the GameObject and all its parents are active.
     * This determines whether the GameObject is actually processed and rendered.
     */
    var activeInHierarchy:Bool;

    /**
     * The local active state of this GameObject.
     * This property ignores the active state of parent GameObjects.
     * Read-only - use SetActive() to change the active state.
     */
    var activeSelf(default, null):Bool;

    /**
     * Controls whether the GameObject is static for optimization purposes.
     * Static GameObjects can be batched more efficiently and are included
     * in precomputed lighting and navigation data.
     * Should be set to true for non-moving environment objects.
     */
    var isStatic:Bool;

    /**
     * The layer this GameObject is assigned to (0-31).
     * Layers are used for selective rendering, physics collisions,
     * and raycasting. Layer 0 is the default layer.
     * 
     * Common Unity layers:
     * - 0: Default
     * - 2: Ignore Raycast  
     * - 5: UI
     */
    var layer:Int;

    /**
     * The tag assigned to this GameObject.
     * Tags are used to identify GameObjects for scripting purposes.
     * Common tags include "Player", "Enemy", "MainCamera", etc.
     * Default tag is "Untagged".
     */
    var tag:String;

}
