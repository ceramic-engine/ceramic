// Ported from data-url 0.3.2 (https://github.com/servo/rust-url/tree/main/data-url): src/mime.rs (tests), tests/wpt.rs
// Original code Copyright 2013-2025 The rust-url developers, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import haxe.io.Bytes;
import glaze.kit.base.text.DataUrl;
import glaze.kit.base.text.DataUrl.Mime;
import glaze.kit.base.text.DataUrl.ForgivingBase64;
import testing.TestCase;

/**
 * Tests of `glaze.kit.base.text.DataUrl` (ported crate `data-url` 0.3.2:
 * `src/lib.rs`, `src/mime.rs`, `src/forgiving_base64.rs`).
 *
 * `testBasicMime` is `mime.rs`'s only `#[test]`. The others replay the
 * crate's `tests/wpt.rs` conformance fixtures (`tests/base64.json`,
 * `tests/data-urls.json`, `tests/mime-types.json`), embedded as data in
 * `DataUrlWptFixtures` below (`tests/generated-mime-types.json`, about 880
 * machine-generated cases / 61 KB, is not ported: disproportionate to this
 * task, and already covered in spirit by the curated `mime-types.json`
 * cases). `testDocExample` replays `lib.rs`'s module-level doc example (not
 * a `#[cfg(test)]` test, but a useful end-to-end smoke test of the ported
 * API).
 */
class TextDataUrlTest extends TestCase {

    function assertBytesEqual(expected:Array<Int>, actual:Null<Bytes>, ?message:String):Void {
        assertNotNull(actual, message);
        if (actual == null)
            return;
        assertEquals(expected.length, actual.length, message);
        if (expected.length != actual.length)
            return;
        for (i in 0...expected.length)
            assertEquals(expected[i], actual.get(i), (message != null ? message + ': ' : '') + 'byte $i');
    }

    function testDocExample() {
        final url = DataUrl.process("data:,Hello%20World!");
        assertNotNull(url);
        final decoded = url.decodeToVec();
        assertNotNull(decoded);
        assertTrue(url.mimeType().matches("text", "plain"));
        assertEquals("US-ASCII", url.mimeType().getParameter("charset"));
        assertBytesEqual(["H".code, "e".code, "l".code, "l".code, "o".code, " ".code, "W".code, "o".code, "r".code, "l".code, "d".code, "!".code], decoded.body);
        assertNull(decoded.fragment);
    }

    function testBasicMime() {
        final mime = new Mime("text", "plain");
        assertTrue(mime.matches("text", "plain"));

        final cloned = mime.clone();
        assertTrue(cloned.matches("text", "plain"));

        final mime2 = new Mime("text", "html", [{name: "one", value: "two"}]);
        assertTrue(mime2.matches("text", "html"));
    }

    function testWptBase64() {
        for (c in DataUrlWptFixtures.BASE64_CASES) {
            final result = ForgivingBase64.decodeToVec(Bytes.ofString(c.input));
            if (c.expected == null) {
                assertNull(result, 'base64 ${c.input}');
            } else {
                assertBytesEqual(c.expected, result, 'base64 ${c.input}');
            }
        }
    }

