// Ported from gpui-kit 0.8.1: crates/base/src/text/node.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.text;

import glaze.AnyElement;
import glaze.App;
import glaze.Window;

/**
 * The block-level nodes.
 *
 * This is the document tree TextView renders. Together with `EditorHost` it
 * is also the hand-over type for external editors: they build the tree,
 * render it with `BlockNodeTools.render` and read geometry back per leaf.
 *
 * Methods are in `BlockNodeTools` (attached with `@:using`).
 */
@:using(glaze.kit.base.text.BlockNode.BlockNodeTools)
enum BlockNode {

    /** Something like a Div container in HTML. */
    Root(children:Array<BlockNode>, span:Null<Span>);

    Paragraph(paragraph:glaze.kit.base.text.Paragraph);

    Heading(level:Int, children:glaze.kit.base.text.Paragraph, span:Null<Span>);

    Blockquote(children:Array<BlockNode>, span:Null<Span>);

    /**
     * `children` only contains ListItem, others will be ignored. `start` is
     * the first ordinal for an ordered list; HTML lists leave it unset.
     */
    List(children:Array<BlockNode>, ordered:Bool, start:Null<Int>, span:Null<Span>);

    /** `checked`: whether the list item is checked, if null, it's not a checkbox. */
    ListItem(children:Array<BlockNode>, spread:Bool, checked:Null<Bool>, span:Null<Span>);

    CodeBlock(codeBlock:glaze.kit.base.text.CodeBlock);

    /** A custom Markdown node produced by `MarkdownExtensions`. */
    Custom(node:MarkdownNode, state:BlockState);

    Table(table:glaze.kit.base.text.Table);

    Break(html:Bool, span:Null<Span>);

    HorizontalRule(span:Null<Span>);

    /** Use for toMarkdown get raw definition */
    Definition(identifier:String, url:String, title:Null<String>, span:Null<Span>);

    Unknown;

}

/** Rust `BlockTextKind`. */
enum abstract BlockTextKind(Int) {
    var All = 0;
    var Selected = 1;

    /**
     * Like `Selected`, but reconstructs Markdown source for the selection
     * instead of the rendered plain text.
     */
    var SelectedSource = 2;
}

/**
 * Methods of `BlockNode`.
 */
@:allow(glaze.kit.base.text)
class BlockNodeTools {

    public static function isListItem(self:BlockNode):Bool {
        return self.match(ListItem(_, _, _, _));
    }

    /** Combine all children, omitting the empty parent nodes. */
    public static function compact(self:BlockNode):BlockNode {
        return switch self {
            case Root(children, _) if (children.length == 1): compact(children[0]);
            case _: self;
        }
    }

    /** Get the span of the node. */
    public static function span(self:BlockNode):Null<Span> {
        return switch self {
            case Root(_, span): span;
            case Paragraph(paragraph): paragraph.span;
            case Heading(_, _, span): span;
            case Blockquote(_, span): span;
            case List(_, _, _, span): span;
            case ListItem(_, _, _, span): span;
            case CodeBlock(codeBlock): codeBlock.span;
            case Custom(node, _): node.span;
            case Table(table): table.span;
            case Break(_, span): span;
            case HorizontalRule(span): span;
            case Definition(_, _, _, span): span;
            case Unknown: null;
        }
    }

    /** A copy of the node with another span (Rust assigns the field in place). */
    public static function withSpan(self:BlockNode, span:Null<Span>):BlockNode {
        return switch self {
            case Root(children, _): Root(children, span);
            case Paragraph(paragraph):
                paragraph.span = span;
                self;
            case Heading(level, children, _): Heading(level, children, span);
            case Blockquote(children, _): Blockquote(children, span);
            case List(children, ordered, start, _): List(children, ordered, start, span);
            case ListItem(children, spread, checked, _): ListItem(children, spread, checked, span);
            case CodeBlock(codeBlock):
                codeBlock.span = span;
                self;
            case Custom(node, _):
                node.span = span;
                self;
            case Table(table):
                table.span = span;
                self;
            case Break(html, _): Break(html, span);
            case HorizontalRule(_): HorizontalRule(span);
            case Definition(identifier, url, title, _): Definition(identifier, url, title, span);
            case Unknown: Unknown;
        }
    }

