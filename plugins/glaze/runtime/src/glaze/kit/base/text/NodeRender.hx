// Ported from gpui-kit 0.8.1: crates/base/src/text/node.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.text;

import glaze.AnyElement;
import glaze.App;
import glaze.Axis;
import glaze.Bounds;
import glaze.DefiniteLength;
import glaze.Div;
import glaze.Element;
import glaze.ElementId;
import glaze.FontStyle;
import glaze.FontWeight;
import glaze.GlobalElementId;
import glaze.HighlightStyle;
import glaze.Hsla;
import glaze.Image;
import glaze.ImageFormat;
import glaze.LayoutId;
import glaze.ObjectFit;
import glaze.Overflow;
import glaze.Pixels;
import glaze.Range;
import glaze.Rems;
import glaze.ScrollHandle;
import glaze.StrikethroughStyle;
import glaze.StyleRefinement;
import glaze.TextStyleRefinement;
import glaze.UnderlineStyle;
import glaze.WhiteSpace;
import glaze.Window;
import glaze.kit.base.GlobalState;
import glaze.kit.base.ScrollableMask;
import glaze.kit.base.Scrollbar;
import glaze.kit.base.text.InlineFlow.InlineFlowItem;
import glaze.kit.base.text.Paragraph.ParagraphRender;
import glaze.kit.base.text.Table.TableColumnWidths;
import glaze.kit.base.text.Table.TableTextStyles;
import glaze.kit.base.theme.Theme;
import glaze.util.Utf8;
import haxe.io.Bytes;

import glaze.Prelude.*;

using glaze.AbsoluteLengthTools;
using glaze.ParentElementTools;
using glaze.kit.base.StyledExt;

/**
 * The render half of node.rs: `BlockNode::render_block`, the paragraph,
 * code block, list and table renders, their helpers, and the
 * `TableCellElement` and `CustomBlockElement` elements.
 */
@:allow(glaze.kit.base.text)
@:access(glaze.kit.base.ScrollableMask)
class NodeRender {

    static final CHECK_SVG_LIGHT = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" fill="none"><path d="m3.25 8.25 3 3 6.5-7" stroke="white" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>';
    static final CHECK_SVG_DARK = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" fill="none"><path d="m3.25 8.25 3 3 6.5-7" stroke="black" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>';

    /** The gap below a heading, relative to the heading's size. */
    static inline final HEADING_BOTTOM_GAP:Float = 0.35;

    static inline final CELL_PAD_PX:Float = 24.0; // px_3 horizontal padding
    static inline final CELL_MIN_PX:Float = 48.0;
    static inline final CELL_BORDER_PX:Float = 1.0; // border_r_1 drawn by every column but the last

    static inline function f32(value:Float):Float {
        return taffy.util.F32.fround(value);
    }

    /** gpui-base `TextSelection::end`, called before a link click is handled. */
    public static inline function endTextSelection(window:Window, cx:App):Void {
        glaze.kit.base.TextSelection.end(window, cx);
    }

    /**
     * Rust `handle_link_click` (text_view.rs, Worker B), called through
     * `TextView.handleLinkClick`.
     */
    static inline function handleLinkClick(handler:Null<(url:String, event:glaze.ClickEvent, window:Window, cx:App) -> Void>, url:String,
            event:glaze.ClickEvent, window:Window, cx:App):Void {
        TextView.handleLinkClick(handler, url, event, window, cx);
    }

    // Helpers

    static function intoElements(elements:Array<AnyElement>):Array<glaze.IntoElement> {
        return [for (element in elements) (element : glaze.IntoElement)];
    }

    /** The text view being prepainted or painted (`GlobalState::text_view_state`). */
    static inline function textViewState(cx:App):Null<glaze.Entity<TextViewState>> {
        return GlobalState.global(cx).textViewState();
    }

    /**
     * The element id of a block that needs one, from `kind` and the block's
     * source start, which is unique across a parsed Markdown document. The
     * HTML parser records no spans, so its blocks fall back to their index
     * among their siblings: unique among them, though not across nesting
     * levels.
     */
    static function blockElementId(kind:String, span:Null<Span>, ix:Int):ElementId {
        return NamedInteger(kind, span != null ? span.start : ix);
    }

    /**
     * The element id of a paragraph that needs one: an inline flow, whose
     * objects are accessibility nodes, or an image, whose element state is
     * its animation. The leaf key is unique per paragraph in a parsed
     * Markdown document; the HTML parser records no spans, so its paragraphs
     * share one.
     */
    static function leafElementId(fadeKey:Null<TextLeafKey>):ElementId {
        return fadeKey != null ? fadeKey.toElementId() : Name('p');
    }

    /**
     * A link's underline: a hairline in a translucent link color, so a run
     * of links reads as text first and as links second.
     */
    static function linkUnderline(style:TextViewStyle):UnderlineStyle {
        final underline = new UnderlineStyle();
        underline.thickness = 1.;
        underline.color = style.link().opacity(0.4);
        return underline;
    }

    /**
     * The font size the blocks inherit, which heading sizes and the spacing
     * of lists, tables and rules are proportional to (like CSS `em`), so a
     * compact 14px view and a 16px document keep the same rhythm.
     *
     * Resolved once per frame into the context; a context built without it
     * (as in tests) resolves it from the window.
     */
    static function bodyFontSize(nodeCx:NodeContext, window:Window):Pixels {
        if (nodeCx.bodyFontSize > 0) {
            return nodeCx.bodyFontSize;
        }
        return window.textStyle().fontSize.toPixels(window.remSize());
    }

    /**
     * A heading's `(size scale, line height, section gap)`, the size relative
     * to the body text and the gap above it relative to the heading itself.
     * Hierarchy comes from weight rather than size: every level is semibold
     * and the sizes step down gently from the body.
     */
    static function headingMetrics(level:Int):Array<Float> {
        return switch level {
            case 1: [1.8, 1.25, 1.1];
            case 2: [f32(4. / 3.), 1.35, 1.6];
            case 3: [f32(17. / 15.), 1.35, 1.4];
            case 4: [1., 1.35, 1.4];
            case 5: [f32(14. / 15.), 1.35, 1.4];
            case _: [f32(13. / 15.), 1.35, 1.4];
        }
    }

    /**
     * The size a heading renders at, including one a caller's heading
     * refinement pins, which its gaps follow.
     */
    static function headingSize(level:Int, nodeCx:NodeContext, window:Window):Pixels {
        final refinement = nodeCx.style.heading(level);
        if (refinement.text != null && refinement.text.fontSize != null) {
            return refinement.text.fontSize.toPixels(window.remSize());
        }
        return f32(bodyFontSize(nodeCx, window) * f32(headingMetrics(level)[0]));
    }

    /** The room above and below a horizontal rule. */
    static function ruleSpace(bodyFontSize:Pixels):Pixels {
        return f32(bodyFontSize * f32(1.6));
    }

    /** The gap below a block: a paragraph gap, unless nothing follows it. */
    static function blockGap(options:NodeRenderOptions, style:TextViewStyle):Rems {
        if (options.inList || options.isLast) {
            return rems(0.);
        }
        return style.paragraphGap();
    }

    /**
     * `block` with `gap` below it. The box only exists to hold the padding,
     * so a block with no gap below it is returned as is.
     */
    static function gapped(block:AnyElement, gap:Rems):AnyElement {
        if ((gap : Float) == 0) {
            return block;
        }
        return div().pb(gap).child(block).intoAnyElement();
    }

