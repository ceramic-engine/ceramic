
using UnityEngine;

public class BootCeramic : MonoBehaviour {

	// Use this for initialization
	void Start () {

		QualitySettings.antiAliasing = 4;

		haxe.root.Main.setUnityObject(this);
		haxe.root.EntryPoint__Main.Main();
	
	}
	
	// Update is called once per frame
	void Update () {
		
		haxe.root.Main.update();

	}
}
