package ceramic;

import tracker.Observable;

using ceramic.Extensions;

@editable({
    highlight: {
        points: 'points',
        minPoints: 2,
        maxPoints: 999999999
    }
})
class Points extends Visual {

    /** An array of floats to describe points */
    @editable public var points(default, set):Array<Float> = [];
    inline function set_points(points:Array<Float>):Array<Float> {
        this.points = points;
        contentDirty = true;
        return points;
    }

    /** If set to `true`, width and heigh will be computed from shape points. */
    @editable({ label: 'Auto Size' })
    public var autoComputeSize(default, set):Bool = true;
    inline function set_autoComputeSize(autoComputeSize:Bool):Bool {
        if (this.autoComputeSize == autoComputeSize) return autoComputeSize;
        this.autoComputeSize = autoComputeSize;
        if (autoComputeSize)
            computeSize();
        return autoComputeSize;
    }

    function computeSize() {

        if (points != null && points.length >= 2) {
            var maxX:Float = 0;
            var maxY:Float = 0;
            var i = 0;
            var lenMinus1 = points.length - 1;
            while (i < lenMinus1) {
                var x = points.unsafeGet(i);
                if (x > maxX)
                    maxX = x;
                i++;
                var y = points.unsafeGet(i);
                if (y > maxY)
                    maxY = y;
                i++;
            }
            size(maxX, maxY);
        }
        else {
            size(0, 0);
        }

    }

    override function computeContent() {

        if (autoComputeSize)
            computeSize();

        contentDirty = false;

    }

#if editor

/// Editor

    public static function editorSetupEntity(entityData:editor.model.EditorEntityData) {

        entityData.props.set('anchorX', 0);
        entityData.props.set('anchorY', 0);
        entityData.props.set('points', [
            0.0, 0.0,
            100.0, 0.0
        ]);

    }

#end

}
