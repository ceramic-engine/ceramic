// Ported from vscode src/vs/platform/contextkey/test/common/contextkey.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.platform.contextkey;

import cityscape.base.common.Platform;
import cityscape.base.common.RegExp;
import cityscape.platform.contextkey.common.ContextKey;
import testing.TestCase;

private class TestContext implements IContext {
    final ctx:Dynamic;

    public function new(ctx:Dynamic) {
        this.ctx = ctx;
    }

    public function getValue(key:String):Any {
        return Reflect.field(ctx, key);
    }
}

/**
 * vscode's 'ContextKeyExpr' tests. In 'evaluate', vscode computes the
 * expected values of `testBatch` with JavaScript (`!!value`,
 * `value == '5'`, `/d.*\/.test(value)`); they are written out here.
 */
class ContextKeyExprTest extends TestCase {

    static function createContext(ctx:Dynamic):IContext {
        return new TestContext(ctx);
    }

    function testContextKeyExprEquals() {
        final a = ContextKeyExpr.and(
            ContextKeyExpr.has('a1'),
            ContextKeyExpr.and(ContextKeyExpr.has('and.a')),
            ContextKeyExpr.has('a2'),
            ContextKeyExpr.regex('d3', new RegExp('d.*')),
            ContextKeyExpr.regex('d4', new RegExp('\\*\\*3*')),
            ContextKeyExpr.equals('b1', 'bb1'),
            ContextKeyExpr.equals('b2', 'bb2'),
            ContextKeyExpr.notEquals('c1', 'cc1'),
            ContextKeyExpr.notEquals('c2', 'cc2'),
            ContextKeyExpr.not('d1'),
            ContextKeyExpr.not('d2')
        );
        final b = ContextKeyExpr.and(
            ContextKeyExpr.equals('b2', 'bb2'),
            ContextKeyExpr.notEquals('c1', 'cc1'),
            ContextKeyExpr.not('d1'),
            ContextKeyExpr.regex('d4', new RegExp('\\*\\*3*')),
            ContextKeyExpr.notEquals('c2', 'cc2'),
            ContextKeyExpr.has('a2'),
            ContextKeyExpr.equals('b1', 'bb1'),
            ContextKeyExpr.regex('d3', new RegExp('d.*')),
            ContextKeyExpr.has('a1'),
            ContextKeyExpr.and(ContextKeyExpr.equals('and.a', true)),
            ContextKeyExpr.not('d2')
        );
        assertTrue(a.equals(b), 'expressions should be equal');
    }

    function testIssue134942EqualsInComparatorExpressions() {
        function testEquals(expr:Null<ContextKeyExpression>, str:String):Void {
            final deserialized = ContextKeyExpr.deserialize(str);
            assertNotNull(expr);
            assertNotNull(deserialized);
            assertEquals(true, expr.equals(deserialized), str);
        }
        testEquals(ContextKeyExpr.greater('value', 0), 'value > 0');
        testEquals(ContextKeyExpr.greaterEquals('value', 0), 'value >= 0');
        testEquals(ContextKeyExpr.smaller('value', 0), 'value < 0');
        testEquals(ContextKeyExpr.smallerEquals('value', 0), 'value <= 0');
    }

    function testNormalize() {
        final key1IsTrue = ContextKeyExpr.equals('key1', true);
        final key1IsNotFalse = ContextKeyExpr.notEquals('key1', false);
        final key1IsFalse = ContextKeyExpr.equals('key1', false);
        final key1IsNotTrue = ContextKeyExpr.notEquals('key1', true);

        assertTrue(key1IsTrue.equals(ContextKeyExpr.has('key1')));
        assertTrue(key1IsNotFalse.equals(ContextKeyExpr.has('key1')));
        assertTrue(key1IsFalse.equals(ContextKeyExpr.not('key1')));
        assertTrue(key1IsNotTrue.equals(ContextKeyExpr.not('key1')));
    }