    public static function text(self:BlockNode):String {
        return textByKind(self, All);
    }

    /**
     * The selected text within this block, in `format`.
     *
     * `SelectionFormat.Source` reconstructs the Markdown source of the
     * selection instead of the rendered text.
     */
    public static function selectedText(self:BlockNode, format:SelectionFormat):String {
        return textByKind(self, switch format {
            case Plain: Selected;
            case _: SelectedSource;
        });
    }

    /** How many styles the selection within this block takes in. */
    public static function selectionStyles(self:BlockNode):SelectionStyles {
        var styles:SelectionStyles = None;
        switch self {
            case Root(children, _) | Blockquote(children, _) | List(children, _, _, _) | ListItem(children, _, _, _):
                for (child in children) {
                    styles = styles.merge(selectionStyles(child));
                }
            case Paragraph(paragraph):
                styles = paragraph.selectionStyles();
            case Heading(_, children, _):
                styles = children.selectionStyles();
            case Table(table):
                for (row in table.children) {
                    for (cell in row.children) {
                        styles = styles.merge(cell.children.selectionStyles());
                    }
                }
            case CodeBlock(codeBlock):
                if (codeBlock.hasSelection()) {
                    styles = One;
                }
            // A plugin's text stands in for content its source spells out.
            case Custom(_, state):
                if (state.isSelected()) {
                    styles = Mixed;
                }
            case Definition(_, _, _, _) | Break(_, _) | HorizontalRule(_) | Unknown:
        }
        return styles;
    }

    public static function selectedSourceRange(self:BlockNode):SourceRangeSelection {
        var selected = SourceRangeSelection.unselected();
        switch self {
            case Root(children, _) | Blockquote(children, _) | List(children, _, _, _) | ListItem(children, _, _, _):
                for (child in children) {
                    selected.merge(selectedSourceRange(child));
                }
            case Paragraph(paragraph):
                selected = paragraph.selectedSourceRange();
            case Heading(_, children, _):
                selected = children.selectedSourceRange();
            case Table(table):
                for (row in table.children) {
                    for (cell in row.children) {
                        selected.merge(cell.children.selectedSourceRange());
                    }
                }
            case CodeBlock(codeBlock):
                selected = codeBlock.selectedSourceRange();
            case Custom(node, state):
                if (state.isSelected()) {
                    final range = node.sourceRange();
                    selected = range != null ? SourceRangeSelection.mapped(range) : SourceRangeSelection.unmapped();
                }
            case Definition(_, _, _, _) | Break(_, _) | HorizontalRule(_) | Unknown:
        }
        return selected;
    }

