using UnityEngine;

public class RaymarchShape : MonoBehaviour
{
    public enum ShapeType { Sphere, Cube, Torus }
    public enum Operation { Union, Blend, Cut, Mask }

    public ShapeType shapeType;
    public Operation operation;
    public Color color = Color.white;
    [Range(0, 1)]
    public float blendStrength = 0.5f;

    // To track parent/child relationships
    [HideInInspector]
    public int numChildren;

    // Access transform data
    public Vector3 Position
    {
        get { return transform.position; }
    }

    public Vector3 Scale
    {
        get
        {
            // Get inherited scale from parent shape, if any
            Vector3 parentScale = Vector3.one;
            if (transform.parent != null && transform.parent.GetComponent<RaymarchShape>() != null)
            {
                parentScale = transform.parent.GetComponent<RaymarchShape>().Scale;
            }
            return Vector3.Scale(transform.localScale, parentScale);
        }
    }
}