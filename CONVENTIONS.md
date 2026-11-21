# DynALisp Conventions

The rules every program, window and data file of DynALisp follows. When a new convention is agreed, add it here, in its section, with the reason for it.

## Folders

Each module is a folder of `Contents\Modules\<Module>` (Dynalisp, LeeMac...), with these sub-folders:

- **Apps** - the commands of each tool, one Lisp file per tool, in a group folder (`Apps\Draw`, `Apps\Layer`...). Indexed by the Startup Suite (`Dyl-Suite`): turned on or off, with aliases and a docs page.
  - A file that uses the functions of an Apps file (Pick hatch of the Hatch Presets window, `rpat:rebuild-hatch` of `Dyl-RebuildPat.lsp`) checks it is turned on (`Dyl:SuiteFileOn-p`), asks to turn it on when it is off and turns it on (`Dyl:SuiteFileOn`), then loads it (`Dyl:SuiteFileLoad`) when its function is not defined yet. Never load an App that is turned off without asking.
- **Remote** - code loaded at startup for every App: shared functions (`Remote>>` prefix), module paths, the readers and setters of the settings (e.g. `Remote>>Dyl:DrawOrderAutoSet`). Remote files load in alphabetical order: a file that loads before `Dyl-Paths.lsp` must fall back to `(strcat *dyl:dyl "\\Res")` instead of `*dyl:dylres`.
- **Reactor** - every reactor (`Reactor>>` prefix), loaded after Remote only while the DynALisp reactors are on (see [Reactors](#reactors)).
- **Res** - the data files (CSV) and dialogs (DCL) of the module, even when the code that uses them is in the core (e.g. `PrepSuite.csv`). Reached with `*dyl:dylres`.
- **Docs** - the **User Guide** of the module: one page per Apps file, in the same group folder (`Docs\Draw\Dyl-QuickDraw.htm`), plus `index.htm`, its pictures in an `images` folder beside the pages.
- **DevDocs** - the **Developer docs** of the module: the same group folders and page names (`DevDocs\Draw\Dyl-QuickDraw.htm`), plus `index.htm`.
  - Both are published on the docs website (see [Windows](#windows)) and neither is installed by the setup: only a git clone has them.
  - The index of the Dynalisp module has two sections. **DynALisp** holds what every module shares, which is not an App: `Core` (the windows of the core), `Plugins` (the ribbon, the .NET plugins) and `Conventions` (the standards the programs follow, `LayerNaming.htm`). **Apps** holds the programs, one sub-heading per group folder.
  - A page that is not an App goes in the folder named after its sub-heading of the DynALisp section, never in a group folder of Apps. A new part of the core (a plugin, a standard) gets its page there and its row in that sub-heading.

`Contents\Resources` is kept for the core of DynALisp itself: `dynalisp.mnl`, the Startup Suite (`StartupSuite.csv`, `Aliases.csv`), the ribbon (`DynALisp.cuix`, `DynALisp.Ribbon.dll`), the core dialogs and `docs.css`. A file that belongs to a module never goes there.

The **LeeMac** module is the **sample module**: in its docs index, its pages, the README and the core windows it is described as a sample that showcases what DynALisp does with existing AutoLISP programs (indexed in the Startup Suite, main and child commands, aliases, shared subfunctions, a docs page per program), and the model for a module of one's own. Its programs keep their author and licence.

*Why: a module stays self-contained, and the core holds only what runs every module. The user decides which Apps are turned on, and an App turned on is only autoloaded: its functions are defined once one of its commands has run. The LeeMac module shows, with real programs, how any collection of AutoLISP code becomes a DynALisp module. In the docs, what runs every module is kept apart from the Apps, so a page found in a group folder is always the page of a program.*

## Commands

- Each Lisp file has **one main command**, named after what it does: `Dyl-*` in the Dynalisp module, `LM-*` in the LeeMac sample module.
- Its other commands (presets, variants) are **child commands named `Pst-*`**, run by their aliases. When a file has no natural main tool, its main command is a picker (`Dyl:ChildPicker` in `dynalisp.mnl`) that lists its children.
- Short names are **aliases** in `Resources\Aliases.csv`, never extra code (the original names of a program, e.g. Lee Mac's `BATTE`, are short names). An alias is **never a long name with a command prefix** (`Dyl-*`, `LM-*`, `Pst-*`): Dyl-Suite refuses it, and a former long name (`DYL-LAYFILTER`) is dropped, not kept as an alias. An alias never takes the name of a command of AutoCAD or of its Express Tools: a command always wins, so that alias is never defined. Dyl-Suite refuses such a name and says what has it (`Dyl:AliasTaken`), and an alias saved before its name was taken is reported with its command (*Alias TCOUNT of LM-TEXTCOUNT not defined: TCOUNT is already a command of another program...*). An original name that is taken gets another alias (`TXTCOUNT` for Lee Mac's `TCOUNT`).
- An alias (or a command) never takes the name of an **alias of `acad.pgp`** either (`DO` for `DONUT`, `CL` for `CENTERLINE`): Dyl-Suite refuses it (`Dyl:PgpAliases`), and Dyl-Diagnostics reports a command turned on or an alias defined with such a name. An original name that is one gets another alias (`ACL` for Lee Mac's `CL`).
- To remove a program, remove with its file its rows of `StartupSuite.csv` (the default and its `User` copy), its aliases in `Aliases.csv` (both), its docs page and its rows and links in the other docs pages (the docs index of its module), and its ribbon row. A custom preset command (`Pst-QuickDrawCustom*`) is a dynamic child, not a row of `StartupSuite.csv`: its aliases are kept while the preset exists.
- The Apps file is **named exactly as its main command**, same spelling and case (`c:Dyl-HatchPresets` -> `Apps\Draw\Dyl-HatchPresets.lsp`), and so is its docs page (`Docs\Draw\Dyl-HatchPresets.htm`). A file that holds only functions, without a command (`LM-PrintList.lsp`), is named after what it holds.
- Command and file names are in **PascalCase**: each word starts with a capital and goes on in lower case, after the prefix (`Dyl-LayerExportToCsv`, `LM-ResetXrefLayers`), never all in capitals (`Dyl-EXPORTLAYERS`) or all in lower case (`dyl-list`). An AutoCAD term of one word is one word (`ByLayer`, `Linetype`, `Multileader`, `Xref`, `Mtext`); an acronym may keep its capitals (`LM-FormatDCL`, `Pst-QuickDrawCMU`). A name is spelled out, never abbreviated (`LM-ModelSpaceToPaperSpace`, not `LM-ms2ps`), and has no version number (`LM-DumpObject`, not `LM-DumpObjectV1-2`): the short names are aliases.
- To rename a command, update its rows of `StartupSuite.csv` before the Lisp file (so its Load value is kept); its short aliases follow it, and its former name is not kept. Rename its Apps file and its docs page with it, and update what names them: the `File` and `Path` columns of `StartupSuite.csv` (the default and its `User` copy), the `Dyl:DocsTile` calls, and the links of the other docs pages.

*Why: typing "Dyl" in the AutoCAD command line suggests only the main commands (a `DYL-*` alias would add a second, outdated name to that list). The child prefix must not contain "DYL" (the suggestion list matches mid-string), and a leading `_` or symbol is parsed by the command line, hence `Pst-`. A file named as its command is found from the command (and the command from the file) without opening the Startup Suite. PascalCase names read the same in the code, the docs and the AutoCAD command line, which shows them in capitals anyway. An alias of `acad.pgp` is what every AutoCAD user types: one of the two names would hide the other. An alias left behind by a program removed points to nothing and is reported by Dyl-Diagnostics on every computer.*

### Calling AutoCAD Commands

- Lisp code calls an AutoCAD command by its **international name**: the command with `_.` in front (`"_.-layer"`, `"_.undo"`, `"_.pedit"`), each keyword option and each Yes/No answer with `_` (`"_ON"`, `"_mark"`, `"_y"`, `"_n"`), in `command`, `command-s`, `vl-cmdf`, a list given to them (`(apply 'command ...)`, `MAJ:cmd-silent`) and a command sent as text (`vla-SendCommand`, `"_.DATALINK "`). Never a bare English name (`"undo"`, `"-layer"`, `"PEDIT"`, `"y"`).
- The values given to a prompt stay as they are: a layer name, a pattern, a point, a number, `""`. A keyword kept in a variable gets its `_` there (`*plt "_P"` in Make Layers).
- The commands of DynALisp itself (`Dyl-*`, `Pst-*` and their aliases) are Lisp commands, the same in every language: a macro of the ribbon runs them as they are.

*Why: a French (or any other) AutoCAD reads a bare name in its own language: `"undo"` is not one of its commands and `"y"` not one of its answers (it asks O/N), so the program stops there. `_` makes every AutoCAD read the English name, and `.` runs the built-in command even when a program redefined it (as Command Optimizer redefines QSAVE and PLOT).*

### Preset aliases

The alias of a Quick Draw preset tells how it draws: `PL-*` for a preset drawn with a polyline, `QD-*` for one that asks its method when drawn (the default for now). Quick Shape presets use `QS-*`. Pick the prefix to match when a preset's method changes or a preset is added.

## Presets And Materials

- The preset tools (Quick Draw, Quick Shape...) are built on the shared preset engine (`Remote\Dyl-Presets.lsp`): one window, the same list, filter, sort and buttons for every tool.
- The hatch parameters live in **materials** (`Remote\Dyl-Materials.lsp`, `Res\Materials.csv`), shared by id: `QD-BRICK`, `PL-BRICK` and a brick shape all use the one *Brick* material, so editing it changes them all.
- The **groups** of the presets and of the hatch presets are one list, `Res\Groups.csv` (`Remote\Dyl-Groups.lsp`: `Remote>>Dyl:Groups`), edited in the **Preset Groups** window that the open button left of every Group list opens. A tool asks for it with `(groups . T)`, and reads the group of a row with `Remote>>Dyl:GroupCase`. A group renamed there is renamed in the files of every preset tool (`Remote>>Dyl:GroupsRename`) and in the presets of the windows open (`*grp:renames*`).

*Why: a preset and its hatch preset are found by their group (the Hatch preset list shows the hatch presets of the group of the preset), so every window must list the same groups, with the same names.*

- In the windows, the messages and the docs, a material is a **hatch preset**: the **Hatch Presets** window (command `Dyl-HatchPresets`), *Hatch preset:* and its open button in the preset windows. The code and the data files keep *material* (`Remote>>Dyl:Material*`, `*mt:*`, `Materials.csv`, the `mt-*` ids, `Remote\Dyl-Materials.lsp`), so the users' copies and older files keep working.

*Why: users pick a hatch, so the windows name it after what it is; the code keeps its names so nothing that reads the files breaks.*

- A material is **only the hatch** (pattern, scale, hatch layer key, optional settings). How it is drawn (method, Linear width, Polygon sides...) is a **behavior of each preset**, set in the **Behaviors** box of the Quick Draw window, never in the Hatch Presets window:
  - The box is defined in `Remote\Dyl-Materials.lsp`: `*mt:behaviordcl*`, `*mt:behaviortiles*`, `Remote>>Dyl:MaterialDlgBehaviorsInit`, `Remote>>Dyl:MaterialDlgBehaviors`, and its *Pick...* button `Remote>>Dyl:MaterialOriginPick`.
  - When a preset is drawn, its behaviors are put in the behavior columns of its material (`Dyl:QuickDrawMat`). Those columns of `Materials.csv` are no longer edited: they are only read to give their behaviors to the presets of older files.
  - A new behavior is a column of `QuickDraw.csv` (`*qd:tiles*`) and a slot of those material columns.
  - Quick Shape presets insert shapes and have no behaviors.
- The **border** (its layer key, the overrides of its properties, its transparency, *Has a border*) is a setting **of each preset** too, in the **Border settings** box of the Quick Draw and Quick Shape windows, never in the Hatch Presets window:
  - The box is defined in `Remote\Dyl-Materials.lsp`: `Remote>>Dyl:MaterialBorderDcl`, `*mt:bordertiles*`, `Remote>>Dyl:MaterialDlgBorderInit`, `Remote>>Dyl:MaterialDlgBorderState`, `Remote>>Dyl:MaterialDlgBorderStatus`.
  - The border columns of a preset follow the order of `*mt:bordertiles*` (`Remote>>Dyl:MaterialBorderTiles`). When a preset is drawn, they are put in the border columns of its material (`Remote>>Dyl:MaterialBorderPut`). Those columns of `Materials.csv` are no longer edited: they only give their border to the presets of older files and to the default presets.
  - A Quick Shape shape always has its border: no *Has a border* there.

*Why: two presets of one material can be drawn differently (`QD-BRICK` asks the method, `PL-BRICK` draws a polyline) and with different borders, so how a preset is drawn belongs to the preset, and a material stays the same hatch wherever it is used.*

- A setting that holds **a list** (the layers of an assembly of Quick Draw) is **one column of text**: its items divided by `|`, the fields of an item by `:`, never `;` or `,` (`Remote>>Dyl:MaterialLayers` reads it and drops the items that are not valid, `Remote>>Dyl:MaterialLayersStr` writes it). It is edited in a window of its own, opened by the open button beside its checkbox (the Assembly Layers window), never as a tile of the preset window, and the window shows a short summary of it beside that button (*3 layers*).

*Why: the CSV files are read with `;`, tab or `,` as their separator (whichever the header uses), so a list kept in one cell must not use them; one column keeps each preset one row, and a file of an older version still reads (the column is empty).*

- A material has **one scale**, in the units of its pattern, never an imperial and a metric one. `Remote>>Dyl:MaterialScale` converts it for the drawing:
  - The units of a pattern are found by `Remote>>Dyl:MaterialPatUnits`: `acad.pat` is imperial and `acadiso.pat` metric.
  - A pattern in its own `.pat` file is metric when the file says `;%UNITS=MM`, or when its file or folder name has *ISO* or *METRIC* in it. Otherwise it is imperial.
  - The scale of an imperial pattern is multiplied by 25.4 in a metric drawing (`MEASUREMENT` 1), and that of a metric pattern divided by 25.4 in an imperial one.
  - A `.pat` file DynALisp writes (`Dyl-RebuildPat`) says its units: `;%UNITS=MM` or `;%UNITS=INCH`.

*Why: One scale per material is one value to keep right, and a pattern draws at the same size in imperial and metric drawings.*

- A material is of one of two **types** (`Type` column, `*mt:types*`), as the patterns of Revit:
  - **Drafting**: a size on paper (a section hatch). It is annotative or follows the drawing scale (*Adaptive scaling*), so it plots at the same size at every scale.
  - **Model**: a real size in the model (a brick in elevation, a course of 2-2/3 in). Its scale makes the lines of its pattern real dimensions; it is never annotative nor adaptive (`Remote>>Dyl:MaterialFix` turns both off, the Hatch Presets window greys them out), so it plots smaller at 1:100 than at 1:50.
  - A material of an older file is Drafting.
- A **preview of a hatch** (a tile of a window) shows it as it plots: at its size on paper, 1:1 on the screen (a WPF unit is 1/96 in). A Drafting hatch that is annotative or adaptive at its own scale; any other at its scale divided by the drawing scale (`CANNOSCALE`). When fewer than about three repeats of its pattern fit in the tile (one brick), the preview zooms out just enough and shows the scale it uses in a corner (*1:100*), never a preview where the pattern cannot be seen.

*Why: a section hatch and an elevation are not scaled the same way: one keeps its size on paper, the other its size in the building. A preview that shows the hatch as it plots tells the user what they will get, and one zoomed out says so.*

- The `G-DS-ANNO-STD-*` layer keys are kept for compatibility only (the display configurations of AutoCAD Architecture) and are **never the layer key of a material** (`*lk:nomaterial*`, `Remote>>Dyl:LayerKeyMaterial-p`):
  - The Hatch Presets window does not list them, and a double-click on one in the Layer Keys window opened from it is refused.
  - A material read with one gets `HATCH` in its place (`Remote>>Dyl:MaterialFix`).
  - A new key of that kind matches the pattern, or is added to it.

*Why: those keys put objects on the screening and non-plotting layers of AutoCAD Architecture, never on the layer of a hatch or its border.*

## Settings

- Every setting is in the **Settings window** (`Dyl-Settings`, Settings region of `dynalisp.mnl`, `Modules\Dynalisp\Res\Dyl-Settings.xaml`), never in a separate dialog or command of its own. It holds settings only, no list of commands to run.
- The window keeps **on/off toggles**, in three sections after **Environment**: **Reactors** (the master switch, then one toggle per reactor, each with a short grey description under it), **Overrides** (Drawing Settings, Commands, File Preferences, System variables, Display) and **Updates** (Install updates automatically). A toggle with more settings has a small square *open* button that opens them in their own window, greyed out while the toggle is off.
- Every setting applies to **all drawings**, never to one drawing only: it is a `Dynalisp*` user setting (`getenv` / `setenv`). Open drawings catch up when they become current (Settings sync), applying only what changed since they last synced. Where a value can also be chosen per drawing (the draw order preset), the setting is the preferred default.
- Every on/off setting is **off on a new installation**, and on only once the user turns it on: read it with `(= "1" (getenv "Dynalisp..."))`, never `(/= "0" ...)`.
- **Environment**, the first section, holds the choices about DynALisp itself, not the drawings: the **Language** of DynALisp (`DynalispLanguage`, `Dyl:Lang` in the Settings region of `dynalisp.mnl`), the language its docs open in, and nothing else: the ribbon and the phases are always in the language of the AutoCAD installed (`Dyl:LangAcad`, see [Ribbon](#ribbon)). A popup, not a toggle: until it is saved, it is the language of the AutoCAD installed (the lcid ending its product key), English for a language DynALisp does not have yet. It is never the Language of the File Preferences (`DynalispPrefLanguage`), which sets the content folders and dictionaries of the drawings: the two are chosen apart. A new language is a row of `*dyl:langs*` (and of `LANGS` in `Installer\Docs\BuildDocs.py` for its docs, its footer in `FOOTER` of `Installer\Docs\BuildSite.py` for the home page of the website, `index.<code>.html`).
- DynALisp prefers **watching and enforcing defaults** (units and grid checked when each drawing opens) over commands to run by hand.

- A question that offers **Remember my answer and do not ask again** (e.g. updating a layer that differs from its layer key) saves the answer as settings of the Settings window: one on/off toggle per answer (*Update them without asking*, *Keep them without asking*: `DynalispLayerKeyUpdate`, `DynalispLayerKeyKeep`), one of them on at most, both off (asked) on a new installation. The Settings window shows the answer remembered and takes it back.

*Why: one place for every setting, and nothing changes in a drawing until the user asks for it; the language DynALisp speaks to the user is not the language of the drawings (an English office may draw in French), so each is chosen on its own; an answer remembered is a setting like any other, so it can always be seen and undone.*

## Reactors

- Never create a `vlr-*` reactor in Apps, Remote or the MNL: every reactor is in a **Reactor** folder.
- The Reactor folders are loaded by `Dyl:load` only while `DynalispReactors` is on (the master switch of Dyl-Settings); off, they are skipped entirely.
- Each Reactor file registers its stop function with `Dyl:ReactorsAdd`, creates nothing when `Dyl:ReactorsOn-p` is nil, and its document manager callback calls `Dyl:ReactorsStop` when the switch was turned off in another drawing.
- Each reactor has its own `Dynalisp*` setting, with a toggle and a short description in the Reactors section of Dyl-Settings. A reactor a command makes for a moment and removes when it runs again (the event count of `Dyl-Diagnostics`) needs no setting: it is in a Reactor file all the same, made only while the reactors are on, and removed by `Dyl:ReactorsStop`.
- Code in Remote or Apps that calls a Reactor function checks it is defined first: `(if Reactor>>Dyl:X ...)`.
- A reactor that counts the commands running (to act when the outer one ends, not after a transparent `'ZOOM`) sets its count back to 0 when a command starts with no other one running (`Dyl:CmdTop-p` in `dynalisp.mnl`), never relying on getting the end of every command it saw start.
- A reactor that watches the objects added (`:vlr-objectAppended`) is **active only while a command or a Lisp command runs**: it is added when one starts and removed when it ends (`Reactor>>Dyl:PhaseWatch`). Objects are also added with no command running (the Project Navigator palette of AutoCAD Architecture, as the first drawing of a session opens), and a Lisp call for each of them, in the middle of that work, froze AutoCAD until Escape was pressed.

*Why: a safe way to shut every reactor down at once, plus a setting for each one. A command whose end a reactor never gets (one run while the drawing opens, one ended in another drawing) would leave its count stuck above 0: the reactor would stop acting and keep collecting every object added, slowing AutoCAD down until a Lisp command reset it.*

## User Files

- The defaults of the editable data files (aliases, Startup Suite, presets, materials, layer keys, draw order and system variable presets, shape libraries...) are committed under `Contents`. The user's edits are saved to a copy at the same path under `DynALisp.bundle\User` (ignored by git), read in place of the default.
- Read a data file with `(Dyl:UserFile path)` and write it with `(Dyl:UserFileW path)`, never the raw default path. A folder whose files are added and deleted (presets, libraries) uses `Dyl:UserDir` / `Dyl:UserDirW` (whole-folder copy, marked by `_UserFolder.txt`). The API is in the UserFiles region of `dynalisp.mnl`.
- `Dyl-UserFiles` lists the copies, resets them, or makes one the default (how an edit is published to the committed defaults).
- **Saved settings** are a `DynALisp Settings <date>` folder: `DynALisp-Settings.txt` (the `Dynalisp*` user settings as `Name=Value` lines), `User\` and `Modules\MyTools\`. Export settings / Import settings of Dyl-UserFiles (`Dyl:SetsExport` / `Dyl:SetsImport`), the uninstall and the setup read and write the same format: change `dynalisp.mnl` and `Installer\DynALisp.iss` together. A setting that only means something on this computer (a stamp, a profile name, a path) goes in `*dyl:setslocal*` and `LocalSettings`, never saved.

*Why: the defaults stay in git, each user's edits stay out of it.*

## Project Files

- Data that belongs to a **project** (its revisions, the revisions of its sheets) is kept in the project itself, in a `DynALisp` folder beside the `.apj` of its Project Navigator project (`<project>\DynALisp\Revisions.csv`), never in a `Dynalisp*` setting or the `User` folder. The project of a drawing is the first folder holding a `.apj`, from the folder of the drawing up (`Remote>>Dyl:RevProject`); its sheets are the drawings of its sheet folder (`SheetLocation` of the `.apj`).
- A choice the whole team must share (the numbering of the revisions, per project or per sheet) is a **setting of the project**, in a file of that folder (`RevisionSettings.csv`), edited in the window of the tool, not in the Settings window. What works the same in every project (the title blocks and their attributes, `RevisionBlocks.csv`) stays a data file of DynALisp (see [User Files](#user-files)).
- The project files are CSV divided by `;`, in UTF-8 when AutoCAD can write it, and **read again just before they are written**, since another user may have changed them:
  - A file every drawing writes its rows to (`Sheets.csv`) is merged: only the rows of the drawings just updated are replaced (`Remote>>Dyl:RevSheetsMerge`).
  - A file edited in a window (`Revisions.csv`) is not saved when it changed since the window opened (its time, `Remote>>Dyl:RevStamp`): the window says so.
- The drawings of a project that are closed are changed with ObjectDBX, without opening them, and only the values that differ are written, so a drawing up to date is never modified. A drawing another user has open (its `.dwl`) is never changed: it is listed, and catches up the next time it is updated.
- What a drawing gets from the project is also kept in the drawing (the revisions of a layout in its XRecord), so a drawing copied or renamed keeps it; the project file wins when it has the drawing.

*Why: everyone who works on a project must see the same revisions, numbered the same way, wherever DynALisp is installed, and the data must move with the project, not with the computer. A project on a server is written by several users at once: a file read long before it is written would lose the work of the others.*

## Versions And Updates

- The version of DynALisp is the `AppVersion` of `PackageContents.xml`, and only there: Dyl-Info, the setup and the release all read it. Its `ProductCode` never changes.
- Each version has its section at the top of `CHANGELOG.md`: a `## <version> - <date>` heading, then one short line per change (plain ASCII: AutoCAD reads the file as is). Raise `AppVersion` and add its section in the same change.
- A release is a `v<version>` tag pushed to the source repository (`DynALisp.bundle`, private): the release workflow builds the setup (`Installer\Build.ps1`) and publishes the release to the public releases repository (`DynALisp.release`, `*dyl:relrepo*`), with the setup and `CHANGELOG.md` as files and its changelog section as notes. Users, the setup and Dyl-Info only ever link to the releases repository; only git clones use the source one.
- DynALisp is installed with the setup or as a git clone. The setup installs only the files git knows (never `User`, `MyTools`, the dev files or the `Docs` and `DevDocs` folders of the modules, which open on the docs website), removes the shipped folders before copying the new ones, waits for AutoCAD to close, and never installs over a git clone. A git clone is updated with `git pull`.
- The uninstall is **clean**: it offers to save the settings first (see [User Files](#user-files)), then removes the whole folder and everything DynALisp added outside it (the `Dynalisp*` user settings, the DynALisp profile, the paths into the folder in the AutoCAD profiles). Anything new that DynALisp adds outside its folder must be removed by the uninstall too (`CleanProduct` in `Installer\DynALisp.iss`).
- A .NET plugin that every version of AutoCAD needs (the clean startup, `Installer\Startup`; the windows, `Installer\Windows`) is one project built twice and committed: for .NET 8 (`Contents\Resources\<Name>.dll`, AutoCAD 2025 and later, `SeriesMin="R25.0"`) and for .NET Framework 4.8 with the references of AutoCAD 2015 (`Contents\Resources\Net48\<Name>.dll`, `SeriesMin="R20.0"` `SeriesMax="R24.3"`), a component of `PackageContents.xml` each. It defines a Lisp function the Lisp side checks before using it (`(if Dyl:CleanStartup ...)`), and a window greys out what it does when it is not loaded. A plugin that reaches into AutoCAD itself by reflection (the lines of the command line) does nothing when it does not find what it looks for. A plugin never relies on a Lisp call made while DynALisp loads: it reads the `Dynalisp*` settings it needs itself when it starts (`FixedProfile\General` of `UserRegistryProductRootKey`, as `DynALisp.Startup.dll` and `Translations.cs` do), and asks the Lisp side for the state of the drawing when AutoCAD is idle. Every class that holds a `LispFunction` or a `CommandMethod` is listed in an `[assembly: CommandClass(...)]` of the plugin: AutoCAD registers the methods of those classes only (a static class cannot be listed), and a Lisp function it never registered makes every `(if Dyl:X ...)` of the Lisp side do nothing, with no error.
- A file edited by DynALisp at run time never goes under `Contents` (see [User Files](#user-files)): an update replaces the shipped folders whole.

*Why: one version number for every reader, updates readable without a GitHub account while the source stays private, users told what changed on each update, the users' edits kept by every update, and nothing left behind by the uninstall unless the user saves it.*

## Git

Claude commits as the work goes, without being asked; it pushes, merges into `main` and tags only when asked.

- **Branches**: `main` always loads in AutoCAD, since git clones `git pull` it and releases are tagged from it.
  - Work of several steps (a new tool, a rename across files, a window rebuilt) goes on a branch made from `main` before its first edit: `feature/<name>`, `fix/<name>` or `refactor/<name>`, in lower case with hyphens (`feature/object-layer-keys`).
  - A change of one step (a small fix, a docs page, a convention) can go straight on `main`.
  - A branch is merged into `main` with `git merge --no-ff` once the user has tried it in AutoCAD and asks for it, then deleted. Work found on `main` at the start of a session that is not committed is committed first, or moved to its branch, before anything new.
- **Staging**: stage by path, only the files of the step (`git add <paths>`), never `git add -A` or `git add .`. Check `git status` before each commit:
  - A file the user changed that is not part of the step is left out, and named in the reply.
  - A file made by AutoCAD or a tool (a crash report, a `__pycache__`, a backup) is never committed: it goes in `.gitignore`.
- **Commits**: one commit per step that is done and leaves DynALisp loading, made when the step is done, never one commit for a whole session.
  - A step is committed whole: a tool with its docs page, its rows of `StartupSuite.csv` and `Aliases.csv`, its ribbon row with `DynALisp.cuix` built again, and the convention it brings in `CONVENTIONS.md`.
  - A rename is a commit of its own (`git mv`, then the lines that name it), before the file is edited, so that git follows its history.
  - The message is a short summary line in the imperative (*Add Object Layer Keys*, 72 characters at most), a blank line, then, when it helps, short lines on what changed and why; plain ASCII; it ends with the `Co-Authored-By` line.
- **Never**: force push, rebase or amend a commit already pushed, skip the hooks, or commit to `main` work that does not load yet. A version raised (`AppVersion` and its `CHANGELOG.md` section) is one commit of its own; the `v<version>` tag is pushed only when the user asks for the release.

*Why: `main` is what every git clone runs and what every release is built from, so it must always work; small commits by path keep each change easy to review and undo, keep the user's own edits and the files made by AutoCAD out of them, and let git follow a file through its renames.*

## Ribbon

- The DynALisp tab of the ribbon (`Contents\Resources\DynALisp.cuix`) is **generated** by `Installer\Ribbon\BuildRibbon.py`, never edited in the CUI editor: its buttons are in `Installer\Ribbon\Ribbon.csv`, their icons in `Installer\Ribbon\RibbonIcons.py`, their names, descriptions (tooltips) and children read from `StartupSuite.csv`.
- Every main command of the Dynalisp module has a button, in the panel of its group, with an **icon of its own** (16 and 32 px, stored in the CUIx). A new tool gets its row and its icon in the same change, then the script is run and `DynALisp.cuix` committed. The script warns about a main command missing from the ribbon or without an icon.
- The children (`Pst-*`) of a tool are listed under the arrow of its button, all of them or the ones picked by patterns when they are too many for one list (Layer Transfer, Drawing Scale). A child has an icon of its own only when it tells it apart (the colour of a phase, the eye of Show / Hide); otherwise it uses the icon of its main command.
- That button is a split button that **follows** the item picked last (`SplitFollow`, the main command first, as the Circle button of AutoCAD), never one that stays on the main command (`SplitNoFollow`): the face of a split button that does not follow shows only an image of the resources of AutoCAD, never one stored in the CUIx, so it would have no icon.
- Items that are not commands of their own (the groups of the Quick Draw Gallery) set a Lisp variable, then run the command (`@*qd:gallerygroup*=All|Phase|Section` in the Children column): the button keeps its name (`SplitFollowStaticText`) and runs the item picked last. The command reads the variable once and clears it, so typed at the command line it opens as usual.
- The pictures of the Ribbon docs page (`Docs\Plugins\Ribbon\*.png`, light and dark) and its Panels section are **drawn by `BuildRibbon.py`** (`Installer\Ribbon\RibbonPanels.py`) from the same panels and icons, never screenshots: they are committed with `DynALisp.cuix`. A drop-down added to the plugin is added to `PLUGIN` of `RibbonPanels.py` too.
- The tab is **in the language of the AutoCAD installed** (the lcid ending its product key, `Dyl:LangAcad`), never in the *Language* of Dyl-Settings, which is the language of the docs only. The CUIx is in English; the texts of another language are in `Installer\Ribbon\Ribbon.<code>.csv` (`Key;Name;Description`: `Panel:<title>`, a command, or an item of a variable, `PST-QUICKDRAWGALLERY=Section`; Name is the label shown, or the full name of a child, shortened as in English). `BuildRibbon.py` writes them by the UID of each item in `Contents\Resources\DynALisp.Ribbon.<code>.csv`, warns about a text missing, and draws the pictures of the docs page in each language (`Draw-fr.png`). The plugin puts them on the tab (`Translations.cs`, `Dyl:RibbonLang`, reading the lcid of the AutoCAD installed itself when it loads, and given it by `Dyl:LangRibbon` when DynALisp loads; `Dyl:RibbonLang` is on `LangCommands`, listed in `CommandClass`), again when AutoCAD makes the ribbon again, and translates its own drop-downs (`T.S`). A new button gets its row in each `Ribbon.<code>.csv` in the same change. In an AutoCAD older than 2025 the tab stays in English. A data file the plugin shows in a drop-down gives its text in another language in a `Description.<code>` column after the English `Description` (`Description.fr` in `Phase.csv`, `Dd1.csv`, `Dd2.csv`, `Major.csv` and `Minor.csv` of `Res\AEC\Standard`), read by `Host.Standard` (a field in quotes may hold a comma), the English text where a row has none; the file is UTF-8 with a BOM. A Lisp reader that shows such a text (the phases: `Remote>>Dyl:PhaseList`, for the status bar, the Layer Phase window and the command line) opens the file as UTF-8 (`(open f "r" "utf8")`, the code page of Windows and the English column when this AutoCAD cannot) and finds the column of the language of the AutoCAD installed (`Dyl:LangAcad`, as the tab) by its name; the other Lisp readers read the columns by position and keep the English ones.
- The icons are flat, as those of AutoCAD: dark outlines, light fills and the orange and teal of the logo, never a line alone in the dark ink (it disappears on the dark ribbon). Check them on both themes with `BuildRibbon.py --sheet`.
- A command that works on the objects selected can be added to the **right-click menu** of those objects in `Installer\Ribbon\ContextMenus.csv` (the alias of the object menu: `OBJECT_MTEXT` for one mtext, `OBJECTS_MTEXT` for several; AutoCAD adds them to its own menu; each menu gets a `POPnnn` alias first, as those of `acad.cuix`). Its macro has no `^C^C`, which would drop the selection, and the command reads the selection first (`(ssget "_I")`). The menu of the text editor itself cannot be changed.
- The tab fits a 1920 px screen: the tools used less often go to the slide-out of their panel (`>1` in the Stack column).
- A tool whose choices are drop-downs gets a **panel of its own**, named after the tool (*Layer Transfer*): its button that runs, its drop-downs, then its *Manager* button. In that panel the buttons have short names (*Transfer*, *Manager*), since the panel title names the tool. Inside a shared panel, a dividing line is a row with `|` as its Command in `Ribbon.csv`.
- A **state** the user must see while drawing (the active phase, auto-phase) is a **drop-down** of the ribbon, as the Layer drop-down of AutoCAD, never a split button (its face shows the item picked last, not the state). A CUIx holds no drop-down of its own:
  - `Contents\Resources\DynALisp.Ribbon.dll` (source in `Installer\Ribbon\Plugin`, .NET 8: AutoCAD 2025 and later) adds it at run time, in the panel of its tool (`PanelId` / `PanelTitle` of its part), next to the button of its tool, found by its UID (`RBN_DYL_CMD_<command>`, given by `BuildRibbon.py`) or its label (`Label`: *Transfer*), and again when AutoCAD rebuilds the ribbon.
  - The Lisp function that shows the state pushes it to the plugin after every change (`Remote>>Dyl:PhaseStatus` calls `Dyl:RibbonPhase`), only when the plugin is loaded (`(if Dyl:RibbonPhase ...)`): in an older AutoCAD, the button alone remains. A state of the drawing is kept per drawing, so a drawing made current shows its own. Picking an item runs the Lisp setter.
  - The choices of a tool can be drop-downs too (the Level, From and To of Layer Transfer), each after a short label (`Host.Labels`, as wide as the longest, so the drop-downs line up). Their lists follow the drawing (read again after each command and when a drawing is made current). Picking a value only chooses it: the button of the tool runs it (`Pst-TransferField`, named *Transfer* in `Ribbon.csv`), reading the choice from the plugin (`(if Dyl:RibbonTransfer ...)`), and asks for the values when there is no choice (no plugin, nothing picked yet). The window of the tool gets a button of its own, *Manager* in the panel of the tool (*<Tool> Manager*, as Quick Draw Manager, in a shared panel). The choices are view choices: kept for the session, never settings.
  - A button whose command works on the objects selected has `1` in the Selection column of `Ribbon.csv`: its macro has no `^C^C`, which would drop them. The plugin cancels the command running first (`^C^C`), and only then.
  - The plugin changes the ribbon **only when AutoCAD is idle with no command running** (`Host.OnIdle`). A Lisp call (`Dyl:RibbonPhase`), a command ended or a drawing made current only asks for it (`Part.Later`), never changes the ribbon at once: they come while DynALisp loads, from reactors and in the middle of commands (the startup commands of AutoCAD Architecture). Only an item the user picks runs a setter (`Host.Picks`: its list open or just closed); an item the ribbon changes on its own is shown again, once a second at most (`Later(1000)`), never in a loop.
  - The plugin reads the names of the drawing with the same rule as the Lisp that acts on them (`NcsName` of `TransferCombos.cs`, `Dyl-LayTransfer-Ncs`): change both together.
  - The DLL is built with `dotnet build Installer\Ribbon\Plugin -c Release`, AutoCAD closed (it keeps the DLL open), and committed with its source, as `DynALisp.cuix`.

*Why: the ribbon follows the commands of the Startup Suite with one script run, its docs pictures follow it in the same run, every tool can be found by its picture, and the CUIx stays the same file whoever builds it. The tab speaks the language of the AutoCAD around it, its panels beside those of AutoCAD, while the docs can be read in another one. A state shown in the ribbon must be the one new objects get, whoever changed it, or the user draws on the wrong phase. The ribbon changed in the middle of a command, or a drop-down set back each time the ribbon changes it, froze AutoCAD at startup.*

## Windows

- The windows of DynALisp are **WPF windows**, shown by `DynALisp.Windows.dll` (`Installer\Windows`): each one a `.xaml` file of the `Res` folder of its module, without code, its controls named by their key (`x:Name`), what they do said by the `dyl:Win.*` properties (`Engine\Win.cs`: rules, sub-windows, docs page). The Lisp shows it with `(Dyl:WinShow file vals)` (Windows region of `dynalisp.mnl`) and gets back the button that closed it with the value of every key:
  - A new window is a `.xaml` file, never a `.dcl`. A DCL window moved to WPF loses its `.dcl` and its DCL functions: no copy is kept, since DynALisp needs AutoCAD 2015 (the oldest the plugin loads in).
  - Nothing calls the Lisp back while a window is open: a button that must run Lisp closes it with its number (`dyl:Win.Close`), and the caller opens it again on the values it got (as `c:Dyl-Settings`).
  - Its look is the theme of the plugin (`Engine\Theme.xaml`), in the colours of the light or dark theme of AutoCAD (`COLORTHEME`, the `Dyl.*` brushes of `Theme.Brushes`): a section is a `GroupBox` (a card without border), an on/off setting a `CheckBox` (drawn as a switch, its description indented under its label), its description a `Dyl.Desc` text, keyed styles and brushes always as `{DynamicResource ...}`, never a colour written in the window file.
  - Its picture in the docs is drawn by `Installer\Windows\Shots`, without AutoCAD, never taken by hand: a window added or changed gets its row in `Shots.csv` and its sample values in `Samples\`, in the same change. The `Windows` workflow draws them on each push of a work branch that changes a window and commits those that changed to it: pull before pushing again.
  - The rules below written for DCL keep their purpose in WPF: the same labels, the same sections, the value boxes lined up at the right of their section, the open button beside its setting.
- The windows not moved yet are DCL; the LeeMac sample module keeps its own (they are the code of Lee Mac).
- Every DynALisp window has an **Open Docs** button (exactly that label, never "Documentation"), key `docs`, next to its OK / Cancel or Close buttons. In a window file, `<Button x:Name="docs" Content="Open Docs"/>`, its page named on the `Window` (`dyl:Win.Docs="Group\Page.htm"`); in DCL:
  `: button {label = "Open Docs"; key = "docs"; width = 12; fixed_width = true;}`
- After `new_dialog`, `(Dyl:DocsTile "Group\\Page.htm")` makes it open the page (relative to `Modules\Dynalisp\Docs`, or a full path): the window stays open, and the button is greyed out when the page is missing. The windows of the core use the pages of `Docs\Core`.
- A new window comes with its docs page. Small Yes/No and name prompts have no button.
- The docs are **two sets**, a page of each for every tool, with the same name:
  - The **User Guide** (`Docs`) is for the user, as Lee Mac's pages: what the tool does in a few sentences, *How To Use* in steps, its windows, its ribbon, what is good to know, its limitations and its commands and aliases. No file path, function, variable or setting name (but the labels the user sees and the commands typed). Every Open Docs button opens it.
  - It names the picture of its window and the GIF of a sample use in placeholders, `<!-- picture: images/<Page>-window.png -->` and `<!-- picture: images/<Page>-use.gif -->`, after its description. The website shows a picture once its file is in `images`, nothing before; `BuildDocs.py --missing` lists the pages still without.
  - The **Developer docs** (`DevDocs`) are for whoever reads or changes the code: the source files and the data (files, dictionaries, `Dynalisp*` settings), when each part loads, each command and reactor step by step through its functions, the functions another App can call, what `Dyl-Diagnostics` checks, and the technical limits. They start with a link to their User Guide page. Layer Phase (`Docs\Layer\Dyl-LayerPhase.htm`, `DevDocs\Layer\Dyl-LayerPhase.htm`) is the model of both.
  - A new tool gets both pages in the same change. A detail moves to the set it belongs to: how to use it in the guide, how it is made in the dev docs, never the same text in both.
  - The developer home of the website is `README.md`, and its conventions this file, both rendered by `BuildSite.py`: a link of theirs to a file that is not on the website keeps its text only, and is reported.
- The docs open on the **docs website**, https://samagior.github.io/DynALisp.docs/ (`*dyl:docsweb*`), never from the `Docs` folders, which the setup does not install:
  - They are edited only in this repository, in the `Docs` and `DevDocs` folders of each module. Every push to `main` that changes them publishes them (`.github/workflows/docs.yml`): `Installer\Docs\BuildSite.py` builds the website (the User Guide of each module in a folder of its own, the Developer docs under `dev/`, `docs.css` at its root, the User Guide home listing the modules at its root, a *User Guide | Developers* switch in the header of every page leading to the same tool in the other set) and the workflow pushes it to the public repository `samagior/DynALisp.docs`, whose GitHub Pages publish it. That repository is generated: it is never edited. A page the website has is never removed from it, even when it is renamed, moved or deleted in the docs: an installed version still opens it at the path of its own list.
  - A page is still named by its path in `Modules\<Module>\Docs` (`Dyl:DocsTile`, `Dyl:SuiteDocs`). The list of the pages of the website, `Contents\Resources\DocsPages.txt`, written by `BuildDocs.py` with the pages git knows only (never those of `MyTools`, ignored), is installed: a page of the list opens on the website (`Dyl:DocsTarget`), found by `Dyl:DocsFind` in place of `findfile`; a page the list does not have (the docs of a module of one's own, `MyTools`) opens from the computer.
  - A page of the LeeMac sample module begins with a note saying it is delivered for consistency purposes only, as the docs of the sample module, that the program and its description are the work of Lee Mac, who keeps all the credit for them, with a link to the original page on his website. `BuildDocs.py` reports a page without it.
  - `BuildDocs.py --check` writes nothing and fails when a page or `DocsPages.txt` is not up to date, or a LeeMac page has no credit: the docs workflow and `Build.ps1` run it, so a page added without running `BuildDocs.py` stops the publication and the setup instead of shipping a list that does not have it.
- The User Guide is **in English and French**: a page is `Page.htm` (English, the one every link and `Dyl:DocsTile` names) and its French copy `Page.fr.htm` beside it, in the same folder. The Developer docs are in English only (their FR switch is greyed out):
  - A docs page opens in the language of DynALisp (*Language* in the Environment section of Dyl-Settings, `Dyl:Lang`), English when the page has no copy in it. Every page is opened through `Dyl:SuiteDlgShell`, which calls `Dyl:DocsTarget` (Docs region of `dynalisp.mnl`).
  - Every page has the **EN | FR switch** at the top right of its header, greyed out for a language it has no copy in yet. `python Installer\Docs\BuildDocs.py` writes it, sets `<html lang>` and points the links of each page to the pages of its language; run it after adding, translating, moving or deleting a page, and commit what it changed (with `DocsPages.txt`). It reports the broken links and how many pages are translated (`--missing` lists the others).
  - A French page translates the text and keeps what DynALisp shows in English as it is: the labels of the windows, the commands, aliases, settings and file names, in English (*Open Docs*, *Save*, `Dyl-Settings`, `DynalispReactors`). The ribbon is translated: a French page names its panels and buttons by their French labels (*Dessin rapide*, *Transférer*). AutoCAD terms are those of the French AutoCAD (calque, hachure, ruban, groupe de fonctions, ligne de commande).
  - A change to a page that has its French copy is made in both, in the same change. A new page may come in English alone: its switch shows FR greyed out until its copy is added.
  - The Lee Mac pages of the LeeMac sample module are their author's: they stay in English.
- In a group of parameters, every **value box** (edit box, popup list) ends at the same distance from the right border of the group:
  - Each value is a `row` of its own, the box last in the row.
  - A box with a label and an `edit_width`, not fixed, is right-justified in the space of its tile.
  - A box after a checkbox is `fixed_width = true`, and the checkbox (a `width`, not fixed) takes the rest of the row.
  - Two values never share a row.
- A group divided into sub-sections has a **dividing line**, drawn like the borders of the groups, over the title of each one (a `text` ending with `:`, such as *Layer key overrides:*):
  `: image {key = "..."; height = 0.8; fixed_height = true; color = -15;}`
  After `new_dialog`, `(Dyl:LineTile key)` (Docs region of `dynalisp.mnl`) draws it.
  A sub-section at the top of a column of the group has its title only, without the line: the border of the group is just above it.
  The two columns of a group are divided by the same line, vertical, between them (an image narrow and as tall as the columns, drawn by `Dyl:LineTile` too):
  `: image {key = "..."; width = 2; height = 1; fixed_width = true; color = -15;}`
- The rows of a group are **dense and balanced**. A group as tall as its neighbours never spreads its extra height between its rows:
  - Each sub-section is a `: column { fixed_height = true; ... }`, its dividing line and title included.
  - A `: spacer { }` between the sub-sections takes the extra height, spread evenly, and the last row ends at the bottom of the group.
  - A group without sub-sections ends with that spacer instead.
- Adding or removing a parameter **rebalances the window**:
  - The columns of groups stay about the same height. When one gets taller by more than a couple of rows, a sub-section moves to the shorter column if it fits there. When the groups no longer balance side by side, they go one under the other, each split in two columns: the basic settings and the layer key overrides on the left, the optional settings on the right (the Hatch settings of the Hatch Presets window).
  - The list heights and the docs follow.
- The **view choices** of a window (the sort of its list, the group it shows) are not settings: they stay in the window, never in the Settings window. They are kept for the session, or, with a **Set default** button beside them, saved as the one the window opens on: a `Dynalisp*` user setting of the tool (`DynalispPresetShow<tool>` for the Show group of the preset windows), off (All) until the user sets it.
- A window that lists items and edits the selected one (presets, materials, layer keys, rules...) lets **several items be selected** in its list (`multiple_select = true`; Ctrl / Shift click), to edit them at once:
  - The fields show the item clicked first (the one shown). A value changed is given to every item selected; their other values are left as they are.
  - A value unique to each item (name, key), Copy, and the values edited line by line (a list of layers) are for one item only: greyed out while several are selected. Delete and Reset act on every item selected.
  - The heading of the fields gives their number (*Parameters (3 selected)*).
  - The code keeps the item shown (`pst:idx`) and the items selected (`pst:sel`). A field's action gives its value to all of them (`Remote>>Dyl:PresetDlgPut`); committing the fields (before changing the selection) writes the item shown only.
  - A window that edits through an *Add* button (a value typed for one item, as System Variables) lets several be selected to Remove them at once.
- A button beside a setting that opens the window editing it (a sub-window, the AutoCAD color dialog...), or the file it comes from (the `.pat` file of a pattern), is the square **open button** of the Settings window, never a `...` button. It goes just to the left of the value box it edits:
  `: image_button {key = "..."; height = 1; fixed_height = true; aspect_ratio = 1; fixed_width = true; color = -15;}`
  In a window file, `<dyl:OpenButton x:Name="..."/>`, greyed out by a rule (`dyl:Win.EnabledBy`).
- After `new_dialog`, `(Dyl:MoreTile key on)` (Docs region of `dynalisp.mnl`) draws its *open* icon. To grey it out or turn it back on, call it again with `on` nil or true in place of `mode_tile`, since `mode_tile` leaves the icon black. A button that does something else keeps a text label (*New...*, *Edit layer keys...*, *Pick...*).

- Windows are **minimal**, for a clean, modern look that is easy to approach: the fewest graphics, text and boxes that do the job.
  - Labels and list items are short, **never with text in parentheses** explaining them (*Sides*, not *Sides (Polygon)*; *Linear*, not *Linear (band along a line)*; *Transparency*, not *Transparency (0-90)*), and no description line under a field. The details are in the docs page that **Open Docs** opens.
  - What can be set is shown by the window itself: a value the current choice does not use (the method of a preset, a checkbox off) is greyed out, never explained.
  - A marker that warns about a value (*(not defined)*, *(missing hatch preset)*) is not an explanation: it stays.
  - The docs name each setting with its label, and explain it there.

*Why: a WPF window looks like the rest of Windows and its picture is drawn from its file, without AutoCAD; a window file without code keeps the Lisp in charge, as with DCL; every window leads to its documentation, in the language the user works in when it is translated, read on a website that anyone can reach without installing DynALisp and that a lighter setup leaves out of the installation, a list is shown the way the user picked it where the list is (and opens that way again once set as the default), a setting that opens its own window looks the same in every window, the values of a group read as one column, its sub-sections look like the groups, a window stays balanced as it changes, many items get the same change in one go, and a window is read at a glance, its explanations kept in one place, the docs.*

## Diagnostics

- What goes wrong is found with **`Dyl-Diagnostics`** (`Apps\Troubleshooting`): one section per part (DynALisp, AutoCAD, Conflicts, Startup Suite, Settings, Reactors, Drawing), each a `dg:s-*` function and a `Pst-Diagnostics*` child run alone, all of them in the full report.
- A tool that adds a startup step, a reactor, a data file, a setting or a way to conflict with other programs **adds its check** to the section it belongs to, in the same change: a problem is a `dg:bad` line (`[!]`, listed again at the top of the report), what is only worth knowing a `dg:note`.
- The startup keeps what it did for the report: its time, warnings and notes (`*dyl:startms*`, `*dyl:startwarn*`, `*dyl:startnote*`) and the Remote and Reactor files that failed to load and their time (`*dyl:loaderrs*`, `*dyl:loadtimes*`). A new startup step goes through `Dyl:StartupStep`, so its errors are kept.
- A report is **written to a text file** of `%TEMP%` and opened in the text editor (`dg:write`, `dg:open`), never printed on the command line, which keeps only what to do next.
- A report never holds the user's profile folder, user name or computer name (`dg:anon`), since it is sent in a **public** GitHub issue of the releases repository that the user opens, reads and submits; DynALisp never sends anything by itself. The drawing itself is never part of it.

*Why: a user can send a whole picture of their setup in one click, and a problem shows in the report the day its tool is added; a file reads, copies and attaches better than the command line; and nothing private is published without the user seeing it first.*

## Spell Dictionaries

- The custom dictionaries are `Res\Dictionaries\<code>.cus` (UTF-16 BE with BOM, CRLF, as AutoCAD writes them), each with its definitions file `<code>-def.csv` (UTF-8 with BOM, `;`), read by `Dyl-Dictionary`.
- Never re-set `DCTCUST` automatically to make AutoCAD read a changed dictionary: the user reloads it (restarts AutoCAD).
- Words added to a `.cus` go in both the default and its `User` copy (AutoCAD uses the copy and writes added words there); restart AutoCAD before using *Add to dictionary*, or AutoCAD writes its old list back.
- Every word of the `.cus` has a row in `-def.csv` (or is a form of one). Add only single real words or real hyphenated compounds (*pare-vapeur*) to the `.cus`, never phrases joined by hyphens; expressions of several words (*semelle filante*) go only in `-def.csv`, with the types `loc.n.m.`, `loc.n.f.`, `loc.adj.` or `loc.adv.`.

*Why: the spell checker checks each word separately, and the user controls when AutoCAD reloads the dictionary.*
