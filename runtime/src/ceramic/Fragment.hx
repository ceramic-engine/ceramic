package ceramic;

import ceramic.Assets;
import ceramic.Entity;
import ceramic.Shortcuts.*;
import haxe.DynamicAccess;
import haxe.Json;

using StringTools;
using ceramic.Extensions;

/**
 * A fragment is a powerful container that manages groups of entities and visuals
 * loaded from fragment data files (.fragment).
 * 
 * Fragments provide:
 * - Dynamic entity instantiation from data definitions
 * - Timeline-based animation support with tracks and keyframes
 * - Component system integration
 * - Hierarchical entity management
 * - Asset loading and dependency management
 * 
 * Fragments are commonly used for:
 * - UI layouts and screens
 * - Reusable game objects and prefabs
 * - Animated sequences and cutscenes
 * - Data-driven content that needs to be loaded/unloaded dynamically
 * 
 * @see FragmentData
 * @see FragmentItem
 * @see Timeline
 */
class Fragment extends Layer {

    /**
     * The asset manager used to load resources referenced by this fragment.
     * If not provided, the fragment will use the default app assets.
     */
    public var assets(default,null):Assets = null;

    /**
     * Array of all entity instances created from fragment items.
     * This includes all types of entities: visuals, components, and other objects.
     */
    public var entities(default,null):Array<Entity>;

    /**
     * Array of fragment item definitions loaded from fragment data.
     * Each item describes an entity to be instantiated with its properties.
     */
    public var items(default,null):Array<FragmentItem>;

    /**
     * Array of timeline track data for animating entity properties.
     * Each track defines keyframe animations for a specific entity field.
     */
    public var tracks(default,null):Array<TimelineTrackData>;

    /**
     * Frames per second for timeline animations.
     * Affects the playback speed of all timeline tracks in this fragment.
     * Default is 30 FPS.
     */
    public var fps(default,set):Int = 30;

    /**
     * The fragment data that defines this fragment's content.
     * Setting this property will instantiate/update all entities and animations.
     */
    public var fragmentData(default,set):FragmentData = null;

    /**
     * Whether this fragment can be resized.
     * When true, the fragment dimensions can be changed after initialization.
     */
    public var resizable:Bool = false;

    /**
     * Whether the timeline should automatically update each frame.
     * Set to false to manually control timeline playback.
     * Default is true.
     */
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

    /**
     * Number of pending asset loads.
     * When this reaches 0, the fragment becomes ready.
     */
    public var pendingLoads(default,null):Int = 0;

    /**
     * The timeline instance managing animations for this fragment.
     * Created automatically when tracks are added.
     */
    public var timeline:Timeline = null;

    /**
     * Whether the fragment has finished loading all assets and is ready to use.
     * Becomes true when all pending loads complete.
     */
    public var ready(default,null):Bool = false;

    /**
     * Event emitted when the fragment becomes ready.
     * All assets are loaded and entities are instantiated.
     */
    @event function _ready();

    /**
     * Schedule a callback to be executed when the fragment is ready.
     * If already ready, the callback is executed immediately.
     * 
     * @param owner The entity that owns this callback (for cleanup)
     * @param cb The callback to execute when ready
     */
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

    /**
     * Cache fragment data for later retrieval by ID.
     * This allows fragments to reference other fragments efficiently.
     * 
     * @param fragmentData The fragment data to cache
     */
    public static function cacheData(fragmentData:FragmentData) {

        cachedFragmentData.set(fragmentData.id, fragmentData);

    }

    /**
     * Retrieve cached fragment data by ID.
     * The data must have been previously cached with `cacheData()`.
     * 
     * @param fragmentId The ID of the fragment data to retrieve
     * @return The cached fragment data, or null if not found
     */
    public static function getData(fragmentId:String):Null<FragmentData> {

        return cachedFragmentData.get(fragmentId);

    }

/// Lifecycle

    /**
     * Create a new fragment instance.
     * 
     * @param assets Optional asset manager for loading resources.
     *               If not provided, uses the default app assets.
     */
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

    /**
     * Create or update an entity from a fragment item definition.
     * If an entity with the same ID already exists, it will be updated.
     * Otherwise, a new entity is created and added to the fragment.
     * 
     * @param item The fragment item definition
     * @return The created or updated entity instance
     */
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

    /**
     * Get an entity by its ID.
     * 
     * @param itemId The ID of the entity to retrieve
     * @return The entity instance, or null if not found
     */
    public extern inline overload function get(itemId:String):Entity {
        return _get(itemId);
    }

    /**
     * Get an entity by its ID with type casting.
     * 
     * @param itemId The ID of the entity to retrieve
     * @param type The expected entity type
     * @return The typed entity instance, or null if not found
     */
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

