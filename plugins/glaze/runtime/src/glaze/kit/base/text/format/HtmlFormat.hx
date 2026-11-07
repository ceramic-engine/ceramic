// Ported from gpui-kit 0.8.1: crates/base/src/text/format/html.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text.format;

import gpui.DefiniteLength;
import gpui.Hsla;
import gpui.Range;
import gpui.Rgba;
import gpui.base.text.BlockNode;
import gpui.base.text.ImageNode;
import gpui.base.text.InlineNode;
import gpui.base.text.LinkMark;
import gpui.base.text.NodeContext;
import gpui.base.text.Paragraph;
import gpui.base.text.ParsedDocument;
import gpui.base.text.RangedMark;
import gpui.base.text.Table;
import gpui.base.text.Table.TableCell;
import gpui.base.text.Table.TableRow;
import gpui.base.text.TextMark;
import gpui.base.text.TextUtils;
import gpui.base.text.format.html5minify.Minifier;
import gpui.util.MathUtil;
import gpui.util.Utf8;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import html5ever.Html5ever;
import html5ever.driver.ParseOpts;
import html5ever.markup5ever.Attribute;
import html5ever.markup5ever_rcdom.Node;
import html5ever.markup5ever_rcdom.NodeData;
import html5ever.markup5ever_rcdom.RcDom;
import html5ever.markup5ever_rcdom.RefCell;

import gpui.Prelude.px;
import gpui.Prelude.relative;
import gpui.Prelude.rgb;

/**
 * A paragraph under construction. A literal line feed is content; only a
 * trailing HTML break is removed when the complete text block is taken.
 */
private class HtmlParagraph {

    public var content:Paragraph = new Paragraph();
    public var endsWithBreak:Bool = false;

    public function new() {}

    public function push(node:InlineNode):Void {
        content.push(node);
        endsWithBreak = false;
    }

    public function pushStr(text:String):Void {
        if (text != '') {
            content.pushStr(text);
            endsWithBreak = false;
        }
    }

    public function pushImage(image:ImageNode):Void {
        push(InlineNode.ofImage(image));
    }

    public function pushBreak():Void {
        content.push(new InlineNode('\n'));
        endsWithBreak = true;
    }

    public function take():Paragraph {
        if (endsWithBreak) {
            HtmlFormat.trimTrailingBreak(content);
        }
        endsWithBreak = false;
        return content.take();
    }

}

/**
 * HTML to `ParsedDocument` (Rust `text/format/html.rs`). The free functions
 * of the Rust module are the statics of this class.
 */
class HtmlFormat {

    static final BLOCK_ELEMENTS:Array<String> = [
        'html', 'body', 'head', 'address', 'article', 'aside', 'blockquote', 'details', 'summary', 'dialog', 'div', 'dl', 'fieldset', 'figcaption',
        'figure', 'footer', 'form', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'header', 'hr', 'main', 'nav', 'ol', 'p', 'pre', 'section', 'table', 'ul',
        'style', 'script'
    ];

    /**
     * Parse HTML into AST Node. Throws the error string when the HTML cannot
     * be read (Rust `Result<ParsedDocument, SharedString>`).
     */
    public static function parse(source:String, cx:NodeContext):ParsedDocument {
        final opts = new ParseOpts();

        final bytes = cleanupHtml(source);
        final cursor = new BytesInput(bytes);
        // Ref
        // https://github.com/servo/html5ever/blob/main/rcdom/examples/print-rcdom.rs
        final dom = try {
            Html5ever.parseDocument(new RcDom(), opts).fromUtf8().readFrom(cursor);
        }
        catch (e:haxe.Exception) {
            throw Std.string(e);
        }

        final paragraph = new HtmlParagraph();
        // NOTE: The outer paragraph is not used.
        var node:Null<BlockNode> = parseNode(dom.document, paragraph, cx);
        if (node == null)
            node = BlockNode.Unknown;
        node = node.compact();

        return new ParsedDocument(source, [node]);
    }

    static function cleanupHtml(source:String):Bytes {
        final w = new BytesOutput();
        final r = new BytesInput(Bytes.ofString(source));
        final minify = new Minifier(w);
        minify.omitDoctype(true);
        try {
            minify.minify(r);
            return w.getBytes();
        }
        catch (e:haxe.Exception) {
            return Bytes.ofString(source);
        }
    }

    static function attrValue(attrs:RefCell<Array<Attribute>>, name:String):Null<String> {
        for (attr in attrs.borrow()) {
            if (attr.name.local == name)
                return attr.value;
        }
        return null;
    }

