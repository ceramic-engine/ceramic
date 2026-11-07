// Ported from gpui-kit 0.8.1: crates/base/src/text/markdown_ext.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text;

import gpui.App;
import gpui.IntoElement;
import gpui.Window;
import markdown.mdast.Node;

/**
 * A reusable Markdown extension that parses and renders one custom node.
 *
 * Rust trait with default methods: extend this class, override `name` and
 * `parse`, and optionally `isBlock`, `render` and `renderInline`.
 */
abstract class MarkdownPlugin {

    /**
     * Whether this plugin produces block-level nodes.
     *
     * Plugins are inline by default. Block plugins should return `true`.
     */
    public function isBlock():Bool {
        return false;
    }

    /** Stable name for nodes produced by this plugin. */
    public abstract function name():String;

    /** Convert an mdast node into a custom Markdown node. */
    public abstract function parse(node:Node, cx:MarkdownParseContext):Null<MarkdownNode>;

    /** Render a custom Markdown node produced by this plugin. */
    public function render(node:MarkdownNode, window:Window, cx:App):IntoElement {
        return node.asText();
    }

    /**
     * Render an inline node using the existing `render` implementation.
     * Override this only when inherited layout context or an explicit
     * baseline is needed.
     */
    public function renderInline(node:MarkdownNode, context:InlineRenderContext, window:Window, cx:App):Null<InlineElement> {
        return new InlineElement(render(node, window, cx));
    }

}
