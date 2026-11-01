package tests;

import gpui.Action;
import gpui.KeyBindingContextPredicate;
import gpui.KeyBindingContextPredicateTools;
import gpui.KeyContext;
import testing.TestCase;

using gpui.KeyBindingContextPredicateTools;

/**
 * Tests ported from gpui-pre 0.3.10: src/keymap/context.rs (all 11 tests).
 */
class KeyContextTest extends TestCase {

    static function parse(source:String):KeyBindingContextPredicate {
        return KeyBindingContextPredicateTools.parse(source);
    }

    function assertPredicate(expected:KeyBindingContextPredicate, actual:KeyBindingContextPredicate, ?pos:haxe.PosInfos) {
        assertTrue(expected.equals(actual), 'expected ' + expected.toString() + ' (' + Std.string(expected) + ') but got ' + actual.toString() + ' (' + Std.string(actual) + ')', pos);
    }

    function testActionsDefinition() {
        // Rust checks that `actions!` compiles with and without a trailing comma.
        // Here the classes are declared at the end of this module.
        final actions:Array<Action> = [new A(), new B(), new C(), new D(), new E(), new F(), new G()];
        final more:Array<Action> = [new H(), new I(), new J(), new K(), new L(), new M(), new N()];
        assertEquals('test_only::A', actions[0].name());
        assertEquals('test_only::G', actions[6].name());
        assertEquals('test_only::H', more[0].name());
        assertEquals('test_only::N', more[6].name());
    }

    function testParseContext() {
        final expected = new KeyContext();
        expected.add('baz');
        expected.set('foo', 'bar');
        assertTrue(expected.equals(KeyContext.parse('baz foo=bar')));
        assertTrue(expected.equals(KeyContext.parse('baz foo = bar')));
        assertTrue(expected.equals(KeyContext.parse('  baz foo   =   bar baz')));
        assertTrue(expected.equals(KeyContext.parse(' baz foo = bar')));
    }

    function testParseIdentifiers() {
        // Identifiers
        assertPredicate(Identifier('abc12'), parse('abc12'));
        assertPredicate(Identifier('_1a'), parse('_1a'));
    }

    function testParseNegations() {
        assertPredicate(Not(Identifier('abc')), parse('!abc'));
        assertPredicate(Not(Not(Identifier('abc'))), parse(' ! ! abc'));
    }

    function testParseEqualityOperators() {
        assertPredicate(Equal('a', 'b'), parse('a == b'));
        assertPredicate(NotEqual('c', 'd'), parse('c!=d'));
        var message:String = null;
        try {
            parse('c == !d');
        }
        catch (e:haxe.Exception) {
            message = e.message;
        }
        assertEquals('operands of == must be identifiers', message);
    }

    function testParseBooleanOperators() {
        assertPredicate(Or(Identifier('a'), Identifier('b')), parse('a || b'));
        assertPredicate(
            Or(Identifier('a'), And(Not(Identifier('b')), Identifier('c'))),
            parse('a || !b && c')
        );
        assertPredicate(
            Or(And(Identifier('a'), Identifier('b')), And(Identifier('c'), Identifier('d'))),
            parse('a && b || c&&d')
        );
        assertPredicate(
            Or(And(Equal('a', 'b'), Identifier('c')), And(Equal('d', 'e'), Identifier('f'))),
            parse('a == b && c || d == e && f')
        );
        assertPredicate(
            And(And(And(Identifier('a'), Identifier('b')), Identifier('c')), Identifier('d')),
            parse('a && b && c && d')
        );
    }

    function testParseParenthesizedExpressions() {
        assertPredicate(
            And(Identifier('a'), Or(Equal('b', 'c'), NotEqual('d', 'e'))),
            parse('a && (b == c || d != e)')
        );
        assertPredicate(Or(Identifier('a'), Identifier('b')), parse(' ( a || b ) '));
    }

    function testIsSuperset() {
        function assertIsSuperset(a:String, b:String, result:Bool, ?pos:haxe.PosInfos) {
            final pa = parse(a);
            final pb = parse(b);
            assertEquals(result, pa.isSuperset(pb), '($a).isSuperset($b)', pos);
        }

        assertIsSuperset('editor', 'editor', true);
        assertIsSuperset('editor', 'workspace', false);

        assertIsSuperset('editor', 'editor && vim_mode', true);
        assertIsSuperset('editor', 'mode == full && editor', true);
        assertIsSuperset('editor && mode == full', 'editor', false);

        assertIsSuperset('editor', 'something > editor', true);
        assertIsSuperset('editor', 'editor > menu', false);

        assertIsSuperset('foo || bar || baz', 'bar', true);
        assertIsSuperset('foo || bar || baz', 'quux', false);
    }

