package ceramic;

// Original: https://github.com/HaxeFlixel/flixel/tree/43a3895d9479f8fdff9296637ef4fab25c473ecb/flixel/util/typeLimit

/**
 * Useful to limit a Dynamic function argument's type to the specified
 * type parameters. This does NOT make the use of Dynamic type-safe in
 * any way (the underlying type is still Dynamic and Std.is() checks +
 * casts are necessary).
 */
abstract Either<T1, T2>(Dynamic) from T1 from T2 to T1 to T2 {}
