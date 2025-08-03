package ceramic;

#if plugin_arcade

/*
 * Copyright (C)2005-2018 Haxe Foundation
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

/**
 * Specialized merge sort implementation for sorting physics bodies.
 *
 * This class provides a stable, high-performance sort specifically optimized for
 * Arcade physics collision detection. The implementation is based on Haxe's standard
 * library merge sort but has been heavily optimized with inlined functions and
 * specialized comparison logic for physics bodies.
 *
 * Four different sort orders are provided:
 * - ArcadeSortGroupLeftRight: Sort by X position ascending (left to right)
 * - ArcadeSortGroupRightLeft: Sort by X position descending (right to left)
 * - ArcadeSortGroupTopBottom: Sort by Y position ascending (top to bottom)
 * - ArcadeSortGroupBottomTop: Sort by Y position descending (bottom to top)
 *
 * @see ArcadeWorld for usage in collision detection
 */
class ArcadeSortGroupLeftRight {

    /**
     * Compares two visuals based on their physics body X position.
     * @param a First visual to compare
     * @param b Second visual to compare
     * @return 1 if a.body.x >= b.body.x, -1 otherwise, 0 if either has no body
     */
    static inline function cmp(a:Visual, b:Visual):Int {

        var result = 0;
        var bodyA = a.body;
        var bodyB = b.body;
        if (bodyA != null && bodyB != null) {
            result = bodyA.x - bodyB.x >= 0 ? 1 : -1;
        }
        return result;

    }

    /**
     * Sorts an array of visuals by their physics body position.
     *
     * This operation modifies the array in place and preserves the relative order
     * of visuals with the same position (stable sort). Visuals without physics
     * bodies are treated as having position 0.
     *
     * @param a The array of visuals to sort
     */
    static inline public function sort(a:Array<Visual>) {
        rec(a, 0, a.length);
    }

    static function rec(a:Array<Visual>, from:Int, to:Int) {
        var middle = (from + to) >> 1;
        if (to - from < 12) {
            if (to <= from) return;
            for (i in (from + 1)...to) {
                var j = i;
                while (j > from) {
                    if (compare(a, j, j - 1) < 0)
                        swap(a, j - 1, j);
                    else
                        break;
                    j--;
                }
            }
            return;
        }
        rec(a, from, middle);
        rec(a, middle, to);
        doMerge(a, from, middle, to, middle - from, to - middle);
    }

    static function doMerge(a:Array<Visual>, from, pivot, to, len1, len2) {
        var first_cut, second_cut, len11, len22, new_mid;
        if (len1 == 0 || len2 == 0)
            return;
        if (len1 + len2 == 2) {
            if (compare(a, pivot, from) < 0)
                swap(a, pivot, from);
            return;
        }
        if (len1 > len2) {
            len11 = len1 >> 1;
            first_cut = from + len11;
            second_cut = lower(a, pivot, to, first_cut);
            len22 = second_cut - pivot;
        } else {
            len22 = len2 >> 1;
            second_cut = pivot + len22;
            first_cut = upper(a, from, pivot, second_cut);
            len11 = first_cut - from;
        }
        rotate(a, first_cut, pivot, second_cut);
        new_mid = first_cut + len22;
        doMerge(a, from, first_cut, new_mid, len11, len22);
        doMerge(a, new_mid, second_cut, to, len1 - len11, len2 - len22);
    }

    static inline function rotate(a:Array<Visual>, from, mid, to) {
        var n;
        if (from == mid || mid == to) return;
        n = gcd(to - from, mid - from);
        while (n-- != 0) {
            var val = a[from + n];
            var shift = mid - from;
            var p1 = from + n, p2 = from + n + shift;
            while (p2 != from + n) {
                a[p1] = a[p2];
                p1 = p2;
                if (to - p2 > shift) p2 += shift;
                else p2 = from + (shift - (to - p2));
            }
            a[p1] = val;
        }
    }

