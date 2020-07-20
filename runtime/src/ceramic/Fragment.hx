package ceramic;

import ceramic.Shortcuts.*;
import ceramic.Entity;
import ceramic.Assets;

import haxe.DynamicAccess;

using ceramic.Extensions;
using StringTools;

/** A fragment is a group of visuals rendered from data (.fragment file) */
@editable({
    implicitSizeUnlessTrue: 'resizable'
})
class Fragment extends Layer {

    @event function floatAChange(floatA:Float, prevFloatA:Float);

    @event function floatBChange(floatB:Float, prevFloatB:Float);

    @event function floatCChange(floatC:Float, prevFloatC:Float);

    @event function floatDChange(floatD:Float, prevFloatD:Float);

    public var editedItems(default,null):Bool = false;

    public var assets(default,null):Assets = null;

    public var entities(default,null):Array<Entity>;

    public var items(default,null):Array<FragmentItem>;

    public var tracks(default,null):Array<TimelineTrackData>;

    public var fps(default,set):Int = 30;

    @editable
    public var fragmentData(default,set):FragmentData = null;

    @editable
    public var resizable:Bool = false;

    @editable
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
     * Custom float value that can be used in editor
     */
    @editable({ group: 'floatsAB' })
    public var floatA(default, set):Float = 0.0;
    function set_floatA(floatA:Float):Float {
        if (this.floatA != floatA) {
            var prevFloatA = this.floatA;
            this.floatA = floatA;
            emitFloatAChange(floatA, prevFloatA);
        }
        return floatA;
    }

    /**
     * Custom float value that can be used in editor
     */
    @editable({ group: 'floatsAB' })
    public var floatB(default, set):Float = 0.0;
    function set_floatB(floatB:Float):Float {
        if (this.floatB != floatB) {
            var prevFloatA = this.floatB;
            this.floatB = floatB;
            emitFloatBChange(floatB, prevFloatA);
        }
        return floatB;
    }

    /**
     * Custom float value that can be used in editor
     */
    @editable({ group: 'floatsCD' })
    public var floatC(default, set):Float = 0.0;
    function set_floatC(floatC:Float):Float {
        if (this.floatC != floatC) {
            var prevFloatC = this.floatC;
            this.floatC = floatC;
            emitFloatCChange(floatC, prevFloatC);
        }
        return floatC;
    }

    /**
     * Custom float value that can be used in editor
     */
    @editable({ group: 'floatsCD' })
    public var floatD(default, set):Float = 0.0;
    function set_floatD(floatD:Float):Float {
        if (this.floatD != floatD) {
            var prevFloatD = this.floatD;
            this.floatD = floatD;
            emitFloatDChange(floatD, prevFloatD);
        }
        return floatD;
    }

    public var pendingLoads(default,null):Int = 0;

    public var timeline:Timeline = null;

    @event function ready();

#if editor

    @event function editableItemUpdate(item:FragmentItem);

    var updatedEditableItems:Map<String,FragmentItem> = null;

#end

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
     * Fragments need to be cached first with `cacheFragmentData()`,
     * unless an editor instance is being active.
     * @param fragmentId 
     * @return Null<FragmentData>
     */
    public static function getData(fragmentId:String):Null<FragmentData> {

        #if editor
        // When using editor, check if fragment exists in editor first
        var editorInstance = editor.Editor.editor;
        if (editorInstance != null) {
            var model = editorInstance.model;
            if (model != null) {
                var project = model.project;
                if (project != null) {
                    var editorFragment = project.fragmentById(fragmentId);
                    if (editorFragment != null) {
                        return editorFragment.toFragmentData();
                    }
                }
            }
        }
        #end

        return cachedFragmentData.get(fragmentId);

    }

/// Lifecycle

    public function new(?assets:Assets, editedItems:Bool = false) {

        super();

        this.editedItems = editedItems;
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
            var toRemove = [];
            for (entity in entities) {
                if (!usedIds.exists(entity.id)) {
                    toRemove.push(entity.id);
                }
            }
            for (id in toRemove) {
                removeItem(id);
            }
        }

