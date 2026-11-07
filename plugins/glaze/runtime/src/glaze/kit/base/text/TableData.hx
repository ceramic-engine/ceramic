// Ported from gpui-kit 0.8.1: crates/base/src/text/node.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.text;

import glaze.Range;

/**
 * Plain snapshot of a rendered Markdown table, passed to the
 * `TextView.tableActions` hook.
 */
class TableData {

    /** First table row (header cells) as plain text. */
    public var headers:Array<String> = [];

    /**
     * Rows after the header as plain text cells. May be ragged while a table
     * is still streaming in.
     */
    public var rows:Array<Array<String>> = [];

    /** The table serialized back to GFM pipe-table Markdown, alignments kept. */
    public var markdown:String = '';

    /**
     * Byte range of the table in the Markdown source, for callers that need
     * to map the table back to the document.
     */
    public var span:Null<Range> = null;

    public function new() {}

    public function equals(other:Null<TableData>):Bool {
        if (other == null || markdown != other.markdown || headers.join('\x00') != other.headers.join('\x00')
            || rows.length != other.rows.length)
            return false;
        if (headers.length != other.headers.length)
            return false;
        for (i in 0...rows.length) {
            if (rows[i].length != other.rows[i].length || rows[i].join('\x00') != other.rows[i].join('\x00'))
                return false;
        }
        return span == null ? other.span == null : span.equals(other.span);
    }

}
