package;

import ceramic.App;
import ceramic.Blending;
import ceramic.Color;
import ceramic.Easing;
import ceramic.EasingUtils;
import ceramic.Entity;
import ceramic.Fragment;
import ceramic.FragmentData;
import ceramic.FragmentsAsset;
import ceramic.InitSettings;
import ceramic.Quad;
import ceramic.Timeline;
import ceramic.TimelineInterpolation;
import ceramic.Timer;
import ceramic.TimelineFloatKeyframe;
import ceramic.TimelineFloatTrack;
import ceramic.Visual;

/**
 * Checks of fragments and timelines (see `check.sh`). Nothing is shown on
 * screen and no asset is loaded: every fragment is built from data written
 * here, with its own schema, so the project does not need
 * `ceramic_entity_field_info`.
 */
class Project extends Entity {

    var checks = 0;

    var failures = 0;

    function new(settings:InitSettings) {

        super();

        settings.targetWidth = 320;
        settings.targetHeight = 240;

        App.app.onceReady(this, ready);

    }

    function ready() {

        // Classes created by name from fragment data
        final kept:Array<Dynamic> = [Quad, Visual, Fragment];
        check('classes are available', kept.length == 3);

        try {
            timelineLabels();
            timelineKeyframes();
            timelineAnimate();
            fragmentItems();
            easings();
            interpolation();
            schemaAndTracks();
            parents();
            nestedFragments();
            assetReload();
        }
        catch (e:Dynamic) {
            fail('uncaught: $e');
        }

        // Last: a scene that preloads a fragment of assets/checks.fragments
        final scene = new CheckScene();
        App.app.scenes.main = scene;
        Timer.delay(this, 5.0, () -> {
            fail('scene: timed out');
            finish();
        });
        scene.scheduleOnceReady(this, () -> {
            try {
                sceneChecks(scene);
            }
            catch (e:Dynamic) {
                fail('uncaught: $e');
            }
            finish();
        });

    }

/// Timeline

    function timelineLabels():Void {

        final timeline = new Timeline();
        timeline.autoUpdate = false;

        // Given in any order, each name keeps its own index
        timeline.setLabel(30, 'c');
        timeline.setLabel(10, 'a');
        timeline.setLabel(20, 'b');

        check('labels: index of a', timeline.indexOfLabel('a') == 10);
        check('labels: index of b', timeline.indexOfLabel('b') == 20);
        check('labels: index of c', timeline.indexOfLabel('c') == 30);
        check('labels: label at 10', timeline.labelAtIndex(10) == 'a');
        check('labels: label at 30', timeline.labelAtIndex(30) == 'c');
        check('labels: sorted by index', timeline.labels.join(',') == 'a,b,c');

        // Moving a label keeps the others in place
        timeline.setLabel(5, 'c');
        check('labels: moved c', timeline.indexOfLabel('c') == 5);
        check('labels: a after the move', timeline.indexOfLabel('a') == 10);
        check('labels: sorted after the move', timeline.labels.join(',') == 'c,a,b');
        check('labels: label before 10', timeline.indexOfLabelBeforeIndex(10) == 5);

        timeline.destroy();

    }

    function timelineKeyframes():Void {

        final track = floatTrack([0, 10, 20], [0, 100, 200]);

        check('keyframes: before 5', track.findKeyframeBefore(5).index == 0);
        check('keyframes: before 10', track.findKeyframeBefore(10).index == 10);
        check('keyframes: after 5', track.findKeyframeAfter(5) != null && track.findKeyframeAfter(5).index == 10);
        check('keyframes: after 10', track.findKeyframeAfter(10) != null && track.findKeyframeAfter(10).index == 20);
        check('keyframes: after the last one', track.findKeyframeAfter(20) == null);
        check('keyframes: at 10', track.findKeyframeAtIndex(10) != null);
        check('keyframes: at 11', track.findKeyframeAtIndex(11) == null);

        track.seek(5);
        check('keyframes: value at 5', track.value == 50);
        track.seek(15);
        check('keyframes: value at 15', track.value == 150);

        track.destroy();

    }

