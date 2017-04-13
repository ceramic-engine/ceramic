# ceramic

Cross-platform game/multimedia engine built on top of existing game/graphics/audio frameworks.

## Why ceramic?

Ceramic is made with very simple goals in mind:

* Provide a high level cross-platform API to make 2D games and animations.
* Have a clear separation of ceramic API and its backend API.
* Ensure adding new backends is as easy as possible by keeping the API clean and minimal.
* Leverage as much as possible existing frameworks instead of reinventing the wheel.
* Target iOS, Android, HTML5 (Canvas2D and WebGL), PC (Win/OSX/Linux).

See the short-term roadmap: https://github.com/jeremyfa/ceramic/issues/1

## How does it work?

Ceramic is built using [Haxe](http://haxe.org), a high level strictly typed programming language that can compile to multiple platforms.

Depending on the platform, it tries to use the best tools available using multiple backends.

The **ceramic** command line tools are also written in Haxe language but run with Node.js.

## Setup / How to use

At the moment, **ceramic** tool is only supported on Mac OS X but it is designed from the ground up to be usable on Windows and Linux in the future, thanks to using [Node.js](https://nodejs.org) and [Haxe](http://haxe.org/) which are two fantastic cross platform tools.

### Install Node.js

Install latest stable version (LTS) of Node.js from [nodejs.org](https://nodejs.org).

### Install Haxe

Install latest stable haxe from [haxe.org](http://haxe.org/).

Run `haxelib setup` from a terminal to choose your haxe library directory. Unless you know what you are doing, just choose default.

### Install Xcode (Mac)

Xcode is required on Mac in order to compile C++ files. You can [install Xcode from the Mac App Store](https://itunes.apple.com/fr/app/xcode/id497799835?mt=12)

### Install ceramic

While some of **ceramic** dependencies are haxe libraries, **ceramic** itself is installed from Git.

```
git clone https://github.com/jeremyfa/ceramic.git
cd ceramic
npm install
npm link .
```

You can now run **ceramic** from terminal:

```
ceramic help
```

### Install Visual Studio Code

[Visual Studio Code](https://code.visualstudio.com/) is a cross-platform code editor that supports the [Haxe](http://haxe.org) programming language thanks to its [Haxe extension](https://marketplace.visualstudio.com/items?itemName=nadako.vshaxe).

Download and install [Visual Studio Code](https://code.visualstudio.com/) on your computer.

### Install required VS Code extensions

You need to install [Haxe](https://marketplace.visualstudio.com/items?itemName=nadako.vshaxe) and [Tasks chooser](https://marketplace.visualstudio.com/items?itemName=jeremyfa.tasks-chooser) extensions.

To do so, open Visual Studio Code, then launch VS Code Quick Open (CMD+P / CTRL+P) and type:

```
ext install vshaxe
```

Then launch VS Code Quick Open again an type:

```
ext install tasks-chooser
```

You can also install them by browsing the [Extension Marketplace](https://code.visualstudio.com/docs/editor/extension-gallery) within VS Code.

### Create a new project

Create a new project named `MyProject` by running:

```
ceramic init --name MyProject --vscode --luxe
```

A new ceramic project is now created inside a `MyProject` directory, using the `luxe` backend and providing Visual Studio Code project files.

Open the `MyProject` directory with Visual Studio Code (you can to so by dragging the folder onto your VS Code icon).

Press (CMD+Shift+B / CTRL+Shift+B) to compile and run the project. **It should work!**

Thanks to the [Tasks chooser](https://marketplace.visualstudio.com/items?itemName=jeremyfa.tasks-chooser) extension, you can choose which target to run by selecting it in the status bar.

## Available backends

At the moment, the only available backend is `luxe` (based on [luxe engine](https://luxeengine.com/)).

It allows to target Mac, Windows, Linux, iOS, Android, HTML5 (WebGL).

More backends may be implemented in the future.