    function testEvaluate() {
        final context = createContext({
            'a': true,
            'b': false,
            'c': '5',
            'd': 'd'
        });
        function testExpression(expr:String, expected:Bool):Void {
            final rules = ContextKeyExpr.deserialize(expr);
            assertEquals(expected, rules.evaluate(context), expr);
        }
        /**
         * The expected values of vscode's `testBatch` for `value`:
         * `!!value`, `value == '5'`, `/d.*\/.test(value)`, `/D/i.test(value)`
         * (`String(value)` is tested: 'undefined' contains a d).
         */
        function testBatch(expr:String, truthy:Bool, equals5:Bool, matchesD:Bool, matchesDi:Bool):Void {
            testExpression(expr, truthy);
            testExpression(expr + ' == true', truthy);
            testExpression(expr + ' != true', !truthy);
            testExpression(expr + ' == false', !truthy);
            testExpression(expr + ' != false', truthy);
            testExpression(expr + ' == 5', equals5);
            testExpression(expr + ' != 5', !equals5);
            testExpression('!' + expr, !truthy);
            testExpression(expr + ' =~ /d.*/', matchesD);
            testExpression(expr + ' =~ /D/i', matchesDi);
        }

        testBatch('a', true, false, false, false);
        testBatch('b', false, false, false, false);
        testBatch('c', true, true, false, false);
        testBatch('d', true, false, true, true);
        testBatch('z', false, false, true, true);

        testExpression('true', true);
        testExpression('false', false);
        testExpression('a && !b', true && !false);
        testExpression('a && b', true && false);
        testExpression('a && !b && c == 5', true && !false && '5' == '5');
        testExpression('d =~ /e.*/', false);

        // precedence test: false && true || true === true because && is evaluated first
        testExpression('b && a || a', true);

        testExpression('a || b', true);
        testExpression('b || b', false);
        testExpression('b && a || a && b', false);
    }

    function testNegate() {
        function testNegate(expr:String, expected:String):Void {
            final actual = ContextKeyExpr.deserialize(expr).negate().serialize();
            assertEquals(expected, actual);
        }
        testNegate('true', 'false');
        testNegate('false', 'true');
        testNegate('a', '!a');
        testNegate('a && b || c', '!a && !c || !b && !c');
        testNegate('a && b || c || d', '!a && !c && !d || !b && !c && !d');
        testNegate('!a && !b || !c && !d', 'a && c || a && d || b && c || b && d');
        testNegate('!a && !b || !c && !d || !e && !f', 'a && c && e || a && c && f || a && d && e || a && d && f || b && c && e || b && c && f || b && d && e || b && d && f');
    }

    function testFalseTrue() {
        function testNormalize(expr:String, expected:String):Void {
            final actual = ContextKeyExpr.deserialize(expr).serialize();
            assertEquals(expected, actual);
        }
        testNormalize('true', 'true');
        testNormalize('!true', 'false');
        testNormalize('false', 'false');
        testNormalize('!false', 'true');
        testNormalize('a && true', 'a');
        testNormalize('a && false', 'false');
        testNormalize('a || true', 'true');
        testNormalize('a || false', 'a');
        testNormalize('isMac', Platform.isMacintosh ? 'true' : 'false');
        testNormalize('isLinux', Platform.isLinux ? 'true' : 'false');
        testNormalize('isWindows', Platform.isWindows ? 'true' : 'false');
    }

    function testIssue101015DistributeOR() {
        function t(expr1:String, expr2:String, expected:Null<String>):Void {
            final e1 = ContextKeyExpr.deserialize(expr1);
            final e2 = ContextKeyExpr.deserialize(expr2);
            final r = ContextKeyExpr.and(e1, e2);
            final actual = r != null ? r.serialize() : null;
            assertEquals(expected, actual);
        }
        t('a', 'b', 'a && b');
        t('a || b', 'c', 'a && c || b && c');
        t('a || b', 'c || d', 'a && c || a && d || b && c || b && d');
        t('a || b', 'c && d', 'a && c && d || b && c && d');
        t('a || b', 'c && d || e', 'a && e || b && e || a && c && d || b && c && d');
    }

    function testContextKeyInExpr() {
        final ainb = ContextKeyExpr.deserialize('a in b');
        assertEquals(true, ainb.evaluate(createContext({'a': 3, 'b': [3, 2, 1]})));
        assertEquals(true, ainb.evaluate(createContext({'a': 3, 'b': [1, 2, 3]})));
        assertEquals(false, ainb.evaluate(createContext({'a': 3, 'b': [1, 2]})));
        assertEquals(false, ainb.evaluate(createContext({'a': 3})));
        assertEquals(false, ainb.evaluate(createContext({'a': 3, 'b': null})));
        assertEquals(true, ainb.evaluate(createContext({'a': 'x', 'b': ['x']})));
        assertEquals(false, ainb.evaluate(createContext({'a': 'x', 'b': ['y']})));
        assertEquals(false, ainb.evaluate(createContext({'a': 'x', 'b': {}})));
        assertEquals(true, ainb.evaluate(createContext({'a': 'x', 'b': {'x': false}})));
        assertEquals(true, ainb.evaluate(createContext({'a': 'x', 'b': {'x': true}})));
        assertEquals(false, ainb.evaluate(createContext({'a': 'prototype', 'b': {}})));
    }

