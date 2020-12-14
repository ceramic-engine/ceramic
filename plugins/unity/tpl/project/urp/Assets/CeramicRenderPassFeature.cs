
using System;
using UnityEngine;
using UnityEngine.Rendering;

public class CeramicRenderPassFeature : UnityEngine.Rendering.Universal.ScriptableRendererFeature
{
    public class CeramicRenderPass : UnityEngine.Rendering.Universal.ScriptableRenderPass
    {
        CommandBuffer m_CommandBuffer;

        public CommandBuffer GetCommandBuffer() {
            return m_CommandBuffer;
        }

        public void SetCommandBuffer(CommandBuffer cmd) {
            m_CommandBuffer = cmd;
        }

        RenderTargetIdentifier m_RenderTarget;

        public RenderTargetIdentifier GetRenderTarget() {
            return m_RenderTarget;
        }

        public void SetRenderTarget(RenderTargetIdentifier target) {
            m_RenderTarget = target;
        }
 
        // This method is called before executing the render pass.
        // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
        // When empty this render pass will render to the active camera render target.
        // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
        // The render pipeline will ensure target setup and clearing happens in an performance manner.
        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            if (GetRenderTarget() == UnityEngine.Rendering.BuiltinRenderTextureType.CameraTarget) {
                // Use default render target
            }
            else {
                ConfigureTarget(GetRenderTarget());
            }
        }
 
        // Here you can implement the rendering logic.
        // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
        // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
        // You don't have to call ScriptableRenderContext.submit, the render pipeline will call it at specific points in the pipeline.
        public override void Execute(ScriptableRenderContext context, ref UnityEngine.Rendering.Universal.RenderingData renderingData)
        {
            CommandBuffer cmd = GetCommandBuffer();
            SetCommandBuffer(null);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
 
        /// Cleanup any allocated resources that were created during the execution of this render pass.
        public override void FrameCleanup(CommandBuffer cmd)
        {
        }
    }
 
    //CeramicRenderPass m_ScriptablePass;
 
    public override void Create()
    {
        //m_ScriptablePass = new CeramicRenderPass();
 
        // Configures where the render pass should be injected.
        //m_ScriptablePass.renderPassEvent = UnityEngine.Rendering.Universal.RenderPassEvent.AfterRenderingOpaques;
    }
 
    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(UnityEngine.Rendering.Universal.ScriptableRenderer renderer, ref UnityEngine.Rendering.Universal.RenderingData renderingData)
    {
        global::backend.Draw.unityUrpAddRenderPasses(renderer, renderingData);
        //renderer.EnqueuePass(m_ScriptablePass);
    }
}
