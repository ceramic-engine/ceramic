// Ported from gpui-kit 0.8.1: crates/base/src/text/stream_fade.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.text;

import glaze.Range;
import glaze.kit.base.motion.Timing;
import glaze.kit.base.text.StreamFadeFrame.LeafFades;
import glaze.kit.base.text.TextLeaf.KeyedTextLeaf;
import glaze.kit.base.text.TextLeaf.TextLeafTools;

private class FadeSegment {
    public var range:Range;
    public final startedAt:Float;

    public inline function new(range:Range, startedAt:Float) {
        this.range = range;
        this.startedAt = startedAt;
    }
}

private class LeafSegments {
    public final key:TextLeafKey;
    public var segments:Array<FadeSegment>;

    public inline function new(key:TextLeafKey, segments:Array<FadeSegment>) {
        this.key = key;
        this.segments = segments;
    }
}

private enum PendingUpdate {
    None;
    /**
     * Every update since the last parse extended the text, which was `origin`
     * bytes long before the first of them.
     */
    Extend(origin:Int);
    Replace;
}

/** Tracks which rendered text arrived recently and samples its fade. */
class StreamFadeTracker {

    var motion:TextViewMotion;

    var pending:PendingUpdate = None;

    var segments:Array<LeafSegments> = [];

    public function new() {
        motion = new TextViewMotion();
    }

    public function setMotion(motion:TextViewMotion):Void {
        if (motion._streamFade == 0) {
            segments = [];
            pending = None;
        }
        this.motion = motion;
    }

    public inline function isEnabled():Bool {
        return motion._streamFade != 0;
    }

    /** The next update extends the current text, which is `len` bytes long. */
    public function noteExtend(len:Int):Void {
        if (!isEnabled()) {
            return;
        }
        pending = switch pending {
            case None: Extend(len);
            case Extend(origin): Extend(origin < len ? origin : len);
            case Replace: Replace;
        }
    }

    /** The next update replaces the current text. */
    public function noteReplace():Void {
        if (isEnabled()) {
            pending = Replace;
        }
    }

    /** Forgets the noted update after its parse failed. */
    public function discardPending():Void {
        pending = None;
    }

    /**
     * Records what `next` renders that `old` did not, for the updates noted
     * since the last call, as segments that start fading at `now`.
     *
     * Only blocks the extension reaches are compared, walking both documents
     * from the tail, so a chunk landing at the end of a long document costs
     * one paragraph, not the document.
     */
    public function record(old:ParsedDocument, next:ParsedDocument, now:Float):Void {
        final pending = this.pending;
        this.pending = None;
        if (!isEnabled()) {
            segments = [];
            return;
        }
        final origin = switch pending {
            case None: return;
            case Replace:
                segments = [];
                return;
            case Extend(origin): origin;
        }

        final affected:Array<KeyedTextLeaf> = [];
        var i = next.blocks.length - 1;
        while (i >= 0) {
            final block = next.blocks[i];
            final span = block.span();
            if (span != null && span.end <= origin) {
                break;
            }
            StreamFade.textLeaves(block, affected);
            i--;
        }
        var firstStart:Null<Int> = null;
        for (leaf in affected) {
            final start = leaf.key.blockStart();
            if (firstStart == null || start < firstStart) firstStart = start;
        }
        if (firstStart == null) {
            return;
        }

        final previous:Array<KeyedTextLeaf> = [];
        var j = old.blocks.length - 1;
        while (j >= 0) {
            final block = old.blocks[j];
            final span = block.span();
            if (span != null && span.end < firstStart) {
                break;
            }
            StreamFade.textLeaves(block, previous);
            j--;
        }

        for (entry in affected) {
            final key = entry.key;
            final leaf = entry.leaf;
            final len = TextLeafTools.len(leaf);
            var prefix = 0;
            for (old in previous) {
                if (old.key.equals(key)) {
                    prefix = TextLeafTools.commonPrefixLen(leaf, old.leaf);
                    break;
                }
            }
            var leafSegments:Null<LeafSegments> = null;
            for (existing in segments) {
                if (existing.key.equals(key)) {
                    leafSegments = existing;
                    break;
                }
            }
            if (leafSegments == null) {
                leafSegments = new LeafSegments(key, []);
                segments.push(leafSegments);
            }
            // Text past the divergence is repainted, so its earlier fade no
            // longer describes what is on screen.
            final kept:Array<FadeSegment> = [];
            for (segment in leafSegments.segments) {
                final end = segment.range.end < prefix ? segment.range.end : prefix;
                segment.range = new Range(segment.range.start, end);
                if (segment.range.start < segment.range.end) kept.push(segment);
            }
            leafSegments.segments = kept;
            if (prefix >= len) {
                continue;
            }
            if (motion._streamFadeStagger == 0) {
                kept.push(new FadeSegment(new Range(prefix, len), now));
                continue;
            }
            final words = StreamFade.fadeUnits(TextLeafTools.chunks(leaf), prefix, len);
            final step = motion.staggerStep(words.length);
            for (ix in 0...words.length) {
                kept.push(new FadeSegment(words[ix], now + step * ix));
            }
        }
        segments = [for (leaf in segments) if (leaf.segments.length > 0) leaf];
    }

    /**
     * Samples every unfinished segment at `now`, dropping the finished ones.
     * `null` means nothing is fading, so no frame needs to follow.
     */
    public function frame(now:Float, reduceMotion:Bool):Null<StreamFadeFrame> {
        if (segments.length == 0) {
            return null;
        }
        if (reduceMotion || !isEnabled()) {
            segments = [];
            return null;
        }
        final timing = new Timing(motion._streamFade).ease(motion._streamFadeEasing);
        final leaves:Array<LeafFades> = [];
        final keptLeaves:Array<LeafSegments> = [];
        for (leaf in segments) {
            final fades:Array<RangedFade> = [];
            final kept:Array<FadeSegment> = [];
            for (segment in leaf.segments) {
                final elapsed = now - segment.startedAt;
                final sample = timing.sample(elapsed > 0 ? elapsed : 0);
                if (sample.finished) {
                    continue;
                }
                var fadeOut = 1.0 - sample.directedProgress;
                if (fadeOut < 0.0) fadeOut = 0.0;
                if (fadeOut > 1.0) fadeOut = 1.0;
                fades.push(new RangedFade(segment.range, fadeOut));
                kept.push(segment);
            }
            leaf.segments = kept;
            if (fades.length == 0) {
                continue;
            }
            leaves.push(new LeafFades(leaf.key, fades));
            keptLeaves.push(leaf);
        }
        segments = keptLeaves;
        return leaves.length > 0 ? new StreamFadeFrame(leaves) : null;
    }

}
