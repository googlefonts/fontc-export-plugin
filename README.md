### fontc export plugin

An export plugin for Glyphs that uses [fontc](https://github.com/googlefonts/fontc) to export fonts. When installed, it shows up in the regular Export dialog (Cmd+E).

It downloads a standalone fontc executable inside the plugin, which is removed when the plugin is deleted.

fontc is a font compiler written in Rust which is designed to be 10x or more faster than
fontmake, our other font compiler written in Python.
Please note that the font compiler is not production-ready yet. You can follow development
progress on the [upstream Github repository](https://github.com/googlefonts/fontc).

![export dialog](exportDialog.png)

The "Command line options" accept whatever fontc accepts.

#### How to update the embdedded fontc

Please note that the instructions below are for the **maintainers** of the plugin, not the
Glyphs.app **users** who can get the updated fontc by upgrading the plugin itself within the app.

1. Check the latest fontc version available at https://github.com/googlefonts/fontc/releases/latest
1. Modify the `FONTC_VERSION` file accordingly
1. Run `./update-requirements.sh` to update the requirements.txt file embedded inside
   the plugin (cf. https://github.com/googlefonts/fontc-export-plugin/pull/1).
1. Bump _both_ `CFBundleShortVersionString` and `CFBundleVersion` in `fontcExport.glyphsFileFormat/Contents/Resources/Info.plist`, and stick to Glyphs.app's conventions whereby `CFBundleShortVersionString` looks like `MAJOR.MINOR` (e.g. `0.1`) and `CFBundleVersion` is a simple integer (e.g. `123`) for the build number.
1. Commit the changes and push
