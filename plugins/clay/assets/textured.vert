// ceramic: multiTexture

attribute vec3 vertexPosition;
attribute vec2 vertexTCoord;
attribute vec4 vertexColor;
// ceramic: multiTexture/vertexTextureId

varying vec2 tcoord;
varying vec4 color;
// ceramic: multiTexture/textureId

uniform mat4 projectionMatrix;
uniform mat4 modelViewMatrix;

void main(void) {

    gl_Position = projectionMatrix * modelViewMatrix * vec4(vertexPosition, 1.0);
    tcoord = vertexTCoord;
    color = vertexColor;
    // ceramic: multiTexture/assignTextureId
    gl_PointSize = 1.0;

}