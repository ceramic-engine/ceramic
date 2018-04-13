attribute vec3 vertexPosition;
attribute vec2 vertexTCoord;
attribute vec4 vertexColor;
attribute vec4 vertexDarkColor;

varying vec2 tcoord;
varying vec4 color;
varying vec4 darkColor;

uniform mat4 projectionMatrix;
uniform mat4 modelViewMatrix;

void main(void) {

    gl_Position = projectionMatrix * modelViewMatrix * vec4(vertexPosition, 1.0);
    tcoord = vertexTCoord;
    color = vertexColor;
    darkColor = vertexDarkColor;
    gl_PointSize = 1.0;

}