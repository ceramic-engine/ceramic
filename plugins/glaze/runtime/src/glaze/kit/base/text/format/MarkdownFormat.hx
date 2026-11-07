// Ported from gpui-kit 0.8.1: crates/base/src/text/format/markdown.rs, crates/base/src/text/format/mod.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text.format;

import gpui.Hsla;
import gpui.Range;
import gpui.base.text.BlockNode;
import gpui.base.text.BlockState;
import gpui.base.text.CodeBlock;
import gpui.base.text.ColumnumnAlign;
import gpui.base.text.ImageNode;
import gpui.base.text.InlineNode;
import gpui.base.text.LinkMark;
import gpui.base.text.MarkdownNode;
import gpui.base.text.MarkdownParseContext;
import gpui.base.text.NodeContext;
import gpui.base.text.Paragraph;
import gpui.base.text.ParsedDocument;
import gpui.base.text.RangedMark;
import gpui.base.text.SourceSegment;
import gpui.base.text.Span;
import gpui.base.text.Table;
import gpui.base.text.TextMark;
import gpui.base.text.TextUtils;
import haxe.io.Bytes;
import markdown.Markdown;
import markdown.ParseOptions;
import markdown.mdast.Node.Node;
import markdown.unist.Point;
import markdown.unist.Position;

using markdown.mdast.NodeTools;

/**
 * The Markdown source with its UTF-8 bytes, converted once per parse so the
 * byte offset helpers below stay linear (Rust works on `&str` directly).
 */
private class SourceText {

    public final text:String;
    public final bytes:Bytes;

    public function new(text:String) {
        this.text = text;
        this.bytes = Bytes.ofString(text);
    }

}

/** Rust `enum InlineGroup<'a>`. */
private enum InlineGroup {

    /** Rust `InlineGroup::Node` (renamed: it would clash with the mdast `Node` type). */
    Single(node:Node);

    Marked(mark:TextMark, nodes:Array<Node>);

}

/** Rust `inline_html_tag` result `(closing, name, attrs)`. */
private class InlineHtmlTag {

    public final closing:Bool;
    public final name:String;
    public final attrs:String;

    public function new(closing:Bool, name:String, attrs:String) {
        this.closing = closing;
        this.name = name;
        this.attrs = attrs;
    }

}

/** Rust `decoded_entity` result `(decoded, source_len)`, decoded as UTF-8 bytes. */
private class DecodedEntity {

    public final decoded:Bytes;
    public final sourceLen:Int;

    public function new(decoded:Bytes, sourceLen:Int) {
        this.decoded = decoded;
        this.sourceLen = sourceLen;
    }

}

/**
 * Rust `Option<BTreeMap<char, Vec<usize>>>` of `source_char_offset`: the
 * byte offsets of every character of the remaining source, indexed after
 * the first failed search. `index` is `null` until then.
 */
class SourceCharPositions {

    public var index:Null<Map<Int, Array<Int>>> = null;

    public function new() {}

}

/**
 * Markdown to `ParsedDocument` (Rust `text/format/markdown.rs`; the free
 * functions are statics). `mod.rs` only declares the format modules.
 */
@:allow(gpui.base.text)
class MarkdownFormat {

    /**
     * Parse Markdown into a tree of nodes. Throws the error message (Rust
     * `Err(SharedString)`) when the parser rejects the source (MDX only).
     */
    public static function parse(source:String, cx:NodeContext):ParsedDocument {
        final options = cx.markdownExtensions.parseOptions();
        var root:Node;
        try {
            root = Markdown.toMdast(source, options);
        } catch (e:markdown.message.Message) {
            throw e.toString();
        }
        final prose = options;
        prose.constructs.mathText = false;
        prose.constructs.mathFlow = false;
        flattenUnclaimedMath(root, source, prose, cx);
        return astToDocument(new SourceText(source), root, cx);
    }

    /** `parse` returning the Rust `Result` as a value. */
    public static function tryParse(source:String, cx:NodeContext):{document:Null<ParsedDocument>, error:Null<String>} {
        try {
            return {document: parse(source, cx), error: null};
        } catch (e:String) {
            return {document: null, error: e};
        }
    }

    /**
     * Math parsing is on by default, so prose that merely contains two dollar
     * signs ("$5 and $10") parses as an inline math node. When no plugin
     * claims such a node, the text between the dollars must stay ordinary
     * Markdown: emphasis, inline HTML and links inside it render as they
     * would anywhere else, and inline HTML tags may pair with tags outside
     * the span. Re-parse the node's source without the math constructs and,
     * when it holds any markup, splice the result into its parent with
     * positions shifted back into the document. Plain prose keeps the literal
     * node, whose atomic source mapping the selection tests rely on.
     */
    static function flattenUnclaimedMath(node:Node, source:String, options:ParseOptions, cx:NodeContext):Void {
        final children = node.children();
        if (children == null)
            return;
        var ix = 0;
        while (ix < children.length) {
            final prose:Null<Array<Node>> = switch children[ix] {
                case InlineMath(_):
                    final parseCx = new MarkdownParseContext(source, cx.offset);
                    if (cx.markdownExtensions.parseInline(children[ix], parseCx) != null) {
                        null;
                    } else {
                        reparseAsProse(children[ix], source, options);
                    }
                case _:
                    null;
            }
            if (prose != null) {
                final count = prose.length;
                children.splice(ix, 1);
                for (i in 0...count)
                    children.insert(ix + i, prose[i]);
                ix += count;
                continue;
            }
            flattenUnclaimedMath(children[ix], source, options, cx);
            ix += 1;
        }
    }