    static function textByKind(self:BlockNode, kind:BlockTextKind):String {
        final text = new StringBuf();
        switch self {
            case Root(children, _):
                final blockText = childrenText(children, kind);
                if (blockText != '') {
                    text.add(blockText);
                    text.add('\n');
                }
            case Paragraph(paragraph):
                final blockText = switch kind {
                    case All: paragraph.text();
                    case Selected: paragraph.selectedText();
                    case SelectedSource: paragraph.selectedSource();
                }
                if (blockText != '') {
                    text.add(blockText);
                    text.add('\n');
                }
            case Heading(level, children, _):
                final blockText = switch kind {
                    case All: children.text();
                    case Selected: children.selectedText();
                    case SelectedSource: children.selectedSource();
                }
                if (blockText != '') {
                    // In source mode, prefix the heading marker so a selected
                    // heading round-trips as Markdown (e.g. `## Title`).
                    if (kind == SelectedSource) {
                        text.add(TextUtils.repeat('#', level));
                        text.add(' ');
                    }
                    text.add(blockText);
                    text.add('\n');
                }
            case List(children, ordered, start, _):
                if (kind == SelectedSource) {
                    // Reconstruct the list source, indenting nested lists and
                    // restoring list markers and task-list checkboxes.
                    text.add(listSelectedSource(children, ordered, start, ''));
                } else {
                    text.add(childrenText(children, kind));
                }
            case ListItem(children, _, _, _):
                text.add(childrenText(children, kind));
            case Blockquote(children, _):
                final blockText = childrenText(children, kind);

                if (blockText != '') {
                    if (kind == SelectedSource) {
                        // Prefix every line with `> ` so a selected blockquote
                        // round-trips as Markdown.
                        final quoted = [
                            for (line in TextUtils.lines(TextUtils.trimEndMatches(blockText, '\n')))
                                line == '' ? '>' : '> ' + line
                        ].join('\n');
                        text.add(quoted);
                    } else {
                        text.add(blockText);
                    }
                    text.add('\n');
                }
            case Table(table):
                if (kind == SelectedSource) {
                    final blockText = glaze.kit.base.text.Table.tableSelectedSource(table);
                    if (blockText != '') {
                        text.add(blockText);
                        text.add('\n');
                    }
                } else {
                    final blockText = new StringBuf();
                    var blockTextEmpty = true;
                    for (row in table.children) {
                        final rowTexts:Array<String> = [];
                        for (cell in row.children) {
                            switch kind {
                                case All:
                                    rowTexts.push(cell.children.text());
                                // Source is handled above; only Selected reaches
                                // here. A cell with nothing selected adds nothing,
                                // so a selection in one cell copies only its text.
                                case _:
                                    final selected = cell.children.selectedText();
                                    if (selected != '') {
                                        rowTexts.push(selected);
                                    }
                            }
                        }
                        if (rowTexts.length > 0) {
                            blockText.add(rowTexts.join(' '));
                            blockText.add('\n');
                            blockTextEmpty = false;
                        }
                    }

                    if (!blockTextEmpty) {
                        text.add(blockText.toString());
                        text.add('\n');
                    }
                }
            case CodeBlock(codeBlock):
                final blockText = switch kind {
                    case All: codeBlock.text();
                    case Selected: codeBlock.selectedText();
                    case SelectedSource: codeBlock.selectedSource();
                }
                if (blockText != '') {
                    text.add(blockText);
                    text.add('\n');
                }
            case Custom(node, state):
                if (kind == All || state.isSelected()) {
                    final content = switch kind {
                        case SelectedSource: node.toMarkdown();
                        case _: node.asText();
                    }
                    if (content != '') {
                        text.add(content);
                        text.add('\n');
                    }
                }
            case Definition(_, _, _, _) | Break(_, _) | HorizontalRule(_) | Unknown:
        }

        return text.toString();
    }

    static function childrenText(children:Array<BlockNode>, kind:BlockTextKind):String {
        final text = new StringBuf();
        for (child in children) {
            text.add(textByKind(child, kind));
        }
        return text.toString();
    }

    /**
     * Whether this block carries a selection, even an empty one.
     *
     * A block only learns its selection when it is painted, so this doubles
     * as "this block was on screen while the selection was made". An empty
     * selection is the caret left by the press that started the drag, which
     * is why it counts (see `ParsedDocument.selectedText`).
     */
    public static function hasSelection(self:BlockNode):Bool {
        return switch self {
            case Root(children, _) | Blockquote(children, _) | List(children, _, _, _) | ListItem(children, _, _, _):
                Lambda.exists(children, child -> hasSelection(child));
            case Paragraph(paragraph): paragraph.hasSelection();
            case Heading(_, children, _): children.hasSelection();
            case Table(table):
                Lambda.exists(table.children, row -> Lambda.exists(row.children, cell -> cell.children.hasSelection()));
            case CodeBlock(codeBlock): codeBlock.hasSelection();
            case Custom(_, state):
                // An observed empty endpoint must suppress virtualized copy fallback.
                state.hasSelectionObservation();
            case Definition(_, _, _, _) | Break(_, _) | HorizontalRule(_) | Unknown: false;
        }
    }

    /**
     * Synchronously clear the selection stored in every inline state.
     *
     * Mirrors the `selectedText` traversal so the selection can be cleared
     * without relying on a repaint.
     */
    public static function clearSelection(self:BlockNode):Void {
        switch self {
            case Root(children, _) | Blockquote(children, _) | List(children, _, _, _) | ListItem(children, _, _, _):
                for (child in children) {
                    clearSelection(child);
                }
            case Paragraph(paragraph):
                paragraph.clearSelection();
            case Heading(_, children, _):
                children.clearSelection();
            case Table(table):
                for (row in table.children) {
                    for (cell in row.children) {
                        cell.children.clearSelection();
                    }
                }
            case CodeBlock(codeBlock):
                codeBlock.clearSelection();
            case Custom(_, state):
                state.clearSelection();
            case Definition(_, _, _, _) | Break(_, _) | HorizontalRule(_) | Unknown:
        }
    }

