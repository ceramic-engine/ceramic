package ceramic;

import ceramic.Assets;
import ceramic.Entity;
import ceramic.Shortcuts.*;
import haxe.DynamicAccess;
import haxe.Json;

using StringTools;
using ceramic.Extensions;

/**
 * A fragment is a group of visuals rendered from data (.fragment file)
 */
class Fragment extends Layer {

    public var assets(default,null):Assets = null;

    public var entities(default,null):Array<Entity>;

    public var items(default,null):Array<FragmentItem>;

    public var tracks(default,null):Array<TimelineTrackData>;

    public var fps(default,set):Int = 30;

    public var fragmentData(default,set):FragmentData = null;

    public var resizable:Bool = false;

    public var autoUpdateTimeline(default, set):Bool = true;
    function set_autoUpdateTimeline(autoUpdateTimeline:Bool):Bool {
        if (this.autoUpdateTimeline != autoUpdateTimeline) {
            this.autoUpdateTimeline = autoUpdateTimeline;
            if (timeline != null) {
                timeline.autoUpdate = autoUpdateTimeline;
            }
        }
        return autoUpdateTimeline;
    }

    public var pendingLoads(default,null):Int = 0;

    public var timeline:Timeline = null;

    public var ready(default,null):Bool = false;

    @event function _ready();

    public function scheduleWhenReady(owner:Entity, cb:()->Void) {

        if (ready) {
            cb();
        }
        else {
            onceReady(owner, cb);
        }

    }

    function willEmitReady() {

        ready = true;

    }

/// Internal

    static var basicTypes:Map<String,Bool> = [
        'Bool' => true,
        'Int' => true,
        'Float' => true,
        'String' => true,
        'ceramic.Color' => true,
        'ceramic.ScriptContent' => true
    ];

/// Create from data

    static var cachedFragmentData:Map<String,FragmentData> = new Map();

    public static function cacheData(fragmentData:FragmentData) {

        cachedFragmentData.set(fragmentData.id, fragmentData);

    }

    /**
     * A static helper to get a fragment data object from fragment id.
     * Fragments need to be cached first with `cacheFragmentData()`.
     * @param fragmentId
     * @return Null<FragmentData>
     */
    public static function getData(fragmentId:String):Null<FragmentData> {

        return cachedFragmentData.get(fragmentId);

    }

/// Lifecycle

    public function new(?assets:Assets) {

        super();

        this.assets = assets;

        entities = [];
        items = [];

        #if ceramic_debug_fragments
        trace('new Fragment(context=$context)');
        #end

    }

/// Data

    function set_fragmentData(fragmentData:FragmentData):FragmentData {

        #if ceramic_debug_fragments
        trace('set fragmentData ${fragmentData.id} / $fragmentData');
        onceReady(this, function() {
            log.success('READY fragment ${fragmentData.id}');
        });
        #end

        pendingLoads++;

        this.fragmentData = fragmentData;
        var usedIds = new Map<String,Bool>();

        if (fragmentData != null) {

            width = fragmentData.width;
            height = fragmentData.height;

            if (fragmentData.color != null) {
                color = fragmentData.color;
            }
            else {
                color = Color.BLACK;
            }

            if (fragmentData.transparent != null) {
                transparent = fragmentData.transparent;
            }
            else {
                transparent = true;
            }

            if (fragmentData.items != null) {
                // Add/Update items
                for (item in fragmentData.items) {
                    putItem(item);
                    usedIds.set(item.id, true);
                }
            }

        }

        // Keep items if fragmentData is provided with no property 'items'
        if (fragmentData == null || Reflect.hasField(fragmentData, 'items')) {
            // Remove unused items
            var toRemove = null;
            for (entity in entities) {
                if (!usedIds.exists(entity.id)) {
                    if (toRemove == null)
                        toRemove = [];
                    toRemove.push(entity.id);
                }
            }
            if (toRemove != null) {
                for (id in toRemove) {
                    removeItem(id);
                }
            }
        }

        // Add fragment-level components
        if (fragmentData != null) {
            pendingLoads++;
            var converter = app.converters.get('ceramic.ReadOnlyMap<String,ceramic.Component>');
            converter.basicToField(
                this,
                'components',
                assets,
                fragmentData.components,
                function(value) {
                    if (destroyed) return;
                    pendingLoads--;

                    onceReady(this, function() {
                        this.fragmentComponents = value;
                    });

                    if (pendingLoads == 0) emitReady();
                }
            );
        }

        // Set FPS (if any)
        if (fragmentData != null && fragmentData.fps != null) {
            fps = fragmentData.fps;
        }

        // Add tracks (if any)
        var usedTrackIds:Map<String,Bool> = null;
        if (fragmentData != null && fragmentData.tracks != null) {
            for (track in fragmentData.tracks) {
                if (usedTrackIds == null)
                    usedTrackIds = new Map();
                usedTrackIds.set(track.entity + '#' + track.field, true);
                putTrack(track);
            }

            // Remove unused tracks
            if (timeline != null && timeline.tracks.length > 0) {
                for (existingTrack in [].concat(timeline.tracks.original)) {
                    if (usedTrackIds == null || !usedTrackIds.exists(existingTrack.id)) {
                        var parts = existingTrack.id.split('#');
                        if (parts.length == 2) {
                            removeTrack(parts[0], parts[1]);
                        }
                        else {
                            log.warning('Cannot remove track with unhandled id: ${existingTrack.id}');
                        }
                    }
                }
            }
        }

        // Add labels (if any)
        var usedLabels:Map<String,Bool> = null;
        if (fragmentData != null && fragmentData.labels != null) {
            var rawLabels = fragmentData.labels;
            for (name in rawLabels.keys()) {
                if (usedLabels == null)
                    usedLabels = new Map();
                usedLabels.set(name, true);
                var index = rawLabels.get(name);
                putLabel(index, name);
            }

            // Remove unused labels
            if (timeline != null && timeline.labels != null) {
                for (existingLabel in [].concat(timeline.labels.original)) {
                    if (usedLabels == null || !usedLabels.exists(existingLabel)) {
                        timeline.removeLabel(existingLabel);
                    }
                }
            }
        }

        pendingLoads--;
        if (pendingLoads == 0) emitReady();

        return fragmentData;

    }

