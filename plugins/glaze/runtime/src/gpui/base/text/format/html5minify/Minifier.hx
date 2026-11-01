// Ported from gpui-kit 0.8.1: crates/base/src/text/format/html5minify/mod.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// That file is a fork of the html5minify crate (https://github.com/martingallagher/html5minify),
// by Martin Gallagher, licensed under MIT (html5minify 0.3.3 Cargo.toml).
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text.format.html5minify;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import haxe.io.Encoding;
import haxe.io.Input;
import haxe.io.Output;
import html5ever.Html5ever;
import html5ever.driver.ParseOpts;
import html5ever.markup5ever.Attribute;
import html5ever.markup5ever.QualName;
import html5ever.markup5ever_rcdom.Node;
import html5ever.markup5ever_rcdom.NodeData;
import html5ever.markup5ever_rcdom.RcDom;

/**
 * HTML5 markup minifier.
 *
 * The free function `minify(r, w)` and the `Minify` trait of the Rust
 * module. Rust readers and writers (`io::Read`, `io::Write`) are
 * `haxe.io.Input` and `haxe.io.Output`; I/O errors are exceptions.
 */
class Minify {

    /**
     * Minifies the HTML input to the destination writer.
     * Outputs HTML5; non-HTML5 input will be transformed to HTML5.
     */
    public static function minify(r:Input, w:Output):Void {
        new Minifier(w).minify(r);
    }

    /**
     * Minifies the source returning the minified HTML5 (Rust trait
     * `Minify::minify`, implemented for every `AsRef<[u8]>`).
     */
    public static function minifyBytes(source:Bytes):Bytes {
        final minified = new BytesOutput();
        minify(new BytesInput(source), minified);
        return minified.getBytes();
    }

}

/**
 * Holds node positional context.
 *
 * Rust keeps the `left` and `right` sibling slices; here they are the
 * siblings before and after `index` in `siblings`.
 */
private class Context {

    public final parent:Node;
    public final parentContext:Null<Context>;
    public final siblings:Array<Node>;
    public final index:Int;

    public function new(parent:Node, parentContext:Null<Context>, siblings:Array<Node>, index:Int) {
        this.parent = parent;
        this.parentContext = parentContext;
        this.siblings = siblings;
        this.index = index;
    }

    /** `left.is_some()`. */
    public inline function hasLeft():Bool {
        return index > 0;
    }

    /** `right.is_some()`. */
    public inline function hasRight():Bool {
        return index + 1 < siblings.length;
    }

    /**
     * Determine whether to trim whitespace.
     * Uses naive HTML5 whitespace collapsing rules.
     */
    public function trim(precedingWhitespace:Bool):{left:Bool, right:Bool} {
        return {left: precedingWhitespace || trimLeft(), right: trimRight()};
    }

    public function trimLeft():Bool {
        if (!hasLeft())
            return Minifier.isBlockElement(parent) || parentTrimLeft();
        var i = index - 1;
        while (i >= 0) {
            final found = isBlockElementOf(siblings[i]);
            if (found != null)
                return found;
            i--;
        }
        return parentTrimLeft();
    }

    function parentTrimLeft():Bool {
        return parentContext == null ? true : parentContext.trimLeft();
    }

    public function trimRight():Bool {
        if (!hasRight())
            return true;
        for (i in index + 1...siblings.length) {
            final found = isBlockElementOf(siblings[i]);
            if (found != null)
                return found;
        }
        return true;
    }

    public function nextElement():Null<Node> {
        if (!hasRight())
            return null;
        for (i in index + 1...siblings.length) {
            if (siblings[i].data.match(Element(_, _, _, _)))
                return siblings[i];
        }
        return null;
    }

    /** Rust `Context::is_block_element`: `None` when the node is not an element. */
    static function isBlockElementOf(node:Node):Null<Bool> {
        return switch node.data {
            case Element(name, _, _, _): Minifier.isBlockElementName(name.local);
            case _: null;
        }
    }

    /**
     * Whether the parent keeps its whitespace, or an element above it does:
     * text in `<pre><code>` keeps its whitespace as well.
     */
    public function preservesWhitespace():Bool {
        final parentPreserves = switch parent.data {
            case Element(name, _, _, _): Minifier.preserveWhitespace(name.local);
            case _: false;
        }
        return parentPreserves || (parentContext != null && parentContext.preservesWhitespace());
    }

}

/**
 * Writes a reserved character as an entity, or returns null (Rust
 * `EntityFn`, working on one byte).
 */