    static inline function gcd(m, n) {
        while (n != 0) {
            var t = m % n;
            m = n;
            n = t;
        }
        return m;
    }

    static inline function upper(a:Array<Visual>, from, to, val) {
        var len = to - from, half, mid;
        while (len > 0) {
            half = len >> 1;
            mid = from + half;
            if (compare(a, val, mid) < 0)
                len = half;
            else {
                from = mid + 1;
                len = len - half - 1;
            }
        }
        return from;
    }

    static inline function lower(a:Array<Visual>, from, to, val) {
        var len = to - from, half, mid;
        while (len > 0) {
            half = len >> 1;
            mid = from + half;
            if (compare(a, mid, val) < 0) {
                from = mid + 1;
                len = len - half - 1;
            } else
                len = half;
        }
        return from;
    }

    static inline function swap(a:Array<Visual>, i, j) {
        var tmp = a[i];
        a[i] = a[j];
        a[j] = tmp;
    }

    static inline function compare(a:Array<Visual>, i, j) {
        return cmp(a[i], a[j]);
    }

}

/**
 * Specialized merge sort implementation for sorting physics bodies.
 *
 * This class provides a stable, high-performance sort specifically optimized for
 * Arcade physics collision detection. The implementation is based on Haxe's standard
 * library merge sort but has been heavily optimized with inlined functions and
 * specialized comparison logic for physics bodies.
 *
 * Four different sort orders are provided:
 * - ArcadeSortGroupLeftRight: Sort by X position ascending (left to right)
 * - ArcadeSortGroupRightLeft: Sort by X position descending (right to left)
 * - ArcadeSortGroupTopBottom: Sort by Y position ascending (top to bottom)
 * - ArcadeSortGroupBottomTop: Sort by Y position descending (bottom to top)
 *
 * @see ArcadeWorld for usage in collision detection
 */
class ArcadeSortGroupRightLeft {

    /**
     * Compares two visuals based on their physics body X position (reversed).
     * @param a First visual to compare
     * @param b Second visual to compare
     * @return 1 if b.body.x >= a.body.x, -1 otherwise, 0 if either has no body
     */
    static inline function cmp(a:Visual, b:Visual):Int {

        var result = 0;
        var bodyA = a.body;
        var bodyB = b.body;
        if (bodyA != null && bodyB != null) {
            result = bodyB.x - bodyA.x >= 0 ? 1 : -1;
        }
        return result;

    }

    /**
     * Sorts an array of visuals by their physics body position.
     *
     * This operation modifies the array in place and preserves the relative order
     * of visuals with the same position (stable sort). Visuals without physics
     * bodies are treated as having position 0.
     *
     * @param a The array of visuals to sort
     */
    static inline public function sort(a:Array<Visual>) {
        rec(a, 0, a.length);
    }

    static function rec(a:Array<Visual>, from:Int, to:Int) {
        var middle = (from + to) >> 1;
        if (to - from < 12) {
            if (to <= from) return;
            for (i in (from + 1)...to) {
                var j = i;
                while (j > from) {
                    if (compare(a, j, j - 1) < 0)
                        swap(a, j - 1, j);
                    else
                        break;
                    j--;
                }
            }
            return;
        }
        rec(a, from, middle);
        rec(a, middle, to);
        doMerge(a, from, middle, to, middle - from, to - middle);
    }

    static function doMerge(a:Array<Visual>, from, pivot, to, len1, len2) {
        var first_cut, second_cut, len11, len22, new_mid;
        if (len1 == 0 || len2 == 0)
            return;
        if (len1 + len2 == 2) {
            if (compare(a, pivot, from) < 0)
                swap(a, pivot, from);
            return;
        }
        if (len1 > len2) {
            len11 = len1 >> 1;
            first_cut = from + len11;
            second_cut = lower(a, pivot, to, first_cut);
            len22 = second_cut - pivot;
        } else {
            len22 = len2 >> 1;
            second_cut = pivot + len22;
            first_cut = upper(a, from, pivot, second_cut);
            len11 = first_cut - from;
        }
        rotate(a, first_cut, pivot, second_cut);
        new_mid = first_cut + len22;
        doMerge(a, from, first_cut, new_mid, len11, len22);
        doMerge(a, new_mid, second_cut, to, len1 - len11, len2 - len22);
    }

