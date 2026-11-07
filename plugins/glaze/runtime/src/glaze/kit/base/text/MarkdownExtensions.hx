// Ported from gpui-kit 0.8.1: crates/base/src/text/markdown_ext.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.text;

import glaze.AnyElement;
import glaze.App;
import glaze.IntoElement;
import glaze.Window;
import markdown.ParseOptions;
import markdown.mdast.Node;

/**
 * Type for a custom Markdown block parser.
 *
 * Parsers run during Markdown AST conversion. They must not depend on
 * `Window` or `App`; return parsed, reusable data in a `MarkdownNode` and
 * render it later with a block renderer.
 */
typedef MarkdownBlockParserFn = (node:Node, cx:MarkdownParseContext) -> Null<MarkdownNode>;

/** Type for a custom Markdown block renderer. */
typedef MarkdownBlockRenderFn = (node:MarkdownNode, window:Window, cx:App) -> AnyElement;

/** Parser for a single inline AST node; follows the block parser contract. */
typedef MarkdownInlineParserFn = MarkdownBlockParserFn;

/**
 * Produces a native GPUI inline element, or `null` for atomic text
 * fallback. Read prepared resources here; start asynchronous work outside
 * rendering.
 */
typedef MarkdownInlineRenderFn = (node:MarkdownNode, context:InlineRenderContext, window:Window, cx:App) -> Null<InlineElement>;

/**
 * Registry for custom Markdown parsing and rendering.
 *
 * The builders return a modified copy, like the Rust `mut self` builders on
 * a `Clone` type (the registered functions are shared).
 */
class MarkdownExtensions {

    static var MARKDOWN_EXTENSIONS_REVISION:Int = 1;

    var enableMdx:Bool = false;
    var enableFrontmatter:Bool = false;
    var blockParsers:Array<MarkdownBlockParserFn> = [];
    var blockRenderers:Map<String, MarkdownBlockRenderFn> = new Map();
    var inlineParsers:Array<MarkdownInlineParserFn> = [];
    var inlineRenderers:Map<String, MarkdownInlineRenderFn> = new Map();
    var revision_:Int = 0;
    var parserRevision_:Int = 0;

    public function new() {}

    /** Rust `Clone`. */
    public function clone():MarkdownExtensions {
        final ext = new MarkdownExtensions();
        ext.enableMdx = enableMdx;
        ext.enableFrontmatter = enableFrontmatter;
        ext.blockParsers = blockParsers.copy();
        ext.blockRenderers = blockRenderers.copy();
        ext.inlineParsers = inlineParsers.copy();
        ext.inlineRenderers = inlineRenderers.copy();
        ext.revision_ = revision_;
        ext.parserRevision_ = parserRevision_;
        return ext;
    }

    /**
     * Change this revision when parser captures or plugin configuration
     * change. Reusing it allows equivalent registrations rebuilt during
     * rendering to retain the parsed document. Renderer-only changes do not
     * need a new value.
     */
    public function parserRevision(revision:Int):MarkdownExtensions {
        final ext = clone();
        ext.parserRevision_ = revision;
        ext.bumpRevision();
        return ext;
    }

    /**
     * Enable YAML frontmatter parsing.
     *
     * Frontmatter is disabled by default because it is not part of
     * CommonMark or GFM. Register a block parser or `MarkdownPlugin` to
     * render the resulting `Node.Yaml` node.
     */
    public function frontmatter():MarkdownExtensions {
        final ext = clone();
        ext.enableFrontmatter = true;
        ext.bumpRevision();
        return ext;
    }

    /**
     * Enable MDX JSX/expression constructs.
     *
     * This disables raw HTML constructs because `markdown-rs` gives HTML
     * priority over MDX when both are enabled.
     */
    public function mdx():MarkdownExtensions {
        final ext = clone();
        ext.enableMdx = true;
        ext.bumpRevision();
        return ext;
    }

    /** Register a parser for block-level Markdown AST nodes. */
    public function blockParser(parser:MarkdownBlockParserFn):MarkdownExtensions {
        final ext = clone();
        ext.pushBlockParser(parser);
        return ext;
    }

    /** Register a renderer for a custom block node name. */
    public function blockRenderer(name:String, renderer:(node:MarkdownNode, window:Window, cx:App) -> IntoElement):MarkdownExtensions {
        final ext = clone();
        ext.pushBlockRenderer(name, renderer);
        return ext;
    }

