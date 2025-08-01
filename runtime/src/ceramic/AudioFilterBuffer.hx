package ceramic;

/**
 * Platform-specific audio filter buffer for real-time audio processing.
 * 
 * AudioFilterBuffer represents a buffer of floating-point audio samples
 * that can be processed by audio filters. The actual implementation varies
 * by backend:
 * - Native platforms (C++): Uses cpp.Pointer<cpp.Float32> for direct memory access
 * - Other platforms: Uses Float32Array for managed array access
 * 
 * This type is used internally by the audio filter system to pass audio
 * data between filters efficiently. Each buffer contains a fixed number
 * of samples that represent a small chunk of audio data.
 * 
 * The buffer supports array-style access for reading and writing samples:
 * ```haxe
 * var sample = buffer[0];  // Read first sample
 * buffer[0] = 0.5;        // Write to first sample
 * ```
 * 
 * @see AudioFilter
 * @see AudioFilters
 * @see Float32Array
 */
typedef AudioFilterBuffer = backend.AudioFilterBuffer;
