using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

/// <summary>
/// Memory-efficient command buffer that stores commands as data to be executed later on a real CommandBuffer.
/// Designed to match CommandBuffer API while avoiding GC pressure and boxing.
/// </summary>
public class CeramicCommandBuffer
{
    // Command types enum - using byte for memory efficiency
    private enum CommandType : byte
    {
        ClearRenderTarget,
        EnableScissorRect,
        DisableScissorRect,
        DrawMesh
    }

    // Command sequence - lightweight command descriptors
    private struct Command
    {
        public CommandType type;
        public int dataIndex; // Index into appropriate data array
    }

    // Data structures for each command type
    private struct ClearRenderTargetData
    {
        public bool clearDepth;
        public bool clearColor;
        public Color backgroundColor;
        public float depth;
    }

    private struct ScissorRectData
    {
        public Rect rect;
    }

    private struct DrawMeshData
    {
        public Mesh mesh;
        public Matrix4x4 matrix;
        public Material material;
    }

    // Command storage - separate arrays for each command type
    private List<Command> commands;
    private List<ClearRenderTargetData> clearRenderTargetCommands;
    private List<ScissorRectData> scissorRectCommands;
    private List<DrawMeshData> drawMeshCommands;

    // Pre-allocated capacity to reduce allocations
    private const int DefaultCapacity = 64;

    // Name for debugging purposes (like Unity's CommandBuffer.name)
    public string name { get; set; } = "";

    public CeramicCommandBuffer()
    {
        commands = new List<Command>(DefaultCapacity);
        clearRenderTargetCommands = new List<ClearRenderTargetData>(8);
        scissorRectCommands = new List<ScissorRectData>(16);
        drawMeshCommands = new List<DrawMeshData>(32);
    }

    // API Methods matching Unity's CommandBuffer

    /// <summary>
    /// Clear all stored commands
    /// </summary>
    public void Clear()
    {
        commands.Clear();
        clearRenderTargetCommands.Clear();
        scissorRectCommands.Clear();
        drawMeshCommands.Clear();
    }

    /// <summary>
    /// Add a ClearRenderTarget command
    /// </summary>
    public void ClearRenderTarget(bool clearDepth, bool clearColor, Color backgroundColor, float depth = 1.0f)
    {
        int dataIndex = clearRenderTargetCommands.Count;
        clearRenderTargetCommands.Add(new ClearRenderTargetData
        {
            clearDepth = clearDepth,
            clearColor = clearColor,
            backgroundColor = backgroundColor,
            depth = depth
        });
        commands.Add(new Command { type = CommandType.ClearRenderTarget, dataIndex = dataIndex });
    }

    /// <summary>
    /// Enable scissor rectangle
    /// </summary>
    public void EnableScissorRect(Rect rect)
    {
        int dataIndex = scissorRectCommands.Count;
        scissorRectCommands.Add(new ScissorRectData
        {
            rect = rect
        });
        commands.Add(new Command { type = CommandType.EnableScissorRect, dataIndex = dataIndex });
    }

    /// <summary>
    /// Disable scissor rectangle
    /// </summary>
    public void DisableScissorRect()
    {
        // No data needed for this command
        commands.Add(new Command { type = CommandType.DisableScissorRect, dataIndex = -1 });
    }

    /// <summary>
    /// Draw a mesh with transform and material
    /// </summary>
    public void DrawMesh(Mesh mesh, Matrix4x4 matrix, Material material)
    {
        int dataIndex = drawMeshCommands.Count;
        drawMeshCommands.Add(new DrawMeshData
        {
            mesh = mesh,
            matrix = matrix,
            material = material
        });
        commands.Add(new Command { type = CommandType.DrawMesh, dataIndex = dataIndex });
    }

    // Additional overloads that might be useful

    /// <summary>
    /// ClearRenderTarget with default depth
    /// </summary>
    public void ClearRenderTarget(bool clearDepth, bool clearColor, Color backgroundColor)
    {
        ClearRenderTarget(clearDepth, clearColor, backgroundColor, 1.0f);
    }

    /// <summary>
    /// Draw mesh with identity matrix
    /// </summary>
    public void DrawMesh(Mesh mesh, Material material)
    {
        DrawMesh(mesh, Matrix4x4.identity, material);
    }

    // Execution method

    /// <summary>
    /// Apply all stored commands on the provided CommandBuffer
    /// </summary>
    public void ApplyToCommandBuffer(CommandBuffer cmd)
    {
        for (int i = 0; i < commands.Count; i++)
        {
            var command = commands[i];
            switch (command.type)
            {
                case CommandType.ClearRenderTarget:
                    var clearCmd = clearRenderTargetCommands[command.dataIndex];
                    cmd.ClearRenderTarget(clearCmd.clearDepth, clearCmd.clearColor,
                                        clearCmd.backgroundColor, clearCmd.depth);
                    break;

                case CommandType.EnableScissorRect:
                    var scissorCmd = scissorRectCommands[command.dataIndex];
                    cmd.EnableScissorRect(scissorCmd.rect);
                    break;

                case CommandType.DisableScissorRect:
                    cmd.DisableScissorRect();
                    break;

                case CommandType.DrawMesh:
                    var drawCmd = drawMeshCommands[command.dataIndex];
                    if (drawCmd.mesh != null && drawCmd.material != null)
                    {
                        cmd.DrawMesh(drawCmd.mesh, drawCmd.matrix, drawCmd.material);
                    }
                    break;
            }
        }
    }