typedef EntityFn = (c:Int) -> Null<String>;

/**
 * Minifier implementation for `io::Write` (here `haxe.io.Output`).
 *
 * Text is handled as Haxe strings: every test and every split is on an ASCII
 * character, so working on code units gives the same output as Rust working
 * on UTF-8 bytes.
 */
class Minifier {

    var w:Output;
    var omitDoctype_:Bool;
    var collapseWhitespace_:Bool;
    var preserveComments_:Bool;
    var precedingWhitespace:Bool;

    /** Creates a new `Minifier` instance. */
    public function new(w:Output) {
        this.w = w;
        this.omitDoctype_ = false;
        this.collapseWhitespace_ = true;
        this.preserveComments_ = false;
        this.precedingWhitespace = false;
    }

    /**
     * Collapse whitespace between elements and in text when whitespace isn't
     * preserved by default. Enabled by default.
     */
    public function collapseWhitespace(collapse:Bool):Minifier {
        this.collapseWhitespace_ = collapse;
        return this;
    }

    /** Omit writing the HTML5 doctype. Disabled by default. */
    public function omitDoctype(omit:Bool):Minifier {
        this.omitDoctype_ = omit;
        return this;
    }

    /** Preserve HTML comments. Disabled by default. */
    public function preserveComments(preserve:Bool):Minifier {
        this.preserveComments_ = preserve;
        return this;
    }

    /** Minifies the given reader input. Throws when it cannot write. */
    public function minify(r:Input):Void {
        final dom = Html5ever.parseDocument(new RcDom(), new ParseOpts()).fromUtf8().readFrom(r);

        if (!omitDoctype_) {
            writeAll('<!doctype html>');
        }

        minifyNode(null, dom.document);
    }

    inline function writeAll(s:String):Void {
        if (s.length > 0)
            w.writeString(s, Encoding.UTF8);
    }

    function minifyNode(ctx:Null<Context>, node:Node):Void {
        switch node.data {
            case Text(contentsCell):
                // Check if whitespace collapsing disabled
                var contents = contentsCell.borrow();

                if (!collapseWhitespace_) {
                    writeAll(contents);
                    return;
                }

                // Check if parent is whitespace preserving element or contains code (<script>, <style>)
                var parentPreservesWhitespace = false;
                var containsCode = false;
                if (ctx != null) {
                    switch ctx.parent.data {
                        case Element(name, _, _, _):
                            parentPreservesWhitespace = preserveWhitespace(name.local);
                            containsCode = Minifier.containsCode(name.local);
                        case _:
                    }
                }
                final skipCollapseWhitespace = ctx != null && ctx.preservesWhitespace();

                if (skipCollapseWhitespace) {
                    // The parser drops a line feed right after `<pre>` or
                    // `<textarea>`, so one that starts the text needs another
                    // in front of it to survive the next parse. Comments
                    // before it are left out, so they do not count. A line
                    // feed after a nested start tag, as in `<pre><code>`, is
                    // kept by the parser and needs nothing.
                    var first = false;
                    if (parentPreservesWhitespace && ctx != null) {
                        if (!ctx.hasLeft()) {
                            first = true;
                        }
                        else {
                            first = !preserveComments_;
                            if (first) {
                                for (i in 0...ctx.index) {
                                    if (!ctx.siblings[i].data.match(Comment(_))) {
                                        first = false;
                                        break;
                                    }
                                }
                            }
                        }
                    }
                    if (first && StringTools.startsWith(contents, '\n')) {
                        writeAll('\n');
                    }
                    // The text is decoded: `&lt;b&gt;` is `<b>` here, and
                    // would come back as markup if written as it is.
                    write(contents, reservedEntity);
                    return;
                }

                if (containsCode) {
                    writeAll(trimAsciiWhitespace(contents));
                    return;
                }

                // Early exit if empty to forego expensive trim logic
                if (contents.length == 0) {
                    return;
                }

                var trimLeft = true;
                var trimRight = true;
                if (ctx != null) {
                    final trim = ctx.trim(precedingWhitespace);
                    trimLeft = trim.left;
                    trimRight = trim.right;
                }
                if (trimLeft && trimRight)
                    contents = trimAsciiWhitespace(contents);
                else if (trimLeft)
                    contents = trimStartAsciiWhitespace(contents);
                else if (trimRight)
                    contents = trimEndAsciiWhitespace(contents);

                // Second empty check after trimming whitespace
                if (contents.length != 0) {
                    // replace \n, \r to ' '
                    final buf = new StringBuf();
                    for (i in 0...contents.length) {
                        final c = StringTools.fastCodeAt(contents, i);
                        buf.addChar(c == '\n'.code || c == '\r'.code ? ' '.code : c);
                    }
                    contents = buf.toString();

                    writeCollapseWhitespace(contents, reservedEntity, null);

                    precedingWhitespace = !trimRight && isAsciiWhitespace(StringTools.fastCodeAt(contents, contents.length - 1));
                }

            case Comment(contents) if (preserveComments_):
                writeAll('<!--');
                writeAll(contents);
                writeAll('-->');

            case Document:
                minifyChildren(ctx, node);

            case Element(name, attrsCell, _, _):
                final attrs = attrsCell.borrow();
                final tag = name.local;

                if (isSelfClosing(tag)) {
                    writeStartTag(name, attrs);
                    return;
                }

                final omit = omitTags(ctx, node, tag, attrs.length == 0);

                if (!omit.start) {
                    writeStartTag(name, attrs);
                }

                minifyChildren(ctx, node);

                if (!omit.end) {
                    writeEndTag(name);
                }

            case _:
        }
    }

