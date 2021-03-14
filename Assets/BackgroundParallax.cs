using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class BackgroundParallax : MonoBehaviour {
    public Transform _Camera;
    public float Factor=0.5f;
    public Vector3 BgInitialPosition;
    public Vector3 CameraInitialPosition;
    // Use this for initialization
    void Start () {

        if (_Camera == null)
            _Camera = Camera.main.transform;

        CameraInitialPosition = _Camera.transform.position;
        BgInitialPosition = transform.position;
        var sprites = GetComponentsInChildren<SpriteRenderer>();
        System.Array.ForEach(sprites, n => n.enabled = true);

    }
	
	// Update is called once per frame
	void LateUpdate () {
        Vector3 displacement = _Camera.position - CameraInitialPosition;
        displacement.z = 0f;

        transform.position = (displacement * Factor) + BgInitialPosition;
	}
}
