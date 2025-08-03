package unityengine;

/**
 * Unity Object class extern binding for Ceramic.
 * Base class for all Unity objects that can exist in scenes.
 * 
 * This is a minimal binding that includes object lifecycle management
 * methods used by the Ceramic Unity backend.
 */
@:native('UnityEngine.Object')
extern class Object {

    /**
     * Returns the instance ID of the object.
     * The instance ID is a unique identifier for each object instance,
     * guaranteed to be unique throughout the lifetime of the object.
     * 
     * @return Unique integer identifier for this object instance
     */
    function GetInstanceID():Int;

    /**
     * Removes a GameObject, component or asset after a specified delay.
     * The object will be destroyed at the beginning of the next frame
     * after the delay has passed.
     * 
     * @param obj The object to destroy
     * @param t Optional delay in seconds before destroying the object (default: 0.0)
     */
    static function Destroy(obj:Object, t:Single = 0.0):Void;

    /**
     * Destroys the object immediately. You should use Destroy instead.
     * This function should only be used when writing editor code or
     * when you need to destroy an object during serialization callbacks.
     * 
     * @param obj The object to destroy immediately
     * @param allowDestroyingAssets If true, allows destroying assets (default: false)
     */
    static function DestroyImmediate(obj:Object, allowDestroyingAssets:Bool = false):Void;

    /**
     * Makes the object persistent across scene loads.
     * The object will not be destroyed when loading a new scene.
     * Commonly used for singleton managers or persistent game state.
     * 
     * @param target The object to make persistent
     */
    static function DontDestroyOnLoad(target:Object):Void;

}
