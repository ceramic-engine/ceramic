package unityengine.rendering;

@:native('UnityEngine.Rendering.VertexAttributeDescriptor')
extern class VertexAttributeDescriptor {

    function new(attribute:VertexAttribute, format:VertexAttributeFormat, dimension:Int, stream:Int);

}