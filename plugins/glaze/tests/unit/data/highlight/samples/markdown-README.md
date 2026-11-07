# markdown (Haxe port)

A pure Haxe port of [markdown-rs](https://github.com/wooorm/markdown-rs) **1.0.0** (the `markdown` crate), the CommonMark compliant markdown parser written in Rust by Titus Wormer. It turns markdown into HTML or into a syntax tree ([mdast](https://github.com/syntax-tree/mdast)), with GFM, math, frontmatter and MDX extensions.

It is the markdown parser of the gpui-kit rich text engine in Glaze (gpui-kit calls `markdown::to_mdast` with the `serde` feature).

It has no dependency (no Ceramic, no other haxelib) and runs on every Haxe target. The input is encoded to UTF-8 and parsed as `haxe.io.Bytes`, like upstream works on `&[u8]`: positions are the same on targets with UTF-16 strings (JavaScript) and UTF-8 strings.

All credit for the design and the algorithms goes to markdown-rs. This port translates the Rust source file by file: each Haxe module starts with a header naming the Rust file it comes from. The code is distributed under the same terms as markdown-rs, MIT (see [LICENSE](LICENSE)).

## What is ported

The whole crate:

- the tokenizer and its state machine (`tokenizer.rs`, `state.rs`, `event.rs`, `parser.rs`, `subtokenize.rs`, `resolve.rs`);
- every construct of `src/construct`: CommonMark (attention, autolinks, block quotes, character escapes and references, code (fenced, indented, text), definitions, hard breaks, headings (atx, setext), HTML (flow, text), labels, links, images, lists, paragraphs, thematic breaks...), GFM (autolink literals, footnotes, strikethrough, tables, task list items, tag filter), math (flow, text), frontmatter (YAML, TOML), MDX (ESM, expressions, JSX);
- `to_html` / `to_html_with_options` (`to_html.rs`) and `to_mdast` (`to_mdast.rs`), with positions;
- the mdast nodes (`mdast.rs`), unist points and positions (`unist.rs`), messages (`message.rs`), the configuration (`configuration.rs`) and the utilities of `src/util`;
- the `serde` feature: `NodeJson.toJson` writes exactly what `serde_json::to_string` writes for a `mdast::Node` (keys, key order, escaping), `NodeJson.toJson(node, true)` what `serde_json::to_string_pretty` writes, and `NodeJson.fromJson` reads it back. The options have `toJson` (serde output) and `fromDynamic`.

Not ported:

- the `Debug` formatting of nodes and options (Rust only), and the `log` feature;
- the swc based parse functions of the upstream tests (`tests/test_utils`): the MDX parse hooks (`mdxEsmParse`, `mdxExpressionParse`) are ported, but there is no JavaScript parser to plug in them here. Without them, MDX expressions are parsed by counting braces and MDX ESM is off, like upstream.

## Usage

```haxe
import markdown.Markdown;
import markdown.Options;
import markdown.ParseOptions;
import markdown.mdast.Node;
import markdown.mdast.NodeJson;

class Main {

    static function main() {
        trace(Markdown.toHtml('## Hi, *Saturn*! 🪐'));
        // <h2>Hi, <em>Saturn</em>! 🪐</h2>

        trace(Markdown.toHtmlWithOptions('~hi~ www.example.com', Options.gfm()));
        // <p><del>hi</del> <a href="http://www.example.com">www.example.com</a></p>

        var tree = Markdown.toMdast('# Hey, *you*!', ParseOptions.gfm());
        switch tree {
            case Root(root):
                for (child in root.children) {
                    trace(child.toString(), child.position()); // Hey, you! 1:1-1:14 (0-13)
                }
            default:
        }
        trace(NodeJson.toJson(tree)); // {"type":"root","children":[{"type":"heading",...
    }

}
```

## Differences with the Rust API

- Names are converted to camelCase (`to_html_with_options` becomes `Markdown.toHtmlWithOptions`, `gfm_table` becomes `gfmTable`). The free functions of `lib.rs` are static functions of `markdown.Markdown`; `toHtmlBytes` and `toMdastBytes` take UTF-8 bytes directly.
- `Default::default()` is the constructor: `new Options()`, `new ParseOptions()`, `new CompileOptions()`, `new Constructs()` (CommonMark). `gfm()` and `mdx()` are static functions. `Options` takes optional `parse` and `compile` arguments.
- Errors (only possible with MDX) are thrown as a `markdown.message.Message` (`place`, `reason`, `ruleId`, `source`; `toString()` is Rust's `Display`). `Place` is an enum (`Position`, `Point`).
- `mdast::Node` is the Haxe enum `markdown.mdast.Node`, whose constructors wrap one class per node kind (`Root(node:Root)`, `Text(node:Text)`...), with the same fields. `Option<T>` fields are nullable, `u8` / `u32` are `Int`, a stop `(usize, usize)` is a two element `Array<Int>`. `ReferenceKind` and `AlignKind` are enum abstracts, `AttributeContent` and `AttributeValue` enums.
- The methods of `Node` are in `NodeTools` (attached with `@:using`): `children()`, `position()`, `positionSet()`, `toString()` (Rust's `ToString`), plus `setChildren()`, `clone()` and `equals()`. Nodes are objects: `children()` and `position()` return the actual array and position, so they also stand for `children_mut()` and `position_mut()`.
- Positions keep upstream's conventions: `offset` is a UTF-8 byte offset, `line` and `column` start at 1, and columns count bytes.
- The MDX parse functions are Haxe functions: `MdxEsmParse` is `(value:String) -> MdxSignal`, `MdxExpressionParse` is `(value:String, kind:MdxExpressionKind) -> MdxSignal`. `MdxSignal` is an enum (`Error(reason, offset, source, ruleId)`, `Eof(reason, source, ruleId)`, `Ok`); offsets are UTF-8 byte offsets in `value`.
- The internal types (`Tokenizer`, events, `StateName`...) are public in Haxe but not meant to be used. The helpers upstream exports for its own tools are in `markdown.util` (`CharacterReference.decodeNamed`, `CharacterReference.decodeNumeric`, `Identifier.idStart`, `Identifier.idCont`, `SanitizeUri.sanitize`, `Location`).

Implementation notes:

- State functions return an `Int` encoded `State` (no allocation per byte), `Option<u8>` bytes are `Int` with `-1` for `None`.
- `str::to_lowercase` and `to_lowercase().to_uppercase()` (identifiers of references and footnotes) use tables generated from the Rust core library, so non-ASCII labels match exactly like upstream, final sigma included. `char::is_whitespace`, the Unicode punctuation list and the identifier tables (unicode-id 0.3.6, the version gpui-kit uses) are ported as range tables.
- `EditMap` finds an existing edit at an index with a map instead of a linear scan (same result). Upstream is quadratic there on large documents; the port parses a 1.6 MB document in about 1 s on Node.js, where the Rust crate takes about 9 s.
- `Bytes.getString` stops at NUL bytes on some targets: strings that contain one are decoded by hand.

Defect of the original kept as is: `partial_mdx_jsx.rs` tests `tokenizer.current == Some(b'*' | b'/')` to add a note about JS comments to two error messages, but `b'*' | b'/'` is a bitwise or (`/`), so the note never shows for `*`. The port does the same, and the recorded messages confirm it.

## Tests

The `test` folder contains a runner that does not need Ceramic. The fixtures (`test/fixtures/*.jsonl`) were recorded from the upstream test suite: every `tests/*.rs` file of markdown-rs 1.0.0 was compiled against a recording shim of the crate, which logged each call to `to_html`, `to_html_with_options` and `to_mdast` with its input, its options (serialized by serde) and the result of the real crate (HTML, the mdast serialized by serde_json, or the error message). The runner replays every call and compares the results exactly.

- 2376 recorded calls from the 48 test files (CommonMark spec, GFM, every construct, misc and serde tests);
- 144 calls are skipped: they use the swc JavaScript parser (`mdx_esm.rs`, part of the MDX expression and JSX tests, `mdx_swc.rs`);
- 313 extra checks: the behavior tests of the `#[cfg(test)]` modules of the sources, the option tests of `tests/serde.rs`, deserialization of every recorded tree, pretty JSON recorded from the crate, and the MDX parse hooks.

```sh
cd test
./run.sh                    # JavaScript build, run with node
haxe build-cpp.hxml && ./bin/cpp/Main   # native build (needs hxcpp)
```
