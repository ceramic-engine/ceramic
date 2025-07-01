using UnityEngine;
using UnityEngine.Audio;
using MiniLoud;
using System.Threading;

public class MiniLoudUnity : MonoBehaviour
{
    /// <summary>
    /// Delegate for audio processing hook
    /// </summary>
    /// <param name="planarBuffer">Audio buffer in planar format [L0,L1,L2,...,R0,R1,R2,...]</param>
    /// <param name="samplesPerChannel">Number of samples per channel</param>
    /// <param name="channels">Number of channels</param>
    /// <param name="sampleRate">Sample rate in Hz</param>
    /// <param name="currentTime">Current DSP time in seconds</param>
    public delegate void AudioProcessingHook(float[] planarBuffer, int samplesPerChannel, int channels, int sampleRate, double currentTime);

    // Thread-safe delegate field using volatile
    private volatile AudioProcessingHook audioProcessingHook;

    /// <summary>
    /// Thread-safe audio processing hook property
    /// </summary>
    public event AudioProcessingHook OnAudioProcess
    {
        add
        {
            // Thread-safe delegate combination
            AudioProcessingHook existingHook;
            AudioProcessingHook newHook;
            do
            {
                existingHook = audioProcessingHook;
                newHook = existingHook + value;
            } while (Interlocked.CompareExchange(ref audioProcessingHook, newHook, existingHook) != existingHook);
        }
        remove
        {
            // Thread-safe delegate removal
            AudioProcessingHook existingHook;
            AudioProcessingHook newHook;
            do
            {
                existingHook = audioProcessingHook;
                newHook = existingHook - value;
            } while (Interlocked.CompareExchange(ref audioProcessingHook, newHook, existingHook) != existingHook);
        }
    }

    public MiniLoudAudio miniLoudAudio;
    public AudioSource audioSource;
    public int channels;
    public int sampleRate;

    // Buffers for planar conversion to avoid allocations
    private float[] planarBuffer;
    private float[] interleavedBuffer;

    // For tracking time
    private double lastDspTime;
    private double currentDspTime;

    void Awake()
    {
        // Create a short silent clip (0.1 seconds is plenty)
        float duration = 0.1f;

        sampleRate = AudioSettings.outputSampleRate;
        channels = AudioSettings.speakerMode == AudioSpeakerMode.Mono ? 1 : 2;

        // lengthSamples is per channel, don't multiply by channels here
        int lengthSamples = Mathf.RoundToInt(duration * sampleRate);

        AudioClip silentClip = AudioClip.Create("SilentLoop", lengthSamples, channels, sampleRate, false);

        // silentData needs total samples (lengthSamples * channels)
        float[] silentData = new float[lengthSamples * channels];
        for (int i = 0; i < silentData.Length; i++)
        {
            silentData[i] = 0;
        }
        silentClip.SetData(silentData, 0);

        // Setup AudioSource
        audioSource = gameObject.GetComponent<AudioSource>();
        if (audioSource == null)
        {
            audioSource = gameObject.AddComponent<AudioSource>();
        }
        audioSource.clip = silentClip;
        audioSource.loop = true;
        audioSource.volume = 0f; // Mute the output since you only want processing

        // Initialize with Unity's audio settings
        miniLoudAudio = new MiniLoudAudio(sampleRate, channels);

        // Initialize DSP time
        lastDspTime = AudioSettings.dspTime;
        currentDspTime = lastDspTime;
    }

    void Start()
    {
        if (!audioSource.isPlaying)
        {
            audioSource.Play();
        }
    }

    void OnAudioFilterRead(float[] data, int channels)
    {
        if (miniLoudAudio != null && data.Length > 0)
        {
            // Update DSP time
            currentDspTime = AudioSettings.dspTime;

            // Ensure buffers are sized correctly
            int totalSamples = data.Length;
            int samplesPerChannel = totalSamples / channels;

            if (planarBuffer == null || planarBuffer.Length != totalSamples)
            {
                planarBuffer = new float[totalSamples];
                interleavedBuffer = new float[totalSamples];
            }

            // Convert from interleaved to planar
            InterleavedToPlanar(data, planarBuffer, samplesPerChannel, channels);

            // Process with MiniLoud (modifies planarBuffer in place)
            miniLoudAudio.ProcessAudio(planarBuffer, channels);

            // Call the audio processing hook if set
            // Copy the delegate reference to ensure thread safety
            AudioProcessingHook hook = audioProcessingHook;
            hook?.Invoke(planarBuffer, samplesPerChannel, channels, sampleRate, currentDspTime);

            // Convert back from planar to interleaved
            PlanarToInterleaved(planarBuffer, data, samplesPerChannel, channels);

            lastDspTime = currentDspTime;
        }
    }

    /// <summary>
    /// Convert interleaved audio data to planar format
    /// </summary>
    /// <param name="interleaved">Input interleaved data [L0,R0,L1,R1,...]</param>
    /// <param name="planar">Output planar data [L0,L1,L2,...,R0,R1,R2,...]</param>
    /// <param name="samplesPerChannel">Number of samples per channel</param>
    /// <param name="channels">Number of channels</param>
    private static void InterleavedToPlanar(float[] interleaved, float[] planar, int samplesPerChannel, int channels)
    {
        for (int ch = 0; ch < channels; ch++)
        {
            int planarOffset = ch * samplesPerChannel;
            for (int i = 0; i < samplesPerChannel; i++)
            {
                planar[planarOffset + i] = interleaved[i * channels + ch];
            }
        }
    }

    /// <summary>
    /// Convert planar audio data to interleaved format
    /// </summary>
    /// <param name="planar">Input planar data [L0,L1,L2,...,R0,R1,R2,...]</param>
    /// <param name="interleaved">Output interleaved data [L0,R0,L1,R1,...]</param>
    /// <param name="samplesPerChannel">Number of samples per channel</param>
    /// <param name="channels">Number of channels</param>
    private static void PlanarToInterleaved(float[] planar, float[] interleaved, int samplesPerChannel, int channels)
    {
        for (int ch = 0; ch < channels; ch++)
        {
            int planarOffset = ch * samplesPerChannel;
            for (int i = 0; i < samplesPerChannel; i++)
            {
                interleaved[i * channels + ch] = planar[planarOffset + i];
            }
        }
    }

    /// <summary>
    /// Convert Unity AudioClip to AudioResource
    /// </summary>
    public static MiniLoud.AudioResource AudioResourceFromAudioClip(AudioClip clip)
    {
        float[] samples = new float[clip.samples * clip.channels];
        clip.GetData(samples, 0);

        // Keep the data in interleaved format - GetAudio expects it this way
        return MiniLoudAudio.CreateFromData(
            samples,  // Interleaved data
            clip.channels,
            clip.frequency
        );
    }

    void OnDestroy()
    {
        // Clear all hooks before destroying
        audioProcessingHook = null;

        if (audioSource != null && audioSource.isPlaying)
        {
            audioSource.Stop();
        }
    }
}