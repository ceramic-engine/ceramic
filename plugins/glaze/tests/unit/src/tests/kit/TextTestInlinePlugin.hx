// Ported from gpui-kit 0.8.1: crates/base/src/text/markdown_ext.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.App;
import gpui.Window;
import gpui.base.text.InlineElement;
import gpui.base.text.InlineRenderContext;
import gpui.base.text.MarkdownNode;
import gpui.base.text.MarkdownParseContext;
import gpui.base.text.MarkdownPlugin;
import markdown.mdast.Node;

/**
 * Test fixture that exercises the same plugin registration path as
 * applications (Rust `text/markdown_ext.rs`'s `#[cfg(test)] TestInlinePlugin`).
 *
 * `markdown_ext.rs` itself has no `#[cfg(test)] mod tests`: this fixture is
 * used by the `#[cfg(test)]` modules of other files (e.g. `document.rs`),
 * so it is ported here, in its own file, for other test files to reuse.
 */
class TextTestInlinePlugin extends MarkdownPlugin {

    final name_:String;
    var parser:Null<(node:Node, cx:MarkdownParseContext) -> Null<MarkdownNode>> = null;
    var renderer:Null<(node:MarkdownNode, context:InlineRenderContext, window:Window, cx:App) -> Null<InlineElement>> = null;

    public function new(name:String) {
        name_ = name;
    }

    public function parseWith(parser:(node:Node, cx:MarkdownParseContext) -> Null<MarkdownNode>):TextTestInlinePlugin {
        this.parser = parser;
        return this;
    }

    public function renderWith(renderer:(node:MarkdownNode, context:InlineRenderContext, window:Window, cx:App) -> Null<InlineElement>):TextTestInlinePlugin {
        this.renderer = renderer;
        return this;
    }

    public function name():String {
        return name_;
    }

    public function parse(node:Node, cx:MarkdownParseContext):Null<MarkdownNode> {
        return parser != null ? parser(node, cx) : null;
    }

    override public function renderInline(node:MarkdownNode, context:InlineRenderContext, window:Window, cx:App):Null<InlineElement> {
        return renderer != null ? renderer(node, context, window, cx) : null;
    }

}
