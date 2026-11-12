package tests.base;

import cityscape.base.common.Arrays.CallbackIterable;
import testing.TestCase;

/**
 * `CallbackIterable`'s searches (Cityscape tests, not ported): Monaco's
 * results, `undefined` when nothing matches. On C# a captured `Null<T>` of a
 * type parameter was read back as `object` and threw when nothing matched,
 * and a value type T must still give null, not 0.
 */
class CallbackIterableTest extends TestCase {

    static function of<T>(items:Array<T>):CallbackIterable<T> {
        return new CallbackIterable<T>(cb -> {
            for (item in items) {
                if (!cb(item))
                    break;
            }
        });
    }

    function testFindFirstAndLastOfObjects() {
        final it = of(['a', 'bb', 'cc', 'd']);
        assertEquals('bb', it.findFirst(s -> s.length == 2));
        assertEquals('cc', it.findLast(s -> s.length == 2));
        assertNull(it.findFirst(s -> s.length == 3));
        assertNull(it.findLast(s -> s.length == 3));
        assertNull(CallbackIterable.empty().findLast(s -> true));
    }

    function testFindFirstAndLastOfInts() {
        final it = of([0, 1, 2, 3]);
        assertEquals(0, it.findFirst(i -> i < 2));
        assertEquals(1, it.findLast(i -> i < 2));
        assertNull(it.findFirst(i -> i > 5));
        assertNull(it.findLast(i -> i > 5));
    }

    function testFindLastMaxBy() {
        final it = of([1, 3, 2, 3]);
        assertEquals(3, it.findLastMaxBy((a, b) -> a - b));
        assertNull(of(([] : Array<Int>)).findLastMaxBy((a, b) -> a - b));
        assertNull(of(([] : Array<String>)).findLastMaxBy((a, b) -> a.length - b.length));
    }

}
