package ceramic;

using ceramic.Extensions;

/**
 * Convenience mesh subclass to draw arc, pie, ring or disc geometry
 * Ring: Angle `360`
 * Pie Segment: Radius and Thickness are `equal` - Border Position: `INSIDE`
 * Circle: Angle `360` - Radius and Thickness are `equal` - Border Position: `INSIDE`
 */
@editable({ implicitSize: true })
class Arc extends Mesh {

    /**
     * Number of sides. Higher is smoother but needs more vertices
     */
    @editable({ slider: [3, 100] })
    public var sides(default,set):Int = 32;
    inline function set_sides(sides:Int):Int {
        if (this.sides == sides) return sides;
        this.sides = sides;
        contentDirty = true;
        return sides;
    }

    /**
     * Radius of the arc
     */
    @editable({ slider: [0, 999] })
    public var radius(default,set):Float = 64;
    function set_radius(radius:Float):Float {
        if (this.radius == radius) return radius;
        this.radius = radius;
        contentDirty = true;
        return radius;
    }

    /**
     * Angle (from 0 to 360). 360 will make it draw a full circle/ring
     */
    @editable({ slider: [0, 360] })
    public var angle(default,set):Float = 270;
    function set_angle(angle:Float):Float {
        if (this.angle == angle) return angle;
        this.angle = angle;
        contentDirty = true;
        return angle;
    }

    /**
     * Position of the drawn border
     */
    @editable
    public var borderPosition(default,set):BorderPosition = MIDDLE;
    inline function set_borderPosition(borderPosition:BorderPosition):BorderPosition {
        if (this.borderPosition == borderPosition) return borderPosition;
        this.borderPosition = borderPosition;
        contentDirty = true;
        return borderPosition;
    }

    /**
     * Thickness of the arc. If same value as radius and borderPosition is `INSIDE`, will draw a pie.
     */
    @editable({ slider: [1, 120] })
    public var thickness(default,set):Float = 16;
    function set_thickness(thickness:Float):Float {
        if (this.thickness == thickness) return thickness;
        this.thickness = thickness;
        contentDirty = true;
        return thickness;
    }

    public function new() {

        super();

        anchor(0.5, 0.5);

    }

    override function computeContent() {

        inline MeshExtensions.createArc(this, radius, angle, thickness, sides, borderPosition);

        contentDirty = false;

    }

#if editor

/// Editor

    public static function editorSetupEntity(entityData:editor.model.EditorEntityData) {

        entityData.props.set('anchorX', 0.5);
        entityData.props.set('anchorY', 0.5);
        entityData.props.set('sides', 32);
        entityData.props.set('radius', 64);
        entityData.props.set('angle', 270);

    }

#end

}
