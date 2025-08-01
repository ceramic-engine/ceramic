package ceramic;

import ceramic.Shortcuts.*;

#if sys
import sys.thread.Mutex;
#end

/**
 * Main audio system manager for Ceramic.
 * 
 * This class manages the audio system, including:
 * - Audio mixers for different buses (channels)
 * - Audio filters and effects
 * - Global audio processing
 * 
 * The audio system uses a bus-based architecture where sounds can be
 * routed through different buses (0, 1, 2, etc.) for separate processing.
 * Bus 0 is the default/master bus.
 * 
 * Features:
 * - Multiple audio buses for organizing sounds
 * - Real-time audio filters (low-pass, high-pass, etc.)
 * - Thread-safe filter management on native platforms
 * - Per-bus volume and effect control via mixers
 * 
 * This class is automatically instantiated by the App and should be
 * accessed via `app.audio`.
 * 
 * @example
 * ```haxe
 * // Get the master mixer
 * var masterMixer = app.audio.mixer(0);
 * masterMixer.volume = 0.8;
 * 
 * // Add a low-pass filter to bus 1
 * var filter = new LowPassFilter();
 * filter.frequency = 1000;
 * app.audio.addFilter(filter, 1);
 * 
 * // Play a sound on bus 1
 * var sound = assets.sound('music');
 * sound.mixer = 1;
 * sound.play();
 * ```
 * 
 * @see AudioMixer
 * @see AudioFilter
 * @see Sound
 */
class Audio extends Entity {

    /**
     * Map of audio mixers indexed by bus number.
     * Created lazily as buses are accessed.
     */
    @:allow(ceramic.Sound)
    var mixers:IntMap<AudioMixer>;

    /**
     * Filters attached to each bus.
     * First dimension is bus index, second is list of filters for that bus.
     */
    var busFilters:Array<Array<AudioFilter>> = [];

    #if sys
    var busFiltersLock = new ceramic.SpinLock();
    #end

    /**
     * Private constructor - Audio is created internally by App.
     * Access via `app.audio`.
     */
    @:allow(ceramic.App)
    private function new() {

        super();

        mixers = new IntMap();
        initMixerIfNeeded(0);

    }

    @:allow(ceramic.Sound)
    inline function initMixerIfNeeded(index:Int):Void {

        if (!mixers.exists(index)) {
            mixers.set(index, new AudioMixer(index));
        }

    }

    /**
     * Get or create an audio mixer for the specified bus.
     * Mixers are created lazily on first access.
     * @param index The bus index (0 for master, 1+ for additional buses)
     * @return The audio mixer for the specified bus
     */
    public function mixer(index:Int):AudioMixer {

        initMixerIfNeeded(index);
        return mixers.getInline(index);

    }

    /**
     * Add an audio filter to a specific bus.
     * Filters are processed in the order they are added.
     * If the filter is already attached to another bus, it will be moved.
     * @param filter The filter to add
     * @param bus The bus to add the filter to (0 = master, default)
     * @throws String if bus index is negative
     */
    public function addFilter(filter:AudioFilter, bus:Int = 0):Void {

        if (bus < 0) {
            throw 'Invalid bus $bus, must be 0 or higher';
        }

        #if sys
        busFiltersLock.acquire();
        #end

        if (filter.bus != -1) {
            _removeFilter(filter, filter.bus);
        }

        while (busFilters.length <= bus) {
            busFilters.push([]);
        }

        busFilters[bus].push(filter);
        filter.attach(bus);

        // Notify backend
        app.backend.audio.addFilter(bus, filter, @:privateAccess filter.emitReady);

        // Invalidate params because filters layout has changed
        for (i in 0...busFilters[bus].length) {
            app.backend.audio.filterParamsChanged(bus, busFilters[bus][i].filterId);
        }

        #if sys
        busFiltersLock.release();
        #end

    }

    /**
     * Remove an audio filter from a specific bus.
     * @param filter The filter to remove
     * @param bus The bus to remove from (if null, uses filter's current bus)
     */
    public function removeFilter(filter:AudioFilter, ?bus:Int):Void {
        #if sys
        busFiltersLock.acquire();
        #end
        _removeFilter(filter, bus);
        #if sys
        busFiltersLock.release();
        #end
    }

    function _removeFilter(filter:AudioFilter, ?bus:Int):Void {
        if (bus == null) bus = filter.bus;
        if (bus < 0 || bus >= busFilters.length) return;

        final filterIndex = busFilters[bus].indexOf(filter);
        if (filterIndex != -1) {
            filter.detach(bus);
            busFilters[bus].splice(filterIndex, 1);

            // Notify backend
            app.backend.audio.removeFilter(bus, filter.filterId);

            // Invalidate params because filters layout has changed
            for (i in 0...busFilters[bus].length) {
                app.backend.audio.filterParamsChanged(bus, busFilters[bus][i].filterId);
            }
        }
    }

    /**
     * Get all filters attached to a specific bus.
     * Returns a copy of the filter array to prevent external modification.
     * @param bus The bus to get filters for
     * @return Read-only array of filters (empty if bus has no filters)
     */
    public function filters(bus:Int):ReadOnlyArray<AudioFilter> {
        #if sys
        busFiltersLock.acquire();
        #end
        var result = busFilters[bus];
        if (result != null) {
            result = [].concat(result);
        }
        else {
            result = [];
        }
        #if sys
        busFiltersLock.release();
        #end
        return result;
    }

    /**
     * Remove all filters from a specific bus.
     * @param bus The bus to clear of all filters
     */
    public function clearFilters(bus:Int):Void {
        #if sys
        busFiltersLock.acquire();
        #end
        if (bus < busFilters.length) {
            final filters = busFilters[bus];
            while (filters.length > 0) {
                _removeFilter(filters[filters.length - 1], bus);
            }
        }
        #if sys
        busFiltersLock.release();
        #end
    }

}
