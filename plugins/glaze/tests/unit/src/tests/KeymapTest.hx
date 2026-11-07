package tests;

import glaze.Action;
import glaze.KeyBinding;
import glaze.KeyBindingMetaIndex;
import glaze.KeyContext;
import glaze.Keymap;
import glaze.Keystroke;
import glaze.NoAction;
import glaze.OperatingSystem;
import glaze.Unbind;
import glaze.keymap.KeyDispatch;
import testing.TestCase;

/**
 * Tests ported from gpui-pre 0.3.10: src/keymap.rs (all 24 tests) and the
 * keystroke matching tests of src/key_dispatch.rs that do not need a window
 * (5 tests: `DispatchTree` is replaced by `KeyDispatch` with the context stack
 * the dispatch path would produce).
 */
class KeymapTest extends TestCase {

    var previousOs:OperatingSystem;

    override function setup() {
        previousOs = OperatingSystem.current;
        // The Rust tests run with the non-Windows keystroke matching
        OperatingSystem.current = Mac;
    }

    override function teardown() {
        OperatingSystem.current = previousOs;
    }

    static function ks(source:String):Keystroke {
        return Keystroke.parse(source);
    }

    static function ctx(source:String):KeyContext {
        return KeyContext.parse(source);
    }

    static function describeBindings(bindings:Array<KeyBinding>):String {
        return [
            for (binding in bindings)
                [for (k in binding.keystrokes) k.inner().unparse(Mac)].join(' ') + ' => ' + binding.action.name()
        ].join(', ');
    }

    static function bindingKeys(keymap:Keymap, action:Action):String {
        return [for (binding in keymap.bindingsForAction(action)) binding.keystrokes[0].inner().unparse(Mac)].join(',');
    }

/// src/keymap.rs

    function testKeymap() {
        final bindings = [
            new KeyBinding('ctrl-a', new ActionAlpha(), null),
            new KeyBinding('ctrl-a', new ActionBeta(), 'pane'),
            new KeyBinding('ctrl-a', new ActionGamma(), 'editor && mode==full'),
        ];

        final keymap = new Keymap();
        keymap.addBindings([for (b in bindings) b.clone()]);

        @:privateAccess {
            // global bindings are enabled in all contexts
            assertEquals(0, keymap.bindingEnabled(bindings[0], []));
            assertEquals(1, keymap.bindingEnabled(bindings[0], [ctx('terminal')]));

            // contextual bindings are enabled in contexts that match their predicate
            assertEquals(null, keymap.bindingEnabled(bindings[1], [ctx('barf x=y')]));
            assertEquals(1, keymap.bindingEnabled(bindings[1], [ctx('pane x=y')]));

            assertEquals(null, keymap.bindingEnabled(bindings[2], [ctx('editor')]));
            assertEquals(1, keymap.bindingEnabled(bindings[2], [ctx('editor mode=full')]));
        }
    }

    function testDepthPrecedence() {
        final keymap = new Keymap();
        keymap.addBindings([
            new KeyBinding('ctrl-a', new ActionBeta(), 'pane'),
            new KeyBinding('ctrl-a', new ActionGamma(), 'editor'),
        ]);

        final result = keymap.bindingsForInput([ks('ctrl-a')], [ctx('pane'), ctx('editor')]);

        assertFalse(result.pending);
        assertEquals(2, result.bindings.length);
        assertTrue(result.bindings[0].action.partialEq(new ActionGamma()));
        assertTrue(result.bindings[1].action.partialEq(new ActionBeta()));
    }

    function testKeymapDisabled() {
        final keymap = new Keymap();
        keymap.addBindings([
            new KeyBinding('ctrl-a', new ActionAlpha(), 'editor'),
            new KeyBinding('ctrl-b', new ActionAlpha(), 'editor'),
            new KeyBinding('ctrl-a', new NoAction(), 'editor && mode==full'),
            new KeyBinding('ctrl-b', new NoAction(), null),
        ]);

        // binding is only enabled in a specific context
        assertEquals(0, keymap.bindingsForInput([ks('ctrl-a')], [ctx('barf')]).bindings.length);
        assertTrue(keymap.bindingsForInput([ks('ctrl-a')], [ctx('editor')]).bindings.length > 0);

        // binding is disabled in a more specific context
        assertEquals(0, keymap.bindingsForInput([ks('ctrl-a')], [ctx('editor mode=full')]).bindings.length);

        // binding is globally disabled
        assertEquals(0, keymap.bindingsForInput([ks('ctrl-b')], [ctx('barf')]).bindings.length);
    }

