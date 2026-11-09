# DynALisp Conventions

The rules every program, window and data file of DynALisp follows. When a new convention is agreed, add it here, in its section, with the reason for it.

## Folders

Each module is a folder of `Contents\Modules\<Module>` (Dynalisp, LeeMac...), with these sub-folders:

- **Apps** - the commands of each tool, one Lisp file per tool, in a group folder (`Apps\Draw`, `Apps\Layer`...). Indexed by the Startup Suite (`Dyl-Suite`): turned on or off, with aliases and a docs page.
- **Remote** - code loaded at startup for every App: shared functions (`Remote>>` prefix), module paths, the readers and setters of the settings (e.g. `Remote>>Dyl:DrawOrderAutoSet`). Remote files load in alphabetical order: a file that loads before `Dyl-Paths.lsp` must fall back to `(strcat *dyl:dyl "\\Res")` instead of `*dyl:dylres`.
- **Reactor** - every reactor (`Reactor>>` prefix), loaded after Remote only while the DynALisp reactors are on (see [Reactors](#reactors)).
- **Res** - the data files (CSV) and dialogs (DCL) of the module, even when the code that uses them is in the core (e.g. `PrepSuite.csv`). Reached with `*dyl:dylres`.
- **Docs** - the HTML docs of the module, one page per Apps file, in the same group folder (`Docs\Draw\Dyl-QuickDraw.htm`), plus `index.htm`.

`Contents\Resources` is kept for the core of DynALisp itself: `dynalisp.mnl`, the Startup Suite (`StartupSuite.csv`, `Aliases.csv`), the core dialogs and `docs.css`. A file that belongs to a module never goes there.

*Why: a module stays self-contained, and the core holds only what runs every module.*

## Commands

- Each Lisp file has **one main command**, named after what it does: `Dyl-*` in the Dynalisp module, `LM-*` in the LeeMac module.
- Its other commands (presets, variants) are **child commands named `Pst-*`**, run by their aliases. When a file has no natural main tool, its main command is a picker (`Dyl:ChildPicker` in `dynalisp.mnl`) that lists its children.
- Short and former command names are **aliases** in `Resources\Aliases.csv`, never extra code.
- To rename a command, update its rows of `StartupSuite.csv` before the Lisp file (so its Load value is kept), and add the former name as an alias.

*Why: typing "Dyl" in the AutoCAD command line suggests only the main commands. The child prefix must not contain "DYL" (the suggestion list matches mid-string), and a leading `_` or symbol is parsed by the command line, hence `Pst-`.*

### Preset aliases

The alias of a Quick Draw preset tells how it draws: `PL-*` for a preset drawn with a polyline, `QD-*` for one that asks its method when drawn (the default for now). Quick Shape presets use `QS-*`. Pick the prefix to match when a preset's method changes or a preset is added.

## Presets And Materials

- The preset tools (Quick Draw, Quick Shape...) are built on the shared preset engine (`Remote\Dyl-Presets.lsp`): one window, the same list, filter, sort and buttons for every tool.
- The hatch parameters live in **materials** (`Remote\Dyl-Materials.lsp`, `Res\Materials.csv`), shared by id: `QD-BRICK`, `PL-BRICK` and a brick shape all use the one *Brick* material, so editing it changes them all.

## Settings

- Every setting is in the **Settings window** (`Dyl-Settings`, Settings region of `dynalisp.mnl`, `Modules\Dynalisp\Res\Dyl-Settings.dcl`), never in a separate dialog or command of its own. It holds settings only, no list of commands to run.
- The window keeps **on/off toggles**, in three sections: **Reactors** (the master switch, then one toggle per reactor, each with a short grey description under it), **Overrides** (Drawing Settings, Commands, File Preferences, System variables, Display) and **Updates** (Install updates automatically). A toggle with more settings has a small square *open* button that opens them in their own window, greyed out while the toggle is off.
- Every setting applies to **all drawings**, never to one drawing only: it is a `Dynalisp*` user setting (`getenv` / `setenv`). Open drawings catch up when they become current (Settings sync), applying only what changed since they last synced. Where a value can also be chosen per drawing (the draw order preset), the setting is the preferred default.
- Every on/off setting is **off on a new installation**, and on only once the user turns it on: read it with `(= "1" (getenv "Dynalisp..."))`, never `(/= "0" ...)`.
- DynALisp prefers **watching and enforcing defaults** (units and grid checked when each drawing opens) over commands to run by hand.

*Why: one place for every setting, and nothing changes in a drawing until the user asks for it.*

## Reactors

- Never create a `vlr-*` reactor in Apps, Remote or the MNL: every reactor is in a **Reactor** folder.
- The Reactor folders are loaded by `Dyl:load` only while `DynalispReactors` is on (the master switch of Dyl-Settings); off, they are skipped entirely.
- Each Reactor file registers its stop function with `Dyl:ReactorsAdd`, creates nothing when `Dyl:ReactorsOn-p` is nil, and its document manager callback calls `Dyl:ReactorsStop` when the switch was turned off in another drawing.
- Each reactor has its own `Dynalisp*` setting, with a toggle and a short description in the Reactors section of Dyl-Settings.
- Code in Remote or Apps that calls a Reactor function checks it is defined first: `(if Reactor>>Dyl:X ...)`.

*Why: a safe way to shut every reactor down at once, plus a setting for each one.*

## User Files

- The defaults of the editable data files (aliases, Startup Suite, presets, materials, layer keys, draw order and system variable presets, shape libraries...) are committed under `Contents`. The user's edits are saved to a copy at the same path under `DynALisp.bundle\User` (ignored by git), read in place of the default.
- Read a data file with `(Dyl:UserFile path)` and write it with `(Dyl:UserFileW path)`, never the raw default path. A folder whose files are added and deleted (presets, libraries) uses `Dyl:UserDir` / `Dyl:UserDirW` (whole-folder copy, marked by `_UserFolder.txt`). The API is in the UserFiles region of `dynalisp.mnl`.
- `Dyl-UserFiles` lists the copies, resets them, or makes one the default (how an edit is published to the committed defaults).
- **Saved settings** are a `DynALisp Settings <date>` folder: `DynALisp-Settings.txt` (the `Dynalisp*` user settings as `Name=Value` lines), `User\` and `Modules\MyTools\`. Export settings / Import settings of Dyl-UserFiles (`Dyl:SetsExport` / `Dyl:SetsImport`), the uninstall and the setup read and write the same format: change `dynalisp.mnl` and `Installer\DynALisp.iss` together. A setting that only means something on this computer (a stamp, a profile name, a path) goes in `*dyl:setslocal*` and `LocalSettings`, never saved.

*Why: the defaults stay in git, each user's edits stay out of it.*

## Versions And Updates

- The version of DynALisp is the `AppVersion` of `PackageContents.xml`, and only there: Dyl-Info, the setup and the release all read it. Its `ProductCode` never changes.
- Each version has its section at the top of `CHANGELOG.md`: a `## <version> - <date>` heading, then one short line per change (plain ASCII: AutoCAD reads the file as is). Raise `AppVersion` and add its section in the same change.
- A release is a `v<version>` tag pushed to GitHub: the release workflow builds the setup (`Installer\Build.ps1`) and publishes the release, with its changelog section as notes.
- DynALisp is installed with the setup or as a git clone. The setup installs only the files git knows (never `User`, `MyTools` or the dev files), removes the shipped folders before copying the new ones, waits for AutoCAD to close, and never installs over a git clone. A git clone is updated with `git pull`.
- The uninstall is **clean**: it offers to save the settings first (see [User Files](#user-files)), then removes the whole folder and everything DynALisp added outside it (the `Dynalisp*` user settings, the DynALisp profile, the paths into the folder in the AutoCAD profiles). Anything new that DynALisp adds outside its folder must be removed by the uninstall too (`CleanProduct` in `Installer\DynALisp.iss`).
- A file edited by DynALisp at run time never goes under `Contents` (see [User Files](#user-files)): an update replaces the shipped folders whole.

*Why: one version number for every reader, users told what changed on each update, the users' edits kept by every update, and nothing left behind by the uninstall unless the user saves it.*

## Windows

- Every DynALisp window has an **Open Docs** button (exactly that label, never "Documentation"), key `docs`, next to its OK / Cancel or Close buttons:
  `: button {label = "Open Docs"; key = "docs"; width = 12; fixed_width = true;}`
- After `new_dialog`, `(Dyl:DocsTile "Group\\Page.htm")` makes it open the page (relative to `Modules\Dynalisp\Docs`, or a full path): the window stays open, and the button is greyed out when the page is missing. The windows of the core use the pages of `Docs\Core`.
- A new window comes with its docs page. Small Yes/No and name prompts have no button.

*Why: every window leads to its documentation.*

## Spell Dictionaries

- The custom dictionaries are `Res\Dictionaries\<code>.cus` (UTF-16 BE with BOM, CRLF, as AutoCAD writes them), each with its definitions file `<code>-def.csv` (UTF-8 with BOM, `;`), read by `Dyl-Dictionary`.
- Never re-set `DCTCUST` automatically to make AutoCAD read a changed dictionary: the user reloads it (restarts AutoCAD).
- Words added to a `.cus` go in both the default and its `User` copy (AutoCAD uses the copy and writes added words there); restart AutoCAD before using *Add to dictionary*, or AutoCAD writes its old list back.
- Every word of the `.cus` has a row in `-def.csv` (or is a form of one). Add only single real words or real hyphenated compounds (*pare-vapeur*) to the `.cus`, never phrases joined by hyphens; expressions of several words (*semelle filante*) go only in `-def.csv`, with the types `loc.n.m.`, `loc.n.f.`, `loc.adj.` or `loc.adv.`.

*Why: the spell checker checks each word separately, and the user controls when AutoCAD reloads the dictionary.*