    /** Rust `next_is_comment` over the nodes of `v` from `start`. */
    function nextIsComment(v:Array<Node>, start:Int):Bool {
        for (i in start...v.length) {
            final found:Null<Bool> = switch v[i].data {
                case Text(contents):
                    if (collapseWhitespace_ && isWhitespace(contents.borrow())) {
                        // Blocks of whitespace are skipped
                        null;
                    }
                    else {
                        false;
                    }
                case Comment(_): preserveComments_;
                case _: false;
            }
            if (found != null)
                return found;
        }
        return false;
    }

    /** Rust `Minifier::is_whitespace`. */
    function isWhitespaceOf(s:String):Null<Bool> {
        if (collapseWhitespace_ && isWhitespace(s)) {
            return null;
        }
        else {
            return !(s.length > 0 && isAsciiWhitespace(StringTools.fastCodeAt(s, 0)));
        }
    }

    /**
     * Determines if start and end tags can be omitted.
     * Whitespace rules are ignored if `collapse_whitespace` is enabled.
     */
    function omitTags(ctx:Null<Context>, node:Node, name:String, emptyAttributes:Bool):{start:Bool, end:Bool} {
        if (ctx == null)
            return {start: false, end: false};

        switch name {
            case 'html':
                // The end tag may be omitted if the <html> element is not immediately followed by a comment.
                final omitEnd = !ctx.hasRight() || !nextIsComment(ctx.siblings, ctx.index + 1);
                // The start tag may be omitted if the first thing inside the <html> element is not a comment.
                final omitStart = emptyAttributes && omitEnd && !nextIsComment(node.children.borrow(), 0);

                return {start: omitStart, end: omitEnd};

            case 'head':
                // The end tag may be omitted if the first thing following the <head> element is not a space character or a comment.
                var omitEnd = true;
                if (ctx.hasRight()) {
                    var found:Null<Bool> = null;
                    for (i in ctx.index + 1...ctx.siblings.length) {
                        found = switch ctx.siblings[i].data {
                            case Text(contents): isWhitespaceOf(contents.borrow());
                            case Comment(_): preserveComments_ ? false : null;
                            case _: true;
                        }
                        if (found != null)
                            break;
                    }
                    omitEnd = found != null ? found : true;
                }
                // The start tag may be omitted if the first thing inside the <head> element is an element.
                var omitStart = emptyAttributes && omitEnd;
                if (omitStart) {
                    var found:Null<Bool> = null;
                    for (child in node.children.borrow()) {
                        found = switch child.data {
                            case Text(contents): isWhitespaceOf(contents.borrow());
                            case Element(_, _, _, _): true;
                            case Comment(_): preserveComments_ ? false : null;
                            case _: false;
                        }
                        if (found != null)
                            break;
                    }
                    omitStart = found != null ? found : true;
                }

                return {start: omitStart, end: omitEnd};

            case 'body':
                // The start tag may be omitted if the first thing inside it is not a space character, comment, <script> element or <style> element.
                var omitStart = emptyAttributes;
                if (omitStart) {
                    var found:Null<Bool> = null;
                    for (child in node.children.borrow()) {
                        found = switch child.data {
                            case Text(contents): isWhitespaceOf(contents.borrow());
                            case Element(name, _, _, _): !(name.local == 'script' || name.local == 'style');
                            case Comment(_): preserveComments_ ? false : null;
                            case _: true;
                        }
                        if (found != null)
                            break;
                    }
                    omitStart = found != null ? found : true;
                }
                // The end tag may be omitted if the <body> element has contents or has a start tag, and is not immediately followed by a comment.
                final omitEnd = !ctx.hasRight() || !nextIsComment(ctx.siblings, ctx.index + 1);

                return {start: omitStart && omitEnd, end: omitEnd};

            case 'p':
                final next = ctx.nextElement();
                var omitEnd = true;
                if (next != null) {
                    omitEnd = switch next.data {
                        case Element(name, _, _, _):
                            switch asciiLowercase(name.local) {
                                case 'address' | 'article' | 'aside' | 'blockquote' | 'div' | 'dl' | 'fieldset' | 'footer' | 'form' | 'h1' | 'h2' |
                                    'h3' | 'h4' | 'h5' | 'h6' | 'header' | 'hr' | 'menu' | 'nav' | 'ol' | 'p' | 'pre' | 'section' | 'table' | 'ul':
                                    true;
                                case _:
                                    false;
                            }
                        case _:
                            false;
                    }
                }

                return {start: false, end: omitEnd};

            // TODO: comprehensive handling of optional end element rules
            case _:
                return {start: false, end: optionalEndTag(name)};
        }
    }

