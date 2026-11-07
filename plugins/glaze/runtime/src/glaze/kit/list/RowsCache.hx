// Ported from gpui-kit 0.8.1: crates/component/src/list/cache.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.list;

import glaze.App;
import glaze.Size;
import glaze.kit.base.IndexPath;

/**
 * A flattened row of a list: an item, or the header or footer of a section
 * (crate private in Rust).
 */
enum RowEntry {
    Entry(index:IndexPath);
    SectionHeader(section:Int);
    SectionFooter(section:Int);
}

class RowEntryTools {

    public static function isSectionHeader(self:RowEntry):Bool {
        return self.match(SectionHeader(_));
    }

    public static function eqIndexPath(self:RowEntry, path:IndexPath):Bool {
        return switch self {
            case Entry(indexPath): indexPath.equals(path);
            case SectionHeader(_) | SectionFooter(_): false;
        }
    }

    public static function index(self:RowEntry):IndexPath {
        return switch self {
            case Entry(indexPath): indexPath;
            case SectionHeader(ix): IndexPath.defaultValue().withSection(ix);
            case SectionFooter(ix): IndexPath.defaultValue().withSection(ix);
        }
    }

    public static function isSectionFooter(self:RowEntry):Bool {
        return self.match(SectionFooter(_));
    }

    public static inline function isEntry(self:RowEntry):Bool {
        return self.match(Entry(_));
    }

    public static function sectionIx(self:RowEntry):Null<Int> {
        return switch self {
            case SectionHeader(ix) | SectionFooter(ix): ix;
            case _: null;
        }
    }

}

/**
 * The measured sizes of an item, a section header and a section footer.
 */
class MeasuredEntrySize {

    public final itemSize:Size;

    public final sectionHeaderSize:Size;

    public final sectionFooterSize:Size;

    public function new(?itemSize:Size, ?sectionHeaderSize:Size, ?sectionFooterSize:Size) {
        this.itemSize = itemSize != null ? itemSize : new Size(0, 0);
        this.sectionHeaderSize = sectionHeaderSize != null ? sectionHeaderSize : new Size(0, 0);
        this.sectionFooterSize = sectionFooterSize != null ? sectionFooterSize : new Size(0, 0);
    }

    public function equals(other:MeasuredEntrySize):Bool {
        return itemSize.equals(other.itemSize)
            && sectionHeaderSize.equals(other.sectionHeaderSize)
            && sectionFooterSize.equals(other.sectionFooterSize);
    }

}

/**
 * The flattened rows of a list (crate private in Rust). Rust shares the
 * vectors through `Rc`; here they are replaced, never mutated, so a copy of
 * the cache shares them the same way.
 */
@:allow(glaze.kit, tests)
class RowsCache {

    /** Only have section's that have rows. */
    public var entities:Array<RowEntry> = [];

    public var itemsCountValue:Int = 0;

    /** The sections, the item is number of rows in each section. */
    public var sections:Array<Int> = [];

    public var entriesSizes:Array<Size> = [];

    var measuredSize:MeasuredEntrySize = new MeasuredEntrySize();

    public function new() {}

    /** Rust `Clone`. */
    public function clone():RowsCache {
        final cache = new RowsCache();
        cache.entities = entities;
        cache.itemsCountValue = itemsCountValue;
        cache.sections = sections;
        cache.entriesSizes = entriesSizes;
        cache.measuredSize = measuredSize;
        return cache;
    }

    public function get(flattenIx:Int):Null<RowEntry> {
        return flattenIx >= 0 && flattenIx < entities.length ? entities[flattenIx] : null;
    }

    /** Returns the number of flattened rows (Includes header, item, footer). */
    public inline function len():Int {
        return entities.length;
    }

    /** Return the number of items in the cache. */
    public inline function itemsCount():Int {
        return itemsCountValue;
    }

    /** Returns the index of the Entry with given path in the flattened rows. */
    public function positionOf(path:IndexPath):Null<Int> {
        for (i in 0...entities.length) {
            final p = entities[i];
            if (RowEntryTools.isEntry(p) && RowEntryTools.eqIndexPath(p, path)) return i;
        }
        return null;
    }

    /**
     * Returns the flattened position of the first item row, skipping section
     * headers and footers.
     */
    public function firstEntryPosition():Null<Int> {
        for (i in 0...entities.length) {
            if (RowEntryTools.isEntry(entities[i])) return i;
        }
        return null;
    }

    function lastEntryIndex():IndexPath {
        var i = entities.length - 1;
        while (i >= 0) {
            if (RowEntryTools.isEntry(entities[i])) return RowEntryTools.index(entities[i]);
            i--;
        }
        return IndexPath.defaultValue();
    }

    function firstEntryIndex():IndexPath {
        for (entry in entities) {
            if (RowEntryTools.isEntry(entry)) return RowEntryTools.index(entry);
        }
        return IndexPath.defaultValue();
    }

    /**
     * Return prev row, if the row is the first in the first section, goes to the last row.
     *
     * Empty rows section are skipped.
     */
    public function prev(path:Null<IndexPath>):IndexPath {
        final path = path != null ? path : IndexPath.defaultValue();
        final pos = positionOf(path);
        if (pos == null) return lastEntryIndex();

        var i = pos - 1;
        while (i >= 0) {
            if (RowEntryTools.isEntry(entities[i])) return RowEntryTools.index(entities[i]);
            i--;
        }
        return lastEntryIndex();
    }

    /**
     * Returns the next row, if the row is the last in the last section, goes to the first row.
     *
     * Empty rows section are skipped.
     */
    public function next(path:Null<IndexPath>):IndexPath {
        if (path == null) return IndexPath.defaultValue();

        final pos = positionOf(path);
        if (pos == null) return firstEntryIndex();

        for (i in (pos + 1)...entities.length) {
            if (RowEntryTools.isEntry(entities[i])) return RowEntryTools.index(entities[i]);
        }
        return firstEntryIndex();
    }

    public function prepareIfNeeded(sectionsCount:Int, measuredSize:MeasuredEntrySize, cx:App, rowsCountF:(Int, App) -> Int):Void {
        final newSections = [];
        for (sectionIx in 0...sectionsCount) {
            newSections.push(rowsCountF(sectionIx, cx));
        }

        var sameSections = newSections.length == sections.length;
        if (sameSections) {
            for (i in 0...newSections.length) {
                if (newSections[i] != sections[i]) {
                    sameSections = false;
                    break;
                }
            }
        }
        final needUpdate = !sameSections || !this.measuredSize.equals(measuredSize);

        if (!needUpdate) {
            return;
        }

        final entriesSizes:Array<Size> = [];
        var totalItemsCount = 0;
        this.measuredSize = measuredSize;
        this.sections = newSections;
        final entities:Array<RowEntry> = [];
        for (section in 0...newSections.length) {
            final itemsCount = newSections[section];
            totalItemsCount += itemsCount;
            if (itemsCount == 0) continue;

            entities.push(SectionHeader(section));
            entriesSizes.push(measuredSize.sectionHeaderSize);
            for (row in 0...itemsCount) {
                entities.push(Entry(new IndexPath(row, section)));
                entriesSizes.push(measuredSize.itemSize);
            }
            entities.push(SectionFooter(section));
            entriesSizes.push(measuredSize.sectionFooterSize);
        }
        this.entities = entities;
        this.entriesSizes = entriesSizes;
        this.itemsCountValue = totalItemsCount;
    }

}
