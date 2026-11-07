// Ported from gpui-kit 0.8.1: crates/base/src/text/document.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.base.text.NodeContext;
import gpui.base.text.ParsedDocument;
import gpui.base.text.PrevBlock;
import gpui.base.text.format.MarkdownFormat;
import testing.TestCase;

/**
 * Tests of document.rs: where a block stands in its flow.
 */
class TextDocumentTest extends TestCase {

    static function positions(source:String):Array<String> {
        final document = MarkdownFormat.parse(source, new NodeContext());
        return [for (ix in 0...document.blocks.length) describe(ParsedDocument.flowPosition(document.blocks, ix))];
    }

    static function describe(position:{isFirst:Bool, prev:PrevBlock}):String {
        return '(${position.isFirst}, ${Std.string(position.prev)})';
    }

    function testFlowPositionSkipsBlocksThatRenderNothing() {
        // The definition renders nothing, so the heading still opens the flow.
        final flow = positions("[ref]: https://example.com\n\n# Title\n\ntext");
        assertEquals(describe({isFirst: true, prev: Other}), flow[1]);
        assertEquals(describe({isFirst: false, prev: Heading(1)}), flow[2]);
    }

    function testFlowPositionReportsThePreviousHeadingOrRule() {
        final flow = positions("text\n\n## A\n\n---\n\n### B");
        assertEquals([
            describe({isFirst: true, prev: Other}),
            describe({isFirst: false, prev: Other}),
            describe({isFirst: false, prev: Heading(2)}),
            describe({isFirst: false, prev: Rule})
        ].join(' '), flow.join(' '));
    }

}