    /** Default `<mark>` background when the tag has no usable color. */
    public static function defaultMarkColor():Hsla {
        return rgb(0xfef08a).toHsla();
    }

    /**
     * Get the highlight background color for a `<mark>` element.
     *
     * Reads the `color` attribute first, then the `background-color`
     * declaration from the `style` attribute. Base accepts CSS hex plus
     * common named colors.
     */
    static function markColor(attrs:RefCell<Array<Attribute>>):Null<Hsla> {
        return markColorFromValues(attrValue(attrs, 'color'), attrValue(attrs, 'style'));
    }

    /**
     * Resolve a `<mark>` color from raw `color` / `style` attribute values.
     *
     * Same rules as the block HTML path: `color` wins, then
     * `style="background-color: ..."`.
     */
    public static function markColorFromValues(color:Null<String>, style:Null<String>):Null<Hsla> {
        if (color != null) {
            final parsed = parseMarkColor(TextUtils.trim(color));
            if (parsed != null)
                return parsed;
        }

        if (style == null)
            return null;
        final value = styleAttrs(style).get('background-color');
        return value != null ? parseMarkColor(value) : null;
    }

    static function parseMarkColor(value:String):Null<Hsla> {
        if (StringTools.startsWith(value, '#')) {
            final rgba = Rgba.tryParse(value);
            return rgba != null ? rgba.toHsla() : null;
        }
        return switch asciiLowercase(value) {
            case 'black': rgb(0x000000).toHsla();
            case 'white': rgb(0xffffff).toHsla();
            case 'blue': rgb(0x3b82f6).toHsla();
            case 'yellow': rgb(0xfacc15).toHsla();
            case _: null;
        }
    }

    /**
     * Get style properties to a map.
     * TODO: Use cssparser to parse style attribute.
     */
    static function styleAttrs(cssText:String):Map<String, String> {
        final styles = new Map<String, String>();
        for (decl in cssText.split(';')) {
            // `splitn(2, ':')`
            final colon = decl.indexOf(':');
            if (colon >= 0) {
                final key = decl.substring(0, colon);
                final value = decl.substring(colon + 1);
                styles.set(TextUtils.trim(key).toLowerCase(), TextUtils.trim(value));
            }
        }

        return styles;
    }

    /**
     * Parse length value from style attribute.
     *
     * When is percentage, it will be converted to relative length.
     * Else, it will be converted to pixels.
     */
    static function valueToLength(value:String):Null<DefiniteLength> {
        if (StringTools.endsWith(value, '%')) {
            final v = MathUtil.parseFloat(TextUtils.trimEndMatches(value, '%'));
            return v != null ? relative(v / 100.) : null;
        }
        else {
            final v = MathUtil.parseFloat(TextUtils.trimEndMatches(value, 'px'));
            return v != null ? px(v).toDefiniteLength() : null;
        }
    }

    /** Get width, height from attributes or parse them from style attribute. */
    static function attrWidthHeight(attrs:RefCell<Array<Attribute>>):{width:Null<DefiniteLength>, height:Null<DefiniteLength>} {
        var width:Null<DefiniteLength> = null;
        var height:Null<DefiniteLength> = null;

        final widthValue = attrValue(attrs, 'width');
        if (widthValue != null) {
            width = valueToLength(widthValue);
        }

        final heightValue = attrValue(attrs, 'height');
        if (heightValue != null) {
            height = valueToLength(heightValue);
        }

        if (width == null || height == null) {
            final cssText = attrValue(attrs, 'style');
            final styles = cssText != null ? styleAttrs(cssText) : new Map<String, String>();
            if (width == null) {
                final v = styles.get('width');
                width = v != null ? valueToLength(v) : null;
            }
            if (height == null) {
                final v = styles.get('height');
                height = v != null ? valueToLength(v) : null;
            }
        }

        return {width: width, height: height};
    }

    static function parseTableRow(table:Table, node:Node):Void {
        final row = new TableRow();
        var count = 0;
        for (child in node.children.borrow()) {
            switch child.data {
                case Element(name, attrs, _, _) if (name.local == 'td' || name.local == 'th'):
                    if (child.children.borrow().length == 0) {
                        continue;
                    }

                    count += 1;
                    parseTableCell(row, child, attrs);
                case _:
            }
        }

        if (count > 0) {
            table.children.push(row);
        }
    }

