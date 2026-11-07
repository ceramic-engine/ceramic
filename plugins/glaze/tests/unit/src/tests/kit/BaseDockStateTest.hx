// Ported from gpui-kit 0.8.1: crates/base/src/dock/state.rs (tests), crates/base/src/dock/state_convert.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#else
import gpui.Axis;
import gpui.Pixels;
import gpui.base.dock.DockAreaState;
import gpui.base.dock.DockPlacement;
import gpui.base.dock.JsonValue;
import gpui.base.dock.PaneNode;
import gpui.base.dock.PaneTree;
import gpui.base.dock.PanelBuilder;
import gpui.base.dock.PanelId;
import gpui.base.dock.PanelInfo;
import gpui.base.dock.PanelSource;
import gpui.base.dock.PanelState;
import gpui.base.dock.RootKind;
import testing.TestCase;

using gpui.base.dock.JsonValue.JsonValueTools;
using gpui.base.dock.PanelInfo.PanelInfoTools;
#end

/**
 * The `#[cfg(test)]` tests of gpui-base's dock persistence: `state.rs` and
 * `state_convert.rs`, plus the JSON format checks of the port (serde_json's
 * output for the same values, measured on serde_json 1.0.151).
 *
 * The fixtures are gpui-kit's `crates/base/src/dock/fixtures/*.json`,
 * copied unmodified to `test/unit/data/dock/`.
 */
#if !macro
@:access(gpui.base.dock.PaneTree)
#end
class BaseDockStateTest #if !macro extends TestCase #end {

    #if !macro

    static function fixture(name:String):String {
        return fixtures().get(name);
    }

    static var cachedFixtures:Null<Map<String, String>> = null;

    static function fixtures():Map<String, String> {
        if (cachedFixtures == null) {
            cachedFixtures = new Map();
            final files:Dynamic = haxe.Json.parse(fixturesJson());
            for (name in Reflect.fields(files)) cachedFixtures.set(name, Reflect.field(files, name));
        }
        return cachedFixtures;
    }

    static function sizes(info:PanelInfo):String {
        return switch info {
            case Stack(sizes, _): [for (size in sizes) JsonValueTools.formatF32(size)].join(',');
            case _: throw 'expected Stack info';
        }
    }

/// state.rs

    /**
     * The whole of a real user's file, not just its outline: every dock and
     * the nesting under each one.
     */
    function testTheShippedFixtureStillDeserializes() {
        final state = DockAreaState.fromJson(fixture('layout.json'));

        assertNull(state.version);
        assertEquals('StackPanel', state.center.panelName);
        assertEquals(2, state.center.children.length);
        assertEquals('TabPanel', state.center.children[0].panelName);
        assertEquals('TabPanel', state.center.children[1].panelName);
        assertEquals(1, state.center.children[1].children.length);
        assertEquals('StoryContainer', state.center.children[1].children[0].panelName);

        final left = state.leftDock;
        assertEquals(true, left.open());
        assertEquals(350., (left.size() : Float));
        assertEquals(DockPlacement.Left, left.placement());
        assertEquals('TabPanel', left.panel().panelName);
        assertEquals(1, left.panel().children.length);
        assertEquals('StoryContainer', left.panel().children[0].panelName);

        final bottom = state.bottomDock;
        assertEquals(true, bottom.open());
        assertEquals(200., (bottom.size() : Float));
        assertEquals(DockPlacement.Bottom, bottom.placement());
        assertEquals('TabPanel', bottom.panel().panelName);
        assertEquals(2, bottom.panel().children.length);
        assertEquals('StoryContainer', bottom.panel().children[0].panelName);

        final right = state.rightDock;
        assertEquals(true, right.open());
        assertEquals(320., (right.size() : Float));
        assertEquals(DockPlacement.Right, right.placement());
        assertEquals('TabPanel', right.panel().panelName);
        assertEquals(1, right.panel().children.length);
        assertEquals('StoryContainer', right.panel().children[0].panelName);
    }

    function testTheSerdeTagsAreFrozen() {
        final stack = PanelInfoTools.stack([1.], Axis.Vertical).toJsonValue();
        assertTrue(stack.equals(JsonValueTools.parse('{"stack": {"sizes": [1.0], "axis": 1}}')));

        final tabs = PanelInfoTools.tabs(2).toJsonValue();
        assertTrue(tabs.equals(JsonValueTools.parse('{"tabs": {"active_index": 2}}')));

        assertEquals('bottom', DockPlacement.Bottom.serdeName());
    }

    function testOptionalDocksAreOmittedNotNulled() {
        final json = DockAreaState.defaultValue().toJsonValue();
        switch json {
            case JObject(object):
                assertFalse(object.exists('left_dock'));
                assertFalse(object.exists('right_dock'));
                assertFalse(object.exists('bottom_dock'));
            case _:
                fail('expected an object');
        }
    }

