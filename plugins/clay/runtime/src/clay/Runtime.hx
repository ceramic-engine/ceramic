package clay;

#if clay_web
typedef Runtime = clay.runtime.WebRuntime;
#elseif clay_sdl
typedef Runtime = clay.runtime.SdlRuntime;
#end
