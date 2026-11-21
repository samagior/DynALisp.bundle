# ![DynALisp Banner](Contents/Resources/Icons/dynalisp-banner-readme.svg "DynALisp Banner")

[![Discord Server](https://img.shields.io/discord/1181042941859467284?logo=discord&logoColor=white)](https://discord.gg/hP2UEVpK)
[![Licence](https://img.shields.io/badge/License-GPL%20v3-blue.svg?)](http://www.gnu.org/licenses/gpl-3.0)
[![Powered by Claude](https://img.shields.io/badge/Powered%20by-Claude-D97757?logo=claude&logoColor=white)](https://claude.com/claude-code)

&nbsp;

## Overview

DynALisp is an open source AutoCAD plugin and development platform written in AutoLISP / Visual LISP. Use it as is, with its built-in tools, or as a base to build your own. It ships as an Autodesk plugin bundle, so it is easy to deploy, manage and customize: every tool can be turned on or off, renamed with aliases, and documented, without touching the code.

- **Ready-made tools** - about 40 DynALisp tools (drawing presets, layers, cleaning, output prep, setup...), each with its docs page.
- **A sample module** - the LeeMac module showcases what DynALisp does with existing AutoLISP programs: over 100 tools by Lee Mac, indexed, turned on or off, given aliases and docs pages, without touching their code. Use it as a model for your own module.
- **One window for every setting** - drawing settings, file preferences, system variables and reactors, applied to all drawings and off until you turn them on.
- **Your edits stay yours** - the defaults are in the repository, your changes are saved to a separate `User` folder, and can be reset at any time.
- **Built for developers** - a large library of subfunctions, available in VS Code as snippets to speed up writing new tools.

&nbsp;

## Requirements

- AutoCAD 2010 (R18) or later, on Windows. AutoCAD LT has no AutoLISP interpreter (see [CADSTA](https://www.cadsta.com/)).
- To edit the code: [Visual Studio Code](https://code.visualstudio.com/) with the [AutoCAD AutoLISP Extension](https://marketplace.visualstudio.com/items?itemName=Autodesk.autolispext).

## Installation

There are two ways to install DynALisp. Both put it in the AutoCAD plugins folder, as `DynALisp.bundle`, and both keep your edits (the `User` folder) when you update. `Dyl-UserFiles` > **Export settings** saves your edits and options to move them to another installation (**Import settings**).

### With the setup (to use the tools)

1. Download `DynALisp-Setup-<version>.exe` from the [latest release](https://github.com/samagior/DynALisp.release/releases/latest) of the public [DynALisp.release](https://github.com/samagior/DynALisp.release) repository and run it. It installs for your Windows user only (no admin rights), into `%APPDATA%\Autodesk\ApplicationPlugins\DynALisp.bundle`. Close AutoCAD first, or the setup waits for you to.
2. Start AutoCAD. Accept the security prompt if AutoCAD asks to load DynALisp.

Windows may warn about an unknown publisher (the setup is not signed yet): click **More info**, then **Run anyway**.

**Updates:** `Dyl-Info` tells you when a new version is out. **Update to...** shows what changed and installs it when you close AutoCAD. To install updates without asking, turn on **Install updates automatically** in `Dyl-Settings` (checked once a day). After an update, AutoCAD shows the changes once (they are in [CHANGELOG.md](CHANGELOG.md)). Uninstall it from Windows Settings > Apps: it offers to save your settings (your edited files, the `Dyl-Settings` options and your `MyTools` module) in a folder you choose, then removes everything DynALisp added. To get them back, pick the saved `DynALisp-Settings.txt` on the **Import Saved Settings** page of the setup, or use **Import settings** in `Dyl-UserFiles`.

### With git (to read or edit the code)

1. Close AutoCAD.
2. Clone the repository into the AutoCAD plugins folder, as `DynALisp.bundle`:

   ```powershell
   git clone https://github.com/samagior/DynALisp.bundle.git "$env:APPDATA\Autodesk\ApplicationPlugins\DynALisp.bundle"
   ```

3. Start AutoCAD. The bundle loads its ribbon (`DynALisp.cuix`) and runs `dynalisp.mnl`, which loads every module. Accept the security prompt if AutoCAD asks to load it.

**Updates:** `git pull`, then restart AutoCAD. `Dyl-Info` tells you when a newer version is out and shows what changed. The setup never installs over a git clone, and the automatic updates are off for one.

&nbsp;

## Getting Started

Type `Dyl` in the command line to see the main commands. The core commands:

| Command | What it does |
| --- | --- |
| `Dyl-Info` | Version, updates, links and the list of core commands |
| `Dyl-Suite` | Turn the module commands on or off, edit their aliases, open their docs |
| `Dyl-Settings` | Drawing settings, file preferences, system variables, reactors, commands |
| `Dyl-PrepSuite` | Output prep: the steps run before saves, prints and REGEN |
| `Dyl-UserFiles` | Your edited files (presets, aliases...): open, reset or make default |
| `Dyl-Docs` / `LM-Docs` | Open the docs of every module (the Docs button of the ribbon) / of the LeeMac sample module |
| `Dyl-Reload` | Load the module commands again, as turned on in Dyl-Suite |
| `Dyl-SuiteUpdate` | Rebuild the command index (`StartupSuite.csv`) from the Lisp files |
| `Dyl-VSCode` | Open the DynALisp folder in VS Code |
| `Dyl-RestoreCommands` | Use the native save, plot, publish, preview and regen commands this session |

Every window has an **Open Docs** button that opens its page on the docs website, **https://samagior.github.io/DynALisp.docs/**. The website has two sets, with a *User Guide | Developers* switch at the top of every page: the **User Guide**, what each tool does and how to use it, and the **Developer docs**, how its code works, whose home is this page. The User Guide is in English and French: they open in the language of DynALisp (*Language* in `Dyl-Settings`, the language of AutoCAD until it is set), and the EN | FR switch at the top right of each page changes it.

The docs are edited in this repository, in the `Docs` (User Guide) and `DevDocs` (Developer docs) folders of each module (`Contents\Modules\<Module>\Docs`); the [conventions](CONVENTIONS.md#windows) say what goes in each, and Layer Phase is the model of both. After editing a page, run `python Installer\Docs\BuildDocs.py`: it writes the switch, links each page to the pages of its language, reports the broken links and writes `Contents\Resources\DocsPages.txt`, the list of the pages of the website. Every push to `main` publishes them (`.github/workflows/docs.yml` builds the website with `Installer\Docs\BuildSite.py` and pushes it to the public repository [DynALisp.docs](https://github.com/samagior/DynALisp.docs)). The website also renders this README and [CONVENTIONS.md](CONVENTIONS.md) as its developer home (`pip install markdown` to build it locally). The setup installs that list, not the `Docs` and `DevDocs` folders: only a git clone has them.

The **DynALisp** tab of the ribbon has a button for each tool of the DynALisp module, in a panel per group (Draw, Layers, Layer Tools, Text, Cleaning, Navigate, Output, Setup, Utilities) and the core commands in the DynALisp panel. The **Quick Draw** button opens the Quick Draw Gallery (a tile with its hatch for each preset; its arrow opens it on a group), **Quick Draw Manager** the Quick Draw window. The arrow of a button lists its presets (the phases, the drawing scales...), and the button then runs the one picked last, as the Circle button of AutoCAD (the main tool is always first in the list); the tools used less often are in the slide-out of their panel (the arrow beside its title). A tool turned off in `Dyl-Suite` answers *Unknown command* when its button is clicked.

### DynALisp Tools

| Group | Tools |
| --- | --- |
| **Draw** | Quick Draw and Quick Shape (hatch, outline and layer presets drawn in one command), Materials, Shrinkwrap |
| **Layer** | Layer keys, sets, filters, groups and transfers, phases, draw order, CSV import / export, color and lineweight matching, pen colors |
| **Cleaning** | Color ByLayer, blocks ByBlock, data links |
| **Output** | Prep Drawing (layers, hidden objects, xrefs, data links, tables, draw order and regen before output), Command Optimizer |
| **Setup** | Units, grid, file preferences, system variable profiles |
| **Navigate** | Switch drawing scale |
| **Utilities** | Batch insert, count by layers, text prefix / suffix, quick select similar, group cluster, rebuild hatch patterns, viewport to paper space, spell dictionaries, text proofreading with Claude... |

Most tools come with presets (`Pst-*` child commands) and short aliases (`PL-*`, `QD-*`, `QS-*`...), listed in `Dyl-Suite`.

&nbsp;

## Structure

```text
DynALisp.bundle
├─ PackageContents.xml       Autodesk bundle manifest (its AppVersion is the version of DynALisp)
├─ CHANGELOG.md              The changes of each version, shown by Dyl-Info
├─ Contents
│  ├─ Resources              Core: dynalisp.mnl, ribbon, Startup Suite, aliases, core dialogs, docs.css
│  └─ Modules
│     ├─ Dynalisp            The DynALisp tools
│     ├─ LeeMac              The sample module: the Lee Mac tools and subfunctions
│     └─ gileCAD             The gileCAD subfunctions
├─ User                      Your edited copies of the data files (not in git)
├─ Licences                  Licences of the third-party code
├─ Installer                 The setup (Inno Setup) and its build script; Ribbon: the ribbon builder
├─ .github                   The release workflow
└─ .vscode                   VS Code settings and subfunction snippets
```

Each module has the same folders:

- **Apps** - one Lisp file per tool, in a group folder (`Apps\Draw`, `Apps\Layer`...), indexed by `Dyl-Suite`.
- **Remote** - shared code loaded at startup for every tool (subfunctions, settings readers).
- **Reactor** - every reactor, loaded only while the DynALisp reactors are on.
- **Res** - the data files (CSV) and dialogs (DCL) of the module.
- **Docs** - the User Guide, one page per tool: what it does and how to use it.
- **DevDocs** - the Developer docs, one page per tool: how its code works.

Add your own tools as a new module folder under `Contents\Modules`: it is loaded and indexed like the others. The LeeMac module is the sample to follow: existing programs, each with one `LM-*` main command, its `Pst-*` children and aliases, shared subfunctions in `Remote`, and a docs page per program. A personal module can be kept out of git (see `.gitignore`).

&nbsp;

## Development

Open the folder in VS Code with `Dyl-VSCode` (it offers to install VS Code when missing). The workspace recommends the AutoLISP extension and adds two snippet files, `LM-LocalSub` and `LM-RemoteSub`, for the Lee Mac subfunctions: insert a subfunction as local code, or as a call to its `Remote>>` copy loaded at startup. `.vscode\lmsnippets.py` regenerates them from `LM-Sub.lsp`.

Before adding a tool, read [CONVENTIONS.md](CONVENTIONS.md): command naming (`Dyl-*` main command, `Pst-*` children, aliases), where files go, settings, reactors, user files and windows. After adding or renaming a command, run `Dyl-SuiteUpdate` to index it.

### The ribbon

`Contents\Resources\DynALisp.cuix` is written by `Installer\Ribbon\BuildRibbon.py` (Python 3 with Pillow: `pip install pillow`), never in the CUI editor:

- `Installer\Ribbon\Ribbon.csv` - the panels and buttons: the panel, the stack (empty: a large button; a number: small buttons stacked together; `>1`: a row of the slide-out), the command, its children listed under its arrow (`*`, or patterns divided by `|`), and a name and description for a command that is not in `StartupSuite.csv`.
- `Installer\Ribbon\RibbonIcons.py` - the icon of each command, drawn at 16 and 32 px and stored in the CUIx. A child without an icon of its own uses the icon of its main command.
- `Installer\Ribbon\Ribbon.fr.csv` - the French texts of the tab (panel titles, button labels and tooltips): the plugin shows them on AutoCAD 2025 and later in a French AutoCAD (the tab follows the language of the AutoCAD installed, not the *Language* of `Dyl-Settings`, which sets the language of the docs only).
- `Installer\Ribbon\ContextMenus.csv` - the commands added to the right-click menus of AutoCAD: the menu (`OBJECT_MTEXT` for one mtext selected, `OBJECTS_MTEXT` for several...) and the command. Empty for now: the first menus made AutoCAD crash on the right click (see `BuildRibbon.py`).

Run `python Installer\Ribbon\BuildRibbon.py` after adding, renaming or removing a tool: it warns about a main command of the module missing from `Ribbon.csv` or without an icon. It also draws the pictures of the panels for the Ribbon docs page (`RibbonPanels.py`, into `Docs\Plugins\Ribbon`) and writes its Panels section; `--pictures` draws them only. `--sheet <file.png>` draws every icon, on the light and the dark ribbon, to review them. Restart AutoCAD to see the new ribbon.

### Releasing a version

1. Raise `AppVersion` in `PackageContents.xml` and add its `## <version> - <date>` section at the top of `CHANGELOG.md`, in the same commit.
2. Push a tag of that version: `git tag v1.1`, then `git push origin v1.1`.

The [release workflow](.github/workflows/release.yml) checks the tag against `AppVersion`, builds the setup with `Installer\Build.ps1` and publishes the release to the public [DynALisp.release](https://github.com/samagior/DynALisp.release) repository: the setup and `CHANGELOG.md` as files, its changelog section as notes. Dyl-Info and the automatic updates read that release, without signing in to GitHub. The workflow needs the `RELEASE_TOKEN` secret of this repository: a fine-grained token with **Contents: Read and write** on `DynALisp.release` only (renew it when it expires, then run the workflow by hand with the tag to publish again). To build the setup locally, install [Inno Setup 6](https://jrsoftware.org/isinfo.php) and run `powershell -ExecutionPolicy Bypass -File Installer\Build.ps1` (output in `Releases`).

&nbsp;

### Why AutoLISP?

#### Pros

- AutoLISP has been around for a long time, is well documented and has a large community library.
- No complex API, system or application to learn.
- The built-in interpreter makes it easy to get going: no compiling required.

#### Cons

- Needs the built-in interpreter, not available in AutoCAD LT (you may want to take a look at the [CADSTA](https://www.cadsta.com/) plugin).
- No Visual LISP IDE or ActiveX (`vla-*`) functions on Mac.
- No access to the full AutoCAD .NET API.
- Only usable in AutoCAD products.
- Some dislike, or have a hard time reading, its parenthesis-heavy syntax that reads from the inside out.

&nbsp;

## Powered By Claude

[![Claude](https://img.shields.io/badge/Claude-Anthropic-D97757?logo=claude&logoColor=white&style=for-the-badge)](https://claude.com/claude-code)

DynALisp is developed with [Claude Code](https://claude.com/claude-code), Anthropic's coding assistant: the ribbon and its icons, the Quick Draw gallery and assemblies, the layer keys, the docs pages and the [conventions](CONVENTIONS.md) were written with it. The **Claude Text Fix** tool (`Dyl-ClaudeTextFix`) uses Claude itself to proofread the texts of a drawing.

### Working on DynALisp with Claude Code

- **Start it in the bundle folder.** [CLAUDE.md](CLAUDE.md) loads [CONVENTIONS.md](CONVENTIONS.md) in every session, so each change follows the DynALisp rules (naming, folders, settings, windows, docs) without repeating them.
- **Ask for the result, one change at a time.** Name the tool and the window, say what should happen ("in Quick Draw, grey out the hatch preset when Assembly is checked"); a short request reviewed and tested beats a long one.
- **Plan the large changes first.** For a new tool or a window redesign, ask for a plan (plan mode) and answer its questions before any code is written.
- **Make new rules conventions.** When you agree on how something should always be done, ask Claude to add it to CONVENTIONS.md, with its reason: the next sessions will follow it.
- **Test in AutoCAD.** Claude cannot run AutoCAD: reload (`Dyl-Reload`, or restart AutoCAD for the menu and `dynalisp.mnl`), try the change, and paste back the command line text of an error. Describe what you see in the window when the layout is off.
- **Rebuild what is generated.** After a tool is added or renamed: `Dyl-SuiteUpdate` for the Startup Suite, and `python Installer\Ribbon\BuildRibbon.py` for the ribbon (Claude runs it when it changes the ribbon).
- **Review, then commit.** Read the diff before committing; Claude commits only when asked.
- **Keep keys out of the files.** Claude Text Fix reads its Anthropic API key from the `ANTHROPIC_API_KEY` environment variable (or asks for it, kept for the session only): never write a key in a Lisp, CSV or settings file.

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
