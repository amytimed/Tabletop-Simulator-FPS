# Tabletop Simulator FPS

This repository contains the Lua script source and Unity AssetBundle source for my Tabletop Simulator FPS Kit, licensed under CC BY-NC-SA 4.0.

## How Screens Work

We utilize render textures and shared AssetBundles to share the screen render texture between the player and the screen.

## Building

### Scripts

#### Scripting Menu

You can open the published save on the workshop, then open the script menu on whatever you changed the script for, change the script and then apply it.

#### Script Tool 2.0

If you want to use my Script Tool 2.0, you'll need to minify the code using a tool such as `luamin` before pasting it in. You can find a `luamin` online tool here: https://mothereff.in/lua-minifier

### Unity AssetBundles

Install Unity 2019.4.40f1 with Windows, Mac and Linux build support, and then open `FPS-Unity-Project`.

Build using `Assets` > `Build AssetBundles`, and then replace the relevant AssetBundles URLs in the in-game objects.

## License

Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International Public License