    function testContextKeyNotInExpr() {
        final aNotInB = ContextKeyExpr.deserialize('a not in b');
        assertEquals(false, aNotInB.evaluate(createContext({'a': 3, 'b': [3, 2, 1]})));
        assertEquals(false, aNotInB.evaluate(createContext({'a': 3, 'b': [1, 2, 3]})));
        assertEquals(true, aNotInB.evaluate(createContext({'a': 3, 'b': [1, 2]})));
        assertEquals(true, aNotInB.evaluate(createContext({'a': 3})));
        assertEquals(true, aNotInB.evaluate(createContext({'a': 3, 'b': null})));
        assertEquals(false, aNotInB.evaluate(createContext({'a': 'x', 'b': ['x']})));
        assertEquals(true, aNotInB.evaluate(createContext({'a': 'x', 'b': ['y']})));
        assertEquals(true, aNotInB.evaluate(createContext({'a': 'x', 'b': {}})));
        assertEquals(false, aNotInB.evaluate(createContext({'a': 'x', 'b': {'x': false}})));
        assertEquals(false, aNotInB.evaluate(createContext({'a': 'x', 'b': {'x': true}})));
        assertEquals(true, aNotInB.evaluate(createContext({'a': 'prototype', 'b': {}})));
    }

    function testIssue106524DistributingANDShouldNormalize() {
        final actual = ContextKeyExpr.and(
            ContextKeyExpr.or(
                ContextKeyExpr.has('a'),
                ContextKeyExpr.has('b')
            ),
            ContextKeyExpr.has('c')
        );
        final expected = ContextKeyExpr.or(
            ContextKeyExpr.and(
                ContextKeyExpr.has('a'),
                ContextKeyExpr.has('c')
            ),
            ContextKeyExpr.and(
                ContextKeyExpr.has('b'),
                ContextKeyExpr.has('c')
            )
        );
        assertEquals(true, actual.equals(expected));
    }

    function testIssue129625RemovesDuplicatedTermsInORExpressions() {
        final expr = ContextKeyExpr.or(
            ContextKeyExpr.has('A'),
            ContextKeyExpr.has('B'),
            ContextKeyExpr.has('A')
        );
        assertEquals('A || B', expr.serialize());
    }

    function testResolvesTrueConstantORExpressions() {
        final expr = ContextKeyExpr.or(
            ContextKeyExpr.has('A'),
            ContextKeyExpr.not('A')
        );
        assertEquals('true', expr.serialize());
    }

    function testResolvesFalseConstantANDExpressions() {
        final expr = ContextKeyExpr.and(
            ContextKeyExpr.has('A'),
            ContextKeyExpr.not('A')
        );
        assertEquals('false', expr.serialize());
    }

    function testIssue129625RemovesDuplicatedTermsInANDExpressions() {
        final expr = ContextKeyExpr.and(
            ContextKeyExpr.has('A'),
            ContextKeyExpr.has('B'),
            ContextKeyExpr.has('A')
        );
        assertEquals('A && B', expr.serialize());
    }

    function testIssue129625RemoveDuplicatedTermsWhenNegating() {
        final expr = ContextKeyExpr.and(
            ContextKeyExpr.has('A'),
            ContextKeyExpr.or(
                ContextKeyExpr.has('B1'),
                ContextKeyExpr.has('B2')
            )
        );
        assertEquals('A && B1 || A && B2', expr.serialize());
        assertEquals('!A || !A && !B1 || !A && !B2 || !B1 && !B2', expr.negate().serialize());
        assertEquals('A && B1 || A && B2', expr.negate().negate().serialize());
        assertEquals('!A || !A && !B1 || !A && !B2 || !B1 && !B2', expr.negate().negate().negate().serialize());
    }

    static function strImplies(p0:String, q0:String):Bool {
        final p = ContextKeyExpr.deserialize(p0);
        final q = ContextKeyExpr.deserialize(q0);
        return ContextKeyUtils.implies(p, q);
    }

    function testIssue129625RemoveRedundantTermsInORExpressions() {
        assertEquals(true, strImplies('a && b', 'a'));
        assertEquals(false, strImplies('a', 'a && b'));
    }