    function testMultipleKeystrokeBindingDisabled() {
        // Tests for https://github.com/zed-industries/zed/issues/30259
        var keymap = new Keymap();
        keymap.addBindings([
            new KeyBinding('space w w', new ActionAlpha(), 'workspace'),
            new KeyBinding('space w w', new NoAction(), 'editor'),
        ]);

        final space = () -> ks('space');
        final w = () -> ks('w');

        final spaceW = () -> [space(), w()];
        final spaceWW = () -> [space(), w(), w()];

        final workspaceContext = () -> [ctx('workspace')];
        final editorWorkspaceContext = () -> [ctx('workspace'), ctx('editor')];

        // Ensure `space` results in pending input on the workspace, but not editor
        final spaceWorkspace = keymap.bindingsForInput([space()], workspaceContext());
        assertEquals(0, spaceWorkspace.bindings.length);
        assertTrue(spaceWorkspace.pending);

        final spaceEditor = keymap.bindingsForInput([space()], editorWorkspaceContext());
        assertEquals(0, spaceEditor.bindings.length);
        assertFalse(spaceEditor.pending);

        // Ensure `space w` results in pending input on the workspace, but not editor
        final spaceWWorkspace = keymap.bindingsForInput(spaceW(), workspaceContext());
        assertEquals(0, spaceWWorkspace.bindings.length);
        assertTrue(spaceWWorkspace.pending);

        final spaceWEditor = keymap.bindingsForInput(spaceW(), editorWorkspaceContext());
        assertEquals(0, spaceWEditor.bindings.length);
        assertFalse(spaceWEditor.pending);

        // Ensure `space w w` results in the binding in the workspace, but not in the editor
        final spaceWWWorkspace = keymap.bindingsForInput(spaceWW(), workspaceContext());
        assertTrue(spaceWWWorkspace.bindings.length > 0);
        assertFalse(spaceWWWorkspace.pending);

        final spaceWWEditor = keymap.bindingsForInput(spaceWW(), editorWorkspaceContext());
        assertEquals(0, spaceWWEditor.bindings.length);
        assertFalse(spaceWWEditor.pending);

        // Now test what happens if we have another binding defined AFTER the NoAction
        // that should result in pending
        keymap = new Keymap();
        keymap.addBindings([
            new KeyBinding('space w w', new ActionAlpha(), 'workspace'),
            new KeyBinding('space w w', new NoAction(), 'editor'),
            new KeyBinding('space w x', new ActionAlpha(), 'editor'),
        ]);

        var result = keymap.bindingsForInput([space()], editorWorkspaceContext());
        assertEquals(0, result.bindings.length);
        assertTrue(result.pending);

        // Now test what happens if we have another binding defined BEFORE the NoAction
        // that should result in pending
        keymap = new Keymap();
        keymap.addBindings([
            new KeyBinding('space w w', new ActionAlpha(), 'workspace'),
            new KeyBinding('space w x', new ActionAlpha(), 'editor'),
            new KeyBinding('space w w', new NoAction(), 'editor'),
        ]);

        result = keymap.bindingsForInput([space()], editorWorkspaceContext());
        assertEquals(0, result.bindings.length);
        assertTrue(result.pending);

        // Now test what happens if we have another binding defined at a higher context
        // that should result in pending
        keymap = new Keymap();
        keymap.addBindings([
            new KeyBinding('space w w', new ActionAlpha(), 'workspace'),
            new KeyBinding('space w x', new ActionAlpha(), 'workspace'),
            new KeyBinding('space w w', new NoAction(), 'editor'),
        ]);

        result = keymap.bindingsForInput([space()], editorWorkspaceContext());
        assertEquals(0, result.bindings.length);
        assertTrue(result.pending);
    }