    static function reparseAsProse(node:Node, source:String, options:ParseOptions):Null<Array<Node>> {
        final nodePosition = node.position();
        if (nodePosition == null)
            return null;
        final position = nodePosition.clone();
        final literal = TextUtils.byteSlice(source, position.start.offset, position.end.offset);
        if (literal == null)
            return null;
        if (!mayHoldInlineMarkup(literal))
            return null;
        var parsed:Node;
        try {
            parsed = Markdown.toMdast(literal, options);
        } catch (e:markdown.message.Message) {
            return null;
        }
        final paragraph = switch parsed {
            case Root(root) if (root.children.length == 1):
                switch root.children[0] {
                    case Paragraph(paragraph): paragraph;
                    case _: return null;
                }
            case _:
                return null;
        }
        var allText = true;
        for (child in paragraph.children) {
            if (!child.match(Text(_))) {
                allText = false;
                break;
            }
        }
        if (allText)
            return null;
        final children = paragraph.children;
        paragraph.children = [];
        for (child in children) {
            shiftPositions(child, position.start);
        }
        return children;
    }

    /**
     * A cheap gate before re-parsing: every inline construct starts with one
     * of these bytes (tags, emphasis, code, links, images, escapes, entities,
     * strikethrough) or is a GFM autolink literal.
     */
    static function mayHoldInlineMarkup(literal:String):Bool {
        for (i in 0...literal.length) {
            switch StringTools.fastCodeAt(literal, i) {
                case '<'.code | '*'.code | '_'.code | '['.code | '`'.code | '~'.code | '\\'.code | '!'.code | '&'.code:
                    return true;
                case _:
            }
        }
        return literal.indexOf('://') != -1 || literal.indexOf('www.') != -1;
    }

    static function shiftPositions(node:Node, origin:Point):Void {
        final position = node.position();
        if (position != null) {
            // New points instead of in place updates, so a point shared with
            // another node is never shifted twice.
            inline function shift(point:Point):Point {
                final firstLine = point.line == 1;
                return new Point(point.line + origin.line - 1, firstLine ? point.column + origin.column - 1 : point.column,
                    point.offset + origin.offset);
            }
            node.positionSet(new Position(shift(position.start), shift(position.end)));
        }
        final children = node.children();
        if (children != null) {
            for (child in children) {
                shiftPositions(child, origin);
            }
        }
    }

    /**
     * CommonMark hands each raw inline tag over as its own `Html` node, so
     * `<strong>x</strong>` arrives as three siblings and the tags alone carry
     * no text. Pair the formatting tags this renderer knows with their closing
     * tag among the siblings and treat what lies between as a marked run, the
     * same way `**x**` is handled.
     */
    static function inlineGroups(children:Array<Node>):Array<InlineGroup> {
        final groups:Array<InlineGroup> = [];
        var ix = 0;
        while (ix < children.length) {
            final tag = inlineHtmlTag(children[ix]);
            if (tag != null && !tag.closing) {
                final mark = inlineHtmlMark(tag.name, tag.attrs);
                if (mark != null) {
                    final close = matchingCloseTag(children, ix, tag.name);
                    if (close != -1) {
                        groups.push(Marked(mark, children.slice(ix + 1, close)));
                        ix = close + 1;
                        continue;
                    }
                }
            }
            groups.push(Single(children[ix]));
            ix += 1;
        }
        return groups;
    }

    static function inlineHtmlTag(node:Node):Null<InlineHtmlTag> {
        final html = switch node {
            case Html(html): html;
            case _: return null;
        }
        final trimmed = TextUtils.trim(html.value);
        if (!StringTools.startsWith(trimmed, '<'))
            return null;
        final afterOpen = trimmed.substr(1);
        if (!StringTools.endsWith(afterOpen, '>'))
            return null;
        final inner = afterOpen.substr(0, afterOpen.length - 1);
        if (StringTools.endsWith(inner, '/'))
            return null;
        final closing = StringTools.startsWith(inner, '/');
        final rest = closing ? inner.substr(1) : inner;
        var nameLen = 0;
        while (nameLen < rest.length && isAsciiAlphanumeric(StringTools.fastCodeAt(rest, nameLen)))
            nameLen++;
        final name = asciiLowercase(rest.substr(0, nameLen));
        final attrs = TextUtils.trim(rest.substr(nameLen));
        return name != '' ? new InlineHtmlTag(closing, name, attrs) : null;
    }

    static function inlineHtmlAttr(attrs:String, name:String):Null<String> {
        inline function isWhitespace(c:Int):Bool {
            return gpui.util.Utf8.isWhitespace(c);
        }
        var rest = attrs;
        while (rest != '') {
            rest = TextUtils.trimStart(rest);
            var keyLen = 0;
            while (keyLen < rest.length) {
                final c = StringTools.fastCodeAt(rest, keyLen);
                if (isWhitespace(c) || c == '='.code || c == '/'.code || c == '>'.code)
                    break;
                keyLen++;
            }
            if (keyLen == 0)
                break;
            final key = rest.substr(0, keyLen);
            rest = TextUtils.trimStart(rest.substr(keyLen));
            var value:String;
            if (StringTools.startsWith(rest, '=')) {
                rest = TextUtils.trimStart(rest.substr(1));
                final first = rest.length > 0 ? StringTools.fastCodeAt(rest, 0) : -1;
                if (first == '"'.code || first == "'".code) {
                    rest = rest.substr(1);
                    final end = rest.indexOf(gpui.util.Utf8.fromCodePoint(first));
                    if (end == -1)
                        return null;
                    value = rest.substr(0, end);
                    rest = rest.substr(end + 1);
                } else {
                    var end = 0;
                    while (end < rest.length && !isWhitespace(StringTools.fastCodeAt(rest, end)))
                        end++;
                    value = rest.substr(0, end);
                    rest = rest.substr(end);
                }
            } else {
                value = '';
            }
            if (asciiLowercase(key) == asciiLowercase(name)) {
                return value;
            }
        }
        return null;
    }