    function testImplies() {
        assertEquals(true, strImplies('a', 'a'));
        assertEquals(true, strImplies('a', 'a || b'));
        assertEquals(false, strImplies('a', 'a && b'));
        assertEquals(false, strImplies('a', 'a && b || a && c'));
        assertEquals(true, strImplies('a && b', 'a'));
        assertEquals(true, strImplies('a && b', 'b'));
        assertEquals(true, strImplies('a && b', 'a && b || c'));
        assertEquals(false, strImplies('a || b', 'a || c'));
        assertEquals(true, strImplies('a || b', 'a || b'));
        assertEquals(true, strImplies('a && b', 'a && b'));
        assertEquals(true, strImplies('a || b', 'a || b || c'));
        assertEquals(true, strImplies('c && a && b', 'c && a'));
    }

    function testGreaterGreaterEqualsSmallerSmallerEqualsEvaluate() {
        function checkEvaluate(expr:String, ctx:Dynamic, expected:Bool):Void {
            final _expr = ContextKeyExpr.deserialize(expr);
            assertEquals(expected, _expr.evaluate(createContext(ctx)), expr);
        }

        checkEvaluate('a > 1', {}, false);
        checkEvaluate('a > 1', {a: 0}, false);
        checkEvaluate('a > 1', {a: 1}, false);
        checkEvaluate('a > 1', {a: 2}, true);
        checkEvaluate('a > 1', {a: '0'}, false);
        checkEvaluate('a > 1', {a: '1'}, false);
        checkEvaluate('a > 1', {a: '2'}, true);
        checkEvaluate('a > 1', {a: 'a'}, false);

        checkEvaluate('a > 10', {a: 2}, false);
        checkEvaluate('a > 10', {a: 11}, true);
        checkEvaluate('a > 10', {a: '11'}, true);
        checkEvaluate('a > 10', {a: '2'}, false);
        checkEvaluate('a > 10', {a: '11'}, true);

        checkEvaluate('a > 1.1', {a: 1}, false);
        checkEvaluate('a > 1.1', {a: 2}, true);
        checkEvaluate('a > 1.1', {a: 11}, true);
        checkEvaluate('a > 1.1', {a: '1.1'}, false);
        checkEvaluate('a > 1.1', {a: '2'}, true);
        checkEvaluate('a > 1.1', {a: '11'}, true);

        checkEvaluate('a > b', {a: 'b'}, false);
        checkEvaluate('a > b', {a: 'c'}, false);
        checkEvaluate('a > b', {a: 1000}, false);

        checkEvaluate('a >= 2', {a: '1'}, false);
        checkEvaluate('a >= 2', {a: '2'}, true);
        checkEvaluate('a >= 2', {a: '3'}, true);

        checkEvaluate('a < 2', {a: '1'}, true);
        checkEvaluate('a < 2', {a: '2'}, false);
        checkEvaluate('a < 2', {a: '3'}, false);

        checkEvaluate('a <= 2', {a: '1'}, true);
        checkEvaluate('a <= 2', {a: '2'}, true);
        checkEvaluate('a <= 2', {a: '3'}, false);
    }

    function testGreaterGreaterEqualsSmallerSmallerEqualsNegate() {
        function checkNegate(expr:String, expected:String):Void {
            final a = ContextKeyExpr.deserialize(expr);
            final b = a.negate();
            assertEquals(expected, b.serialize());
        }

        checkNegate('a > 1', 'a <= 1');
        checkNegate('a > 1.1', 'a <= 1.1');
        checkNegate('a > b', 'a <= b');

        checkNegate('a >= 1', 'a < 1');
        checkNegate('a >= 1.1', 'a < 1.1');
        checkNegate('a >= b', 'a < b');

        checkNegate('a < 1', 'a >= 1');
        checkNegate('a < 1.1', 'a >= 1.1');
        checkNegate('a < b', 'a >= b');

        checkNegate('a <= 1', 'a > 1');
        checkNegate('a <= 1.1', 'a > 1.1');
        checkNegate('a <= b', 'a > b');
    }

    function testIssue111899ContextKeysCanUseLtOrGt() {
        final actual = ContextKeyExpr.deserialize('editorTextFocus && vim.active && vim.use<C-r>');
        assertTrue(actual.equals(
            ContextKeyExpr.and(
                ContextKeyExpr.has('editorTextFocus'),
                ContextKeyExpr.has('vim.active'),
                ContextKeyExpr.has('vim.use<C-r>')
            )
        ));
    }

}
