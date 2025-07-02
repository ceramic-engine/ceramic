using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.RenderGraphModule;

public class CeramicRenderPassFeature : ScriptableRendererFeature
{
    public class CeramicRenderPass : ScriptableRenderPass
    {
        CommandBuffer m_CommandBuffer;
        CeramicCommandBuffer m_CeramicCommandBuffer;

        public CommandBuffer GetCommandBuffer()
        {
            return m_CommandBuffer;
        }

        public void SetCommandBuffer(CommandBuffer cmd)
        {
            m_CommandBuffer = cmd;
        }

        public CeramicCommandBuffer GetCeramicCommandBuffer()
        {
            return m_CeramicCommandBuffer;
        }

        public void SetCeramicCommandBuffer(CeramicCommandBuffer cmd)
        {
            m_CeramicCommandBuffer = cmd;
        }

        RTHandle m_RenderTarget;
        RenderTargetInfo m_RenderTarget_Info;

        RTHandle m_RenderTargetDepth;
        RenderTargetInfo m_RenderTargetDepth_Info;

        public RTHandle GetRenderTarget()
        {
            return m_RenderTarget;
        }

        public void SetRenderTarget(RTHandle target)
        {
            m_RenderTarget = target;
            if (target != null)
            {
                m_RenderTarget_Info = CreateRenderTargetInfo(target);
            }
        }

        public RTHandle GetRenderTargetDepth()
        {
            return m_RenderTargetDepth;
        }

        public void SetRenderTargetDepth(RTHandle targetDepth)
        {
            m_RenderTargetDepth = targetDepth;
            if (targetDepth != null)
            {
                m_RenderTargetDepth_Info = CreateRenderTargetInfo(targetDepth);
            }
        }

        private RenderTargetInfo CreateRenderTargetInfo(RTHandle rtHandle)
        {
            var desc = rtHandle.rt.descriptor;
            return new RenderTargetInfo
            {
                width = desc.width,
                height = desc.height,
                volumeDepth = desc.volumeDepth,
                msaaSamples = desc.msaaSamples,
                format = desc.graphicsFormat
            };
        }

        // Render Graph version - executes command buffer via Graphics.ExecuteCommandBuffer
        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            if (!Application.isPlaying)
                return;

            using (var builder = renderGraph.AddRasterRenderPass<PassData>("Ceramic Render Pass", out var passData))
            {
                // Get camera data from frame data
                var cameraData = frameData.Get<UniversalCameraData>();
                var resourceData = frameData.Get<UniversalResourceData>();

                // Set up color render attachment
                if (GetRenderTarget() != null)
                {
                    // Use custom render target
                    var colorTargetHandle = renderGraph.ImportTexture(GetRenderTarget(), m_RenderTarget_Info);
                    builder.SetRenderAttachment(colorTargetHandle, 0, AccessFlags.Write);
                    passData.colorTarget = colorTargetHandle;
                }
                else
                {
                    // Use camera's active color target
                    builder.SetRenderAttachment(resourceData.activeColorTexture, 0, AccessFlags.Write);
                    passData.colorTarget = resourceData.activeColorTexture;
                }

                // Set up depth render attachment
                if (GetRenderTargetDepth() != null)
                {
                    // Use custom depth target
                    var depthTargetHandle = renderGraph.ImportTexture(GetRenderTargetDepth(), m_RenderTargetDepth_Info);
                    builder.SetRenderAttachmentDepth(depthTargetHandle, AccessFlags.Write);
                    passData.depthTarget = depthTargetHandle;
                }
                else
                {
                    // Use camera's active depth target
                    builder.SetRenderAttachmentDepth(resourceData.activeDepthTexture, AccessFlags.Write);
                    passData.depthTarget = resourceData.activeDepthTexture;
                }

                // Store command buffer in pass data
                passData.commandBuffer = GetCeramicCommandBuffer();

                // Set execution function
                builder.SetRenderFunc((PassData data, RasterGraphContext context) =>
                {
                    if (data.commandBuffer != null)
                    {
                        var cmd = context.cmd;
                        data.commandBuffer.ApplyToRasterCommandBuffer(cmd);
                        CeramicCommandBufferPool.Release(data.commandBuffer);
                    }
                });
            }

            // Clear the stored command buffer since it's been queued for execution
            SetCommandBuffer(null);
        }

        // Legacy fallback methods for compatibility mode (when Render Graph is disabled)
        [System.Obsolete("This rendering path is for compatibility mode only (when Render Graph is disabled). Use Render Graph API instead.")]
        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            if (GetRenderTarget() != null)
            {
                ConfigureTarget(GetRenderTarget());
            }
        }

        [System.Obsolete("This rendering path is for compatibility mode only (when Render Graph is disabled). Use Render Graph API instead.")]
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = GetCommandBuffer();
            if (cmd != null)
            {
                SetCommandBuffer(null);
                context.ExecuteCommandBuffer(cmd);
                CommandBufferPool.Release(cmd);
            }
        }

        // Data structure for passing information to the render function
        private class PassData
        {
            public TextureHandle colorTarget;
            public TextureHandle depthTarget;
            public CeramicCommandBuffer commandBuffer;
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
        //m_ScriptablePass.renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        global::backend.Draw.unityUrpAddRenderPasses(renderer, renderingData);
        //renderer.EnqueuePass(m_ScriptablePass);
    }
}