        // Add fragment-level components
        if (fragmentData != null #if editor && edited #end) {
            pendingLoads++;
            var converter = app.converters.get('ceramic.ReadOnlyMap<String,ceramic.Component>');
            converter.basicToField(
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
        if (fragmentData != null && fragmentData.tracks != null) {
            for (track in fragmentData.tracks) {
                putTrack(track);
            }
        }

        pendingLoads--;
        if (pendingLoads == 0) emitReady();

        return fragmentData;

    }

    function set_fps(fps:Int):Int {
        if (this.fps != fps) {
            this.fps = fps;
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
            existingWasVisual = Std.is(existing, Visual);
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

#if editor
        instance.edited = editedItems;
#end

        // Set name
        if (instance.data.name == null && item.name != null) instance.data.name = item.name;

        // Copy item data
        if (item.data != null && instance.data != null) {
            for (key in Reflect.fields(item.data)) {
                Reflect.setField(instance.data, key, Reflect.field(item.data, key));
            }
        }

        // Copy item properties
        if (item.props != null) {
            var orderedProps = Reflect.fields(item.props);

            // TODO sort by order of properties in underlying class
            // For now we just ensure components is the last property being instanced
            haxe.ds.ArraySort.sort(orderedProps, function(a:String, b:String):Int {

                var nA = 0;
                var nB = 0;

                #if ceramic_fragment_legacy
                if (a == 'components') nA++;
                else if (b == 'components') nB++;
                #end

                return nA - nB;

            });
            
            for (field in orderedProps) {
                var fieldType = FieldInfo.typeOf(item.entity, field);
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
            var fieldType = FieldInfo.typeOf(item.entity, 'components');
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
            if (FieldInfo.typeOf(item.entity, 'assets') == 'ceramic.Assets') {
                instance.setProperty('assets', assets);
            }

            // Add instance (if new)
            entities.push(instance);
        }
        var isVisual = Std.is(instance, Visual);
        // Add it to display tree if it is a visual
        if (isVisual && !existingWasVisual) {
            add(cast instance);
        }

        #if ceramic_entity_script
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

#if editor
        // Update editable fields from instance
        computeInstanceContentIfNeeded(item.id, instance);
        if (editedItems) {
            updateEditableFieldsFromInstance(item.id);
        }
#end

        return instance;

    }

    private function putItemField(isFragment:Bool, item:FragmentItem, instance:Entity, field:String, value:Dynamic, converter:ConvertField<Dynamic,Dynamic>) {

        pendingLoads++;
        converter.basicToField(
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

                        #if editor
                        computeInstanceContentIfNeeded(item.id, instance);
                        if (editedItems) {
                            updateEditableFieldsFromInstance(item.id);
                        }
                        #end
                    }
                    else {
                        onceReady(this, function() {
                            // #if editor
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
                                    if (k != 'editable' && k != 'script') {
                                        if (map == null || map.get(k) == null) {
                                            instance.removeComponent(k);
                                        }
                                    }
                                }
                            }
                            */
                            #if editor
                            computeInstanceContentIfNeeded(item.id, instance);
                            if (editedItems) {
                                updateEditableFieldsFromInstance(item.id);
                            }
                            #end
                            // #else
                            // instance.setProperty(field, value);
                            // #end
                        });
                    }
                }

                if (pendingLoads == 0) emitReady();
            }
        );

    }

    public function get(itemId:String):Entity {

        for (entity in entities) {
            if (entity.id == itemId) {
                
                return entity;
            }
        }

        return null;

    }

    @:noCompletion @:deprecated
    public function getItemInstanceByName(name:String):Entity {

        for (entity in entities) {
            if (entity.data.name == name) {
                
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

#if editor

    var emitEditableItemUpdateScheduled:Bool = false;

    public function computeInstanceContentIfNeeded(itemId:String, ?entity:Entity) {

        // Update editable fields from instance
        if (entity == null) {
            entity = get(itemId);
        }
        if (entity != null) {
            var isVisual = Std.is(entity, Visual);
            if (isVisual) {
                var visual:Visual = cast entity;
                if (visual.contentDirty) {
                    visual.computeContent();
                }
            }
        }

    }

    public function updateEditableFieldsFromInstance(itemId:String):Void {

        if (!emitEditableItemUpdateScheduled) {
            emitEditableItemUpdateScheduled = true;
            app.onceImmediate(() -> {
                if (!destroyed) {
                    updateEditableFieldsFromInstance(itemId);
                }
            });
            return;
        }
        else {
            emitEditableItemUpdateScheduled = false;
        }

        // Get item
        var item = getItem(itemId);
        if (item == null) {
            return;
        }

        // Get instance
        var instance = get(item.id);
        if (instance == null) {
            return;
        }

        // Compute missing data (if any)
        var editableFields = FieldInfo.editableFieldInfo(item.entity);
        var hasChanged = false;
        for (field in editableFields.keys()) {
            var fieldType = FieldInfo.typeOf(item.entity, field);
            var converter = fieldType != null ? app.converters.get(fieldType) : null;
            var value:Dynamic = null;
            if (converter != null) {
                value = converter.fieldToBasic(instance.getProperty(field));
            } else {
                value = instance.getProperty(field);
                switch (Type.typeof(value)) {
                    case TEnum(e):
                        value = Std.string(value);
                        var fieldInfo = editableFields.get(field);
                        var metaEditable = fieldInfo.meta.get('editable');
                        if (metaEditable != null && metaEditable.length > 0 && metaEditable[0].options != null) {
                            var opts:Array<String> = metaEditable[0].options;
                            for (opt in opts) {
                                if (value.toLowerCase() == opt.toLowerCase()) {
                                    value = opt;
                                    break;
                                }
                            }
                        }
                    default:
                        // Keep the value as is
                }
            }
            if (field == 'components') {
                // TODO?
            }
            else {
                if (Reflect.field(item.props, field) != value || !Reflect.hasField(item.props, field)) {
                    hasChanged = true;
                    Reflect.setField(item.props, field, value);
                }
            }
        }

        if (hasChanged) {
            if (updatedEditableItems == null) {
                updatedEditableItems = new Map();
                app.onceUpdate(this, function(delta) {
                    var prevUpdated = updatedEditableItems;
                    updatedEditableItems = null;
                    for (itemId in prevUpdated.keys()) {
                        var anItem = prevUpdated.get(itemId);
                        emitEditableItemUpdate(anItem);
                    }
                });
            }
            updatedEditableItems.set(item.id, item);
        }

    }

#end

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

    /** Fragment components mapping. Does not contain components
        created separatelywith `component()` or macro-based components or components property. */
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
            var entityInfo = #if editor FieldInfo.types(entityType) #else null #end;
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
            var prevTime:Float = -1;
            var isSorted = true;
            for (keyframe in track.keyframes) {
                var index = keyframe.index;
                var time = index / fps;

                if (time < prevTime) {
                    isSorted = false;
                }
                prevTime = time;

                var existing = timelineTrack.findKeyframeAtTime(time);
                _keyframeResult.value = null;
                app.timelines.emitCreateKeyframe(entityFieldType, trackOptions, keyframe.value, time, EasingUtils.easingFromString(keyframe.easing), existing, _keyframeResult);
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
                    log.warning('Failed to create or update keyframe #$index of track $trackId for field $field of entity type $entityType');
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

        #if editor
        // Update editable fields from instance
        computeInstanceContentIfNeeded(entityId, entity);
        if (editedItems) {
            updateEditableFieldsFromInstance(entityId);
        }
        #end

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

        //trace('remove track $entity # $field');

    }
    
    public function createTimelineIfNeeded() {
        
        if (timeline == null) {
            timeline = new Timeline();
            timeline.autoUpdate = autoUpdateTimeline;
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

}
