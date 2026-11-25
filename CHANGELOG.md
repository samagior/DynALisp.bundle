# Changelog

The changes of each version of DynALisp, newest first. Dyl-Info shows them before an
update, and once after it. Each version is a `## <version> - <date>` heading (the
AppVersion of PackageContents.xml), then one short line per change.

## 2.0 - 2026-11-25

- DynALisp 2.0 needs AutoCAD 2025 or later; for AutoCAD 2015 to 2024, keep DynALisp 1.x (1.2), which gets fixes only.
- AutoCAD 2027: the plugins (windows, ribbon, clean startup, Assistant, simulation) have their .NET 10 build, which AutoCAD 2027 needs.
- The setup refuses a computer without AutoCAD 2025 or later, and says where to get 1.x.
- Dyl-Diagnostics: says which build of the plugins AutoCAD loads, and the path of a plugin not loaded.

## 1.2 - 2026-11-25

- The last version for AutoCAD 2015 to 2024: it gets fixes only. DynALisp 2.0 needs AutoCAD 2025 or later.
- An AutoCAD older than 2025 is offered the updates of 1.x only.
- Manager: the preset windows as tabs of one window, fast to switch, open while you draw.
- Simulation of a 2D detail: heat, vapour, condensation and monthly balance (ISO 10211, 6946, 13788).
- Assistant (Dyl-Assistant): ask Claude about the drawing, change it once you approve; Text Fix through Claude Code.
- Materials: Assign, Match and Show; code assemblies with their fire and sound ratings.
- Hatch Presets window in WPF; Drafting hatch previews always at 1:1.
- Windows fitted to the screen and resizable.
- A drawing starts in about 0.4 s: the LeeMac and gileCAD libraries load when first needed.
- Fixed: SAVE and SAVEAS could say Unknown command; Make Layers and Batch Insert.

## 1.1 - 2026-11-20

- Docs website: every Open Docs button opens https://samagior.github.io/DynALisp.docs/; the setup no longer installs the docs.
- The docs in two sets: a User Guide (English and French, how to use each tool) and Developer docs (how the code works).
- Language in Dyl-Settings > Environment: the language of the docs. The ribbon follows the language of the AutoCAD installed.
- Works in a French (or any other) AutoCAD: every AutoCAD command is called by its international name.
- Revisions: the revisions of a Project Navigator project and of its sheets, shared by the whole team.
- Ribbon drop-downs (AutoCAD 2025 and later): Auto-phase and Phase, Level, From and To of Layer Transfer.
- Dyl-Diagnostics: a report of the setup, the settings, the reactors and the drawing, to send in an issue.
- Clean startup (Dyl-Settings > Overrides): the command line keeps only the useful lines once AutoCAD has started.
- Hatch Presets (formerly Materials), shared Preset Groups, behaviors and border set on each preset, assembly layers.
- Pick hatch... of the Hatch Presets rebuilds a missing pattern from a hatch of the drawing.
- Commands renamed in PascalCase; their short aliases are kept.
- Fixed: AutoCAD Architecture froze on the first drawing with auto-phase on; reactors stuck after some commands.
- Quick Draw Gallery: every group listed, also the empty ones; keeps its first and last pages.
- New words in the French dictionary.

## 1.0 - 2026-11-09

- First release, installed with DynALisp-Setup-1.0.exe or cloned with git.
- About 40 DynALisp tools and over 100 tools by Lee Mac, each with its docs page.
- Dyl-Suite: turn each command on or off, edit its aliases, open its docs.
- Dyl-Settings: reactors, drawing settings, commands, file preferences, system variables, display.
- Dyl-UserFiles: your edits saved in the User folder, kept by every update; Export / Import settings to move them.
- Uninstall: offers to save your settings, then removes everything; the setup imports saved settings.
- Dyl-Info: checks for new versions, shows what changed, installs the update when AutoCAD closes.
- Automatic updates (Dyl-Settings > Updates): checked once a day, off until you turn them on.