    function timelineAnimate():Void {

        // Not looping: the last label ends when the timeline reaches its end
        var timeline = new Timeline();
        timeline.autoUpdate = false;
        timeline.loop = false;
        timeline.add(cast floatTrack([0, 20], [0, 1]));
        timeline.setLabel(0, 'a');
        timeline.setLabel(10, 'b');

        var completed = 0;
        var ended:Array<String> = [];
        timeline.onEndLabel(this, (index, name) -> ended.push(name));

        timeline.animate('a', () -> completed++);
        timeline.seek(5);
        check('animate: a still playing', completed == 0);
        timeline.seek(10);
        check('animate: a complete', completed == 1);

        timeline.animate('b', () -> completed++);
        timeline.seek(15);
        check('animate: b still playing', completed == 1);
        timeline.seek(20);
        check('animate: b (last label) complete', completed == 2);
        check('animate: labels ended', ended.join(',') == 'a,b');
        timeline.seek(20);
        check('animate: the end is reported once', ended.join(',') == 'a,b');
        timeline.destroy();

        // Looping: the last label ends when the timeline wraps
        timeline = new Timeline();
        timeline.autoUpdate = false;
        timeline.loop = true;
        timeline.add(cast floatTrack([0, 20], [0, 1]));
        timeline.setLabel(0, 'a');
        timeline.setLabel(10, 'b');
        completed = 0;
        timeline.animate('b', () -> completed++);
        timeline.seek(19);
        check('animate (loop): b still playing', completed == 0);
        timeline.seek(22);
        check('animate (loop): b complete after the wrap', completed == 1);
        check('animate (loop): wrapped position', timeline.position == 2);
        timeline.destroy();

    }

    function floatTrack(indexes:Array<Int>, values:Array<Float>):TimelineFloatTrack {

        final track = new TimelineFloatTrack();
        for (i in 0...indexes.length) {
            track.add(new TimelineFloatKeyframe(values[i], indexes[i], Easing.LINEAR));
        }
        return track;

    }

/// Fragment items

    static final QUAD_SCHEMA:Dynamic = {
        x: 'Float', y: 'Float', width: 'Float', height: 'Float', alpha: 'Float', depth: 'Float'
    };

    function fragmentItems():Void {

        var fragment = new Fragment();
        check('fragment: default assets', fragment.assets != null);
        fragment.destroy();

        fragment = new Fragment(App.app.assets);
        fragment.fragmentData = data('items', [
            { id: 'a', entity: 'ceramic.Quad', schema: QUAD_SCHEMA, props: { x: 10, width: 40, height: 20, alpha: 0.5 } },
            { id: 'b', entity: 'ceramic.Quad', schema: QUAD_SCHEMA, props: { x: 60 } }
        ]);

        final a:Quad = fragment.get('a', Quad);
        check('items: a created', a != null && a.x == 10 && a.width == 40 && a.alpha == 0.5);
        check('items: a added', a != null && a.parent == fragment);
        check('items: two items', fragment.items.length == 2 && fragment.entities.length == 2);

        // Same class: the instance is kept, the item is replaced
        fragment.fragmentData = data('items', [
            { id: 'a', entity: 'ceramic.Quad', schema: QUAD_SCHEMA, props: { x: 12, width: 40, height: 20 } },
            { id: 'b', entity: 'ceramic.Quad', schema: QUAD_SCHEMA, props: { x: 60 } }
        ]);
        check('items: instance kept', fragment.get('a') == a && a.x == 12);
        check('items: item replaced', fragment.getItem('a') != null && fragment.getItem('a').props.x == 12);
        check('items: removed prop back to its default', a.alpha == 1);
        check('items: still two items', fragment.items.length == 2 && fragment.entities.length == 2);

        // Another class: a new instance, still listed and displayed
        fragment.fragmentData = data('items', [
            { id: 'a', entity: 'ceramic.Visual', schema: QUAD_SCHEMA, props: { x: 14 } },
            { id: 'b', entity: 'ceramic.Quad', schema: QUAD_SCHEMA, props: { x: 60 } }
        ]);
        final a2 = fragment.get('a', Visual);
        check('items: class changed', a2 != null && (a2:Entity) != (a:Entity) && !Std.isOfType(a2, Quad) && a2.x == 14);
        check('items: previous instance destroyed', a.destroyed);
        check('items: new instance added', a2 != null && a2.parent == fragment);
        check('items: item of the new class listed', fragment.getItem('a') != null && fragment.getItem('a').entity == 'ceramic.Visual');
        check('items: two items after the class change', fragment.items.length == 2 && fragment.entities.length == 2);

        // An item that is not in the data anymore goes away
        fragment.fragmentData = data('items', [
            { id: 'b', entity: 'ceramic.Quad', schema: QUAD_SCHEMA, props: { x: 60 } }
        ]);
        check('items: a removed', fragment.get('a') == null && fragment.getItem('a') == null && fragment.items.length == 1);

        fragment.destroy();

    }

