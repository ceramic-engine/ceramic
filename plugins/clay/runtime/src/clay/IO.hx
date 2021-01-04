package clay;

#if clay_web
typedef IO = clay.io.WebIO;
#elseif clay_sdl
typedef IO = clay.io.SdlIO;
#end
