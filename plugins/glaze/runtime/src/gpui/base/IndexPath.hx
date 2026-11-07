// Ported from gpui-kit 0.8.1: crates/base/src/index_path.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

import gpui.ElementId;

/**
 * Represents an index path in a list: a section index, a row and a column
 * (all 0 by default). Immutable: the builders return a new path.
 */
class IndexPath {

    /** The section index. */
    public final section:Int;

    /** The item index in the section. */
    public final row:Int;

    /** The column index. */
    public final column:Int;

    public inline function new(row:Int = 0, section:Int = 0, column:Int = 0) {
        this.section = section;
        this.row = row;
        this.column = column;
    }

    /**
     * Rust `IndexPath::default()`.
     */
    public static inline function defaultValue():IndexPath {
        return new IndexPath();
    }

    /** Set the section for the index path. */
    public inline function withSection(section:Int):IndexPath {
        return new IndexPath(row, section, column);
    }

    /** Set the row for the index path. */
    public inline function withRow(row:Int):IndexPath {
        return new IndexPath(row, section, column);
    }

    /** Set the column for the index path. */
    public inline function withColumn(column:Int):IndexPath {
        return new IndexPath(row, section, column);
    }

    /**
     * Check if the self is equal to the given index path (same section and row).
     */
    public inline function eqRow(index:IndexPath):Bool {
        return section == index.section && row == index.row;
    }

    public function equals(other:IndexPath):Bool {
        return other != null && section == other.section && row == other.row && column == other.column;
    }

    /**
     * Rust `From<IndexPath> for ElementId`: `index-path(section,row,column)`.
     */
    public function toElementId():ElementId {
        return ElementId.Name('index-path($section,$row,$column)');
    }

    public function toString():String {
        return 'IndexPath(section: $section, row: $row, column: $column)';
    }

}
