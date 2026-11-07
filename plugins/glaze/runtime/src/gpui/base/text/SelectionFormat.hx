// Ported from gpui-kit 0.8.1: crates/base/src/text/state.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text;

/**
 * The format of the text returned by `TextViewState.selectedText`, which is
 * also what copy writes to the clipboard.
 */
enum abstract SelectionFormat(Int) {

    /** The rendered text, without any markup (the default). */
    var Plain = 0;

    /**
     * The source of the selection.
     *
     * Select-all returns the original source verbatim, a partial selection is
     * reconstructed as Markdown from the parsed nodes (e.g. selecting inside a
     * `**bold**` run yields `**bold**`).
     */
    var Source = 1;

    /**
     * The rendered text while the selection stays within one style, the source
     * as soon as it takes in several.
     *
     * A style is everything the source would spell out around the selected
     * text: the marks of an inline run (emphasis, code, a link's URL) and the
     * block it sits in (a heading's `#`, a list marker, a code fence). So
     * selecting inside a `**bold**` run, a link or a code block yields the
     * text alone, also when the selection reaches exactly up to the run's
     * boundaries, while a selection across that boundary, into a second block,
     * or over an inline object copies like `Source`. Two blocks count as two
     * styles even when their marks match. Select-all copies the source verbatim.
     */
    var SourceAcrossStyles = 2;

}
