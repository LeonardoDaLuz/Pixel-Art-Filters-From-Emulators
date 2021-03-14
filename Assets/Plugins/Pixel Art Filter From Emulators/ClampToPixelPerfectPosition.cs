using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ClampToPixelPerfectPosition : MonoBehaviour {
    public float PixelsPerUnit=16;
    private float densityUnit;
    private Rigidbody2D rb;
    private bool OrderOfScriptChanged;

    // Use this for initialization
    void Start () {
        rb = GetComponent<Rigidbody2D>();
    }

    private void OnDrawGizmosSelected()
    {
        ClampCameraToPixelPosition();
        densityUnit = 1f / PixelsPerUnit;

#if UNITY_EDITOR
        if (!OrderOfScriptChanged)
        {
            // Get the name of the script we want to change it's execution order
            string scriptName = typeof(Camera2DFilters).Name;

            // Iterate through all scripts (Might be a better way to do this?)
            foreach (UnityEditor.MonoScript monoScript in UnityEditor.MonoImporter.GetAllRuntimeMonoScripts())
            {
                // If found our script
                if (monoScript.name == scriptName && UnityEditor.MonoImporter.GetExecutionOrder(monoScript) != +4000)
                {
                    UnityEditor.MonoImporter.SetExecutionOrder(monoScript, +4000);
                }
            }
            OrderOfScriptChanged = true;
        }
#endif
    }
    // Update is called once per frame
    void LateUpdate () {
        ClampCameraToPixelPosition();
    }

    void ClampCameraToPixelPosition()
    {
        #region Rigidbody backup
        //It is to preventing the rigidbody clean up.
        Vector2 velBk = Vector2.zero;
        float angularVelBk = 0f;

        if (rb != null)
        {
            velBk = rb.velocity;
            angularVelBk = rb.angularVelocity;
        }
        #endregion

        #region Clamping
        var x = transform.position.x;
        x = x / densityUnit;
        x = Mathf.Round(x);
        x = x * densityUnit;

        var y = transform.position.y;
        y = y / densityUnit;
        y = Mathf.Round(y);
        y = y * densityUnit;

        if (float.IsNaN(x) || float.IsNaN(y))
            return;

        transform.position = new Vector3(x, y, transform.position.z);

        #endregion

        #region Restore Rigidbody
        if (rb != null) //Rigidbody needs be restored because the transform.position changes clean-up velocities. But if you don't use rigidbody on camera, this is useless
        {
            rb.velocity = velBk;
            rb.angularVelocity = angularVelBk;
        }
        #endregion
    }
}

