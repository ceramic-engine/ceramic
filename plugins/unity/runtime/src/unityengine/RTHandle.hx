package unityengine;

/**
 * A handle to a render texture in Unity's Scriptable Render Pipeline.
 * RTHandles provide an abstraction over RenderTextures with automatic
 * scaling and resource management.
 * 
 * Part of Unity's Render Pipeline (URP/HDRP) infrastructure, RTHandles
 * enable dynamic resolution scaling and efficient texture pooling.
 * 
 * In Ceramic's Unity backend, RTHandles may be used when integrating
 * with Unity's modern rendering pipelines for advanced effects.
 * 
 * Key benefits over RenderTexture:
 * - Automatic resolution scaling with screen size
 * - Memory pooling and reuse
 * - Integration with SRP render passes
 * - Dynamic resolution support
 * 
 * Note: This is primarily used internally by Unity's rendering
 * systems and advanced custom render passes.
 * 
 * @see RenderTexture
 */
@:native('UnityEngine.Rendering.RTHandle')
extern class RTHandle {

}
