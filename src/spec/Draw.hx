package spec;

import backend.Draw;

interface Draw {

    function drawQuad(quad:ceramic.Quad):Void;

    function drawMesh(mesh:ceramic.Mesh):Void;

    function drawText(text:ceramic.Text):Void;

    function drawGraphics(graphics:ceramic.Graphics):Void;

} //Draw
