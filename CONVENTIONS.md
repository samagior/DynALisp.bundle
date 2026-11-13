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

The **LeeMac** module is the **sample module**: in its docs index, its pages, the README and the core windows it is described as a sample that showcases what DynALisp does with existing AutoLISP programs (indexed in the Startup Suite, main and child commands, aliases, shared subfunctions, a docs page per program), and the model for a module of one's own. Its programs keep their author and licence.

*Why: a module stays self-contained, and the core holds only what runs every module. The LeeMac module shows, with real programs, how any collection of AutoLISP code becomes a DynALisp module.*

## Commands

- Each Lisp file has **one main command**, named after what it does: `Dyl-*` in the Dynalisp module, `LM-*` in the LeeMac sample module.
- Its other commands (presets, variants) are **child commands named `Pst-*`**, run by their aliases. When a file has no natural main tool, its main command is a picker (`Dyl:ChildPicker` in `dynalisp.mnl`) that lists its children.
- Short names are **aliases** in `Resources\Aliases.csv`, never extra code (the original names of a program, e.g. Lee Mac's `BATTE`, are short names). An alias is **never a long name with a command prefix** (`Dyl-*`, `LM-*`, `Pst-*`): Dyl-Suite refuses it, and a former long name (`DYL-LAYFILTER`) is dropped, not kept as an alias. An alias never takes the name of a command of AutoCAD or of its Express Tools: a command always wins, so that alias is never defined. Dyl-Suite refuses such a name and says what has it (`Dyl:AliasTaken`), and an alias saved before its name was taken is reported with its command (*Alias TCOUNT of LM-TEXTCOUNT not defined: TCOUNT is already a command of another program...*). An original name that is taken gets another alias (`TXTCOUNT` for Lee Mac's `TCOUNT`).
- The Apps file is **named exactly as its main command**, same spelling and case (`c:Dyl-HatchPresets` -> `Apps\Draw\Dyl-HatchPresets.lsp`), and so is its docs page (`Docs\Draw\Dyl-HatchPresets.htm`). A file that holds only functions, without a command (`LM-PrintList.lsp`), is named after what it holds.
- Command and file names are in **PascalCase**: each word starts with a capital and goes on in lower case, after the prefix (`Dyl-LayerExportToCsv`, `LM-ResetXrefLayers`), never all in capitals (`Dyl-EXPORTLAYERS`) or all in lower case (`dyl-list`). An AutoCAD term of one word is one word (`ByLayer`, `Linetype`, `Multileader`, `Xref`, `Mtext`); an acronym may keep its capitals (`LM-FormatDCL`, `Pst-QuickDrawCMU`). A name is spelled out, never abbreviated (`LM-ModelSpaceToPaperSpace`, not `LM-ms2ps`), and has no version number (`LM-DumpObject`, not `LM-DumpObjectV1-2`): the short names are aliases.
- To rename a command, update its rows of `StartupSuite.csv` before the Lisp file (so its Load value is kept); its short aliases follow it, and its former name is not kept. Rename its Apps file and its docs page with it, and update what names them: the `File` and `Path` columns of `StartupSuite.csv` (the default and its `User` copy), the `Dyl:DocsTile` calls, and the links of the other docs pages.

*Why: typing "Dyl" in the AutoCAD command line suggests only the main commands (a `DYL-*` alias would add a second, outdated name to that list). The child prefix must not contain "DYL" (the suggestion list matches mid-string), and a leading `_` or symbol is parsed by the command line, hence `Pst-`. A file named as its command is found from the command (and the command from the file) without opening the Startup Suite. PascalCase names read the same in the code, the docs and the AutoCAD command line, which shows them in capitals anyway.*

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

- The `G-DS-ANNO-STD-*` layer keys are kept for compatibility only (the display configurations of AutoCAD Architecture) and are **never the layer key of a material** (`*lk:nomaterial*`, `Remote>>Dyl:LayerKeyMaterial-p`):
  - The Hatch Presets window does not list them, and a double-click on one in the Layer Keys window opened from it is refused.
  - A material read with one gets `HATCH` in its place (`Remote>>Dyl:MaterialFix`).
  - A new key of that kind matches the pattern, or is added to it.

*Why: those keys put objects on the screening and non-plotting layers of AutoCAD Architecture, never on the layer of a hatch or its border.*

## Settings

