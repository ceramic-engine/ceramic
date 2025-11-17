package ceramic;

#if cpp
typedef Float32 = cpp.Float32;
#elseif cs
typedef Float32 = Single;
#else
typedef Float32 = Float;
#end