    function testWptDataUrls() {
        // Known upstream conformance gap (see `wpt.rs`'s `known_failures`):
        // this crate does not validate the URL authority at all (it never
        // parses one), so `data://test:test/,X` is accepted and decodes as
        // `text/plain;charset=US-ASCII` / "X" even though the WPT fixture
        // expects the browser's full URL parser to reject it earlier.
        // Reproduced as-is below, not fixed (see docs/DEVIATIONS.md policy).
        final knownFailure = "data://test:test/,X";

        for (c in DataUrlWptFixtures.DATA_URL_CASES) {
            final url = DataUrl.process(c.input);
            if (c.input == knownFailure) {
                assertNotNull(url, 'data: URL ${c.input}');
                assertTrue(url.mimeType().toString() == "text/plain;charset=US-ASCII", 'data: URL ${c.input}');
                final decoded = url.decodeToVec();
                assertNotNull(decoded, 'data: URL ${c.input}');
                continue;
            }
            if (c.expectedMime != null) {
                assertNotNull(url, 'data: URL ${c.input}');
                final decoded = url.decodeToVec();
                assertNotNull(decoded, 'data: URL ${c.input}');
                final expectedMime = c.expectedMime == "" ? "text/plain;charset=US-ASCII" : c.expectedMime;
                assertEquals(expectedMime, url.mimeType().toString(), 'data: URL ${c.input}');
                if (c.expectedBody != null)
                    assertBytesEqual(c.expectedBody, decoded.body, 'data: URL ${c.input}');
            } else if (url != null) {
                final decoded = url.decodeToVec();
                assertNull(decoded, 'data: URL ${c.input} (mime ${url.mimeType()})');
            }
        }
    }

    function testWptMimeTypes() {
        for (c in DataUrlWptFixtures.MIME_TYPE_CASES) {
            final parsed = Mime.parse(c.input);
            final label = (c.comment != null ? c.comment + ': ' : '') + c.input;
            if (c.output == null) {
                assertNull(parsed, label);
            } else {
                assertNotNull(parsed, label);
                if (parsed != null)
                    assertEquals(c.output, parsed.toString(), label);
            }
        }
    }

}

/**
 * Data from `data-url` 0.3.2's `tests/base64.json`, `tests/data-urls.json`
 * and `tests/mime-types.json` (<https://github.com/servo/rust-url>), MIT OR
 * Apache-2.0; data only, see NOTICE.md.
 */
private class DataUrlWptFixtures {

