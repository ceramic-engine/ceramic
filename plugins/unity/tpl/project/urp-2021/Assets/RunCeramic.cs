
using UnityEngine;

public class RunCeramicBehaviour : MonoBehaviour
{
	// Use this for initialization
	void Start()
	{
		haxe.root.Main.sync(this);
	}

	// Update is called once per frame
	void Update()
	{
		haxe.root.Main.sync(this);
		haxe.root.Main.regularUpdate();
	}
}