    static function parseTableCell(row:TableRow, node:Node, attrs:RefCell<Array<Attribute>>):Void {
        final paragraph = new HtmlParagraph();
        for (child in node.children.borrow()) {
            parseParagraph(paragraph, child);
        }
        final width = attrWidthHeight(attrs).width;
        final tableCell = new TableCell(paragraph.take(), width);
        row.children.push(tableCell);
    }

    /**
     * Trim text but leave at least one space.
     *
     * - Before: " \r\n Hello world \t "
     * - After: " Hello world "
     *
     * Unused by the parser (dead code in Rust too).
     */
    static function trimText(text:String):String {
        final out = new StringBuf();
        var outEndsWithSpace = false;

        var i = 0;
        var pos = 0;
        while (pos < text.length) {
            final c = ttf.Utf8.codePointAt(text, pos);
            pos += c >= 0x10000 ? 2 : 1;
            final skip = Utf8.isWhitespace(c) && i > 0 && outEndsWithSpace;
            if (!skip) {
                out.add(Utf8.fromCodePoint(c));
                outEndsWithSpace = c == ' '.code;
            }
            i++;
        }

        return out.toString();
    }

    /** Rust `push_merged`, local to `parse_paragraph`. */
    static function pushMerged(paragraph:HtmlParagraph, text:String, marks:Array<RangedMark>, newMark:Null<TextMark>):Void {
        if (text == '') {
            return;
        }
        final node = new InlineNode(text).marks(marks);
        if (newMark != null) {
            final len = TextUtils.len(node.text_);
            final last = node.marks_.length > 0 ? node.marks_[node.marks_.length - 1] : null;
            if (last != null && last.range.start == 0 && last.range.end == len) {
                last.mark.merge(newMark);
            }
            else {
                node.marks_.push(new RangedMark(new Range(0, len), newMark));
            }
        }
        paragraph.push(node);
    }

    /** Rust `merge_children_with_mark`, local to `parse_paragraph`. */
    static function mergeChildrenWithMark(node:Node, paragraph:HtmlParagraph, newMark:Null<TextMark>):Void {
        var mergedText = '';
        var mergedLen = 0;
        var mergedMarks:Array<RangedMark> = [];
        var endsWithBreak:Null<Bool> = null;

        for (child in node.children.borrow()) {
            final childParagraph = new HtmlParagraph();
            parseParagraph(childParagraph, child);

            if (!childParagraph.content.isEmpty()) {
                endsWithBreak = childParagraph.endsWithBreak;
            }
            for (node in childParagraph.content.children_) {
                final offset = mergedLen;
                mergedText += node.text_;
                mergedLen += TextUtils.len(node.text_);
                for (ranged in node.marks_) {
                    mergedMarks.push(new RangedMark(new Range(ranged.range.start + offset, ranged.range.end + offset), ranged.mark));
                }

                final image = node.image;
                if (image != null) {
                    if (newMark != null && newMark.link != null) {
                        image.link = newMark.link.clone();
                    }

                    final text = mergedText;
                    final marks = mergedMarks;
                    mergedText = '';
                    mergedLen = 0;
                    mergedMarks = [];
                    pushMerged(paragraph, text, marks, newMark != null ? newMark.clone() : null);

                    paragraph.push(InlineNode.ofImage(image));
                }
            }
        }

        pushMerged(paragraph, mergedText, mergedMarks, newMark != null ? newMark.clone() : null);
        if (endsWithBreak != null) {
            paragraph.endsWithBreak = endsWithBreak;
        }
    }

    static function parseParagraph(paragraph:HtmlParagraph, node:Node):Void {
        switch node.data {
            case Text(contents):
                final part = contents.borrow();
                paragraph.pushStr(part);
            case Element(name, attrs, _, _):
                switch name.local {
                    case 'em' | 'i':
                        mergeChildrenWithMark(node, paragraph, new TextMark().withItalic());
                    case 'strong' | 'b':
                        mergeChildrenWithMark(node, paragraph, new TextMark().withBold());
                    case 'del' | 's':
                        mergeChildrenWithMark(node, paragraph, new TextMark().withStrikethrough());
                    case 'u':
                        mergeChildrenWithMark(node, paragraph, new TextMark().withUnderline());
                    case 'code':
                        mergeChildrenWithMark(node, paragraph, new TextMark().withCode());
                    case 'mark':
                        var color = markColor(attrs);
                        if (color == null)
                            color = defaultMarkColor();
                        mergeChildrenWithMark(node, paragraph, new TextMark().withHighlight(color));
                    case 'a':
                        final href = attrValue(attrs, 'href');
                        final linkMark = new LinkMark(href != null ? href : '', null, attrValue(attrs, 'title'));

                        mergeChildrenWithMark(node, paragraph, new TextMark().withLink(linkMark));
                    case 'br':
                        paragraph.pushBreak();
                    case 'img':
                        final src = attrValue(attrs, 'src');
                        if (src == null) {
                            #if debug
                            ceramic.Shortcuts.log.warning('Image node missing src attribute');
                            #end
                            return;
                        }

                        final alt = attrValue(attrs, 'alt');
                        final title = attrValue(attrs, 'title');
                        final size = attrWidthHeight(attrs);

                        final image = new ImageNode(src);
                        image.alt = alt;
                        image.width = size.width;
                        image.height = size.height;
                        image.title = title;
                        paragraph.pushImage(image);
                    case _:
                        mergeChildrenWithMark(node, paragraph, null);
                }
            case _:
                mergeChildrenWithMark(node, paragraph, null);
        }
    }