    function data(id:String, items:Array<Dynamic>):FragmentData {

        return {
            id: id,
            data: {},
            width: 320,
            height: 240,
            components: null,
            items: cast items
        };

    }

/// Easings and interpolation

    function easings():Void {

        check('easing: by name', EasingUtils.easingFromString('QUAD_EASE_IN') == QUAD_EASE_IN);
        check('easing: none by default', EasingUtils.easingFromString(null) == NONE && EasingUtils.easingFromString('') == NONE);

        final bezier = EasingUtils.easingFromString('BEZIER(0.25, 0.1,0.25,1)');
        check('easing: bezier', switch bezier {
            case BEZIER(x1, y1, x2, y2): x1 == 0.25 && y1 == 0.1 && x2 == 0.25 && y2 == 1;
            case _: false;
        });
        check('easing: bezier to string', EasingUtils.easingToString(bezier) == 'BEZIER(0.25,0.1,0.25,1)');
        check('easing: name to string', EasingUtils.easingToString(BOUNCE_EASE_OUT) == 'BOUNCE_EASE_OUT');

        var thrown = false;
        try {
            EasingUtils.easingFromString('BEZIER(1,2)');
        }
        catch (e:Dynamic) {
            thrown = true;
        }
        check('easing: invalid bezier', thrown);

    }

    function interpolation():Void {

        final half = TimelineInterpolation.ratio(5, 0, 10);
        check('interpolation: ratio', half == 0.5 && TimelineInterpolation.ratio(12, 0, 10) == 1 && TimelineInterpolation.ratio(-1, 0, 10) == 0);
        check('interpolation: float', TimelineInterpolation.float(0, 100, LINEAR, half) == 50);
        check('interpolation: float eased', TimelineInterpolation.float(0, 100, QUAD_EASE_IN, half) == 25);
        check('interpolation: degrees take the shortest path', TimelineInterpolation.degrees(350, 10, LINEAR, half) == 0);
        check('interpolation: degrees', TimelineInterpolation.degrees(10, 50, LINEAR, half) == 30);
        check('interpolation: bool', TimelineInterpolation.bool(false, true, half) == false && TimelineInterpolation.bool(false, true, 1) == true);
        check('interpolation: color', TimelineInterpolation.color(Color.BLACK, Color.WHITE, LINEAR, half) == Color.interpolate(Color.BLACK, Color.WHITE, 0.5));

        final result:Array<Float> = [];
        check('interpolation: array changed', TimelineInterpolation.floatArray(result, [0, 10, 20], [10, 20], LINEAR, half));
        check('interpolation: array', result.length == 2 && result[0] == 5 && result[1] == 15);
        check('interpolation: array unchanged', !TimelineInterpolation.floatArray(result, [0, 10, 20], [10, 20], LINEAR, half));

        // A track gives the same values
        final track = floatTrack([0, 10], [0, 100]);
        track.keyframes[1].easing = QUAD_EASE_IN;
        track.seek(5);
        check('interpolation: same as a track', track.value == TimelineInterpolation.float(0, 100, QUAD_EASE_IN, half));
        track.destroy();

    }

/// Schema, tracks and labels

