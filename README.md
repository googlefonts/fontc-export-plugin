### fontc export plugin

An export plugin for Glyphs that uses [fontc](https://github.com/googlefonts/fontc) to export fonts. When installed, it shows up in the regular Export dialog (Cmd+E).

It downloads a standalone fontc executable inside the plugin, which is removed when the plugin is deleted.

fontc is a font compiler written in Rust which is designed to be 10x or more faster than
fontmake, our other font compiler written in Python.
Please note that the font compiler is not production-ready yet. You can follow development
progress on the [upstream Github repository](https://github.com/googlefonts/fontc).

![export dialog](exportDialog.png)

The "Command line options" accept whatever fontc accepts.

#### How to update the embedded fontc

Please note that the instructions below are for the **maintainers** of the plugin, not the
Glyphs.app **users** who can get the updated fontc by upgrading the plugin itself within the app.

##### Automated Updates (Recommended)

The plugin repository is configured to **automatically create pull requests** when new fontc
releases are published:

1. When a new fontc release is published in the [fontc repository](https://github.com/googlefonts/fontc),
   a GitHub Actions workflow automatically sends a webhook to this plugin repository.
2. The plugin repository receives the webhook and runs the update workflow (on macOS runners), which:
   - Updates the `FONTC_VERSION` file
   - Downloads the `requirements.txt` from the new release
   - Auto-increments both version numbers in `Info.plist`:
     - `CFBundleShortVersionString`: Minor version bump (e.g., 0.5 → 0.6)
     - `CFBundleVersion`: Build number increment (e.g., 6 → 7)
   - Validates all changes, including creating a temporary Python 3.11 venv, installing fontc from requirements.txt, and verifying `fontc --version` works
   - Creates a pull request with all updates
3. Review and merge the automatically created pull request.

**Setup required** (one-time, maintainers only):

The fontc repository needs a GitHub secret named `FONTC_GLYPHS_PLUGIN_REPO_TOKEN` with a Personal Access
Token that has `repo` and `workflow` permissions to trigger workflows in this plugin repository.
This token is used by the notification workflow in `fontc/.github/workflows/notify-plugin.yml`.

##### Manual Updates (Fallback)

If you need to update manually (e.g., for testing or if automation fails):

**Requirements**: macOS with Python 3.11 installed (to match Glyphs.app's current Python version)

1. Run the update script:
   - To update to the latest release: `./scripts/update-fontc-version.sh`
   - To update to a specific version: `./scripts/update-fontc-version.sh 0.3.2`
   - This automatically fetches the version (if not specified), updates `FONTC_VERSION`, downloads `requirements.txt`, and bumps version numbers etc.
2. Run validation: `./scripts/validate-update.sh` to verify the update
   - This creates a Python 3.11 venv, installs fontc, and tests that it runs correctly
3. Commit the changes and push
4. Create a pull request manually if needed
