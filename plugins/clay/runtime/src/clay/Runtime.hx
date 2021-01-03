package clay;

#if clay_web
typedef Runtime = clay.runtime.web.WebRuntime;
#elseif clay_native
typedef Runtime = clay.runtime.native.NativeRuntime;
#end
