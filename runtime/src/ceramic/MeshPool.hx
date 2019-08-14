package ceramic;

using ceramic.Extensions;

/** An utility to reuse meshes at application level. */
class MeshPool {

    static var availableMeshes:Array<Mesh> = [];

    /** Get or create a mesh. The mesh is active an ready to be displayed. */
    public static function get():Mesh {

        return new Mesh();
/*
        if (availableMeshes.length > 0) {
            var mesh = availableMeshes.pop();
            mesh.active = true;
            if (mesh.indices == null) mesh.indices = [];
            if (mesh.vertices == null) mesh.vertices = [];
            if (mesh.colors == null) mesh.colors = [];
            return mesh;
        }
        else {
            return new Mesh();
        }*/

    } //get

    /** Recycle an existing mesh. The mesh will be cleaned up and marked as inactive (e.g. not displayed) */
    public static function recycle(mesh:Mesh):Void {

        mesh.destroy();
        return;
        /*

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
        mesh.blending = Blending.NORMAL;
        mesh.shader = null;

        #if ceramic_no_depth_range
        mesh.depthRange = -1;
        #else
        mesh.depthRange = 1;
        #end

#if ceramic_debug_rendering_option
        mesh.debugRendering = DebugRendering.DEFAULT;
#end

        if (mesh.indices != null && mesh.indices.length > 0) {
            #if cpp
            untyped mesh.indices.__SetSize(0);
            #else
            mesh.indices.splice(0, mesh.indices.length);
            #end
        }

        if (mesh.vertices != null && mesh.vertices.length > 0) {
            #if cpp
            untyped mesh.vertices.__SetSize(0);
            #else
            mesh.vertices.splice(0, mesh.vertices.length);
            #end
        }

        if (mesh.colors != null && mesh.colors.length > 0) {
            #if cpp
            untyped mesh.colors.__SetSize(0);
            #else
            mesh.colors.splice(0, mesh.colors.length);
            #end
        }

        mesh.offPointerDown();
        mesh.offPointerUp();
        mesh.offPointerOver();
        mesh.offPointerOut();
        mesh.offFocus();
        mesh.offBlur();

        availableMeshes.push(mesh);*/

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