    function testOverrideMultikey() {
        var keymap = new Keymap();
        keymap.addBindings([
            new KeyBinding('ctrl-w left', new ActionAlpha(), 'editor'),
            new KeyBinding('ctrl-w', new NoAction(), 'editor'),
        ]);

        var result = keymap.bindingsForInput([ks('ctrl-w')], [ctx('editor')]);
        assertEquals(0, result.bindings.length);
        assertTrue(result.pending);

        keymap = new Keymap();
        keymap.addBindings([
            new KeyBinding('ctrl-w left', new ActionAlpha(), 'editor'),
            new KeyBinding('ctrl-w', new ActionBeta(), 'editor'),
        ]);

        result = keymap.bindingsForInput([ks('ctrl-w')], [ctx('editor')]);
        assertEquals(1, result.bindings.length);
        assertFalse(result.pending);
    }

    function testSimpleDisable() {
        final keymap = new Keymap();
        keymap.addBindings([
            new KeyBinding('ctrl-x', new ActionAlpha(), 'editor'),
            new KeyBinding('ctrl-x', new NoAction(), 'editor'),
        ]);

        final result = keymap.bindingsForInput([ks('ctrl-x')], [ctx('editor')]);
        assertEquals(0, result.bindings.length);
        assertFalse(result.pending);
    }

    function testDisableWeakerSourcesOnly() {
        final USER:KeyBindingMetaIndex = 0;
        final VIM:KeyBindingMetaIndex = 1;
        final BASE:KeyBindingMetaIndex = 2;
        final DEFAULT:KeyBindingMetaIndex = 3;

        final editorContext = () -> [ctx('editor')];
        final ctrlX = () -> [ks('ctrl-x')];

        // A base keymap null disables a default binding in the same context.
        var keymap = new Keymap();
        keymap.addBindings([
            new KeyBinding('ctrl-x', new ActionAlpha(), 'editor').withMeta(DEFAULT),
            new KeyBinding('ctrl-x', new NoAction(), 'editor').withMeta(BASE),
        ]);
        var result = keymap.bindingsForInput(ctrlX(), editorContext());
        assertEquals(0, result.bindings.length);

        // A user binding is not affected by base keymap or default nulls.
        keymap = new Keymap();
        keymap.addBindings([
            new KeyBinding('ctrl-x', new NoAction(), 'editor').withMeta(DEFAULT),
            new KeyBinding('ctrl-x', new NoAction(), 'editor').withMeta(BASE),
            new KeyBinding('ctrl-x', new ActionBeta(), null).withMeta(USER),
        ]);
        result = keymap.bindingsForInput(ctrlX(), editorContext());
        assertEquals(1, result.bindings.length);
        assertTrue(result.bindings[0].action.partialEq(new ActionBeta()));

        // A user binding at a shallower context is not disabled by a deeper
        // base keymap null.
        keymap = new Keymap();
        keymap.addBindings([
            new KeyBinding('ctrl-x', new NoAction(), 'editor').withMeta(BASE),
            new KeyBinding('ctrl-x', new ActionBeta(), 'workspace').withMeta(USER),
        ]);
        result = keymap.bindingsForInput(ctrlX(), [ctx('workspace'), ctx('editor')]);
        assertEquals(1, result.bindings.length);
        assertTrue(result.bindings[0].action.partialEq(new ActionBeta()));

        // A vim binding survives a base keymap null, and a user null disables
        // everything.
        keymap = new Keymap();
        keymap.addBindings([
            new KeyBinding('ctrl-x', new ActionAlpha(), 'editor').withMeta(DEFAULT),
            new KeyBinding('ctrl-x', new NoAction(), 'editor').withMeta(BASE),
            new KeyBinding('ctrl-x', new ActionGamma(), 'editor').withMeta(VIM),
        ]);
        result = keymap.bindingsForInput(ctrlX(), editorContext());
        assertEquals(1, result.bindings.length);
        assertTrue(result.bindings[0].action.partialEq(new ActionGamma()));

        keymap = new Keymap();
        keymap.addBindings([
            new KeyBinding('ctrl-x', new ActionAlpha(), 'editor').withMeta(DEFAULT),
            new KeyBinding('ctrl-x', new ActionGamma(), 'editor').withMeta(VIM),
            new KeyBinding('ctrl-x', new NoAction(), 'editor').withMeta(USER),
        ]);
        result = keymap.bindingsForInput(ctrlX(), editorContext());
        assertEquals(0, result.bindings.length);
    }

