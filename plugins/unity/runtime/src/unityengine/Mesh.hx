package unityengine;

import unityengine.rendering.VertexAttributeDescriptor;
import unityengine.rendering.MeshUpdateFlags;
import unityengine.rendering.IndexFormat;
import unityengine.rendering.SubMeshDescriptor;

import cs.NativeArray;
import cs.types.UInt16;

@:native('UnityEngine.Mesh')
extern class Mesh extends Object {

    var subMeshCount:Int;

    function new();

    function SetVertexBufferParams(vertexCount:Int, attributes:NativeArray<VertexAttributeDescriptor>):Void;

    function SetVertexBufferData(data:NativeArray<Single>, dataStart:Int, meshBufferStart:Int, count:Int, stream:Int, flags:MeshUpdateFlags):Void;

    function SetIndexBufferParams(indexCount:Int, format:IndexFormat):Void;

    function SetIndexBufferData(data:NativeArray<UInt16>, dataStart:Int, meshBufferStart:Int, count:Int, flags:MeshUpdateFlags):Void;

    function SetSubMesh(index:Int, desc:SubMeshDescriptor, flags:MeshUpdateFlags):Void;

}