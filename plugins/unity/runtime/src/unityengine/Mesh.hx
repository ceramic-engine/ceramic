package unityengine;

import unityengine.rendering.VertexAttributeDescriptor;
import unityengine.rendering.MeshUpdateFlags;
import unityengine.rendering.IndexFormat;
import unityengine.rendering.SubMeshDescriptor;

import cs.NativeArray;
import cs.types.UInt16;

/**
 * Represents 3D geometry data for rendering.
 * Meshes contain vertex positions, normals, UVs, colors, and triangle indices.
 * 
 * In Ceramic's Unity backend, Meshes are used for efficient batch rendering
 * of 2D sprites and shapes. The backend dynamically builds meshes from
 * Ceramic's visual elements for optimal GPU performance.
 * 
 * Key components:
 * - Vertex buffer: Per-vertex data (position, UV, color, etc.)
 * - Index buffer: Triangle definitions referencing vertices
 * - SubMeshes: Separate sections for different materials
 * 
 * Modern Unity mesh API features:
 * - Direct buffer access for performance
 * - Multiple vertex streams
 * - 32-bit index support for large meshes
 * - Efficient update flags
 * 
 * @see MeshTopology
 * @see VertexAttributeDescriptor
 */
@:native('UnityEngine.Mesh')
extern class Mesh extends Object {

    /**
     * Number of sub-meshes in this mesh.
     * Each sub-mesh can use a different material.
     * 
     * Ceramic typically uses one sub-mesh per draw call,
     * allowing batching of similar visuals.
     */
    var subMeshCount:Int;

    /**
     * Creates a new empty Mesh.
     * Must set vertex and index data before use.
     * 
     * @example Creating a simple quad:
     * ```haxe
     * var mesh = new Mesh();
     * mesh.SetVertexBufferParams(4, vertexLayout);
     * // Set vertices...
     * mesh.SetIndexBufferParams(6, IndexFormat.UInt16);
     * // Set indices...
     * ```
     */
    function new();

    /**
     * Defines the vertex buffer layout and size.
     * Must be called before setting vertex data.
     * 
     * @param vertexCount Total number of vertices
     * @param attributes Array defining vertex data layout:
     *                  - Position (Vector3)
     *                  - UV coordinates (Vector2)
     *                  - Color (Color32)
     *                  - Normal (Vector3)
     *                  etc.
     * 
     * This configures how vertex data is interpreted by shaders.
     */
    function SetVertexBufferParams(vertexCount:Int, attributes:NativeArray<VertexAttributeDescriptor>):Void;

    /**
     * Uploads vertex data to the GPU.
     * Data must match the layout from SetVertexBufferParams.
     * 
     * @param data Source array of vertex data (interleaved floats)
     * @param dataStart Starting index in source array
     * @param meshBufferStart Starting vertex index in mesh
     * @param count Number of floats to copy
     * @param stream Vertex stream index (0 for main stream)
     * @param flags Update behavior:
     *              - Default: Normal update
     *              - DontValidateIndices: Skip validation for performance
     *              - DontResetBoneBounds: Preserve skeletal bounds
     * 
     * For Ceramic, this typically contains position, UV, and color data.
     */
    function SetVertexBufferData(data:NativeArray<Single>, dataStart:Int, meshBufferStart:Int, count:Int, stream:Int, flags:MeshUpdateFlags):Void;

    /**
     * Defines the index buffer size and format.
     * Must be called before setting index data.
     * 
     * @param indexCount Total number of indices (3 per triangle)
     * @param format Index data type:
     *               - UInt16: 16-bit indices (max 65k vertices)
     *               - UInt32: 32-bit indices (max 4B vertices)
     * 
     * Ceramic uses UInt16 for most cases as meshes are rebuilt frequently.
     */
    function SetIndexBufferParams(indexCount:Int, format:IndexFormat):Void;

    /**
     * Uploads triangle index data to the GPU.
     * Defines which vertices form triangles.
     * 
     * @param data Source array of indices (triangle vertex references)
     * @param dataStart Starting index in source array  
     * @param meshBufferStart Starting index in mesh buffer
     * @param count Number of indices to copy
     * @param flags Update behavior flags
     * 
     * Indices should be in groups of 3 for triangle topology.
     * Winding order affects face culling (clockwise = front).
     */
    function SetIndexBufferData(data:NativeArray<UInt16>, dataStart:Int, meshBufferStart:Int, count:Int, flags:MeshUpdateFlags):Void;

    /**
     * Defines a sub-mesh within the mesh.
     * Each sub-mesh can render with a different material.
     * 
     * @param index Sub-mesh index (0 to subMeshCount-1)
     * @param desc Sub-mesh definition:
     *             - indexStart: First index in buffer
     *             - indexCount: Number of indices
     *             - topology: Usually MeshTopology.Triangles
     * @param flags Update behavior flags
     * 
     * Ceramic uses sub-meshes to batch visuals by texture/shader.
     */
    function SetSubMesh(index:Int, desc:SubMeshDescriptor, flags:MeshUpdateFlags):Void;

}