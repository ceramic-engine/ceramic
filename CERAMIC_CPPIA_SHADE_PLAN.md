# Plan — Shaders shade (et worklets audio) dans le mode cppia

## Contexte

En mode cppia (`--cppia`), le code projet est compilé en bytecode CLIENT, le
moteur reste natif dans le HOST. Or les shaders shade d'un projet sont des
classes Haxe (`src/**/shaders/*.hx`) transpilées en GLSL par une macro qui
tourne pendant la compile **host**. Comme ces classes vivent dans le CLIENT en
mode cppia, elles ne sont jamais transpilées → les fichiers `*_shaders_*.frag/.vert`
manquent du bundle → null reference en jeu (constaté sur zenith :
`Failed to load asset zenith_shaders_lightingChannels`, puis crash LevelScene).

Les shaders **du moteur** (textured/msdf/pixelArt), eux, fonctionnent : ils sont
dans le host, donc transpilés normalement.

C'est la même classe de problème que les **audio worklets custom** (artefacts
transpilés spécifiques au projet, générés à la compile) — déjà documentée comme
limitation. Ce plan traite shade (le blocage réel de zenith) et pose le même
schéma pour les worklets.

## Mécanique actuelle (vérifiée)

- `ClayBuild.hx:251-252` : la compile principale (= HOST en cppia) reçoit
  `--macro shade.macros.ShadeMacro.initRegister(<outTargetPath>)`.
- `ShadeMacro.initRegister` (shade) : pose un `Context.onAfterGenerate` qui
  écrit `<outTargetPath>/shade/info.json` = liste des shaders vus pendant CETTE
  compile (peuplée par le `@:genericBuild` de `shade.Shader<V,F>`).
- `ClayBuild.hx:562-644` : après la compile, lit `shade/info.json`, dédoublonne
  par hash, lance la task `shade` (`--in <fichier.hx> --target glsl --out
  shade/glsl`) + variante instanced, gère un skip par comparaison
  `prev-info.json`.
- `copyTranspiledShadersToPlatformAssets()` (`:178-199`) : copie tout
  `shade/glsl/*` dans les assets de la plateforme. Déjà appelée aussi quand la
  compile haxe est skippée.

En cppia, la compile CLIENT (`ClayBuild.hx:698-708`, `clientArgs`) n'a NI le
`--macro initRegister`, NI de passe de transpilation → shaders projet perdus.

## Modification

### 1. Compile client : collecter les shaders projet
Dans le bloc client cppia (`clientArgs`), ajouter le macro shade pointant vers
un dossier séparé pour ne pas écraser le `shade/info.json` du host :
```haxe
clientArgs.push('--macro');
clientArgs.push('shade.macros.ShadeMacro.initRegister(' +
    Json.stringify(Path.join([outTargetPath, 'shade-cppia'])) + ')');
```
→ écrit `shade-cppia/info.json` (shaders du projet uniquement).

### 2. Refactor : extraire la transpilation en fonction réutilisable
Sortir le bloc `:562-644` en une fonction locale
`transpileShadersFromInfos(infoPaths:Array<String>)` qui :
- lit chaque `info.json` fourni, **unionne** les `shaders[]` par hash
  (dé-duplication déjà présente, juste étendue à plusieurs sources) ;
- garde la même task `shade` (une passe standard + une passe instanced) vers
  `shade/glsl` ;
- garde le skip par `prev-info.json`, mais la clé de comparaison devient
  l'union (host + client), pour que changer un shader projet réinvalide bien.

Le nom des fichiers GLSL vient du nom de la classe shader → engine et projet ne
collisionnent pas dans `shade/glsl`. Une seule passe = pas de
`deleteRecursive(glsl)` qui effacerait la moitié de l'autre.

### 3. Câblage des deux chemins
- **Build normal** (non-cppia) : `transpileShadersFromInfos(['shade/info.json'])`
  — comportement inchangé.
- **Build cppia** : après une compile client réussie,
  `transpileShadersFromInfos(['shade/info.json', 'shade-cppia/info.json'])`
  puis `copyTranspiledShadersToPlatformAssets()`.
  (Le host cppia continue d'écrire son `shade/info.json` pour les shaders
  moteur.)

### 4. Skip / fraîcheur
La passe de transpilation ne tourne en cppia que si le client a été recompilé
(déjà géré par `mustCompileClient`) OU si `shade/glsl` est absent. Réutiliser la
comparaison `prev-info.json` sur l'union pour éviter une transpilation inutile
quand rien n'a changé.

### 5. Audio worklets (même schéma, en parallèle)
`AudioFiltersMacro.init()` (`ClayBuild.hx:258-259`) a exactement le même
couplage. À traiter pareil : macro sur la compile client + collecte/transpile
worklets depuis le client. **Hors périmètre immédiat** (zenith ne semble pas
utiliser de worklet custom) — documenté ici pour la cohérence ; à activer si un
projet cppia en a besoin. Ne PAS régresser le chemin natif.

## Points de vigilance
- Le path pur C++/HXCPP et le build natif ne doivent pas changer de
  comportement (seul le branchement `cppiaFlag` ajoute des étapes).
- La task `shade` est indépendante de cppia (elle transpile des `.hx` shader en
  GLSL) : rien à changer côté plugin shade.
- Vérifier les shaders **instanced** (`#if shade_instanced`) : la passe projet
  doit produire les variantes `_inst` comme la passe moteur.
- Le `@:genericBuild` du shader tourne bien pendant la compile client puisque le
  code client référence les shaders (zenith : LevelScene) — à confirmer au 1er run.

## Vérification
1. `ceramic clay run mac --cppia` sur **zenith** : plus de
   `Failed to load asset zenith_shaders_*`, l'app atteint le gameplay sans null
   ref. Comparer le rendu au build natif (mêmes shaders visuellement).
2. Vérifier `shade/glsl` contient bien engine + projet, et que les fichiers
   sont copiés dans `project/mac/<app>.app/Contents/Resources/assets/`.
3. Itération : modifier un shader projet → rebuild cppia rapide → GLSL régénéré.
4. Non-régression : `ceramic clay build mac` (natif) sur zenith + GcBench —
   shaders transpilés comme avant, aucun `shade-cppia/` créé.
5. Instanced : un shader projet avec `#if shade_instanced` produit son `_inst`.

## Suite
Une fois shade réglé sur zenith desktop, reste C3 (mobile) et, si besoin, le
même traitement pour les audio worklets custom.
