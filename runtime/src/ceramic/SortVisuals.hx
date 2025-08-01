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

package ceramic;

using ceramic.Extensions;

/**
 * High-performance stable merge sort implementation specifically optimized for Visual arrays.
 * 
 * SortVisuals provides a specialized sorting algorithm for rendering order in Ceramic.
 * It implements a stable merge sort that preserves the relative order of visuals with
 * equal sorting criteria, which is crucial for consistent rendering behavior across
 * all platforms.
 * 
 * The sorting criteria hierarchy:
 * 1. Invisible/untouchable visuals are sorted first (behind everything)
 * 2. Render target priority (higher priority renders on top)
 * 3. Depth value (higher depth renders on top)
 * 4. For Quads/Meshes with same depth:
 *    - Texture index (lower index renders on top for batching efficiency)
 *    - Blending mode (for draw call batching)
 * 
 * This implementation is heavily optimized:
 * - All methods are inlined for maximum performance
 * - Uses unsafe array access to avoid bounds checking
 * - Switches to insertion sort for small arrays (< 12 elements)
 * - Custom comparison function optimized for Visual properties
 * 
 * Example usage:
 * ```haxe
 * var visuals:Array<Visual> = [...];
 * SortVisuals.sort(visuals); // Sorts in place
 * ```
 * 
 * Note: This class is used internally by the rendering system and typically
 * doesn't need to be called directly unless implementing custom rendering logic.
 * 
 * Based on Haxe's stable sort implementation with Visual-specific optimizations.
 * 
 * @see ceramic.Visual For the visual hierarchy
 * @see ceramic.SortVisualsByDepth For depth-only sorting
 */
class SortVisuals {

    /**
     * Compares two visuals for rendering order.
     * 
     * @param a First visual to compare
     * @param b Second visual to compare
     * @return -1 if a should render before b, 1 if b should render before a, 0 if equal
     */
    static inline function cmp(a:Visual, b:Visual):Int {

        var result = 0;

        if (!a.computedVisible && !a.computedTouchable) {
            result = -1;
        }
        else if (!b.computedVisible && !b.computedTouchable) {
            result = 1;
        }
        else if (a.computedRenderTarget != b.computedRenderTarget) {
            if (a.computedRenderTarget == null) result = 1;
            else if (b.computedRenderTarget == null) result = -1;
            else if (a.computedRenderTarget.priority > b.computedRenderTarget.priority) result = -1;
            else if (a.computedRenderTarget.priority < b.computedRenderTarget.priority) result = 1;
            else if (a.computedRenderTarget.index < b.computedRenderTarget.index) result = -1;
            else result = 1;
        }
        else if (a.computedDepth > b.computedDepth) {
            result = 1;
        }
        else if (a.computedDepth < b.computedDepth) {
            result = -1;
        }
        else {
            var aQuad:Quad = a.asQuad;
            var bQuad:Quad = b.asQuad;
            var aMesh:Mesh = a.asMesh;
            var bMesh:Mesh = b.asMesh;
            var aIsQuadOrMesh = aQuad != null || aMesh != null;
            var bIsQuadOrMesh = bQuad != null || bMesh != null;

            if (aIsQuadOrMesh && bIsQuadOrMesh) {
                var aTexture = aMesh != null ? aMesh.texture : aQuad.texture;
                var bTexture = bMesh != null ? bMesh.texture : bQuad.texture;
                if (aTexture != null && bTexture == null) result = 1;
                else if (aTexture == null && bTexture != null) result = -1;
                else if (aTexture != null && bTexture != null) {
                    if (aTexture.index < bTexture.index) result = 1;
                    else if (aTexture.index > bTexture.index) result = -1;
                    else if ((a.blending:Int) > (b.blending:Int)) result = 1;
                    else if ((a.blending:Int) < (b.blending:Int)) result = -1;
                }
                else if ((a.blending:Int) > (b.blending:Int)) result = 1;
                else if ((a.blending:Int) < (b.blending:Int)) result = -1;
            }
        }

        return result;

    }

    /**
     * Sorts an array of Visual objects in place for optimal rendering order.
     * 
     * This operation modifies the input array directly. The sort is stable,
     * meaning visuals with equal sorting criteria maintain their relative order.
     * This is important for predictable rendering when multiple visuals have
     * the same depth and properties.
     * 
     * The algorithm automatically chooses between merge sort for larger arrays
     * and insertion sort for small arrays (< 12 elements) for optimal performance.
     * 
     * @param a The array of visuals to sort. Modified in place.
     *          If null, behavior is undefined.
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
            var k = from + n;
            var val = a.unsafeGet(k);
            var shift = mid - from;
            var p1 = from + n, p2 = from + n + shift;
            while (p2 != from + n) {
                a.unsafeSet(p1, a.unsafeGet(p2));
                p1 = p2;
                if (to - p2 > shift) p2 += shift;
                else p2 = from + (shift - (to - p2));
            }
            a.unsafeSet(p1, val);
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
        var tmp = a.unsafeGet(i);
        a.unsafeSet(i, a.unsafeGet(j));
        a.unsafeSet(j, tmp);
    }

    static inline function compare(a:Array<Visual>, i, j) {
        return cmp(a.unsafeGet(i), a.unsafeGet(j));
    }

}
