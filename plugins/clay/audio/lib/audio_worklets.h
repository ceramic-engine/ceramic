#ifndef AUDIO_WORKLETS_H
#define AUDIO_WORKLETS_H

/*
 * audio_worklets — standalone audio worklet processing library.
 *
 * Pure C ABI over the audio worklet code transpiled from haxe by
 * reflaxe.CPP. This library is self-contained plain C++ (no hxcpp, no
 * haxe runtime, no GC): it can be embedded in any host — a hxcpp app
 * (through the linc_audio_worklets bindings), a Unity native plugin, or
 * any other C/C++ project.
 *
 * Threading contract (mirrors the ceramic audio filter host):
 * - audio_worklets_init() must be called once, before anything else.
 * - audio_worklets_add_bus_filter / _destroy_bus_filter / _set_params /
 *   _filter_ready are called from the game/main thread.
 * - audio_worklets_process_bus() is called from the audio thread; the
 *   library handles the synchronization between both sides internally,
 *   with the same granularity as the ceramic hxcpp host: atomic spin
 *   locks scoped per bus for the params, a control spin lock for the
 *   worklet lists, and a lock-free fast path so the audio thread takes
 *   no lock at all for worklet synchronization when nothing changed.
 *
 * Bus indices must be in the [0, 31] range.
 */

#ifdef __cplusplus
extern "C" {
#endif

/* Initializes the library and registers the generated worklet factory.
 * Call once before any other function. */
void audio_worklets_init(void);

/* Creates a worklet of the given class (fully qualified haxe class name,
 * e.g. "ceramic.LowPassFilterWorklet") and queues it for processing on
 * the given bus. Returns 1 on success, 0 if the class name is unknown. */
int audio_worklets_add_bus_filter(int bus, int filterId, const char* workletClass);

/* Queues the removal of the worklet associated with the given filter. */
void audio_worklets_destroy_bus_filter(int bus, int filterId);

/* Updates the worklet parameter values of the given filter (values are
 * copied; safe with regard to the audio thread). */
void audio_worklets_set_params(int bus, int filterId, const float* values, int count);

/* Returns 1 once the worklet of the given filter has been synchronized
 * into the active processing list (i.e. it is effectively processing
 * audio), 0 otherwise. */
int audio_worklets_filter_ready(int bus, int filterId);

/* Processes one audio chunk through all the worklets of the given bus.
 * `buffer` contains planar float32 samples (one full channel block after
 * another, NOT interleaved), modified in place.
 * Call from the audio thread. */
void audio_worklets_process_bus(int bus, float* buffer, unsigned int samples,
                                unsigned int channels, float sampleRate, double time);

/* --- Host integration helpers (optional) ---------------------------------
 * Ready-tracking + callbacks matching the soloud bus filter contract used
 * by the clay host: these can be handed directly to the audio engine so
 * that the audio thread never runs anything but this library. */

/* Called by the audio engine when a bus filter instance is (de)activated. */
void audio_worklets_clay_create(int busIndex, int instanceId);
void audio_worklets_clay_destroy(int busIndex, int instanceId);

/* Audio-thread processing callback (planar float32 buffer). */
void audio_worklets_clay_process(int busIndex, int instanceId, float* aBuffer,
                                 unsigned int aSamples, unsigned int aChannels,
                                 float aSamplerate, double time);

/* Returns 1 once the audio engine activated a filter instance on the bus. */
int audio_worklets_clay_bus_ready(int busIndex);

#ifdef __cplusplus
}
#endif

#endif /* AUDIO_WORKLETS_H */