    public static final BASE64_CASES:Array<{input:String, expected:Null<Array<Int>>}> = [
        {input: "", expected: []},
        {input: "abcd", expected: [105, 183, 29]},
        {input: " abcd", expected: [105, 183, 29]},
        {input: "abcd ", expected: [105, 183, 29]},
        {input: " abcd===", expected: null},
        {input: "abcd=== ", expected: null},
        {input: "abcd ===", expected: null},
        {input: "a", expected: null},
        {input: "ab", expected: [105]},
        {input: "abc", expected: [105, 183]},
        {input: "abcde", expected: null},
        {input: "\u{10000}", expected: null},
        {input: "=", expected: null},
        {input: "==", expected: null},
        {input: "===", expected: null},
        {input: "====", expected: null},
        {input: "=====", expected: null},
        {input: "a=", expected: null},
        {input: "a==", expected: null},
        {input: "a===", expected: null},
        {input: "a====", expected: null},
        {input: "a=====", expected: null},
        {input: "ab=", expected: null},
        {input: "ab==", expected: [105]},
        {input: "ab===", expected: null},
        {input: "ab====", expected: null},
        {input: "ab=====", expected: null},
        {input: "abc=", expected: [105, 183]},
        {input: "abc==", expected: null},
        {input: "abc===", expected: null},
        {input: "abc====", expected: null},
        {input: "abc=====", expected: null},
        {input: "abcd=", expected: null},
        {input: "abcd==", expected: null},
        {input: "abcd===", expected: null},
        {input: "abcd====", expected: null},
        {input: "abcd=====", expected: null},
        {input: "abcde=", expected: null},
        {input: "abcde==", expected: null},
        {input: "abcde===", expected: null},
        {input: "abcde====", expected: null},
        {input: "abcde=====", expected: null},
        {input: "=a", expected: null},
        {input: "=a=", expected: null},
        {input: "a=b", expected: null},
        {input: "a=b=", expected: null},
        {input: "ab=c", expected: null},
        {input: "ab=c=", expected: null},
        {input: "abc=d", expected: null},
        {input: "abc=d=", expected: null},
        {input: "ab\u{b}cd", expected: null},
        {input: "ab\u{3000}cd", expected: null},
        {input: "ab\u{3001}cd", expected: null},
        {input: "ab\tcd", expected: [105, 183, 29]},
        {input: "ab\ncd", expected: [105, 183, 29]},
        {input: "ab\u{c}cd", expected: [105, 183, 29]},
        {input: "ab\rcd", expected: [105, 183, 29]},
        {input: "ab cd", expected: [105, 183, 29]},
        {input: "ab\u{a0}cd", expected: null},
        {input: "ab\t\n\u{c}\r cd", expected: [105, 183, 29]},
        {input: " \t\n\u{c}\r ab\t\n\u{c}\r cd\t\n\u{c}\r ", expected: [105, 183, 29]},
        {input: "ab\t\n\u{c}\r =\t\n\u{c}\r =\t\n\u{c}\r ", expected: [105]},
        {input: "A", expected: null},
        {input: "/A", expected: [252]},
        {input: "//A", expected: [255, 240]},
        {input: "///A", expected: [255, 255, 192]},
        {input: "////A", expected: null},
        {input: "/", expected: null},
        {input: "A/", expected: [3]},
        {input: "AA/", expected: [0, 15]},
        {input: "AAAA/", expected: null},
        {input: "AAA/", expected: [0, 0, 63]},
        {input: "\u{0}nonsense", expected: null},
        {input: "abcd\u{0}nonsense", expected: null},
        {input: "YQ", expected: [97]},
        {input: "YR", expected: [97]},
        {input: "~~", expected: null},
        {input: "..", expected: null},
        {input: "--", expected: null},
        {input: "__", expected: null},
    ];
    public static final DATA_URL_CASES:Array<{input:String, expectedMime:Null<String>, expectedBody:Null<Array<Int>>}> = [
        {input: "data://test/,X", expectedMime: "text/plain;charset=US-ASCII", expectedBody: [88]},
        {input: "data://test:test/,X", expectedMime: null, expectedBody: null},
        {input: "data:,X", expectedMime: "text/plain;charset=US-ASCII", expectedBody: [88]},
        {input: "data:", expectedMime: null, expectedBody: null},
        {input: "data:text/html", expectedMime: null, expectedBody: null},
        {input: "data:text/html    ;charset=x   ", expectedMime: null, expectedBody: null},
        {input: "data:,", expectedMime: "text/plain;charset=US-ASCII", expectedBody: []},
        {input: "data:,X#X", expectedMime: "text/plain;charset=US-ASCII", expectedBody: [88]},
        {input: "data:,%FF", expectedMime: "text/plain;charset=US-ASCII", expectedBody: [255]},
        {input: "data:text/plain,X", expectedMime: "text/plain", expectedBody: [88]},
        {input: "data:text/plain ,X", expectedMime: "text/plain", expectedBody: [88]},
        {input: "data:text/plain%20,X", expectedMime: "text/plain%20", expectedBody: [88]},
        {input: "data:text/plain\u{c},X", expectedMime: "text/plain%0c", expectedBody: [88]},
        {input: "data:text/plain%0C,X", expectedMime: "text/plain%0c", expectedBody: [88]},
        {input: "data:text/plain;,X", expectedMime: "text/plain", expectedBody: [88]},
        {input: "data:;x=x;charset=x,X", expectedMime: "text/plain;x=x;charset=x", expectedBody: [88]},
        {input: "data:;x=x,X", expectedMime: "text/plain;x=x", expectedBody: [88]},
        {input: "data:text/plain;charset=windows-1252,%C2%B1", expectedMime: "text/plain;charset=windows-1252", expectedBody: [194, 177]},
        {input: "data:text/plain;Charset=UTF-8,%C2%B1", expectedMime: "text/plain;charset=UTF-8", expectedBody: [194, 177]},
        {input: "data:text/plain,%", expectedMime: "text/plain", expectedBody: [37]},
        {input: "data:text/plain,X%", expectedMime: "text/plain", expectedBody: [88, 37]},
        {input: "data:text/plain,X%%", expectedMime: "text/plain", expectedBody: [88, 37, 37]},
        {input: "data:text/plain;Charset=UTF-8,X%X", expectedMime: "text/plain;charset=UTF-8", expectedBody: [88, 37, 88]},
        {input: "data:text/plain;Charset=UTF-8,X%0", expectedMime: "text/plain;charset=UTF-8", expectedBody: [88, 37, 48]},
        {input: "data:text/plain;Charset=UTF-8,X%0X", expectedMime: "text/plain;charset=UTF-8", expectedBody: [88, 37, 48, 88]},
        {input: "data:text/plain;charset=windows-1252,\u{e1}\u{f1}\u{e7}\u{259}\u{1f4a9}", expectedMime: "text/plain;charset=windows-1252", expectedBody: [195, 161, 195, 177, 195, 167, 201, 153, 240, 159, 146, 169]},
        {input: "data:text/plain;charset=UTF-8,\u{e1}\u{f1}\u{e7}\u{259}\u{1f4a9}", expectedMime: "text/plain;charset=UTF-8", expectedBody: [195, 161, 195, 177, 195, 167, 201, 153, 240, 159, 146, 169]},
        {input: "data:image/gif,%C2%B1", expectedMime: "image/gif", expectedBody: [194, 177]},
        {input: "data:IMAGE/gif,%C2%B1", expectedMime: "image/gif", expectedBody: [194, 177]},
        {input: "data:IMAGE/gif;hi=x,%C2%B1", expectedMime: "image/gif;hi=x", expectedBody: [194, 177]},
        {input: "data:IMAGE/gif;CHARSET=x,%C2%B1", expectedMime: "image/gif;charset=x", expectedBody: [194, 177]},
        {input: "data: ,%FF", expectedMime: "text/plain;charset=US-ASCII", expectedBody: [255]},
        {input: "data:%20,%FF", expectedMime: "text/plain;charset=US-ASCII", expectedBody: [255]},
        {input: "data:\u{c},%FF", expectedMime: "text/plain;charset=US-ASCII", expectedBody: [255]},
        {input: "data:%1F,%FF", expectedMime: "text/plain;charset=US-ASCII", expectedBody: [255]},
        {input: "data:\u{0},%FF", expectedMime: "text/plain;charset=US-ASCII", expectedBody: [255]},
        {input: "data:%00,%FF", expectedMime: "text/plain;charset=US-ASCII", expectedBody: [255]},
        {input: "data:text/html  ,X", expectedMime: "text/html", expectedBody: [88]},
        {input: "data:text / html,X", expectedMime: "text/plain;charset=US-ASCII", expectedBody: [88]},
        {input: "data:\u{2020},X", expectedMime: "text/plain;charset=US-ASCII", expectedBody: [88]},
        {input: "data:\u{2020}/\u{2020},X", expectedMime: "%e2%80%a0/%e2%80%a0", expectedBody: [88]},
        {input: "data:X,X", expectedMime: "text/plain;charset=US-ASCII", expectedBody: [88]},
        {input: "data:image/png,X X", expectedMime: "image/png", expectedBody: [88, 32, 88]},
        {input: "data:application/javascript,X X", expectedMime: "application/javascript", expectedBody: [88, 32, 88]},
        {input: "data:application/xml,X X", expectedMime: "application/xml", expectedBody: [88, 32, 88]},
        {input: "data:text/javascript,X X", expectedMime: "text/javascript", expectedBody: [88, 32, 88]},
        {input: "data:text/plain,X X", expectedMime: "text/plain", expectedBody: [88, 32, 88]},
        {input: "data:unknown/unknown,X X", expectedMime: "unknown/unknown", expectedBody: [88, 32, 88]},
        {input: "data:text/plain;a=\",\",X", expectedMime: "text/plain;a=\"\"", expectedBody: [34, 44, 88]},
        {input: "data:text/plain;a=%2C,X", expectedMime: "text/plain;a=%2C", expectedBody: [88]},
        {input: "data:;base64;base64,WA", expectedMime: "text/plain", expectedBody: [88]},
        {input: "data:x/x;base64;base64,WA", expectedMime: "x/x", expectedBody: [88]},
        {input: "data:x/x;base64;charset=x,WA", expectedMime: "x/x;charset=x", expectedBody: [87, 65]},
        {input: "data:x/x;base64;charset=x;base64,WA", expectedMime: "x/x;charset=x", expectedBody: [88]},
        {input: "data:x/x;base64;base64x,WA", expectedMime: "x/x", expectedBody: [87, 65]},
        {input: "data:;base64,W%20A", expectedMime: "text/plain;charset=US-ASCII", expectedBody: [88]},
        {input: "data:;base64,W%0CA", expectedMime: "text/plain;charset=US-ASCII", expectedBody: [88]},
        {input: "data:x;base64x,WA", expectedMime: "text/plain;charset=US-ASCII", expectedBody: [87, 65]},
        {input: "data:x;base64;x,WA", expectedMime: "text/plain;charset=US-ASCII", expectedBody: [87, 65]},
        {input: "data:x;base64=x,WA", expectedMime: "text/plain;charset=US-ASCII", expectedBody: [87, 65]},
        {input: "data:; base64,WA", expectedMime: "text/plain;charset=US-ASCII", expectedBody: [88]},
        {input: "data:;  base64,WA", expectedMime: "text/plain;charset=US-ASCII", expectedBody: [88]},
        {input: "data:  ;charset=x   ;  base64,WA", expectedMime: "text/plain;charset=x", expectedBody: [88]},
        {input: "data:;base64;,WA", expectedMime: "text/plain", expectedBody: [87, 65]},
        {input: "data:;base64 ,WA", expectedMime: "text/plain;charset=US-ASCII", expectedBody: [88]},
        {input: "data:;base64   ,WA", expectedMime: "text/plain;charset=US-ASCII", expectedBody: [88]},
        {input: "data:;base 64,WA", expectedMime: "text/plain", expectedBody: [87, 65]},
        {input: "data:;BASe64,WA", expectedMime: "text/plain;charset=US-ASCII", expectedBody: [88]},
        {input: "data:;%62ase64,WA", expectedMime: "text/plain", expectedBody: [87, 65]},
        {input: "data:%3Bbase64,WA", expectedMime: "text/plain;charset=US-ASCII", expectedBody: [87, 65]},
        {input: "data:;charset=x,X", expectedMime: "text/plain;charset=x", expectedBody: [88]},
        {input: "data:; charset=x,X", expectedMime: "text/plain;charset=x", expectedBody: [88]},
        {input: "data:;charset =x,X", expectedMime: "text/plain", expectedBody: [88]},
        {input: "data:;charset= x,X", expectedMime: "text/plain;charset=\" x\"", expectedBody: [88]},
        {input: "data:;charset=,X", expectedMime: "text/plain", expectedBody: [88]},
        {input: "data:;charset,X", expectedMime: "text/plain", expectedBody: [88]},
        {input: "data:;charset=\"x\",X", expectedMime: "text/plain;charset=x", expectedBody: [88]},
        {input: "data:;CHARSET=\"X\",X", expectedMime: "text/plain;charset=X", expectedBody: [88]},
    ];
    public static final MIME_TYPE_CASES:Array<{comment:Null<String>, input:String, output:Null<String>}> = [
        {comment: "Basics", input: "text/html;charset=gbk", output: "text/html;charset=gbk"},
        {comment: "Basics", input: "TEXT/HTML;CHARSET=GBK", output: "text/html;charset=GBK"},
        {comment: "Legacy comment syntax", input: "text/html;charset=gbk(", output: "text/html;charset=\"gbk(\""},
        {comment: "Legacy comment syntax", input: "text/html;x=(;charset=gbk", output: "text/html;x=\"(\";charset=gbk"},
        {comment: "Duplicate parameter", input: "text/html;charset=gbk;charset=windows-1255", output: "text/html;charset=gbk"},
        {comment: "Duplicate parameter", input: "text/html;charset=();charset=GBK", output: "text/html;charset=\"()\""},
        {comment: "Spaces", input: "text/html;charset =gbk", output: "text/html"},
        {comment: "Spaces", input: "text/html ;charset=gbk", output: "text/html;charset=gbk"},
        {comment: "Spaces", input: "text/html; charset=gbk", output: "text/html;charset=gbk"},
        {comment: "Spaces", input: "text/html;charset= gbk", output: "text/html;charset=\" gbk\""},
        {comment: "Spaces", input: "text/html;charset= \"gbk\"", output: "text/html;charset=\" \\\"gbk\\\"\""},
        {comment: "0x0B and 0x0C", input: "text/html;charset=\u{b}gbk", output: "text/html"},
        {comment: "0x0B and 0x0C", input: "text/html;charset=\u{c}gbk", output: "text/html"},
        {comment: "0x0B and 0x0C", input: "text/html;\u{b}charset=gbk", output: "text/html"},
        {comment: "0x0B and 0x0C", input: "text/html;\u{c}charset=gbk", output: "text/html"},
        {comment: "Single quotes are a token, not a delimiter", input: "text/html;charset='gbk'", output: "text/html;charset='gbk'"},
        {comment: "Single quotes are a token, not a delimiter", input: "text/html;charset='gbk", output: "text/html;charset='gbk"},
        {comment: "Single quotes are a token, not a delimiter", input: "text/html;charset=gbk'", output: "text/html;charset=gbk'"},
        {comment: "Single quotes are a token, not a delimiter", input: "text/html;charset=';charset=GBK", output: "text/html;charset='"},
        {comment: "Invalid parameters", input: "text/html;test;charset=gbk", output: "text/html;charset=gbk"},
        {comment: "Invalid parameters", input: "text/html;test=;charset=gbk", output: "text/html;charset=gbk"},
        {comment: "Invalid parameters", input: "text/html;';charset=gbk", output: "text/html;charset=gbk"},
        {comment: "Invalid parameters", input: "text/html;\";charset=gbk", output: "text/html;charset=gbk"},
        {comment: "Invalid parameters", input: "text/html ; ; charset=gbk", output: "text/html;charset=gbk"},
        {comment: "Invalid parameters", input: "text/html;;;;charset=gbk", output: "text/html;charset=gbk"},
        {comment: "Invalid parameters", input: "text/html;charset= \"\u{7f};charset=GBK", output: "text/html;charset=GBK"},
        {comment: "Invalid parameters", input: "text/html;charset=\"\u{7f};charset=foo\";charset=GBK", output: "text/html;charset=GBK"},
        {comment: "Double quotes", input: "text/html;charset=\"gbk\"", output: "text/html;charset=gbk"},
        {comment: "Double quotes", input: "text/html;charset=\"gbk", output: "text/html;charset=gbk"},
        {comment: "Double quotes", input: "text/html;charset=gbk\"", output: "text/html;charset=\"gbk\\\"\""},
        {comment: "Double quotes", input: "text/html;charset=\" gbk\"", output: "text/html;charset=\" gbk\""},
        {comment: "Double quotes", input: "text/html;charset=\"gbk \"", output: "text/html;charset=\"gbk \""},
        {comment: "Double quotes", input: "text/html;charset=\"\\ gbk\"", output: "text/html;charset=\" gbk\""},
        {comment: "Double quotes", input: "text/html;charset=\"\\g\\b\\k\"", output: "text/html;charset=gbk"},
        {comment: "Double quotes", input: "text/html;charset=\"gbk\"x", output: "text/html;charset=gbk"},
        {comment: "Double quotes", input: "text/html;charset=\"\";charset=GBK", output: "text/html;charset=\"\""},
        {comment: "Double quotes", input: "text/html;charset=\";charset=GBK", output: "text/html;charset=\";charset=GBK\""},
        {comment: "Unexpected code points", input: "text/html;charset={gbk}", output: "text/html;charset=\"{gbk}\""},
        {comment: "Parameter name longer than 127", input: "text/html;0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789=x;charset=gbk", output: "text/html;0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789=x;charset=gbk"},
        {comment: "type/subtype longer than 127", input: "0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789/0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789", output: "0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789/0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789"},
        {comment: "Invalid names", input: "text/html;a]=bar;b[=bar;c=bar", output: "text/html;c=bar"},
        {comment: "Semicolons in value", input: "text/html;valid=\";\";foo=bar", output: "text/html;valid=\";\";foo=bar"},
        {comment: "Semicolons in value", input: "text/html;in]valid=\";asd=foo\";foo=bar", output: "text/html;foo=bar"},
        {comment: "Valid", input: "!#$%&'*+-.^_`|~0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz/!#$%&'*+-.^_`|~0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz;!#$%&'*+-.^_`|~0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz=!#$%&'*+-.^_`|~0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz", output: "!#$%&'*+-.^_`|~0123456789abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz/!#$%&'*+-.^_`|~0123456789abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz;!#$%&'*+-.^_`|~0123456789abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz=!#$%&'*+-.^_`|~0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"},
        {comment: "Valid", input: "x/x;x=\"\t !\\\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\\\]^_`abcdefghijklmnopqrstuvwxyz{|}~\u{80}\u{81}\u{82}\u{83}\u{84}\u{85}\u{86}\u{87}\u{88}\u{89}\u{8a}\u{8b}\u{8c}\u{8d}\u{8e}\u{8f}\u{90}\u{91}\u{92}\u{93}\u{94}\u{95}\u{96}\u{97}\u{98}\u{99}\u{9a}\u{9b}\u{9c}\u{9d}\u{9e}\u{9f}\u{a0}\u{a1}\u{a2}\u{a3}\u{a4}\u{a5}\u{a6}\u{a7}\u{a8}\u{a9}\u{aa}\u{ab}\u{ac}\u{ad}\u{ae}\u{af}\u{b0}\u{b1}\u{b2}\u{b3}\u{b4}\u{b5}\u{b6}\u{b7}\u{b8}\u{b9}\u{ba}\u{bb}\u{bc}\u{bd}\u{be}\u{bf}\u{c0}\u{c1}\u{c2}\u{c3}\u{c4}\u{c5}\u{c6}\u{c7}\u{c8}\u{c9}\u{ca}\u{cb}\u{cc}\u{cd}\u{ce}\u{cf}\u{d0}\u{d1}\u{d2}\u{d3}\u{d4}\u{d5}\u{d6}\u{d7}\u{d8}\u{d9}\u{da}\u{db}\u{dc}\u{dd}\u{de}\u{df}\u{e0}\u{e1}\u{e2}\u{e3}\u{e4}\u{e5}\u{e6}\u{e7}\u{e8}\u{e9}\u{ea}\u{eb}\u{ec}\u{ed}\u{ee}\u{ef}\u{f0}\u{f1}\u{f2}\u{f3}\u{f4}\u{f5}\u{f6}\u{f7}\u{f8}\u{f9}\u{fa}\u{fb}\u{fc}\u{fd}\u{fe}\u{ff}\"", output: "x/x;x=\"\t !\\\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\\\]^_`abcdefghijklmnopqrstuvwxyz{|}~\u{80}\u{81}\u{82}\u{83}\u{84}\u{85}\u{86}\u{87}\u{88}\u{89}\u{8a}\u{8b}\u{8c}\u{8d}\u{8e}\u{8f}\u{90}\u{91}\u{92}\u{93}\u{94}\u{95}\u{96}\u{97}\u{98}\u{99}\u{9a}\u{9b}\u{9c}\u{9d}\u{9e}\u{9f}\u{a0}\u{a1}\u{a2}\u{a3}\u{a4}\u{a5}\u{a6}\u{a7}\u{a8}\u{a9}\u{aa}\u{ab}\u{ac}\u{ad}\u{ae}\u{af}\u{b0}\u{b1}\u{b2}\u{b3}\u{b4}\u{b5}\u{b6}\u{b7}\u{b8}\u{b9}\u{ba}\u{bb}\u{bc}\u{bd}\u{be}\u{bf}\u{c0}\u{c1}\u{c2}\u{c3}\u{c4}\u{c5}\u{c6}\u{c7}\u{c8}\u{c9}\u{ca}\u{cb}\u{cc}\u{cd}\u{ce}\u{cf}\u{d0}\u{d1}\u{d2}\u{d3}\u{d4}\u{d5}\u{d6}\u{d7}\u{d8}\u{d9}\u{da}\u{db}\u{dc}\u{dd}\u{de}\u{df}\u{e0}\u{e1}\u{e2}\u{e3}\u{e4}\u{e5}\u{e6}\u{e7}\u{e8}\u{e9}\u{ea}\u{eb}\u{ec}\u{ed}\u{ee}\u{ef}\u{f0}\u{f1}\u{f2}\u{f3}\u{f4}\u{f5}\u{f6}\u{f7}\u{f8}\u{f9}\u{fa}\u{fb}\u{fc}\u{fd}\u{fe}\u{ff}\""},
        {comment: "End-of-file handling", input: "x/x;test", output: "x/x"},
        {comment: "End-of-file handling", input: "x/x;test=\"\\", output: "x/x;test=\"\\\\\""},
        {comment: "Whitespace (not handled by generated-mime-types.json or above)", input: "x/x;x= ", output: "x/x"},
        {comment: "Whitespace (not handled by generated-mime-types.json or above)", input: "x/x;x=\t", output: "x/x"},
        {comment: "Whitespace (not handled by generated-mime-types.json or above)", input: "x/x\n\r\t ;x=x", output: "x/x;x=x"},
        {comment: "Whitespace (not handled by generated-mime-types.json or above)", input: "\n\r\t x/x;x=x\n\r\t ", output: "x/x;x=x"},
        {comment: "Whitespace (not handled by generated-mime-types.json or above)", input: "x/x;\n\r\t x=x\n\r\t ;x=y", output: "x/x;x=x"},
        {comment: "Latin1", input: "text/html;test=\u{ff};charset=gbk", output: "text/html;test=\"\u{ff}\";charset=gbk"},
        {comment: ">Latin1", input: "x/x;test=\u{fffd};x=x", output: "x/x;x=x"},
        {comment: "Failure", input: "\u{b}x/x", output: null},
        {comment: "Failure", input: "\u{c}x/x", output: null},
        {comment: "Failure", input: "x/x\u{b}", output: null},
        {comment: "Failure", input: "x/x\u{c}", output: null},
        {comment: "Failure", input: "", output: null},
        {comment: "Failure", input: "\t", output: null},
        {comment: "Failure", input: "/", output: null},
        {comment: "Failure", input: "bogus", output: null},
        {comment: "Failure", input: "bogus/", output: null},
        {comment: "Failure", input: "bogus/ ", output: null},
        {comment: "Failure", input: "bogus/bogus/;", output: null},
        {comment: "Failure", input: "</>", output: null},
        {comment: "Failure", input: "(/)", output: null},
        {comment: "Failure", input: "\u{ff}/\u{ff}", output: null},
        {comment: "Failure", input: "text/html(;doesnot=matter", output: null},
        {comment: "Failure", input: "{/}", output: null},
        {comment: "Failure", input: "\u{100}/\u{100}", output: null},
        {comment: "Failure", input: "text /html", output: null},
        {comment: "Failure", input: "text/ html", output: null},
        {comment: "Failure", input: "\"text/html\"", output: null},
    ];
}