    function minifyChildren(ctx:Null<Context>, node:Node):Void {
        final children = node.children.borrow();

        for (i in 0...children.length) {
            final child = children[i];
            if (precedingWhitespace && isBlockElement(child)) {
                precedingWhitespace = false;
            }

            minifyNode(new Context(node, ctx, children, i), child);
        }
    }

    function writeQualifiedName(name:QualName):Void {
        if (name.prefix != null) {
            writeAll(asciiLowercase(name.prefix));
            writeAll(':');
        }

        writeAll(asciiLowercase(name.local));
    }

    function writeStartTag(name:QualName, attrs:Array<Attribute>):Void {
        writeAll('<');
        writeQualifiedName(name);

        for (attr in attrs)
            writeAttribute(attr);

        writeAll('>');
    }

    function writeEndTag(name:QualName):Void {
        writeAll('</');
        writeQualifiedName(name);
        writeAll('>');
    }

    function writeAttribute(attr:Attribute):Void {
        writeAll(' ');
        writeQualifiedName(attr.name);

        var value = attr.value;
        if (collapseWhitespace_)
            value = trimAsciiWhitespace(value);

        if (value.length == 0) {
            return;
        }

        writeAll('=');

        var unquoted = true;
        var double = false;
        var single = false;
        for (i in 0...value.length) {
            final c = StringTools.fastCodeAt(value, i);
            double = double || c == '"'.code;
            single = single || c == "'".code;
            unquoted = unquoted && !double && !single && c != '='.code && !isAsciiWhitespace(c);
        }

        if (unquoted) {
            writeAll(value);
        }
        else if (double) {
            writeAttributeValue(value, "'", reservedEntityWithApos);
        }
        else {
            writeAttributeValue(value, '"', reservedEntity);
        }
    }

    function writeAttributeValue(v:String, quote:String, f:EntityFn):Void {
        writeAll(quote);

        if (collapseWhitespace_) {
            writeCollapseWhitespace(v, f, false);
        }
        else {
            writeAll(v);
        }

        writeAll(quote);
    }

    /**
     * Efficiently writes blocks of content, e.g. a string with no collapsed
     * whitespace would result in a single write.
     */
    function writeCollapseWhitespace(b:String, f:EntityFn, precedingWhitespace:Null<Bool>):Void {
        var pos = 0;
        var preceding:Bool = precedingWhitespace != null ? precedingWhitespace : this.precedingWhitespace;
        for (i in 0...b.length) {
            final isWhitespace = isAsciiWhitespace(StringTools.fastCodeAt(b, i));

            if (isWhitespace && preceding) {
                if (i != pos) {
                    write(b.substring(pos, i), f);
                }

                // ASCII whitespace = 1 byte
                pos = i + 1;
                preceding = true;
            }
            else {
                preceding = isWhitespace;
            }
        }

        if (pos < b.length) {
            write(b.substring(pos), f);
        }
    }

    function write(b:String, f:EntityFn):Void {
        var pos = 0;
        for (i in 0...b.length) {
            final entity = f(StringTools.fastCodeAt(b, i));
            if (entity != null) {
                writeAll(b.substring(pos, i));
                writeAll(entity);

                // Reserved characters are 1 byte
                pos = i + 1;
            }
        }

        if (pos < b.length) {
            writeAll(b.substring(pos));
        }
    }