    function testFailToDisable() {
        // disabled at the wrong level
        final keymap = new Keymap();
        keymap.addBindings([
            new KeyBinding('ctrl-x', new ActionAlpha(), 'editor'),
            new KeyBinding('ctrl-x', new NoAction(), 'workspace'),
        ]);

        final result = keymap.bindingsForInput([ks('ctrl-x')], [ctx('workspace'), ctx('editor')]);
        assertEquals(1, result.bindings.length);
        assertFalse(result.pending);
    }

    function testDisableDeeper() {
        final keymap = new Keymap();
        keymap.addBindings([
            new KeyBinding('ctrl-x', new ActionAlpha(), 'workspace'),
            new KeyBinding('ctrl-x', new NoAction(), 'editor'),
        ]);

        final result = keymap.bindingsForInput([ks('ctrl-x')], [ctx('workspace'), ctx('editor')]);
        assertEquals(0, result.bindings.length);
        assertFalse(result.pending);
    }

    function testPendingMatchEnabled() {
        final keymap = new Keymap();
        keymap.addBindings([
            new KeyBinding('ctrl-x', new ActionBeta(), 'vim_mode == normal'),
            new KeyBinding('ctrl-x 0', new ActionAlpha(), 'Workspace'),
        ]);

        final matched = keymap.bindingsForInput(
            [ks('ctrl-x')],
            [ctx('Workspace'), ctx('Pane'), ctx('Editor vim_mode=normal')]
        );
        assertEquals(1, matched.bindings.length);
        assertTrue(matched.bindings[0].action.partialEq(new ActionBeta()));
        assertTrue(matched.pending);
    }

    function testPendingMatchEnabledExtended() {
        var keymap = new Keymap();
        keymap.addBindings([
            new KeyBinding('ctrl-x', new ActionBeta(), 'vim_mode == normal'),
            new KeyBinding('ctrl-x 0', new NoAction(), 'Workspace'),
        ]);

        var matched = keymap.bindingsForInput(
            [ks('ctrl-x')],
            [ctx('Workspace'), ctx('Pane'), ctx('Editor vim_mode=normal')]
        );
        assertEquals(1, matched.bindings.length);
        assertTrue(matched.bindings[0].action.partialEq(new ActionBeta()));
        assertFalse(matched.pending);

        keymap = new Keymap();
        keymap.addBindings([
            new KeyBinding('ctrl-x', new ActionBeta(), 'Workspace'),
            new KeyBinding('ctrl-x 0', new NoAction(), 'vim_mode == normal'),
        ]);

        matched = keymap.bindingsForInput(
            [ks('ctrl-x')],
            [ctx('Workspace'), ctx('Pane'), ctx('Editor vim_mode=normal')]
        );
        assertEquals(1, matched.bindings.length);
        assertTrue(matched.bindings[0].action.partialEq(new ActionBeta()));
        assertFalse(matched.pending);
    }

    function testOverridingPrefix() {
        final keymap = new Keymap();
        keymap.addBindings([
            new KeyBinding('ctrl-x 0', new ActionAlpha(), 'Workspace'),
            new KeyBinding('ctrl-x', new ActionBeta(), 'vim_mode == normal'),
        ]);

        final matched = keymap.bindingsForInput(
            [ks('ctrl-x')],
            [ctx('Workspace'), ctx('Pane'), ctx('Editor vim_mode=normal')]
        );
        assertEquals(1, matched.bindings.length);
        assertTrue(matched.bindings[0].action.partialEq(new ActionBeta()));
        assertFalse(matched.pending);
    }

