// Dyl-SysVars.dcl - Dynalisp system variable profiles dialog (Dyl-SysVars command)
// Copyright (C) 2026  Samuel Martineau
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
// Like the System Variable Monitor of AutoCAD: each variable of the profile with its
// preferred value, its current value and whether they differ. The profiles are the CSV
// files of Res\SysVars (see Modules\Dynalisp\Remote\Dyl-SysVars.lsp).

sv_button : button {width = 12; fixed_width = true;}

dyl_sysvars
: dialog {label = "DynALisp - System Variables";
  // The profile shown (the active one on OK) and its system variables:
  : boxed_column {label = "Profile (the one set in every drawing)";
    : row {
      : popup_list {key = "pro"; width = 30; fixed_width = true;}
      : sv_button {label = "New..."; key = "pnw";}
      : sv_button {label = "Copy..."; key = "pcp";}
      : sv_button {label = "Rename..."; key = "prn";}
      : sv_button {label = "Delete"; key = "pdl";}
      : spacer {}
    }
    // Header: a disabled list with the same tabs as the list under it:
    // Variable, Preferred value, Current value (marked when it differs), as the protected
    // variables below:
    : list_box {key = "hdr"; width = 84; height = 2; fixed_height = true; tabs = "22 44"; is_enabled = false;}
    // Several rows can be selected (Ctrl / Shift click): Remove removes them all:
    : list_box {key = "lst"; width = 84; height = 14; tabs = "22 44"; multiple_select = true;}
    : row {
      : edit_box {label = "Variable:"; key = "var"; edit_width = 18; edit_limit = 64;}
      : edit_box {label = "Preferred value:"; key = "val"; edit_width = 24; edit_limit = 255;}
    }
    : row {
      : sv_button {label = "Add"; key = "add";}
      : sv_button {label = "Use current"; key = "cur";}
      : sv_button {label = "List..."; key = "brw";}
      : sv_button {label = "Remove"; key = "del";}
      : spacer {}
      : button {label = "Reset all"; key = "rst"; width = 14; fixed_width = true;}
    }
  }
  // The protected variables (Res\SysVarsProtected.csv): their preferred value set in every
  // drawing whatever the profile, no profile changes them (no value: protected only):
  : boxed_column {label = "Protected variables (set in every drawing, never changed by a profile)";
    : list_box {key = "khd"; width = 84; height = 2; fixed_height = true; tabs = "22 44"; is_enabled = false;}
    : list_box {key = "kls"; width = 84; height = 7; tabs = "22 44"; multiple_select = true;}
    : row {
      : edit_box {label = "Variable:"; key = "kvr"; edit_width = 18; edit_limit = 64;}
      : edit_box {label = "Preferred value:"; key = "kvl"; edit_width = 24; edit_limit = 255;}
    }
    : row {
      : sv_button {label = "Add"; key = "kad";}
      : sv_button {label = "Use current"; key = "kcu";}
      : sv_button {label = "List..."; key = "kbr";}
      : sv_button {label = "Remove"; key = "kdl";}
      : spacer {}
    }
  }
  : text {key = "msg"; width = 84;}
  : text {label = "Reset all sets every variable, protected ones included, to its preferred value in this drawing. * = differs.";}
  : row {
    : spacer {width = 1;}
    : button {label = "OK"; key = "accept"; width = 12; fixed_width = true; is_default = true;}
    : button {label = "Cancel"; key = "cancel"; width = 12; fixed_width = true; is_cancel = true;}
    : button {label = "Open Docs"; key = "docs"; width = 12; fixed_width = true;}
    : spacer {width = 1;}
  }
}

// Every system variable of AutoCAD (List... of the profile or of the protected variables):
// read from Express\sysvdlg.dat of the AutoCAD installation (the Express Tools list, see
// sv:catalog). Add adds the variable to the list it was opened from; a double-click
// closes the window and puts the variable in the variable box of that list.
sv_desc : text {width = 110; fixed_width = true;}

dyl_sysvars_list
: dialog {key = "ttl";
  : row {
    : edit_box {label = "Search:"; key = "flt"; edit_width = 40; edit_limit = 64;}
    : text {key = "cnt"; width = 30;}
  }
  : list_box {key = "hdr"; width = 110; height = 2; fixed_height = true; tabs = "24 40"; is_enabled = false;}
  : list_box {key = "lst"; width = 110; height = 18; tabs = "24 40";}
  : boxed_column {label = "Description";
    : sv_desc {key = "inf";}
    : sv_desc {key = "ds1";}
    : sv_desc {key = "ds2";}
    : sv_desc {key = "ds3";}
  }
  : text {key = "msg"; width = 110;}
  : row {
    : sv_button {label = "Add"; key = "add";}
    : button {label = "AutoCAD Help"; key = "doc"; width = 16; fixed_width = true;}
    : spacer {}
    : button {label = "Close"; key = "cancel"; width = 12; fixed_width = true; is_cancel = true;}
    : button {label = "Open Docs"; key = "docs"; width = 12; fixed_width = true;}
  }
}

// Name of a new, copied or renamed profile:
dyl_sysvars_name
: dialog {key = "ttl";
  : edit_box {key = "nam"; label = "Profile name:"; edit_width = 40; edit_limit = 64; allow_accept = true;}
  ok_cancel;
  errtile;
}
