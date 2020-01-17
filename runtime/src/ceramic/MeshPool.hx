package ceramic;

using ceramic.Extensions;

/** An utility to reuse meshes at application level. */
class MeshPool {

    static var availableMeshes:Array<Mesh> = [];

    static var availableFloatArrays:Array<Array<Float>> = [];
    static var availableIntArrays:Array<Array<Int>> = [];

    @:noCompletion inline static public function getIntArray():Array<Int> {

        return availableIntArrays.length > 0 ? availableIntArrays.pop() : [];

    } //getIntArray

    @:noCompletion inline static public function getFloatArray():Array<Float> {

        return availableFloatArrays.length > 0 ? availableFloatArrays.pop() : [];

    } //getFloatArray

    @:noCompletion inline static public function recycleIntArray(array:Array<Int>):Void {

        if (array != null) {
            if (array.length > 0) {
                #if cpp
                untyped array.__SetSize(0);
                #else
                array.splice(0, array.length);
                #end
            }
            availableIntArrays.push(array);
        }

    } //recycleIntArray

    @:noCompletion inline static public function recycleFloatArray(array:Array<Float>):Void {

        if (array != null) {
            if (array.length > 0) {
                #if cpp
                untyped array.__SetSize(0);
                #else
                array.splice(0, array.length);
                #end
            }
            availableFloatArrays.push(array);
        }

    } //recycleIntArray

    /** Get or create a mesh. The mesh is active an ready to be displayed. */
    public static function get():Mesh {

        if (availableMeshes.length > 0) {
            var mesh = availableMeshes.pop();
            mesh.active = true;
            mesh.visible = true;
            mesh.touchable = true;
            mesh.indices = getIntArray();
            mesh.vertices = getFloatArray();
            mesh.colors = getIntArray();
            mesh.uvs = getFloatArray();
            return mesh;
        }
        else {
            return new Mesh();
        }

    } //get

    /** Recycle an existing mesh. The mesh will be cleaned up and marked as inactive (e.g. not displayed) */
    public static function recycle(mesh:Mesh):Void {

        mesh.clear();

        if (mesh.parent != null) {
            mesh.parent.remove(mesh);
        }

        mesh.pos(0, 0);
        mesh.scale(1, 1);
        mesh.anchor(0, 0);
        mesh.skew(0, 0);
        mesh._width = 0;
        mesh._height = 0;
        mesh.transform = null;
        mesh.rotation = 0;
        mesh.visible = true;
        mesh.touchable = true;
        mesh.active = false;
        mesh.renderTarget = null;
        mesh.texture = null;
        mesh.multiTouch = false;
        mesh._numPointerDown = 0;
        mesh._numPointerOver = 0;
        mesh.clip = null;
        mesh.inheritAlpha = false;
        mesh.alpha = 1;
        mesh.blending = Blending.AUTO;
        mesh.shader = null;
        mesh.customFloatAttributesSize = 0;

        #if ceramic_no_depth_range
        mesh.depthRange = -1;
        #else
        mesh.depthRange = 1;
        #end

#if ceramic_debug_rendering_option
        mesh.debugRendering = DebugRendering.DEFAULT;
#end

        recycleIntArray(mesh.indices);
        recycleFloatArray(mesh.vertices);
        recycleIntArray(mesh.colors);
        recycleFloatArray(mesh.uvs);

        mesh.indices = null;
        mesh.vertices = null;
        mesh.colors = null;
        mesh.uvs = null;

        mesh.offPointerDown();
        mesh.offPointerUp();
        mesh.offPointerOver();
        mesh.offPointerOut();
        mesh.offFocus();
        mesh.offBlur();

        availableMeshes.push(mesh);

    } //recycle

    public static function clear():Void {
        
        if (availableMeshes.length > 0) {
            var prevAvailable = availableMeshes;
            availableMeshes = [];
            for (i in 0...prevAvailable.length) {
                prevAvailable.unsafeGet(i).destroy();
            }
        }

    } //clear

} //MeshPool