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
  * Simplified high-performance stable merge sort for Visual arrays based on depth only.
  * 
  * SortVisualsByDepth provides a streamlined sorting algorithm that orders visuals
  * purely by their depth property, ignoring other rendering criteria like texture
  * or blending mode. This makes it faster than SortVisuals when you only need
  * depth-based ordering.
  * 
  * Key characteristics:
  * - Sorts by depth only (higher depth values render on top)
  * - Stable sort: preserves relative order of visuals with equal depth
  * - Same optimizations as SortVisuals (inlining, unsafe access, insertion sort for small arrays)
  * - Faster than full SortVisuals when texture batching is not a concern
  * 
  * Use cases:
  * - UI elements where depth is the primary ordering criterion
  * - Debug visualizations
  * - Scenarios where draw call batching is less important than simplicity
  * 
  * Example usage:
  * ```haxe
  * var visuals:Array<Visual> = [...];
  * SortVisualsByDepth.sort(visuals); // Sorts in place by depth only
  * ```
  * 
  * @see ceramic.SortVisuals For complete rendering order sorting
  * @see ceramic.Visual.depth For the depth property
  */
 class SortVisualsByDepth {
 
     /**
      * Compares two visuals by depth only.
      * 
      * @param a First visual to compare
      * @param b Second visual to compare
      * @return -1 if a has lower depth, 1 if a has higher depth, 0 if equal
      */
     static inline function cmp(a:Visual, b:Visual):Int {
 
         var result = 0;
 
         if (a.depth > b.depth) {
             result = 1;
         }
         else if (a.depth < b.depth) {
             result = -1;
         }
 
         return result;
 
     }
 
     /**
      * Sorts an array of Visual objects in place by depth value only.
      * 
      * This is a simplified version of SortVisuals.sort() that only considers
      * the depth property. Visuals with higher depth values will be sorted
      * after (rendered on top of) visuals with lower depth values.
      * 
      * The sort is stable, preserving the relative order of visuals with
      * equal depth values. This operation modifies the array in place.
      * 
      * @param a The array of visuals to sort by depth. Modified in place.
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
 