    /**
     * Get a fragment item definition by ID.
     * 
     * @param itemId The ID of the item to retrieve
     * @return The fragment item definition, or null if not found
     */
    public function getItem(itemId:String):FragmentItem {

        for (item in items) {
            if (item.id == itemId) {

                return item;
            }
        }

        return null;

    }

    /**
     * Get a fragment item definition by name.
     * 
     * @param name The name of the item to retrieve
     * @return The fragment item definition, or null if not found
     */
    public function getItemByName(name:String):FragmentItem {

        for (item in items) {
            if (item.name == name) {

                return item;
            }
        }

        return null;

    }

    /**
     * Get the entity class name for a fragment item.
     * 
     * @param itemId The ID of the item
     * @return The fully qualified class name of the entity type
     */
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

    /**
     * Remove an entity and its item definition from the fragment.
     * The entity will be destroyed.
     * 
     * @param itemId The ID of the item to remove
     */
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

    /**
     * Remove all entities and item definitions from the fragment.
     * All entities will be destroyed.
     */
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
     * Components defined at the fragment level (not on individual entities).
     * These are separate from components added via `component()` or the components property.
     * Setting this property will add/remove/update components as needed.
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
     * Create or update a timeline track for animating entity properties.
     * The track will be added to the fragment's timeline, creating it if needed.
     * 
     * @param entityType Optional entity type. If not provided, will be resolved from the entity ID.
     * @param track The track data containing entity ID, field name, and keyframes
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

    /**
     * Get timeline track data for a specific entity field.
     * 
     * @param entity The entity ID
     * @param field The field name being animated
     * @return The track data, or null if not found
     */
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

    /**
     * Remove a timeline track for a specific entity field.
     * 
     * @param entity The entity ID
     * @param field The field name being animated
     */
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

    /**
     * Create the timeline instance if it doesn't exist yet.
     * Called automatically when tracks or labels are added.
     */
    public function createTimelineIfNeeded() {

        if (timeline == null) {
            timeline = new Timeline();
            timeline.fps = fps;
            timeline.autoUpdate = autoUpdateTimeline;
        }

    }

    /**
     * Create or update a timeline label at a specific position.
     * Labels can be used to mark important points in the animation.
     * 
     * @param index The timeline position (frame index)
     * @param name The label name
     */
    public function putLabel(index:Int, name:String):Void {

        // Create timeline is not created already
        createTimelineIfNeeded();

        // Update timeline with given label
        timeline.setLabel(index, name);

    }

    /**
     * Get the timeline position of a label by name.
     * 
     * @param name The label name
     * @return The frame index, or -1 if the label doesn't exist
     */
    public function indexOfLabel(name:String):Int {

        if (timeline != null) {
            return timeline.indexOfLabel(name);
        }

        return -1;

    }

    /**
     * Get the label name at a specific timeline position.
     * 
     * @param index The frame index
     * @return The label name, or null if no label exists at that position
     */
    public function labelAtIndex(index:Int):String {

        if (timeline != null) {
            return timeline.labelAtIndex(index);
        }

        return null;

    }

    /**
     * Remove a timeline label by name.
     * 
     * @param name The label name to remove
     */
    public function removeLabel(name:String):Void {

        if (timeline != null) {
            timeline.removeLabel(name);
        }

    }

    /**
     * Remove a timeline label at a specific position.
     * 
     * @param index The frame index where the label should be removed
     */
    public function removeLabelAtIndex(index:Int):Void {

        if (timeline != null) {
            timeline.removeLabelAtIndex(index);
        }

    }

    /**
     * Whether the timeline playback is paused.
     * Setting this to true stops all animations in the fragment.
     */
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
    /**
     * Event emitted when floatA value changes.
     * Can be used for custom fragment behaviors.
     */
    @event function floatAChange(floatA:Float, prevFloatA:Float);

    /**
     * Event emitted when floatB value changes.
     * Can be used for custom fragment behaviors.
     */
    @event function floatBChange(floatB:Float, prevFloatB:Float);

    /**
     * Event emitted when floatC value changes.
     * Can be used for custom fragment behaviors.
     */
    @event function floatCChange(floatC:Float, prevFloatC:Float);

    /**
     * Event emitted when floatD value changes.
     * Can be used for custom fragment behaviors.
     */
    @event function floatDChange(floatD:Float, prevFloatD:Float);
    #end

    #if ceramic_fragment_location_event
    /**
     * Event for changing the current location/state of the fragment.
     * The behavior depends on how this event is handled by listeners.
     * Common uses include scene transitions or state changes.
     * 
     * @param location The new location identifier
     */
    @event public function location(location:String);
    #end

}