    function testContextPrecedenceWithSameSource() {
        // User has both Workspace and Editor bindings for the same key:
        // Editor binding should take precedence over Workspace binding
        final keymap = new Keymap();
        keymap.addBindings([
            new KeyBinding('cmd-r', new ActionAlpha(), 'Workspace'),
            new KeyBinding('cmd-r', new ActionBeta(), 'Editor'),
        ]);

        // Context stack: [Workspace, Editor] (Editor is deeper)
        final result = keymap.bindingsForInput([ks('cmd-r')], [ctx('Workspace'), ctx('Editor')]);

        // Both bindings should be returned, but Editor binding should be first (highest precedence)
        assertEquals(2, result.bindings.length);
        assertTrue(result.bindings[0].action.partialEq(new ActionBeta()));
        assertTrue(result.bindings[1].action.partialEq(new ActionAlpha()));
    }

    function testBindingsForAction() {
        final keymap = new Keymap();
        keymap.addBindings([
            new KeyBinding('ctrl-a', new ActionAlpha(), 'pane'),
            new KeyBinding('ctrl-b', new ActionBeta(), 'editor && mode == full'),
            new KeyBinding('ctrl-c', new ActionGamma(), 'workspace'),
            new KeyBinding('ctrl-a', new NoAction(), 'pane && active'),
            new KeyBinding('ctrl-b', new NoAction(), 'editor'),
        ]);

        assertEquals('ctrl-a', bindingKeys(keymap, new ActionAlpha()));
        assertEquals('', bindingKeys(keymap, new ActionBeta()));
        assertEquals('ctrl-c', bindingKeys(keymap, new ActionGamma()));
    }

    function testTargetedUnbindIgnoresTargetContext() {
        final keymap = new Keymap();
        keymap.addBindings([
            new KeyBinding('tab', new ActionAlpha(), 'Editor'),
            new KeyBinding('tab', new ActionBeta(), 'Editor && showing_completions'),
            new KeyBinding('tab', new Unbind('test_only::ActionAlpha'), 'Editor && edit_prediction'),
        ]);

        final result = keymap.bindingsForInput([ks('tab')], [ctx('Editor showing_completions edit_prediction')]);

        assertFalse(result.pending);
        assertEquals(1, result.bindings.length);
        assertTrue(result.bindings[0].action.partialEq(new ActionBeta()));
    }

    function testBindingsForActionKeepsBindingForNarrowerTargetedUnbind() {
        final keymap = new Keymap();
        keymap.addBindings([
            new KeyBinding('tab', new ActionAlpha(), 'Editor'),
            new KeyBinding('tab', new Unbind('test_only::ActionAlpha'), 'Editor && edit_prediction'),
            new KeyBinding('tab', new ActionBeta(), 'Editor && showing_completions'),
        ]);

        assertEquals('tab', bindingKeys(keymap, new ActionAlpha()));
        assertEquals('tab', bindingKeys(keymap, new ActionBeta()));
    }

    function testBindingsForActionRemovesBindingForBroaderTargetedUnbind() {
        final keymap = new Keymap();
        keymap.addBindings([
            new KeyBinding('tab', new ActionAlpha(), 'Editor && edit_prediction'),
            new KeyBinding('tab', new Unbind('test_only::ActionAlpha'), 'Editor'),
        ]);

        assertEquals(0, keymap.bindingsForAction(new ActionAlpha()).length);
    }

    function testSourcePrecedenceSorting() {
        // KeybindSource precedence: User (0) > Vim (1) > Base (2) > Default (3)
        // Test that user keymaps take precedence over default keymaps at the same context depth
        final keymap = new Keymap();

        // Add a default keymap binding first
        final defaultBinding = new KeyBinding('cmd-r', new ActionAlpha(), 'Editor');
        defaultBinding.setMeta(3); // Default source
        keymap.addBindings([defaultBinding]);

        // Add a user keymap binding
        final userBinding = new KeyBinding('cmd-r', new ActionBeta(), 'Editor');
        userBinding.setMeta(0); // User source
        keymap.addBindings([userBinding]);

        final result = keymap.bindingsForInput([ks('cmd-r')], [ctx('Editor')]);

        // User binding should take precedence over default binding
        assertEquals(2, result.bindings.length);
        assertTrue(result.bindings[0].action.partialEq(new ActionBeta()));
        assertTrue(result.bindings[1].action.partialEq(new ActionAlpha()));
    }

