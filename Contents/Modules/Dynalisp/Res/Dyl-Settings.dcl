// Dyl-Settings.dcl - Dynalisp settings dialog (Dyl-Settings command)
// Copyright (C) 2023  Samuel Martineau
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
// The drawing defaults are the unit and grid presets of
// Modules\Dynalisp\Remote\Dyl-DrawingSetup.lsp.
// The output prep window (dyl_prepsuite, opened by the Output prep button of
// dyl_settings and by Dyl-PrepSuite): toggle keys are
// t_<STEP>_<COLUMN>, the steps of MAJ:steps and the columns of MAJ:PrepCols: the
// save commands share the SAVE column, the print commands the PLOT one (MAJ:groups),
// PREVIEW and REGEN have their own.


prep_head : text {width = 11; fixed_width = true;}
prep_step : text {width = 46; fixed_width = true;}
prep_tog  : toggle {width = 11; fixed_width = true;}
set_label : text {width = 8; fixed_width = true;}
set_head  : text {width = 32; fixed_width = true;}
set_pop   : popup_list {width = 32; fixed_width = true;}
pref_label : text {width = 29; fixed_width = true;}
pref_pop  : popup_list {width = 37; fixed_width = true;}
// Reactors and Overrides: a setting with its open button, which opens the window that edits it (the
// toggles are as wide, so the buttons line up):
// Both one line high, so the rows and their descriptions sit close together. The open
// button is the square image button of every DynALisp window (a plain button cannot be
// made that small, the aspect ratio of 1 gives it a width equal to its height): its
// "open" icon is drawn by Dyl:MoreTile in dynalisp.mnl:
set_tog   : toggle {width = 38; fixed_width = true; height = 1; fixed_height = true;}
set_more  : image_button {height = 1; fixed_height = true; aspect_ratio = 1; fixed_width = true; color = -15;}
// Short description under a reactor setting, greyed out and indented by set_indent
// (the width of the checkbox box) so it lines up with the label of the setting. Both
// are text_parts (texts without margins) in a concatenation (a row without margins), so
// the line sits close under its setting; a spacer as the indent made the line taller:
set_indent : text_part {label = ""; width = 2.5; fixed_width = true; height = 1; fixed_height = true;}
set_desc  : text_part {width = 41; fixed_width = true; height = 1; fixed_height = true; is_enabled = false;}

