package unityengine.rendering;

@:native('UnityEngine.Rendering.SubMeshDescriptor')
extern class SubMeshDescriptor {

    function new(indexStart:Int, indexCount:Int, topology:MeshTopology);

}