    /** The fade ranges overlapping `start..end`, rebased to start at `start`. */
    static function sliceFades(fades:Array<RangedFade>, start:Int, end:Int):Array<RangedFade> {
        final result:Array<RangedFade> = [];
        for (item in fades) {
            final clippedStart = item.range.start > start ? item.range.start : start;
            final clippedEnd = item.range.end < end ? item.range.end : end;
            if (clippedStart < clippedEnd)
                result.push(new RangedFade(new Range(clippedStart - start, clippedEnd - start), item.fadeOut));
        }
        return result;
    }

    /**
     * The range highlight backgrounds overlapping `start..end`, rebased to
     * start at `start`.
     */
    static function sliceBackgrounds(backgrounds:Array<RangedColor>, start:Int, end:Int):Array<RangedColor> {
        final result:Array<RangedColor> = [];
        for (item in backgrounds) {
            final clippedStart = item.range.start > start ? item.range.start : start;
            final clippedEnd = item.range.end < end ? item.range.end : end;
            if (clippedStart < clippedEnd)
                result.push(new RangedColor(new Range(clippedStart - start, clippedEnd - start), item.color));
        }
        return result;
    }

    /** `slice_ranges` over highlights (cloned). */
    static function sliceHighlights(highlights:Array<RangedHighlight>, start:Int, end:Int):Array<RangedHighlight> {
        final result:Array<RangedHighlight> = [];
        for (item in highlights) {
            final clippedStart = item.range.start > start ? item.range.start : start;
            final clippedEnd = item.range.end < end ? item.range.end : end;
            if (clippedStart < clippedEnd)
                result.push(new RangedHighlight(new Range(clippedStart - start, clippedEnd - start), item.highlight.clone()));
        }
        return result;
    }

    /**
     * The highlight a text mark renders with. The link decoration is applied
     * by the caller, which also has to record the link range.
     */
    static function markHighlight(mark:TextMark, nodeCx:NodeContext, cx:App):InlineHighlight {
        var highlight = new HighlightStyle();
        if (mark.bold) {
            highlight.fontWeight = FontWeight.BOLD;
        }
        if (mark.italic) {
            highlight.fontStyle = FontStyle.Italic;
        }
        if (mark.strikethrough) {
            highlight.strikethrough = new StrikethroughStyle(1.);
        }
        if (mark.underline) {
            final underline = new UnderlineStyle();
            underline.thickness = 1.;
            highlight.underline = underline;
        }
        var fontFamily:Null<String> = null;
        if (mark.code) {
            highlight = highlight.highlight(nodeCx.style.inlineCodeHighlight());
            final style = nodeCx.style.inlineCodeStyle();
            final text = style.text;
            final codeText = new HighlightStyle();
            if (text != null) {
                codeText.color = text.color;
                if (text.has(TextStyleRefinement.FONT_WEIGHT))
                    codeText.fontWeight = text.fontWeight;
                if (text.has(TextStyleRefinement.FONT_STYLE))
                    codeText.fontStyle = text.fontStyle;
                codeText.underline = text.underline;
                codeText.strikethrough = text.strikethrough;
            }
            highlight = highlight.highlight(codeText);
            fontFamily = text != null && text.fontFamily != null ? text.fontFamily : Theme.global(cx).tokens.typography.mono;
        }
        if (mark.highlight != null) {
            highlight.backgroundColor = mark.highlight;
        }
        return new InlineHighlight(highlight, fontFamily, mark.code ? 0.875 : null, mark.code ? nodeCx.style.inlineCodeStyle().clone() : null);
    }

    // Paragraph

    /**
     * The text, highlights and (unresolved) links of a text-only paragraph,
     * from the cache when the style has not changed since they were built.
     */
    static function plainRender(paragraph:Paragraph, nodeCx:NodeContext, cx:App):ParagraphRender {
        final monoFont = Theme.global(cx).tokens.typography.mono;
        final cached = paragraph.renderCache;
        if (cached != null && (cached.style == nodeCx.style || cached.style.equals(nodeCx.style)) && cached.monoFont == monoFont) {
            return new ParagraphRender(cached.style, cached.monoFont, cached.text, [for (h in cached.highlights) h],
                [for (l in cached.links) l]);
        }

        final text = new StringBuf();
        var highlights:Array<RangedHighlight> = [];
        final links:Array<RangedLink> = [];
        var offset = 0;
        for (inlineNode in paragraph.children_) {
            final textLen = TextUtils.len(inlineNode.text_);
            text.add(inlineNode.text_);
            final nodeHighlights:Array<RangedHighlight> = [];
            for (item in inlineNode.marks_) {
                final innerRange = new Range(offset + item.range.start, offset + item.range.end);
                final highlight = markHighlight(item.mark, nodeCx, cx);
                if (item.mark.link != null) {
                    highlight.style.color = nodeCx.style.link();
                    highlight.style.underline = linkUnderline(nodeCx.style);
                    links.push(new RangedLink(innerRange, item.mark.link.clone()));
                }
                nodeHighlights.push(new RangedHighlight(innerRange, highlight));
            }
            highlights = InlineHighlight.combineHighlights(highlights, nodeHighlights);
            offset += textLen;
        }
        final render = new ParagraphRender(nodeCx.style, monoFont, text.toString(), highlights, links);
        paragraph.renderCache = render;
        return new ParagraphRender(render.style, render.monoFont, render.text, [for (h in highlights) h], [for (l in links) l]);
    }

    /**
     * The highlights over `Paragraph.text`, for measuring the paragraph with
     * the runs it renders with. Link colors are left out: they do not move
     * glyphs.
     */
    static function inlineHighlights(paragraph:Paragraph, nodeCx:NodeContext, cx:App):Array<RangedHighlight> {
        var highlights:Array<RangedHighlight> = [];
        var offset = 0;
        for (inlineNode in paragraph.children_) {
            final nodeHighlights = [
                for (item in inlineNode.marks_)
                    new RangedHighlight(new Range(offset + item.range.start, offset + item.range.end), markHighlight(item.mark, nodeCx, cx))
            ];
            highlights = InlineHighlight.combineHighlights(highlights, nodeHighlights);
            offset += TextUtils.len(inlineNode.text_);
        }
        return highlights;
    }

    /** Resolves a link written by reference through the document's definitions. */
    static function resolveLink(link:LinkMark, nodeCx:NodeContext):LinkMark {
        if (link.identifier != null) {
            final mark = nodeCx.linkRefs.get(link.identifier);
            if (mark != null)
                return mark.clone();
        }
        return link;
    }

    /** The image element of an inline image, with its link handlers. */
    static function imageElement(ix:Int, image:ImageNode, nodeCx:NodeContext):AnyElement {
        final linkClickHandler = nodeCx.linkClickHandler;
        final element = img(nodeCx.imageSourceFor(image)).id(ix).objectFit(ObjectFit.Contain).maxW(relative(1.));
        if (image.width != null)
            element.w(image.width);
        final link = image.link;
        if (link != null) {
            final auxLink = link.clone();
            element.cursorPointer()
                .onClick((event, window, cx) -> {
                    endTextSelection(window, cx);
                    cx.stopPropagation();
                    handleLinkClick(linkClickHandler, link.url, event, window, cx);
                })
                .onAuxClick((event, window, cx) -> {
                    endTextSelection(window, cx);
                    cx.stopPropagation();
                    handleLinkClick(linkClickHandler, auxLink.url, event, window, cx);
                });
        }
        return element.intoAnyElement();
    }