dyl_settings
: dialog {label = "DynALisp - Settings";
    : column {
      // The reactors (Reactor folder of each module). DynALisp reactors (DynalispReactors,
      // see Dyl:ReactorsOn-p) turns them all off: the Reactor folders are then not loaded and
      // the reactor settings under it are greyed out (Dyl:SetDlgRea):
      : boxed_column {label = "Reactors";
        // What the section is, greyed out like the descriptions of its settings:
        : set_desc {label = "Act on new objects as you draw.";}
        : spacer {height = 0.5;}
        : set_tog {label = "DynALisp reactors"; key = "rea";}
        : concatenation {: set_indent {} : set_desc {label = "Off: no reactor runs.";}}
        // ... runs Dyl-LayerPhase, then opens this window again:
        : row {
          : set_tog {label = "Auto-phase new objects"; key = "aph";}
          : set_more {key = "lph";}
        }
        : concatenation {: set_indent {} : set_desc {label = "Puts new objects on the active phase.";}}
        // ... runs Dyl-DrawOrder, then opens this window again:
        : row {
          : set_tog {label = "Auto draw order"; key = "ado";}
          : set_more {key = "ldo";}
        }
        : concatenation {: set_indent {} : set_desc {label = "Stacks new objects by layer level.";}}
        // DynalispObjectKeys (Reactor\Dyl-ObjectLayerKeys.lsp): ... runs Dyl-ObjectLayerKeys
        // (the key of each kind of object), then opens this window again:
        : row {
          : set_tog {label = "Auto layer keys"; key = "alk";}
          : set_more {key = "lol";}
        }
        : concatenation {: set_indent {} : set_desc {label = "Puts new dimensions, text on their key.";}}
        // DynalispSettingsSync (Dyl:SettingsSyncOn-p, Reactor\Dyl-SettingsSync.lsp):
        : set_tog {label = "Settings sync"; key = "syn";}
        : concatenation {: set_indent {} : set_desc {label = "Open drawings follow saved settings.";}}
      }
      : boxed_column {label = "Overrides";
        // What the section is, greyed out like the descriptions of the reactors:
        : set_desc {label = "Set in every drawing opened.";}
        : spacer {height = 0.5;}
        // Drawing defaults (Remote\Dyl-DrawingSetup.lsp, DynalispSetupOn): every drawing
        // opened is checked against the default units and grid of its kind. ... opens the
        // drawing defaults window (dyl_drawdefs below), greyed out while the check is off:
        : row {
          : set_tog {label = "Drawing Settings"; key = "dso";}
          : set_more {key = "dsm";}
        }
        // Redefines the save and print commands and REGEN (Dyl-CmdOptimizer), which run
        // the steps of the output prep window (dyl_prepsuite below, Dyl-PrepSuite):
        : row {
          : set_tog {label = "Commands"; key = "prp";}
          : set_more {key = "prs";}
        }
        // The DynALisp profile (Remote\Dyl-FilePrefs.lsp), its paths set from the file
        // preferences: ... opens the file preferences window (dyl_fileprefs below), greyed
        // out while the profile is off:
        : row {
          : set_tog {label = "File Preferences"; key = "pfo";}
          : set_more {key = "pfm";}
        }
        // System variables (Remote\Dyl-SysVars.lsp, DynalispSysVarOn): the preferred values
        // of the active profile set in every drawing opened. ... runs Dyl-SysVars (the
        // profiles), then opens this window again; greyed out while off or when
        // Dyl-SysVars is turned off in Dyl-Suite:
        : row {
          : set_tog {label = "System variables"; key = "svo";}
          : set_more {key = "svm";}
        }
        // The display settings (Remote\Dyl-EnvColor.lsp, DynalispDisplayOn), applied in
        // every drawing opened: ... opens the display window (dyl_display below), greyed
        // out while they are off:
        : row {
          : set_tog {label = "Display"; key = "dpo";}
          : set_more {key = "dpm";}
        }
        // Revisions (Remote\Dyl-Revisions.lsp, DynalispRevisionSync): every sheet of a project
        // updated with the revisions of the project when it opens. ... runs
        // Pst-RevisionTitleBlocks (the title blocks), then opens this window again; greyed out
        // when Dyl-Revisions is turned off in Dyl-Suite:
        : row {
          : set_tog {label = "Revisions"; key = "rvo";}
          : set_more {key = "rvm";}
        }
        // Clean startup (DynalispCleanStartup, Contents\Resources\DynALisp.Startup.dll of
        // Installer\Startup): the lines AutoCAD prints while it starts removed from the
        // command line, from the next startup; greyed out without the plugin (Dyl:CleanStartup):
        : set_tog {label = "Clean startup"; key = "csu";}
        : spacer {}
      }
      // The layers of the layer keys that exist with other values than their key (Remote\Dyl-LayerKey.lsp,
      // Remote>>Dyl:LayerKeyCheck): asked by default (Yes / No); the answer remembered by
      // "Remember my answer" of that question is set here, or taken back (both off): one of
      // the two at most (DynalispLayerKeyUpdate, DynalispLayerKeyKeep):
      : boxed_column {label = "Layer keys";
        : set_desc {label = "Existing layers that differ from their key.";}
        : spacer {height = 0.5;}
        : set_tog {label = "Update them without asking"; key = "lku";}
        : set_tog {label = "Keep them without asking"; key = "lkk";}
        : concatenation {: set_indent {} : set_desc {label = "Both off: asked when the key is used.";}}
      }
      // New versions of DynALisp (Dyl:UpdAuto, DynalispAutoUpdate): checked once a day by
      // the first drawing opened, the setup started (installs when AutoCAD closes). For a
      // git clone, greyed out and its description says so (aud, set by Dyl:SetDlgFill):
      : boxed_column {label = "Updates";
        : set_desc {label = "New versions of DynALisp.";}
        : spacer {height = 0.5;}
        : set_tog {label = "Install updates automatically"; key = "aup";}
        : concatenation {: set_indent {} : set_desc {key = "aud"; label = "Checks daily, installs as AutoCAD closes.";}}
      }
    }
  : row {
    : spacer {width = 1;}
    : button {label = "Save"; key = "accept"; width = 12; fixed_width = true; mnemonic = "S"; is_default = true;}
    : button {label = "Cancel"; key = "cancel"; width = 12; fixed_width = true; mnemonic = "C"; is_cancel = true;}
    : button {label = "Open Docs"; key = "docs"; width = 12; fixed_width = true;}
    : spacer {width = 1;}
  }
}