    /// <summary>
    /// Apply all stored commands on the provided RasterCommandBuffer
    /// </summary>
    public void ApplyToRasterCommandBuffer(RasterCommandBuffer cmd)
    {
        for (int i = 0; i < commands.Count; i++)
        {
            var command = commands[i];
            switch (command.type)
            {
                case CommandType.ClearRenderTarget:
                    var clearCmd = clearRenderTargetCommands[command.dataIndex];
                    cmd.ClearRenderTarget(clearCmd.clearDepth, clearCmd.clearColor,
                                        clearCmd.backgroundColor, clearCmd.depth);
                    break;

                case CommandType.EnableScissorRect:
                    var scissorCmd = scissorRectCommands[command.dataIndex];
                    cmd.EnableScissorRect(scissorCmd.rect);
                    break;

                case CommandType.DisableScissorRect:
                    cmd.DisableScissorRect();
                    break;

                case CommandType.DrawMesh:
                    var drawCmd = drawMeshCommands[command.dataIndex];
                    if (drawCmd.mesh != null && drawCmd.material != null)
                    {
                        cmd.DrawMesh(drawCmd.mesh, drawCmd.matrix, drawCmd.material);
                    }
                    break;
            }
        }
    }

    // Utility properties

    /// <summary>
    /// Number of commands stored
    /// </summary>
    public int CommandCount => commands.Count;

    /// <summary>
    /// Check if there are any commands to execute
    /// </summary>
    public bool HasCommands => commands.Count > 0;

    // Memory management helpers

    /// <summary>
    /// Trim excess capacity from internal arrays to reduce memory usage
    /// </summary>
    public void TrimExcess()
    {
        commands.TrimExcess();
        clearRenderTargetCommands.TrimExcess();
        scissorRectCommands.TrimExcess();
        drawMeshCommands.TrimExcess();
    }

    /// <summary>
    /// Ensure capacity for the specified number of commands to reduce allocations
    /// </summary>
    public void EnsureCapacity(int capacity)
    {
        if (commands.Capacity < capacity)
        {
            commands.Capacity = capacity;
        }
    }

    // Debug helpers

    /// <summary>
    /// Get a debug string representation of stored commands
    /// </summary>
    public string GetDebugString()
    {
        string bufferName = !string.IsNullOrEmpty(name) ? name : "Unnamed";

        if (commands.Count == 0)
            return $"CeramicCommandBuffer '{bufferName}': No commands";

        var sb = new System.Text.StringBuilder();
        sb.AppendLine($"CeramicCommandBuffer '{bufferName}': {commands.Count} commands");

        for (int i = 0; i < commands.Count; i++)
        {
            var cmd = commands[i];
            sb.AppendLine($"  {i}: {cmd.type}");
        }

        return sb.ToString();
    }

    /// <summary>
    /// String representation for debugging
    /// </summary>
    public override string ToString()
    {
        string bufferName = !string.IsNullOrEmpty(name) ? name : "Unnamed";
        return $"CeramicCommandBuffer '{bufferName}' ({commands.Count} commands)";
    }

    /// <summary>
    /// Get memory usage statistics
    /// </summary>
    public (int commandsMemory, int dataMemory, int totalMemory) GetMemoryUsage()
    {
        int commandsMemory = commands.Count * System.Runtime.InteropServices.Marshal.SizeOf<Command>();

        int dataMemory =
            clearRenderTargetCommands.Count * System.Runtime.InteropServices.Marshal.SizeOf<ClearRenderTargetData>() +
            scissorRectCommands.Count * System.Runtime.InteropServices.Marshal.SizeOf<ScissorRectData>() +
            drawMeshCommands.Count * System.Runtime.InteropServices.Marshal.SizeOf<DrawMeshData>();

        return (commandsMemory, dataMemory, commandsMemory + dataMemory);
    }
}

// Pooling system for CeramicCommandBuffers
public static class CeramicCommandBufferPool
{
    private static readonly Stack<CeramicCommandBuffer> pool = new Stack<CeramicCommandBuffer>();
    private static readonly object lockObject = new object();

    /// <summary>
    /// Get a CeramicCommandBuffer from the pool. If pool is empty, creates a new one.
    /// </summary>
    /// <param name="name">Optional name for debugging purposes</param>
    /// <returns>A cleared CeramicCommandBuffer ready for use</returns>
    public static CeramicCommandBuffer Get(string name = null)
    {
        CeramicCommandBuffer buffer;

        lock (lockObject)
        {
            if (pool.Count > 0)
            {
                buffer = pool.Pop();
            }
            else
            {
                buffer = new CeramicCommandBuffer();
            }
        }

        // Always clear the buffer when getting from pool
        buffer.Clear();
        buffer.name = name;

        return buffer;
    }

    /// <summary>
    /// Return a CeramicCommandBuffer to the pool for reuse
    /// </summary>
    /// <param name="buffer">The buffer to return to the pool</param>
    public static void Release(CeramicCommandBuffer buffer)
    {
        if (buffer == null)
            return;

        // Clear the buffer before returning to pool
        buffer.Clear();
        buffer.name = "";

        lock (lockObject)
        {
            pool.Push(buffer);
        }
    }

    /// <summary>
    /// Get the current size of the pool
    /// </summary>
    public static int PoolSize
    {
        get
        {
            lock (lockObject)
            {
                return pool.Count;
            }
        }
    }

    /// <summary>
    /// Clear all buffers from the pool (useful for cleanup)
    /// </summary>
    public static void ClearPool()
    {
        lock (lockObject)
        {
            pool.Clear();
        }
    }
}
