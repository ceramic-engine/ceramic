attribute vec3 vertexPosition;
attribute vec2 vertexTCoord;
attribute vec4 vertexColor;

varying vec2 tcoord;
varying vec4 color;
varying float tflag;

uniform mat4 projectionMatrix;
uniform mat4 modelViewMatrix;

void main(void) {

    gl_Position = projectionMatrix * modelViewMatrix * vec4(vertexPosition.xy, 0.0, 1.0);
    tcoord = vertexTCoord;
    color = vertexColor;
    tflag = vertexPosition.z;
    gl_PointSize = 1.0;

}