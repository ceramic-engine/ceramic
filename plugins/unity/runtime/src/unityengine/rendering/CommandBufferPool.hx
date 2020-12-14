package unityengine.rendering;

@:native('UnityEngine.Rendering.CommandBufferPool')
extern class CommandBufferPool {

    static function Get():CommandBuffer;

    static function Release(cmd:CommandBuffer):Void;

}
