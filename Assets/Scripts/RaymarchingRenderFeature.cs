using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class RaymarchingRenderFeature : ScriptableRendererFeature
{
    class RaymarchingRenderPass : ScriptableRenderPass
    {
        public Material raymarchMaterial = null;
        private string profilerTag = "RaymarchingPass";

        public RaymarchingRenderPass(Material material)
        {
            raymarchMaterial = material;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (raymarchMaterial == null)
                return;

            CommandBuffer cmd = CommandBufferPool.Get(profilerTag);
            
            // Unity automatically sets _ScreenParams, no need to set it manually

            // Get the camera's current color target.
            RenderTargetIdentifier cameraColorTarget = renderingData.cameraData.renderer.cameraColorTargetHandle;

            // Blit the current camera color target to itself using the raymarching material.
            // This applies your raymarching effect over the entire screen.
            cmd.Blit(cameraColorTarget, cameraColorTarget, raymarchMaterial);

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }

    public Material raymarchMaterial;
    public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingTransparents;

    RaymarchingRenderPass raymarchPass;

    public override void Create()
    {
        raymarchPass = new RaymarchingRenderPass(raymarchMaterial)
        {
            renderPassEvent = renderPassEvent
        };
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (raymarchMaterial != null)
            renderer.EnqueuePass(raymarchPass);
    }
}
