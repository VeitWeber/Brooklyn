> [!NOTE]
> This is a fork of [iF2007/Brooklyn](https://github.com/iF2007/Brooklyn), which is itself a fork of the original [pedrommcarrasco/Brooklyn](https://github.com/pedrommcarrasco/Brooklyn).
>
> Brooklyn was created and open-sourced by [Pedro Carrasco](https://github.com/pedrommcarrasco). The fixes for macOS Sonoma and later in release `2.2.0` (clean screen saver termination, player cleanup, Universal 2 build) were made by [iF2007](https://github.com/iF2007). See [Changes in this fork](#changes-in-this-fork) for what was added on top.

![](Design/logo.jpg)

> Screen Saver by [Pedro Carrasco](https://twitter.com/pedrommcarrasco) based on the animations presented during **[Apple Special Event](https://www.youtube.com/watch?v=bfHEnw6Rm-4)** (October 30, 2018) from the Brooklyn Academy of Music, Howard Gilman Opera House.

<p align="center">
    <img src="Design/showcase.gif" alt="Example"/>
</p>

## Features ✅

* Doesn't require internet connection
* Light & Dark theme
* Select which animations you want to see
* Loop each animation how many times you want
* Make the animations' order random

<p align="center">
    <img src="Design/preferenceMenu.png" alt="Example"/>
</p>

## Changes in this fork

Version `2.3.0` builds on iF2007's `2.2.0` and was written for macOS 27:

* **Playback restarts cleanly.** The player is rebuilt whenever the screen saver starts. Before, stopping emptied the queue, so a restart on the same view (the preview in System Settings) stayed black. Changed options now also apply on the next start.
* **Looping re-queues the right clip.** The clip that actually finished is appended again, and the queue is only changed on the main thread.
* **Background instances are ended more reliably.** When the screen saver stops, the host process is ended with `exit(0)`. Full-size views are covered even when macOS reports `isPreview` incorrectly.
* **Options sheet.** The preview stops playing when the sheet is closed.
* **Project.** Deployment target macOS 14.0, Swift 5 for all targets, bundle identifier typo fixed (`com.pedrommcarrasco.brooklyn`), the original author's signing team removed, in-app links point to this fork, unused Sparkle keys and the leftover Travis CI and CocoaPods files removed.

## Installation 📦

This fork does not publish a prebuilt binary, so the screen saver is built from source with Xcode.

1. Close **System Settings**.
2. Build the screen saver:

   ```shell
   xcodebuild -project Brooklyn.xcodeproj -scheme Brooklyn -configuration Release -derivedDataPath /tmp/brooklyn-build build
   ```

3. Install it for the current user:

   ```shell
   mkdir -p ~/"Library/Screen Savers"
   rm -rf ~/"Library/Screen Savers/Brooklyn.saver"
   cp -R /tmp/brooklyn-build/Build/Products/Release/Brooklyn.saver ~/"Library/Screen Savers/"
   ```

4. Select **Brooklyn** in **System Settings > Wallpaper > Screen Saver** (on macOS 14 and 15: **System Settings > Screen Saver**).

A bundle built on your own Mac is not quarantined, so macOS does not block it.

### Prebuilt binaries from the original repositories

These do not contain the changes of this fork:

* `2.2.0` from [iF2007/Brooklyn](https://github.com/iF2007/Brooklyn/releases)
* `2.1.0` from [pedrommcarrasco/Brooklyn](https://github.com/pedrommcarrasco/Brooklyn/releases)

They are not notarized, so macOS blocks them when they are opened for the first time. Allow them with `Open Anyway` in **System Settings > Privacy & Security**.

## Uninstallation 🗑️

Delete `Brooklyn.saver` either in `/Library/Screen Savers` or `/Users/USERNAME/Library/Screen Savers`.

## Compatibility 🔧

Requires macOS 14 (Sonoma) or above.

## Troubleshooting 🤕

A downloaded `Brooklyn.saver` can stay blocked even after clicking `Open Anyway`. In that case, remove the quarantine attribute from the bundle:

```shell
xattr -d com.apple.quarantine ~/"Library/Screen Savers/Brooklyn.saver"
```

## Credits ❤️

* Original project: [pedrommcarrasco/Brooklyn](https://github.com/pedrommcarrasco/Brooklyn) by Pedro Carrasco. According to its README, it is no longer actively maintained.
* Fork with the fixes for macOS Sonoma and later: [iF2007/Brooklyn](https://github.com/iF2007/Brooklyn)

If you enjoy Brooklyn, please consider supporting its author Pedro:

* https://github.com/users/pedrommcarrasco/sponsorship
* https://www.buymeacoffee.com/pedrommcarrasco
* https://www.paypal.me/pedrommcarrasco

## License ⛔

Brooklyn's available under the MIT license. See the [LICENSE](LICENSE) file for more information. Logo & original animations are Apple's property.