    function set_fps(fps:Int):Int {
        if (this.fps != fps) {
            this.fps = fps;
            if (timeline != null) {
                timeline.fps = fps;
            }
            // When fps changes, we need to update track data
            if (tracks != null) {
                for (track in tracks) {
                    putTrack(track);
                }
            }
        }
        return fps;
    }

/// Public API

    public function putItem(item:FragmentItem):Entity {

        var existing = get(item.id);
        var existingWasVisual = false;

        // Remove previous object if entity class is different
        if (existing != null) {
            existingWasVisual = Std.isOfType(existing, Visual);
            if (item.entity != Type.getClassName(Type.getClass(existing))) {
                removeItem(item.id);
                existing = null;
            }
        }
        else {
            items.push(item);
        }

        var entityClass = Type.resolveClass(item.entity);
        var instance:Entity = existing != null ? existing : null;
        var isFragment = item.entity == 'ceramic.Fragment';
        if (instance == null) {
            var newArgs:Array<Dynamic> = [];
            if (isFragment) {
                newArgs.push(assets);
                newArgs.push(false);
                #if ceramic_debug_fragments
                if (isFragment) log.info('load item (fragment) ${item.id}');
                #end
            }
            instance = cast Type.createInstance(entityClass, newArgs);
        }
        if (instance == null) {
            throw 'Failed to create instance of ${item.entity}';
        }
        instance.id = item.id;

        if (isFragment) {
            var frag:ceramic.Fragment = cast instance;
            frag.depthRange = 1;
        }

        #if ceramic_entity_data
        // Set name
        if (instance.data.name == null && item.name != null) instance.data.name = item.name;

        // Copy item data
        if (item.data != null && instance.data != null) {
            for (key in Reflect.fields(item.data)) {
                Reflect.setField(instance.data, key, Reflect.field(item.data, key));
            }
        }
        #end

        // Copy item properties
        if (item.props != null) {
            var orderedProps = Reflect.fields(item.props);

            // TODO sort by order of properties in underlying class
            // For now we just ensure components is the last property being instanced
            haxe.ds.ArraySort.sort(orderedProps, function(a:String, b:String):Int {

                var nA = 0;
                var nB = 0;

                return nA - nB;

            });

            for (field in orderedProps) {
                var fieldType = typeOfItemField(item, field);
                var value:Dynamic = Reflect.field(item.props, field);
                var converter = fieldType != null ? app.converters.get(fieldType) : null;
                if (converter != null) {
                    putItemField(isFragment, item, instance, field, value, converter);
                }
                else {
                    if (!basicTypes.exists(fieldType)) {
                        var resolvedEnum = Type.resolveEnum(fieldType);
                        if (resolvedEnum != null) {
                            for (name in Type.getEnumConstructs(resolvedEnum)) {
                                if (name.toLowerCase() == value.toLowerCase()) {
                                    value = Type.createEnum(resolvedEnum, name);
                                    break;
                                }
                            }
                        }
                    }
                    instance.setProperty(field, value);
                }
            }

            // Components
            var fieldType = typeOfItemField(item, 'components');
            var value:Dynamic = item.components;
            var converter = fieldType != null ? app.converters.get(fieldType) : null;
            if (converter != null) {
                putItemField(isFragment, item, instance, 'components', value, converter);
            }
            else {
                log.warning('No converter found for field: components (type: $fieldType)');
            }

        }

        // A few more stuff to do if item is new
        if (existing == null) {

            // If instance has an assets property, set it from our fragment context
            if (typeOfItemField(item, 'assets') == 'ceramic.Assets') {
                instance.setProperty('assets', assets);
            }

            // Add instance (if new)
            entities.push(instance);
        }
        var isVisual = Std.isOfType(instance, Visual);
        // Add it to display tree if it is a visual
        if (isVisual && !existingWasVisual) {
            add(cast instance);
        }

        #if plugin_script
        // If there is a script object, give access to fragment
        var script = instance.script;
        if (script != null) {
            var interp = script.interp;
            if (interp != null) {
                var variables = interp.variables;
                if (variables != null) {
                    variables.set('fragment', this);
                }
            }
        }
        #end

        // Also ensure track is up to date, if there is any and the item is new
        if (existing == null) {
            putTracksForItem(item.id);
        }

        return instance;

    }

