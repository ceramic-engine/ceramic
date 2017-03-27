package backend;

abstract QuadInfo(phoenix.geometry.QuadGeometry) from phoenix.geometry.QuadGeometry to phoenix.geometry.QuadGeometry {}

abstract MeshInfo(phoenix.geometry.Geometry) from phoenix.geometry.Geometry to phoenix.geometry.Geometry {}

abstract TextInfo(Bool) from Bool to Bool {}

abstract GraphicsInfo(Bool) from Bool to Bool {}

class Draw implements spec.Draw {

    public function new() {}

    inline public function drawQuad(quad:ceramic.Quad):Void {}

    inline public function drawMesh(mesh:ceramic.Mesh):Void {}

    inline public function drawText(text:ceramic.Text):Void {}

    inline public function drawGraphics(graphics:ceramic.Graphics):Void {}

} //Draw
