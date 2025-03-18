using UnityEngine;

public class CameraFollow : MonoBehaviour
{
    [Header("Follow Settings")]
    public Transform target;
    [Tooltip("Damping time for smooth movement.")]
    public float smoothTime = 0.3f;
    private Vector3 velocity = Vector3.zero;

    [Header("Fractal Settings")]
    public float fractalScale = 1.0f;
    public float clampSize = 1.0f;
    public int fractalIterations = 8;

    [Header("Collision Settings")]
    public float safeDistance = 0.5f;
    public float pushStrength = 1.0f;
    public float collisionThreshold = 0.05f; // Only apply if the penetration exceeds this threshold

    Vector2 SdFractal(Vector3 p)
    {
        Vector3 point = p / fractalScale;
        point = new Vector3(point.x, point.z, point.y);

        float scale = 1.1f;
        int iteration = 0;
        for (int i = 0; i < fractalIterations; i++)
        {
            iteration = i;
            point = 2.0f * new Vector3(
                Mathf.Clamp(point.x, -clampSize, clampSize),
                Mathf.Clamp(point.y, -clampSize, clampSize),
                Mathf.Clamp(point.z, -clampSize, clampSize)
            ) - point;

            Vector3 pointWithSin = point + new Vector3(Mathf.Sin(point.z * 0.3f), Mathf.Sin(point.z * 0.3f), Mathf.Sin(point.z * 0.3f));
            float r2 = Vector3.Dot(point, pointWithSin);
            float k = Mathf.Max(2.0f / r2, 0.5f);
            point *= k;
            scale *= k;
        }

        float l = new Vector2(point.x, point.y).magnitude;
        float rxy = l - 1.0f;
        float n = l * point.z;
        rxy = Mathf.Max(rxy, n / 8.0f);
        float dst = (rxy) / Mathf.Abs(scale) * fractalScale;
        return new Vector2(iteration, dst);
    }

    Vector3 CalculateNormal(Vector3 pos)
    {
        float eps = 0.001f;
        float dx = SdFractal(pos + new Vector3(eps, 0, 0)).y - SdFractal(pos - new Vector3(eps, 0, 0)).y;
        float dy = SdFractal(pos + new Vector3(0, eps, 0)).y - SdFractal(pos - new Vector3(0, eps, 0)).y;
        float dz = SdFractal(pos + new Vector3(0, 0, eps)).y - SdFractal(pos - new Vector3(0, 0, eps)).y;
        return new Vector3(dx, dy, dz).normalized;
    }

    void LateUpdate()
    {
        if (target == null) return;

        // Smoothly move the camera to the target's position.
        Vector3 desiredPosition = Vector3.SmoothDamp(transform.position, target.position, ref velocity, smoothTime);

        // Check fractal collision
        float distance = SdFractal(desiredPosition).y;
        float penetration = safeDistance - distance;
        if (penetration > collisionThreshold)
        {
            Vector3 normal = CalculateNormal(desiredPosition);
            // Apply a proportional correction based on penetration
            desiredPosition += normal * penetration * pushStrength;
        }

        // Directly assign the new position.
        transform.position = desiredPosition;

        // Smoothly rotate the camera to match the target.
        transform.rotation = Quaternion.Slerp(transform.rotation, target.rotation, Time.deltaTime / smoothTime);
    }
}