- Every setting is in the **Settings window** (`Dyl-Settings`, Settings region of `dynalisp.mnl`, `Modules\Dynalisp\Res\Dyl-Settings.dcl`), never in a separate dialog or command of its own. It holds settings only, no list of commands to run.
- The window keeps **on/off toggles**, in three sections: **Reactors** (the master switch, then one toggle per reactor, each with a short grey description under it), **Overrides** (Drawing Settings, Commands, File Preferences, System variables, Display) and **Updates** (Install updates automatically). A toggle with more settings has a small square *open* button that opens them in their own window, greyed out while the toggle is off.
- Every setting applies to **all drawings**, never to one drawing only: it is a `Dynalisp*` user setting (`getenv` / `setenv`). Open drawings catch up when they become current (Settings sync), applying only what changed since they last synced. Where a value can also be chosen per drawing (the draw order preset), the setting is the preferred default.
- Every on/off setting is **off on a new installation**, and on only once the user turns it on: read it with `(= "1" (getenv "Dynalisp..."))`, never `(/= "0" ...)`.
- DynALisp prefers **watching and enforcing defaults** (units and grid checked when each drawing opens) over commands to run by hand.

- A question that offers **Remember my answer and do not ask again** (e.g. updating a layer that differs from its layer key) saves the answer as settings of the Settings window: one on/off toggle per answer (*Update them without asking*, *Keep them without asking*: `DynalispLayerKeyUpdate`, `DynalispLayerKeyKeep`), one of them on at most, both off (asked) on a new installation. The Settings window shows the answer remembered and takes it back.

*Why: one place for every setting, and nothing changes in a drawing until the user asks for it; an answer remembered is a setting like any other, so it can always be seen and undone.*

## Reactors

- Never create a `vlr-*` reactor in Apps, Remote or the MNL: every reactor is in a **Reactor** folder.
- The Reactor folders are loaded by `Dyl:load` only while `DynalispReactors` is on (the master switch of Dyl-Settings); off, they are skipped entirely.
- Each Reactor file registers its stop function with `Dyl:ReactorsAdd`, creates nothing when `Dyl:ReactorsOn-p` is nil, and its document manager callback calls `Dyl:ReactorsStop` when the switch was turned off in another drawing.
- Each reactor has its own `Dynalisp*` setting, with a toggle and a short description in the Reactors section of Dyl-Settings.
- Code in Remote or Apps that calls a Reactor function checks it is defined first: `(if Reactor>>Dyl:X ...)`.
- A reactor that counts the commands running (to act when the outer one ends, not after a transparent `'ZOOM`) sets its count back to 0 when a command starts with no other one running (`Dyl:CmdTop-p` in `dynalisp.mnl`), never relying on getting the end of every command it saw start.

*Why: a safe way to shut every reactor down at once, plus a setting for each one. A command whose end a reactor never gets (one run while the drawing opens, one ended in another drawing) would leave its count stuck above 0: the reactor would stop acting and keep collecting every object added, slowing AutoCAD down until a Lisp command reset it.*

## User Files

