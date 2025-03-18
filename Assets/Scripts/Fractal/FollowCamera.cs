using UnityEngine;

public class FollowCamera : MonoBehaviour
{
    [Header("Follow Settings")]
    public Transform target;
    [Tooltip("Damping time for smooth movement.")]
    public float smoothTime = 0.3f;
    private Vector3 velocity = Vector3.zero;

    void LateUpdate()
    {
        if (target == null) return;

        // Smoothly move the camera to the target's position.
        Vector3 desiredPosition = Vector3.SmoothDamp(transform.position, target.position, ref velocity, smoothTime);

        // Directly assign the new position.
        transform.position = desiredPosition;

        // Smoothly rotate the camera to match the target.
        transform.rotation = Quaternion.Slerp(transform.rotation, target.rotation, Time.deltaTime / smoothTime);
    }
}