    /**
     * `fadeKey` names this paragraph's text for the streamed fade-in and for
     * range highlights; the owning block supplies it because a heading or
     * table cell paragraph carries no span of its own.
     */
    static function renderParagraph(paragraph:Paragraph, fadeKey:Null<TextLeafKey>, nodeCx:NodeContext, window:Window, cx:App):AnyElement {
        final children = paragraph.children_;
        final fades = nodeCx.streamFades(fadeKey);
        final backgrounds = nodeCx.rangeBackgrounds(fadeKey);

        if (shouldRenderInlineFlow(paragraph)) {
            return new InlineFlow(leafElementId(fadeKey), inlineFlowItems(paragraph, fadeKey, fades, backgrounds, nodeCx, cx), nodeCx.linkClickHandler)
                .editorKey(leafKey(paragraph))
                .intoAnyElement();
        }

        var hasImage = false;
        for (child in children) {
            if (child.image != null) {
                hasImage = true;
                break;
            }
        }
        // Text alone is one `Inline`, which needs no box of its own, and its
        // text, highlights and links are cached across frames.
        if (!hasImage) {
            final plain = plainRender(paragraph, nodeCx, cx);
            final text = plain.text;
            // An editor leaf is laid out even when empty, so the editor gets
            // a line box for the caret.
            if (text == '' && leafKey(paragraph) == null) {
                return div().intoAnyElement();
            }
            final links = [for (item in plain.links) new RangedLink(item.range, resolveLink(item.link, nodeCx))];
            final textLen = TextUtils.len(text);
            final highlights = InlineHighlight.fadeHighlights(plain.highlights, sliceFades(fades, 0, textLen));
            final itemBackgrounds = sliceBackgrounds(backgrounds, 0, textLen);
            final reveal = nodeCx.revealAt(fadeKey, 0, textLen);
            paragraph.state.setText(text);
            return new Inline(paragraph.state, links, highlights, nodeCx.linkClickHandler).rangeBackgrounds(itemBackgrounds)
                .reveal(reveal)
                .intoAnyElement();
        }

        final childNodes:Array<AnyElement> = [];

        var text = '';
        var highlights:Array<RangedHighlight> = [];
        var links:Array<RangedLink> = [];
        var offset = 0;
        // Where `text` starts in the paragraph's whole rendered text, which
        // is the byte space the fade ranges use.
        var consumed = 0;

        for (ix in 0...children.length) {
            final inlineNode = children[ix];
            final textLen = TextUtils.len(inlineNode.text_);
            text += inlineNode.text_;

            final image = inlineNode.image;
            if (image != null) {
                final len = TextUtils.len(text);
                if (len > 0) {
                    inlineNode.state.setText(text);
                    childNodes.push(new Inline(inlineNode.state, links.copy(),
                        InlineHighlight.fadeHighlights(highlights.copy(), sliceFades(fades, consumed, consumed + len)), nodeCx.linkClickHandler)
                        .rangeBackgrounds(sliceBackgrounds(backgrounds, consumed, consumed + len))
                        .reveal(nodeCx.revealAt(fadeKey, consumed, consumed + len))
                        .intoAnyElement());
                }
                childNodes.push(imageElement(ix, image, nodeCx));

                consumed += len;
                text = '';
                links = [];
                highlights = [];
                offset = 0;
            } else {
                final nodeHighlights:Array<RangedHighlight> = [];
                for (item in inlineNode.marks_) {
                    final innerRange = new Range(offset + item.range.start, offset + item.range.end);
                    final highlight = markHighlight(item.mark, nodeCx, cx);

                    if (item.mark.link != null) {
                        highlight.style.color = nodeCx.style.link();
                        highlight.style.underline = linkUnderline(nodeCx.style);

                        // convert link references, replace link
                        links.push(new RangedLink(innerRange, resolveLink(item.mark.link.clone(), nodeCx)));
                    }

                    nodeHighlights.push(new RangedHighlight(innerRange, highlight));
                }

                highlights = InlineHighlight.combineHighlights(highlights, nodeHighlights);
                offset += textLen;
            }
        }

        // Add the last text node
        final len = TextUtils.len(text);
        if (len > 0) {
            final textEnd = consumed + len;
            final faded = InlineHighlight.fadeHighlights(highlights, sliceFades(fades, consumed, textEnd));
            paragraph.state.setText(text);
            childNodes.push(new Inline(paragraph.state, links, faded, nodeCx.linkClickHandler)
                .rangeBackgrounds(sliceBackgrounds(backgrounds, consumed, textEnd))
                .reveal(nodeCx.revealAt(fadeKey, consumed, textEnd))
                .intoAnyElement());
        }

        // Images keep an identified box: an image's element state is its
        // animation, and the box scopes that state per paragraph.
        return div().id(leafElementId(fadeKey)).children(intoElements(childNodes)).intoAnyElement();
    }

    /** The key an external editor gave this leaf, if any. */
    static function leafKey(paragraph:Paragraph):Null<Int> {
        return paragraph.state.editorKey;
    }

    static function shouldRenderInlineFlow(paragraph:Paragraph):Bool {
        var hasImage = false;
        var hasText = false;
        var hasCustom = false;
        var hasCode = false;
        for (child in paragraph.children_) {
            if (child.image != null)
                hasImage = true;
            if (child.text_ != '')
                hasText = true;
            if (child.custom != null)
                hasCustom = true;
            for (item in child.marks_) {
                if (item.mark.code)
                    hasCode = true;
            }
        }
        // An editor leaf with an image always uses the flow, which reports
        // its pieces to the editor (an image-only paragraph would otherwise
        // take the plain image path, which reports nothing).
        if (hasImage && leafKey(paragraph) != null) {
            return true;
        }
        return hasCustom || (hasImage && hasText) || hasCode;
    }

