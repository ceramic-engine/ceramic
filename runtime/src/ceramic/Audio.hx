package ceramic;

import ceramic.Shortcuts.*;

#if sys
import sys.thread.Mutex;
#end

class Audio extends Entity {

    @:allow(ceramic.Sound)
    var mixers:IntMap<AudioMixer>;

    /**
     * Filters attached to each channel
     */
    var channelFilters:Array<Array<AudioFilter>> = [];

    #if sys
    var channelFiltersLock = new ceramic.SpinLock();
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
     * Add a filter to a specific channel
     * @param filter The filter to add
     * @param channel The channel to add the filter to (0-based)
     */
    public function addFilter(filter:AudioFilter, channel:Int = 0):Void {

        if (channel < 0) {
            throw 'Invalid channel $channel, must be 0 or higher';
        }

        #if sys
        channelFiltersLock.acquire();
        #end

        if (filter.channel != -1) {
            _removeFilter(filter, filter.channel);
        }

        while (channelFilters.length <= channel) {
            channelFilters.push([]);
        }

        channelFilters[channel].push(filter);
        filter.attach(channel);

        // Notify backend
        app.backend.audio.addFilter(channel, filter);

        #if sys
        channelFiltersLock.release();
        #end

    }

    /**
     * Remove a filter from a specific channel
     * @param filter The filter to remove
     * @param channel The channel to remove the filter from
     */
    public function removeFilter(filter:AudioFilter, ?channel:Int):Void {
        #if sys
        channelFiltersLock.acquire();
        #end
        _removeFilter(filter, channel);
        #if sys
        channelFiltersLock.release();
        #end
    }

    function _removeFilter(filter:AudioFilter, ?channel:Int):Void {
        if (channel == null) channel = filter.channel;
        if (channel < 0 || channel >= channelFilters.length) return;

        final filterIndex = channelFilters[channel].indexOf(filter);
        if (filterIndex != -1) {
            filter.detach(channel);
            channelFilters[channel].splice(filterIndex, 1);

            // Notify backend
            app.backend.audio.removeFilter(channel, filter.id);
        }
    }

    /**
     * Get all filters for a specific channel
     * @param channel The channel to get filters for
     * @return Array of filters
     */
    public function filters(channel:Int):ReadOnlyArray<AudioFilter> {
        #if sys
        channelFiltersLock.acquire();
        #end
        var result = channelFilters[channel];
        if (result != null) {
            result = [].concat(result);
        }
        else {
            result = [];
        }
        #if sys
        channelFiltersLock.release();
        #end
        return result;
    }

    /**
     * Remove all filters from a specific channel
     * @param channel The channel to clear
     */
    public function clearFilters(channel:Int):Void {
        #if sys
        channelFiltersLock.acquire();
        #end
        if (channel < channelFilters.length) {
            final filters = channelFilters[channel];
            while (filters.length > 0) {
                _removeFilter(filters[filters.length - 1], channel);
            }
        }
        #if sys
        channelFiltersLock.release();
        #end
    }

}