    static function inlineHtmlMark(name:String, attrs:String):Null<TextMark> {
        return switch name {
            case 'strong' | 'b': new TextMark().withBold();
            case 'em' | 'i': new TextMark().withItalic();
            case 'u': new TextMark().withUnderline();
            case 's' | 'del' | 'strike': new TextMark().withStrikethrough();
            case 'mark':
                var color:Null<Hsla> = HtmlFormat.markColorFromValues(inlineHtmlAttr(attrs, 'color'), inlineHtmlAttr(attrs, 'style'));
                if (color == null)
                    color = HtmlFormat.defaultMarkColor();
                new TextMark().withHighlight(color);
            case _: null;
        }
    }

    /** The index of the closing tag, `-1` for none (Rust `None`). */
    static function matchingCloseTag(children:Array<Node>, open:Int, name:String):Int {
        var depth = 0;
        for (ix in open + 1...children.length) {
            final tag = inlineHtmlTag(children[ix]);
            if (tag == null || tag.name != name)
                continue;
            if (!tag.closing) {
                depth += 1;
            } else {
                if (depth == 0) {
                    return ix;
                }
                depth -= 1;
            }
        }
        return -1;
    }

    static function parseInlineChildren(source:SourceText, paragraph:Paragraph, children:Array<Node>, cx:NodeContext):String {
        final text = new StringBuf();
        for (group in inlineGroups(children)) {
            switch group {
                case Single(child):
                    text.add(parseParagraph(source, paragraph, child, cx));
                case Marked(mark, nodes):
                    text.add(mergeChildrenWithMark(source, paragraph, nodes, mark, cx));
            }
        }
        return text.toString();
    }

    static function parseTableRow(source:SourceText, table:Table, node:markdown.mdast.Node.TableRow, cx:NodeContext):Void {
        final row = new TableRow();
        for (c in node.children) {
            switch c {
                case TableCell(cell):
                    parseTableCell(source, row, cell, cx);
                case _:
            }
        }
        // GFM fixes the column count with the header/delimiter. Leave missing
        // cells implicit; the renderer places them on the shared column grid.
        final columns = table.columnAligns_.length;
        if (row.children.length > columns)
            row.children.splice(columns, row.children.length - columns);
        table.children.push(row);
    }

    static function parseTableCell(source:SourceText, row:TableRow, node:markdown.mdast.Node.TableCell, cx:NodeContext):Void {
        final paragraph = new Paragraph();
        parseInlineChildren(source, paragraph, node.children, cx);
        row.children.push(new TableCell(paragraph));
    }

    /**
     * Push a text run with its existing `marks` plus `newMark` across the
     * full run.
     *
     * If the last mark already covers the full run, merge into it. Otherwise
     * add a new full-run mark. Empty runs are skipped so callers can flush
     * freely.
     */
    static function pushMerged(paragraph:Paragraph, text:String, marks:Array<RangedMark>, sourceSegments:Array<SourceSegment>,
            newMark:TextMark):Void {
        if (text == '') {
            return;
        }

        final node = new InlineNode(text).marks(marks).sourceSegments(sourceSegments);
        final len = TextUtils.len(node.text_);
        final last = node.marks_.length > 0 ? node.marks_[node.marks_.length - 1] : null;
        if (last != null && last.range.start == 0 && last.range.end == len) {
            last.mark.merge(newMark);
        } else {
            node.marks_.push(new RangedMark(new Range(0, len), newMark));
        }
        paragraph.push(node);
    }

    /**
     * Parse `children` and apply `mark` across each emitted text run.
     *
     * Nested child marks are kept and shifted to match the combined text for
     * the current run, which lets nested emphasis like `**_x_**` render as
     * both bold and italic. Inline images split the run and are emitted as
     * sibling image nodes. The return value is the plain text from all
     * children, for callers that need to pass text back to their parent node.
     */
    static function mergeChildrenWithMark(source:SourceText, paragraph:Paragraph, children:Array<Node>, mark:TextMark, cx:NodeContext):String {
        final text = new StringBuf();
        var mergedText = new StringBuf();
        var mergedLen = 0;
        var mergedMarks:Array<RangedMark> = [];
        var mergedSourceSegments:Array<SourceSegment> = [];

        inline function flush():Void {
            final taken = mergedText.toString();
            final takenMarks = mergedMarks;
            final takenSegments = mergedSourceSegments;
            mergedText = new StringBuf();
            mergedLen = 0;
            mergedMarks = [];
            mergedSourceSegments = [];
            pushMerged(paragraph, taken, takenMarks, takenSegments, mark.clone());
        }

        for (group in inlineGroups(children)) {
            final childParagraph = new Paragraph();
            final childText = switch group {
                case Single(child): parseParagraph(source, childParagraph, child, cx);
                case Marked(childMark, nodes): mergeChildrenWithMark(source, childParagraph, nodes, childMark, cx);
            }
            text.add(childText);

            for (node in childParagraph.children_) {
                if (node.custom != null) {
                    flush();
                    if (node.marks_.length > 0) {
                        node.marks_[0].mark.merge(mark.clone());
                    } else {
                        node.marks_.push(new RangedMark(new Range(0, TextUtils.len(node.text_)), mark.clone()));
                    }
                    paragraph.push(node);
                    continue;
                }
                final mergedOffset = mergedLen;
                mergedText.add(node.text_);
                mergedLen += TextUtils.len(node.text_);
                for (segment in node.sourceSegments_) {
                    mergedSourceSegments.push(new SourceSegment(new Range(segment.rendered.start + mergedOffset,
                        segment.rendered.end + mergedOffset), segment.source, segment.linear));
                }
                node.sourceSegments_ = [];

                for (ranged in node.marks_) {
                    mergedMarks.push(new RangedMark(new Range(ranged.range.start + mergedOffset, ranged.range.end + mergedOffset), ranged.mark));
                }

                final image = node.image;
                if (image != null) {
                    if (mark.link != null) {
                        image.link = mark.link.clone();
                    }
                    // GPUI InteractiveText does not support inline images, so
                    // flush the accumulated text run and emit the image as its
                    // own sibling InlineNode.
                    flush();
                    paragraph.push(InlineNode.ofImage(image));
                }
            }
        }

        pushMerged(paragraph, mergedText.toString(), mergedMarks, mergedSourceSegments, mark);
        return text.toString();
    }