    static function inlineFlowItems(paragraph:Paragraph, leafKey:Null<TextLeafKey>, fades:Array<RangedFade>, backgrounds:Array<RangedColor>,
            nodeCx:NodeContext, cx:App):Array<InlineFlowItem> {
        final items:Array<InlineFlowItem> = [];
        var text = '';
        var highlights:Array<RangedHighlight> = [];
        var links:Array<RangedLink> = [];
        var offset = 0;
        // Where `text` starts in the paragraph's whole rendered text, which
        // is the byte space the fade and background ranges use.
        var consumed = 0;

        for (inlineNode in paragraph.children_) {
            final node = inlineNode.custom;
            if (node != null) {
                inlineNode.state.setText(text);
                if (text != '') {
                    final len = TextUtils.len(text);
                    final itemFades = sliceFades(fades, consumed, consumed + len);
                    final itemBackgrounds = sliceBackgrounds(backgrounds, consumed, consumed + len);
                    final itemReveal = nodeCx.revealAt(leafKey, consumed, consumed + len);
                    consumed += len;
                    items.push(InlineFlowItem.Text(inlineNode.state, text, links, InlineHighlight.fadeHighlights(highlights, itemFades),
                        itemBackgrounds, itemReveal));
                    text = '';
                    links = [];
                    highlights = [];
                }
                var objectStyle = new HighlightStyle();
                var objectLink:Null<LinkMark> = null;
                for (item in inlineNode.marks_) {
                    objectStyle = objectStyle.highlight(markHighlight(item.mark, nodeCx, cx).style);
                    final link = item.mark.link;
                    if (link != null) {
                        objectLink = resolveLink(link, nodeCx).clone();
                        objectStyle.color = nodeCx.style.link();
                        objectStyle.underline = linkUnderline(nodeCx.style);
                    }
                }
                final renderedNode = node.clone();
                final extensions = nodeCx.markdownExtensions;
                final sourceRange = node.sourceRange();
                items.push(InlineFlowItem.Object(node.sharedText(), sourceRange != null ? sourceRange.start : items.length,
                    (context, window, cx) -> extensions.renderInline(renderedNode, context, window, cx), node.sharedAccessibilityName(),
                    inlineNode.customSelection, objectStyle, objectLink));
                consumed += TextUtils.len(inlineNode.text_);
                offset = 0;
                continue;
            }
            final textLen = TextUtils.len(inlineNode.text_);
            text += inlineNode.text_;

            final image = inlineNode.image;
            if (image != null) {
                final len = TextUtils.len(text);
                if (text != '') {
                    inlineNode.state.setText(text);
                    items.push(InlineFlowItem.Text(inlineNode.state, text, links.copy(),
                        InlineHighlight.fadeHighlights(highlights.copy(), sliceFades(fades, consumed, consumed + len)),
                        sliceBackgrounds(backgrounds, consumed, consumed + len), nodeCx.revealAt(leafKey, consumed, consumed + len)));
                }

                items.push(InlineFlowItem.Image(nodeCx.imageSourceFor(image), image.link != null ? image.link.clone() : null, image.getTitle(),
                    image.width, image.height));

                consumed += len;
                text = '';
                links = [];
                highlights = [];
                offset = 0;
            } else {
                final nodeHighlights:Array<RangedHighlight> = [];
                for (item in inlineNode.marks_) {
                    final innerRange = new Range(offset + item.range.start, offset + item.range.end);
                    final highlight = markHighlight(item.mark, nodeCx, cx);

                    if (item.mark.link != null) {
                        highlight.style.color = nodeCx.style.link();
                        highlight.style.underline = linkUnderline(nodeCx.style);
                        links.push(new RangedLink(innerRange, resolveLink(item.mark.link.clone(), nodeCx)));
                    }

                    nodeHighlights.push(new RangedHighlight(innerRange, highlight));
                }

                highlights = InlineHighlight.combineHighlights(highlights, nodeHighlights);
                offset += textLen;
            }
        }

        if (text != '') {
            final len = TextUtils.len(text);
            paragraph.state.setText(text);
            final faded = InlineHighlight.fadeHighlights(highlights, sliceFades(fades, consumed, consumed + len));
            final itemBackgrounds = sliceBackgrounds(backgrounds, consumed, consumed + len);
            final reveal = nodeCx.revealAt(leafKey, consumed, consumed + len);
            items.push(InlineFlowItem.Text(paragraph.state, text, links, faded, itemBackgrounds, reveal));
        }

        return items;
    }

    // Code block

    static function renderCodeBlock(codeBlock:CodeBlock, options:NodeRenderOptions, nodeCx:NodeContext, window:Window, cx:App):AnyElement {
        final style = nodeCx.style;
        final theme = Theme.global(cx);
        final leafKey = codeBlock.span != null ? TextLeafKey.block(codeBlock.span.start) : null;
        // The language sits quietly in the top-right corner, where custom
        // actions go instead when the caller provides them; the top padding
        // keeps the first line clear of it. Like the actions, it stays out of
        // the scrolled content so it holds its corner.
        final lang = codeBlock.lang();
        final langLabel:Null<Div> = if (lang != null && lang != '' && nodeCx.codeBlockActions == null) {
            div().absolute()
                .top(px(7.))
                .right3()
                .fontFamily(theme.tokens.typography.sans)
                .textSize(theme.tokens.typography.xs.size)
                .lineHeight(px(16.))
                .textColor(style.mutedForeground())
                .child(lang);
        } else null;

        final highlighter = nodeCx.codeBlockHighlighter;
        final styles = highlighter != null ? codeBlock.highlightedStyles(highlighter) : [];
        final block = div().wFull()
            .minW0()
            .px4()
            .pt(langLabel != null ? px(28.) : px(14.))
            .pb(px(14.))
            .bg(style.codeBackground())
            .border1()
            .borderColor(style.border())
            .fontFamily(theme.tokens.typography.mono)
            .textSize(theme.tokens.typography.monoMd.size)
            .lineHeight(relative(1.6))
            .relative()
            .refineStyle(style.codeBlock())
            .child(new Inline(codeBlock.state, [],
                InlineHighlight.fadeHighlights([for (s in styles) new RangedHighlight(s.range, InlineHighlight.fromStyle(s.style))],
                    nodeCx.streamFades(leafKey)), nodeCx.linkClickHandler)
                .rangeBackgrounds(nodeCx.rangeBackgrounds(leafKey).copy())
                .reveal(nodeCx.revealAt(leafKey, 0, TextUtils.len(codeBlock.code()))));
        final codeBlockActions = nodeCx.codeBlockActions;
        final actions:Null<Div> = codeBlockActions != null ? div().id('actions')
            .absolute()
            .top2()
            .right2()
            .bg(style.codeBackground())
            .rounded(theme.tokens.radius.md)
            .child(codeBlockActions(codeBlock, window, cx)) : null;
        // The id scopes the caller's action ids per code block, so plain ids
        // like `"copy"` don't collide across blocks.
        final id = blockElementId('codeblock', codeBlock.span, options.ix);
        final codeBlockStyle = style.codeBlock();
        final element:AnyElement = if (codeBlockStyle.has(StyleRefinement.OVERFLOW_Y) && codeBlockStyle.overflowY == Overflow.Scroll) {
            final scrollHandle:ScrollHandle = window.useKeyedState(blockElementId('codeblock-scroll', codeBlock.span, options.ix), cx,
                _ -> new ScrollHandle())
                .read(cx)
                .value;
            // Scroll mode is opted in by setting `style.codeBlock`'s
            // `overflowY` to `Overflow.Scroll`. The mask consumes the wheel in
            // the capture phase, so an ancestor `list` doesn't scroll on the
            // same event. Mask, scrollbar and actions are siblings of the
            // scrolled block, so they stay pinned to the viewport instead of
            // moving with the code.
            final container = div().id(id)
                .wFull()
                .minW0()
                .relative()
                .child(block.id('scroll').trackScroll(scrollHandle))
                .child(new ScrollableMask(Axis.Vertical, scrollHandle).id(id))
                .child(div().absolute().inset0().child(Scrollbar.vertical(scrollHandle)));
            if (actions != null)
                container.child(actions);
            if (langLabel != null)
                container.child(langLabel);
            container.intoAnyElement();
        } else {
            // Without actions nothing under the block needs element state.
            if (actions != null) {
                block.id(id).child(actions).intoAnyElement();
            } else {
                if (langLabel != null)
                    block.child(langLabel);
                block.intoAnyElement();
            }
        }

        return gapped(element, options.isLast ? rems(0.) : style.paragraphGap());
    }

    // Lists