    static inline function rotate(a:Array<Visual>, from, mid, to) {
        var n;
        if (from == mid || mid == to) return;
        n = gcd(to - from, mid - from);
        while (n-- != 0) {
            var val = a[from + n];
            var shift = mid - from;
            var p1 = from + n, p2 = from + n + shift;
            while (p2 != from + n) {
                a[p1] = a[p2];
                p1 = p2;
                if (to - p2 > shift) p2 += shift;
                else p2 = from + (shift - (to - p2));
            }
            a[p1] = val;
        }
    }

    static inline function gcd(m, n) {
        while (n != 0) {
            var t = m % n;
            m = n;
            n = t;
        }
        return m;
    }

    static inline function upper(a:Array<Visual>, from, to, val) {
        var len = to - from, half, mid;
        while (len > 0) {
            half = len >> 1;
            mid = from + half;
            if (compare(a, val, mid) < 0)
                len = half;
            else {
                from = mid + 1;
                len = len - half - 1;
            }
        }
        return from;
    }

    static inline function lower(a:Array<Visual>, from, to, val) {
        var len = to - from, half, mid;
        while (len > 0) {
            half = len >> 1;
            mid = from + half;
            if (compare(a, mid, val) < 0) {
                from = mid + 1;
                len = len - half - 1;
            } else
                len = half;
        }
        return from;
    }

    static inline function swap(a:Array<Visual>, i, j) {
        var tmp = a[i];
        a[i] = a[j];
        a[j] = tmp;
    }

    static inline function compare(a:Array<Visual>, i, j) {
        return cmp(a[i], a[j]);
    }

}

/**
 * Specialized merge sort implementation for sorting physics bodies.
 *
 * This class provides a stable, high-performance sort specifically optimized for
 * Arcade physics collision detection. The implementation is based on Haxe's standard
 * library merge sort but has been heavily optimized with inlined functions and
 * specialized comparison logic for physics bodies.
 *
 * Four different sort orders are provided:
 * - ArcadeSortGroupLeftRight: Sort by X position ascending (left to right)
 * - ArcadeSortGroupRightLeft: Sort by X position descending (right to left)
 * - ArcadeSortGroupTopBottom: Sort by Y position ascending (top to bottom)
 * - ArcadeSortGroupBottomTop: Sort by Y position descending (bottom to top)
 *
 * @see ArcadeWorld for usage in collision detection
 */
class ArcadeSortGroupTopBottom {

    /**
     * Compares two visuals based on their physics body Y position.
     * @param a First visual to compare
     * @param b Second visual to compare
     * @return 1 if a.body.y >= b.body.y, -1 otherwise, 0 if either has no body
     */
    static inline function cmp(a:Visual, b:Visual):Int {

        var result = 0;
        var bodyA = a.body;
        var bodyB = b.body;
        if (bodyA != null && bodyB != null) {
            result = bodyA.y - bodyB.y >= 0 ? 1 : -1;
        }
        return result;

    }

    /**
     * Sorts an array of visuals by their physics body position.
     *
     * This operation modifies the array in place and preserves the relative order
     * of visuals with the same position (stable sort). Visuals without physics
     * bodies are treated as having position 0.
     *
     * @param a The array of visuals to sort
     */
    static inline public function sort(a:Array<Visual>) {
        rec(a, 0, a.length);
    }