/// state_convert.rs

    function testASplitSerializesAsAStackPanel() {
        final tree = new PaneTree(RootKind.Split);
        tree.pushTabsForTest(tree.root().id(), [PanelId.fromU64(1)]);
        tree.pushTabsForTest(tree.root().id(), [PanelId.fromU64(2)]);
        tree.normalize();

        final source = new FakePanels([{id: PanelId.fromU64(1), name: 'Alpha'}, {id: PanelId.fromU64(2), name: 'Beta'}]);
        final state = tree.toState(source);

        assertEquals('StackPanel', state.panelName);
        // Both slots were pushed with no explicit size, so both serialize as
        // the zero sentinel.
        assertEquals('0.0,0.0', sizes(state.info));
        assertEquals('TabPanel', state.children[0].panelName);
        assertEquals('Alpha', state.children[0].children[0].panelName);
    }

    function testAnUnresolvedSlotSizeSerializesAsTheZeroSentinel() {
        final tree = new PaneTree(RootKind.Split);
        final root = tree.root().id();
        tree.pushSizedTabsForTest(root, [PanelId.fromU64(1)], 120.);
        tree.pushSizedTabsForTest(root, [PanelId.fromU64(2)], null);
        tree.normalize();

        final source = new FakePanels([{id: PanelId.fromU64(1), name: 'Alpha'}, {id: PanelId.fromU64(2), name: 'Beta'}]);
        final state = tree.toState(source);

        // The concrete slot keeps its value; only the unresolved one is
        // written as the `0.0` sentinel.
        assertEquals('120.0,0.0', sizes(state.info));
    }

    function testAnEmptyTabGroupSerializesAsTabsNotAsAPanel() {
        final tree = new PaneTree(RootKind.Any);
        tree.setRootTabsForTest([], 0);

        final state = tree.toState(new FakePanels([]));

        assertEquals('TabPanel', state.panelName);
        assertTrue(state.info.equals(PanelInfo.Tabs(0)), 'the old writer emitted PanelInfo::Panel here, which failed to restore');
    }

    function testAnEmptyCenterStillSerializesAsAStackPanel() {
        final tree = new PaneTree(RootKind.Split);
        final state = tree.toState(new FakePanels([]));
        assertEquals('StackPanel', state.panelName);
        assertTrue(state.info.match(Stack(_, _)));
    }

    static function tabsState(children:Array<PanelState>, activeIndex:Int):PanelState {
        return new PanelState(PaneTree.TAB_PANEL_NAME, children, PanelInfoTools.tabs(activeIndex));
    }

    static function panelState(name:String):PanelState {
        return new PanelState(name, [], PanelInfoTools.panel(JNull));
    }

    function testNestedTabGroupsAreFlattened() {
        final state = tabsState([tabsState([panelState('Alpha')], 0), tabsState([panelState('Beta')], 0)], 1);

        final builder = new RecordingBuilder();
        final tree = PaneTree.fromState(state, RootKind.Any, builder);

        assertEquals('Alpha,Beta', builder.built.join(','));
        switch tree.root().kind() {
            case Tabs(panels, activeIx):
                assertEquals(2, panels.length);
                assertEquals(1, activeIx);
            case _:
                fail('expected a tab group');
        }
    }

    function testABarePanelLeafIsWrappedInATabGroup() {
        final builder = new RecordingBuilder();
        final tree = PaneTree.fromState(panelState('Alpha'), RootKind.Any, builder);

        assertTrue(switch tree.root().kind() {
            case Tabs(panels, _): panels.length == 1;
            case _: false;
        });
    }

    function testATabPanelCarryingPanelInfoIsReadAsAnEmptyGroup() {
        // What the old `TabPanel::dump` wrote for an empty tab group.
        final state = new PanelState(PaneTree.TAB_PANEL_NAME, [], PanelInfoTools.panel(JNull));

        final builder = new RecordingBuilder();
        final tree = PaneTree.fromState(state, RootKind.Any, builder);

        assertEquals(0, builder.built.length, 'no panel is built for the phantom leaf');
        assertTrue(switch tree.root().kind() {
            case Tabs(panels, _): panels.length == 0;
            case _: false;
        });
    }

    function testASplitRootIsForcedEvenWhenTheStateIsATabGroup() {
        final state = tabsState([panelState('Alpha')], 0);
        final builder = new RecordingBuilder();
        final tree = PaneTree.fromState(state, RootKind.Split, builder);

        assertTrue(tree.root().kind().match(Split(_, _, _)));
    }

    static function canonicalize(json:String):PanelState {
        final state = DockAreaState.fromJson(json);
        final panels = new PreservingPanels();
        final tree = PaneTree.fromState(state.center, RootKind.Split, panels);
        return tree.toState(panels);
    }

    function testCanonicalizationReachesAFixpointInOnePass() {
        for (name in ['layout.json', 'nested_splits.json', 'legacy_empty_tab_group.json', 'unregistered_panel.json',
            'zero_size_sentinel.json', 'legacy_empty_stack_panel.json', 'placeholder_wrapped_empty_stack.json']) {
            final once = canonicalize(fixture(name));
            final wrapped = new DockAreaState(null, once.clone());
            final twice = canonicalize(wrapped.toJson());
            assertTrue(once.equals(twice), 'r(r(x)) != r(x) for $name');
        }
    }

    function testAnUnregisteredPanelKeepsItsPayloadThroughARoundTrip() {
        final state = canonicalize(fixture('unregistered_panel.json'));
        final leaf = state.children[0].children[0];

        assertEquals('PanelFromTheFuture', leaf.panelName);
        assertTrue(leaf.info.equals(PanelInfoTools.panel(JsonValueTools.parse('{"keep": "me"}'))));
    }

    function testTheLegacyEmptyTabGroupIsRewrittenIntoTheTabsForm() {
        final state = canonicalize(fixture('legacy_empty_tab_group.json'));

        // The empty group collapses, leaving the mandatory split root.
        assertEquals('StackPanel', state.panelName);
        assertEquals(0, state.children.length);
    }

    function testTheLegacyEmptyStackPanelIsReadAsAnEmptySplit() {
        final state = DockAreaState.fromJson(fixture('legacy_empty_stack_panel.json'));
        final panels = new PreservingPanels();
        final tree = PaneTree.fromState(state.center, RootKind.Split, panels);

        assertEquals(0, panels.states.length, 'no placeholder is built for it');
        final dumped = tree.toState(panels);
        assertEquals('StackPanel', dumped.panelName);
        assertTrue(dumped.info.match(Stack(_, _)));
        assertEquals(0, dumped.children.length);
    }

    /**
     * The shape a reader without the rule above saved back: the placeholder
     * it built sat in a tab group and dumped the defective state unchanged.
     */
    function testAnEmptyStackPanelSavedInsideATabGroupIsDropped() {
        final state = canonicalize(fixture('placeholder_wrapped_empty_stack.json'));
        final group = state.children[0];

        assertEquals('TabPanel', group.panelName);
        assertTrue(group.info.equals(PanelInfoTools.tabs(0)));
        assertEquals('Alpha', [for (child in group.children) child.panelName].join(','));
    }

    function testNestedSameAxisSplitsAreFlattenedAndSingleChildSplitsCollapse() {
        final state = canonicalize(fixture('nested_splits.json'));

        assertEquals('StackPanel', state.panelName);
        assertEquals(3, state.children.length,
            'the horizontal inner split splices in and the vertical single-child split collapses');
        for (child in state.children) assertEquals('TabPanel', child.panelName);
        assertEquals('Alpha', state.children[0].children[0].panelName);
        assertEquals('Beta', state.children[1].children[0].panelName);
        assertEquals('Gamma', state.children[2].children[0].panelName);

        // 50 + 150 = 200 inside a 400 slot: a genuine 2x scale. The vertical
        // single-child split's own inner size (300) is discarded; its outer
        // slot (300) is what the surviving child inherits.
        assertEquals('100.0,300.0,300.0', sizes(state.info));
    }

    function testATreeSurvivesARoundTripExactly() {
        final state = DockAreaState.fromJson(fixture('nested_splits.json'));
        final panels = new PreservingPanels();
        final tree = PaneTree.fromState(state.center, RootKind.Split, panels);

        final dumped = tree.toState(panels);
        final rebuiltPanels = new PreservingPanels();
        final rebuilt = PaneTree.fromState(dumped, RootKind.Split, rebuiltPanels);

        assertTrue(tree.toState(panels).equals(rebuilt.toState(rebuiltPanels)), 'load(dump(t)) must describe the same layout as t');
    }

    /**
     * Pins the one value in the schema that means something different now
     * than it ever did before: a literal `0.0` slot size next to a genuine
     * `200.0` sibling.
     */
    function testAZeroSizeSlotRoundTripsThroughTheNoneSentinel() {
        final state = DockAreaState.fromJson(fixture('zero_size_sentinel.json'));
        final panels = new PreservingPanels();
        final tree = PaneTree.fromState(state.center, RootKind.Split, panels);

        switch tree.root().kind() {
            case Split(_, _, sizes):
                assertNull(sizes[0], 'the 0.0 sentinel reads back as null, not as a real zero-width panel');
                assertEquals(200., (sizes[1] : Float));
            case _:
                fail('expected the root to stay a split');
        }

        final dumped = tree.toState(panels);
        assertEquals('0.0,200.0', sizes(dumped.info), 'the unconstrained slot writes back out as the 0.0 sentinel');
    }

    /**
     * Pins that a bare `TabPanel` root (the shape every dock of the shipped
     * fixture stores) survives a round trip under `RootKind.Any` as a `Tabs`
     * node, with its one panel intact.
     */
    function testABareTabPanelRootIsNotWrappedUnderRootKindAny() {
        final state = PanelState.fromJson(fixture('bare_tab_panel_root.json'));
        final panels = new PreservingPanels();
        final tree = PaneTree.fromState(state, RootKind.Any, panels);

        assertTrue(tree.root().kind().match(Tabs(_, _)),
            'a bare TabPanel root must stay a Tabs node under RootKind.Any, not get wrapped in a synthetic split');

        final dumped = tree.toState(panels);
        assertEquals('TabPanel', dumped.panelName);
    }