    static function renderListItemRow(content:AnyElement, ix:Int, options:NodeRenderOptions, checked:Null<Bool>, style:TextViewStyle,
            lineHeight:Pixels, indent:Pixels):Div {
        final row = glaze.kit.base.Prelude.hFlex().wFull().minW0().relative().itemsStart().contentStart();
        if (!options.todo && checked == null) {
            // The marker hangs in an indent column, right-aligned against
            // the text like an outside list marker, and steps back in color
            // so the item text leads.
            row.child(div().flexNone()
                .minW(indent)
                .pr(px(f32(indent * f32(0.3))))
                .textRight()
                .textColor(style.mutedForeground())
                .refineStyle(style.listStyle())
                .child(TextUtils.trimEnd(TextUtils.listItemPrefix(ix, options.listStart, options.ordered, options.depth))));
        }
        if (checked != null) {
            // Todo list checkbox
            final checkSvg = style.isDark() ? CHECK_SVG_DARK : CHECK_SVG_LIGHT;
            final listText = style.listStyle().text;
            final box = div().flex()
                .size(rems(0.9375))
                .itemsCenter()
                .justifyCenter()
                .rounded(px(4.))
                .border(px(1.5))
                .borderColor(listText != null && listText.color != null ? listText.color : style.mutedForeground());
            if (checked) {
                box.bg(style.link()).borderColor(style.link()).child(img(glaze.Image.fromBytes(ImageFormat.Svg, Bytes.ofString(checkSvg))).size(rems(0.75)));
            }
            row.child(div().flex().mr2().h(lineHeight).flexNone().itemsCenter().justifyCenter().child(box));
        }
        final body = div().flex1().minW0().overflowHidden();
        // A done task steps back so the open ones stand out.
        if (checked == true) {
            body.textColor(style.mutedForeground());
        }
        return row.child(body.child(content));
    }

    static function itemOptions(options:NodeRenderOptions, checked:Null<Bool>):NodeRenderOptions {
        final o = options.copy();
        o.depth = options.depth + 1;
        o.todo = checked != null;
        o.isLast = true;
        return o;
    }

    static function renderListItem(item:BlockNode, ix:Int, options:NodeRenderOptions, nodeCx:NodeContext, window:Window, cx:App):AnyElement {
        switch item {
            case ListItem(children, spread, checked, _):
                final body = bodyFontSize(nodeCx, window);
                final indent:Pixels = f32(body * f32(1.4));
                final container = div().wFull().minW0();
                // Items breathe a little apart, less than paragraphs do.
                if (ix > 0)
                    container.pt(px(f32(body * 0.25)));
                if (spread)
                    container.child(div());
                final items:Array<Div> = [];

                for (childIx in 0...children.length) {
                    final child = children[childIx];
                    switch child {
                        case Paragraph(_):
                            final lastNotList = childIx > 0 && !children[childIx - 1].match(List(_, _, _, _));

                            final text = child.renderBlock(itemOptions(options, checked), nodeCx, window, cx);

                            // Continuation paragraph: stack vertically below the
                            // previous row, indented to align with the text
                            // column (past bullet/number prefix).
                            if (lastNotList && items.length > 0) {
                                final precedingRow = items.pop();
                                items.push(div().child(precedingRow).child(div().wFull().pl(indent).overflowHidden().child(text)));
                                continue;
                            }

                            items.push(renderListItemRow(text, ix, options, checked, nodeCx.style, window.lineHeight(), indent));
                        case List(_, _, _, _):
                            items.push(div().ml(indent).child(child.renderBlock(itemOptions(options, checked), nodeCx, window, cx)));
                        case Root(_, _) | Heading(_, _, _) | Blockquote(_, _) | CodeBlock(_) | Custom(_, _) | Table(_) | HorizontalRule(_):
                            final block = child.renderBlock(itemOptions(options, checked), nodeCx, window, cx);

                            if (childIx == 0) {
                                items.push(renderListItemRow(block, ix, options, checked, nodeCx.style, window.lineHeight(), indent));
                            } else {
                                // Indent continuation blocks to align with a
                                // nested sub-list (`ml(indent)`) and with
                                // continuation paragraphs.
                                items.push(div().wFull().minW0().pl(indent).overflowHidden().child(block));
                            }
                        case ListItem(_, _, _, _) | Break(_, _) | Definition(_, _, _, _) | Unknown:
                    }
                }
                for (row in items)
                    container.child(row);
                return container.intoAnyElement();
            case _:
                return div().intoAnyElement();
        }
    }

    // Tables

    /**
     * Horizontal padding of a table cell: `px_3` unless `style.tableCell`
     * sets it.
     */
    static function tableCellPaddingX(style:TextViewStyle, remSize:Pixels):Float {
        final cellStyle = style.tableCell();
        inline function side(length:Null<DefiniteLength>):Float {
            return switch length {
                case Absolute(length): length.toPixels(remSize);
                case _: CELL_PAD_PX / 2.;
            }
        }
        return f32(side(cellStyle.paddingLeft) + side(cellStyle.paddingRight));
    }

    /**
     * The max-content width of every table column: the widest cell line,
     * shaped with the runs the cell renders with, plus the cell's padding and
     * border. Never capped: a cap would clip overflowing text *and* leave it
     * outside the scrollable width, making it unreachable.
     */
    static function measureTableColumns(table:Table, colCount:Int, nodeCx:NodeContext, window:Window, cx:App):Array<Float> {
        final textStyles = TableTextStyles.of(nodeCx.style, window);
        final remSize = window.remSize();
        final monoFamily = Theme.global(cx).tokens.typography.mono;
        final inlineCode = nodeCx.style.inlineCodeHighlight();
        var measured = table.columnWidthsCache;
        if (measured != null
            && !(measured.widths.length == colCount
                && measured.textStyles.equals(textStyles)
                && measured.remSize == remSize
                && measured.monoFamily == monoFamily
                && measured.inlineCode.equals(inlineCode)
                && measured.textSystem == window.textSystem())) {
            measured = null;
        }
        if (measured == null) {
            final result = measureTableTextColumns(table, colCount, textStyles, nodeCx, window, cx);
            measured = new TableColumnWidths(window.textSystem(), textStyles, remSize, monoFamily, inlineCode, result.widths, result.customCells);
            table.columnWidthsCache = measured;
        }

        // Resource-backed cells must be measured again, even when their text
        // is unchanged. Do not retain their widths: a loaded image or a
        // plugin can get narrower as well as wider.
        final colW = measured.widths.copy();
        for (cellIx in measured.customCells) {
            final rowIx = cellIx[0];
            final ix = cellIx[1];
            final cell = table.children[rowIx].children[ix];
            final items = inlineFlowItems(cell.children, null, [], [], nodeCx, cx);
            final style = textStyles.rowRefinement(rowIx).clone();
            final width:Float = window.withTextStyle(style, window -> InlineFlow.intrinsicWidth(items, window, cx));
            final border = ix + 1 < colCount ? CELL_BORDER_PX : 0.;
            colW[ix] = Math.max(colW[ix], f32(f32(width + CELL_PAD_PX) + border));
        }
        return colW;
    }

