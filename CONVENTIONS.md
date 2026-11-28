# DynALisp Conventions

The rules every program, window and data file of DynALisp follows. This file is the core, read for every change: the rules of the smaller topics in full, and for each larger topic its main rules and the file of `Conventions` that holds all of them, to read before changing what it covers. When a new convention is agreed, add it here or to the file of its topic, in its section, with the reason for it.

*Why: this file is read for every change, so it holds only what every change must know; the rules of a topic are read when work on it starts, and a session carries only the rules of its work.*

| Topic | Read before changing |
|---|---|
| [Presets And Materials](Conventions/PresetsAndMaterials.md) | Quick Draw, Quick Shape, the assemblies, the materials, the hatch presets, the groups, the previews of a hatch or the DynALisp data of an object |
| [Simulation](Conventions/Simulation.md) | The simulation, its zones, its climates or what it shows |
| [Project Files](Conventions/ProjectFiles.md) | Data kept with a project (the revisions) |
| [Versions And Updates](Conventions/VersionsAndUpdates.md) | The version, a release, the setup or the uninstall, or a .NET plugin |
| [Ribbon](Conventions/Ribbon.md) | The ribbon, its icons, its translations, its plugin or a right-click menu |
| [Windows](Conventions/Windows.md) | A window (WPF or DCL), its picture in the docs or the Manager |
| [Docs](Conventions/Docs.md) | A docs page, the docs website or their translation |
| [Claude](Conventions/Claude.md) | The Assistant, Text Fix or anything that asks Claude |
| [Spell Dictionaries](Conventions/SpellDictionaries.md) | A spell dictionary |

## Folders

Each module is a folder of `Contents\Modules\<Module>` (Dynalisp, LeeMac...), with these sub-folders:

- **Apps** - the commands of each tool, one Lisp file per tool, in a group folder (`Apps\Draw`, `Apps\Layer`...). Indexed by the Startup Suite (`Dyl-Suite`): turned on or off, with aliases and a docs page.
  - A file that uses the functions of an Apps file (Pick hatch of the Hatch Presets window, `rpat:rebuild-hatch` of `Dyl-RebuildPat.lsp`) checks it is turned on (`Dyl:SuiteFileOn-p`), asks to turn it on when it is off and turns it on (`Dyl:SuiteFileOn`), then loads it (`Dyl:SuiteFileLoad`) when its function is not defined yet. Never load an App that is turned off without asking.
- **Remote** - code loaded at startup for every App: shared functions (`Remote>>` prefix), module paths, the readers and setters of the settings (e.g. `Remote>>Dyl:DrawOrderAutoSet`). Remote files load in alphabetical order: a file that loads before `Dyl-Paths.lsp` must fall back to `(strcat *dyl:dyl "\\Res")` instead of `*dyl:dylres`.
  - The Remote folders of the **library modules** (`*dyl:libmods*`: LeeMac, gileCAD, over 11,000 lines of subfunctions) are **loaded on demand**, never at startup: once in a drawing (`Dyl:LibsLoad`), just before the first App of a module other than Dynalisp loads (its commands are stubs that load them, `Dyl:LibAutoload`; `Dyl:SuiteFileLoad` loads them too). The Remote of Dynalisp and of `MyTools` still load at startup.
  - The Dynalisp module never needs a library module: a function of theirs that it uses is copied, unchanged and credited, into `Remote\Dyl-Basics.lsp` (`Remote>>LM:str->lst`, `Remote>>LM:csv->lst`...), and changed in both files together. Its Apps and Remote call only that copy, or a function of their own.
