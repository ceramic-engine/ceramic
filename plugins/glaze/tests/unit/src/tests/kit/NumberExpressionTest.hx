// New tests for the Haxe port of gpui-kit (no gpui-kit origin): the kit additions without upstream
// equivalent (KIT-nnn in docs/DEVIATIONS.md). See NOTICE.md.
package tests.kit;

import glaze.kit.input.NumberExpression;
import testing.TestCase;

/** The expressions a number input may hold (KIT-036): `NumberExpression.evaluate`. */
class NumberExpressionTest extends TestCase {

    function testNumbers() {
        assertEquals(136., NumberExpression.evaluate('136'));
        assertEquals(0.5, NumberExpression.evaluate('.5'));
        assertEquals(-2.25, NumberExpression.evaluate(' -2.25 '));
        assertEquals(3., NumberExpression.evaluate('+3'));
    }

    function testOperationsAndPriorities() {
        assertEquals(144., NumberExpression.evaluate('136+8'));
        assertEquals(128., NumberExpression.evaluate('136 - 8'));
        assertEquals(20., NumberExpression.evaluate('10*2'));
        assertEquals(0.25, NumberExpression.evaluate('1/4'));
        assertEquals(14., NumberExpression.evaluate('2+3*4'));
        assertEquals(20., NumberExpression.evaluate('(2+3)*4'));
        assertEquals(-20., NumberExpression.evaluate('-(2+3)*4'));
        assertEquals(1., NumberExpression.evaluate('8/4/2'));
        assertEquals(5., NumberExpression.evaluate('10-3-2'));
        assertEquals(6., NumberExpression.evaluate('2*-3*-1'));
    }

    function testWhatIsNotAnExpression() {
        assertEquals(null, NumberExpression.evaluate(''));
        assertEquals(null, NumberExpression.evaluate('   '));
        assertEquals(null, NumberExpression.evaluate('abc'));
        assertEquals(null, NumberExpression.evaluate('12px'));
        assertEquals(null, NumberExpression.evaluate('1+'));
        assertEquals(null, NumberExpression.evaluate('(1+2'));
        assertEquals(null, NumberExpression.evaluate('1+2)'));
        assertEquals(null, NumberExpression.evaluate('1..2'));
        assertEquals(null, NumberExpression.evaluate('1/0'));
        assertEquals(null, NumberExpression.evaluate('1e3'));
    }

}