    /**
     * Reconstruct the Markdown source of the selected items of a list.
     *
     * Restores the list marker (`- ` / `N. `) and task-list checkbox
     * (`[x] ` / `[ ] `) of each item, and recurses into nested lists with a
     * deeper `indent` so nesting is preserved. Items with no selected content
     * are skipped but still consume an ordered number, so the remaining
     * items keep their original numbering.
     */
    static function listSelectedSource(children:Array<BlockNode>, ordered:Bool, start:Null<Int>, indent:String):String {
        final out = new StringBuf();
        var itemIx = 0;

        for (child in children) {
            switch child {
                case ListItem(itemChildren, _, checked, _):
                    final marker = ordered ? TextUtils.ordinalString(TextUtils.orderedListOrdinal(start, itemIx)) + '. ' : '- ';
                    final checkbox = checked == null ? '' : (checked ? '[x] ' : '[ ] ');
                    final childIndent = indent + TextUtils.repeat(' ', marker.length);

                    // Split the item into its own content and any nested lists, so the
                    // nested lists can be indented under the content.
                    final contentBuf = new StringBuf();
                    final nestedBuf = new StringBuf();
                    for (sub in itemChildren) {
                        switch sub {
                            case List(subChildren, subOrdered, subStart, _):
                                nestedBuf.add(listSelectedSource(subChildren, subOrdered, subStart, childIndent));
                            case _:
                                contentBuf.add(textByKind(sub, SelectedSource));
                        }
                    }
                    final content = TextUtils.trimEndMatches(contentBuf.toString(), '\n');
                    final nested = nestedBuf.toString();

                    if (content == '' && nested == '') {
                        itemIx += 1;
                        continue;
                    }

                    if (content == '') {
                        // An item whose only selected content is a nested list.
                        out.add(indent);
                        out.add(marker);
                        out.add(TextUtils.trimEnd(checkbox));
                        out.add('\n');
                    } else {
                        // The first line carries the marker and checkbox; continuation
                        // lines are indented to align under the item text.
                        final lines = TextUtils.lines(content);
                        if (lines.length > 0) {
                            out.add(indent);
                            out.add(marker);
                            out.add(checkbox);
                            out.add(lines[0]);
                            out.add('\n');
                        }
                        for (i in 1...lines.length) {
                            out.add(childIndent);
                            out.add(lines[i]);
                            out.add('\n');
                        }
                    }
                    out.add(nested);
                    itemIx += 1;
                case _:
            }
        }

        return out.toString();
    }

    /**
     * Converts the node to markdown format.
     *
     * This is used to generate markdown for test.
     */
    public static function toMarkdown(self:BlockNode):String {
        final result = switch self {
            case Root(children, _):
                [for (child in children) toMarkdown(child)].join('\n\n');
            case Paragraph(paragraph):
                paragraph.toMarkdown();
            case Heading(level, children, _):
                TextUtils.repeat('#', level) + ' ' + children.toMarkdown();
            case Blockquote(children, _):
                final content = [for (child in children) toMarkdown(child)].join('\n\n');
                [for (line in TextUtils.lines(content)) '> ' + line].join('\n');
            case List(children, ordered, start, _):
                [
                    for (i in 0...children.length) {
                        final prefix = ordered ? TextUtils.ordinalString(TextUtils.orderedListOrdinal(start, i)) + '. ' : '- ';
                        prefix + toMarkdown(children[i]);
                    }
                ].join('\n');
            case ListItem(children, _, checked, _):
                final checkbox = checked == null ? '' : (checked ? '[x] ' : '[ ] ');
                checkbox + [for (child in children) toMarkdown(child)].join('\n');
            case CodeBlock(codeBlock):
                '```' + (codeBlock.lang() != null ? codeBlock.lang() : '') + '\n' + codeBlock.code() + '\n```';
            case Table(table):
                table.toMarkdown();
            case Break(html, _):
                html ? '<br>' : '\n';
            case HorizontalRule(_):
                '---';
            case Custom(node, _):
                node.toMarkdown();
            case Definition(identifier, url, title, _):
                title != null ? '[$identifier]: $url "$title"' : '[$identifier]: $url';
            case Unknown:
                '';
        }
        return TextUtils.trim(result);
    }

