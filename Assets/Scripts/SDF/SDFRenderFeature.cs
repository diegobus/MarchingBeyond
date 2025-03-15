using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class SDFRenderFeature : ScriptableRendererFeature
{
    class RaymarchingRenderPass : ScriptableRenderPass
    {
        public Material raymarchMaterial = null;
        private string profilerTag = "RaymarchingPass";
        private Camera currentCamera;

        public RaymarchingRenderPass(Material material)
        {
            raymarchMaterial = material;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (raymarchMaterial == null)
                return;

            CommandBuffer cmd = CommandBufferPool.Get(profilerTag);

            // Get current camera info
            currentCamera = renderingData.cameraData.camera;

            // Set camera matrices
            if (currentCamera != null)
            {
                raymarchMaterial.SetMatrix("_CameraToWorld", currentCamera.cameraToWorldMatrix);
                raymarchMaterial.SetMatrix("_CameraInverseProjection", currentCamera.projectionMatrix.inverse);
                raymarchMaterial.SetVector("_CameraPosition", currentCamera.transform.position);
            }

            // Find main light for shading
            Light mainLight = null;
            foreach (var visibleLight in renderingData.lightData.visibleLights)
            {
                if (visibleLight.lightType == LightType.Directional)
                {
                    mainLight = visibleLight.light;
                    break;
                }
            }

            if (mainLight != null)
            {
                Vector3 lightDir = mainLight.transform.forward;
                raymarchMaterial.SetVector("_LightDirection", -lightDir); // Negate for "coming from" direction
                raymarchMaterial.SetColor("_LightColor", mainLight.color * mainLight.intensity);
            }
            else
            {
                // Default light from above if no light found
                raymarchMaterial.SetVector("_LightDirection", new Vector3(0.5f, -0.5f, -0.5f).normalized);
                raymarchMaterial.SetColor("_LightColor", Color.white);
            }

            // Get the camera's current color target
            RenderTargetIdentifier cameraColorTarget = renderingData.cameraData.renderer.cameraColorTargetHandle;

            // Apply the raymarching effect
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