using UnityEngine;

public class Master : MonoBehaviour
{
    public ComputeShader raymarching; // Assign your compute shader in the Inspector
    public Light directionalLight;    // Assign a directional light (optional)

    private RenderTexture target;

    // Create or update the render texture
    void InitRenderTexture()
    {
        if (target == null || target.width != Screen.width || target.height != Screen.height)
        {
            if (target != null)
            {
                target.Release();
            }
            target = new RenderTexture(Screen.width, Screen.height, 0, RenderTextureFormat.ARGBFloat);
            target.enableRandomWrite = true;
            target.Create();
        }
    }

    // Called after the camera has finished rendering
    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        InitRenderTexture();

        // Get current camera
        Camera cam = Camera.current;

        // Set matrices for ray direction calculation in the compute shader
        raymarching.SetMatrix("_CameraToWorld", cam.cameraToWorldMatrix);
        raymarching.SetMatrix("_CameraInverseProjection", cam.projectionMatrix.inverse);

        // Set light direction (if a light is assigned)
        if (directionalLight != null)
        {
            raymarching.SetVector("_LightDirection", directionalLight.transform.forward);
        }
        else
        {
            raymarching.SetVector("_LightDirection", Vector3.forward);
        }

        // Bind the output render texture to the shader
        raymarching.SetTexture(0, "Result", target);

        // Calculate thread groups based on texture dimensions (our compute shader uses 8x8 threads)
        int threadGroupsX = Mathf.CeilToInt(Screen.width / 8.0f);
        int threadGroupsY = Mathf.CeilToInt(Screen.height / 8.0f);
        raymarching.Dispatch(0, threadGroupsX, threadGroupsY, 1);

        // Blit the result texture to the screen
        Graphics.Blit(target, destination);
    }
}
