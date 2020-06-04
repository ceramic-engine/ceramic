package ceramic;

import tracker.Observable;

@editable({
    highlight: {
        points: 'points',
        minPoints: 2,
        maxPoints: 999999999
    }
})
class Points extends Visual implements Observable {

    /** An array of floats to describe points */
    @editable public var points:Array<Float> = [];

#if editor

/// Editor

    public static function editorSetupEntity(entityData:editor.model.EditorEntityData) {

        entityData.props.set('width', 0);
        entityData.props.set('height', 0);
        entityData.props.set('anchorX', 0);
        entityData.props.set('anchorY', 0);
        entityData.props.set('points', [
            0.0, 0.0,
            100.0, 0.0
        ]);

    }

#end

}
