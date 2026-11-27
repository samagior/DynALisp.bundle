# ![DynALisp Banner](Contents/Resources/Icons/dynalisp-banner-readme.svg "DynALisp Banner")

[![Discord Server](https://img.shields.io/discord/1181042941859467284?logo=discord&logoColor=white)](https://discord.gg/hP2UEVpK)
[![Licence](https://img.shields.io/badge/License-GPL%20v3-blue.svg?)](http://www.gnu.org/licenses/gpl-3.0)
[![Powered by Claude](https://img.shields.io/badge/Powered%20by-Claude-D97757?logo=claude&logoColor=white)](https://claude.com/claude-code)

&nbsp;

The source of DynALisp, an open source AutoCAD plugin and development platform written in AutoLISP / Visual LISP, with .NET plugins where Lisp falls short. This page is for **programmers and power users**: how DynALisp is built, how to run it from a git clone, how to add your own tools, build its plugins and contribute.

To install DynALisp and use its tools, go to **[DynALisp](https://github.com/samagior/DynALisp)** (the setup and the releases) and the **[User Guide](https://samagior.github.io/DynALisp.docs/)**.

> **Warning: DynALisp is under heavy development.** Installing it is not recommended in its current state: commands, settings, data files and the APIs of its modules still change without notice, and `main` can break what you built on it. If you install it or build on it anyway, you do so at your own risk.

&nbsp;

## Overview

DynALisp ships as an Autodesk plugin bundle (`DynALisp.bundle`): AutoCAD loads it from its plugins folder, with its ribbon, its .NET plugins and `dynalisp.mnl`, which loads every module. On top of the tools it ships, it is a frame for your own:

- **Modules** - each collection of tools is a module folder under `Contents\Modules`, loaded and indexed the same way. Add yours beside the others.
- **The Startup Suite** - an index of every command, built from the Lisp files: each tool can be turned on or off, renamed with aliases and given a docs page, without touching its code (`Dyl-Suite`).
- **A sample module** - the LeeMac module turns over 100 existing programs by Lee Mac into DynALisp tools (main and child commands, aliases, shared subfunctions, a docs page each) without changing their code: the model for a module of your own.
- **Settings and data that stay yours** - the defaults of the data files (presets, aliases, layer keys...) are committed; every edit goes to a copy in a `User` folder that git ignores and every update keeps.
- **A subfunction library** - LeeMac and gileCAD, over 11,000 lines, loaded only when a tool needs them, and available in VS Code as snippets.
- **.NET where it counts** - the windows (WPF), the ribbon, the reading of the data files, the Assistant and the simulation are .NET plugins; the Lisp side checks they are loaded before calling them.

&nbsp;

## Requirements

- **AutoCAD 2025 (R25.0) or later**, on Windows (64-bit). AutoCAD LT has no AutoLISP interpreter (see [CADSTA](https://www.cadsta.com/)).
- **AutoCAD 2015 to 2024**: DynALisp 1.x, on the branch `release/1.x` (fixes only).
- **[git](https://git-scm.com/)**, to install from source and stay up to date.
- **[Visual Studio Code](https://code.visualstudio.com/)** with the [AutoCAD AutoLISP Extension](https://marketplace.visualstudio.com/items?itemName=Autodesk.autolispext), to edit the Lisp.
- **The [.NET 10 SDK](https://dotnet.microsoft.com/download)**, to build the .NET plugins (it builds both their .NET 8 and .NET 10 versions).
- **Python 3**, to build the ribbon (`pip install pillow`) and the docs website (`pip install markdown`).
- **[Inno Setup 6](https://jrsoftware.org/isinfo.php)**, only to build the setup on your computer.

## Install From Source

1. Close AutoCAD.
2. Clone the repository into the AutoCAD plugins folder, as `DynALisp.bundle`:

   ```powershell
   git clone https://github.com/samagior/DynALisp.bundle.git "$env:APPDATA\Autodesk\ApplicationPlugins\DynALisp.bundle"
   ```

3. Start AutoCAD and accept the security prompt if it asks to load DynALisp.

**Updates:** `git pull`, then restart AutoCAD. The setup never installs over a git clone, and the automatic updates are off for one. A clone holds what the setup leaves out: the `Docs` and `DevDocs` folders, the `Installer` sources and the VS Code workspace.

&nbsp;

## Commands For Power Users

Type `Dyl` in the command line to list the main commands. Those that customize DynALisp or help work on it:

| Command | What it does |
| --- | --- |
| `Dyl-Suite` | Turn each command on or off, edit its aliases, open its docs |
| `Dyl-Settings` | Every setting: environment, reactors, Assistant, overrides, layer keys, updates |
| `Dyl-UserFiles` | Your edited data files: open, reset, make one the committed default; export and import settings |
| `Dyl-PrepSuite` | Output prep: the steps run before saves, prints and REGEN |
| `Dyl-Reload` | Load the module commands again, as turned on in Dyl-Suite |
| `Dyl-SuiteUpdate` | Rebuild the command index (`StartupSuite.csv`) from every Lisp file |
| `Dyl-Diagnostics` | A report of the setup, the settings, the reactors and the drawing |
| `Dyl-VSCode` | Open the DynALisp folder in VS Code |
| `Dyl-RestoreCommands` | Use the native save, plot, publish, preview and regen commands this session |

&nbsp;

## Structure

```text
DynALisp.bundle
├─ PackageContents.xml       Autodesk bundle manifest (its AppVersion is the version of DynALisp)
├─ CHANGELOG.md              What's New: what each version brings to its users, shown by Dyl-Info
├─ CHANGELOG.fr.md           Its French copy
├─ CONVENTIONS.md            The rules every change follows; Conventions\: those of each topic
├─ Contents
│  ├─ Resources              Core: dynalisp.mnl, Startup Suite, aliases, ribbon, plugins (Net10\: .NET 10 builds), docs.css
│  └─ Modules
│     ├─ Dynalisp            The DynALisp tools
│     ├─ LeeMac              The sample module: the Lee Mac tools and subfunctions
│     ├─ gileCAD             The gileCAD subfunctions
│     └─ MyTools             Your own module (not in git)
├─ User                      Your edited copies of the data files (not in git)
├─ Licences                  Licences of the third-party code
├─ Installer                 The setup and the sources of everything generated (see below)
├─ .github                   The workflows: release, docs website, plugin builds and tests
└─ .vscode                   VS Code settings and subfunction snippets
```

Each module has the same folders:

- **Apps** - one Lisp file per tool, named as its main command, in a group folder (`Apps\Draw`, `Apps\Layer`...), indexed by the Startup Suite.
- **Remote** - shared code loaded at startup for every tool (subfunctions, settings readers). The Remote of the library modules (LeeMac, gileCAD) loads on demand, just before the first of their programs runs.
- **Reactor** - every reactor, loaded only while the DynALisp reactors are on.
- **Res** - the data files (CSV) and the windows (WPF `.xaml`, older DCL) of the module.
- **Docs** - the User Guide, one page per tool: what it does and how to use it (English and French).
- **DevDocs** - the Developer docs, one page per tool: how its code works (English).

`Installer` holds the sources of what is built:

| Folder | What it builds |
| --- | --- |
| `Core` | `DynALisp.Core.dll`: the core in .NET, reads the data files once per session for every drawing |
| `Windows` | `DynALisp.Windows.dll`: shows the WPF windows of the `Res` folders (`Dyl:WinShow`); `Shots`: their pictures for the docs |
| `Ribbon` | `DynALisp.cuix` and its icons (`BuildRibbon.py`), and `DynALisp.Ribbon.dll` (translations, drop-downs) |
| `Startup` | `DynALisp.Startup.dll`: the clean startup of the command line |
| `Assistant` | `DynALisp.Assistant.dll`: the Assistant palette and its tools, through Claude Code |
| `Simulation` | `DynALisp.Simulation.dll`: the simulation of a 2D detail, its calculation tested alone |
| `Assemblies` | The assemblies of Quick Draw, from `Walls.txt` and `Floors.txt` |
| `Docs` | The docs switch and index (`BuildDocs.py`) and the docs website (`BuildSite.py`) |
| `DynALisp.iss`, `Build.ps1` | The setup (Inno Setup) and its build script |

&nbsp;

## Your Own Tools

Add your tools as a module folder under `Contents\Modules` (`MyTools` is kept out of git, and the setup and **Export settings** keep it): it is loaded and indexed like the others. Follow the LeeMac module: one Lisp file per program, each with one main command (named as its file), its `Pst-*` child commands and short aliases, shared subfunctions in `Remote`, and a docs page per program. Then run `Dyl-SuiteUpdate` to index it, and turn its commands on in `Dyl-Suite`.

Open the folder in VS Code with `Dyl-VSCode` (it offers to install VS Code when missing). The workspace recommends the AutoLISP extension and adds two snippet files for the Lee Mac subfunctions: `LM-LocalSub` inserts one as local code, `LM-RemoteSub` as a call to its `Remote>>` copy. `.vscode\lmsnippets.py` regenerates them from `LM-Sub.lsp`.

Before writing a tool, read [CONVENTIONS.md](CONVENTIONS.md): command naming (`Dyl-*` main command, `Pst-*` children, aliases), where files go, settings, reactors, user files and git, then the file of `Conventions` for each topic the tool touches (its windows, its docs, its ribbon, its presets...).

&nbsp;

## Building

### The .NET Plugins

Each plugin is one project built twice: for .NET 8 with the references of AutoCAD 2025 (`Contents\Resources\<Name>.dll`, AutoCAD 2025 and 2026) and for .NET 10 with those of AutoCAD 2027 (`Contents\Resources\Net10\<Name>.dll`, AutoCAD 2027 and later, which is not binary compatible with 2025 and 2026). Both builds are committed, so a clone runs without building anything.

```powershell
dotnet build Installer\Windows -c Release
```

The Release build copies both DLLs to where `PackageContents.xml` loads them. Close AutoCAD first: it keeps the DLLs open. The AutoCAD references come from NuGet (`AutoCAD.NET`), so no AutoCAD is needed to build. On Linux, add `-p:EnableWindowsTargeting=true`.

What needs no AutoCAD is a library of its own, tested alone, and checked by a workflow on each push that changes it:

```powershell
dotnet test Installer\Core\Tests
dotnet test Installer\Simulation\Tests
```

### The Ribbon

`Contents\Resources\DynALisp.cuix` is written by `Installer\Ribbon\BuildRibbon.py`, never in the CUI editor:

- `Ribbon.csv` - the panels and buttons: the panel, the stack (empty: a large button; a number: small buttons stacked together; `>1`: a row of the slide-out), the command, and its children listed under its arrow.
- `RibbonIcons.py` - the icon of each command, drawn at 16 and 32 px. A child without an icon of its own uses the icon of its main command.
- `Ribbon.<code>.csv` (`Ribbon.fr.csv`) - the texts of the tab in another language, shown by the ribbon plugin in an AutoCAD of that language.
- `ContextMenus.csv` - the commands added to the right-click menus of AutoCAD.

Run `python Installer\Ribbon\BuildRibbon.py` after adding, renaming or removing a tool: it warns about a main command missing from `Ribbon.csv` or without an icon, and draws the pictures of the panels for the Ribbon docs page. `--sheet <file.png>` draws every icon on the light and the dark ribbon, to review them. Restart AutoCAD to see the new ribbon.

### The Docs

The docs are edited here, in the `Docs` (User Guide) and `DevDocs` (Developer docs) folders of each module; [Conventions/Docs.md](Conventions/Docs.md) says what goes in each. After editing a page, run `python Installer\Docs\BuildDocs.py`: it writes the language switch, links each page to the pages of its language, reports the broken links and writes `Contents\Resources\DocsPages.txt`. A push publishes them: `.github/workflows/docs.yml` builds the website with `BuildSite.py` and pushes it to the public repository [DynALisp.docs](https://github.com/samagior/DynALisp.docs), served at **https://samagior.github.io/DynALisp.docs/**. This README and the conventions are its developer home.

The pictures of the windows are drawn without AutoCAD by `Installer\Windows\Shots` (a row of `Shots.csv` each), on Windows or by the `windows.yml` workflow.

### The Setup

To build it on your computer: `powershell -ExecutionPolicy Bypass -File Installer\Build.ps1` (output in `Releases`). It installs only the files git knows.

&nbsp;

## Contributing

- **Read the conventions first.** [CONVENTIONS.md](CONVENTIONS.md) is the core, read for every change; the larger topics (presets and materials, windows, docs, ribbon, versions, Claude, simulation...) have their file in `Conventions`, read before changing what they cover. A new rule goes there, with its reason, in the same change.
- **Branches.** `main` always loads in AutoCAD. Work of several steps goes on a branch made from `main`: `feature/<name>`, `fix/<name>` or `refactor/<name>`. The changes of a period of work are tried in AutoCAD together, then merged into `main` as one pull request.
- **Commits.** One commit per step that is done and leaves DynALisp loading, staged by path (never `git add -A`). A tool is committed whole: its Lisp file, its docs pages, its rows of `StartupSuite.csv` and `Aliases.csv`, its ribbon row. A rename is a commit of its own.
- **Diagnostics.** A tool that adds a startup step, a reactor, a data file or a setting adds its check to `Dyl-Diagnostics`.
- **Problems.** Users report them on the [issues of DynALisp](https://github.com/samagior/DynALisp/issues), with the report of `Dyl-Diagnostics`.

### Releasing a Version

1. Raise `AppVersion` in `PackageContents.xml` and turn the `## Next` section of `CHANGELOG.md` and `CHANGELOG.fr.md` into its `## <version> - <date>` section, in a commit of its own. A change that users see adds its `### <title>` to `## Next` (both files) when it is merged: what they can do now and where to find it, with a picture and a link to its docs page (the format is at the top of `CHANGELOG.md`).
2. Push a tag of that version: `git tag v2.1`, then `git push origin v2.1` (1.x versions are tagged on `release/1.x`).

The [release workflow](.github/workflows/release.yml) checks the tag against `AppVersion`, builds the setup and publishes the release to the public [DynALisp](https://github.com/samagior/DynALisp) repository: the setup, `CHANGELOG.md` and `CHANGELOG.fr.md` as files, the section of the version as notes (its pictures and links pointed to the docs website). Dyl-Info and the automatic updates read that release without signing in to GitHub. The workflow needs the `RELEASE_TOKEN` secret: a fine-grained token with **Contents: Read and write** on the releases repository only (renew it when it expires, then run the workflow by hand with the tag).

&nbsp;

## Powered By Claude

[![Claude](https://img.shields.io/badge/Claude-Anthropic-D97757?logo=claude&logoColor=white&style=for-the-badge)](https://claude.com/claude-code)

DynALisp is developed with [Claude Code](https://claude.com/claude-code), Anthropic's coding assistant: the ribbon and its icons, the windows, the Quick Draw gallery and assemblies, the layer keys, the .NET plugins, the docs and the [conventions](CONVENTIONS.md) were written with it. The **Assistant** (`Dyl-Assistant`) and **Text Fix** (`Dyl-TextFix`) ask Claude itself, through the user's own Claude Code ([Conventions/Claude.md](Conventions/Claude.md)).

### Working on DynALisp with Claude Code

- **Start it in the bundle folder.** [CLAUDE.md](CLAUDE.md) loads [CONVENTIONS.md](CONVENTIONS.md) in every session, so each change follows the DynALisp rules without repeating them; Claude reads the file of `Conventions` of a topic before changing what it covers.
- **Ask for the result, one change at a time.** Name the tool and the window, say what should happen ("in Quick Draw, grey out the material when Assembly is checked"); a short request reviewed and tested beats a long one.
- **Plan the large changes first.** For a new tool or a window redesign, ask for a plan and answer its questions before any code is written.
- **Make new rules conventions.** When you agree on how something should always be done, ask Claude to add it to the conventions, with its reason: the next sessions will follow it.
- **Test in AutoCAD.** Claude cannot run AutoCAD: reload (`Dyl-Reload`, or restart AutoCAD for the ribbon and `dynalisp.mnl`), try the change, and paste back the command line text of an error.
- **Review before merging.** Claude commits and pushes each step to the work branch as it goes; merging into `main` and tagging a release stay your call.

&nbsp;

## Why AutoLISP?

### Pros

- AutoLISP has been around for a long time, is well documented and has a large community library.
- No complex API, system or application to learn.
- The built-in interpreter makes it easy to get going: no compiling required.

### Cons

- Needs the built-in interpreter, not available in AutoCAD LT (you may want to take a look at the [CADSTA](https://www.cadsta.com/) plugin).
- No Visual LISP IDE or ActiveX (`vla-*`) functions on Mac.
- No access to the full AutoCAD .NET API: DynALisp adds .NET plugins where it needs it (windows, ribbon, data files).
- Only usable in AutoCAD products.
- Some dislike, or have a hard time reading, its parenthesis-heavy syntax that reads from the inside out.

&nbsp;

## Licence

DynALisp is released under the [GNU GPL v3](LICENSE). The Lee Mac tools keep their own licence: see [LEE-MAC-LICENCE](Licences/LEE-MAC-LICENCE.md).

## Credit

- **Lee McDonnell** ; founder of [Lee Mac Programming](https://www.lee-mac.com/) and a highly helpful resource in the community.
- **Gilles Chanteau** ; founder of [gileCAD](https://gilecad.azurewebsites.net/Default.aspx) and yet another very helpful resource in the community, publisher of my AutoLISP bible: [Introduction à AutoLISP](https://apps.autodesk.com/ACD/en/Detail/Index?id=6145646386361353211&appLang=fr&os=Win32_64) (French only).
- **Jimmy Bergmark** ; founder of [JTB World](https://jtbworld.com/), creator of many plug-ins on the Autodesk App Store.
- **Arnold Higuit** ; maker of a very extensive course on Udemy: [Practical AutoLISP Programming - Beginner to Advanced](https://www.udemy.com/course/practical-autolisp-programming-beginner-to-advanced/). A sample is available on [YouTube](https://www.youtube.com/watch?v=OqD9iW_bp4U&list=PLQKJ4G-oY3jOZV0x8K3dlR--wGwaHPT1D) as well. Not recommended as a full play-through, as it is not the most entertaining, but very well structured and a good reference to keep on hand.
- **Claude** ; Anthropic's AI assistant, through [Claude Code](https://claude.com/claude-code): a partner for the code, the icons, the docs and the conventions of DynALisp (see [Powered By Claude](#powered-by-claude)).
- **Nikolay Raspopov** ; founder of [CADSTA](https://www.cadsta.com/) and creator of the [AutoCAD AutoLISP Extension](https://marketplace.visualstudio.com/items?itemName=NikolayRaspopov.AutoCAD-AutoLISP) for VS Code.