    /**
     * Rust `Clone`: a deep copy of the tree that shares the runtime state of
     * the leaves (`Arc`).
     */
    public static function clone(self:BlockNode):BlockNode {
        inline function cloneAll(children:Array<BlockNode>):Array<BlockNode> {
            return [for (child in children) clone(child)];
        }
        inline function cloneSpan(span:Null<Span>):Null<Span> {
            return span != null ? span.copy() : null;
        }
        return switch self {
            case Root(children, span): Root(cloneAll(children), cloneSpan(span));
            case Paragraph(paragraph): Paragraph(paragraph.clone());
            case Heading(level, children, span): Heading(level, children.clone(), cloneSpan(span));
            case Blockquote(children, span): Blockquote(cloneAll(children), cloneSpan(span));
            case List(children, ordered, start, span): List(cloneAll(children), ordered, start, cloneSpan(span));
            case ListItem(children, spread, checked, span): ListItem(cloneAll(children), spread, checked, cloneSpan(span));
            case CodeBlock(codeBlock): CodeBlock(codeBlock.clone());
            case Custom(node, state): Custom(node.clone(), state);
            case Table(table): Table(table.clone());
            case Break(html, span): Break(html, cloneSpan(span));
            case HorizontalRule(span): HorizontalRule(cloneSpan(span));
            case Definition(identifier, url, title, span): Definition(identifier, url, title, cloneSpan(span));
            case Unknown: Unknown;
        }
    }

    /** Rust `PartialEq`. */
    public static function equals(self:BlockNode, other:BlockNode):Bool {
        inline function allEqual(a:Array<BlockNode>, b:Array<BlockNode>):Bool {
            return arrayEquals(a, b);
        }
        return switch [self, other] {
            case [Root(a, sa), Root(b, sb)]: allEqual(a, b) && Span.eq(sa, sb);
            case [Paragraph(a), Paragraph(b)]: a.equals(b);
            case [Heading(la, a, sa), Heading(lb, b, sb)]: la == lb && a.equals(b) && Span.eq(sa, sb);
            case [Blockquote(a, sa), Blockquote(b, sb)]: allEqual(a, b) && Span.eq(sa, sb);
            case [List(a, oa, sta, sa), List(b, ob, stb, sb)]: allEqual(a, b) && oa == ob && sta == stb && Span.eq(sa, sb);
            case [ListItem(a, spa, ca, sa), ListItem(b, spb, cb, sb)]: allEqual(a, b) && spa == spb && ca == cb && Span.eq(sa, sb);
            case [CodeBlock(a), CodeBlock(b)]: a.equals(b);
            case [Custom(a, sta), Custom(b, stb)]: a.equals(b) && sta.equals(stb);
            case [Table(a), Table(b)]: a.equals(b);
            case [Break(ha, sa), Break(hb, sb)]: ha == hb && Span.eq(sa, sb);
            case [HorizontalRule(sa), HorizontalRule(sb)]: Span.eq(sa, sb);
            case [Definition(ia, ua, ta, sa), Definition(ib, ub, tb, sb)]: ia == ib && ua == ub && ta == tb && Span.eq(sa, sb);
            case [Unknown, Unknown]: true;
            case _: false;
        }
    }

    public static function arrayEquals(a:Array<BlockNode>, b:Array<BlockNode>):Bool {
        if (a.length != b.length)
            return false;
        for (i in 0...a.length) {
            if (!equals(a[i], b[i]))
                return false;
        }
        return true;
    }

    /**
     * Renders this block as a document block (Rust `render_block`): the
     * spacing, list and table chrome around it included.
     */
    public static function renderBlock(self:BlockNode, options:NodeRenderOptions, nodeCx:NodeContext, window:Window, cx:App):AnyElement {
        return NodeRender.renderBlock(self, options, nodeCx, window, cx);
    }

}