    /**
     * The first measurement still visits all ordinary cells. The cache
     * avoids repeating that work; it is not a budget for the initial table
     * layout.
     */
    static function measureTableTextColumns(table:Table, colCount:Int, textStyles:TableTextStyles, nodeCx:NodeContext, window:Window,
            cx:App):{widths:Array<Float>, customCells:Array<Array<Int>>} {
        final colW = [for (_ in 0...colCount) CELL_MIN_PX];
        final customCells:Array<Array<Int>> = [];
        for (rowIx in 0...table.children.length) {
            final row = table.children[rowIx];
            final textStyle = textStyles.row(rowIx);
            final fontSize:Float = textStyle.fontSize.toPixels(window.remSize());
            for (ix in 0...row.children.length) {
                if (ix >= colW.length) {
                    continue;
                }
                final cell = row.children[ix];
                var hasCustom = false;
                for (node in cell.children.children_) {
                    if (node.custom != null) {
                        hasCustom = true;
                        break;
                    }
                }
                if (hasCustom) {
                    customCells.push([rowIx, ix]);
                    continue;
                }
                final text = cell.children.text();
                final highlights = inlineHighlights(cell.children, nodeCx, cx);
                var w:Float = 0.0;
                var lineStart = 0;
                for (rawLine in text.split('\n')) {
                    final rawLen = TextUtils.len(rawLine);
                    final start = lineStart + (rawLen - TextUtils.len(TextUtils.trimStart(rawLine)));
                    final lineEnd = lineStart + rawLen;
                    lineStart = lineEnd + 1;
                    final line = TextUtils.trim(rawLine);
                    if (line == '') {
                        continue;
                    }
                    final lineLen = TextUtils.len(line);
                    final end = start + lineLen;
                    final lineHighlights = sliceHighlights(highlights, start, end);
                    var lineW:Float = 0.;
                    for (sized in InlineHighlight.textSizeRanges(lineLen, lineHighlights, fontSize, window.remSize())) {
                        final range = sized.range;
                        final scale = sized.fadeOut;
                        final rangeHighlights = sliceHighlights(lineHighlights, range.start, range.end);
                        final scaledSize = f32(fontSize * scale);
                        final insets = InlineHighlight.codeInsetsOf(rangeHighlights, scaledSize, window.remSize());
                        lineW = f32(lineW + f32(insets.left + insets.right));
                        final runs = InlineHighlight.textRuns(range.len(), textStyle, rangeHighlights);
                        lineW = f32(lineW + window.textSystem().layoutLine(TextUtils.slice(line, range.start, range.end), scaledSize, runs, null).width);
                    }
                    w = Math.max(w, lineW);
                }
                // Border-box widths, so the padding and border the cell draws
                // must leave the measured text its full width.
                final border = ix + 1 < colCount ? CELL_BORDER_PX : 0.;
                colW[ix] = Math.max(colW[ix], f32(f32(w + CELL_PAD_PX) + border));
            }
        }
        return {widths: colW, customCells: customCells};
    }

    /**
     * Render a Markdown table.
     *
     * Columns are sized from the measured max-content width of their cells,
     * so they line up and fit their content on proportional fonts and mixed
     * scripts alike. The layout adapts to the frame:
     *
     * - Wider than the content: every column fits its content and the spare
     *   width is shared in proportion to it.
     * - Narrower: the narrow columns keep their full content width and only
     *   the widest ones shrink and wrap, all down to one common width (see
     *   `renderTableRows`).
     * - Narrower than the column floors: the default layout clips, while
     *   `style.table` overflow-x: scroll keeps the floors and scrolls
     *   horizontally, so no content ever becomes unreachable.
     *
     * `whiteSpace: nowrap` on `style.tableCell` composes like in CSS: the
     * refinement keeps cell text on a single line, and the scroll layout
     * raises the floors to the full content widths so the single-line
     * columns never shrink.
     */
    static function renderTable(item:BlockNode, options:NodeRenderOptions, nodeCx:NodeContext, textSize:Pixels, window:Window, cx:App):AnyElement {
        // A scrolling column stops shrinking (and the table starts to scroll)
        // at a floor scaled to its content: roughly the width at which the
        // text wraps to `CELL_WRAP_MAX_LINES` lines, clamped between the two
        // bounds so moderate columns can still wrap meaningfully while one
        // huge column cannot push the scroll threshold arbitrarily high.
        final CELL_WRAP_MAX_LINES = 2.0;
        final CELL_WRAP_MIN_PX = 160.0;
        final CELL_WRAP_MAX_PX = 480.0;
        final TABLE_BORDER_PX = 2.0; // the frame's border_1, left + right

        final table = switch item {
            case Table(table): table;
            case _: return div().intoAnyElement();
        }

        final style = nodeCx.style;
        var colCount = 0;
        for (row in table.children) {
            if (row.children.length > colCount)
                colCount = row.children.length;
        }
        final colW = measureTableColumns(table, colCount, nodeCx, window, cx);
        final tableStyle = style.table();
        final scroll = tableStyle.has(StyleRefinement.OVERFLOW_X) && tableStyle.overflowX == Overflow.Scroll;
        final cellText = style.tableCell().text;
        final nowrap = cellText != null && cellText.has(TextStyleRefinement.WHITE_SPACE) && cellText.whiteSpace == WhiteSpace.Nowrap;
        final remSize = window.remSize();
        final wrapMinPx:Float = rems(4.).toPixels(remSize);
        // Widths were measured with the default cell padding.
        final paddingDelta = f32(tableCellPaddingX(style, remSize) - CELL_PAD_PX);
        // Lengths are rounded to device pixels for layout. Round the content
        // widths up, or a column can lose the fraction of a pixel that keeps
        // its text on one line.
        final scaleFactor = window.scaleFactor();
        inline function deviceCeil(width:Float):Float {
            return f32(Math.fceil(f32(width * scaleFactor)) / scaleFactor);
        }
        final columns:Array<TableColumn> = [];
        for (ix in 0...colW.length) {
            final w = f32(colW[ix] + paddingDelta);
            final floor = if (scroll && nowrap) {
                w;
            } else if (scroll) {
                Math.min(glaze.util.MathUtil.clamp(f32(w / CELL_WRAP_MAX_LINES), CELL_WRAP_MIN_PX, CELL_WRAP_MAX_PX), w);
            } else {
                Math.min(w, wrapMinPx);
            }
            final divider = ix + 1 < colCount ? CELL_BORDER_PX : 0.;
            final max = deviceCeil(f32(w - divider));
            columns.push(new TableColumn(Math.min(deviceCeil(f32(floor - divider)), max), max, divider));
        }

        final rows = renderTableRows(table, columns, nodeCx, window, cx);
        final theme = Theme.global(cx);
        final frameBuilder = new glaze.StyleBuilder();
        frameBuilder.textSize(textSize)
            .bg(style.tableBackground() != null ? style.tableBackground() : theme.tokens.colors.surface)
            .border1()
            .borderColor(style.border())
            .refineStyle(style.table());
        final frame = frameBuilder.style();
        final body:AnyElement = if (scroll) {
            final scrollHandle:ScrollHandle = window.useKeyedState(blockElementId('table-scroll', table.span, options.ix), cx, _ -> new ScrollHandle())
                .read(cx)
                .value;
            var minTotalW = 0.;
            for (column in columns)
                minTotalW = f32(minTotalW + f32(column.min + column.divider));
            minTotalW = f32(minTotalW + TABLE_BORDER_PX);
            // Scroll viewport owns the visible frame, including any
            // caller-provided radius. Keeping the border here makes the
            // rounded frame stable while the wider row track moves below it.
            //
            // `horizontalScrollArea` clips with `overflowHidden` and delegates
            // the wheel to a sibling `ScrollableMask`, so the gesture is
            // locked to its starting axis and a horizontal swipe is consumed
            // before an ancestor scroller can take its vertical component.
            ScrollableMask.horizontalScrollArea(blockElementId('table', table.span, options.ix), scrollHandle, frame,
                // Row track sized to `max(viewport, column floors)`.
                div().minWFull().w(px(minTotalW)).children(intoElements(rows))).intoAnyElement();
        } else {
            div().wFull().overflowHidden().refineStyle(frame).children(intoElements(rows)).intoAnyElement();
        }

        final container = div().pb(blockGap(options, style)).wFull().child(body);
        // Custom actions row (e.g. copy / download) rendered below the
        // table. The hook's element spans full width; alignment is up to the
        // caller. The gap keeps hover backgrounds of the action buttons off
        // the table border, and the id scopes the caller's element ids per
        // table, so plain ids like `"copy"` don't collide across tables.
        final tableActions = nodeCx.tableActions;
        if (tableActions != null) {
            container.child(div().id(blockElementId('table-actions', table.span, options.ix)).mt1().child(tableActions(table.cachedTableData(), window, cx)));
        }
        return container.intoAnyElement();
    }