    static function sourceSegments(source:SourceText, rendered:String, span:Null<Span>, sourceOffset:Int,
            includePrecedingEscape:Bool):Array<SourceSegment> {
        if (span == null) {
            return [];
        }
        final localStart = saturatingSub(span.start, sourceOffset);
        final localEnd = saturatingSub(span.end, sourceOffset);
        final raw = bytesGet(source.bytes, localStart, localEnd);
        if (raw == null) {
            return [];
        }

        final renderedBytes = Bytes.ofString(rendered);
        final segments = alignedSourceSegments(raw, renderedBytes, span.start, true, true);

        // The text node of an escaped character starts after its backslash.
        // The backslash and the character map as a whole; the rest of the run
        // stays linear.
        if (includePrecedingEscape && localStart >= 1 && source.bytes.get(localStart - 1) == '\\'.code && segments.length > 0) {
            final first = segments[0];
            final firstCharLen = first.rendered.start < renderedBytes.length ? utf8CharLen(renderedBytes.get(first.rendered.start)) : 0;
            if (first.linear && first.rendered.len() > firstCharLen) {
                final rest = new SourceSegment(new Range(first.rendered.start + firstCharLen, first.rendered.end),
                    new Range(first.source.start + firstCharLen, first.source.end), true);
                first.rendered = new Range(first.rendered.start, rest.rendered.start);
                first.source = new Range(first.source.start, rest.source.start);
                segments.insert(1, rest);
            }
            final first = segments[0];
            first.source = new Range(first.source.start - 1, first.source.end);
            first.linear = false;
        }
        return segments;
    }

    static function alignedSourceSegments(raw:Bytes, rendered:Bytes, sourceOffset:Int, decodeEntities:Bool,
            decodeEscapes:Bool):Array<SourceSegment> {
        final segments:Array<SourceSegment> = [];
        final rawLen = raw.length;
        final renderedLen = rendered.length;
        var rawCursor = 0;
        var renderedStart = 0;
        var whitespaceEnd = 0;
        final sourcePositions = new SourceCharPositions();
        var entityCursor = -1;
        var entity:Null<DecodedEntity> = null;
        // Only the final LF may absorb source-only text before it. Find the
        // preceding line boundary once instead of recounting the suffix per LF.
        var finalLineStart = 0;
        if (rawLen > 0 && raw.get(rawLen - 1) == '\n'.code) {
            var i = rawLen - 2;
            while (i >= 0 && raw.get(i) != '\n'.code)
                i--;
            finalLineStart = i >= 0 ? i + 1 : 0;
        }

        while (renderedStart < renderedLen) {
            if (decodeEntities && entityCursor != rawCursor) {
                entity = decodedEntity(raw, rawCursor);
                entityCursor = rawCursor;
            }
            if (entity != null && bytesStartWith(rendered, renderedStart, entity.decoded, 0, entity.decoded.length)) {
                final renderedEnd = renderedStart + entity.decoded.length;
                pushSourceSegment(segments, new SourceSegment(new Range(renderedStart, renderedEnd),
                    new Range(sourceOffset + rawCursor, sourceOffset + rawCursor + entity.sourceLen),
                    // Even when the decoded characters take as many bytes as
                    // the entity, as `&acE;` does, they are not one for one.
                    false));
                renderedStart = renderedEnd;
                rawCursor += entity.sourceLen;
                continue;
            }

            final renderedChar = utf8Decode(rendered, renderedStart);
            final charLen = utf8CharLen(rendered.get(renderedStart));
            final renderedEnd = renderedStart + charLen;
            final remainderLen = rawLen - rawCursor;
            if (renderedChar == ' '.code && rawCursor >= whitespaceEnd) {
                // Reuse this boundary while consuming a run of literal spaces.
                // Otherwise a long horizontal-whitespace run also costs O(n^2).
                var p = rawCursor;
                while (p < rawLen) {
                    final byte = raw.get(p);
                    if (byte != ' '.code && byte != '\t'.code)
                        break;
                    p++;
                }
                whitespaceEnd = p;
            }
            var relativeStart:Int;
            var sourceLen:Int;
            if (renderedChar == ' '.code && whitespaceEnd < rawLen
                && (raw.get(whitespaceEnd) == '\n'.code || raw.get(whitespaceEnd) == '\r'.code)) {
                final newlineLen = (whitespaceEnd + 1 < rawLen && raw.get(whitespaceEnd) == '\r'.code
                    && raw.get(whitespaceEnd + 1) == '\n'.code) ? 2 : 1;
                relativeStart = whitespaceEnd - rawCursor;
                sourceLen = newlineLen;
            } else if (renderedChar == '\n'.code && remainderLen > 0 && raw.get(rawLen - 1) == '\n'.code && rawCursor >= finalLineStart) {
                relativeStart = 0;
                sourceLen = remainderLen;
            } else if (decodeEscapes && remainderLen > 0 && raw.get(rawCursor) == '\\'.code
                && bytesStartWith(raw, rawCursor + 1, rendered, renderedStart, charLen)) {
                relativeStart = 0;
                sourceLen = 1 + charLen;
            } else if (bytesStartWith(raw, rawCursor, rendered, renderedStart, charLen)) {
                relativeStart = 0;
                sourceLen = charLen;
            } else {
                final sourceStart = sourceCharOffset(raw, rawCursor, renderedChar, sourcePositions);
                if (sourceStart != -1) {
                    relativeStart = sourceStart - rawCursor;
                    sourceLen = charLen;
                } else {
                    // Decoded entities and other source-only syntax have no
                    // exact rendered-byte mapping. Leave a rendered gap for
                    // this character, but keep aligning later characters in
                    // the node.
                    renderedStart = renderedEnd;
                    continue;
                }
            }
            final sourceStart = rawCursor + relativeStart;
            final sourceEnd = sourceStart + sourceLen;
            pushSourceSegment(segments, new SourceSegment(new Range(renderedStart, renderedEnd),
                new Range(sourceOffset + sourceStart, sourceOffset + sourceEnd), sourceLen == charLen));
            rawCursor = sourceEnd;
            renderedStart = renderedEnd;
        }
        return segments;
    }