/// JSON format of the port (serde_json 1.0.151 outputs)

    function testF32NumbersAreWrittenLikeSerde() {
        final cases:Array<{value:Float, json:String}> = [
            {value: 0., json: '0.0'},
            {value: 1., json: '1.0'},
            {value: 350., json: '350.0'},
            {value: 0.1, json: '0.1'},
            {value: 1. / 3., json: '0.33333334'},
            {value: 233.33333, json: '233.33333'},
            {value: gpui.SpringMath.f32(gpui.SpringMath.f32(2. / 3.) * 700.), json: '466.6667'},
            {value: 1e-6, json: '0.000001'},
            {value: 1e-7, json: '1e-7'},
            {value: 1.5e-7, json: '1.5e-7'},
            {value: 123456789., json: '123456790.0'},
            {value: 1e12, json: '1000000000000.0'},
            {value: 1e13, json: '1e+13'},
            {value: 1.5e13, json: '1.5e+13'},
            {value: 3.4028235e38, json: '3.4028235e+38'},
            {value: -2.5, json: '-2.5'},
            {value: 100.25, json: '100.25'},
            {value: 0.000123, json: '0.000123'},
            {value: 1234567., json: '1234567.0'},
            {value: 0.3, json: '0.3'},
            {value: 16777216., json: '16777216.0'},
        ];
        for (c in cases) assertEquals(c.json, JsonValueTools.formatF32(c.value));
    }

    function testJsonValuesRoundTripLikeSerde() {
        final value = JsonValueTools.parse('{"b":1,"a":[1.0,2.50,-0,1e2,12345678901234,0.1],"c":{"z":null,"y":true}}');
        assertEquals('{"b":1,"a":[1.0,2.5,-0.0,100.0,12345678901234,0.1],"c":{"z":null,"y":true}}', value.stringify());
        assertEquals('{\n  "b": 1,\n  "a": [\n    1.0,\n    2.5,\n    -0.0,\n    100.0,\n    12345678901234,\n    0.1\n  ],\n  "c": {\n    "z": null,\n    "y": true\n  }\n}',
            value.stringifyPretty());
        assertEquals('{\n  "a": [],\n  "b": {}\n}', JsonValueTools.parse('{"a":[],"b":{}}').stringifyPretty());
        assertEquals('"a\\"b\\\\c/d\\n\\t\\r\\b\\f\\u0001\\u001fé"', JString('a"b\\c/d\n\t\r\x08\x0c\x01\x1fé').stringify());
        assertEquals('é😀', switch JsonValueTools.parse('"\\u00e9\\ud83d\\ude00"') {
            case JString(s): s;
            case _: '';
        });
        // An integer never equals a float in serde_json.
        assertFalse(JsonValueTools.parse('1').equals(JsonValueTools.parse('1.0')));
        assertTrue(JsonValueTools.parse('{"a":1,"b":2}').equals(JsonValueTools.parse('{"b":2,"a":1}')));
    }

    function testInvalidStatesAreRejectedLikeSerde() {
        // A float where serde wants `usize`, a missing required field, an
        // unknown variant, trailing characters.
        assertRaises(() -> DockAreaState.fromJson('{"center":{"panel_name":"TabPanel","children":[],"info":{"tabs":{"active_index":1.0}}}}'));
        assertRaises(() -> DockAreaState.fromJson('{"center":{"panel_name":"TabPanel","children":[]}}'));
        assertRaises(() -> DockAreaState.fromJson('{"center":{"panel_name":"X","children":[],"info":{"leaf":null}}}'));
        assertRaises(() -> DockAreaState.fromJson('{"center":{"panel_name":"X","children":[],"info":{"panel":null}}} x'));
        // Integers are fine for `f32` fields, and unknown fields are ignored
        // (the shipped fixture carries `resizeable`).
        final state = DockAreaState.fromJson('{"version":2,"center":{"panel_name":"StackPanel","children":[],"info":{"stack":{"sizes":[],"axis":0}}},'
            + '"left_dock":{"panel":{"panel_name":"TabPanel","children":[],"info":{"tabs":{"active_index":0}}},"placement":"left","size":240,"open":false,"x":1}}');
        assertEquals(2, state.version);
        assertEquals(240., (state.leftDock.size() : Float));
        assertEquals('{"version":2,"center":{"panel_name":"StackPanel","children":[],"info":{"stack":{"sizes":[],"axis":0}}},'
            + '"left_dock":{"panel":{"panel_name":"TabPanel","children":[],"info":{"tabs":{"active_index":0}}},"placement":"left","size":240.0,"open":false}}',
            state.toJson());
    }

    /**
     * The `DockArea::dump` JSON written by the original during the
     * `kit-dock-base-script` reference run (`reference_dumps.json`, taken from
     * its truth): the port reads every one and writes it back byte for byte.
     */
    function testReferenceDumpsReadAndWriteBackIdentically() {
        final dumps:Array<String> = haxe.Json.parse(fixture('reference_dumps.json'));
        assertTrue(dumps.length > 10);
        for (json in dumps) {
            final state = DockAreaState.fromJson(json);
            assertEquals(json, state.toJson());
            assertTrue(DockAreaState.fromJson(state.toJsonPretty()).equals(state));
        }
    }

    function testTheDefaultStateIsWrittenLikeSerde() {
        assertEquals('{"version":null,"center":{"panel_name":"","children":[],"info":{"panel":null}}}', DockAreaState.defaultValue().toJson());
    }

    #end

    static macro function fixturesJson():Expr {
        final file = Context.getPosInfos(Context.currentPos()).file;
        final dir = haxe.io.Path.normalize(haxe.io.Path.directory(sys.FileSystem.absolutePath(file)) + '/../../../data/dock');
        final files:Dynamic = {};
        for (name in sys.FileSystem.readDirectory(dir)) {
            if (!StringTools.endsWith(name, '.json')) continue;
            final path = dir + '/' + name;
            Context.registerModuleDependency('tests.kit.BaseDockStateTest', path);
            Reflect.setField(files, name, sys.io.File.getContent(path));
        }
        return macro $v{haxe.Json.stringify(files)};
    }

}