    static function parseNode(node:Node, paragraph:HtmlParagraph, cx:NodeContext):Null<BlockNode> {
        switch node.data {
            case Text(contents):
                final text = contents.borrow();
                if (text.length > 0) {
                    paragraph.pushStr(text);
                }

                return null;
            case Element(name, attrs, _, _):
                switch name.local {
                    // A line break inside the paragraph being built, as a markdown
                    // hard break becomes. As a block of its own it landed apart from
                    // the text on both sides, which then stayed on one line.
                    case 'br':
                        paragraph.pushBreak();
                        return null;
                    case 'h1' | 'h2' | 'h3' | 'h4' | 'h5' | 'h6':
                        final children:Array<BlockNode> = [];
                        consumeParagraph(children, paragraph);

                        final last = name.local.length > 0 ? name.local.charCodeAt(name.local.length - 1) : '6'.code;
                        final level = last >= '0'.code && last <= '9'.code ? last - '0'.code : 6;

                        final paragraph = new HtmlParagraph();
                        for (child in node.children.borrow()) {
                            parseParagraph(paragraph, child);
                        }

                        final heading = BlockNode.Heading(level, paragraph.take(), null);
                        if (children.length > 0) {
                            children.push(heading);

                            return BlockNode.Root(children, null);
                        }
                        else {
                            return heading;
                        }
                    case 'img':
                        final children:Array<BlockNode> = [];
                        consumeParagraph(children, paragraph);

                        final src = attrValue(attrs, 'src');
                        if (src == null) {
                            #if debug
                            ceramic.Shortcuts.log.warning('image node missing src attribute');
                            #end
                            return null;
                        }

                        final alt = attrValue(attrs, 'alt');
                        final title = attrValue(attrs, 'title');
                        final size = attrWidthHeight(attrs);

                        final paragraph = new HtmlParagraph();
                        final image = new ImageNode(src);
                        image.title = title;
                        image.alt = alt;
                        image.width = size.width;
                        image.height = size.height;
                        paragraph.pushImage(image);

                        if (children.length > 0) {
                            children.push(BlockNode.Paragraph(paragraph.take()));
                            return BlockNode.Root(children, null);
                        }
                        else {
                            return BlockNode.Paragraph(paragraph.take());
                        }
                    case 'ul' | 'ol':
                        final ordered = name.local == 'ol';
                        final children = consumeChildrenNodes(node, paragraph, cx);
                        return BlockNode.List(children, ordered, null, null);
                    case 'li':
                        final children:Array<BlockNode> = [];
                        consumeParagraph(children, paragraph);

                        var endsWithBreak = false;
                        for (child in node.children.borrow()) {
                            final childParagraph = new HtmlParagraph();
                            final childNode = parseNode(child, childParagraph, cx);
                            if (childNode != null) {
                                children.push(childNode);
                                endsWithBreak = false;
                            }
                            if (childParagraph.content.textLen() > 0) {
                                endsWithBreak = childParagraph.endsWithBreak;
                                // If last child is paragraph, merge child
                                if (children.length > 0) {
                                    switch children[children.length - 1] {
                                        case Paragraph(lastParagraph):
                                            lastParagraph.merge(childParagraph.content);
                                            continue;
                                        case _:
                                    }
                                }

                                children.push(BlockNode.Paragraph(childParagraph.content));
                            }
                        }

                        if (endsWithBreak && children.length > 0) {
                            switch children[children.length - 1] {
                                case Paragraph(last):
                                    trimTrailingBreak(last);
                                case _:
                            }
                        }
                        consumeParagraph(children, paragraph);

                        return BlockNode.ListItem(children, false, null, null);
                    case 'table':
                        final children:Array<BlockNode> = [];
                        consumeParagraph(children, paragraph);

                        final table = new Table();
                        for (child in node.children.borrow()) {
                            switch child.data {
                                case Element(name, _, _, _) if (name.local == 'tbody' || name.local == 'thead'):
                                    for (subChild in child.children.borrow()) {
                                        parseTableRow(table, subChild);
                                    }
                                case _:
                                    parseTableRow(table, child);
                            }
                        }
                        consumeParagraph(children, paragraph);

                        final table = BlockNode.Table(table);
                        if (children.length > 0) {
                            children.push(table);
                            return BlockNode.Root(children, null);
                        }
                        else {
                            return table;
                        }
                    case 'blockquote':
                        final children = consumeChildrenNodes(node, paragraph, cx);
                        return BlockNode.Blockquote(children, null);
                    case 'style' | 'script':
                        return null;
                    case _:
                        if (BLOCK_ELEMENTS.contains(TextUtils.trim(name.local))) {
                            final children:Array<BlockNode> = [];

                            // Case:
                            //
                            // Hello <p>Inner text of block element</p> World

                            // Insert before text as a node: the "Hello"
                            consumeParagraph(children, paragraph);

                            // Inner of the block element: the "Inner text of block element"
                            for (child in node.children.borrow()) {
                                final childNode = parseNode(child, paragraph, cx);
                                if (childNode != null) {
                                    children.push(childNode);
                                }
                            }
                            consumeParagraph(children, paragraph);

                            if (children.length == 0) {
                                return null;
                            }
                            else {
                                return BlockNode.Root(children, null);
                            }
                        }
                        else {
                            // Others to as Inline
                            parseParagraph(paragraph, node);

                            if (paragraph.content.isImage()) {
                                return BlockNode.Paragraph(paragraph.take());
                            }
                            else {
                                return null;
                            }
                        }
                }
            case Document:
                final children = consumeChildrenNodes(node, paragraph, cx);
                return BlockNode.Root(children, null);
            case Doctype(_, _, _) | Comment(_) | ProcessingInstruction(_, _):
                return null;
        }
    }