    /** The byte offset of `character` from `rawCursor`, `-1` for none (Rust `None`). */
    static function sourceCharOffset(raw:Bytes, rawCursor:Int, character:Int, positions:SourceCharPositions):Int {
        final index = positions.index;
        if (index != null) {
            final offsets = index.get(character);
            if (offsets == null)
                return -1;
            // partition_point(|&offset| offset < raw_cursor)
            var lo = 0;
            var hi = offsets.length;
            while (lo < hi) {
                final mid = (lo + hi) >> 1;
                if (offsets[mid] < rawCursor)
                    lo = mid + 1;
                else
                    hi = mid;
            }
            return lo < offsets.length ? offsets[lo] : -1;
        }
        final encoded = Bytes.ofString(gpui.util.Utf8.fromCodePoint(character));
        final rawLen = raw.length;
        var i = rawCursor;
        while (i + encoded.length <= rawLen) {
            if (bytesStartWith(raw, i, encoded, 0, encoded.length))
                return i;
            i++;
        }

        // Successful searches advance rawCursor, so their scans do not
        // overlap. A missing character does not advance it. Index the
        // remaining source only after the first miss so later gaps cannot
        // repeatedly scan that suffix.
        final indexed = new Map<Int, Array<Int>>();
        var offset = rawCursor;
        while (offset < rawLen) {
            final c = utf8Decode(raw, offset);
            var list = indexed.get(c);
            if (list == null) {
                list = [];
                indexed.set(c, list);
            }
            list.push(offset);
            offset += utf8CharLen(raw.get(offset));
        }
        positions.index = indexed;
        return -1;
    }

    /**
     * Pushes `segment`, merging it into the previous one when both are linear
     * and adjacent, so that a merged run still maps byte for byte. Any other
     * segment is kept whole on its own.
     */
    static function pushSourceSegment(segments:Array<SourceSegment>, segment:SourceSegment):Void {
        final previous = segments.length > 0 ? segments[segments.length - 1] : null;
        if (previous != null && previous.linear && segment.linear && previous.rendered.end == segment.rendered.start
            && previous.source.end == segment.source.start) {
            previous.rendered = new Range(previous.rendered.start, segment.rendered.end);
            previous.source = new Range(previous.source.start, segment.source.end);
        } else {
            segments.push(segment);
        }
    }

    /** Rust `decoded_entity(&source[pos..])`. */
    static function decodedEntity(source:Bytes, pos:Int):Null<DecodedEntity> {
        final len = source.length;
        if (pos >= len || source.get(pos) != '&'.code)
            return null;
        // candidate = source[pos + 1..]
        var candidateEnd = -1;
        var i = pos + 1;
        while (i < len) {
            final byte = source.get(i);
            if (byte == ';'.code || !(isAsciiAlphanumeric(byte) || byte == '#'.code)) {
                candidateEnd = i - (pos + 1);
                break;
            }
            i++;
        }
        if (candidateEnd == -1)
            return null;
        if (source.get(pos + 1 + candidateEnd) != ';'.code)
            return null;
        final semicolon = candidateEnd + 1;
        // name = source[1..=semicolon], ASCII only
        final name = source.getString(pos + 1, semicolon);
        final number = name.substr(0, name.length - 1);
        var decoded:String;
        if (StringTools.startsWith(name, '#x') || StringTools.startsWith(name, '#X')) {
            final value = parseU32(number.substr(2), 16);
            if (value == -1 || !isValidChar(value))
                return null;
            decoded = gpui.util.Utf8.fromCodePoint(value);
        } else if (StringTools.startsWith(name, '#')) {
            final value = parseU32(number.substr(1), 10);
            if (value == -1 || !isValidChar(value))
                return null;
            decoded = gpui.util.Utf8.fromCodePoint(value);
        } else {
            final entity = html5ever.markup5ever.data.Data.namedEntity(name);
            if (entity == null)
                return null;
            final first = entity[0];
            final second = entity[1];
            if (!isValidChar(first))
                return null;
            decoded = gpui.util.Utf8.fromCodePoint(first);
            if (second != 0) {
                if (!isValidChar(second))
                    return null;
                decoded += gpui.util.Utf8.fromCodePoint(second);
            }
        }
        return new DecodedEntity(Bytes.ofString(decoded), semicolon + 1);
    }

