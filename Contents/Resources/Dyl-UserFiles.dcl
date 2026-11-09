// Dyl-UserFiles.dcl - Dynalisp user files dialog (Dyl-UserFiles command)
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
// The list is set by c:Dyl-UserFiles (see the UserFiles region of dynalisp.mnl).


dyl_userfiles
: dialog {label = "DynALisp - User Files";
  : text {key = "loc"; width = 104;}
  : text {label = "Your edits are saved there (ignored by git); the defaults under Contents are never changed by the commands.";}
  // Columns: path under the User folder, what it is
  : list_box {key = "lst"; width = 104; height = 14; tabs = "74";}
  : text {key = "msg"; width = 104;}
  // Saved settings (Dyl:SetsExport / Dyl:SetsImport): the User folder, the options of
  // Dyl-Settings and the MyTools module, in a "DynALisp Settings <date>" folder:
  : row {
    : button {label = "Export settings..."; key = "exp"; width = 20; fixed_width = true; mnemonic = "E";}
    : button {label = "Import settings..."; key = "imp"; width = 20; fixed_width = true; mnemonic = "I";}
    : text {label = "Your files, Dyl-Settings options and MyTools, to keep or move.";}
  }
  : row {
    : button {label = "Open"; key = "opn"; width = 12; fixed_width = true; mnemonic = "O";}
    : button {label = "Open User folder"; key = "dir"; width = 20; fixed_width = true; mnemonic = "U";}
    : spacer {width = 2;}
    : button {label = "Reset to default"; key = "rst"; width = 20; fixed_width = true; mnemonic = "R";}
    : button {label = "Make it the default"; key = "pub"; width = 22; fixed_width = true; mnemonic = "M";}
    : spacer {width = 2;}
    : button {label = "Close"; key = "cancel"; width = 12; fixed_width = true; is_cancel = true; is_default = true;}
    : button {label = "Open Docs"; key = "docs"; width = 12; fixed_width = true;}
  }
}
