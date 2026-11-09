// Dyl-Info.dcl - Dynalisp info dialog (Dyl-Info command)
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
// The version, update status and core commands are set by c:Dyl-Info (see the
// Info region of dynalisp.mnl).


dyl_info
: dialog {label = "DynALisp - Info";
  : row {
    : boxed_column {label = "DynALisp";
      : text {key = "ver"; width = 60;}
      : text {key = "upd"; width = 60;}
      : text {key = "acv"; width = 60;}
      : text {key = "pth"; width = 60;}
      // dwn: Update to x... / What's new in x... (git clone) / Download x (no setup in
      // the release), set by Dyl:InfoDlgUpd; whn: the changes up to this version:
      : row {
        : button {label = "Update"; key = "dwn"; width = 24; fixed_width = true; mnemonic = "U";}
        : button {label = "What's new"; key = "whn"; width = 14; fixed_width = true; mnemonic = "W";}
        : button {label = "Check again"; key = "chk"; width = 16; fixed_width = true; mnemonic = "k";}
        : button {label = "GitHub repository"; key = "git"; width = 20; fixed_width = true; mnemonic = "G";}
      }
    }
    : boxed_column {label = "Module docs";
      : popup_list {label = "Module:"; key = "mod"; edit_width = 24;}
      : button {label = "Open docs index"; key = "mdc"; width = 20; fixed_width = true; mnemonic = "O";}
      : spacer {}
    }
  }
  : boxed_column {label = "Core commands";
    // Columns: command, what it does
    : list_box {key = "cmd"; width = 112; height = 14; tabs = "24";}
    : text {label = "Double-click a command (or Run) to close this window and run it. The module commands are listed in Dyl-Suite.";}
  }
  : row {
    : button {label = "Run"; key = "run"; width = 12; fixed_width = true; mnemonic = "R";}
    : spacer {width = 1;}
    : button {label = "Close"; key = "cancel"; width = 12; fixed_width = true; is_cancel = true; is_default = true;}
    : button {label = "Open Docs"; key = "docs"; width = 12; fixed_width = true;}
  }
}

// The What's new window (Dyl:InfoNotesDlg in dynalisp.mnl): the changes of the versions
// from CHANGELOG.md, before an update (Install starts its setup, greyed out when there
// is nothing to install), after one, or all of them (What's new of dyl_info):
dyl_whatsnew
: dialog {label = "DynALisp - What's New";
  : text {key = "hed"; width = 100;}
  : list_box {key = "lst"; width = 100; height = 20;}
  : text {key = "msg"; width = 100;}
  : row {
    : button {label = "Install"; key = "ins"; width = 32; fixed_width = true; mnemonic = "I";}
    : button {label = "All releases"; key = "rel"; width = 16; fixed_width = true; mnemonic = "A";}
    : spacer {width = 1;}
    : button {label = "Close"; key = "cancel"; width = 12; fixed_width = true; is_cancel = true; is_default = true;}
    : button {label = "Open Docs"; key = "docs"; width = 12; fixed_width = true;}
  }
}
