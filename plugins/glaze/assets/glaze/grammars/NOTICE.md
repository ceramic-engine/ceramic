# Grammars

TextMate grammars used by the code highlighter (`glaze.kit.highlighter`).
They are the files of tm-grammars 1.31.15 (https://github.com/shikijs/textmate-grammars-themes),
the grammar collection of shiki 3.23, unchanged. tm-grammars itself is MIT licensed
(LICENSE-tm-grammars). Each grammar keeps the license of its origin: the sections of the
NOTICE file of tm-grammars that cover these files are reproduced in NOTICE-tm-grammars.

erb.json, toml.json and yaml.json come from TextMate bundles (textmate/ruby.tmbundle,
textmate/toml.tmbundle, textmate/yaml.tmbundle), not covered by that NOTICE. The README of
each bundle states this license for its files:

```
Permission to copy, use, modify, sell and distribute this
software is granted. This software is provided "as is" without
express or implied warranty, and with no claim as to its
suitability for any purpose.
```

Regenerate with `node tests/unit/data/highlight/bundle-grammars.mjs <tm-grammars package folder>`.

| File | Scope | Origin | License |
|------|-------|--------|---------|
| astro.json | source.astro | https://github.com/withastro/language-tools/blob/8e55c37cbcf134dedf0068781245da5a9d46d081/packages/vscode/syntaxes/astro.tmLanguage.src.yaml | MIT |
| c.json | source.c | https://github.com/microsoft/vscode/blob/bd1abe08c38bb5deccf65610f8f3c03d2338d20d/extensions/cpp/syntaxes/c.tmLanguage.json | MIT |
| cmake.json | source.cmake | https://github.com/twxs/vs.language.cmake/blob/19b1b8fe2d68d72cf294d0c3c22f0a3fc54f8f6f/syntaxes/CMake.tmLanguage | MIT |
| coffee.json | source.coffee | https://github.com/microsoft/vscode/blob/ff58f5083f57b50e6a100ab60454dfb72fe21e80/extensions/coffeescript/syntaxes/coffeescript.tmLanguage.json | MIT |
| cpp.json | source.cpp | https://github.com/microsoft/vscode/blob/6ac83c7c7dda9f27ca1fe9d98675253e010b75d1/extensions/cpp/syntaxes/cpp.tmLanguage.json | MIT |
| cpp-macro.json | source.cpp.embedded.macro | https://github.com/microsoft/vscode/blob/6ac83c7c7dda9f27ca1fe9d98675253e010b75d1/extensions/cpp/syntaxes/cpp.embedded.macro.tmLanguage.json | MIT |
| csharp.json | source.cs | https://github.com/microsoft/vscode/blob/84f7ab5aa01c31d5352c7db89051e8c391fd9ae1/extensions/csharp/syntaxes/csharp.tmLanguage.json | MIT |
| css.json | source.css | https://github.com/microsoft/vscode/blob/091ef378baaa141c8bc4bbe9775d4cb3bd655a80/extensions/css/syntaxes/css.tmLanguage.json | MIT |
| diff.json | source.diff | https://github.com/microsoft/vscode/blob/4549bd26c7b799284e0ebd8dc1e0310e6a8707a1/extensions/diff/syntaxes/diff.tmLanguage.json | MIT |
| docker.json | source.dockerfile | https://github.com/microsoft/vscode/blob/8270a86019db7551da42b71d15c6080a414d8c81/extensions/docker/syntaxes/docker.tmLanguage.json | MIT |
| elixir.json | source.elixir | https://github.com/elixir-editors/elixir-tmbundle/blob/43c8cd957d5ac6e1abbd8730fc7a08c81a6e76c9/Syntaxes/Elixir.tmLanguage | NOASSERTION |
| erb.json | text.html.erb | https://github.com/textmate/ruby.tmbundle/blob/ecf0f1df23984bcff9b51552e35d9696cb0d9539/Syntaxes/HTML%20(Ruby%20-%20ERB).tmLanguage | see NOTICE-tm-grammars |
| go.json | source.go | https://github.com/microsoft/vscode/blob/091ef378baaa141c8bc4bbe9775d4cb3bd655a80/extensions/go/syntaxes/go.tmLanguage.json | MIT |
| graphql.json | source.graphql | https://github.com/prisma-labs/vscode-graphql/blob/4569aef2364b42b6acd8188e4a6ca9b0ba3c6a1d/grammars/graphql.json | MIT |
| haml.json | text.haml | https://github.com/karuna/haml-vscode/blob/aa45415aefd691af0a501ea4f98e434490623e0d/syntaxes/haml.json | MIT |
| haxe.json | source.hx | https://github.com/vshaxe/haxe-TmLanguage/blob/67b4ee73be516277095b03056f183ffe8a6dd1ac/haxe.YAML-tmLanguage | MIT |
| html.json | text.html.basic | https://github.com/microsoft/vscode/blob/45324363153075dab0482312ae24d8c068d81e4f/extensions/html/syntaxes/html.tmLanguage.json | MIT |
| html-derivative.json | text.html.derivative | https://github.com/microsoft/vscode/blob/4064f172528461afc6944383d07521f6a30da89c/extensions/html/syntaxes/html-derivative.tmLanguage.json | MIT |
| hxml.json | source.hxml | https://github.com/vshaxe/haxe-TmLanguage/blob/cf8117cb69876af5fbac537860ffc73928fe2571/hxml.YAML-tmLanguage | MIT |
| ini.json | source.ini | https://github.com/microsoft/vscode/blob/8fdf170a0850c1cc027382f31650aaf300d3ae2a/extensions/ini/syntaxes/ini.tmLanguage.json | MIT |
| java.json | source.java | https://github.com/microsoft/vscode/blob/3c86ede5f554f6e196c832394e126b291a1de606/extensions/java/syntaxes/java.tmLanguage.json | MIT |
| javascript.json | source.js | https://github.com/microsoft/vscode/blob/210541906e5a96ab39f9c753f921b1bd35f4138b/extensions/javascript/syntaxes/JavaScript.tmLanguage.json | MIT |
| json.json | source.json | https://github.com/microsoft/vscode/blob/d6af4893ed9a3545163a4cb748fa5548bd1e51a5/extensions/json/syntaxes/JSON.tmLanguage.json | MIT |
| jsonc.json | source.json.comments | https://github.com/microsoft/vscode/blob/0adddd82816db666c52038e8277312dc55da2756/extensions/json/syntaxes/JSONC.tmLanguage.json | MIT |
| jsx.json | source.js.jsx | https://github.com/microsoft/vscode/blob/210541906e5a96ab39f9c753f921b1bd35f4138b/extensions/javascript/syntaxes/JavaScriptReact.tmLanguage.json | MIT |
| kotlin.json | source.kotlin | https://github.com/fwcd/vscode-kotlin/blob/626e20d5c51a4379c4c0ee293aa89e58b5232aec/syntaxes/kotlin.tmLanguage.json | MIT |
| less.json | source.css.less | https://github.com/microsoft/vscode/blob/03dc55030b3b2b5c4779d4ac1e2e46cd1f5a6b7c/extensions/less/syntaxes/less.tmLanguage.json | MIT |
| lua.json | source.lua | https://github.com/microsoft/vscode/blob/c8fdd1650c06321d687ddfd1eff06aae4b616256/extensions/lua/syntaxes/lua.tmLanguage.json | MIT |
| make.json | source.makefile | https://github.com/microsoft/vscode/blob/91db8ea85fee30ebb3c7a5e7939aa2a8d79811c5/extensions/make/syntaxes/make.tmLanguage.json | MIT |
| markdown.json | text.html.markdown | https://github.com/microsoft/vscode/blob/6d8ab9737d58fc5eaf07e2ae6553b38183a5de47/extensions/markdown-basics/syntaxes/markdown.tmLanguage.json | MIT |
| php.json | source.php | https://github.com/microsoft/vscode/blob/84f7ab5aa01c31d5352c7db89051e8c391fd9ae1/extensions/php/syntaxes/php.tmLanguage.json | MIT |
| postcss.json | source.css.postcss | https://github.com/vuejs/vetur/blob/8ccae3ba50b65837d4cd4acc71a3b84cd3bee27c/syntaxes/vue-postcss.json | MIT |
| proto.json | source.proto | https://github.com/zxh0/vscode-proto3/blob/274be763ecae7055505354b44f4892a2669e1da8/syntaxes/proto3.tmLanguage.json | MIT |
| pug.json | text.pug | https://github.com/microsoft/vscode/blob/6ac83c7c7dda9f27ca1fe9d98675253e010b75d1/extensions/pug/syntaxes/pug.tmLanguage.json | MIT |
| python.json | source.python | https://github.com/microsoft/vscode/blob/cf4c9e469d521fa5f33353737e8157eb0789ad02/extensions/python/syntaxes/MagicPython.tmLanguage.json | MIT |
| regexp.json | source.regexp.python | https://github.com/MagicStack/MagicPython/blob/c9b3409deb69acec31bbf7913830e93a046b30cc/grammars/MagicRegExp.tmLanguage | MIT |
| ruby.json | source.ruby | https://github.com/microsoft/vscode/blob/091ef378baaa141c8bc4bbe9775d4cb3bd655a80/extensions/ruby/syntaxes/ruby.tmLanguage.json | MIT |
| rust.json | source.rust | https://github.com/microsoft/vscode/blob/9a2c94d213696a4453b6d9988b003d98e7646e75/extensions/rust/syntaxes/rust.tmLanguage.json | MIT |
| sass.json | source.sass | https://github.com/TheRealSyler/vscode-sass-indented/blob/f0e50cfaca4b64a1d49f8d938f188d6fd0bcfb6f/syntaxes/sass.tmLanguage.json | NOASSERTION |
| scala.json | source.scala | https://github.com/scala/vscode-scala-syntax/blob/1d4029f21c9c57ce3e05486968b5de2847c25c62/syntaxes/Scala.tmLanguage.json | MIT |
| scss.json | source.css.scss | https://github.com/microsoft/vscode/blob/cf8d61ebd2f022f4ce8280171f0360d1fe0a206d/extensions/scss/syntaxes/scss.tmLanguage.json | MIT |
| shellscript.json | source.shell | https://github.com/microsoft/vscode/blob/9473445f7d3dcb5c579f42ece8b6c18c43c63ed3/extensions/shellscript/syntaxes/shell-unix-bash.tmLanguage.json | MIT |
| sql.json | source.sql | https://github.com/microsoft/vscode/blob/84f7ab5aa01c31d5352c7db89051e8c391fd9ae1/extensions/sql/syntaxes/sql.tmLanguage.json | MIT |
| stylus.json | source.stylus | https://github.com/d4rkr00t/language-stylus/blob/198a851f385aee857332f3ce5dd981ff67720ead/syntaxes/stylus.json | MIT |
| svelte.json | source.svelte | https://github.com/sveltejs/language-tools/blob/32bd44e5af1eea464198cc6e841281b045e0f04d/packages/svelte-vscode/syntaxes/svelte.tmLanguage.src.yaml | MIT |
| swift.json | source.swift | https://github.com/jtbandes/swift-tmlanguage/blob/3fca2fa10f7dc962d19ee617b17844d6eecfa2cb/Swift.tmLanguage.yaml | MIT |
| toml.json | source.toml | https://github.com/textmate/toml.tmbundle/blob/e82b64c1e86396220786846201e9aa3f0a2d9ca2/Syntaxes/TOML.tmLanguage | see NOTICE-tm-grammars |
| tsx.json | source.tsx | https://github.com/microsoft/vscode/blob/210541906e5a96ab39f9c753f921b1bd35f4138b/extensions/typescript-basics/syntaxes/TypeScriptReact.tmLanguage.json | MIT |
| typescript.json | source.ts | https://github.com/microsoft/vscode/blob/210541906e5a96ab39f9c753f921b1bd35f4138b/extensions/typescript-basics/syntaxes/TypeScript.tmLanguage.json | MIT |
| xml.json | text.xml | https://github.com/microsoft/vscode/blob/10a1d2a50a2882f5ae85bdb51eb04d3064fb9de9/extensions/xml/syntaxes/xml.tmLanguage.json | MIT |
| yaml.json | source.yaml | https://github.com/textmate/yaml.tmbundle/blob/e54ceae3b719506dba7e481a77cea4a8b576ae46/Syntaxes/YAML.tmLanguage | see NOTICE-tm-grammars |
| zig.json | source.zig | https://github.com/ziglang/vscode-zig/blob/9c7bb7631f3af99331475b633aaf5b70345c6713/syntaxes/zig.tmLanguage.json | MIT |
