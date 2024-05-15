# encoding: utf-8

###########################################################################################################
#
#
# 	fontc Export Plugin
#
# 	Compiling fonts with fontc through the Export dialog.
#
###########################################################################################################

import objc, os, subprocess
from GlyphsApp import *
from GlyphsApp import GSScriptingHandler
from GlyphsApp.plugins import *
from Foundation import (
    NSMutableOrderedSet,
    NSClassFromString,
    NSZeroRect,
    NSMaxXEdge,
    NSArray,
    NSAttributedString,
)
from AppKit import NSImageNameFolder, NSPopover, NSPopoverBehaviorTransient
from io import StringIO
from pathlib import Path
import glob
import shlex
import shutil
import sys

# Preference key names
ExportPathKey = "org_fontc_exportPath"
UseExportPathKey = "org_fontc_useExportPath"
AdditionalOptionsKey = "org_fontc_additional_options"
ExportRecentExportPathsKey = "org_fontc_recent_exportPaths"
ClearBuildDirKey = "org_fontc_clear_build_dir"

GSAddParameterViewControllerClass = NSClassFromString("GSAddParameterViewController")


def run_subprocess_in_macro_window(
    command, check=False, show_window=False, capture_output=False
):
    """Wrapper for subprocess.run that writes in real time to Macro output window"""

    if show_window:
        Glyphs.showMacroWindow()

    # echo command
    print(f"$ {' '.join(shlex.quote(str(arg)) for arg in command)}")

    # Start the subprocess asynchronously and redirect output to a pipe
    process = subprocess.Popen(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,  # Redirect stderr to stdout
        encoding="utf-8",
        text=True,
        bufsize=1,  # Line-buffered
    )

    # Read the output line by line and write to Glyphs.app's Macro output window
    output = StringIO() if capture_output else None
    while process.poll() is None:
        for line in process.stdout:
            sys.stdout.write(line)
            if output is not None:
                output.write(line)

    returncode = process.wait()

    if check and returncode != 0:
        # Raise an exception if the process returned an error code
        raise subprocess.CalledProcessError(
            returncode, process.args, process.stdout, process.stderr
        )

    if capture_output:
        return subprocess.CompletedProcess(
            process.args, returncode, output.getvalue(), ""
        )

    return subprocess.CompletedProcess(process.args, returncode, None, None)


def relative_to_home(path_str):
    """Convert absolute path to ~/path if within $HOME, else return original."""
    path = Path(path_str)
    home_dir = Path.home()
    try:
        return f"~/{path.relative_to(home_dir)}"
    except ValueError:
        return path_str


class FontcAddOptionViewController(GSAddParameterViewControllerClass):

    def addParameter_(self, sender):
        newOptions = []
        for option in self.customParameterController().selectedObjects():
            name = option["identifier"]
            newOptions.append(name)
        if len(newOptions) == 0:
            return
        options = Glyphs.defaults[AdditionalOptionsKey]
        if options is None:
            options = ""
        options = " ".join(filter(None, (options, *newOptions)))
        Glyphs.defaults[AdditionalOptionsKey] = options


