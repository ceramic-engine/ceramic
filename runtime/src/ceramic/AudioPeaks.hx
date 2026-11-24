package ceramic;

/**
 * Utility to reduce audio samples to peaks, the data needed to draw a waveform.
 *
 * Samples are split in a number of slices of equal duration, and each slice is
 * reduced to the lowest and the highest value it contains, every channel mixed.
 * Drawing one vertical bar per slice, from its lowest to its highest value,
 * gives the waveform of the sound at the width of that many bars.
 *
 * It works on the buffers provided by `Sound.requestSamples()`:
 * 32 bit float planar samples (one channel after another, not interleaved).
 *
 * ```haxe
 * sound.requestSamples((buffer, samples, channels, sampleRate) -> {
 *     if (buffer == null) return;
 *     var peaks = AudioPeaks.compute(buffer, samples, channels, 200);
 *     for (i in 0...200) {
 *         var low = AudioPeaks.min(peaks, i);
 *         var high = AudioPeaks.max(peaks, i);
 *         // Draw a bar from `low` to `high`, both in the -1 to 1 range
 *     }
 * });
 * ```
 *
 * @see Sound
 */
class AudioPeaks {

    /**
     * Compute the peaks of the given samples.
     *
     * @param buffer Planar 32 bit float samples: `samples` values for each channel, one channel after another
     * @param samples Number of samples of one channel
     * @param channels Number of channels
     * @param count Number of slices to reduce the samples to
     * @param start (optional) Index of the first sample to read (default: 0)
     * @param end (optional) Index after the last sample to read (default: `samples`)
     * @return An array of `count * 2` values: for each slice, its lowest value then its highest one.
     *         Read it with `AudioPeaks.min()` and `AudioPeaks.max()`. A slice without any sample is `0, 0`.
     */
    public static function compute(buffer:Float32Array, samples:Int, channels:Int, count:Int, start:Int = 0, end:Int = -1):Float32Array {

        if (count < 0) count = 0;
        var result = new Float32Array(count * 2);

        if (buffer == null || samples <= 0 || channels <= 0 || count == 0)
            return result;

        if (end < 0 || end > samples) end = samples;
        if (start < 0) start = 0;
        var range = end - start;
        if (range <= 0)
            return result;

        for (i in 0...count) {

            // Slices cover the range without gap nor overlap
            var from = start + Math.floor(i * (range / count));
            var to = start + Math.floor((i + 1) * (range / count));
            if (i == count - 1) to = end;

            // With more slices than samples, a slice shows the sample it falls on
            if (to <= from) to = from + 1;
            if (to > end) to = end;
            if (from >= to) from = to - 1;

            var low:Float = 0;
            var high:Float = 0;
            var first = true;

            for (channel in 0...channels) {
                var offset = channel * samples;
                for (n in from...to) {
                    var value:Float = buffer[offset + n];
                    if (first) {
                        low = value;
                        high = value;
                        first = false;
                    }
                    else if (value < low) {
                        low = value;
                    }
                    else if (value > high) {
                        high = value;
                    }
                }
            }

            result[i * 2] = low;
            result[i * 2 + 1] = high;

        }

        return result;

    }

    /**
     * The lowest value of a slice of peaks computed with `AudioPeaks.compute()`.
     */
    inline public static function min(peaks:Float32Array, index:Int):Float {

        return peaks[index * 2];

    }

    /**
     * The highest value of a slice of peaks computed with `AudioPeaks.compute()`.
     */
    inline public static function max(peaks:Float32Array, index:Int):Float {

        return peaks[index * 2 + 1];

    }

}