    static function reservedEntity(v:Int):Null<String> {
        return switch v {
            case '<'.code: '&lt;';
            case '>'.code: '&gt;';
            case '&'.code: '&#38;';
            case _: null;
        }
    }

    static function reservedEntityWithApos(v:Int):Null<String> {
        if (v == "'".code) {
            return '&#39;';
        }
        else {
            return reservedEntity(v);
        }
    }

    /** Rust free `is_whitespace`: every byte is ASCII whitespace. */
    static function isWhitespace(s:String):Bool {
        for (i in 0...s.length) {
            if (!isAsciiWhitespace(StringTools.fastCodeAt(s, i)))
                return false;
        }
        return true;
    }

    @:allow(gpui.base.text.format.html5minify)
    static function isBlockElementName(name:String):Bool {
        return switch name {
            case 'address' | 'article' | 'aside' | 'blockquote' | 'body' | 'br' | 'details' | 'dialog' | 'dd' | 'div' | 'dl' | 'dt' | 'fieldset' |
                'figcaption' | 'figure' | 'footer' | 'form' | 'h1' | 'h2' | 'h3' | 'h4' | 'h5' | 'h6' | 'head' | 'header' | 'hgroup' | 'hr' | 'html' |
                'li' | 'link' | 'main' | 'meta' | 'nav' | 'ol' | 'option' | 'p' | 'pre' | 'script' | 'section' | 'source' | 'table' | 'td' | 'th' |
                'title' | 'tr' | 'ul':
                true;
            case _:
                false;
        }
    }

    @:allow(gpui.base.text.format.html5minify)
    static function isBlockElement(node:Node):Bool {
        return switch node.data {
            case Element(name, _, _, _): isBlockElementName(name.local);
            case Document: true;
            case _: false;
        }
    }

    /** Rust `u8::is_ascii_whitespace`: space, tab, line feed, form feed, carriage return. */
    static inline function isAsciiWhitespace(c:Int):Bool {
        return c == ' '.code || c == '\t'.code || c == '\n'.code || c == 0x0C || c == '\r'.code;
    }

    /** Rust `trim_matches(is_ascii_whitespace)`. */
    static function trimAsciiWhitespace(s:String):String {
        return trimEndAsciiWhitespace(trimStartAsciiWhitespace(s));
    }

    /** Rust `trim_start_matches(is_ascii_whitespace)`. */
    static function trimStartAsciiWhitespace(s:String):String {
        var start = 0;
        while (start < s.length && isAsciiWhitespace(StringTools.fastCodeAt(s, start)))
            start++;
        return start == 0 ? s : s.substring(start);
    }

    /** Rust `trim_end_matches(is_ascii_whitespace)`. */
    static function trimEndAsciiWhitespace(s:String):String {
        var end = s.length;
        while (end > 0 && isAsciiWhitespace(StringTools.fastCodeAt(s, end - 1)))
            end--;
        return end == s.length ? s : s.substring(0, end);
    }

    /** Rust `str::to_ascii_lowercase`. */
    static function asciiLowercase(s:String):String {
        var buf:Null<StringBuf> = null;
        for (i in 0...s.length) {
            final c = StringTools.fastCodeAt(s, i);
            if (c >= 'A'.code && c <= 'Z'.code) {
                if (buf == null) {
                    buf = new StringBuf();
                    buf.addSub(s, 0, i);
                }
                buf.addChar(c + 32);
            }
            else if (buf != null) {
                buf.addChar(c);
            }
        }
        return buf == null ? s : buf.toString();
    }

    @:allow(gpui.base.text.format.html5minify)
    static function preserveWhitespace(name:String):Bool {
        return name == 'pre' || name == 'textarea';
    }

    static function containsCode(name:String):Bool {
        return name == 'script' || name == 'style';
    }

    static function isSelfClosing(name:String):Bool {
        return switch name {
            case 'area' | 'base' | 'br' | 'col' | 'embed' | 'hr' | 'img' | 'input' | 'link' | 'meta' | 'param' | 'source' | 'track' | 'wbr' |
                'command' | 'keygen' | 'menuitem':
                true;
            case _:
                false;
        }
    }

    static function optionalEndTag(name:String):Bool {
        return switch name {
            case 'basefont' | 'colgroup' | 'dd' | 'dt' | 'frame' | 'isindex' | 'li' | 'option' | 'p' | 'tbody' | 'td' | 'tfoot' | 'th' | 'thead' |
                'tr':
                true;
            case _:
                false;
        }
    }

}