// The drawing defaults window (opened by the open button of Drawing defaults in
// dyl_settings, see Dyl:SetDefsDlg). Popups of the unit (u) and grid (g) presets for the
// imperial (im) and metric (mt) drawings, first item: not checked:
dyl_drawdefs
: dialog {label = "DynALisp - Drawing Settings";
  : boxed_column {label = "Drawing Settings (checked in every drawing)";
    : row {
      : set_label {label = "";}
      : set_head {label = "Imperial drawings";}
      : set_head {label = "Metric drawings";}
    }
    : row {
      : set_label {label = "Units:";}
      : set_pop {key = "uim";}
      : set_pop {key = "umt";}
    }
    : row {
      : set_label {label = "Grid:";}
      : set_pop {key = "gim";}
      : set_pop {key = "gmt";}
    }
    : text {label = "Drawings that differ are set to their default.";}
  }
  // Shrinkwrap gap step (Remote\Dyl-Shrinkwrap.lsp, DynalispShrinkGapImperial / Metric): when
  // no outline is found, the gap tolerance is made larger by this step, up to 10 times:
  : boxed_column {label = "Shrinkwrap gap step (tried when no outline is found)";
    : row {
      : set_label {label = "Step:";}
      : edit_box {key = "gpi"; width = 32; fixed_width = true; edit_width = 10;}
      : edit_box {key = "gpm"; width = 32; fixed_width = true; edit_width = 10;}
    }
    : text {key = "gerr"; width = 72;}
  }
  : text {label = "Saved when Settings is saved.";}
  : row {
    : spacer {width = 1;}
    : button {label = "OK"; key = "accept"; width = 12; fixed_width = true; is_default = true;}
    : button {label = "Cancel"; key = "cancel"; width = 12; fixed_width = true; is_cancel = true;}
    : button {label = "Open Docs"; key = "docs"; width = 12; fixed_width = true;}
    : spacer {width = 1;}
  }
}


// The display window (opened by the open button of Display in dyl_settings, see
// Dyl:SetDisplayDlg): the display settings applied in every drawing while Display is on.
// The other display settings are to be added to this box:
dyl_display
: dialog {label = "DynALisp - Display";
  : boxed_column {label = "Display (applied in every drawing)";
    // Model space background color, first item: not set (the current color kept):
    : row {
      : text {label = "Background:"; width = 12; fixed_width = true;}
      : popup_list {key = "bkg"; width = 24; fixed_width = true;}
    }
  }
  : text {label = "Saved when Settings is saved.";}
  : row {
    : spacer {width = 1;}
    : button {label = "OK"; key = "accept"; width = 12; fixed_width = true; is_default = true;}
    : button {label = "Cancel"; key = "cancel"; width = 12; fixed_width = true; is_cancel = true;}
    : button {label = "Open Docs"; key = "docs"; width = 12; fixed_width = true;}
    : spacer {width = 1;}
  }
}


// The file preferences window (opened by the open button of the DynALisp profile in
// dyl_settings, see Dyl:SetPrefsDlg): the paths of the DynALisp profile, from
// Res\FilePrefs.csv. Popups in the *fp:prefs* order (*dyl:setprefs*):
dyl_fileprefs
: dialog {label = "DynALisp - File Preferences";
  : boxed_column {label = "DynALisp profile (set in every drawing)";
    : row {
      : pref_label {label = "AEC library classification:";}
      : pref_pop {key = "pcl";}
    }
    : row {
      : pref_label {label = "Drawing units:";}
      : pref_pop {key = "pun";}
    }
    : row {
      : pref_label {label = "Language (content, spelling):";}
      : pref_pop {key = "pla";}
    }
    // DynalispPrefCustomDict: used only when the language has one (FilePrefs.csv):
    : toggle {label = "Use the DynALisp custom dictionary of the language, when it has one"; key = "pcd";}
    : text {key = "pfs"; width = 66;}
  }
  : text {label = "Saved when Settings is saved.";}
  : row {
    : spacer {width = 1;}
    : button {label = "OK"; key = "accept"; width = 12; fixed_width = true; is_default = true;}
    : button {label = "Cancel"; key = "cancel"; width = 12; fixed_width = true; is_cancel = true;}
    : button {label = "Open Docs"; key = "docs"; width = 12; fixed_width = true;}
    : spacer {width = 1;}
  }
}