    static function rec(a:Array<Visual>, from:Int, to:Int) {
        var middle = (from + to) >> 1;
        if (to - from < 12) {
            if (to <= from) return;
            for (i in (from + 1)...to) {
                var j = i;
                while (j > from) {
                    if (compare(a, j, j - 1) < 0)
                        swap(a, j - 1, j);
                    else
                        break;
                    j--;
                }
            }
            return;
        }
        rec(a, from, middle);
        rec(a, middle, to);
        doMerge(a, from, middle, to, middle - from, to - middle);
    }

    static function doMerge(a:Array<Visual>, from, pivot, to, len1, len2) {
        var first_cut, second_cut, len11, len22, new_mid;
        if (len1 == 0 || len2 == 0)
            return;
        if (len1 + len2 == 2) {
            if (compare(a, pivot, from) < 0)
                swap(a, pivot, from);
            return;
        }
        if (len1 > len2) {
            len11 = len1 >> 1;
            first_cut = from + len11;
            second_cut = lower(a, pivot, to, first_cut);
            len22 = second_cut - pivot;
        } else {
            len22 = len2 >> 1;
            second_cut = pivot + len22;
            first_cut = upper(a, from, pivot, second_cut);
            len11 = first_cut - from;
        }
        rotate(a, first_cut, pivot, second_cut);
        new_mid = first_cut + len22;
        doMerge(a, from, first_cut, new_mid, len11, len22);
        doMerge(a, new_mid, second_cut, to, len1 - len11, len2 - len22);
    }

    static inline function rotate(a:Array<Visual>, from, mid, to) {
        var n;
        if (from == mid || mid == to) return;
        n = gcd(to - from, mid - from);
        while (n-- != 0) {
            var val = a[from + n];
            var shift = mid - from;
            var p1 = from + n, p2 = from + n + shift;
            while (p2 != from + n) {
                a[p1] = a[p2];
                p1 = p2;
                if (to - p2 > shift) p2 += shift;
                else p2 = from + (shift - (to - p2));
            }
            a[p1] = val;
        }
    }

    static inline function gcd(m, n) {
        while (n != 0) {
            var t = m % n;
            m = n;
            n = t;
        }
        return m;
    }

    static inline function upper(a:Array<Visual>, from, to, val) {
        var len = to - from, half, mid;
        while (len > 0) {
            half = len >> 1;
            mid = from + half;
            if (compare(a, val, mid) < 0)
                len = half;
            else {
                from = mid + 1;
                len = len - half - 1;
            }
        }
        return from;
    }

    static inline function lower(a:Array<Visual>, from, to, val) {
        var len = to - from, half, mid;
        while (len > 0) {
            half = len >> 1;
            mid = from + half;
            if (compare(a, mid, val) < 0) {
                from = mid + 1;
                len = len - half - 1;
            } else
                len = half;
        }
        return from;
    }

    static inline function swap(a:Array<Visual>, i, j) {
        var tmp = a[i];
        a[i] = a[j];
        a[j] = tmp;
    }

    static inline function compare(a:Array<Visual>, i, j) {
        return cmp(a[i], a[j]);
    }

}

/**
 * Specialized merge sort implementation for sorting physics bodies.
 *
 * This class provides a stable, high-performance sort specifically optimized for
 * Arcade physics collision detection. The implementation is based on Haxe's standard
 * library merge sort but has been heavily optimized with inlined functions and
 * specialized comparison logic for physics bodies.
 *
 * Four different sort orders are provided:
 * - ArcadeSortGroupLeftRight: Sort by X position ascending (left to right)
 * - ArcadeSortGroupRightLeft: Sort by X position descending (right to left)
 * - ArcadeSortGroupTopBottom: Sort by Y position ascending (top to bottom)
 * - ArcadeSortGroupBottomTop: Sort by Y position descending (bottom to top)
 *
 * @see ArcadeWorld for usage in collision detection
 */
class ArcadeSortGroupBottomTop {

