// Ported from gpui-kit 0.8.1: crates/component/src/text/frontmatter.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.text;

import glaze.App;
import glaze.IntoElement;
import glaze.Window;
import glaze.kit.base.text.MarkdownNode;
import glaze.kit.base.text.MarkdownParseContext;
import glaze.kit.base.text.MarkdownPlugin;
import glaze.kit.descriptionlist.DescriptionList;
import markdown.mdast.Node;

/**
 * Renders top-level YAML frontmatter mappings as a description list.
 *
 * Enable frontmatter parsing with `MarkdownExtensions.frontmatter` before
 * registering this plugin. Values are rendered as plain text; YAML block
 * scalars with `|-` and `>-` are supported. Quoted or compound values,
 * comments after values, other block headers, and more-indented folded lines
 * use TextView's YAML code block fallback.
 */
class FrontmatterPlugin extends MarkdownPlugin {

    static inline final NODE_NAME = 'frontmatter';

    public function new() {}

    override public function isBlock():Bool {
        return true;
    }

    public function name():String {
        return NODE_NAME;
    }

    public function parse(node:Node, cx:MarkdownParseContext):Null<MarkdownNode> {
        final yaml = switch node {
            case Yaml(yaml): yaml;
            case _: return null;
        }
        final frontmatter = parseFrontmatter(yaml.value);
        if (frontmatter == null) {
            return null;
        }
        final text = frontmatter.text();
        final source = cx.nodeSource(node);

        return new MarkdownNode(NODE_NAME, frontmatter)
            .text(text)
            .markdown(source != null ? source : yaml.value);
    }

    override public function render(node:MarkdownNode, window:Window, cx:App):IntoElement {
        final frontmatter = node.data(Frontmatter);
        if (frontmatter == null) {
            throw 'frontmatter node data';
        }

        return DescriptionList.horizontal()
            .labelWidth(glaze.Prelude.rems(12.))
            .columns(1)
            .children([
                for (entry in frontmatter.entries) DescriptionItem.create(entry.key).value(entry.value)
            ]);
    }

    /** Rust `str::lines`: split on `\n`, drop a final `\r` of each line and a final empty line. */
    static function lines(value:String):Array<String> {
        if (value.length == 0) {
            return [];
        }
        final lines = value.split('\n');
        if (lines[lines.length - 1] == '') {
            lines.pop();
        }
        return [for (line in lines) StringTools.endsWith(line, '\r') ? line.substr(0, line.length - 1) : line];
    }

    static inline function startsWithBlank(value:String):Bool {
        return StringTools.startsWith(value, ' ') || StringTools.startsWith(value, '\t');
    }

    static function isPlainKey(key:String):Bool {
        if (key.length == 0) {
            return false;
        }
        for (i in 0...key.length) {
            final c = StringTools.fastCodeAt(key, i);
            final ok = (c >= '0'.code && c <= '9'.code) || (c >= 'a'.code && c <= 'z'.code) || (c >= 'A'.code && c <= 'Z'.code) || c == '-'.code
                || c == '_'.code;
            if (!ok) {
                return false;
            }
        }
        return true;
    }

    /** `false` where Rust's `push_continuation` returns `None`. */
    static function pushContinuation(entry:FrontmatterParseEntry, line:String):Bool {
        // Remove only the structural indentation, never scalar content spaces.
        var content = '';
        if (line.length != 0) {
            var indent = 0;
            while (indent < line.length && StringTools.fastCodeAt(line, indent) == ' '.code) {
                indent++;
            }
            if (indent == line.length && entry.indent == null) {
                // Its significance depends on the indentation of a later line.
                return false;
            }
            if (entry.indent == null) {
                entry.indent = indent;
            }
            final required:Int = entry.indent;
            if (required == 0 || (indent < required && indent != line.length)) {
                return false;
            }
            content = line.substr(required < line.length ? required : line.length);
        }
        switch entry.style {
            case Folded:
                // Folding more-indented lines requires a wider YAML grammar.
                if (startsWithBlank(content)) {
                    return false;
                }
                if (content.length == 0) {
                    entry.value += '\n';
                    entry.lines++;
                    return true;
                }
                if (entry.value.length != 0 && !StringTools.endsWith(entry.value, '\n')) {
                    entry.value += ' ';
                }
            case Literal:
                if (entry.lines > 0) {
                    entry.value += '\n';
                }
            case Plain | Empty:
                return false;
        }
        entry.value += content;
        entry.lines++;
        return true;
    }

