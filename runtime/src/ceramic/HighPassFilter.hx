package ceramic;

import ceramic.AudioFilter;
import ceramic.AudioFilterBuffer;
import ceramic.AudioFilterWorklet;

/**
 * A high-pass audio filter that attenuates frequencies below a cutoff point.
 * 
 * High-pass filters allow high frequencies to pass through while reducing
 * or eliminating low frequencies. Common uses include:
 * - Removing rumble or low-frequency noise
 * - Creating "tinny" or "telephone" effects
 * - Frequency band isolation for audio analysis
 * - Cleaning up muddy audio mixes
 * 
 * The filter uses a biquad implementation for stable, efficient processing
 * with adjustable resonance (Q factor) for frequency emphasis at the cutoff.
 * 
 * @example
 * ```haxe
 * // Remove low frequencies below 200Hz
 * var highPass = new HighPassFilter();
 * highPass.cutoffFrequency = 200;
 * highPass.gain = 1.0;
 * 
 * // Create a resonant high-pass effect
 * var resonantHP = new HighPassFilter();
 * resonantHP.cutoffFrequency = 1000;
 * resonantHP.resonance = 5.0;  // Emphasize the cutoff frequency
 * 
 * // Apply to an audio mixer
 * audioMixer.addFilter(highPass);
 * ```
 * 
 * @see LowPassFilter
 * @see AudioFilter
 * @see AudioMixer
 */
class HighPassFilter extends AudioFilter {

    public function workletClass() return HighPassFilterWorklet;

}

/**
 * The audio processing worklet for the high-pass filter.
 * Implements a second-order biquad high-pass filter with per-channel processing.
 */
class HighPassFilterWorklet extends AudioFilterWorklet {

    /**
     * Cutoff frequency in Hz.
     * Frequencies below this value will be attenuated.
     * Range: 1 Hz to half the sample rate (Nyquist frequency).
     * Default: 1000 Hz
     */
    @param var cutoffFrequency:Float = 1000.0;

    /**
     * Filter gain/amplitude multiplier.
     * Adjusts the overall output level after filtering.
     * Range: 0.0 to any positive value (1.0 = unity gain).
     * Default: 1.0
     */
    @param var gain:Float = 1.0;

    /**
     * Filter resonance/Q factor.
     * Controls the sharpness of the filter and frequency emphasis at the cutoff.
     * - 0.707: No resonance (Butterworth response)
     * - < 0.707: Gentler rolloff
     * - > 0.707: Sharper rolloff with peak at cutoff
     * Range: 0.1 to 30.0 (higher values = more resonance)
     * Default: 0.707
     */
    @param var resonance:Float = 0.707;

    // Biquad filter state for each channel
    var x1:Array<Float> = []; // input history 1
    var x2:Array<Float> = []; // input history 2
    var y1:Array<Float> = []; // output history 1
    var y2:Array<Float> = []; // output history 2

    // Cached filter coefficients
    var a0:Float = 1.0;
    var a1:Float = 0.0;
    var a2:Float = 0.0;
    var b1:Float = 0.0;
    var b2:Float = 0.0;

    var lastCutoff:Float = -1.0;
    var lastQ:Float = -1.0;
    var lastSampleRate:Float = -1.0;

    /**
     * Process audio buffer in place. Override this method to implement custom filtering.
     * CAUTION: this may be called from a background thread
     * @param buffer The audio buffer to process (modify in place, planar layout: one channel after another, not interleaved)
     * @param samples Number of samples per channel
     * @param channels Number of audio channels (1 = mono, 2 = stereo)
     * @param sampleRate Sample rate in Hz
     * @param time Current playback time in seconds
     */
    public function process(buffer:AudioFilterBuffer, samples:Int, channels:Int, sampleRate:Float, time:Float) {

        // Clamp parameters to safe ranges
        var clampedCutoff = Math.max(1.0, Math.min(cutoffFrequency, sampleRate * 0.49));
        var clampedQ = Math.max(0.1, Math.min(resonance, 30.0));

        // Recalculate coefficients if parameters changed
        if (clampedCutoff != lastCutoff || clampedQ != lastQ || sampleRate != lastSampleRate) {
            calculateCoefficients(clampedCutoff, clampedQ, sampleRate);
            lastCutoff = clampedCutoff;
            lastQ = clampedQ;
            lastSampleRate = sampleRate;
        }

        // Ensure we have filter state for each channel
        while (x1.length < channels) {
            x1.push(0.0);
            x2.push(0.0);
            y1.push(0.0);
            y2.push(0.0);
        }

        // Process each channel (PLANAR format: channel blocks are sequential)
        for (channel in 0...channels) {
            var channelOffset = channel * samples;  // PLANAR: each channel is a separate block

            var _x1 = x1[channel];
            var _x2 = x2[channel];
            var _y1 = y1[channel];
            var _y2 = y2[channel];

            // Process each sample in this channel
            for (sample in 0...samples) {
                var index:Int = channelOffset + sample;  // PLANAR indexing!
                var input:Float = buffer[index];

                // Biquad filter equation:
                // y[n] = (a0*x[n] + a1*x[n-1] + a2*x[n-2] - b1*y[n-1] - b2*y[n-2])
                var output:Float = a0 * input + a1 * _x1 + a2 * _x2 - b1 * _y1 - b2 * _y2;

                // Shift delay line
                _x2 = _x1;
                _x1 = input;
                _y2 = _y1;
                _y1 = output;

                // Apply gain and store result
                buffer[index] = output * gain;
            }

            // Store filter state for this channel
            x1[channel] = _x1;
            x2[channel] = _x2;
            y1[channel] = _y1;
            y2[channel] = _y2;
        }
    }

    /**
     * Calculates biquad filter coefficients for the high-pass response.
     * Uses the standard audio EQ cookbook formulas for a second-order high-pass filter.
     * 
     * @param cutoff Cutoff frequency in Hz
     * @param q Quality factor (resonance)
     * @param sampleRate Sample rate in Hz
     */
    function calculateCoefficients(cutoff:Float, q:Float, sampleRate:Float) {
        // Calculate biquad coefficients for high-pass filter
        var omega = 2.0 * Math.PI * cutoff / sampleRate;
        var sin = Math.sin(omega);
        var cos = Math.cos(omega);
        var alpha = sin / (2.0 * q);

        var b0 = 1.0 + alpha;
        var b1_coeff = -2.0 * cos;
        var b2_coeff = 1.0 - alpha;

        var a0_coeff = (1.0 + cos) / 2.0;    // High-pass: (1 + cos) instead of (1 - cos)
        var a1_coeff = -(1.0 + cos);         // High-pass: negative (1 + cos)
        var a2_coeff = (1.0 + cos) / 2.0;    // High-pass: (1 + cos) instead of (1 - cos)

        // Normalize coefficients
        a0 = a0_coeff / b0;
        a1 = a1_coeff / b0;
        a2 = a2_coeff / b0;
        b1 = b1_coeff / b0;
        b2 = b2_coeff / b0;
    }
}