package unityengine;

/**
 * Unity Behaviour class extern binding for Ceramic.
 * Base class for components that can be enabled or disabled.
 * 
 * Behaviours are Components that can be turned on and off.
 * This includes MonoBehaviour scripts, as well as built-in
 * components like Colliders and Renderers.
 * 
 * This is a minimal binding that serves as an intermediate
 * base class in Unity's component hierarchy.
 */
@:native('UnityEngine.Behaviour')
extern class Behaviour extends Component {

}