    static final SCHEMA:Dynamic = {
        'ceramic.Quad': {
            x: 'Float', y: 'Float', width: 'Float', height: 'Float', alpha: 'Float', rotation: 'Float', visible: 'Bool', color: 'ceramic.Color',
            blending: 'ceramic.Blending'
        },
        'ceramic.Visual': {
            x: 'Float', y: 'Float', width: 'Float', height: 'Float'
        },
        'ceramic.Fragment': {
            x: 'Float', y: 'Float', fragmentData: 'ceramic.FragmentData'
        }
    };

    function schemaAndTracks():Void {

        final fragment = new Fragment();
        fragment.autoUpdateTimeline = false;

        var d = data('anim', [
            { id: 'q', entity: 'ceramic.Quad', props: { x: 0, width: 10, height: 10, color: 0xFF0000 } }
        ]);
        d.schema = SCHEMA;
        d.fps = 60;
        d.tracks = [
            track('q', 'x', [0, 10], [0, 100], ['LINEAR', 'LINEAR']),
            track('q', 'alpha', [0, 10], [0, 1], ['LINEAR', 'BEZIER(0,0,1,1)']),
            track('q', 'visible', [0, 5], [false, true], ['NONE', 'NONE']),
            track('q', 'rotation', [0, 10], [350, 10], ['LINEAR', 'LINEAR'], { degrees: true })
        ];
        d.labels = cast { start: 0, end: 10 };
        fragment.fragmentData = d;

        final q = fragment.get('q', Quad);
        check('schema: item created', q != null && q.width == 10 && q.color == Color.RED);

        // A blending is written by its name, in any case, or by its number
        check('blending: auto by default', q != null && q.blending == Blending.AUTO);
        check('blending: names', Blending.ADD.toString() == 'ADD' && Blending.fromString('MULTIPLY') == Blending.MULTIPLY);
        final blended = new Fragment();
        var b = data('blended', [
            { id: 'byName', entity: 'ceramic.Quad', props: { width: 10, height: 10, blending: 'ADD' } },
            { id: 'lower', entity: 'ceramic.Quad', props: { width: 10, height: 10, blending: 'screen' } },
            { id: 'byNumber', entity: 'ceramic.Quad', props: { width: 10, height: 10, blending: 8 } },
            { id: 'unknown', entity: 'ceramic.Quad', props: { width: 10, height: 10, blending: 'NOPE' } }
        ]);
        b.schema = SCHEMA;
        blended.fragmentData = b;
        check('blending: by name', blended.get('byName', Quad) != null && blended.get('byName', Quad).blending == Blending.ADD);
        check('blending: name in lower case', blended.get('lower', Quad) != null && blended.get('lower', Quad).blending == Blending.SCREEN);
        check('blending: by number', blended.get('byNumber', Quad) != null && blended.get('byNumber', Quad).blending == Blending.MULTIPLY);
        check('blending: unknown name is auto', blended.get('unknown', Quad) != null && blended.get('unknown', Quad).blending == Blending.AUTO);
        blended.destroy();
        check('tracks: created', fragment.timeline != null && fragment.timeline.tracks.length == 4);
        check('tracks: fps', fragment.fps == 60 && fragment.timeline.fps == 60);
        check('tracks: labels', fragment.indexOfLabel('end') == 10 && fragment.indexOfLabel('start') == 0);

        fragment.timeline.seek(5);
        check('tracks: float at 5', q.x == 50);
        check('tracks: bezier at 5', Math.abs(q.alpha - 0.5) < 0.01);
        check('tracks: bool at 5', q.visible == true);
        check('tracks: degrees at 5', q.rotation == 0);
        fragment.timeline.seek(2);
        check('tracks: bool at 2', q.visible == false);

        // One track and one label less, a keyframe moved
        d = data('anim', [
            { id: 'q', entity: 'ceramic.Quad', props: { x: 0, width: 10, height: 10 } }
        ]);
        d.schema = SCHEMA;
        d.tracks = [
            track('q', 'x', [0, 20], [0, 100], ['LINEAR', 'LINEAR']),
            track('q', 'alpha', [], [], [])
        ];
        d.labels = cast { start: 0 };
        fragment.fragmentData = d;
        check('tracks: unused ones removed', fragment.timeline.tracks.length == 1 && fragment.tracks.length == 2);
        check('tracks: unused label removed', fragment.indexOfLabel('end') == -1 && fragment.indexOfLabel('start') == 0);
        check('tracks: size follows the keyframes', fragment.timeline.size == 20);
        fragment.timeline.seek(10);
        check('tracks: updated keyframes', q.x == 50);

        // No track and no label at all
        d = data('anim', [
            { id: 'q', entity: 'ceramic.Quad', props: { x: 0, width: 10, height: 10 } }
        ]);
        d.schema = SCHEMA;
        fragment.fragmentData = d;
        check('tracks: all removed', fragment.timeline.tracks.length == 0 && fragment.tracks.length == 0);
        check('tracks: labels all removed', fragment.timeline.labels.length == 0);

        fragment.destroy();

    }

