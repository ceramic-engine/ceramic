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

        // Render Graph version - records the ceramic command buffer as a raster pass (camera-sized
        // targets, mergeable) or as an unsafe pass (off-size targets, see RecordOffscreenUnsafe).
        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            if (!Application.isPlaying)
                return;

            // Get camera data from frame data
            var cameraData = frameData.Get<UniversalCameraData>();
            var resourceData = frameData.Get<UniversalResourceData>();

            // A custom render target whose fragment setup (dimensions or sample count) differs
            // from the camera target CANNOT share the camera's native render pass: URP's
            // NativePassCompiler would try to merge it and throw "Mismatch in fragment dimensions"
            // (e.g. an off-size offscreen target like a shadow map vs the camera). Render those in
            // their OWN pass via AddUnsafePass — manual SetRenderTarget, excluded from native-pass
            // merging — still scheduled and tracked inside RenderGraph (no immediate
            // Graphics.ExecuteCommandBuffer side-channel).
            if (GetRenderTarget() != null &&
                (m_RenderTarget_Info.width != cameraData.cameraTargetDescriptor.width ||
                 m_RenderTarget_Info.height != cameraData.cameraTargetDescriptor.height ||
                 m_RenderTarget_Info.msaaSamples != cameraData.cameraTargetDescriptor.msaaSamples))
            {
                RecordOffscreenUnsafe(renderGraph);
                SetCommandBuffer(null);
                return;
            }

            using (var builder = renderGraph.AddRasterRenderPass<PassData>("Ceramic Render Pass", out var passData))
            {
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

        // Off-size custom target: render in its own pass, OUTSIDE native-pass merging, but still
        // within RenderGraph. AddUnsafePass lets us SetRenderTarget manually (raster passes can't),
        // so URP's NativePassCompiler never tries to merge this differently-sized target into the
        // camera's native pass. The produced texture is sampled later by the main pass (via a
        // MaterialPropertyBlock, like the IBL maps), ordered by enqueue order + AllowPassCulling.
        void RecordOffscreenUnsafe(RenderGraph renderGraph)
        {
            using (var builder = renderGraph.AddUnsafePass<PassData>("Ceramic Render Pass (offscreen)", out var passData))
            {
                // Declare the imported external textures as written (RenderGraph resource tracking),
                // and keep the RTHandles for the manual SetRenderTarget in the render func.
                var colorHandle = renderGraph.ImportTexture(GetRenderTarget(), m_RenderTarget_Info);
                builder.UseTexture(colorHandle, AccessFlags.Write);
                passData.colorRT = GetRenderTarget();

                if (GetRenderTargetDepth() != null)
                {
                    var depthHandle = renderGraph.ImportTexture(GetRenderTargetDepth(), m_RenderTargetDepth_Info);
                    builder.UseTexture(depthHandle, AccessFlags.Write);
                    passData.depthRT = GetRenderTargetDepth();
                    passData.hasDepth = true;
                }
                else
                {
                    passData.hasDepth = false;
                }

                passData.commandBuffer = GetCeramicCommandBuffer();
                builder.AllowPassCulling(false);

                builder.SetRenderFunc((PassData data, UnsafeGraphContext context) =>
                {
                    // Unwrap the native CommandBuffer (unsafe passes expose an UnsafeCommandBuffer).
                    CommandBuffer cmd = CommandBufferHelpers.GetNativeCommandBuffer(context.cmd);
                    if (data.hasDepth)
                        cmd.SetRenderTarget(data.colorRT, data.depthRT);
                    else
                        cmd.SetRenderTarget(data.colorRT);
                    if (data.commandBuffer != null)
                    {
                        data.commandBuffer.ApplyToCommandBuffer(cmd);
                        CeramicCommandBufferPool.Release(data.commandBuffer);
                    }
                });
            }
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
            // Offscreen (unsafe) path: the RTHandles bound manually via cmd.SetRenderTarget.
            public RTHandle colorRT;
            public RTHandle depthRT;
            public bool hasDepth;
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