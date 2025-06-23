
using UnityEngine;
using UnityEngine.Audio;

public class RunCeramic : MonoBehaviour
{
	public AudioMixer audioMixer;

	// Use this for initialization
	void Start()
	{
		haxe.root.Main.sync(this, audioMixer);
	}

	// Update is called once per frame
	void Update()
	{
		haxe.root.Main.sync(this, audioMixer);
		haxe.root.Main.regularUpdate();
	}
}
