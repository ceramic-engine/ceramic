package ceramic;

import ceramic.Triangulate;

using ceramic.Extensions;

/**
 * A visual component that renders the Ceramic engine logo as a mesh.
 * 
 * The logo consists of:
 * - An elliptical top section representing a ceramic disc
 * - A curved bottom section with shadow and highlight layers
 * 
 * The logo is procedurally generated and can be customized with:
 * - Resolution: Controls the smoothness of curves
 * - Tilt: Adjusts the perspective of the ellipse
 * - Shadow size: Controls the shadow layer thickness
 * 
 * ```haxe
 * var logo = new CeramicLogo();
 * logo.size(224, 324); // Double the default size
 * logo.resolution = 2; // Higher quality curves
 * logo.tilt = 0.8; // Less tilted perspective
 * logo.shadowSize = 0.15; // Larger shadow
 * logo.pos(screen.width * 0.5, screen.height * 0.5);
 * logo.anchor(0.5, 0.5);
 * ```
 */
class CeramicLogo extends Mesh {

    /**
     * Number of vertices used for the ellipse section.
     * Used internally to track where the ellipse ends and bottom sections begin.
     */
    var numEllipseVertices:Int = 0;

    /**
     * Number of indices used for the ellipse section.
     * Used internally to track the ellipse mesh data.
     */
    var numEllipseIndices:Int = 0;

    /**
     * Tracks how much of the bottom section has been filled.
     * Used internally when building the shadow and highlight layers.
     */
    var filledBottom:Float = 0.0;

    /**
     * Bezier easing curve used for the bottom section curvature.
     * Creates the distinctive curved shape of the logo's bottom.
     */
    var curveEasing:BezierEasing = BezierEasing.get(0.71, 0.0, 1.0, 0.38);

    /**
     * Controls the quality/smoothness of the logo curves.
     * Higher values create more vertices for smoother curves.
     * 
     * Common values:
     * - 0.5: Low quality (faster rendering)
     * - 1.0: Normal quality (default)
     * - 2.0: High quality (smoother curves)
     */
    @content public var resolution:Float = 1.0;

    /**
     * Controls the perspective tilt of the top ellipse.
     * Lower values make the ellipse appear more flat/viewed from above.
     * 
     * Common values:
     * - 0.5: Very flat perspective
     * - 1.0: Normal perspective (default)
     * - 1.5: More tilted perspective
     */
    @content public var tilt:Float = 1.0;

    /**
     * The size of the shadow layer as a fraction of the logo width.
     * Controls how thick the gray shadow section appears.
     * 
     * Common values:
     * - 0.05: Thin shadow
     * - 0.1075: Normal shadow (default)
     * - 0.15: Thick shadow
     */
    @content public var shadowSize:Float = 0.1075;

    override function set_width(width:Float):Float {
        if (this.width != width) {
            super.set_width(width);
            contentDirty = true;
        }
        return width;
    }

    override function set_height(height:Float):Float {
        if (this.height != height) {
            super.set_height(height);
            contentDirty = true;
        }
        return height;
    }

    /**
     * Creates a new Ceramic logo mesh.
     * The logo is initialized with default size of 112x162 pixels.
     * Color mapping is set to INDICES for per-triangle coloring.
     */
    public function new() {

        super();

        colorMapping = INDICES;
        colors = [];

        size(112, 162);

    }

    /**
     * Generates the logo mesh geometry.
     * Called automatically when content is marked dirty (size, resolution, tilt, or shadowSize changes).
     * Builds the logo in three layers:
     * 1. Top ellipse (gray)
     * 2. Bottom section with shadow (lighter gray)
     * 3. Bottom section highlight (white)
     */
    override function computeContent() {

        if (width <= 0 || height <= 0) {
            return;
        }

        colors.setArrayLength(0);
        vertices.setArrayLength(0);
        indices.setArrayLength(0);
        filledBottom = 0;

        computeEllipse(0x888888);
        computeBottomSection(0xBEBEBE, shadowSize);
        computeBottomSection(0xFFFFFF, 1.0);

    }

    /**
     * Generates the elliptical top section of the logo.
     * Creates a filled ellipse using triangle fan technique.
     * 
     * @param color The color to apply to the ellipse triangles
     */
    function computeEllipse(color:Color) {

        final w:Float = width;

        final sides:Int = Math.floor(Math.ceil(w * 0.25 * resolution) / 2) * 2;
        final angleOffset:Float = Math.PI * 1.5;
        final sideLength:Float = Utils.degToRad(360) / sides;
        final _scaleX:Float = w * 0.5;
        final _scaleY:Float = w * 0.5 * 0.095 * tilt;

        vertices.push(_scaleX);
        vertices.push(_scaleY);

        for (i in 0...sides+1) {

            final rawX = Math.cos(Math.PI + sideLength * i);
            final rawY = Math.sin(Math.PI + sideLength * i);

            vertices.push((1.0 + rawX) * _scaleX);
            vertices.push((1.0 + rawY) * _scaleY);

            if (i > 0) {
                var n = i;
                indices.push(0);
                indices.push(n);
                indices.push(n + 1);
                colors.push(color);
                colors.push(color);
                colors.push(color);
            }

        }

        numEllipseVertices = Math.floor(vertices.length / 2);
        numEllipseIndices = indices.length;

    }

