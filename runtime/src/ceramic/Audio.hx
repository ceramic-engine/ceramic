package ceramic;

import ceramic.Shortcuts.*;

#if sys
import sys.thread.Mutex;
#end

class Audio extends Entity {

    @:allow(ceramic.Sound)
    var mixers:IntMap<AudioMixer>;

    /**
     * Filters attached to each bus
     */
    var busFilters:Array<Array<AudioFilter>> = [];

    #if sys
    var busFiltersLock = new ceramic.SpinLock();
    #end

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

    public function mixer(index:Int):AudioMixer {

        initMixerIfNeeded(index);
        return mixers.getInline(index);

    }

    /**
     * Add a filter to a specific bus
     * @param filter The filter to add
     * @param bus The bus to add the filter to (0-based)
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
     * Remove a filter from a specific bus
     * @param filter The filter to remove
     * @param bus The bus to remove the filter from
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
     * Get all filters for a specific bus
     * @param bus The bus to get filters for
     * @return Array of filters
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
     * Remove all filters from a specific bus
     * @param bus The bus to clear
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