    function testPossibleNextBindingsExcludeNullBindings() {
        final keymap = new Keymap([
            new KeyBinding('ctrl-k a', new ActionAlpha(), 'Editor'),
            new KeyBinding('ctrl-k b', new ActionBeta(), 'Editor'),
            new KeyBinding('ctrl-k a', new NoAction(), 'Editor'),
        ]);

        final bindings = keymap.possibleNextBindingsForInput([ks('ctrl-k')], [ctx('Editor')]);
        assertEquals('ctrl-k b => test_only::ActionBeta', describeBindings(bindings));
    }

    function testPossibleNextBindingsExcludeUnboundBindings() {
        final keymap = new Keymap([
            new KeyBinding('ctrl-k a', new ActionAlpha(), 'Editor'),
            new KeyBinding('ctrl-k b', new ActionBeta(), 'Editor'),
            new KeyBinding('ctrl-k a', new Unbind('test_only::ActionAlpha'), 'Editor'),
        ]);

        final bindings = keymap.possibleNextBindingsForInput([ks('ctrl-k')], [ctx('Editor')]);
        assertEquals('ctrl-k b => test_only::ActionBeta', describeBindings(bindings));
    }

    function testPossibleNextBindingsKeepUserBindingOverBaseKeymapNull() {
        final USER:KeyBindingMetaIndex = 0;
        final BASE:KeyBindingMetaIndex = 2;
        final DEFAULT:KeyBindingMetaIndex = 3;

        final keymap = new Keymap();
        keymap.addBindings([
            new KeyBinding('ctrl-k a', new ActionAlpha(), 'Editor').withMeta(DEFAULT),
            new KeyBinding('ctrl-k a', new NoAction(), 'Editor').withMeta(BASE),
            new KeyBinding('ctrl-k a', new ActionBeta(), 'Editor').withMeta(USER),
        ]);

        final bindings = keymap.possibleNextBindingsForInput([ks('ctrl-k')], [ctx('Editor')]);
        assertEquals('ctrl-k a => test_only::ActionBeta', describeBindings(bindings));
    }

    function testPossibleNextBindingsApplyDisablingByContext() {
        final keymap = new Keymap([
            new KeyBinding('ctrl-k a', new ActionAlpha(), 'Workspace'),
            new KeyBinding('ctrl-k a', new ActionBeta(), 'Editor'),
            new KeyBinding('ctrl-k b', new ActionGamma(), 'Editor'),
            // Only removes the editor binding, so the workspace binding still dispatches.
            new KeyBinding('ctrl-k a', new Unbind('test_only::ActionBeta'), 'Editor'),
            // Doesn't apply because `Terminal` isn't in the context stack.
            new KeyBinding('ctrl-k b', new NoAction(), 'Terminal'),
        ]);

        final bindings = keymap.possibleNextBindingsForInput([ks('ctrl-k')], [ctx('Workspace'), ctx('Editor')]);
        assertEquals(
            'ctrl-k b => test_only::ActionGamma, ctrl-k a => test_only::ActionAlpha',
            describeBindings(bindings)
        );
    }

    function testPossibleNextBindingsExcludeLongerChordDisabledInDeeperContext() {
        final keymap = new Keymap([
            new KeyBinding('space w w', new ActionAlpha(), 'Workspace'),
            new KeyBinding('space w x', new ActionBeta(), 'Workspace'),
            new KeyBinding('space w w', new NoAction(), 'AgentPanel'),
        ]);
        final contextStack = [ctx('Workspace'), ctx('AgentPanel')];

        for (input in ['space', 'space w']) {
            final keystrokes = [for (k in input.split(' ')) ks(k)];
            final bindings = keymap.possibleNextBindingsForInput(keystrokes, contextStack);
            assertEquals('space w x => test_only::ActionBeta', describeBindings(bindings));
        }
    }