- **Reactor** - every reactor (`Reactor>>` prefix), loaded after Remote only while the DynALisp reactors are on (see [Reactors](#reactors)).
- **Res** - the data files (CSV) and dialogs (DCL) of the module, even when the code that uses them is in the core (e.g. `PrepSuite.csv`). Reached with `*dyl:dylres`.
- **Docs** - the **User Guide** of the module: one page per Apps file, in the same group folder (`Docs\Draw\Dyl-QuickDraw.htm`), plus `index.htm`, its pictures in an `images` folder beside the pages.
- **DevDocs** - the **Developer docs** of the module: the same group folders and page names (`DevDocs\Draw\Dyl-QuickDraw.htm`), plus `index.htm`.
  - Both are published on the docs website (see [Docs](Conventions/Docs.md)) and neither is installed by the setup: only a git clone has them.
  - The index of the Dynalisp module has two sections. **DynALisp** holds what every module shares, which is not an App: `Core` (the windows of the core), `Plugins` (the ribbon, the .NET plugins) and `Conventions` (the standards the programs follow, `LayerNaming.htm`). **Apps** holds the programs, one sub-heading per group folder.
  - A page that is not an App goes in the folder named after its sub-heading of the DynALisp section, never in a group folder of Apps. A new part of the core (a plugin, a standard) gets its page there and its row in that sub-heading. A sub-window of an App (the Band Settings of Quick Draw) is part of that program: its page goes beside the page of the App, in its group folder, named after its window file (`Docs\Draw\Dyl-QuickDrawBandSettings.htm` for `Res\Dyl-QuickDrawBandSettings.xaml`), and the page of the App links to it. The index of the module lists it too, in the rows just under its App (`<tr class="window">`, indented, *Window of Quick Draw* in place of its syntax), in the User Guide as in the Developer docs, so every page can be reached from the index.

`Contents\Resources` is kept for the core of DynALisp itself: `dynalisp.mnl`, the Startup Suite (`StartupSuite.csv`, `Aliases.csv`), the ribbon (`DynALisp.cuix`, `DynALisp.Ribbon.dll`), the core dialogs and `docs.css`. A file that belongs to a module never goes there.

The **LeeMac** module is the **sample module**: in its docs index, its pages, the README and the core windows it is described as a sample that showcases what DynALisp does with existing AutoLISP programs (indexed in the Startup Suite, main and child commands, aliases, shared subfunctions, a docs page per program), and the model for a module of one's own. Its programs keep their author and licence.

*Why: a module stays self-contained, and the core holds only what runs every module. A drawing that runs only the tools of Dynalisp never reads the libraries of the other modules, so it opens faster. The user decides which Apps are turned on, and an App turned on is only autoloaded: its functions are defined once one of its commands has run. The LeeMac module shows, with real programs, how any collection of AutoLISP code becomes a DynALisp module. In the docs, what runs every module is kept apart from the Apps, so a page found in a group folder is always the page of a program or of one of its windows, and a window is found under its program.*

## Commands

- Each Lisp file has **one main command**, named after what it does: `Dyl-*` in the Dynalisp module, `LM-*` in the LeeMac sample module.
- Its other commands (presets, variants) are **child commands named `Pst-*`**, run by their aliases. When a file has no natural main tool, its main command is a picker (`Dyl:ChildPicker` in `dynalisp.mnl`) that lists its children.
- Short names are **aliases** in `Resources\Aliases.csv`, never extra code (the original names of a program, e.g. Lee Mac's `BATTE`, are short names). An alias is **never a long name with a command prefix** (`Dyl-*`, `LM-*`, `Pst-*`): Dyl-Suite refuses it, and a former long name (`DYL-LAYFILTER`) is dropped, not kept as an alias. An alias never takes the name of a command of AutoCAD or of its Express Tools: a command always wins, so that alias is never defined. Dyl-Suite refuses such a name and says what has it (`Dyl:AliasTaken`), and an alias saved before its name was taken is reported with its command (*Alias TCOUNT of LM-TEXTCOUNT not defined: TCOUNT is already a command of another program...*). An original name that is taken gets another alias (`TXTCOUNT` for Lee Mac's `TCOUNT`).
- An alias (or a command) never takes the name of an **alias of `acad.pgp`** either (`DO` for `DONUT`, `CL` for `CENTERLINE`): Dyl-Suite refuses it (`Dyl:PgpAliases`), and Dyl-Diagnostics reports a command turned on or an alias defined with such a name. An original name that is one gets another alias (`ACL` for Lee Mac's `CL`).
- To remove a program, remove with its file its rows of `StartupSuite.csv` (the default and its `User` copy), its aliases in `Aliases.csv` (both), its docs page and its rows and links in the other docs pages (the docs index of its module), and its ribbon row. A custom preset command (`Pst-QuickDrawCustom*`) is a dynamic child, not a row of `StartupSuite.csv`: its aliases are kept while the preset exists.
- The Apps file is **named exactly as its main command**, same spelling and case (`c:Dyl-Materials` -> `Apps\Draw\Dyl-Materials.lsp`), and so is its docs page (`Docs\Draw\Dyl-Materials.htm`). A file that holds only functions, without a command (`LM-PrintList.lsp`), is named after what it holds.
- Command and file names are in **PascalCase**: each word starts with a capital and goes on in lower case, after the prefix (`Dyl-LayerExportToCsv`, `LM-ResetXrefLayers`), never all in capitals (`Dyl-EXPORTLAYERS`) or all in lower case (`dyl-list`). An AutoCAD term of one word is one word (`ByLayer`, `Linetype`, `Multileader`, `Xref`, `Mtext`); an acronym may keep its capitals (`LM-FormatDCL`, `Pst-QuickDrawCMU`). A name is spelled out, never abbreviated (`LM-ModelSpaceToPaperSpace`, not `LM-ms2ps`), and has no version number (`LM-DumpObject`, not `LM-DumpObjectV1-2`): the short names are aliases.
- To rename a command, update its rows of `StartupSuite.csv` before the Lisp file (so its Load value is kept); its short aliases follow it, and its former name is not kept. Rename its Apps file and its docs page with it, and update what names them: the `File` and `Path` columns of `StartupSuite.csv` (the default and its `User` copy), the `Dyl:DocsTile` calls, and the links of the other docs pages.

*Why: typing "Dyl" in the AutoCAD command line suggests only the main commands (a `DYL-*` alias would add a second, outdated name to that list). The child prefix must not contain "DYL" (the suggestion list matches mid-string), and a leading `_` or symbol is parsed by the command line, hence `Pst-`. A file named as its command is found from the command (and the command from the file) without opening the Startup Suite. PascalCase names read the same in the code, the docs and the AutoCAD command line, which shows them in capitals anyway. An alias of `acad.pgp` is what every AutoCAD user types: one of the two names would hide the other. An alias left behind by a program removed points to nothing and is reported by Dyl-Diagnostics on every computer.*

### Calling AutoCAD Commands

- Lisp code calls an AutoCAD command by its **international name**: the command with `_.` in front (`"_.-layer"`, `"_.undo"`, `"_.pedit"`), each keyword option and each Yes/No answer with `_` (`"_ON"`, `"_mark"`, `"_y"`, `"_n"`), in `command`, `command-s`, `vl-cmdf`, a list given to them (`(apply 'command ...)`, `MAJ:cmd-silent`) and a command sent as text (`vla-SendCommand`, `"_.DATALINK "`). Never a bare English name (`"undo"`, `"-layer"`, `"PEDIT"`, `"y"`).
- The values given to a prompt stay as they are: a layer name, a pattern, a point, a number, `""`. A keyword kept in a variable gets its `_` there (`*plt "_P"` in Make Layers).
- The commands of DynALisp itself (`Dyl-*`, `Pst-*` and their aliases) are Lisp commands, the same in every language: a macro of the ribbon runs them as they are.

*Why: a French (or any other) AutoCAD reads a bare name in its own language: `"undo"` is not one of its commands and `"y"` not one of its answers (it asks O/N), so the program stops there. `_` makes every AutoCAD read the English name, and `.` runs the built-in command even when a program redefined it (as Command Optimizer redefines QSAVE and PLOT).*

### Redefining AutoCAD Commands

- A command of AutoCAD that DynALisp replaces with a Lisp command of its own (the output prep of Command Optimizer: `QSAVE`, `SAVEAS`, `PLOT`...) is **never unknown**: UNDEFINE holds for the whole session, a Lisp command for one drawing only, so the commands undefined in the session are kept on the blackboard (`*maj:undefined*`), and a drawing that starts gives them an autoload of their Lisp file at once, at the top of `dyl:startup` (`MAJ:stubs`; given back with `_.REDEFINE` when the file is missing). A native command is undefined only with its Lisp command defined in that drawing (`MAJ:Redefine`), and only the commands whose state changes are run: none in a drawing opened after the first one.
- What DynALisp runs before the native command never stops it: its steps are caught (`MAJ:PrepSafe`), a step that fails is said on the command line, the command it left running cancelled, and the native command runs all the same.
- The native command is called with `initdia` when it shows a dialog, `QSAVE` too in a drawing never saved (`DWGTITLED` 0): called by Lisp without it, AutoCAD asks on the command line.

*Why: a drawing whose startup stopped halfway (an error in a file just changed) said *Unknown command* to SAVE, and a new drawing could not be saved at all; an error in a prep step must never cost the user their work. Giving the 11 commands back and undefining them again in every drawing took a third of a second at each startup.*

## Presets And Materials

- The preset tools (Quick Draw, Quick Shape, the assemblies, the materials, the hatch presets) share the preset engine (`Remote\Dyl-Presets.lsp`): one window, the same list and buttons for every tool.
- What an object is made of is a **material** (`mt-*`, `Materials.csv`), how it is hatched a **hatch preset** (`hp-*`, `HatchPresets.csv`), each shared by id; how a preset draws it (its method, border, hatch, band settings) belongs to the preset, never to its material.
- An object made of a material carries the id of its material (the `DYNALISP` extended data), never its values; the data of a material are in SI units, never made up.

The rest: [Conventions/PresetsAndMaterials.md](Conventions/PresetsAndMaterials.md), read before changing Quick Draw, Quick Shape, the assemblies, the materials, the hatch presets, the groups, the previews of a hatch or the DynALisp data of an object.

## Simulation

- The simulation of a 2D detail (`Dyl-Simulation`) follows the methods of the standards (ISO 10211, ISO 6946, ISO 13788), never one of DynALisp, and never guesses a value or a material: a detail with a problem is not simulated.
- What it shows over the drawing is transient; only `Pst-SimulationKeep` adds objects to the drawing.

The rest: [Conventions/Simulation.md](Conventions/Simulation.md), read before changing the simulation, its zones, its climates or what it shows.

## Settings

- Every setting is in the **Settings window** (`Dyl-Settings`, Settings region of `dynalisp.mnl`, `Modules\Dynalisp\Res\Dyl-Settings.xaml`), never in a separate dialog or command of its own. It holds settings only, no list of commands to run.
- The window keeps **on/off toggles**, in the sections after **Environment**: **Reactors** (the master switch, then one toggle per reactor, each with a short grey description under it), **Assistant** (what Claude may do in the drawing: *Allow Lisp*), **Overrides** (Drawing Settings, Commands, File Preferences, System variables, Display), **Layer keys** and **Updates** (Install updates automatically). A toggle with more settings has a small square *open* button that opens them in their own window, greyed out while the toggle is off.
- Every setting applies to **all drawings**, never to one drawing only: it is a `Dynalisp*` user setting (`getenv` / `setenv`). Open drawings catch up when they become current (Settings sync), applying only what changed since they last synced. Where a value can also be chosen per drawing (the draw order preset), the setting is the preferred default.
- Every on/off setting is **off on a new installation**, and on only once the user turns it on: read it with `(= "1" (getenv "Dynalisp..."))`, never `(/= "0" ...)`.
- **Environment**, the first section, holds the choices about DynALisp itself, not the drawings: the **Language** of DynALisp (`DynalispLanguage`, `Dyl:Lang` at the top of the Docs region of `dynalisp.mnl`, defined before the startup steps that open a window), the language its docs open in, and nothing else: the ribbon and the phases are always in the language of the AutoCAD installed (`Dyl:LangAcad`, see [Ribbon](Conventions/Ribbon.md)). A popup, not a toggle: until it is saved, it is the language of the AutoCAD installed (the lcid ending its product key), English for a language DynALisp does not have yet. It is never the Language of the File Preferences (`DynalispPrefLanguage`), which sets the content folders and dictionaries of the drawings: the two are chosen apart. A new language is a row of `*dyl:langs*` (and of `LANGS` in `Installer\Docs\BuildDocs.py` for its docs, its footer in `FOOTER` of `Installer\Docs\BuildSite.py` for the home page of the website, `index.<code>.html`).
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
- What DynALisp records for the user, that is not a copy of a default (the active time and the pins of the Start page, `Activity.cs`), goes in a folder of its own under `User` (`User\Start`): kept with the user's files by Saved settings and the setup, never listed by `Dyl-UserFiles`, never made a default, never in a report.
- **Saved settings** are a `DynALisp Settings <date>` folder: `DynALisp-Settings.txt` (the `Dynalisp*` user settings as `Name=Value` lines), `User\` and `Modules\MyTools\`. Export settings / Import settings of Dyl-UserFiles (`Dyl:SetsExport` / `Dyl:SetsImport`), the uninstall and the setup read and write the same format: change `dynalisp.mnl` and `Installer\DynALisp.iss` together. A setting that only means something on this computer (a stamp, a profile name, a path) goes in `*dyl:setslocal*` and `LocalSettings`, never saved.

- A data file read again and again (the presets, the layer keys) is **kept in memory** with the date and size of its files (`*pst:readcache*`, `*lk:readcache*`), read again only when one changed, and dropped by every writer of DynALisp (`Remote>>Dyl:PresetWrite`, `Remote>>Dyl:LayerKeyWrite`, `Remote>>Dyl:GroupsWriteOf`). A cache never outlives a change it cannot see: a file changed by hand or by another drawing has another date or size.
- A CSV data file of a module is read with `Remote>>Dyl:CsvRead` (`Remote>>Dyl:CsvHead` for its header), never with a new reader of its own, and written with `Remote>>Dyl:CsvWrite`, never `Remote>>LM:writecsv` alone: while **DynALisp.Core.dll** (`Installer\Core`, the core of DynALisp in .NET) is loaded, `Dyl:Data` reads each file once per session of AutoCAD for every drawing, read again when its date or size changes, and `Remote>>Dyl:CsvWrite` tells it a file was written (`Dyl:DataDrop`); without it, the Lisp side reads the file itself (`Remote>>Dyl:CsvReadLisp`), the same rows. The files of the Startup Suite, read by `dynalisp.mnl` itself (`StartupSuite.csv`, `Aliases.csv`), go through `Dyl:SuiteCsv` and `Dyl:SuiteCsvDone`, which do the same.
- What is made from the data files the same way in every drawing and is slow to make (the 860 assemblies read and fixed, what Quick Draw shows of them) is **kept for the session** on the blackboard with `Remote>>Dyl:SessionKept` (`*qd:asmreadbb*`, `*qd:asmshowsbb*`), with what it was made from that every drawing reads alike (`Remote>>Dyl:SessionStamps`): the date and size of its files (`Remote>>Dyl:PresetStamps`), the count of the data files written in the session (`*dyl:datawrites*`, raised by `Remote>>Dyl:CsvWrite`), the date of the defaults and of the files of its code, and what the caller adds (the units and system variables it depends on). A drawing finds it there instead of making it again.
- A data file made from the code (the index of the Startup Suite, `StartupSuite.csv`) is made again only for the files changed since it was written: when an Apps file is newer, `Dyl:Suite` parses that file again and keeps the commands of the others from the index; `Dyl-SuiteUpdate` parses them all.

*Why: the defaults stay in git, each user's edits stay out of it. A file of 860 assemblies parsed on each call made every tab of the Manager, and every object a reactor names, take seconds; the 200 Apps files parsed again after each `git pull` added 2 s to the next drawing opened; a file read by the .NET core is divided once for the whole session, not once in each drawing, and the drawings never see two versions of it; the assemblies read and what Quick Draw shows of them took 2.5 s in each new drawing. What DynALisp records for the user (the time spent in each drawing) is theirs: it stays on their computer with their other files, apart from the copies that can be published as defaults.*

## Project Files

- Data that belongs to a project (its revisions) is kept in a `DynALisp` folder beside its `.apj`, never in a setting or the `User` folder, and read again just before it is written.

The rest: [Conventions/ProjectFiles.md](Conventions/ProjectFiles.md), read before changing data kept with a project (the revisions).

## Versions And Updates

- The version is the `AppVersion` of `PackageContents.xml`, and only there; raise it with its `CHANGELOG.md` section, in a commit of its own.
- `CHANGELOG.md` (and `CHANGELOG.fr.md`) is **What's New**, for the users only: a change they see adds its `### <title>`, its text, a picture and the link to its docs page to `## Next` when it is merged; never how the code changed.
- DynALisp 2.0 runs in AutoCAD 2025 and later; 1.x, for AutoCAD 2015 to 2024, lives on the branch `release/1.x` (fixes only).
- A .NET plugin is built for .NET 8 (AutoCAD 2025 and 2026) and for .NET 10 (AutoCAD 2027 and later, `Net10`), both committed; the Lisp checks its function is defined before using it.
- The core of DynALisp in .NET (`Installer\Core`, `DynALisp.Core.dll`) takes over from Lisp one step at a time; each of its functions gives what the Lisp code it replaces gives (checked against witness files taken in AutoCAD, `Installer\Core\Tests\Witness`), and that code stays for when it is not loaded, except the windows of the Manager, whose Lisp goes once their tab is in .NET.

The rest: [Conventions/VersionsAndUpdates.md](Conventions/VersionsAndUpdates.md), read before changing the version, a release, the setup or the uninstall, or a .NET plugin.

## Git

Claude commits and pushes as the work goes, without being asked: each commit is pushed to the branch it was made on. It merges into `main` and tags only when asked.

- **Branches**: `main` always loads in AutoCAD, since git clones `git pull` it and releases are tagged from it.
  - Work of several steps (a new tool, a rename across files, a window rebuilt) goes on a branch made from `main` before its first edit: `feature/<name>`, `fix/<name>` or `refactor/<name>`, in lower case with hyphens (`feature/object-layer-keys`).
  - A change of one step (a small fix, a docs page, a convention) can go straight on `main`, or on the work branch already open for the batch.
  - A branch is merged into `main` with `git merge --no-ff` once the user has tried it in AutoCAD and asks for it, then deleted. Work found on `main` at the start of a session that is not committed is committed first, or moved to its branch, before anything new.
- **Batches**: the changes of a period of work go together on one work branch, committed step by step, and are tried in AutoCAD **once**, together, by the user: then the branch is merged as one pull request. A fix found while trying them goes on the same branch, never in a merge of its own; a new batch starts from `main` once the last one is merged.
- **Staging**: stage by path, only the files of the step (`git add <paths>`), never `git add -A` or `git add .`. Check `git status` before each commit:
  - A file the user changed that is not part of the step is left out, and named in the reply.
  - A file made by AutoCAD or a tool (a crash report, a `__pycache__`, a backup) is never committed: it goes in `.gitignore`.
- **Commits**: one commit per step that is done and leaves DynALisp loading, made when the step is done, never one commit for a whole session.
  - A step is committed whole: a tool with its docs page, its rows of `StartupSuite.csv` and `Aliases.csv`, its ribbon row with `DynALisp.cuix` built again, and the convention it brings in `CONVENTIONS.md` or the file of its topic.
  - A rename is a commit of its own (`git mv`, then the lines that name it), before the file is edited, so that git follows its history.
  - The message is a short summary line in the imperative (*Add Object Layer Keys*, 72 characters at most), a blank line, then, when it helps, short lines on what changed and why; plain ASCII; it ends with the `Co-Authored-By` line.
- **Never**: force push, rebase or amend a commit already pushed, skip the hooks, or commit to `main` work that does not load yet. A version raised (`AppVersion` and its `CHANGELOG.md` section) is one commit of its own; the `v<version>` tag is pushed only when the user asks for the release.

*Why: `main` is what every git clone runs and what every release is built from, so it must always work; a commit pushed at once is never lost with the computer or the session it was made in, while merging and tagging, which change what users get, stay the user's call; small commits by path keep each change easy to review and undo, keep the user's own edits and the files made by AutoCAD out of them, and let git follow a file through its renames; each merge is a `git pull`, an index of the Startup Suite made again and a test in AutoCAD for the user, so changes tried and merged in batches cost that once, not after every fix.*

## Ribbon

- The ribbon is generated by `Installer\Ribbon\BuildRibbon.py` from `Ribbon.csv`, never edited in the CUI editor: a new main command gets its row, its icon and its row in each `Ribbon.<code>.csv` in the same change.

The rest: [Conventions/Ribbon.md](Conventions/Ribbon.md), read before changing the ribbon, its icons, its translations, its plugin or a right-click menu.

## Windows

- A new window is a WPF `.xaml` file of the `Res` folder of its module, without code, shown with `Dyl:WinShow`, never a `.dcl`; its picture in the docs is drawn by `Installer\Windows\Shots` (a row of `Shots.csv`).
- Every window has an **Open Docs** button and its docs page; windows are minimal, their labels short, never explained in parentheses.
- A window is never seen before it is drawn (no white window): it is shown hidden until its layout has settled (`Engine\Reveal.cs`), as `Session.Show` and the Manager do for every window.

The rest: [Conventions/Windows.md](Conventions/Windows.md), read before changing a window (WPF or DCL), its picture in the docs or the Manager.

## Docs

- Every tool has two pages of the same name, its **User Guide** (`Docs`, for the user, English and French) and its **Developer docs** (`DevDocs`, for the code, English only), made in the same change as the tool.
- A page that has its French copy is changed in both; run `python Installer\Docs\BuildDocs.py` after adding, moving or translating a page, and commit what it changed.

The rest: [Conventions/Docs.md](Conventions/Docs.md), read before changing a docs page, the docs website or their translation.

## Claude

- A tool that asks Claude goes through Claude Code, signed in by the user, run isolated, never the API with a key of the user; it is off on a new installation, and every change it makes to a drawing is approved by the user first.

The rest: [Conventions/Claude.md](Conventions/Claude.md), read before changing the Assistant, Text Fix or anything that asks Claude.

## Diagnostics

- What goes wrong is found with **`Dyl-Diagnostics`** (`Apps\Troubleshooting`): one section per part (DynALisp, AutoCAD, Conflicts, Startup Suite, Settings, Reactors, Interface, Drawing), each a `dg:s-*` function and a `Pst-Diagnostics*` child run alone, all of them in the full report.
- A tool that adds a startup step, a reactor, a data file, a setting or a way to conflict with other programs **adds its check** to the section it belongs to, in the same change: a problem is a `dg:bad` line (`[!]`, listed again at the top of the report), what is only worth knowing a `dg:note`.
- The startup keeps what it did for the report: its time, warnings and notes (`*dyl:startms*`, `*dyl:startwarn*`, `*dyl:startnote*`), the time of each of its steps (`*dyl:steptimes*`, marked by `Dyl:StartupMark`: the time since the mark before; a window a step shows the user, What's new, is shown through `Dyl:StartupWait`, so the time it stays open is not counted) and the Remote and Reactor files that failed to load and their time (`*dyl:loaderrs*`, `*dyl:loadtimes*`). A new startup step goes through `Dyl:StartupStep`, so its errors and its time are kept.
- A report is **written to a text file** of `%TEMP%` and opened in the text editor (`dg:write`, `dg:open`), never printed on the command line, which keeps only what to do next.
- A report never holds the user's profile folder, user name or computer name (`dg:anon`), since it is sent in a **public** GitHub issue of DynALisp.bundle (`*dyl:gitrepo*`) that the user opens, reads and submits; DynALisp never sends anything by itself. *Report a problem* of the Start page makes the report itself (`*dg:forissue*`, `Dyl:StartPageIssue`): the user only says what happened, and still reads and submits the issue. The drawing itself is never part of it.

*Why: a user can send a whole picture of their setup in one click, and a problem shows in the report the day its tool is added; a file reads, copies and attaches better than the command line; and nothing private is published without the user seeing it first.*

## Spell Dictionaries

- The custom dictionaries are `Res\Dictionaries\<code>.cus` with their `<code>-def.csv`; `DCTCUST` is never set again automatically.

The rest: [Conventions/SpellDictionaries.md](Conventions/SpellDictionaries.md), read before changing a spell dictionary.
