using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteInEditMode]
public class RaymarchManager : MonoBehaviour
{
    public Material raymarchMaterial;
    public SDFRenderFeature renderFeature;

    private Light mainLight;
    private ComputeBuffer shapeBuffer;

    // Structure to match the shader buffer
    struct ShapeData
    {
        public Vector3 position;
        public Vector3 scale;
        public Vector4 color;
        public Vector3 rotation;
        public int shapeType;
        public int operation;
        public float blendStrength;
        public int numChildren;
        public float padding1; // For alignment

        public static int GetSize()
        {
            return
                sizeof(float) * 3 + // position
                sizeof(float) * 3 + // scale
                sizeof(float) * 4 + // color
                sizeof(float) * 3 + // rotation
                sizeof(int) + // shapeType
                sizeof(int) + // operation
                sizeof(float) + // blendStrength
                sizeof(int) + // numChildren
                sizeof(float); // padding
        }
    }

    void OnEnable()
    {
        // Make sure our shader gets updated with camera data
        Camera.onPreCull += UpdateCameraData;

        if (renderFeature != null)
            renderFeature.raymarchMaterial = raymarchMaterial;

        // Initially update scene data
        UpdateScene();
    }

    void OnDisable()
    {
        Camera.onPreCull -= UpdateCameraData;

        if (shapeBuffer != null)
        {
            shapeBuffer.Release();
            shapeBuffer = null;
        }
    }

    // Called before camera render
    void UpdateCameraData(Camera camera)
    {
        if (raymarchMaterial != null && camera == Camera.main)
        {
            // Update camera matrices
            raymarchMaterial.SetMatrix("_CameraToWorld", camera.cameraToWorldMatrix);
            raymarchMaterial.SetMatrix("_CameraInverseProjection", camera.projectionMatrix.inverse);
            raymarchMaterial.SetVector("_CameraPosition", camera.transform.position);

            // Update light info
            if (mainLight == null)
                mainLight = FindObjectOfType<Light>();

            if (mainLight != null)
            {
                raymarchMaterial.SetVector("_LightDirection", mainLight.transform.forward);
                raymarchMaterial.SetColor("_LightColor", mainLight.color * mainLight.intensity);
            }
        }
    }

    void UpdateScene()
    {
        if (raymarchMaterial == null)
            return;

        // Get all shapes in the scene
        List<RaymarchShape> allShapes = new List<RaymarchShape>(FindObjectsOfType<RaymarchShape>());

        // Sort by operation to make sure parents come before children
        allShapes.Sort((a, b) => a.operation.CompareTo(b.operation));

        // Organize shapes into a hierarchy-aware list
        List<RaymarchShape> organizedShapes = new List<RaymarchShape>();

        foreach (var shape in allShapes)
        {
            // Only add top-level shapes (those without a parent with RaymarchShape)
            if (shape.transform.parent == null || shape.transform.parent.GetComponent<RaymarchShape>() == null)
            {
                Transform parentTransform = shape.transform;
                organizedShapes.Add(shape);

                // Count direct children with RaymarchShape component
                int childCount = 0;
                for (int j = 0; j < parentTransform.childCount; j++)
                {
                    if (parentTransform.GetChild(j).GetComponent<RaymarchShape>() != null)
                    {
                        childCount++;
                        organizedShapes.Add(parentTransform.GetChild(j).GetComponent<RaymarchShape>());
                    }
                }

                // Update child count on the parent
                shape.numChildren = childCount;
            }
        }

        // Create shape data array
        ShapeData[] shapeData = new ShapeData[organizedShapes.Count];

        for (int i = 0; i < organizedShapes.Count; i++)
        {
            var shape = organizedShapes[i];

            shapeData[i] = new ShapeData
            {
                position = shape.Position,
                scale = shape.Scale,
                rotation = shape.Rotation,
                color = new Vector4(shape.color.r, shape.color.g, shape.color.b, shape.color.a),
                shapeType = (int)shape.shapeType,
                operation = (int)shape.operation,
                blendStrength = shape.blendStrength,
                numChildren = shape.numChildren
            };
        }

        // Create or update the compute buffer
        if (shapeBuffer != null)
            shapeBuffer.Release();

        if (shapeData.Length > 0)
        {
            shapeBuffer = new ComputeBuffer(shapeData.Length, ShapeData.GetSize());
            shapeBuffer.SetData(shapeData);

            raymarchMaterial.SetBuffer("_Shapes", shapeBuffer);
            raymarchMaterial.SetInt("_NumShapes", shapeData.Length);
        }
        else
        {
            raymarchMaterial.SetInt("_NumShapes", 0);
        }
    }

    void Update()
    {
        // Update scene data each frame to capture changes in transforms
        UpdateScene();
    }
}