    function testChildOperator() {
        final predicate = parse('parent > child');

        final parentContext = KeyContext.parse('parent');
        final childContext = KeyContext.parse('child');

        var contexts = [parentContext, childContext];
        assertTrue(predicate.eval(contexts));

        final grandparentContext = KeyContext.parse('grandparent');

        contexts = [grandparentContext, parentContext, childContext];
        assertTrue(predicate.eval(contexts));

        final otherContext = KeyContext.parse('other');

        contexts = [otherContext, childContext];
        assertFalse(predicate.eval(contexts));

        contexts = [parentContext, otherContext, childContext];
        assertTrue(predicate.eval(contexts));

        assertFalse(predicate.eval([]));
        assertFalse(predicate.eval([childContext]));
        assertFalse(predicate.eval([parentContext]));

        final zanyPredicate = parse('child > child');
        assertFalse(zanyPredicate.eval([childContext]));
        assertTrue(zanyPredicate.eval([childContext, childContext]));
    }

    function testNotOperator() {
        final notPredicate = parse('!editor');
        var editorContext = KeyContext.parse('editor');
        var workspaceContext = KeyContext.parse('workspace');
        final parentContext = KeyContext.parse('parent');
        final childContext = KeyContext.parse('child');

        assertTrue(notPredicate.eval([workspaceContext]));
        assertFalse(notPredicate.eval([editorContext]));
        assertFalse(notPredicate.eval([editorContext, workspaceContext]));
        assertFalse(notPredicate.eval([workspaceContext, editorContext]));

        final complexNot = parse('!editor && workspace');
        assertTrue(complexNot.eval([workspaceContext]));
        assertFalse(complexNot.eval([editorContext, workspaceContext]));

        final notModePredicate = parse('!(mode == full)');
        final modeContext = new KeyContext();
        modeContext.set('mode', 'full');
        assertFalse(notModePredicate.eval([modeContext]));

        final otherModeContext = new KeyContext();
        otherModeContext.set('mode', 'partial');
        assertTrue(notModePredicate.eval([otherModeContext]));

        var notDescendant = parse('!(parent > child)');
        assertTrue(notDescendant.eval([parentContext]));
        assertTrue(notDescendant.eval([childContext]));
        assertFalse(notDescendant.eval([parentContext, childContext]));

        notDescendant = parse('parent > !child');
        assertFalse(notDescendant.eval([parentContext]));
        assertFalse(notDescendant.eval([childContext]));
        assertFalse(notDescendant.eval([parentContext, childContext]));

        final doubleNot = parse('!!editor');
        assertTrue(doubleNot.eval([editorContext]));
        assertFalse(doubleNot.eval([workspaceContext]));

        // Test complex descendant cases
        workspaceContext = KeyContext.parse('Workspace');
        final paneContext = KeyContext.parse('Pane');
        editorContext = KeyContext.parse('Editor');

        // Workspace > Pane > Editor
        final workspacePaneEditor = [workspaceContext, paneContext, editorContext];

        // Pane > (Pane > Editor) - should not match
        final panePaneEditor = parse('Pane > (Pane > Editor)');
        assertFalse(panePaneEditor.eval(workspacePaneEditor));

        final workspacePaneEditorPredicate = parse('Workspace > Pane > Editor');
        assertTrue(workspacePaneEditorPredicate.eval(workspacePaneEditor));

        // (Pane > Pane) > Editor - should not match
        final panePaneThenEditor = parse('(Pane > Pane) > Editor');
        assertFalse(panePaneThenEditor.eval(workspacePaneEditor));

        // Pane > !Workspace - should match
        final paneNotWorkspace = parse('Pane > !Workspace');
        assertTrue(paneNotWorkspace.eval([paneContext, editorContext]));
        assertFalse(paneNotWorkspace.eval([paneContext, workspaceContext]));

        // !Workspace - shouldn't match when Workspace is in the context
        final notWorkspace = parse('!Workspace');
        assertFalse(notWorkspace.eval([workspaceContext]));
        assertTrue(notWorkspace.eval([paneContext]));
        assertTrue(notWorkspace.eval([editorContext]));
        assertFalse(notWorkspace.eval(workspacePaneEditor));
    }