    function track(entity:String, field:String, indexes:Array<Int>, values:Array<Dynamic>, easings:Array<String>, ?options:Dynamic):Dynamic {

        return {
            loop: false,
            entity: entity,
            field: field,
            options: options,
            keyframes: [for (i in 0...indexes.length) { index: indexes[i], easing: easings[i], value: values[i] }]
        };

    }

/// Parents

    function parents():Void {

        final fragment = new Fragment();

        // A child can be listed before its parent
        var d = data('parents', [
            { id: 'grandchild', entity: 'ceramic.Quad', parent: 'child', props: { x: 1 } },
            { id: 'child', entity: 'ceramic.Quad', parent: 'box', props: { x: 2 } },
            { id: 'box', entity: 'ceramic.Quad', props: { x: 3 } },
            { id: 'alone', entity: 'ceramic.Quad', parent: 'missing', props: { x: 4 } }
        ]);
        d.schema = SCHEMA;
        fragment.fragmentData = d;

        final box = fragment.get('box', Quad);
        final child = fragment.get('child', Quad);
        final grandchild = fragment.get('grandchild', Quad);
        check('parents: box in the fragment', box.parent == fragment);
        check('parents: child in box', child.parent == box);
        check('parents: grandchild in child', grandchild.parent == child);
        check('parents: unknown parent', fragment.get('alone', Quad).parent == fragment);

        // Moved to the fragment, then back
        d = data('parents', [
            { id: 'grandchild', entity: 'ceramic.Quad', parent: 'child', props: { x: 1 } },
            { id: 'child', entity: 'ceramic.Quad', props: { x: 2 } },
            { id: 'box', entity: 'ceramic.Quad', props: { x: 3 } }
        ]);
        d.schema = SCHEMA;
        fragment.fragmentData = d;
        check('parents: child moved to the fragment', child.parent == fragment && fragment.get('child') == child);
        check('parents: grandchild followed', grandchild.parent == child);

        d = data('parents', [
            { id: 'grandchild', entity: 'ceramic.Quad', parent: 'child', props: { x: 1 } },
            { id: 'child', entity: 'ceramic.Quad', parent: 'box', props: { x: 2 } },
            { id: 'box', entity: 'ceramic.Quad', props: { x: 3 } }
        ]);
        d.schema = SCHEMA;
        fragment.fragmentData = d;
        check('parents: child back in box', child.parent == box);

        // The class of the parent changes: its children go to the new instance
        d = data('parents', [
            { id: 'grandchild', entity: 'ceramic.Quad', parent: 'child', props: { x: 1 } },
            { id: 'child', entity: 'ceramic.Quad', parent: 'box', props: { x: 2 } },
            { id: 'box', entity: 'ceramic.Visual', props: { x: 3 } }
        ]);
        d.schema = SCHEMA;
        fragment.fragmentData = d;
        final box2 = fragment.get('box', Visual);
        check('parents: parent replaced', box.destroyed && box2 != null && !box2.destroyed);
        check('parents: child kept by the new parent', !child.destroyed && child.parent == box2 && fragment.get('child') == child);

        // The parent goes away, the child stays
        d = data('parents', [
            { id: 'grandchild', entity: 'ceramic.Quad', parent: 'child', props: { x: 1 } },
            { id: 'child', entity: 'ceramic.Quad', parent: 'box', props: { x: 2 } }
        ]);
        d.schema = SCHEMA;
        fragment.fragmentData = d;
        check('parents: parent removed', box2.destroyed && fragment.get('box') == null);
        check('parents: child survives its parent', !child.destroyed && child.parent == fragment && !grandchild.destroyed);

        // A loop is refused
        d = data('parents', [
            { id: 'a', entity: 'ceramic.Quad', parent: 'b', props: { x: 1 } },
            { id: 'b', entity: 'ceramic.Quad', parent: 'a', props: { x: 2 } }
        ]);
        d.schema = SCHEMA;
        fragment.fragmentData = d;
        final a = fragment.get('a', Quad);
        final b = fragment.get('b', Quad);
        check('parents: no loop', a != null && b != null && (a.parent == fragment || b.parent == fragment));

        // Removing an item by hand removes what is inside
        d = data('parents', [
            { id: 'box', entity: 'ceramic.Quad', props: { x: 3 } },
            { id: 'child', entity: 'ceramic.Quad', parent: 'box', props: { x: 2 } },
            { id: 'grandchild', entity: 'ceramic.Quad', parent: 'child', props: { x: 1 } },
            { id: 'other', entity: 'ceramic.Quad', props: { x: 1 } }
        ]);
        d.schema = SCHEMA;
        fragment.fragmentData = d;
        fragment.removeItem('box');
        check('parents: removeItem takes the children', fragment.items.length == 1 && fragment.entities.length == 1 && fragment.get('other') != null);

        fragment.destroy();

    }

/// Fragments inside fragments

