package clay;

#if clay_web
typedef IO = clay.web.WebIO;
#elseif clay_sdl
typedef IO = clay.sdl.SDLIO;
#end
