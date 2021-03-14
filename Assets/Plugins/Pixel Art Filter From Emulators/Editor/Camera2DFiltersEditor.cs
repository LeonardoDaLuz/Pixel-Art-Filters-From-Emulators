using UnityEditor;
using UnityEngine;

[CustomEditor(typeof(Camera2DFilters))]
public class Camera2DFiltersEditor : Editor
{
    const string resourceFilename = "custom-editor-uie";
    public override void OnInspectorGUI()
    {
        if (Application.isPlaying)
            return;

        Camera2DFilters _target = (Camera2DFilters)target;

        if (_target.cam == null)
            _target.cam = _target.GetComponent<Camera>();

        _target.AutoConfigureCamera();


        DrawDefaultInspector();


    }
}