package tests;

import glaze.Action;
import glaze.ActionBuildError;
import glaze.ActionRegistry;
import glaze.App;
import glaze.KeyBinding;
import glaze.KeyContext;
import glaze.Keystroke;
import glaze.MacroActionData;
import glaze.NoAction;
import glaze.TestDispatcher;
import glaze.Unbind;
import testing.TestCase;

/**
 * Tests of gpui-pre 0.3.10: src/action.rs. `test_action_macros` is ported
 * from tests/action_macros.rs (Rust only checks that it compiles, here the
 * generated methods are checked too). action.rs itself has no test module:
 * the other checks follow its code (registry, build by name, errors).
 */
class ActionTest extends TestCase {

    function testActionMacros() {
        final some:Action = new SomeAction();
        assertEquals('test_only::SomeAction', some.name());
        assertEquals('test_only::SomeAction', SomeAction.nameForType());
        assertEquals(null, SomeAction.documentation());
        assertEquals('Documented action', SomeActionWithDocs.documentation());
        assertEquals('test_only::AnotherAction', new AnotherAction().name());

        // A manual implementation keeps its own methods
        final registerable = new RegisterableAction();
        assertEquals('RegisterableAction', registerable.name());
        assertTrue(registerable.partialEq(new RegisterableAction()));
    }

    function testUnitActions() {
        final a = new SomeAction();
        assertTrue(a.partialEq(new SomeAction()));
        assertFalse(a.partialEq(new AnotherAction()));
        assertFalse(a.partialEq(null));
        final clone = a.boxedClone();
        assertTrue(clone != a);
        assertTrue(clone.partialEq(a));
        assertTrue(Std.isOfType(SomeAction.build({}), SomeAction));
        assertEquals(0, SomeAction.deprecatedAliases().length);
    }

    function testDataActions() {
        final a = new SelectNext(true);
        final b = new SelectNext(false);
        assertTrue(a.partialEq(new SelectNext(true)));
        assertFalse(a.partialEq(b));
        assertTrue(a.boxedClone().partialEq(a));
        assertEquals('editor_test::SelectNext', a.name());

        final built:SelectNext = cast SelectNext.build({replace_newest: true});
        assertTrue(built.replaceNewest);

        final moved:MoveBy = cast MoveBy.build({rows: 3, label: 'x', tags: ['a', 'b']});
        assertEquals(3, moved.rows);
        assertEquals('x', moved.label);
        assertEquals(1.5, moved.scale);
        assertTrue(moved.partialEq(new MoveBy(3, 'x', 1.5, ['a', 'b'])));
        assertFalse(moved.partialEq(new MoveBy(3, 'x', 1.5, ['a'])));

        final withScale:MoveBy = cast MoveBy.build({rows: 1, scale: 2, tags: []});
        assertEquals(2.0, withScale.scale);
        assertEquals(null, withScale.label);
    }

    function testRegistryBuildByName() {
        final app = new App(new TestDispatcher());

        final names = app.allActionNames();
        assertTrue(names.indexOf('zed::NoAction') != -1);
        assertTrue(names.indexOf('zed::Unbind') != -1);
        assertTrue(names.indexOf('test_only::SomeAction') != -1);
        assertTrue(names.indexOf('editor_test::SelectNext') != -1);
        assertTrue(names.indexOf('editor_test::OldSelectNext') != -1);

        assertTrue(Std.isOfType(app.buildAction('test_only::SomeAction'), SomeAction));
        assertTrue(Std.isOfType(app.buildAction('zed::NoAction', {}), NoAction));

        final unbind = app.buildAction('zed::Unbind', haxe.Json.parse('"editor::NewLine"'));
        assertTrue(unbind.partialEq(new Unbind('editor::NewLine')));

        final selectNext = app.buildAction('editor_test::SelectNext', haxe.Json.parse('{"replace_newest": true}'));
        assertTrue(selectNext.partialEq(new SelectNext(true)));

        // Deprecated aliases build the action too
        final aliased = app.buildAction('editor_test::OldSelectNext', {replace_newest: false});
        assertTrue(aliased.partialEq(new SelectNext(false)));
        assertEquals('editor_test::SelectNext', app.actions.deprecatedAliases().get('editor_test::OldSelectNext'));
        assertEquals('use something else', app.actions.deprecationMessages().get('editor_test::SelectNext'));

        // Build by type
        assertTrue(Std.isOfType(app.actions.buildActionType(SomeAction), SomeAction));
    }

