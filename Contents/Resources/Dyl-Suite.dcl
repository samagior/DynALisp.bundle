// Dyl-Suite.dcl - Dynalisp Startup Suite manager dialog (Dyl-Suite command)
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


dyl_suite
: dialog {label = "DynALisp - Startup Suite";
  : row {
    : popup_list {label = "Module:"; key = "mod"; width = 26; fixed_width = true;}
    : popup_list {label = "Group:"; key = "grp"; width = 30; fixed_width = true;}
    : popup_list {label = "Show:"; key = "shw"; width = 20; fixed_width = true;}
    : popup_list {label = "Sort by:"; key = "srt"; width = 22; fixed_width = true;}
    : edit_box {label = "Search (Enter):"; key = "flt"; width = 32; allow_accept = false;}
    : button {label = "Clear"; key = "clr"; width = 10; fixed_width = true; mnemonic = "l";}
  }
  // Columns: state, fold, command, aliases, name, module, group. The column titles
  // are a one-line list box with the same tabs, so they line up with the list
  // ("v" marks the column sorted).
  : list_box {key = "hdr"; width = 152; height = 2; fixed_height = true; tabs = "6 11 57 83 127 138"; is_tab_stop = false;}
  : list_box {key = "lst"; width = 152; height = 28; multiple_select = true; tabs = "6 11 57 83 127 138";}
  : row {
    : text {key = "cnt"; width = 58;}
    : toggle {label = "Show unloaded commands"; key = "sof";}
    : toggle {label = "Show child commands"; key = "sch";}
    : button {label = "Fold/Unfold"; key = "fld"; width = 14; fixed_width = true;}
    : button {label = "Fold/Unfold All"; key = "fal"; width = 18; fixed_width = true;}
  }
  : row {
    : boxed_row {label = "Selection";
      : column {
        : text {key = "nam"; width = 86;}
        : text {key = "des"; width = 86;}
        : text {key = "pth"; width = 86;}
        : row {
          : button {label = "Command docs"; key = "doc"; width = 16; fixed_width = true; mnemonic = "D";}
          : button {label = "Open Lisp"; key = "lsp"; width = 16; fixed_width = true; mnemonic = "O";}
        }
      }
    }
    : boxed_column {label = "Aliases of the command";
      : row {
        : list_box {key = "als"; width = 30; height = 6;}
        : column {
          : edit_box {label = "Alias:"; key = "aln"; edit_width = 20; edit_limit = 64; allow_accept = false;}
          : row {
            : button {label = "Add"; key = "aad"; width = 10; fixed_width = true;}
            : button {label = "Rename"; key = "aren"; width = 10; fixed_width = true;}
            : button {label = "Remove"; key = "adel"; width = 10; fixed_width = true;}
          }
        }
      }
      : text {key = "ams"; width = 62;}
    }
  }
  : row {
    : button {label = "On/Off"; key = "onf"; width = 14; fixed_width = true; mnemonic = "n";}
    : spacer {width = 2;}
    : button {label = "All Listed On/Off"; key = "aonf"; width = 22; fixed_width = true; mnemonic = "A";}
    : spacer {width = 2;}
    : button {label = "Open in VS Code"; key = "vsc"; width = 20; fixed_width = true; mnemonic = "V";}
    : spacer {width = 1;}
    : button {label = "Save"; key = "accept"; width = 12; fixed_width = true; mnemonic = "S"; is_default = true;}
    : button {label = "Cancel"; key = "cancel"; width = 12; fixed_width = true; mnemonic = "C"; is_cancel = true;}
    : button {label = "Open Docs"; key = "docs"; width = 12; fixed_width = true;}
  }
}

// Install guide of Visual Studio Code, shown by Dyl-VSCode when it is missing
// (see Dyl:VSCodeGuide). msg tells what to do after each button.
dyl_vscode
: dialog {label = "DynALisp - Visual Studio Code";
  : text {value = "Visual Studio Code was not found on this computer. It is a free code editor"; width = 76;}
  : text {value = "from Microsoft, used to read and edit the DynALisp Lisp files."; width = 76;}
  : spacer {height = 1;}
  : text {value = "1. Install it: Install (winget) installs it for your Windows user, no administrator"; width = 76;}
  : text {value = "    rights needed. Or Download page: get the User Installer for Windows, run it and"; width = 76;}
  : text {value = "    keep \"Add to PATH\" checked."; width = 76;}
  : text {value = "2. Click Open DynALisp: the DynALisp.bundle folder opens in Visual Studio Code."; width = 76;}
  : text {value = "3. In Visual Studio Code, trust the folder and install the recommended AutoLISP"; width = 76;}
  : text {value = "    extension (Autodesk) when asked."; width = 76;}
  : spacer {height = 1;}
  : text {key = "msg"; width = 76;}
  : row {
    : button {label = "Install (winget)"; key = "wgt"; width = 20; fixed_width = true; mnemonic = "I";}
    : button {label = "Download page"; key = "web"; width = 18; fixed_width = true; mnemonic = "D";}
    : spacer {width = 2;}
    : button {label = "Open DynALisp"; key = "accept"; width = 18; fixed_width = true; mnemonic = "O"; is_default = true;}
    : button {label = "Close"; key = "cancel"; width = 12; fixed_width = true; is_cancel = true;}
    : button {label = "Open Docs"; key = "docs"; width = 12; fixed_width = true;}
  }
}

// Question of up to 3 lines, the labels of both buttons are set by Dyl:SuiteAsk
dyl_suite_ask
: dialog {label = "DynALisp - Startup Suite";
  : text {key = "l1"; width = 60;}
  : text {key = "l2"; width = 60;}
  : text {key = "l3"; width = 60;}
  : row {
    : spacer {width = 1;}
    : button {key = "accept"; label = "Yes"; width = 12; fixed_width = true; is_default = true;}
    : button {key = "cancel"; label = "No"; width = 12; fixed_width = true; is_cancel = true;}
    : spacer {width = 1;}
  }
}
