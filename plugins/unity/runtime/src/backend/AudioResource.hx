package backend;

#if documentation

typedef AudioResource = AudioResourceImpl;

#else

abstract AudioResource(AudioResourceImpl) from AudioResourceImpl to AudioResourceImpl {}

#end
