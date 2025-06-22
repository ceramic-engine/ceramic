package backend;

import unityengine.rendering.CommandBuffer;
import unityengine.rendering.universal.ScriptableRenderPass;

@:native('CeramicRenderPassFeature.CeramicRenderPass')
extern class CeramicRenderPass extends ScriptableRenderPass {

    function new();

    #if unity_rendergraph
    function GetCeramicCommandBuffer():CeramicCommandBuffer;
    function SetCeramicCommandBuffer(cmd:CeramicCommandBuffer):Void;
    #else
    function GetCommandBuffer():CommandBuffer;
    function SetCommandBuffer(cmd:CommandBuffer):Void;
    #end

}