class FontcExport(FileFormatPlugin):

    # Definitions of IBOutlets

    # The NSView object from the User Interface. Keep this here!
    dialog = objc.IBOutlet()

    # Example variables. You may delete them
    recentExportPathsButton = objc.IBOutlet()
    additionalOptions = objc.IBOutlet()

    @objc.python_method
    def settings(self):
        self.name = Glyphs.localize({"en": "fontc"})
        self.icon = "ExportIconTemplate"
        self.toolbarPosition = 100
        self._options = None  # lazy load when actually needed.
        # Load .nib dialog (with .extension)
        self.loadNib("IBdialog", __file__)

    @objc.python_method
    def start(self):
        # Init user preferences if not existent and set default value
        Glyphs.registerDefault(ExportPathKey, os.path.expanduser("~/Documents"))
        Glyphs.registerDefault(ClearBuildDirKey, False)

        self.setupRecentExportPathsButton()

    @objc.python_method
    def setupRecentExportPathsButton(self):
        menu = self.recentExportPathsButton.menu()
        while len(menu.itemArray()) > 1:
            menu.removeItemAtIndex_(1)

        recentExportPaths = Glyphs.defaults[ExportRecentExportPathsKey]
        if recentExportPaths and len(recentExportPaths) > 0:
            folderImage = NSImage.imageNamed_(NSImageNameFolder)
            folderImage.setSize_(NSMakeSize(16, 16))

            for recentExportPath in recentExportPaths:
                item = NSMenuItem.alloc().initWithTitle_action_keyEquivalent_(
                    recentExportPath.stringByStandardizingPath().stringByAbbreviatingWithTildeInPath(),
                    "setRecentExportPath:",
                    "",
                )
                item.setRepresentedObject_(recentExportPath)
                item.setImage_(folderImage)
                item.setTarget_(self)
                menu.addItem_(item)

            item = NSMenuItem.separatorItem()
            menu.addItem_(item)

            item = NSMenuItem.alloc().initWithTitle_action_keyEquivalent_(
                "Clear Recent", "clearRecent:", ""
            )
            item.setTarget_(self)
            menu.addItem_(item)

        item = NSMenuItem.alloc().initWithTitle_action_keyEquivalent_(
            f"Update fontc", "updateFontc:", ""
        )
        item.setTarget_(self)
        menu.addItem_(item)

        item = NSMenuItem.alloc().initWithTitle_action_keyEquivalent_(
            f"Clear build directory", "clearBuildDir:", ""
        )
        item.setTarget_(self)
        menu.addItem_(item)

    @objc.python_method
    def tempPath(self, familyName):
        appSupportSubpath = GSGlyphsInfo.applicationSupportPath()
        tempPath = os.path.join(appSupportSubpath, "Temp", f"{familyName}-fontc")
        return tempPath

    @objc.python_method
    def pluginResourcesDirPath(self):
        return os.path.dirname(__file__)

    @objc.python_method
    def fontcPath(self):
        return os.path.join(self.pluginResourcesDirPath(), "bin", "fontc")

    @objc.python_method
    def setUpFontc(self):
        fontcPath = self.fontcPath()
        if os.path.exists(fontcPath):
            return fontcPath

        scriptingHandler = GSScriptingHandler.sharedHandler()
        glyphsPythonPath = os.path.join(
            scriptingHandler.currentPythonPath(), "bin", "python3"
        )

        installCommand = [
            glyphsPythonPath,
            "-m",
            "pip",
            "install",
            "--disable-pip-version-check",
            "--target",
            self.pluginResourcesDirPath(),
            "fontc",
        ]
        run_subprocess_in_macro_window(installCommand, check=True)

        assert os.path.exists(fontcPath), "fontc not found after installation"
        return fontcPath

    def setRecentExportPath_(self, sender):
        exportPath = sender.representedObject()
        Glyphs.defaults[ExportPathKey] = exportPath

    def clearRecent_(self, sender):
        Glyphs.defaults[ExportRecentExportPathsKey] = None
        self.setupRecentExportPathsButton()

    def options(self):
        if self._options is None:
            options = NSArray.arrayWithContentsOfFile_(
                os.path.join(self.pluginResourcesDirPath(), "options.plist")
            )
            for option in options:
                text = option.get("text", None)
                if text:
                    text = NSAttributedString.attributedStringFromMarkdownString_(text)
                    option["text"] = text
            self._options = options
        return self._options

    @objc.python_method
    def fontcDistInfoPath(self):
        # find directory that starts with "fontc-" and ends with ".dist-info" in pluginResourcesDirPath
        distInfoDirs = glob.glob(
            os.path.join(self.pluginResourcesDirPath(), "fontc-*.dist-info")
        )
        if len(distInfoDirs) == 0:
            return None
        elif len(distInfoDirs) != 1:
            raise ValueError(
                f"Expected exactly one directory matching 'fontc-*.dist-info', got {distInfoDirs}"
            )
        return distInfoDirs[0]

    @objc.python_method
    def currentFontcVersion(self):
        distInfoPath = self.fontcDistInfoPath()
        if not distInfoPath:
            return "[not installed]"
        # strip the 'fontc-' prefix and '.dist-info' suffix to get version string
        return os.path.basename(distInfoPath)[6:-10]

    def updateFontc_(self, sender):
        fontcPath = self.fontcPath()
        if os.path.exists(fontcPath):
            print("Removed fontc; it will be re-downloaded on next export.")
            shutil.rmtree(os.path.dirname(fontcPath))
            distInfoPath = self.fontcDistInfoPath()
            if distInfoPath:
                shutil.rmtree(distInfoPath)

    def clearBuildDir_(self, sender):
        Glyphs.defaults[ClearBuildDirKey] = True

    @objc.IBAction
    def showAddOptionPopup_(self, sender):
        contentViewController = FontcAddOptionViewController.new()
        contentViewController.setCustomParameters_(self.options())
        popover = NSPopover.new()
        popover.setBehavior_(NSPopoverBehaviorTransient)
        popover.setContentViewController_(contentViewController)
        popover.setDelegate_(contentViewController)

        popover.showRelativeToRect_ofView_preferredEdge_(NSZeroRect, sender, NSMaxXEdge)

    @objc.python_method
    def export(self, font):
        fontcPath = self.setUpFontc()

        if Glyphs.boolDefaults[UseExportPathKey]:
            exportPath = Glyphs.defaults[ExportPathKey]
        else:
            exportPath = GetFolder()

        if exportPath is None:
            return False, "No export path"

        tempFolder = self.tempPath(font.familyName)
        if os.path.isdir(tempFolder) and Glyphs.defaults[ClearBuildDirKey]:
            shutil.rmtree(tempFolder)
            Glyphs.defaults[ClearBuildDirKey] = False
        os.makedirs(tempFolder, exist_ok=True)

        tempFile = os.path.join(tempFolder, "font.glyphs")
        font.save(tempFile, makeCopy=True)

        arguments = [
            fontcPath,
            "--build-dir",
            tempFolder,
            tempFile,
        ]
        additionalOptions = Glyphs.defaults[AdditionalOptionsKey]
        if additionalOptions:
            arguments.extend(shlex.split(additionalOptions))

        result = run_subprocess_in_macro_window(arguments, capture_output=True)

        if result.returncode != 0:
            errorLines = []
            for line in result.stdout.splitlines():
                # TODO check that fontc error log lines do in fact match this
                # (I simply replaced s/fontmake/fontc/)
                if line.startswith("ERROR:") or "fontc: Error:" in line:
                    errorLines.append(line)
            errorMsg = (
                "\n".join(errorLines)
                or "An error occurred. Check Macro Window for details."
            )
            return False, errorMsg

        # TODO use fileName custom parameter if set?
        fileName = f"{font.familyName.replace(' ', '')}-VF.ttf"
        src = os.path.join(tempFolder, "font.ttf")
        if not os.path.exists(src):
            return False, f"font.ttf not found in {tempFolder}"

        dst = os.path.join(exportPath, fileName)
        print(f"$ cp {shlex.quote(src)} {shlex.quote(dst)}")
        shutil.copyfile(src, dst)
        return True, f"Exported successfully:\n\n{relative_to_home(dst)}"

    @objc.IBAction
    def openDoc_(self, sender):
        path = GetFolder()
        if path is not None:
            Glyphs.defaults[ExportPathKey] = path

            recentExportPaths = Glyphs.defaults[ExportRecentExportPathsKey]
            if not recentExportPaths:
                recentExportPaths = []

            recentExportPathsSet = NSMutableOrderedSet.alloc().initWithArray_(
                recentExportPaths
            )
            recentExportPathsSet.insertObject_atIndex_(path, 0)
            Glyphs.defaults[ExportRecentExportPathsKey] = recentExportPathsSet.array()
            self.setupRecentExportPathsButton()

    @objc.python_method
    def __file__(self):
        """Please leave this method unchanged"""
        return __file__