    function nestedFragments():Void {

        var card = data('cached-card', [
            { id: 'back', entity: 'ceramic.Quad', props: { width: 60, height: 80 } }
        ]);
        card.schema = SCHEMA;
        card.width = 60;
        card.height = 80;
        Fragment.cacheData(card);

        final fragment = new Fragment();
        var d = data('outer', [
            { id: 'byId', entity: 'ceramic.Fragment', props: { x: 5, fragmentData: 'cached-card' } },
            { id: 'inline', entity: 'ceramic.Fragment', props: { x: 70, fragmentData: card } },
            { id: 'unknown', entity: 'ceramic.Fragment', props: { fragmentData: 'nope' } }
        ]);
        d.schema = SCHEMA;
        fragment.fragmentData = d;

        final byId = fragment.get('byId', Fragment);
        final inlined = fragment.get('inline', Fragment);
        check('nested: by id', byId != null && byId.fragmentData == card && byId.get('back') != null && byId.width == 60 && byId.x == 5);
        check('nested: inline data', inlined != null && inlined.fragmentData == card && inlined.get('back') != null);
        check('nested: unknown id', fragment.get('unknown', Fragment) != null && fragment.get('unknown', Fragment).fragmentData == null);
        check('nested: ready', fragment.ready);

        // The reference goes away
        d = data('outer', [
            { id: 'byId', entity: 'ceramic.Fragment', props: { x: 5 } }
        ]);
        d.schema = SCHEMA;
        fragment.fragmentData = d;
        check('nested: emptied', fragment.get('byId') == byId && byId.fragmentData == null && byId.entities.length == 0);
        fragment.destroy();

        // A fragment that contains itself (directly or not) stops there
        var first = data('first', [
            { id: 'second', entity: 'ceramic.Fragment', props: { fragmentData: 'second' } }
        ]);
        first.schema = SCHEMA;
        var second = data('second', [
            { id: 'first', entity: 'ceramic.Fragment', props: { fragmentData: 'first' } }
        ]);
        second.schema = SCHEMA;
        Fragment.cacheData(first);
        Fragment.cacheData(second);
        final looping = new Fragment();
        looping.fragmentData = first;
        final inner = looping.get('second', Fragment);
        check('nested: no endless nesting', inner != null && inner.fragmentData == second && inner.get('first', Fragment).fragmentData == null);
        looping.destroy();

    }

/// Following a fragments asset

