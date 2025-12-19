package sys.thread;

@:cxxStd
@:haxeStd
@:coreApi
@:nativeName("std::mutex", "Mutex")
@:include("mutex", true)
extern class Mutex {
	public function new();

	@:nativeName("lock")
	public function acquire(): Void;

	@:nativeName("try_lock")
	public function tryAcquire(): Bool;

	@:nativeName("unlock")
	public function release(): Void;
}
