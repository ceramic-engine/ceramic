package clay;

#if clay_web
typedef Runtime = clay.web.WebRuntime;
#elseif clay_sdl
typedef Runtime = clay.sdl.SDLRuntime;
#end