    /**
     * Generates a layer of the bottom section of the logo.
     * Creates a curved shape that connects to the ellipse and curves down to a point.
     * Called twice: once for the shadow layer and once for the highlight layer.
     * 
     * @param color The color to apply to this section
     * @param cut The horizontal cutoff point as a fraction of width (0-1).
     *            Used to create the layered shadow/highlight effect.
     */
    function computeBottomSection(color:Color, cut:Float) {

        final w:Float = width;
        final h:Float = height;

        final topY:Float = vertices[numEllipseVertices * 2 - 1];
        final leftX:Float = filledBottom * w;
        final rightX:Float = cut * w;

        var leftIndex0:Int = -1;
        var leftIndex1:Int = -1;
        var rightIndex0:Int = -1;
        var rightIndex1:Int = -1;

        var index:Int = numEllipseVertices * 2 - 2;
        while (index >= numEllipseVertices && vertices[index] < leftX) {
            index -= 2;
        }
        if (filledBottom == 0) {
            leftIndex0 = index;
            leftIndex1 = index - 2;
        }
        else {
            leftIndex0 = index + 2;
            leftIndex1 = index;
        }

        index = numEllipseVertices * 2 - 2;
        while (index >= numEllipseVertices && vertices[index] < rightX) {
            index -= 2;
        }
        if (cut == 1) {
            rightIndex0 = index;
            rightIndex1 = index - 2;
        }
        else {
            rightIndex0 = index + 2;
            rightIndex1 = index;
        }

        var leftY:Float = vertices[leftIndex0 + 1] + (vertices[leftIndex1 + 1] - vertices[leftIndex0 + 1]) * ((leftX - vertices[leftIndex0]) / (vertices[leftIndex1] - vertices[leftIndex0]));
        var rightY:Float = vertices[rightIndex0 + 1] + (vertices[rightIndex1 + 1] - vertices[rightIndex0 + 1]) * ((rightX - vertices[rightIndex0]) / (vertices[rightIndex1] - vertices[rightIndex0]));

        final bottomX:Float = 0.5 * w;
        final bottomY:Float = 1.0 * h;

        final curvedRatio:Float = 0.36 * (1.0 + (tilt - 1.0) * 0.1);
        final straightRatio:Float = 1.0 - curvedRatio;

        final straightHeight:Float = (bottomY - topY) * straightRatio;
        final leftCurvedStartY:Float = leftY + straightHeight;
        final rightCurvedStartY:Float = rightY + straightHeight;
        final leftCurvedHeight:Float = bottomY - leftCurvedStartY;
        final rightCurvedHeight:Float = bottomY - rightCurvedStartY;

        var n:Int = Math.floor(vertices.length / 2);

        vertices.push(leftX);
        vertices.push(leftY);

        var numVerticesBetween:Int = 0;
        index = leftIndex1;
        do {
            vertices.push(vertices[index]);
            vertices.push(vertices[index+1]);

            index -= 2;
            numVerticesBetween++;
        }
        while (index >= rightIndex0);

        vertices.push(rightX);
        vertices.push(rightY);

        vertices.push(rightX);
        vertices.push(rightCurvedStartY);

        vertices.push(leftX);
        vertices.push(leftCurvedStartY);

        var numIndicesBefore = indices.length;
        Triangulate.triangulate(vertices, n, numVerticesBetween + 4, indices);

        n = Math.floor(vertices.length / 2) - 2;

        for (i in 0...indices.length-numIndicesBefore) {
            colors.push(color);
        }

        final numYSteps:Int = Math.ceil(Math.max(leftCurvedHeight, rightCurvedHeight) * 0.35 * resolution);
        if (numYSteps > 0) {

            for (s in 0...numYSteps) {

                final stepRatio:Float = (s + 1.0) / numYSteps;
                final easedRatioY:Float = Utils.lerp(stepRatio, (1.0 - curveEasing.ease(1.0 - stepRatio)), 0.55);
                final stepLeftY:Float = leftCurvedStartY + leftCurvedHeight * easedRatioY;
                final stepRightY:Float = rightCurvedStartY + rightCurvedHeight * easedRatioY;

                if (s < numYSteps - 1) {

                    final easedX:Float = curveEasing.ease(easedRatioY);
                    final stepLeftX:Float = leftX + (bottomX - leftX) * easedX;
                    final stepRightX:Float = rightX + (bottomX - rightX) * easedX;

                    vertices.push(stepLeftX);
                    vertices.push(stepLeftY);

                    vertices.push(stepRightX);
                    vertices.push(stepRightY);

                    if (s == 0) {
                        indices.push(n + 1);
                        indices.push(n);
                        indices.push(n + 2);
                        indices.push(n + 2);
                        indices.push(n);
                        indices.push(n + 3);
                    }
                    else {
                        indices.push(n);
                        indices.push(n + 1);
                        indices.push(n + 2);
                        indices.push(n + 2);
                        indices.push(n + 1);
                        indices.push(n + 3);
                    }

                    n += 2;

                    for (i in 0...6) {
                        colors.push(color);
                    }
                }
                else {

                    vertices.push(bottomX);
                    vertices.push(Math.max(stepLeftY, stepRightY));

                    indices.push(n);
                    indices.push(n + 1);
                    indices.push(n + 2);

                    n += 2;

                    for (i in 0...3) {
                        colors.push(color);
                    }
                }

            }
        }

        filledBottom = cut;

    }

}