    function testContextDisplay() {
        final ident = (s:String) -> Identifier(s);
        final eq = (a:String, b:String) -> Equal(a, b);
        final notEq = (a:String, b:String) -> NotEqual(a, b);
        final and = (a, b) -> KeyBindingContextPredicate.And(a, b);
        final or = (a, b) -> KeyBindingContextPredicate.Or(a, b);
        final descendant = (a, b) -> KeyBindingContextPredicate.Descendant(a, b);
        final not = (a) -> KeyBindingContextPredicate.Not(a);

        final testCases:Array<{predicate:KeyBindingContextPredicate, expected:String}> = [
            {predicate: ident('a'), expected: 'a'},
            {predicate: eq('a', 'b'), expected: 'a == b'},
            {predicate: notEq('a', 'b'), expected: 'a != b'},
            {predicate: descendant(ident('a'), ident('b')), expected: 'a > b'},
            {predicate: not(ident('a')), expected: '!a'},
            {predicate: notEq('a', 'b'), expected: 'a != b'},
            {predicate: descendant(ident('a'), ident('b')), expected: 'a > b'},
            {predicate: not(and(ident('a'), ident('b'))), expected: '!(a && b)'},
            {predicate: not(or(ident('a'), ident('b'))), expected: '!(a || b)'},
            {predicate: and(ident('a'), ident('b')), expected: 'a && b'},
            {predicate: and(and(ident('a'), ident('b')), ident('c')), expected: 'a && b && c'},
            {predicate: or(ident('a'), ident('b')), expected: 'a || b'},
            {predicate: or(or(ident('a'), ident('b')), ident('c')), expected: 'a || b || c'},
            {predicate: or(ident('a'), and(ident('b'), ident('c'))), expected: 'a || (b && c)'},
            {
                predicate: and(and(and(ident('a'), eq('b', 'c')), not(descendant(ident('d'), ident('e')))), eq('f', 'g')),
                expected: 'a && b == c && !(d > e) && f == g'
            },
            {
                predicate: and(and(ident('a'), or(ident('b'), ident('c'))), ident('d')),
                expected: 'a && (b || c) && d'
            },
            {
                predicate: or(or(ident('a'), and(ident('b'), ident('c'))), ident('d')),
                expected: 'a || (b && c) || d'
            },
        ];

        for (testCase in testCases) {
            final actual = testCase.predicate.toString();
            assertEquals(testCase.expected, actual);
            final parsed = parse(actual);
            assertPredicate(testCase.predicate, parsed);
        }
    }

/// Additional checks (not in GPUI's tests)

    function testParseErrors() {
        function errorOf(source:String):String {
            try {
                parse(source);
            }
            catch (e:haxe.Exception) {
                return e.message;
            }
            return null;
        }
        assertEquals('unexpected end', errorOf(''));
        assertEquals("expected a ')'", errorOf('(a'));
        assertEquals("unexpected character ''&''", errorOf('&a'));
        assertEquals("unexpected character '')''", errorOf('a)'));
        assertEquals('operands of != must be identifiers', errorOf('a != !b'));
    }

    function testDepthOfAndContextHelpers() {
        final contexts = [KeyContext.parse('Workspace'), KeyContext.parse('Pane'), KeyContext.parse('Editor mode=full')];
        assertEquals(3, parse('Editor').depthOf(contexts));
        assertEquals(2, parse('Pane').depthOf(contexts));
        assertEquals(1, parse('Workspace').depthOf(contexts));
        assertEquals(null, parse('Terminal').depthOf(contexts));
        assertEquals(3, parse('mode == full').depthOf(contexts));

        final context = KeyContext.parse('Editor mode=full extension=rs');
        assertEquals('Editor', context.primary().key);
        assertEquals(2, context.secondary().length);
        assertEquals('full', context.get('mode'));
        assertEquals('Editor mode=full extension=rs', context.toString());

        final withOs = KeyContext.newWithDefaults(Mac);
        assertEquals('macos', withOs.get('os'));

        // Vim operator characters are identifiers
        assertPredicate(Equal('vim_operator', '>'), parse('vim_operator == >'));
    }

}

@:action(namespace = test_only) private class A implements Action {}
@:action(namespace = test_only) private class B implements Action {}
@:action(namespace = test_only) private class C implements Action {}
@:action(namespace = test_only) private class D implements Action {}
@:action(namespace = test_only) private class E implements Action {}
@:action(namespace = test_only) private class F implements Action {}
@:action(namespace = test_only) private class G implements Action {}
@:action(namespace = test_only) private class H implements Action {}
@:action(namespace = test_only) private class I implements Action {}
@:action(namespace = test_only) private class J implements Action {}
@:action(namespace = test_only) private class K implements Action {}
@:action(namespace = test_only) private class L implements Action {}
@:action(namespace = test_only) private class M implements Action {}
@:action(namespace = test_only) private class N implements Action {}
