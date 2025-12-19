package haxe.atomic;

@:cxxStd
@:haxeStd
abstract AtomicInt(AtomicIntImpl) {
	public inline function new(value: Int): Void {
		this = new AtomicIntImpl(value);
	}

	public inline function add(b: Int): Int {
		return this.fetch_add(b);
	}

	public inline function sub(b: Int): Int {
		return this.fetch_sub(b);
	}

	public inline function and(b: Int): Int {
		return this.fetch_and(b);
	}

	public inline function or(b: Int): Int {
		return this.fetch_or(b);
	}

	public inline function xor(b: Int): Int {
		return this.fetch_xor(b);
	}

	public inline function compareExchange(expected: Int, replacement: Int): Int {
		return this.compareExchangeImpl(expected, replacement);
	}

	public inline function exchange(value: Int): Int {
		return this.exchange(value);
	}

	public inline function load(): Int {
		return this.load();
	}

	public inline function store(value: Int): Int {
		return this.storeImpl(value);
	}
}

@:cxxStd
@:noHaxeNamespaces
@:nativeName("std::atomic<int>", "AtomicIntImpl")
@:include("atomic", true)
private extern class AtomicIntImpl {
	public function new(value: Int);

	public function fetch_add(b: Int): Int;
	public function fetch_sub(b: Int): Int;
	public function fetch_and(b: Int): Int;
	public function fetch_or(b: Int): Int;
	public function fetch_xor(b: Int): Int;

	@:nativeFunctionCode("([&]() { int _expected = {arg0}; {this}.compare_exchange_strong(_expected, {arg1}); return _expected; })()")
	public function compareExchangeImpl(expected: Int, replacement: Int): Int;

	public function exchange(value: Int): Int;
	public function load(): Int;

	@:nativeFunctionCode("({this}.store({arg0}), {arg0})")
	public function storeImpl(value: Int): Int;
}