    private function typeOfItemField(item:FragmentItem, field:String):String {

        return if (item.schema != null) {
            // Use type provided by fragment data
            Reflect.field(item.schema, field);
        }
        else {
            // Try to resolve type from reflection if we
            // don't have the info from the fragment data
            FieldInfo.typeOf(item.entity, field);
        }

    }

    private function putItemField(isFragment:Bool, item:FragmentItem, instance:Entity, field:String, value:Dynamic, converter:ConvertField<Dynamic,Dynamic>) {

        pendingLoads++;
        converter.basicToField(
            instance,
            field,
            assets,
            value,
            function(value:Dynamic) {

                pendingLoads--;
                if (destroyed) return;

                if (!instance.destroyed) {
                    if (isFragment && field == 'fragmentData') {
                        var fragment:Fragment = cast instance;
                        pendingLoads++;
                        fragment.onceReady(this, function() {
                            pendingLoads--;
                            if (destroyed) return;
                            if (pendingLoads == 0) emitReady();
                        });
                        fragment.fragmentData = value;
                    }
                    else if (field != 'components') {
                        instance.setProperty(field, value);
                    }
                    else {
                        onceReady(this, function() {
                            var map:Map<String,Component> = null;
                            if (value != null) {
                                map = cast value;
                                if (map != null) {
                                    for (k in map.keys()) {
                                        var c = map.get(k);
                                        if (c != null) {
                                            instance.component(k, c);
                                        }
                                    }
                                }
                            }
                            /*
                            // For now don't remove any component, may change this later
                            if (instance.components != null) {
                                for (k in instance.components.keys()) {
                                    if (k != 'script') {
                                        if (map == null || map.get(k) == null) {
                                            instance.removeComponent(k);
                                        }
                                    }
                                }
                            }
                            */
                        });
                    }
                }

                if (pendingLoads == 0) emitReady();
            }
        );

    }

    public extern inline overload function get(itemId:String):Entity {
        return _get(itemId);
    }

    public extern inline overload function get<T:Entity>(itemId:String, type:Class<T>):T {
        return _getWithType(itemId, type);
    }

    function _get(itemId:String):Entity {

        for (entity in entities) {
            if (entity.id == itemId) {

                return entity;
            }
        }

        return null;

    }

    function _getWithType<T:Entity>(itemId:String, type:Class<T>):T {
        final entity:Entity = _get(itemId);
        if (entity != null) {
            return cast entity;
        }
        return null;
    }

    @:noCompletion @:deprecated
    public function getItemInstanceByName(name:String):Entity {

        for (entity in entities) {
            #if ceramic_entity_data
            if (entity.data.name == name) {

                return entity;

            }
            else #end if (entity.id == name) {

                return entity;

            }
        }

