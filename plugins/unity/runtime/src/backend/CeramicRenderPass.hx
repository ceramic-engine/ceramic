package backend;

import unityengine.rendering.CommandBuffer;
import unityengine.rendering.universal.ScriptableRenderPass;

#if !no_backend_docs
/**
 * External interface to Unity's native CeramicRenderPass C# class.
 * 
 * This is a custom render pass for Unity's Universal Render Pipeline (URP)
 * that handles Ceramic's 2D rendering. It extends ScriptableRenderPass to
 * integrate seamlessly with Unity's rendering pipeline while providing
 * optimized paths for Ceramic's specific needs.
 * 
 * The render pass is responsible for:
 * - Executing command buffers at the appropriate rendering stage
 * - Managing render state for 2D graphics
 * - Handling render targets and viewport setup
 * - Coordinating with Unity's render graph system (when available)
 * 
 * The implementation supports both legacy command buffer mode and the newer
 * render graph API, automatically selecting based on Unity version and settings.
 * 
 * @see ScriptableRenderPass Unity's base class for custom render passes
 * @see backend.Draw Creates and manages these render passes
 * @see CeramicCommandBuffer Commands executed by this pass
 */
#end
@:native('CeramicRenderPassFeature.CeramicRenderPass')
extern class CeramicRenderPass extends ScriptableRenderPass {

    #if !no_backend_docs
    /**
     * Creates a new CeramicRenderPass instance.
     * Typically managed by the rendering system rather than created directly.
     */
    #end
    function new();

    #if unity_rendergraph
    #if !no_backend_docs
    /**
     * Gets the Ceramic command buffer for render graph mode.
     * Used when Unity's render graph is enabled for more efficient rendering.
     * 
     * @return The current Ceramic command buffer
     */
    #end
    function GetCeramicCommandBuffer():CeramicCommandBuffer;
    
    #if !no_backend_docs
    /**
     * Sets the Ceramic command buffer for render graph mode.
     * The render pass will execute this buffer during its execution phase.
     * 
     * @param cmd The Ceramic command buffer to execute
     */
    #end
    function SetCeramicCommandBuffer(cmd:CeramicCommandBuffer):Void;
    #else
    #if !no_backend_docs
    /**
     * Gets the standard Unity command buffer for legacy mode.
     * Used when render graph is not available or disabled.
     * 
     * @return The current Unity command buffer
     */
    #end
    function GetCommandBuffer():CommandBuffer;
    
    #if !no_backend_docs
    /**
     * Sets the standard Unity command buffer for legacy mode.
     * The render pass will execute this buffer during its execution phase.
     * 
     * @param cmd The Unity command buffer to execute
     */
    #end
    function SetCommandBuffer(cmd:CommandBuffer):Void;
    #end

}