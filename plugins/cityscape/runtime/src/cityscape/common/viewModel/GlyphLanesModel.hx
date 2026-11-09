// Ported from vscode src/vs/editor/common/viewModel/glyphLanesModel.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.viewModel;

import cityscape.common.Model.GlyphMarginLane;
import cityscape.common.Model.IGlyphMarginLanesModel;
import cityscape.common.core.Range;
import haxe.ds.Vector;

class GlyphMarginLanesModel implements IGlyphMarginLanesModel {

    static inline final MAX_LANE = 3; // GlyphMarginLane.Right

    var lanes:Vector<Int>;
    var persist = 0;
    var _requiredLanes = 1; // always render at least one lane

    public function new(maxLine:Int) {
        this.lanes = newBytes(Math.ceil(((maxLine + 1) * MAX_LANE) / 8));
    }

    static function newBytes(length:Int):Vector<Int> {
        final v = new Vector<Int>(length);
        for (i in 0...length) {
            v[i] = 0;
        }
        return v;
    }

    public function reset(maxLine:Int):Void {
        final bytes = Math.ceil(((maxLine + 1) * MAX_LANE) / 8);
        if (this.lanes.length < bytes) {
            this.lanes = newBytes(bytes);
        } else {
            for (i in 0...this.lanes.length) {
                this.lanes[i] = 0;
            }
        }
        this._requiredLanes = 1;
    }

    public var requiredLanes(get, never):Int;
    function get_requiredLanes():Int {
        return this._requiredLanes;
    }

    public function push(lane:GlyphMarginLane, range:Range, ?persist:Bool):Void {
        if (persist == true) {
            this.persist |= (1 << ((lane : Int) - 1));
        }
        for (i in range.startLineNumber...range.endLineNumber + 1) {
            final bit = (MAX_LANE * i) + ((lane : Int) - 1);
            this.lanes[bit >>> 3] = (this.lanes[bit >>> 3] | (1 << (bit % 8))) & 0xFF;
            final count = this.countAtLine(i);
            if (count > this._requiredLanes) {
                this._requiredLanes = count;
            }
        }
    }

    public function getLanesAtLine(lineNumber:Int):Array<GlyphMarginLane> {
        final lanes:Array<GlyphMarginLane> = [];
        var bit = MAX_LANE * lineNumber;
        for (i in 0...MAX_LANE) {
            if ((this.persist & (1 << i)) != 0 || (this.lanes[bit >>> 3] & (1 << (bit % 8))) != 0) {
                lanes.push(i + 1);
            }
            bit++;
        }

        return lanes.length > 0 ? lanes : [GlyphMarginLane.Center];
    }

    function countAtLine(lineNumber:Int):Int {
        var bit = MAX_LANE * lineNumber;
        var count = 0;
        for (i in 0...MAX_LANE) {
            if ((this.persist & (1 << i)) != 0 || (this.lanes[bit >>> 3] & (1 << (bit % 8))) != 0) {
                count++;
            }
            bit++;
        }
        return count;
    }

}