        return null;

    }

    public function getItem(itemId:String):FragmentItem {

        for (item in items) {
            if (item.id == itemId) {

                return item;
            }
        }

        return null;

    }

    public function getItemByName(name:String):FragmentItem {

        for (item in items) {
            if (item.name == name) {

                return item;
            }
        }

        return null;

    }

    public function typeOfItem(itemId:String):String {

        var item = getItem(itemId);
        if (item != null) {
            return item.entity;
        }
        else {
            log.warning('Failed to resolve entity type for item $itemId');
            return null;
        }

    }

    public function removeItem(itemId:String):Void {

        for (entity in entities) {
            if (entity.id == itemId) {

                entities.remove(entity);
                entity.destroy();

                break;
            }
        }

        for (item in items) {
            if (item.id == itemId) {

                items.remove(item);

                break;
            }
        }

    }

    public function removeAllItems():Void {

        for (entity in [].concat(entities)) {

            entities.remove(entity);
            entity.destroy();

        }

        for (item in [].concat(items)) {

            items.remove(item);

        }

    }

    override function destroy() {

        super.destroy();

        if (timeline != null) {
            timeline.destroy();
            timeline = null;
        }

        removeAllItems();

    }

/// Fragment components

    // We need to override this setter to ensure a component is not accidentally destroyed
    // if provided from fragmentComponents property
    override function set_components(components:ReadOnlyMap<String,Component>):ReadOnlyMap<String,Component> {
        if (_components == components) return components;

        // Remove older components
        if (_components != null) {
            for (name in _components.keys()) {
                if (components == null || !components.exists(name)) {
                    if (fragmentComponents == null || !fragmentComponents.exists(name)) {
                        removeComponent(name);
                    }
                }
            }
        }

        // Add new components
        if (components != null) {
            for (name in components.keys()) {
                var newComponent = components.get(name);
                if (_components != null) {
                    var existing = _components.get(name);
                    if (existing != null) {
                        if (existing != newComponent) {
                            removeComponent(name);
                            component(name, newComponent);
                        }
                    } else {
                        component(name, newComponent);
                    }
                } else {
                    component(name, newComponent);
                }
            }
        }

        // Update mapping
        _components = components;

        return components;
    }

    /**
     * Fragment components mapping. Does not contain components
     * created separatelywith `component()` or macro-based components or components property.
     */
    public var fragmentComponents(default,set):ReadOnlyMap<String,Component> = null;
    function set_fragmentComponents(fragmentComponents:ReadOnlyMap<String,Component>):ReadOnlyMap<String,Component> {
        if (this.fragmentComponents == fragmentComponents) return fragmentComponents;

        // Remove older components
        if (this.fragmentComponents != null) {
            for (name in this.fragmentComponents.keys()) {
                if (fragmentComponents == null || !fragmentComponents.exists(name)) {
                    removeComponent(name);
                }
            }
        }

        // Add new components
        if (fragmentComponents != null) {
            for (name in fragmentComponents.keys()) {
                var newComponent = fragmentComponents.get(name);
                if (this.fragmentComponents != null) {
                    var existing = this.fragmentComponents.get(name);
                    if (existing != null) {
                        if (existing != newComponent) {
                            removeComponent(name);
                            component(name, newComponent);
                        }
                    } else {
                        component(name, newComponent);
                    }
                } else {
                    component(name, newComponent);
                }
            }
        }

        // Update mapping
        this.fragmentComponents = fragmentComponents;

        return fragmentComponents;
    }

    function isManagedComponent() {

    }