    static function codeSourceSegments(source:SourceText, code:String, span:Null<Span>, sourceOffset:Int):Array<SourceSegment> {
        if (span == null) {
            return [];
        }
        final raw = bytesGet(source.bytes, saturatingSub(span.start, sourceOffset), saturatingSub(span.end, sourceOffset));
        if (raw == null) {
            return [];
        }
        final rawLen = raw.length;
        final trimmed = TextUtils.trimStart(raw.toString());
        var fence = -1;
        var fenceLen = 0;
        if (trimmed.length > 0) {
            final character = StringTools.fastCodeAt(trimmed, 0);
            if (character == '`'.code || character == '~'.code) {
                var count = 0;
                while (count < trimmed.length && StringTools.fastCodeAt(trimmed, count) == character)
                    count++;
                if (count >= 3) {
                    fence = character;
                    fenceLen = count;
                }
            }
        }
        var bodyStart = 0;
        var bodyEnd = rawLen;
        if (fence != -1) {
            var firstNewline = -1;
            for (i in 0...rawLen) {
                if (raw.get(i) == '\n'.code) {
                    firstNewline = i;
                    break;
                }
            }
            final start = firstNewline == -1 ? rawLen : firstNewline + 1;
            var lastNewline = rawLen - 1;
            while (lastNewline >= 0 && raw.get(lastNewline) != '\n'.code)
                lastNewline--;
            final lastLine = lastNewline < 0 ? start : lastNewline + 1;
            final closing = TextUtils.trim(raw.getString(lastLine, rawLen - lastLine));
            var isClosing = closing.length >= fenceLen;
            if (isClosing) {
                for (i in 0...closing.length) {
                    if (StringTools.fastCodeAt(closing, i) != fence) {
                        isClosing = false;
                        break;
                    }
                }
            }
            bodyStart = start;
            bodyEnd = isClosing ? lastLine : rawLen;
        }

        return alignedSourceSegments(raw.sub(bodyStart, bodyEnd - bodyStart), Bytes.ofString(code), span.start + bodyStart, false, false);
    }

    static function mappedInline(source:SourceText, text:String, node:Node, cx:NodeContext):InlineNode {
        final position = node.position();
        final span = position != null ? new Span(cx.offset + position.start.offset, cx.offset + position.end.offset) : null;
        final segments = sourceSegments(source, text, span, cx.offset, node.match(Text(_)));
        return new InlineNode(text).sourceSegments(segments);
    }

    static function appendInlineHtmlBlocks(paragraph:Paragraph, blocks:Array<BlockNode>):Null<String> {
        final text = new StringBuf();

        for (block in blocks) {
            switch block {
                case Root(children, _):
                    final inner = appendInlineHtmlBlocks(paragraph, children);
                    if (inner == null)
                        return null;
                    text.add(inner);
                case Paragraph(htmlParagraph):
                    text.add(htmlParagraph.text());
                    for (child in htmlParagraph.children_) {
                        paragraph.push(child);
                    }
                case Break(_, _):
                    text.add('\n');
                    paragraph.push(new InlineNode('\n'));
                case _:
                    return null;
            }
        }

        return text.toString();
    }

    static function parseParagraph(source:SourceText, paragraph:Paragraph, node:Node, cx:NodeContext):String {
        final position = node.position();
        final span = position != null ? new Span(cx.offset + position.start.offset, cx.offset + position.end.offset) : null;
        if (span != null) {
            paragraph.setSpan(span);
        }

        final parseCx = new MarkdownParseContext(source.text, cx.offset);
        var custom = cx.markdownExtensions.parseInline(node, parseCx);
        if (custom != null) {
            custom.setSpan(span);
            final nodeSource = parseCx.nodeSource(node);
            custom = custom.withInlineSource(nodeSource != null ? nodeSource : '');
            final text = custom.asText();
            paragraph.push(InlineNode.ofCustom(custom));
            return text;
        }

        var text = '';

        switch node {
            case Paragraph(val):
                text += parseInlineChildren(source, paragraph, val.children, cx);
            case Text(val):
                // A CommonMark *soft* break lives inside this value as a plain
                // line ending. The renderer treats a newline in a text run as a
                // line break, so a paragraph hard-wrapped in the source would
                // render one visual line per source line instead of reflowing
                // to the available width. Collapse soft breaks to spaces;
                // *hard* breaks never reach here, they arrive as their own
                // Node.Break.
                //
                // mdast hands the line ending over exactly as the source wrote
                // it, so a CRLF document still carries its carriage return
                // here. Take the CR with the newline: dropping only the newline
                // would strand the CR in the middle of the reflowed line.
                text = StringTools.replace(StringTools.replace(StringTools.replace(val.value, '\r\n', ' '), '\n', ' '), '\r', ' ');
                paragraph.push(mappedInline(source, text, node, cx));
            case Emphasis(val):
                text = mergeChildrenWithMark(source, paragraph, val.children, new TextMark().withItalic(), cx);
            case Strong(val):
                text = mergeChildrenWithMark(source, paragraph, val.children, new TextMark().withBold(), cx);
            case Delete(val):
                text = mergeChildrenWithMark(source, paragraph, val.children, new TextMark().withStrikethrough(), cx);
            case InlineCode(val):
                text = val.value;
                paragraph.push(new InlineNode(text).sourceSegments(codeSourceSegments(source, text, span, cx.offset))
                    .marks([new RangedMark(new Range(0, TextUtils.len(text)), new TextMark().withCode())]));
            case Link(val):
                final linkMark = new LinkMark(val.url, null, val.title);
                text = mergeChildrenWithMark(source, paragraph, val.children, new TextMark().withLink(linkMark), cx);
            case Image(raw):
                final image = new ImageNode(raw.url);
                image.title = raw.title;
                image.alt = raw.alt;
                image.span = raw.position != null ? new Span(cx.offset + raw.position.start.offset, cx.offset + raw.position.end.offset) : null;
                paragraph.pushImage(image);
            case ImageReference(raw):
                final definition = cx.linkRefs.get(raw.identifier);
                if (definition != null) {
                    final image = new ImageNode(definition.url);
                    image.title = definition.title;
                    image.alt = raw.alt;
                    image.span = span;
                    paragraph.pushImage(image);
                }
            case Break(_):
                // Hard line break (trailing two spaces / backslash). Mirror the
                // inline-HTML <br> path: emit a newline inline node so the
                // break renders instead of silently concatenating adjacent
                // lines.
                text += '\n';
                paragraph.push(mappedInline(source, '\n', node, cx));
            case InlineMath(raw):
                // Math parsing is on by default, so ordinary prose that merely
                // contains dollar signs ("spent $5 and $10") arrives here as a
                // math node whenever no inline plugin claimed it. Emitting
                // `raw.value` would drop the delimiters and restyle the run as
                // code, silently rewriting what the author typed. Fall back to
                // the original source so unclaimed math stays literal.
                final nodeSource = parseCx.nodeSource(node);
                text = nodeSource != null ? nodeSource : raw.value;
                paragraph.push(mappedInline(source, text, node, cx));
            case MdxTextExpression(raw):
                text = raw.value;
                paragraph.push(new InlineNode(text).sourceSegments(codeSourceSegments(source, text, span, cx.offset))
                    .marks([new RangedMark(new Range(0, TextUtils.len(text)), new TextMark())]));
            case Html(val):
                var el:Null<ParsedDocument> = null;
                try {
                    el = HtmlFormat.parse(val.value, cx);
                } catch (err:String) {
                    // Rust logs `failed parsing html` in debug builds.
                    text += val.value;
                }
                if (el != null) {
                    final inlineText = appendInlineHtmlBlocks(paragraph, el.blocks.copy());
                    if (inlineText != null) {
                        text = inlineText;
                    }
                    // Otherwise Rust logs `unsupported inline html tag` in
                    // debug builds.
                }
            case FootnoteReference(foot):
                final prefix = '[${foot.identifier}]';
                paragraph.push(mappedInline(source, prefix, node, cx)
                    .marks([new RangedMark(new Range(0, TextUtils.len(prefix)), new TextMark().withItalic())]));
            case LinkReference(link):
                final linkMark = new LinkMark('', link.identifier, link.label);
                text = mergeChildrenWithMark(source, paragraph, link.children, new TextMark().withLink(linkMark), cx);
            case _:
                // Rust logs `unsupported inline node` in debug builds.
        }

        return text;
    }