    static function consumeChildrenNodes(node:Node, paragraph:HtmlParagraph, cx:NodeContext):Array<BlockNode> {
        final children:Array<BlockNode> = [];
        consumeParagraph(children, paragraph);
        for (child in node.children.borrow()) {
            final childNode = parseNode(child, paragraph, cx);
            if (childNode != null) {
                children.push(childNode);
            }
            consumeParagraph(children, paragraph);
        }

        return children;
    }

    static function consumeParagraph(children:Array<BlockNode>, paragraph:HtmlParagraph):Void {
        if (paragraph.content.isEmpty()) {
            return;
        }

        children.push(BlockNode.Paragraph(paragraph.take()));
    }

    /**
     * Drops one trailing HTML break after the parser has established its
     * provenance. The break may be a separate node or part of a marked run.
     * A standalone break is retained for Markdown's inline-HTML parser.
     */
    @:allow(gpui.base.text.format)
    static function trimTrailingBreak(paragraph:Paragraph):Void {
        final children = paragraph.children_;
        if (children.length == 1 && children[0].text_ == '\n') {
            return;
        }
        if (children.length == 0) {
            return;
        }
        final last = children[children.length - 1];
        if (!StringTools.endsWith(last.text_, '\n')) {
            return;
        }
        final text = last.text_.substr(0, last.text_.length - 1);
        if (text == '') {
            gpui.util.Stacks.drop(children);
            return;
        }
        final len = TextUtils.len(text);
        last.text_ = text;
        final kept:Array<RangedMark> = [];
        for (ranged in last.marks_) {
            final end = ranged.range.end < len ? ranged.range.end : len;
            if (ranged.range.start < end)
                kept.push(new RangedMark(new Range(ranged.range.start, end), ranged.mark));
        }
        last.marks_ = kept;
    }

    /** Rust `str::to_ascii_lowercase`. */
    static function asciiLowercase(s:String):String {
        final buf = new StringBuf();
        for (i in 0...s.length) {
            final c = StringTools.fastCodeAt(s, i);
            buf.addChar(c >= 'A'.code && c <= 'Z'.code ? c + 32 : c);
        }
        return buf.toString();
    }

}