/// Timeline

    /**
     * Internal value used to hold timeline tracks created from `createTrack` events
     */
    static var _trackResult = new Value<TimelineTrack<TimelineKeyframe>>();

    /**
     * Internal value used to hold timeline keyframes created from `createKeyframe` events
     */
    static var _keyframeResult = new Value<TimelineKeyframe>();

    /**
     * Internal list used to keep track of used keyframes when updating a track,
     * then be able to remove the keyframes that are not used anymore
     */
    static var _usedKeyframes:Array<TimelineKeyframe> = [];

    /**
     * Create or update a timeline track from the provided track data
     * @param entityType
     *      (optional) entity type being targeted by the track.
     *      If not provided, will try to resolve it from track's target entity id
     * @param track Track data used to create or update timeline track
     */
    public function putTrack(?entityType:String, track:TimelineTrackData):Void {

        //trace('put track: $track');

        var existingIndexes:Map<Int,Bool> = null;

        var existing = getTrack(track.entity, track.field);
        if (existing == null) {
            // Add track data
            if (tracks == null) {
                tracks = [];
            }
            tracks.push(track);
        }
        else {
            // Keep references of existing keyframes
            existingIndexes = new Map<Int,Bool>();
            for (keyframe in existing.keyframes) {
                existingIndexes.set(keyframe.index, true);
            }

            // Replace track data
            var indexOfTrack = tracks.indexOf(existing);
            tracks[indexOfTrack] = track;
        }

        // Retrieve entity instance
        var entityId = track.entity;
        var entity = get(entityId);

        // Update keyframes
        if (track.keyframes != null && track.keyframes.length > 0) {
            // Create timeline is not created already
            createTimelineIfNeeded();

            var field = track.field;
            var trackId = entityId + '#' + field;
            var trackOptions = track.options;

            if (entityType == null) {
                entityType = typeOfItem(track.entity);
            }
            if (entityType == null) {
                log.warning('Cannot update timeline track $trackId: failed to resolve entity type');
                return;
            }
            // TODO avoid using FieldInfo for new format
            var entityInfo = FieldInfo.types(entityType);
            var entityFieldType = entityInfo != null ? entityInfo.get(field) : null;
            if (entityFieldType == null) {
                log.warning('Cannot update timeline track $trackId: failed to resolve info for $field of entity type $entityType');
                return;
            }

            // Create timeline track if not created yet
            var timelineTrack = timeline.get(trackId);
            if (timelineTrack == null) {
                if (entity == null) {
                    log.warning('Failed to create timeline track $trackId because there is no entity with id ${track.entity}');
                    return;
                }

                _trackResult.value = null;
                app.timelines.emitCreateTrack(entityFieldType, trackOptions, _trackResult);
                timelineTrack = _trackResult.value;
                if (timelineTrack == null) {
                    log.warning('Failed to create timeline track $trackId for $field of entity type $entityType');
                    return;
                }

                // When entity is destroyed, destroy track as well
                entity.onDestroy(timelineTrack, _ -> {
                    timelineTrack.destroy();
                });

                // Configure new track
                timelineTrack.id = trackId;
                app.timelines.emitBindTrack(entityFieldType, trackOptions, timelineTrack, entity, field);

                // Add track to timeline
                timeline.add(timelineTrack);
            }

            timelineTrack.loop = track.loop;

            // Add/update keyframes
            if (_usedKeyframes.length > 0) {
                for (i in 0..._usedKeyframes.length) {
                    _usedKeyframes.unsafeSet(i, null);
                }
                _usedKeyframes.setArrayLength(0);
            }
            var prevIndex:Int = -1;
            var isSorted = true;
            for (keyframe in track.keyframes) {
                var index = keyframe.index;

                if (index < prevIndex) {
                    isSorted = false;
                }
                prevIndex = index;

                var existing = timelineTrack.findKeyframeAtIndex(index);
                _keyframeResult.value = null;
                app.timelines.emitCreateKeyframe(entityFieldType, trackOptions, keyframe.value, index, EasingUtils.easingFromString(keyframe.easing), existing, _keyframeResult);
                var timelineKeyframe = _keyframeResult.value;

                if (timelineKeyframe != null) {
                    _usedKeyframes.push(timelineKeyframe);
                    if (existing != null) {
                        if (existing != timelineKeyframe) {
                            timelineTrack.remove(existing);
                            timelineTrack.add(timelineKeyframe);
                        }
                        else {
                            // Keeping the same keyframe, just changed its internal values!
                        }
                    }
                    else {
                        timelineTrack.add(timelineKeyframe);
                    }
                }
                else {
                    log.warning('Failed to create or update keyframe #$frame of track $trackId for field $field of entity type $entityType');
                    return;
                }
            }

            // Check if some keyframes should be removed
            var toRemove:Array<TimelineKeyframe> = null;
            var timelineKeyframes = timelineTrack.keyframes;
            if (isSorted) {
                // When input keyframes array is properly sorted in ascending order, we can efficiently check keyframes
                // that should be kept and keyframes that should be removed
                var usedIndex = 0;
                for (i in 0...timelineKeyframes.length) {
                    var timelineKeyframe = timelineKeyframes[i];
                    if (_usedKeyframes[usedIndex] == timelineKeyframe) {
                        // Allright, this is a keyframe we want to keep
                        usedIndex++;
                    }
                    else {
                        // This keyframe is not used anymore, remove it
                        if (toRemove == null) {
                            toRemove = [];
                        }
                        toRemove.push(timelineKeyframe);
                    }
                }
            }
            else {
                // When input keyframes array is not sorted in ascending order,
                // we need to walk used keyframe array at each iteration!
                log.warning('Input keyframe array should be sorted by time in ascending order!');
                for (i in 0...timelineKeyframes.length) {
                    var timelineKeyframe = timelineKeyframes[i];
                    if (_usedKeyframes.indexOf(timelineKeyframe) == -1) {
                        // This keyframe is not used anymore, remove it
                        if (toRemove == null) {
                            toRemove = [];
                        }
                        toRemove.push(timelineKeyframe);
                    }
                }
            }

            // So, is there anything to remove?
            if (toRemove != null) {
                // Yes!
                for (timelineKeyframe in toRemove) {
                    timelineTrack.remove(timelineKeyframe);
                }
                toRemove = null;
            }

            // Cleanup used keyframes array
            if (_usedKeyframes.length > 0) {
                for (i in 0..._usedKeyframes.length) {
                    _usedKeyframes.unsafeSet(i, null);
                }
                _usedKeyframes.setArrayLength(0);
            }

            // Apply timeline track changes to entity
            timelineTrack.apply();
        }

    }

    function putTracksForItem(itemId:String):Void {

        if (tracks != null) {
            for (i in 0...tracks.length) {
                var track = tracks[i];
                if (track.entity == itemId) {
                    putTrack(track);
                }
            }
        }

    }

    public function getTrack(entity:String, field:String):TimelineTrackData {

        if (tracks != null) {
            for (track in tracks) {
                if (track.entity == entity && track.field == field) {
                    return track;
                }
            }
        }

        return null;

    }

    public function removeTrack(entity:String, field:String):Void {

        if (tracks != null) {
            var index = -1;
            for (i in 0...tracks.length) {
                var track = tracks[i];
                if (track.entity == entity && track.field == field) {
                    index = i;
                    break;
                }
            }

            if (index != -1) {
                tracks.splice(index, 1);

                // Remove the actual timeline track
                if (timeline != null) {
                    var trackId = entity + '#' + field;
                    var timelineTrack = timeline.get(trackId);
                    if (timelineTrack != null) {
                        timeline.remove(timelineTrack);
                        timelineTrack.destroy();
                    }
                }
            }
        }

    }

    public function createTimelineIfNeeded() {

        if (timeline == null) {
            timeline = new Timeline();
            timeline.fps = fps;
            timeline.autoUpdate = autoUpdateTimeline;
        }

    }

    /**
     * Create or update a timeline label from the provided label index and name
     * @param index Label index (position)
     * @param name Label name
     */
    public function putLabel(index:Int, name:String):Void {

        // Create timeline is not created already
        createTimelineIfNeeded();

        // Update timeline with given label
        timeline.setLabel(index, name);

    }

    /**
     * Return the index (position) of the given label name or -1 if no such label exists.
     * @param name
     * @return Int
     */
    public function indexOfLabel(name:String):Int {

        if (timeline != null) {
            return timeline.indexOfLabel(name);
        }

        return -1;

    }

    /**
     * Return the label at the given index (position), if any exists.
     * @param index
     * @return Int
     */
    public function labelAtIndex(index:Int):String {

        if (timeline != null) {
            return timeline.labelAtIndex(index);
        }

        return null;

    }

    /**
     * Remove label with the given name
     * @param name Label name
     */
    public function removeLabel(name:String):Void {

        if (timeline != null) {
            timeline.removeLabel(name);
        }

    }

    /**
     * Remove label at the given index (position)
     * @param index Label index
     */
    public function removeLabelAtIndex(index:Int):Void {

        if (timeline != null) {
            timeline.removeLabelAtIndex(index);
        }

    }

    public var paused(get, set):Bool;
    function get_paused():Bool {
        return timeline != null && timeline.paused;
    }
    function set_paused(paused:Bool):Bool {
        var prevPaused = timeline != null && timeline.paused;
        if (prevPaused != paused) {
            createTimelineIfNeeded();
            timeline.paused = paused;
        }
        return paused;
    }

    #if ceramic_fragment_float_events
    @event function floatAChange(floatA:Float, prevFloatA:Float);

    @event function floatBChange(floatB:Float, prevFloatB:Float);

    @event function floatCChange(floatC:Float, prevFloatC:Float);

    @event function floatDChange(floatD:Float, prevFloatD:Float);
    #end

    #if ceramic_fragment_location_event
    /**
     * Emit this event to change current location.
     * Behavior depends on how this event is handled and does nothing by default.
     */
    @event public function location(location:String);
    #end

}