    function testBuildErrors() {
        final app = new App(new TestDispatcher());

        var error:ActionBuildError = null;
        try {
            app.buildAction('nope::Missing');
        }
        catch (e:ActionBuildError) {
            error = e;
        }
        assertNotNull(error);
        assertTrue(error.isNotFound());
        assertEquals('Didn\'t find an action named "nope::Missing"', error.message);

        error = null;
        try {
            app.buildAction('editor_test::SelectNext', {});
        }
        catch (e:ActionBuildError) {
            error = e;
        }
        assertNotNull(error);
        assertFalse(error.isNotFound());
        assertEquals('Error while building action "editor_test::SelectNext": missing field `replace_newest`', error.message);

        error = null;
        try {
            app.buildAction('editor_test::SelectNext', {replace_newest: 'yes'});
        }
        catch (e:ActionBuildError) {
            error = e;
        }
        assertNotNull(error);

        error = null;
        try {
            app.buildAction('test_only::NotFromJson');
        }
        catch (e:ActionBuildError) {
            error = e;
        }
        assertNotNull(error);
        assertEquals('Error while building action "test_only::NotFromJson": test_only::NotFromJson cannot be built from JSON', error.message);

        // noRegister actions cannot be built by name
        assertRaises(() -> app.buildAction('test_only::Unregistered'));
    }

    function testDuplicateRegistration() {
        final registry = new ActionRegistry();
        assertRaises(() -> registry.insertAction(new MacroActionData('test_only::SomeAction', 'Other', SomeAction.build, [], null, null)));
    }

    function testAppBindKeys() {
        final app = new App(new TestDispatcher());
        final version = app.keyBindings().version();
        app.bindKeys([
            new KeyBinding('cmd-s', new SomeAction(), 'Editor'),
            new KeyBinding('cmd-s', new AnotherAction(), null),
        ]);
        assertTrue(app.keyBindings().version() != version);
        assertEquals(2, app.keyBindings().bindings().length);

        final result = app.keyBindings().bindingsForInput([Keystroke.parse('cmd-s')], [KeyContext.parse('Editor')]);
        assertEquals(2, result.bindings.length);
        assertTrue(result.bindings[0].action.partialEq(new AnotherAction()));

        assertEquals(2, app.allBindingsForInput([Keystroke.parse('cmd-s')]).length);

        app.clearKeyBindings();
        assertEquals(0, app.keyBindings().bindings().length);
    }

    function testNoActionAndUnbind() {
        assertEquals('zed::NoAction', new NoAction().name());
        assertEquals('zed::Unbind', new Unbind('a::B').name());
        assertTrue(NoAction.isNoAction(new NoAction()));
        assertFalse(NoAction.isNoAction(new SomeAction()));
        assertTrue(Unbind.isUnbind(new Unbind('a::B')));
        assertTrue(new Unbind('a::B').partialEq(new Unbind('a::B')));
        assertFalse(new Unbind('a::B').partialEq(new Unbind('a::C')));
        assertTrue(NoAction.documentation().indexOf('unbinds the keybinding') != -1);
    }

}

@:action(namespace = test_only) private class SomeAction implements Action {}

/**
 * Documented action
 */
@:action(namespace = test_only) private class SomeActionWithDocs implements Action {}

@:action(namespace = test_only) private class AnotherAction implements Action {}

/**
 * Manual implementation (Rust: `register_action!` with a hand written `impl Action`).
 */
private class RegisterableAction implements Action {

    public function new() {}

    public function boxedClone():Action {
        return new RegisterableAction();
    }

    public function partialEq(action:Action):Bool {
        return Std.isOfType(action, RegisterableAction);
    }

    public function name():String {
        return 'RegisterableAction';
    }

}

@:action(namespace = editor_test, deprecatedAliases = ['editor_test::OldSelectNext'], deprecated = 'use something else')
private class SelectNext implements Action {

    public final replaceNewest:Bool;

}

@:action(namespace = editor_test)
private class MoveBy implements Action {

    public final rows:Int;

    public final label:Null<String>;

    public var scale:Float = 1.5;

    public final tags:Array<String>;

}

@:action(namespace = test_only, noJson)
private class NotFromJson implements Action {}

@:action(namespace = test_only, noRegister)
private class Unregistered implements Action {}
