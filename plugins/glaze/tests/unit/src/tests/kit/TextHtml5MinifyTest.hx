// Ported from gpui-kit 0.8.1: crates/base/src/text/format/html5minify/mod.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// That file is a fork of the html5minify crate (https://github.com/martingallagher/html5minify),
// by Martin Gallagher, licensed under MIT (html5minify 0.3.3 Cargo.toml).
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.base.text.format.html5minify.Minifier;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import testing.TestCase;

/**
 * Tests of `gpui.base.text.format.html5minify.Minifier` (Rust
 * `text/format/html5minify/mod.rs`).
 */
class TextHtml5MinifyTest extends TestCase {

    function testWriteCollapseWhitespace() {
        final cases:Array<{input:String, expected:String, precedingWhitespace:Bool}> = [
            {input: "", expected: "", precedingWhitespace: false},
            {input: "  ", expected: " ", precedingWhitespace: false},
            {input: "   ", expected: " ", precedingWhitespace: false},
            {input: "   ", expected: "", precedingWhitespace: true},
            {input: " x      y  ", expected: " x y ", precedingWhitespace: false},
            {input: " x      y  ", expected: "x y ", precedingWhitespace: true},
            {input: " x   \n  \t \n   y  ", expected: " x y ", precedingWhitespace: false},
            {input: " x   \n  \t \n   y  ", expected: "x y ", precedingWhitespace: true},
        ];
        for (c in cases) {
            final w = new BytesOutput();
            final minifier = new Minifier(w);
            @:privateAccess minifier.precedingWhitespace = c.precedingWhitespace;
            @:privateAccess minifier.writeCollapseWhitespace(c.input, Minifier.reservedEntity, c.precedingWhitespace);

            final s = w.getBytes().toString();

            assertEquals(c.expected, s);
        }
    }

    function testOmitTags() {
        final cases:Array<{input:String, expected:String, collapseWhitespace:Bool, preserveComments:Bool}> = [
            // <html>
            {input: "<html>", expected: "", collapseWhitespace: true, preserveComments: false},
            // Comments ignored
            {input: "<html><!-- -->", expected: "", collapseWhitespace: true, preserveComments: false},
            // Comments preserved
            {input: "<html>     <!-- -->    ", expected: "<html><!-- -->", collapseWhitespace: true, preserveComments: true},
            {input: "<html><!-- --></html>", expected: "<html><!-- -->", collapseWhitespace: true, preserveComments: true},
            {
                input: "<html><!-- --></html><!-- -->",
                expected: "<html><!-- --></html><!-- -->",
                collapseWhitespace: true,
                preserveComments: true
            },
            {
                input: "<html>    <!-- -->    </html>    <!-- -->    ",
                expected: "<html><!-- --></html><!-- -->",
                collapseWhitespace: true,
                preserveComments: true
            },
            {
                input: "<html>    <!-- -->    </html>    <!-- -->    ",
                // <body> is implicitly added to the DOM
                expected: "<html><!-- --><body>        </html><!-- -->",
                collapseWhitespace: false,
                preserveComments: true
            },
            // <head>
            {
                input: "<html>   <head>   <title>A</title>     </head>   <body><p>     B  </p> </body>",
                expected: "<title>A</title><p>B",
                collapseWhitespace: true,
                preserveComments: false
            },
            {
                input: "<html>   <head>   <title>A</title>     </head>   <body><p>     B  </p> </body>",
                expected: "<head>   <title>A</title>     </head>   <p>     B   ",
                collapseWhitespace: false,
                preserveComments: false
            },
            {
                input: "<html>   <head><!-- -->   <title>A</title>     </head>   <body><p>     B  </p> </body>",
                expected: "<head><!-- --><title>A</title><p>B",
                collapseWhitespace: true,
                preserveComments: true
            },
            // <body>
            {input: "<body>", expected: "", collapseWhitespace: true, preserveComments: false},
            {
                input: "<body>    <script>let x = 1;</script>   ",
                expected: "<body><script>let x = 1;</script>",
                collapseWhitespace: true,
                preserveComments: false
            },
            {
                input: "<body>        <style>body{margin:1em}</style>",
                expected: "<body><style>body{margin:1em}</style>",
                collapseWhitespace: true,
                preserveComments: false
            },
            {input: "<body>    <p>A", expected: "<p>A", collapseWhitespace: true, preserveComments: false},
            {input: "<body id=main>    <p>A", expected: "<body id=main><p>A", collapseWhitespace: true, preserveComments: false},
            // Retain whitespace, whitespace before <p>
            {input: "    <body>    <p>A      ", expected: "<body>    <p>A      ", collapseWhitespace: false, preserveComments: false},
            // Retain whitespace, touching <p>
            {input: "<body><p>A</body>", expected: "<p>A", collapseWhitespace: false, preserveComments: false},
            // Comments ignored
            {input: "<body><p>A</body><!-- -->", expected: "<p>A", collapseWhitespace: false, preserveComments: false},
            // Comments preserved
            {input: "<body><p>A</body><!-- -->", expected: "<body><p>A</body><!-- -->", collapseWhitespace: false, preserveComments: true},
            // Retain end tag if touching inline element
            {
                input: "<p>Some text</p><button></button>",
                expected: "<p>Some text</p><button></button>",
                collapseWhitespace: false,
                preserveComments: false
            },
        ];
        for (c in cases) {
            final w = new BytesOutput();
            final minifier = new Minifier(w);
            minifier.omitDoctype(true).collapseWhitespace(c.collapseWhitespace).preserveComments(c.preserveComments);
            minifier.minify(new BytesInput(Bytes.ofString(c.input)));

            final s = w.getBytes().toString();

            assertEquals(c.expected, s);
        }
    }

}