    function testPossibleNextBindingsExcludeDisabledBindingsWithTypedInput() {
        // Option-S reports both its physical key and the character it produced, so typed input
        // matches bindings written with either.
        final typedInput = [ks('alt-s->ß')];
        final keymap = new Keymap([
            new KeyBinding('ß a', new ActionAlpha(), null),
            new KeyBinding('alt-s a', new NoAction(), null),
        ]);
        assertEquals(0, keymap.possibleNextBindingsForInput(typedInput, []).length);

        // Cross-check against dispatch of the same typed input.
        final typedThenA = [ks('alt-s->ß'), ks('a')];
        final dispatched = keymap.bindingsForInput(typedThenA, []);
        assertEquals(0, dispatched.bindings.length);
    }

/// src/key_dispatch.rs (tests that do not need a window)

    function testKeybindingForActionBounds() {
        final tree = new KeyDispatch(new Keymap([
            new KeyBinding('cmd-n', new TestAction(), 'ProjectPanel'),
        ]));

        final contexts = [ctx('Workspace'), ctx('ProjectPanel')];

        final keybinding = tree.bindingsForAction(new TestAction(), contexts);

        assertTrue(keybinding[0].action.partialEq(new TestAction()));
    }

    function testBindingsForActionHidesTargetedUnbindInActiveContext() {
        final tree = new KeyDispatch(new Keymap([
            new KeyBinding('tab', new TestAction(), 'Editor'),
            new KeyBinding('tab', new Unbind('dispatch_test::TestAction'), 'Editor && edit_prediction'),
            new KeyBinding('tab', new SecondaryTestAction(), 'Editor && showing_completions'),
        ]));

        final contexts = [ctx('Workspace'), ctx('Editor showing_completions edit_prediction')];

        final bindings = tree.bindingsForAction(new TestAction(), contexts);
        assertEquals(0, bindings.length);

        final highest = tree.highestPrecedenceBindingForAction(new TestAction(), contexts);
        assertNull(highest);

        final fallbackBindings = tree.bindingsForAction(new SecondaryTestAction(), contexts);
        assertEquals(1, fallbackBindings.length);
        assertTrue(fallbackBindings[0].action.partialEq(new SecondaryTestAction()));
    }

    function testBindingsForActionKeepsTargetedBindingOutsideUnbindContext() {
        final tree = new KeyDispatch(new Keymap([
            new KeyBinding('tab', new TestAction(), 'Editor'),
            new KeyBinding('tab', new Unbind('dispatch_test::TestAction'), 'Editor && edit_prediction'),
            new KeyBinding('tab', new SecondaryTestAction(), 'Editor && showing_completions'),
        ]));

        final contexts = [ctx('Workspace'), ctx('Editor')];

        final bindings = tree.bindingsForAction(new TestAction(), contexts);
        assertEquals(1, bindings.length);
        assertTrue(bindings[0].action.partialEq(new TestAction()));

        final highest = tree.highestPrecedenceBindingForAction(new TestAction(), contexts);
        assertTrue(highest != null && highest.action.partialEq(new TestAction()));
    }

    function testOverlayAfterBaseRestoresShadowedPickerBinding() {
        // A picker action is bound in `Picker > Editor`, but a base keymap binds
        // the same chord to an editor action in `Editor`. Both resolve at the
        // same context depth, so precedence is decided by load order (later wins).
        final contexts = [ctx('Picker'), ctx('Editor')];

        // Default keymap (picker binding) followed by a base keymap that binds
        // the same chord to an editor action: the base binding wins and the
        // picker action is shadowed.
        final shadowed = new KeyDispatch(new Keymap([
            new KeyBinding('ctrl-alt-down', new TestAction(), 'Picker > Editor'),
            new KeyBinding('ctrl-alt-down', new SecondaryTestAction(), 'Editor'),
        ]));
        var highest = shadowed.highestPrecedenceBindingForAction(new TestAction(), contexts);
        assertNull(highest, 'picker binding should be shadowed by the base editor binding');

        // Re-binding the picker action in an overlay loaded after the base keymap
        // restores it as the resolved binding.
        final fixed = new KeyDispatch(new Keymap([
            new KeyBinding('ctrl-alt-down', new TestAction(), 'Picker > Editor'),
            new KeyBinding('ctrl-alt-down', new SecondaryTestAction(), 'Editor'),
            // overlay loaded last:
            new KeyBinding('ctrl-alt-down', new TestAction(), 'Picker > Editor'),
        ]));
        highest = fixed.highestPrecedenceBindingForAction(new TestAction(), contexts);
        assertTrue(highest != null && highest.action.partialEq(new TestAction()),
            'overlay loaded after base should restore the picker binding');

        // Conversely, putting the override before the base keymap does NOT help.
        final overrideBeforeBase = new KeyDispatch(new Keymap([
            new KeyBinding('ctrl-alt-down', new TestAction(), 'Picker > Editor'),
            new KeyBinding('ctrl-alt-down', new TestAction(), 'Picker > Editor'),
            new KeyBinding('ctrl-alt-down', new SecondaryTestAction(), 'Editor'),
        ]));
        highest = overrideBeforeBase.highestPrecedenceBindingForAction(new TestAction(), contexts);
        assertNull(highest, 'an override loaded before the base binding cannot win the equal-depth tie');
    }