    function assetReload():Void {

        var menu = data('menu', [
            { id: 'button', entity: 'ceramic.Quad', props: { x: 10, width: 80, height: 30 } },
            { id: 'card', entity: 'ceramic.Fragment', props: { fragmentData: 'card' } }
        ]);
        menu.schema = SCHEMA;
        var card = data('card', [
            { id: 'back', entity: 'ceramic.Quad', props: { width: 60 } }
        ]);
        card.schema = SCHEMA;

        // A fragment with the same id in the cache: the asset comes first
        var cachedCard = data('card', []);
        Fragment.cacheData(cachedCard);

        final asset = new FragmentsAsset('reload');
        final fragment = new Fragment();
        fragment.loadFromAsset(asset, 'menu');
        check('asset: nothing before the asset is loaded', fragment.fragmentData == null && fragment.fragmentsAsset == asset);

        asset.fragments = cast { menu: menu, card: card };
        final button = fragment.get('button', Quad);
        final nested = fragment.get('card', Fragment);
        check('asset: loaded', fragment.fragmentData == menu && button != null && button.x == 10);
        check('asset: nested fragment from the same asset', nested != null && nested.fragmentData == card && nested.get('back', Quad).width == 60);

        var clicks = 0;
        button.onPointerDown(this, _ -> clicks++);

        // The file changes
        var menu2 = data('menu', [
            { id: 'button', entity: 'ceramic.Quad', props: { x: 40, width: 80, height: 30 } },
            { id: 'title', entity: 'ceramic.Quad', props: { x: 0 } },
            { id: 'card', entity: 'ceramic.Fragment', props: { fragmentData: 'card' } }
        ]);
        menu2.schema = SCHEMA;
        var card2 = data('card', [
            { id: 'back', entity: 'ceramic.Quad', props: { width: 90 } }
        ]);
        card2.schema = SCHEMA;
        asset.fragments = cast { menu: menu2, card: card2 };

        check('asset: reloaded', fragment.fragmentData == menu2 && fragment.get('title') != null);
        check('asset: instance kept', fragment.get('button') == button && button.x == 40);
        check('asset: nested fragment reloaded', fragment.get('card') == nested && nested.get('back', Quad).width == 90);
        @:privateAccess button.emitPointerDown(null);
        check('asset: listeners kept', clicks == 1);

        // The fragment is not in the file anymore: what is displayed stays
        asset.fragments = cast { card: card2 };
        check('asset: kept when missing', fragment.fragmentData == menu2 && fragment.get('button') == button);

        asset.destroy();
        check('asset: kept when the asset is destroyed', fragment.fragmentData == menu2 && fragment.fragmentsAsset == null);

        fragment.destroy();

    }

/// Scene

    function sceneChecks(scene:CheckScene):Void {

        final menu = scene.menu;
        check('scene: preloaded fragment', menu != null && menu.ready && menu.parent == scene && menu.active);
        if (menu == null) return;

        check('scene: fragment id from its key', menu.fragmentData.id == 'menu');
        check('scene: was ready in create()', scene.menuWasReady);
        final panel = menu.get('panel', Quad);
        final button = menu.get('button', Quad);
        check('scene: items', panel != null && panel.width == 200 && button != null && button.parent == panel);
        final card = menu.get('card', Fragment);
        check('scene: nested fragment by id', card != null && card.fragmentData != null && card.fragmentData.id == 'card' && card.get('back') != null);
        check('scene: track', menu.timeline != null && menu.timeline.tracks.length == 1 && menu.indexOfLabel('in') == 0);

        check('scene: fragment loaded without preload', scene.card != null && scene.card.parent == scene && scene.card.get('back') != null);
        check('scene: unknown fragments asset', scene.missing == null);

    }

/// Checks

    function check(name:String, ok:Bool):Void {

        checks++;
        if (!ok) fail(name);

    }

    function fail(name:String):Void {

        failures++;
        App.app.logger.error('FAILED $name');

    }

    function finish():Void {

        App.app.logger.info('fragments: $checks checks, $failures failed');
        #if (headless && nodejs)
        js.Node.process.exit(failures == 0 ? 0 : 1);
        #end

    }

}