    /**
     * Corner radii for the first and last table rows, derived from the frame
     * radius in `style.table()`, inset by the frame's 1px border.
     * `[topLeft, topRight, bottomLeft, bottomRight]`.
     */
    static function tableRowCornerRadii(style:TextViewStyle, window:Window):Array<Null<Float>> {
        final remSize = window.remSize();
        inline function inset(radius:Null<glaze.AbsoluteLength>):Null<Float> {
            return radius != null ? Math.max(f32(radius.toPixels(remSize) - 1.), 0.) : null;
        }
        final radii = style.table();
        return [
            inset(radii.cornerRadiusTopLeft),
            inset(radii.cornerRadiusTopRight),
            inset(radii.cornerRadiusBottomLeft),
            inset(radii.cornerRadiusBottomRight)
        ];
    }

    /**
     * The table rows, each a flex row laid out on the same column grid.
     *
     * Every column is a cell plus slack beside it. A cell grows from zero up
     * to its content width `max` and never below its floor `min`: flex
     * layout grows all cells equally and freezes each one that reaches its
     * content width, so the narrow columns fit their content and the widest
     * ones share what is left. The slack grows only after every cell is
     * frozen, so a frame wider than the content spreads the extra width in
     * proportion to the columns, placed after, around or before the cell to
     * follow the column alignment.
     *
     * A row with fewer cells than the table keeps empty cells in their place,
     * so its columns line up with the other rows.
     */
    static function renderTableRows(table:Table, columns:Array<TableColumn>, nodeCx:NodeContext, window:Window, cx:App):Array<AnyElement> {
        // The slack's share of the frame while any cell is still growing is
        // `SLACK_GROW / (cells * CELL_GROW)`, a negligible fraction of a
        // pixel. The slack factors still add up to `SLACK_GROW`.
        final CELL_GROW = 1e6;
        final SLACK_GROW = 1.0;

        final style = nodeCx.style;
        final colCount = columns.length;
        var totalW = 0.;
        for (column in columns)
            totalW = f32(totalW + column.max);
        totalW = Math.max(totalW, 1.);
        // The slack is part of the column, so it carries the cell's fill and
        // the column divider in the cell's border color.
        final slackStyle = new StyleRefinement();
        slackStyle.background = style.tableCell().background;
        slackStyle.borderColor = style.tableCell().borderColor;
        function slack(grow:Float):Div {
            return div().flexBasis(px(0.)).flexGrow(grow).flexShrink(0.).borderColor(style.border()).refineStyle(slackStyle);
        }

        final rowCount = table.children.length;
        final radii = tableRowCornerRadii(style, window);
        final topLeft = radii[0];
        final topRight = radii[1];
        final bottomLeft = radii[2];
        final bottomRight = radii[3];
        final rows:Array<AnyElement> = [];
        var cellOrdinal = 0;
        for (rowIx in 0...table.children.length) {
            final row = table.children[rowIx];
            final cells:Array<AnyElement> = [];
            for (ix in 0...columns.length) {
                final column = columns[ix];
                final isLastCol = ix + 1 == colCount;
                final align = table.columnAlign(ix);
                var content:Null<AnyElement> = null;
                if (ix < row.children.length) {
                    final cell = row.children[ix];
                    final fadeKey = table.span != null ? TextLeafKey.tableCell(table.span.start, cellOrdinal) : null;
                    cellOrdinal += 1;
                    content = renderParagraph(cell.children, fadeKey, nodeCx, window, cx);
                }

                final grow = f32(f32(SLACK_GROW * column.max) / totalW);
                final lead = switch align {
                    case None | Left: 0.;
                    case Center: f32(grow / 2.);
                    case Right: grow;
                }
                final trail = switch align {
                    case None | Left: grow;
                    case Center: f32(grow / 2.);
                    case Right: 0.;
                }
                if (lead > 0.) {
                    cells.push(slack(lead).intoAnyElement());
                }
                final cellDiv = div().flexBasis(px(0.)).flexGrow(CELL_GROW).minW(px(column.min)).maxW(px(column.max)).overflowHidden();
                if (align == Center)
                    cellDiv.textCenter();
                if (align == Right)
                    cellDiv.textRight();
                cellDiv.px3().py(px(7.)).refineStyle(style.tableCell());
                if (content != null)
                    cellDiv.child(content);
                cells.push(new TableCellElement(cellDiv.intoAnyElement()).intoAnyElement());
                if (trail > 0. || !isLastCol) {
                    final trailing = slack(trail);
                    if (!isLastCol)
                        trailing.borderR1();
                    cells.push(trailing.intoAnyElement());
                }
            }
            final rowDiv = div().wFull();
            if (rowIx < rowCount - 1)
                rowDiv.borderB1();
            rowDiv.borderColor(style.border()).flex().flexRow();
            // The first row is the header, as everywhere else that reads a
            // table (`tableData`, `toMarkdown`). The refinement comes last so
            // it can override the defaults.
            if (rowIx == 0) {
                rowDiv.bg(style.codeBackground()).textColor(style.foreground());
                if (topLeft != null)
                    rowDiv.roundedTl(px(topLeft));
                if (topRight != null)
                    rowDiv.roundedTr(px(topRight));
                rowDiv.refineStyle(style.tableHead());
            }
            if (rowIx + 1 == rowCount) {
                if (bottomLeft != null)
                    rowDiv.roundedBl(px(bottomLeft));
                if (bottomRight != null)
                    rowDiv.roundedBr(px(bottomRight));
            }
            rows.push(rowDiv.children(intoElements(cells)).intoAnyElement());
        }
        return rows;
    }

    // Blocks