    function testPendingHasBindingState() {
        final tree = new KeyDispatch(new Keymap([
            new KeyBinding('ctrl-b h', new TestAction(), null),
            new KeyBinding('space', new TestAction(), 'ContextA'),
            new KeyBinding('space f g', new TestAction(), 'ContextB'),
        ]));

        // Empty dispatch path: empty context stack
        var result = tree.dispatchKey([], ks('ctrl-b'), []);
        assertEquals(1, result.pending.length);
        assertFalse(result.pendingHasBinding);

        result = tree.dispatchKey(result.pending, ks('h'), []);
        assertEquals(0, result.pending.length);
        assertEquals(1, result.bindings.length);
        assertFalse(result.pendingHasBinding);

        // A node with the `ContextB` context
        result = tree.dispatchKey([], ks('space'), [ctx('ContextB')]);

        assertEquals(1, result.pending.length);
        assertFalse(result.pendingHasBinding);
    }

/// Additional checks of the dispatch algorithm (not in GPUI's tests)

    function testDispatchKeyReplaysUnmatchedPrefix() {
        final tree = new KeyDispatch(new Keymap([
            new KeyBinding('ctrl-k', new ActionAlpha(), null),
            new KeyBinding('ctrl-k ctrl-k x', new ActionBeta(), null),
            new KeyBinding('a', new ActionGamma(), null),
        ]));

        // ctrl-k is ambiguous: pending, with a binding
        var result = tree.dispatchKey([], ks('ctrl-k'), []);
        assertEquals(1, result.pending.length);
        assertTrue(result.pendingHasBinding);

        // ctrl-k ctrl-k still pending
        result = tree.dispatchKey(result.pending, ks('ctrl-k'), []);
        assertEquals(2, result.pending.length);

        // `a` breaks the sequence: both ctrl-k are replayed with their binding, then `a` matches
        result = tree.dispatchKey(result.pending, ks('a'), []);
        assertEquals(0, result.pending.length);
        assertEquals(2, result.toReplay.length);
        assertEquals('ctrl-k', result.toReplay[0].keystroke.unparse(Mac));
        assertEquals(1, result.toReplay[0].bindings.length);
        assertTrue(result.toReplay[0].bindings[0].action.partialEq(new ActionAlpha()));
        assertEquals(1, result.toReplay[1].bindings.length);
        assertEquals(1, result.bindings.length);
        assertTrue(result.bindings[0].action.partialEq(new ActionGamma()));

        // Flushing a pending input replays it
        final replays = tree.flushDispatch([ks('ctrl-k'), ks('ctrl-k')], []);
        assertEquals(2, replays.length);
        assertTrue(replays[0].bindings[0].action.partialEq(new ActionAlpha()));
    }

}

@:action(namespace = test_only) private class ActionAlpha implements Action {}

@:action(namespace = test_only) private class ActionBeta implements Action {}

@:action(namespace = test_only) private class ActionGamma implements Action {}

@:action(namespace = test_only) private class ActionDelta implements Action {}

@:action(namespace = dispatch_test) private class TestAction implements Action {}

@:action(namespace = dispatch_test) private class SecondaryTestAction implements Action {}
