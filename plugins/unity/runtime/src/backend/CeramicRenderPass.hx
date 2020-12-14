package backend;

import unityengine.rendering.CommandBuffer;
import unityengine.rendering.universal.ScriptableRenderPass;

@:native('CeramicRenderPassFeature.CeramicRenderPass')
extern class CeramicRenderPass extends ScriptableRenderPass {

    function new();

    function GetCommandBuffer():CommandBuffer;

    function SetCommandBuffer(cmd:CommandBuffer):Void;

}