dyl_prepsuite
: dialog {label = "DynALisp - Output Prep";
  : boxed_column {label = "Steps run before each command";
    : row {
      : prep_step {label = "Step";}
      : prep_head {label = "All saves";}
      : prep_head {label = "All prints";}
      : prep_head {label = "PREVIEW";}
      : prep_head {label = "REGEN";}
    }
    : row {
      : prep_step {label = "Turn on and thaw all layers";}
      : prep_tog {key = "t_LAYERS_SAVE";}
      : prep_tog {key = "t_LAYERS_PLOT";}
      : prep_tog {key = "t_LAYERS_PREVIEW";}
      : prep_tog {key = "t_LAYERS_REGEN";}
    }
    : row {
      : prep_step {label = "Unhide hidden / isolated objects";}
      : prep_tog {key = "t_UNHIDE_SAVE";}
      : prep_tog {key = "t_UNHIDE_PLOT";}
      : prep_tog {key = "t_UNHIDE_PREVIEW";}
      : prep_tog {key = "t_UNHIDE_REGEN";}
    }
    : row {
      : prep_step {label = "Reload all xrefs (slow)";}
      : prep_tog {key = "t_XREFS_SAVE";}
      : prep_tog {key = "t_XREFS_PLOT";}
      : prep_tog {key = "t_XREFS_PREVIEW";}
      : prep_tog {key = "t_XREFS_REGEN";}
    }
    : row {
      : prep_step {label = "Update all data links";}
      : prep_tog {key = "t_DATALINKS_SAVE";}
      : prep_tog {key = "t_DATALINKS_PLOT";}
      : prep_tog {key = "t_DATALINKS_PREVIEW";}
      : prep_tog {key = "t_DATALINKS_REGEN";}
    }
    : row {
      : prep_step {label = "Fit table row heights";}
      : prep_tog {key = "t_TABLES_SAVE";}
      : prep_tog {key = "t_TABLES_PLOT";}
      : prep_tog {key = "t_TABLES_PREVIEW";}
      : prep_tog {key = "t_TABLES_REGEN";}
    }
    : row {
      : prep_step {label = "Apply the draw order (if auto draw order on)";}
      : prep_tog {key = "t_DRAWORDER_SAVE";}
      : prep_tog {key = "t_DRAWORDER_PLOT";}
      : prep_tog {key = "t_DRAWORDER_PREVIEW";}
      : prep_tog {key = "t_DRAWORDER_REGEN";}
    }
    : row {
      : prep_step {label = "Rebuild the draw order (keeps panning fast)";}
      : prep_tog {key = "t_DRAWORDERCLEAN_SAVE";}
      : prep_tog {key = "t_DRAWORDERCLEAN_PLOT";}
      : prep_tog {key = "t_DRAWORDERCLEAN_PREVIEW";}
      : prep_tog {key = "t_DRAWORDERCLEAN_REGEN";}
    }
    : row {
      : prep_step {label = "Regenerate the drawing (REGENALL, slow)";}
      : prep_tog {key = "t_REGEN_SAVE";}
      : prep_tog {key = "t_REGEN_PLOT";}
      : prep_tog {key = "t_REGEN_PREVIEW";}
      : prep_tog {key = "t_REGEN_REGEN";}
    }
    : row {
      : button {label = "All On"; key = "allon"; width = 12; fixed_width = true; mnemonic = "A";}
      : button {label = "All Off"; key = "alloff"; width = 12; fixed_width = true; mnemonic = "f";}
      : text {label = "A command with no step checked runs as the native one.";}
    }
  }
  : text {key = "sta"; width = 80;}
  : row {
    : spacer {width = 1;}
    : button {label = "OK"; key = "accept"; width = 12; fixed_width = true; is_default = true;}
    : button {label = "Cancel"; key = "cancel"; width = 12; fixed_width = true; is_cancel = true;}
    : button {label = "Open Docs"; key = "docs"; width = 12; fixed_width = true;}
    : spacer {width = 1;}
  }
}
