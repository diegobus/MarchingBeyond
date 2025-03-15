using System.Collections.Generic;
using UnityEngine;

// Attach this script to a manager GameObject in your scene
public class RaymarchingSceneManager : MonoBehaviour
{
    // Represents a shape that can be raymarched
    public enum ShapeType { Sphere, Cube, Torus, Mandelbulb }
    public enum Operation { Union, Blend, Cut, Mask }

    // This class defines a shape in the scene
    [System.Serializable]
    public class RaymarchShape
    {
        public ShapeType shapeType;
        public Operation operation;
        public Transform transform;
        public Color color = Color.white;
        [Range(0, 1)]
        public float blendStrength = 0.5f;
        [Range(1, 16)]
        public float specialParam1 = 8f; // Fractal power for Mandelbulb
        [Range(1, 20)]
        public float specialParam2 = 10f; // Fractal iterations for Mandelbulb
    }

    // List of shapes to raymarch
    public List<RaymarchShape> shapes = new List<RaymarchShape>();

    // Reference to your render feature
    public SDFRenderFeature renderFeature;

    // Buffer for passing shape data to the shader
    private ComputeBuffer shapeBuffer;

    // Struct matching the one in the shader
    struct ShapeData
    {
        public Vector3 position;
        public Vector3 scale;
        public Vector4 color; // Using Vector4 for alignment
        public int shapeType;
        public int operation;
        public float blendStrength;
        public float specialParam1;
        public float specialParam2;
        public int numChildren;
        public float padding1; // For alignment
        public float padding2; // For alignment
        public float padding3; // For alignment

        // Size of the struct in bytes
        public static int GetSize()
        {
            return
                sizeof(float) * 3 + // position
                sizeof(float) * 3 + // scale
                sizeof(float) * 4 + // color (Vector4)
                sizeof(int) + // shapeType
                sizeof(int) + // operation
                sizeof(float) + // blendStrength
                sizeof(float) + // specialParam1
                sizeof(float) + // specialParam2
                sizeof(int) + // numChildren
                sizeof(float) * 3; // padding
        }
    }

    void OnEnable()
    {
        // Create initial buffer
        UpdateShapeBuffer();
    }

    void OnDisable()
    {
        // Clean up buffer when disabled
        ReleaseBuffer();
    }

    // Call this when shapes change in the scene
    public void UpdateShapeBuffer()
    {
        // Release the old buffer if it exists
        ReleaseBuffer();

        if (shapes.Count == 0 || renderFeature == null || renderFeature.raymarchMaterial == null)
            return;

        // Create a new buffer
        shapeBuffer = new ComputeBuffer(shapes.Count, ShapeData.GetSize());

        // Fill the buffer with shape data
        ShapeData[] shapeData = new ShapeData[shapes.Count];

        for (int i = 0; i < shapes.Count; i++)
        {
            var shape = shapes[i];
            if (shape.transform == null) continue;

            shapeData[i] = new ShapeData
            {
                position = shape.transform.position,
                scale = shape.transform.lossyScale,
                color = new Vector4(shape.color.r, shape.color.g, shape.color.b, shape.color.a),
                shapeType = (int)shape.shapeType,
                operation = (int)shape.operation,
                blendStrength = shape.blendStrength,
                specialParam1 = shape.specialParam1,
                specialParam2 = shape.specialParam2,
                numChildren = 0 // For now, not handling hierarchies
            };
        }

        // Set the data in the buffer
        shapeBuffer.SetData(shapeData);

        // Set the buffer and count in the shader
        renderFeature.raymarchMaterial.SetBuffer("_Shapes", shapeBuffer);
        renderFeature.raymarchMaterial.SetInt("_NumShapes", shapes.Count);
    }

    private void ReleaseBuffer()
    {
        if (shapeBuffer != null)
        {
            shapeBuffer.Release();
            shapeBuffer = null;
        }
    }

    // Update shapes every frame (for movement)
    void Update()
    {
        if (renderFeature?.raymarchMaterial != null && shapeBuffer != null)
        {
            // Update only the positions and scales if objects move
            ShapeData[] shapeData = new ShapeData[shapes.Count];
            shapeBuffer.GetData(shapeData);

            bool hasChanges = false;

            for (int i = 0; i < shapes.Count; i++)
            {
                if (shapes[i].transform != null)
                {
                    // Check if position or scale changed
                    if (shapeData[i].position != shapes[i].transform.position ||
                        shapeData[i].scale != shapes[i].transform.lossyScale)
                    {
                        shapeData[i].position = shapes[i].transform.position;
                        shapeData[i].scale = shapes[i].transform.lossyScale;
                        hasChanges = true;
                    }
                }
            }

            if (hasChanges)
            {
                shapeBuffer.SetData(shapeData);
            }
        }
    }

    // Add shape convenience methods
    public void AddShape(ShapeType type, Transform transform, Color color, Operation op = Operation.Union)
    {
        var newShape = new RaymarchShape
        {
            shapeType = type,
            transform = transform,
            color = color,
            operation = op
        };

        shapes.Add(newShape);
        UpdateShapeBuffer();
    }

    public void RemoveShape(Transform transform)
    {
        shapes.RemoveAll(s => s.transform == transform);
        UpdateShapeBuffer();
    }
}