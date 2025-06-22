package backend;

@:native('CeramicCommandBufferPool')
extern class CeramicCommandBufferPool {

    static function Get():CeramicCommandBuffer;

    static function Release(cmd:CeramicCommandBuffer):Void;

}
