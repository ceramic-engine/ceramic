// Ported from gpui-kit 0.8.1: crates/base/src/text/utils.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.ImageFormat;
import gpui.base.text.TextUtils;
import testing.TestCase;

/**
 * Tests of `gpui.base.text.TextUtils` (Rust `text/utils.rs`).
 */
class TextUtilsTest extends TestCase {

    function testDataUrlImage() {
        function image(url:String):{format:ImageFormat, bytes:Array<Int>} {
            final img = TextUtils.dataUrlImage(url);
            assertNotNull(img, 'expected an embedded image for $url');
            final bytes = [for (i in 0...img.bytes.length) img.bytes.get(i)];
            return {format: img.format, bytes: bytes};
        }

        var result = image("data:image/png;base64,iVBORw0KGgo=");
        assertEquals(Png, result.format);
        assertEquals('137,80,78,71,13,10,26,10', result.bytes.join(','));

        // Legacy mime aliases and the percent-encoded (non-base64) body form.
        result = image("data:image/jpg;base64,/9j/4A==");
        assertEquals(Jpeg, result.format);
        assertEquals('255,216,255,224', result.bytes.join(','));

        result = image("data:image/svg+xml,%3Csvg%3E%3C/svg%3E");
        assertEquals(Svg, result.format);
        assertEquals([for (i in 0...'<svg></svg>'.length) '<svg></svg>'.charCodeAt(i)].join(','), result.bytes.join(','));

        assertNull(TextUtils.dataUrlImage("https://example.com/logo.png"));
        assertNull(TextUtils.dataUrlImage("data:text/plain;base64,aGVsbG8="));
        assertNull(TextUtils.dataUrlImage("data:image/png;base64,not*base64"));
        assertNull(TextUtils.dataUrlImage("data:image/png"));
    }

    function testListItemPrefix() {
        assertEquals("1. ", TextUtils.listItemPrefix(0, 1, true, 0));
        assertEquals("2. ", TextUtils.listItemPrefix(1, 1, true, 0));
        assertEquals("3. ", TextUtils.listItemPrefix(2, 1, true, 0));
        assertEquals("11. ", TextUtils.listItemPrefix(10, 1, true, 0));
        assertEquals("3. ", TextUtils.listItemPrefix(0, 3, true, 0));
        assertEquals("4. ", TextUtils.listItemPrefix(1, 3, true, 0));
        assertEquals("A. ", TextUtils.listItemPrefix(0, 1, true, 1));
        assertEquals("B. ", TextUtils.listItemPrefix(1, 1, true, 1));
        assertEquals("D. ", TextUtils.listItemPrefix(0, 4, true, 1));
        assertEquals("E. ", TextUtils.listItemPrefix(1, 4, true, 1));
        assertEquals("a. ", TextUtils.listItemPrefix(0, 1, true, 2));
        assertEquals("b. ", TextUtils.listItemPrefix(1, 1, true, 2));
        assertEquals("g. ", TextUtils.listItemPrefix(6, 1, true, 2));
        assertEquals("0. ", TextUtils.listItemPrefix(0, 0, true, 1));
        assertEquals("1. ", TextUtils.listItemPrefix(1, 0, true, 1));
        assertEquals("• ", TextUtils.listItemPrefix(0, null, false, 0));
        assertEquals("◦ ", TextUtils.listItemPrefix(0, null, false, 1));
        assertEquals("▪ ", TextUtils.listItemPrefix(0, null, false, 2));
        assertEquals("‣ ", TextUtils.listItemPrefix(0, null, false, 3));
        assertEquals("⁃ ", TextUtils.listItemPrefix(0, null, false, 4));
    }

}