    /** Apply a reusable Markdown plugin. */
    public function plugin(plugin:MarkdownPlugin):MarkdownExtensions {
        final name = plugin.name();
        if (plugin.isBlock()) {
            final extensions = blockParser((node, cx) -> plugin.parse(node, cx));
            extensions.pushBlockRenderer(name, (node, window, cx) -> plugin.render(node, window, cx));
            return extensions;
        } else {
            final extensions = clone();
            extensions.inlineParsers.push((node, cx) -> plugin.parse(node, cx));
            extensions.inlineRenderers.set(name, (node, context, window, cx) -> plugin.renderInline(node, context, window, cx));
            extensions.bumpRevision();
            return extensions;
        }
    }

    @:allow(glaze.kit.base.text)
    function revision():Int {
        return revision_;
    }

    /**
     * Whether replacing these extension handles can change the parsed tree.
     *
     * Render methods commonly rebuild equivalent plugin closures every frame.
     * Their globally unique revisions differ, but the parser shape remains
     * stable; render handles may be refreshed without reparsing the
     * document.
     */
    @:allow(glaze.kit.base.text)
    function hasSameParserConfiguration(other:MarkdownExtensions):Bool {
        if (!(parserRevision_ == other.parserRevision_ && enableMdx == other.enableMdx && enableFrontmatter == other.enableFrontmatter
            && blockParsers.length == other.blockParsers.length && mapCount(blockRenderers) == mapCount(other.blockRenderers)
            && inlineParsers.length == other.inlineParsers.length && mapCount(inlineRenderers) == mapCount(other.inlineRenderers)))
            return false;
        for (name in inlineRenderers.keys()) {
            if (!other.inlineRenderers.exists(name))
                return false;
        }
        for (name in blockRenderers.keys()) {
            if (!other.blockRenderers.exists(name))
                return false;
        }
        return true;
    }

    static function mapCount<T>(map:Map<String, T>):Int {
        var count = 0;
        for (_ in map.keys())
            count++;
        return count;
    }

    @:allow(glaze.kit.base.text)
    function pushBlockParser(parser:MarkdownBlockParserFn):Void {
        blockParsers.push(parser);
        bumpRevision();
    }

    @:allow(glaze.kit.base.text)
    function pushBlockRenderer(name:String, renderer:(node:MarkdownNode, window:Window, cx:App) -> IntoElement):Void {
        blockRenderers.set(name, (node, window, cx) -> renderer(node, window, cx).intoAnyElement());
        bumpRevision();
    }

    @:allow(glaze.kit.base.text)
    function parseOptions():ParseOptions {
        final options = ParseOptions.gfm();
        options.constructs.frontmatter = enableFrontmatter;
        options.constructs.mathText = true;
        // Both fences or neither: with only `mathText` on, the inline
        // construct swallows a `$$` block, so a block plugin matching
        // `Node.Math` never fires and the formula renders inline.
        options.constructs.mathFlow = true;
        if (enableMdx) {
            options.constructs.htmlFlow = false;
            options.constructs.htmlText = false;
            options.constructs.mdxExpressionFlow = true;
            options.constructs.mdxExpressionText = true;
            options.constructs.mdxJsxFlow = true;
            options.constructs.mdxJsxText = true;
        }
        return options;
    }

    @:allow(glaze.kit.base.text)
    function parseBlock(node:Node, cx:MarkdownParseContext):Null<MarkdownNode> {
        for (parser in blockParsers) {
            final result = parser(node, cx);
            if (result != null)
                return result;
        }
        return null;
    }

    @:allow(glaze.kit.base.text)
    function parseInline(node:Node, cx:MarkdownParseContext):Null<MarkdownNode> {
        for (parser in inlineParsers) {
            final result = parser(node, cx);
            if (result != null)
                return result;
        }
        return null;
    }

    @:allow(glaze.kit.base.text)
    function renderInline(node:MarkdownNode, context:InlineRenderContext, window:Window, cx:App):Null<InlineElement> {
        final render = inlineRenderers.get(node.name());
        return render != null ? render(node, context, window, cx) : null;
    }

    @:allow(glaze.kit.base.text)
    function renderBlock(node:MarkdownNode, window:Window, cx:App):Null<AnyElement> {
        final render = blockRenderers.get(node.name());
        return render != null ? render(node, window, cx) : null;
    }

    function bumpRevision():Void {
        revision_ = MARKDOWN_EXTENSIONS_REVISION++;
    }

}
