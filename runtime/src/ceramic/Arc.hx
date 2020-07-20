package ceramic;

using ceramic.Extensions;

@editable({ implicitSize: true })
class Arc extends Mesh {

    @editable({ slider: [3, 100] })
    public var sides(default,set):Int = 32;
    inline function set_sides(sides:Int):Int {
        if (this.sides == sides) return sides;
        this.sides = sides;
        contentDirty = true;
        return sides;
    }

    @editable({ slider: [0, 999] })
    public var radius(default,set):Float = 64;
    function set_radius(radius:Float):Float {
        if (this.radius == radius) return radius;
        this.radius = radius;
        contentDirty = true;
        return radius;
    }

    @editable({ slider: [0, 360] })
    public var angle(default,set):Float = 270;
    function set_angle(angle:Float):Float {
        if (this.angle == angle) return angle;
        this.angle = angle;
        contentDirty = true;
        return angle;
    }

    @editable
    public var borderPosition(default,set):BorderPosition = MIDDLE;
    inline function set_borderPosition(borderPosition:BorderPosition):BorderPosition {
        if (this.borderPosition == borderPosition) return borderPosition;
        this.borderPosition = borderPosition;
        contentDirty = true;
        return borderPosition;
    }

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

        var count:Int = Math.ceil(sides * angle / 360);

        width = radius * 2;
        height = radius * 2;

        vertices.setArrayLength(0);
        indices.setArrayLength(0);

        var _x:Float;
        var _y:Float;

        var angleOffset:Float = Math.PI * 1.5;
        var sidesOverTwoPi:Float = Utils.degToRad(angle) / count;

        var borderStart:Float = switch borderPosition {
            case INSIDE: -thickness;
            case OUTSIDE: 0;
            case MIDDLE: -thickness * 0.5;
        }
        var borderEnd:Float = switch borderPosition {
            case INSIDE: 0;
            case OUTSIDE: thickness;
            case MIDDLE: thickness * 0.5;
        }

        for (i in 0...count+1) {

            var rawX = Math.cos(angleOffset + sidesOverTwoPi * i);
            var rawY = Math.sin(angleOffset + sidesOverTwoPi * i);

            _x = (radius + borderStart) * rawX;
            _y = (radius + borderStart) * rawY;

            vertices.push(radius + _x);
            vertices.push(radius + _y);

            _x = (radius + borderEnd) * rawX;
            _y = (radius + borderEnd) * rawY;

            vertices.push(radius + _x);
            vertices.push(radius + _y);

            if (i > 0) {
                var n = (i - 1) * 2;
                indices.push(n);
                indices.push(n + 1);
                indices.push(n + 2);
                indices.push(n + 1);
                indices.push(n + 2);
                indices.push(n + 3);
            }

        }

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