#if !macro

/**
 * A `PanelSource` backed by a fixed map, so conversion is testable without an
 * `App`.
 */
private class FakePanels implements PanelSource {

    final names:Array<{id:PanelId, name:String}>;

    public function new(names:Array<{id:PanelId, name:String}>) {
        this.names = names;
    }

    public function panelName(id:PanelId):String {
        for (entry in names) if (entry.id == id) return entry.name;
        return 'Unknown';
    }

    public function isVisible(id:PanelId):Bool {
        return true;
    }

    public function dump(id:PanelId):PanelState {
        return new PanelState(panelName(id), [], PanelInfoTools.panel(JNull));
    }

}

/**
 * Assigns each leaf `PanelState` an id in encounter order, so the reader can
 * be tested without a registry or an `App`.
 */
private class RecordingBuilder implements PanelBuilder {

    public final built:Array<String> = [];

    public function new() {}

    public function build(state:PanelState, info:PanelInfo):PanelId {
        built.push(state.panelName);
        return PanelId.fromU64(built.length);
    }

}

/**
 * Round-trips leaves by remembering the exact `PanelState` each id came from,
 * which is what the production invalid-panel path must also do.
 */
private class PreservingPanels implements PanelBuilder implements PanelSource {

    public final states:Array<PanelState> = [];

    public function new() {}

    public function build(state:PanelState, info:PanelInfo):PanelId {
        states.push(state.clone());
        return PanelId.fromU64(states.length);
    }

    public function panelName(id:PanelId):String {
        return states[id.asU64() - 1].panelName;
    }

    public function isVisible(id:PanelId):Bool {
        return true;
    }

    public function dump(id:PanelId):PanelState {
        return states[id.asU64() - 1].clone();
    }

}

#end