- The defaults of the editable data files (aliases, Startup Suite, presets, materials, layer keys, draw order and system variable presets, shape libraries...) are committed under `Contents`. The user's edits are saved to a copy at the same path under `DynALisp.bundle\User` (ignored by git), read in place of the default.
- Read a data file with `(Dyl:UserFile path)` and write it with `(Dyl:UserFileW path)`, never the raw default path. A folder whose files are added and deleted (presets, libraries) uses `Dyl:UserDir` / `Dyl:UserDirW` (whole-folder copy, marked by `_UserFolder.txt`). The API is in the UserFiles region of `dynalisp.mnl`.
- `Dyl-UserFiles` lists the copies, resets them, or makes one the default (how an edit is published to the committed defaults).
- **Saved settings** are a `DynALisp Settings <date>` folder: `DynALisp-Settings.txt` (the `Dynalisp*` user settings as `Name=Value` lines), `User\` and `Modules\MyTools\`. Export settings / Import settings of Dyl-UserFiles (`Dyl:SetsExport` / `Dyl:SetsImport`), the uninstall and the setup read and write the same format: change `dynalisp.mnl` and `Installer\DynALisp.iss` together. A setting that only means something on this computer (a stamp, a profile name, a path) goes in `*dyl:setslocal*` and `LocalSettings`, never saved.

*Why: the defaults stay in git, each user's edits stay out of it.*

## Versions And Updates

- The version of DynALisp is the `AppVersion` of `PackageContents.xml`, and only there: Dyl-Info, the setup and the release all read it. Its `ProductCode` never changes.
- Each version has its section at the top of `CHANGELOG.md`: a `## <version> - <date>` heading, then one short line per change (plain ASCII: AutoCAD reads the file as is). Raise `AppVersion` and add its section in the same change.
- A release is a `v<version>` tag pushed to the source repository (`DynALisp.bundle`, private): the release workflow builds the setup (`Installer\Build.ps1`) and publishes the release to the public releases repository (`DynALisp.release`, `*dyl:relrepo*`), with the setup and `CHANGELOG.md` as files and its changelog section as notes. Users, the setup and Dyl-Info only ever link to the releases repository; only git clones use the source one.
- DynALisp is installed with the setup or as a git clone. The setup installs only the files git knows (never `User`, `MyTools` or the dev files), removes the shipped folders before copying the new ones, waits for AutoCAD to close, and never installs over a git clone. A git clone is updated with `git pull`.
- The uninstall is **clean**: it offers to save the settings first (see [User Files](#user-files)), then removes the whole folder and everything DynALisp added outside it (the `Dynalisp*` user settings, the DynALisp profile, the paths into the folder in the AutoCAD profiles). Anything new that DynALisp adds outside its folder must be removed by the uninstall too (`CleanProduct` in `Installer\DynALisp.iss`).
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
- The icons are flat, as those of AutoCAD: dark outlines, light fills and the orange and teal of the logo, never a line alone in the dark ink (it disappears on the dark ribbon). Check them on both themes with `BuildRibbon.py --sheet`.
- A command that works on the objects selected can be added to the **right-click menu** of those objects in `Installer\Ribbon\ContextMenus.csv` (the alias of the object menu: `OBJECT_MTEXT` for one mtext, `OBJECTS_MTEXT` for several; AutoCAD adds them to its own menu; each menu gets a `POPnnn` alias first, as those of `acad.cuix`). Its macro has no `^C^C`, which would drop the selection, and the command reads the selection first (`(ssget "_I")`). The menu of the text editor itself cannot be changed.
- The tab fits a 1920 px screen: the tools used less often go to the slide-out of their panel (`>1` in the Stack column).

*Why: the ribbon follows the commands of the Startup Suite with one script run, every tool can be found by its picture, and the CUIx stays the same file whoever builds it.*

## Windows

- Every DynALisp window has an **Open Docs** button (exactly that label, never "Documentation"), key `docs`, next to its OK / Cancel or Close buttons:
  `: button {label = "Open Docs"; key = "docs"; width = 12; fixed_width = true;}`
- After `new_dialog`, `(Dyl:DocsTile "Group\\Page.htm")` makes it open the page (relative to `Modules\Dynalisp\Docs`, or a full path): the window stays open, and the button is greyed out when the page is missing. The windows of the core use the pages of `Docs\Core`.
- A new window comes with its docs page. Small Yes/No and name prompts have no button.
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
- After `new_dialog`, `(Dyl:MoreTile key on)` (Docs region of `dynalisp.mnl`) draws its *open* icon. To grey it out or turn it back on, call it again with `on` nil or true in place of `mode_tile`, since `mode_tile` leaves the icon black. A button that does something else keeps a text label (*New...*, *Edit layer keys...*, *Pick...*).

- Windows are **minimal**, for a clean, modern look that is easy to approach: the fewest graphics, text and boxes that do the job.
  - Labels and list items are short, **never with text in parentheses** explaining them (*Sides*, not *Sides (Polygon)*; *Linear*, not *Linear (band along a line)*; *Transparency*, not *Transparency (0-90)*), and no description line under a field. The details are in the docs page that **Open Docs** opens.
  - What can be set is shown by the window itself: a value the current choice does not use (the method of a preset, a checkbox off) is greyed out, never explained.
  - A marker that warns about a value (*(not defined)*, *(missing hatch preset)*) is not an explanation: it stays.
  - The docs name each setting with its label, and explain it there.

*Why: every window leads to its documentation, a list is shown the way the user picked it where the list is (and opens that way again once set as the default), a setting that opens its own window looks the same in every window, the values of a group read as one column, its sub-sections look like the groups, a window stays balanced as it changes, many items get the same change in one go, and a window is read at a glance, its explanations kept in one place, the docs.*

## Spell Dictionaries

- The custom dictionaries are `Res\Dictionaries\<code>.cus` (UTF-16 BE with BOM, CRLF, as AutoCAD writes them), each with its definitions file `<code>-def.csv` (UTF-8 with BOM, `;`), read by `Dyl-Dictionary`.
- Never re-set `DCTCUST` automatically to make AutoCAD read a changed dictionary: the user reloads it (restarts AutoCAD).
- Words added to a `.cus` go in both the default and its `User` copy (AutoCAD uses the copy and writes added words there); restart AutoCAD before using *Add to dictionary*, or AutoCAD writes its old list back.
- Every word of the `.cus` has a row in `-def.csv` (or is a form of one). Add only single real words or real hyphenated compounds (*pare-vapeur*) to the `.cus`, never phrases joined by hyphens; expressions of several words (*semelle filante*) go only in `-def.csv`, with the types `loc.n.m.`, `loc.n.f.`, `loc.adj.` or `loc.adv.`.

*Why: the spell checker checks each word separately, and the user controls when AutoCAD reloads the dictionary.*