    /**
     * Definitions may follow their references or live inside a container.
     * The parser normalizes identifiers; CommonMark uses the first definition.
     */
    static function collectDefinitions(node:Node, definitions:Map<String, LinkMark>):Void {
        switch node {
            case Definition(def):
                if (!definitions.exists(def.identifier)) {
                    definitions.set(def.identifier, new LinkMark(def.url, def.identifier, def.title));
                }
            case _:
        }
        final children = node.children();
        if (children != null) {
            for (child in children) {
                collectDefinitions(child, definitions);
            }
        }
    }

    static function astToDocument(source:SourceText, root:Node, cx:NodeContext):ParsedDocument {
        final definitions = new Map<String, LinkMark>();
        collectDefinitions(root, definitions);
        // BTreeMap order.
        final identifiers = [for (identifier in definitions.keys()) identifier];
        identifiers.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
        for (identifier in identifiers) {
            cx.addRef(identifier, definitions.get(identifier));
        }

        final rootNode = switch root {
            case Root(r): r;
            case _: throw 'expected root node';
        }

        final blocks = [for (c in rootNode.children) astToNode(source, c, cx)];
        return new ParsedDocument(source.text, blocks);
    }

    static function newSpan(pos:Null<Position>, cx:NodeContext):Null<Span> {
        if (pos == null)
            return null;
        return new Span(cx.offset + pos.start.offset, cx.offset + pos.end.offset);
    }

    static function astToNode(source:SourceText, value:Node, cx:NodeContext):BlockNode {
        final span = newSpan(value.position(), cx);
        final parseCx = new MarkdownParseContext(source.text, cx.offset);
        final custom = cx.markdownExtensions.parseBlock(value, parseCx);
        if (custom != null) {
            custom.setSpan(span);
            return BlockNode.Custom(custom, new BlockState());
        }

        return switch value {
            case Root(_):
                throw 'node::Root should be handled separately';
            case Paragraph(val):
                final paragraph = new Paragraph();
                parseInlineChildren(source, paragraph, val.children, cx);
                paragraph.span = newSpan(val.position, cx);
                BlockNode.Paragraph(paragraph);
            case Blockquote(val):
                final children = [for (c in val.children) astToNode(source, c, cx)];
                BlockNode.Blockquote(children, newSpan(val.position, cx));
            case List(list):
                final children = [for (c in list.children) astToNode(source, c, cx)];
                BlockNode.List(children, list.ordered, list.start, newSpan(list.position, cx));
            case ListItem(val):
                final children = [for (c in val.children) astToNode(source, c, cx)];
                BlockNode.ListItem(children, val.spread, val.checked, newSpan(val.position, cx));
            case Break(val):
                BlockNode.Break(false, newSpan(val.position, cx));
            case Code(raw):
                final span = newSpan(raw.position, cx);
                final segments = codeSourceSegments(source, raw.value, span, cx.offset);
                BlockNode.CodeBlock(new CodeBlock(raw.value, raw.lang, span).withMeta(raw.meta).sourceSegments(segments));
            case Heading(val):
                final paragraph = new Paragraph();
                parseInlineChildren(source, paragraph, val.children, cx);
                BlockNode.Heading(val.depth, paragraph, newSpan(val.position, cx));
            case Math(val):
                final span = newSpan(val.position, cx);
                final segments = codeSourceSegments(source, val.value, span, cx.offset);
                BlockNode.CodeBlock(new CodeBlock(val.value, null, span).sourceSegments(segments));
            case Html(val):
                var el:Null<ParsedDocument> = null;
                try {
                    el = HtmlFormat.parse(val.value, cx);
                } catch (err:String) {
                    // Rust logs `error parsing html` in debug builds.
                }
                if (el != null) {
                    BlockNode.Root(el.blocks.copy(), newSpan(val.position, cx));
                } else {
                    BlockNode.Paragraph(gpui.base.text.Paragraph.ofText(val.value));
                }
            case MdxFlowExpression(val):
                final span = newSpan(val.position, cx);
                final segments = codeSourceSegments(source, val.value, span, cx.offset);
                BlockNode.CodeBlock(new CodeBlock(val.value, 'mdx', span).sourceSegments(segments));
            case Yaml(val):
                BlockNode.CodeBlock(new CodeBlock(val.value, 'yml', newSpan(val.position, cx)));
            case Toml(val):
                BlockNode.CodeBlock(new CodeBlock(val.value, 'toml', newSpan(val.position, cx)));
            case MdxJsxTextElement(val):
                final paragraph = new Paragraph();
                parseInlineChildren(source, paragraph, val.children, cx);
                paragraph.span = newSpan(val.position, cx);
                BlockNode.Paragraph(paragraph);
            case MdxJsxFlowElement(val):
                final paragraph = new Paragraph();
                parseInlineChildren(source, paragraph, val.children, cx);
                paragraph.span = newSpan(val.position, cx);
                BlockNode.Paragraph(paragraph);
            case ThematicBreak(val):
                BlockNode.HorizontalRule(newSpan(val.position, cx));
            case Table(val):
                final table = new Table();
                table.columnAligns_ = [for (align in val.align) ColumnumnAlign.fromAlignKind(align)];
                for (c in val.children) {
                    switch c {
                        case TableRow(row):
                            parseTableRow(source, table, row, cx);
                        case _:
                    }
                }
                table.span = newSpan(val.position, cx);
                BlockNode.Table(table);
            case FootnoteDefinition(def):
                final paragraph = new Paragraph();
                final prefix = '[${def.identifier}]: ';
                paragraph.push(new InlineNode(prefix).marks([new RangedMark(new Range(0, TextUtils.len(prefix)), new TextMark().withItalic())]));

                parseInlineChildren(source, paragraph, def.children, cx);
                paragraph.span = newSpan(def.position, cx);
                BlockNode.Paragraph(paragraph);
            case Definition(def):
                BlockNode.Definition(def.identifier, def.url, def.title, newSpan(def.position, cx));
            case _:
                // Rust logs `unsupported node` in debug builds.
                BlockNode.Unknown;
        }
    }

