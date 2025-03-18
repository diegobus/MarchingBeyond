using UnityEngine;
using UnityEngine.InputSystem;

public class CameraMove : MonoBehaviour
{
    [SerializeField] private float moveSpeed = 5f;
    [SerializeField] private float lookSensitivity = 2f;
    [SerializeField] private GameObject spaceshipModel;
    [SerializeField] private float leanAngle = 15f;
    [SerializeField] private float leanSpeed = 5f;

    private float pitch = 0f;
    private float yaw = 0f;
    private bool cursorLocked = true;
    private float currentLean = 0f;
    private float targetLean = 0f;
    private Quaternion initialSpaceshipRotation;

    void Start()
    {
        // Initialize rotation based on the current transform rotation.
        Vector3 angles = transform.eulerAngles;
        yaw = angles.y;
        pitch = angles.x;
        LockCursor();

        // Store the initial rotation of the spaceship model
        if (spaceshipModel != null)
        {
            initialSpaceshipRotation = spaceshipModel.transform.localRotation;
        }
    }

    void Update()
    {
        // Toggle cursor lock on Escape
        if (Keyboard.current.escapeKey.wasPressedThisFrame)
        {
            cursorLocked = !cursorLocked;
            if (cursorLocked)
                LockCursor();
            else
                UnlockCursor();
        }

        // Look rotation when the cursor is locked
        if (cursorLocked)
        {
            Vector2 mouseDelta = Mouse.current.delta.ReadValue() * lookSensitivity;
            yaw += mouseDelta.x;
            pitch -= mouseDelta.y;
            pitch = Mathf.Clamp(pitch, -90f, 90f);
            transform.rotation = Quaternion.Euler(pitch, yaw, 0f);
        }

        // Movement (WASD)
        Vector3 moveDir = Vector3.zero;
        if (Keyboard.current.wKey.isPressed) moveDir += transform.forward;
        if (Keyboard.current.sKey.isPressed) moveDir -= transform.forward;

        // Handle horizontal movement and ship leaning
        bool movingRight = Keyboard.current.dKey.isPressed;
        bool movingLeft = Keyboard.current.aKey.isPressed;

        if (movingRight)
        {
            moveDir += transform.right;
            targetLean = -leanAngle; // Negative angle to lean right
        }
        else if (movingLeft)
        {
            moveDir -= transform.right;
            targetLean = leanAngle; // Positive angle to lean left
        }
        else
        {
            targetLean = 0f; // Return to center when not moving horizontally
        }

        transform.position += moveDir.normalized * moveSpeed * Time.deltaTime;

        // Apply smooth leaning to the spaceship model
        if (spaceshipModel != null)
        {
            // Smoothly interpolate current lean toward target lean
            currentLean = Mathf.Lerp(currentLean, targetLean, Time.deltaTime * leanSpeed);

            // Apply the rotation to the spaceship model while preserving initial rotation
            Quaternion leanRotation = Quaternion.Euler(currentLean, 0f, 0f);

            // Combine the initial rotation with the lean rotation
            spaceshipModel.transform.localRotation = initialSpaceshipRotation * leanRotation;
        }
    }

    private void LockCursor()
    {
        Cursor.lockState = CursorLockMode.Locked;
        Cursor.visible = false;
    }

    private void UnlockCursor()
    {
        Cursor.lockState = CursorLockMode.None;
        Cursor.visible = true;
    }
}