    public static function renderBlock(block:BlockNode, options:NodeRenderOptions, nodeCx:NodeContext, window:Window, cx:App):AnyElement {
        final mb = blockGap(options, nodeCx.style);

        switch block {
            case Root(children, _):
                final container = div();
                for (ix in 0...children.length) {
                    final node = children[ix];
                    // A nested root (an HTML block container) continues the
                    // flow around it: until it shows a block of its own, it
                    // stands where the container stands.
                    final position = ParsedDocument.flowPosition(children, ix);
                    final childOptions = options.copy();
                    childOptions.ix = ix;
                    if (position.isFirst) {
                        childOptions.isFirst = options.isFirst;
                        childOptions.prev = options.prev;
                    } else {
                        childOptions.isFirst = false;
                        childOptions.prev = position.prev;
                    }
                    childOptions.isLast = options.isLast && ix + 1 == children.length;
                    container.child(renderBlock(node, childOptions, nodeCx, window, cx));
                }
                return container.intoAnyElement();
            case Paragraph(paragraph):
                return gapped(renderParagraph(paragraph, paragraph.span != null ? TextLeafKey.block(paragraph.span.start) : null, nodeCx, window, cx),
                    mb);
            case Heading(level, children, span):
                final metrics = headingMetrics(level);
                final lineHeight = metrics[1];
                final sectionGap = metrics[2];
                final refinement = nodeCx.style.heading(level);
                final textSize = headingSize(level, nodeCx, window);
                // The previous block already leaves a gap below itself, so
                // only the rest of the section gap is added here: the two
                // collapse like CSS margins. A heading right after another
                // one belongs to the same section and stays close. Nested in
                // a list item, a heading sits flush with the item.
                final top:Float = if (options.isFirst || options.depth > 0) {
                    0.;
                } else {
                    switch options.prev {
                        case Heading(_): f32(textSize * 0.25);
                        case Rule: Math.max(f32(f32(textSize * f32(sectionGap)) - (ruleSpace(bodyFontSize(nodeCx, window)) : Float)), 0.);
                        case Other: Math.max(f32(f32(textSize * f32(sectionGap)) - (nodeCx.style.paragraphGap().toPixels(window.remSize()) : Float)), 0.);
                    }
                }
                final bottom:Float = options.isLast ? 0. : f32(textSize * f32(HEADING_BOTTOM_GAP));

                final heading = div().pt(px(top))
                    .pb(px(bottom))
                    .whitespaceNormal()
                    .textSize(textSize)
                    .lineHeight(relative(lineHeight))
                    .fontWeight(FontWeight.SEMIBOLD);
                if (level >= 6)
                    heading.textColor(nodeCx.style.mutedForeground());
                return heading.refineStyle(refinement)
                    .child(renderParagraph(children, span != null ? TextLeafKey.block(span.start) : null, nodeCx, window, cx))
                    .intoAnyElement();
            case Blockquote(children, _):
                final quote = div().wFull()
                    .textColor(nodeCx.style.mutedForeground())
                    .borderL2()
                    .borderColor(nodeCx.style.border())
                    .pl(px(f32(bodyFontSize(nodeCx, window) * f32(0.9))))
                    .refineStyle(nodeCx.style.blockquoteStyle());
                // Nested tables measure while rendering, before this div
                // applies its text style.
                final childrenLen = children.length;
                for (index in 0...children.length) {
                    final c = children[index];
                    final isLast = index == childrenLen - 1;
                    final position = ParsedDocument.flowPosition(children, index);
                    final quoteText = nodeCx.style.blockquoteStyle().text;
                    quote.child(window.withTextStyle(quoteText != null ? quoteText.clone() : new TextStyleRefinement(), window -> {
                        final childOptions = options.withIsLast(isLast);
                        childOptions.isFirst = position.isFirst;
                        childOptions.prev = position.prev;
                        return renderBlock(c, childOptions, nodeCx, window, cx);
                    }));
                }
                return gapped(quote.intoAnyElement(), mb);
            case List(children, ordered, start, _):
                final list = div().wFull().minW0().pb(mb);
                var itemIndex = 0;
                for (ix in 0...children.length) {
                    final item = children[ix];
                    final isItem = item.isListItem();

                    final itemOptions = options.copy();
                    itemOptions.ix = ix;
                    itemOptions.ordered = ordered;
                    itemOptions.listStart = start;
                    list.child(renderListItem(item, itemIndex, itemOptions, nodeCx, window, cx));

                    if (isItem) {
                        itemIndex += 1;
                    }
                }
                return list.intoAnyElement();
            case CodeBlock(codeBlock):
                return codeBlock.render(options, nodeCx, window, cx);
            case Custom(node, state):
                final rendered = nodeCx.markdownExtensions.renderBlock(node, window, cx);
                final inner:AnyElement = rendered != null ? rendered : div().child(node.asText()).intoAnyElement();

                return div().pb(mb).child(new CustomBlockElement(inner, state)).intoAnyElement();
            case Table(_):
                // Tables are data and read a step denser than the body. The
                // columns are measured while rendering, so they are measured
                // at the same size the cells are laid out with; the actions
                // row below keeps the body size.
                final textSize:Pixels = f32(bodyFontSize(nodeCx, window) * f32(14. / 15.));
                final refinement = new TextStyleRefinement();
                refinement.fontSize = glaze.AbsoluteLength.Pixels(textSize);
                return window.withTextStyle(refinement, window -> renderTable(block, options, nodeCx, textSize, window, cx));
            case HorizontalRule(_):
                // A section break: a hairline with more room around it than a
                // paragraph gap. The previous block's own gap counts toward
                // the space above, as with headings.
                final space = ruleSpace(bodyFontSize(nodeCx, window));
                final top:Float = if (options.isFirst || options.depth > 0) {
                    0.;
                } else {
                    final above:Float = switch options.prev {
                        case Rule: space;
                        case Heading(level): f32(headingSize(level, nodeCx, window) * f32(HEADING_BOTTOM_GAP));
                        case Other: nodeCx.style.paragraphGap().toPixels(window.remSize());
                    }
                    Math.max(f32(space - above), 0.);
                }
                final rule = div().pt(px(top));
                if (!options.isLast)
                    rule.pb(space);
                return rule.child(div().bg(nodeCx.style.border()).h(px(1.))).intoAnyElement();
            case Break(_, _):
                return div().intoAnyElement();
            case Unknown | Definition(_, _, _, _):
                return div().intoAnyElement();
            case ListItem(_, _, _, _):
                // Rust logs `unknown implementation` in debug builds.
                return div().intoAnyElement();
        }
    }

}

/** A table column's cell widths for layout, excluding the divider after it. */
class TableColumn {

    /** The width below which the column stops shrinking. */
    public final min:Float;

    /** The width that fits the content on its widest line. */
    public final max:Float;

    public final divider:Float;

    public function new(min:Float, max:Float, divider:Float) {
        this.min = min;
        this.max = max;
        this.divider = divider;
    }

}

/**
 * A table cell, laid out as its content. Text painted inside it knows its
 * cell, so a drag that starts in the cell selects only in that cell.
 */
class TableCellElement extends Element {

    final content:AnyElement;

    public function new(content:AnyElement) {
        this.content = content;
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        return content.requestLayout(window, cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        // Prepaint runs for the whole window before any text paints, so the
        // cell that holds the anchor is known to all text, in every view.
        final view = NodeRender.textViewState(cx);
        if (view != null) {
            view.read(cx).selectionAdapter.recordTableCell(bounds, cx);
        }
        GlobalState.global(cx).pushTableCell(bounds);
        content.prepaint(window, cx);
        GlobalState.global(cx).popTableCell();
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        GlobalState.global(cx).pushTableCell(bounds);
        content.paint(window, cx);
        GlobalState.global(cx).popTableCell();
    }

}

/** Observe the plugin's own bounds without changing its layout or listeners. */
class CustomBlockElement extends Element {

    final content:AnyElement;
    final state:BlockState;

    public function new(content:AnyElement, state:BlockState) {
        this.content = content;
        this.state = state;
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        return content.requestLayout(window, cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        content.prepaint(window, cx);
    }

    @:access(glaze.kit.base.text.BlockState)
    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final view = NodeRender.textViewState(cx);
        var selection:Null<BlockState.BlockSelection> = null;
        if (view != null) {
            final viewState = view.read(cx);
            if (!viewState.isSelectable()) {
                selection = null;
            } else if (viewState.isAllSelected()) {
                selection = Full;
            } else if (viewState.preserveInlineSelection) {
                selection = state.selection();
            } else {
                final points = viewState.paintedSelectionPoints(cx);
                selection = points != null ? BlockState.customBlockSelection(bounds, points.start, points.end) : null;
            }
        }
        state.setSelection(selection);
        if (view != null) {
            final viewState = view.read(cx);
            if (viewState.isSelectable()) {
                viewState.selectionAdapter.registerCopyProjection(CopyProjection.CustomBlock(new BlockState.CustomBlockSelectionProjection(state,
                    bounds)), cx);
            }
            final visible = bounds.intersect(window.contentMask().bounds);
            if (viewState.isSelectable() && visible.size.width > 0 && visible.size.height > 0) {
                viewState.selectionAdapter.registerInline([visible]);
            }
        }
        content.paint(window, cx);
        if (selection == Full) {
            final color = view.read(cx).textViewStyle.selection();
            window.paintQuad(fill(bounds, color));
        }
    }

}
