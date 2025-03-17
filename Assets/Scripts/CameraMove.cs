using UnityEngine;
using UnityEngine.InputSystem;

public class FreeCamera : MonoBehaviour
{
    [SerializeField] private float moveSpeed = 5f;
    [SerializeField] private float lookSensitivity = 2f;

    private float pitch = 0f;
    private float yaw = 0f;
    private bool cursorLocked = true;

    void Start()
    {
        // Initialize rotation based on the current transform rotation.
        Vector3 angles = transform.eulerAngles;
        yaw = angles.y;
        pitch = angles.x;
        LockCursor();
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
        if (Keyboard.current.dKey.isPressed) moveDir += transform.right;
        if (Keyboard.current.aKey.isPressed) moveDir -= transform.right;
        transform.position += moveDir.normalized * moveSpeed * Time.deltaTime;
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
