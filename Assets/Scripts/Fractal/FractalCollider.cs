using UnityEngine;

public class Player : MonoBehaviour
{
    [Header("Fractal Settings")]
    [Tooltip("Matches the _Scale property in the shader.")]
    public float fractalScale = 1.0f;
    [Tooltip("Matches the _CSize property in the shader.")]
    public float clampSize = 1.0f;
    [Tooltip("Number of iterations used in the fractal SDF. The shader uses 8 iterations by default.")]
    public int fractalIterations = 8;

    [Header("Collision Settings")]
    [Tooltip("Minimum allowed distance from the fractal surface.")]
    public float safeDistance = 0.5f;
    [Tooltip("Multiplier for how strongly the object is pushed out of the fractal.")]
    public float pushStrength = 1.0f;

    /// <summary>
    /// Approximate signed distance function for the fractal.
    /// This function mimics the shader’s sdFractal() routine.
    /// It returns a Vector2 where x holds the iteration count (for debugging) 
    /// and y is the computed distance.
    /// </summary>
    Vector2 SdFractal(Vector3 p)
    {
        // Scale the input position
        Vector3 point = p / fractalScale;
        // Swap coordinates (using xzy order) to match the shader’s reordering
        point = new Vector3(point.x, point.z, point.y);

        float scale = 1.1f;
        int iteration = 0;
        // Loop similar to shader’s fixed 8 iterations (or as set in fractalIterations)
        for (int i = 0; i < fractalIterations; i++)
        {
            iteration = i;
            // Clamp each component between -clampSize and clampSize
            point = 2.0f * new Vector3(
                Mathf.Clamp(point.x, -clampSize, clampSize),
                Mathf.Clamp(point.y, -clampSize, clampSize),
                Mathf.Clamp(point.z, -clampSize, clampSize)
            ) - point;

            // Compute r2 using a sine modification on p.z
            Vector3 pointWithSin = point + new Vector3(Mathf.Sin(point.z * 0.3f), Mathf.Sin(point.z * 0.3f), Mathf.Sin(point.z * 0.3f));
            float r2 = Vector3.Dot(point, pointWithSin);
            float k = Mathf.Max(2.0f / r2, 0.5f);
            point *= k;
            scale *= k;
        }

        // Compute distance from the fractal surface
        float l = new Vector2(point.x, point.y).magnitude;
        float rxy = l - 1.0f;
        float n = l * point.z;
        rxy = Mathf.Max(rxy, n / 8.0f);
        float dst = (rxy) / Mathf.Abs(scale) * fractalScale;
        return new Vector2(iteration, dst);
    }

    /// <summary>
    /// Numerically approximates the normal of the fractal surface at a given position.
    /// Uses a finite difference method.
    /// </summary>
    Vector3 CalculateNormal(Vector3 pos)
    {
        float eps = 0.001f;
        float dx = SdFractal(pos + new Vector3(eps, 0, 0)).y - SdFractal(pos - new Vector3(eps, 0, 0)).y;
        float dy = SdFractal(pos + new Vector3(0, eps, 0)).y - SdFractal(pos - new Vector3(0, eps, 0)).y;
        float dz = SdFractal(pos + new Vector3(0, 0, eps)).y - SdFractal(pos - new Vector3(0, 0, eps)).y;
        return new Vector3(dx, dy, dz).normalized;
    }

    void Update()
    {
        Vector3 currentPos = transform.position;
        float distance = SdFractal(currentPos).y;
        Debug.Log("Distance: " + distance);

        // If the GameObject is too close to the fractal surface, push it outward
        if (distance < safeDistance)
        {
            Vector3 normal = CalculateNormal(currentPos);
            // Determine how far to push the object so that it reaches the safe distance
            float pushDistance = safeDistance - distance;
            transform.position += normal * pushDistance * pushStrength;
        }
    }
}