    /**
     * Compares two visuals based on their physics body Y position (reversed).
     * @param a First visual to compare
     * @param b Second visual to compare
     * @return 1 if b.body.y > a.body.y, -1 otherwise, 0 if either has no body
     */
    static inline function cmp(a:Visual, b:Visual):Int {

        var result = 0;
        var bodyA = a.body;
        var bodyB = b.body;
        if (bodyA != null && bodyB != null) {
            result = bodyB.y - bodyA.y > 0 ? 1 : -1;
        }
        return result;

    }

    /**
     * Sorts an array of visuals by their physics body position.
     *
     * This operation modifies the array in place and preserves the relative order
     * of visuals with the same position (stable sort). Visuals without physics
     * bodies are treated as having position 0.
     *
     * @param a The array of visuals to sort
     */
    static inline public function sort(a:Array<Visual>) {
        rec(a, 0, a.length);
    }

    static function rec(a:Array<Visual>, from:Int, to:Int) {
        var middle = (from + to) >> 1;
        if (to - from < 12) {
            if (to <= from) return;
            for (i in (from + 1)...to) {
                var j = i;
                while (j > from) {
                    if (compare(a, j, j - 1) < 0)
                        swap(a, j - 1, j);
                    else
                        break;
                    j--;
                }
            }
            return;
        }
        rec(a, from, middle);
        rec(a, middle, to);
        doMerge(a, from, middle, to, middle - from, to - middle);
    }

    static function doMerge(a:Array<Visual>, from, pivot, to, len1, len2) {
        var first_cut, second_cut, len11, len22, new_mid;
        if (len1 == 0 || len2 == 0)
            return;
        if (len1 + len2 == 2) {
            if (compare(a, pivot, from) < 0)
                swap(a, pivot, from);
            return;
        }
        if (len1 > len2) {
            len11 = len1 >> 1;
            first_cut = from + len11;
            second_cut = lower(a, pivot, to, first_cut);
            len22 = second_cut - pivot;
        } else {
            len22 = len2 >> 1;
            second_cut = pivot + len22;
            first_cut = upper(a, from, pivot, second_cut);
            len11 = first_cut - from;
        }
        rotate(a, first_cut, pivot, second_cut);
        new_mid = first_cut + len22;
        doMerge(a, from, first_cut, new_mid, len11, len22);
        doMerge(a, new_mid, second_cut, to, len1 - len11, len2 - len22);
    }

    static inline function rotate(a:Array<Visual>, from, mid, to) {
        var n;
        if (from == mid || mid == to) return;
        n = gcd(to - from, mid - from);
        while (n-- != 0) {
            var val = a[from + n];
            var shift = mid - from;
            var p1 = from + n, p2 = from + n + shift;
            while (p2 != from + n) {
                a[p1] = a[p2];
                p1 = p2;
                if (to - p2 > shift) p2 += shift;
                else p2 = from + (shift - (to - p2));
            }
            a[p1] = val;
        }
    }

    static inline function gcd(m, n) {
        while (n != 0) {
            var t = m % n;
            m = n;
            n = t;
        }
        return m;
    }

    static inline function upper(a:Array<Visual>, from, to, val) {
        var len = to - from, half, mid;
        while (len > 0) {
            half = len >> 1;
            mid = from + half;
            if (compare(a, val, mid) < 0)
                len = half;
            else {
                from = mid + 1;
                len = len - half - 1;
            }
        }
        return from;
    }

    static inline function lower(a:Array<Visual>, from, to, val) {
        var len = to - from, half, mid;
        while (len > 0) {
            half = len >> 1;
            mid = from + half;
            if (compare(a, mid, val) < 0) {
                from = mid + 1;
                len = len - half - 1;
            } else
                len = half;
        }
        return from;
    }

    static inline function swap(a:Array<Visual>, i, j) {
        var tmp = a[i];
        a[i] = a[j];
        a[j] = tmp;
    }

    static inline function compare(a:Array<Visual>, i, j) {
        return cmp(a[i], a[j]);
    }

}

#end
