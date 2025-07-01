
using UnityEngine;
using UnityEngine.Audio;

public class RunCeramic : MonoBehaviour
{
	public AudioMixer audioMixer;

	void Awake()
	{
#if UNITY_EDITOR
        // Set DSP buffer size to 1024 (Best Performance) only in editor
		// (because it's using Mono. On IL2CPP targets, we'd favor lower latency)
        AudioConfiguration config = AudioSettings.GetConfiguration();
		if (config.dspBufferSize != 1024) {
			config.dspBufferSize = 1024;
			AudioSettings.Reset(config);
		}
#endif
	}

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