    static inline function isBlockScalar(entry:Null<FrontmatterParseEntry>):Bool {
        return entry != null && (entry.style == Folded || entry.style == Literal);
    }

    @:allow(tests)
    static function parseFrontmatter(value:String):Null<Frontmatter> {
        final entries:Array<FrontmatterParseEntry> = [];
        var current:Null<FrontmatterParseEntry> = null;

        for (line in lines(value)) {
            final trimmed = StringTools.trim(line);
            if (trimmed.length == 0) {
                if (isBlockScalar(current)) {
                    if (!pushContinuation(current, line)) {
                        return null;
                    }
                }
                continue;
            }

            final isTopLevel = !startsWithBlank(line);
            if (StringTools.startsWith(trimmed, '#') && (isTopLevel || !isBlockScalar(current))) {
                continue;
            }

            if (isTopLevel) {
                final colon = line.indexOf(':');
                if (colon < 0) {
                    return null;
                }
                final key = line.substr(0, colon);
                var rawValue = line.substr(colon + 1);
                if (rawValue.length != 0 && !startsWithBlank(rawValue)) {
                    return null;
                }
                final key = StringTools.trim(key);
                if (!isPlainKey(key)) {
                    return null;
                }

                if (current != null) {
                    entries.push(current);
                    current = null;
                }

                rawValue = StringTools.trim(rawValue);
                var entryValue = '';
                var style:FrontmatterScalarStyle;
                switch rawValue {
                    case '>-':
                        style = Folded;
                    case '|-':
                        style = Literal;
                    case '':
                        style = Empty;
                    case _:
                        // Decline syntax we cannot interpret faithfully. The caller
                        // preserves it using the existing YAML code block fallback.
                        final first = rawValue.charAt(0);
                        if (['\'', '"', '[', ']', '{', '}', '&', '*', '!', '|', '>', '#', '%', '@', '`'].indexOf(first) >= 0
                            || ['- ', '? ', ': ', '-\t', '?\t', ':\t'].filter(prefix -> StringTools.startsWith(rawValue, prefix)).length > 0
                            || StringTools.endsWith(rawValue, ':')
                            || [' #', '\t#', ': ', ':\t'].filter(pattern -> rawValue.indexOf(pattern) >= 0).length > 0) {
                            return null;
                        }
                        entryValue = rawValue;
                        style = Plain;
                }
                current = new FrontmatterParseEntry(key, entryValue, style);
            }
            else if (isBlockScalar(current)) {
                if (!pushContinuation(current, line)) {
                    return null;
                }
            }
            else {
                return null;
            }
        }

        if (current != null) {
            entries.push(current);
        }
        if (entries.length == 0) {
            return null;
        }

        return new Frontmatter([
            for (entry in entries) new FrontmatterEntry(entry.key, if (entry.style == Folded || entry.style == Literal) {
                var value = entry.value;
                while (StringTools.endsWith(value, '\n')) {
                    value = value.substr(0, value.length - 1);
                }
                value;
            } else {
                entry.value;
            })
        ]);
    }

}

@:allow(glaze.kit.text, tests)
class FrontmatterEntry {

    public final key:String;

    public final value:String;

    public function new(key:String, value:String) {
        this.key = key;
        this.value = value;
    }

}

@:allow(glaze.kit.text, tests)
class Frontmatter {

    public final entries:Array<FrontmatterEntry>;

    public function new(entries:Array<FrontmatterEntry>) {
        this.entries = entries;
    }

    public function text():String {
        return [for (entry in entries) '${entry.key}: ${entry.value}'].join('\n');
    }

}

private enum FrontmatterScalarStyle {
    Plain;
    Folded;
    Literal;
    Empty;
}

private class FrontmatterParseEntry {

    public final key:String;

    public var value:String;

    public final style:FrontmatterScalarStyle;

    public var indent:Null<Int> = null;

    public var lines:Int = 0;

    public function new(key:String, value:String, style:FrontmatterScalarStyle) {
        this.key = key;
        this.value = value;
        this.style = style;
    }

}
