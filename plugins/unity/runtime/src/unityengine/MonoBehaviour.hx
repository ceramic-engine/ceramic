package unityengine;

import unityengine.GameObject;

/**
 * Unity MonoBehaviour class extern binding for Ceramic.
 * The base class for Unity scripts that can be attached to GameObjects.
 * 
 * MonoBehaviour is the foundation for most Unity gameplay code.
 * This binding exposes the essential properties needed by the
 * Ceramic Unity backend for script management.
 */
@:native('UnityEngine.MonoBehaviour')
extern class MonoBehaviour extends Behaviour {

    /**
     * Controls whether this component is enabled and will receive updates.
     * When false, Unity lifecycle methods like Update() won't be called.
     * The component remains attached to the GameObject.
     */
    var enabled:Bool;

    /**
     * Reports if the component is both enabled and its GameObject is active.
     * This is true only when both enabled=true and the GameObject is
     * active in the hierarchy. Read-only property.
     */
    var isActiveAndEnabled:Bool;

    /**
     * Reference to the GameObject this component is attached to.
     * Every component must be attached to exactly one GameObject.
     * Use this to access other components on the same GameObject.
     */
    var gameObject:GameObject;

    /**
     * The tag of the GameObject this component is attached to.
     * Shorthand for gameObject.tag. Tags are used to identify
     * GameObjects for scripting purposes.
     */
    var tag:String;

    /**
     * The name of the GameObject this component is attached to.
     * Shorthand for gameObject.name. Useful for debugging and
     * finding specific objects in the scene.
     */
    var name:String;

}
