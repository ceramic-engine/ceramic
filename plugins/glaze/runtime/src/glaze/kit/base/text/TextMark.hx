// Ported from gpui-kit 0.8.1: crates/base/src/text/node.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.text;

import glaze.Hsla;

/**
 * The style of a run of inline text.
 *
 * Mutable like the Rust struct: the builders (`bold()`, `italic()`...)
 * set the field and return this mark, like Rust's `mut self` builders.
 * Use `clone()` where Rust clones.
 */
class TextMark {

    public var bold:Bool = false;

    public var italic:Bool = false;

    public var strikethrough:Bool = false;

    public var underline:Bool = false;

    public var code:Bool = false;

    /**
     * Highlight (`<mark>`) the text with this background color.
     *
     * `null` means the text is not highlighted.
     */
    public var highlight:Null<Hsla> = null;

    public var link:Null<LinkMark> = null;

    public function new() {}

    public function withBold():TextMark {
        bold = true;
        return this;
    }

    public function withItalic():TextMark {
        italic = true;
        return this;
    }

    public function withStrikethrough():TextMark {
        strikethrough = true;
        return this;
    }

    public function withUnderline():TextMark {
        underline = true;
        return this;
    }

    public function withCode():TextMark {
        code = true;
        return this;
    }

    /** Mark the text as highlighted (`<mark>`) with the given background color. */
    public function withHighlight(color:Hsla):TextMark {
        highlight = color;
        return this;
    }

    public function withLink(link:LinkMark):TextMark {
        this.link = link;
        return this;
    }

    public function merge(other:TextMark):Void {
        bold = bold || other.bold;
        italic = italic || other.italic;
        strikethrough = strikethrough || other.strikethrough;
        underline = underline || other.underline;
        code = code || other.code;
        if (other.highlight != null) {
            highlight = other.highlight;
        }
        if (other.link != null) {
            link = other.link;
        }
    }

    public function clone():TextMark {
        final mark = new TextMark();
        mark.bold = bold;
        mark.italic = italic;
        mark.strikethrough = strikethrough;
        mark.underline = underline;
        mark.code = code;
        mark.highlight = highlight;
        mark.link = link != null ? link.clone() : null;
        return mark;
    }

    public function equals(other:Null<TextMark>):Bool {
        return other != null && bold == other.bold && italic == other.italic && strikethrough == other.strikethrough
            && underline == other.underline && code == other.code
            && (highlight == null ? other.highlight == null : other.highlight != null && highlight.equals(other.highlight))
            && LinkMark.eq(link, other.link);
    }

}