    // Byte helpers (Rust `str` / `[u8]` operations on UTF-8 bytes)

    static inline function saturatingSub(a:Int, b:Int):Int {
        return a > b ? a - b : 0;
    }

    static inline function isAsciiAlphanumeric(c:Int):Bool {
        return (c >= '0'.code && c <= '9'.code) || (c >= 'a'.code && c <= 'z'.code) || (c >= 'A'.code && c <= 'Z'.code);
    }

    static function asciiLowercase(s:String):String {
        final buf = new StringBuf();
        for (i in 0...s.length) {
            final c = StringTools.fastCodeAt(s, i);
            buf.addChar(c >= 'A'.code && c <= 'Z'.code ? c + 32 : c);
        }
        return buf.toString();
    }

    /** Rust `char::from_u32(value).is_some()`. */
    static inline function isValidChar(value:Int):Bool {
        return value >= 0 && value <= 0x10FFFF && !(value >= 0xD800 && value <= 0xDFFF);
    }

    /** Rust `u32::from_str_radix` / `str::parse::<u32>()`: `-1` on error. */
    static function parseU32(digits:String, radix:Int):Int {
        if (digits == '')
            return -1;
        var value = 0.0;
        for (i in 0...digits.length) {
            final c = StringTools.fastCodeAt(digits, i);
            final digit = if (c >= '0'.code && c <= '9'.code) c - '0'.code; else if (radix == 16 && c >= 'a'.code && c <= 'f'.code) c
                - 'a'.code + 10; else if (radix == 16 && c >= 'A'.code && c <= 'F'.code) c - 'A'.code + 10; else -1;
            if (digit == -1)
                return -1;
            value = value * radix + digit;
            if (value > 4294967295.0)
                return -1;
        }
        // Values past the Unicode range are rejected by `isValidChar` anyway.
        return value > 0x10FFFF ? 0x110000 : Std.int(value);
    }

    /** Rust `s.get(start..end)` on bytes: `null` out of bounds or off a character boundary. */
    static function bytesGet(bytes:Bytes, start:Int, end:Int):Null<Bytes> {
        if (start > end || end > bytes.length)
            return null;
        if (!isBoundary(bytes, start) || !isBoundary(bytes, end))
            return null;
        return bytes.sub(start, end - start);
    }

    static inline function isBoundary(bytes:Bytes, pos:Int):Bool {
        return pos == 0 || pos == bytes.length || (bytes.get(pos) & 0xC0) != 0x80;
    }

    static inline function utf8CharLen(lead:Int):Int {
        return lead < 0x80 ? 1 : (lead < 0xE0 ? 2 : (lead < 0xF0 ? 3 : 4));
    }

    static function utf8Decode(bytes:Bytes, pos:Int):Int {
        final b0 = bytes.get(pos);
        if (b0 < 0x80)
            return b0;
        if (b0 < 0xE0)
            return ((b0 & 0x1F) << 6) | (bytes.get(pos + 1) & 0x3F);
        if (b0 < 0xF0)
            return ((b0 & 0x0F) << 12) | ((bytes.get(pos + 1) & 0x3F) << 6) | (bytes.get(pos + 2) & 0x3F);
        return ((b0 & 0x07) << 18) | ((bytes.get(pos + 1) & 0x3F) << 12) | ((bytes.get(pos + 2) & 0x3F) << 6) | (bytes.get(pos + 3) & 0x3F);
    }

    /** Whether `a[aPos..]` starts with `b[bPos..bPos + len]`. */
    static function bytesStartWith(a:Bytes, aPos:Int, b:Bytes, bPos:Int, len:Int):Bool {
        if (aPos + len > a.length || bPos + len > b.length)
            return false;
        for (i in 0...len) {
            if (a.get(aPos + i) != b.get(bPos + i))
                return false;
        }
        return true;
    }

}
