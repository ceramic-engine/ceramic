package backend;

#if cpp
typedef ArrayBuffer = snow.api.buffers.ArrayBuffer;
#else
typedef ArrayBuffer = snow.api.buffers.Float32Array;
#end
