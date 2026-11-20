// Dyl-Revisions.dcl - the windows of Dyl-Revisions (Apps\Output\Dyl-Revisions.lsp)
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

// The open button (Dyl:MoreTile), the dividing line (Dyl:LineTile), the value boxes and
// the buttons of both windows:
rev_more : image_button { height = 1; fixed_height = true; aspect_ratio = 1; fixed_width = true; color = -15; }
rev_line : image { height = 0.8; fixed_height = true; color = -15; }
rev_edit : edit_box { edit_width = 30; }
rev_pop : popup_list { edit_width = 30; }
rev_buttons : row { fixed_width = true; alignment = right;
  : button { key = "accept"; label = "OK"; is_default = true; width = 12; fixed_width = true; }
  : button { key = "cancel"; label = "Cancel"; is_cancel = true; width = 12; fixed_width = true; }
  : button { key = "docs"; label = "Open Docs"; width = 12; fixed_width = true; }
}

// The Revisions window (Dyl-Revisions):
dyl_rev : dialog { label = "DynALisp - Revisions";
  : text { key = "prj"; width = 124; }
  : row {
    : boxed_column { label = "Revisions";
      : list_box { key = "rhd"; width = 74; height = 2; fixed_height = true; tabs = "5 12 24 62"; is_enabled = false; }
      : list_box { key = "rev"; width = 74; height = 12; tabs = "5 12 24 62"; multiple_select = true; }
      : row { fixed_width = true; alignment = left;
        : button { key = "new"; label = "New"; width = 12; }
        : button { key = "del"; label = "Delete"; width = 12; }
        : button { key = "up"; label = "Move Up"; width = 12; }
        : button { key = "dn"; label = "Move Down"; width = 12; }
      }
    }
    : column {
      : boxed_column { key = "pbx"; label = "Parameters";
        : row { : rev_pop { key = "num"; label = "Numbering:"; } }
        : row { : rev_edit { key = "dat"; label = "Date:"; } }
        : row { : rev_edit { key = "dsc"; label = "Description:"; } }
        : row { : rev_edit { key = "ito"; label = "Issued to:"; } }
        : row { : rev_edit { key = "iby"; label = "Issued by:"; } }
        : row { : toggle { key = "iss"; label = "Issued"; } }
        : spacer { }
      }
      : boxed_column { label = "Project";
        : row { : rev_pop { key = "pnm"; label = "Numbering:"; } }
        : row { : rev_pop { key = "pst"; label = "First number:"; } }
        : row {
          : text { label = "Title blocks:"; }
          : rev_more { key = "tbm"; }
          : text { key = "tbs"; width = 28; fixed_width = true; }
        }
        : spacer { }
      }
    }
  }
  : boxed_column { key = "sbx"; label = "Sheets";
    : list_box { key = "shd"; width = 124; height = 2; fixed_height = true; tabs = "46 80 94"; is_enabled = false; }
    : list_box { key = "sht"; width = 124; height = 12; tabs = "46 80 94"; multiple_select = true; }
    : row { fixed_width = true; alignment = left;
      : button { key = "add"; label = "Add Revision"; width = 20; }
      : button { key = "rem"; label = "Remove Revision"; width = 20; }
      : button { key = "all"; label = "Update All Sheets"; width = 20; }
    }
  }
  errtile;
  rev_buttons;
}

// The Revision Title Blocks window (Pst-RevisionTitleBlocks, the open button of Title blocks):
dyl_revtb : dialog { label = "DynALisp - Revision Title Blocks";
  : row {
    : boxed_column { label = "Title blocks";
      : list_box { key = "thd"; width = 46; height = 2; fixed_height = true; tabs = "30 37"; is_enabled = false; }
      : list_box { key = "tbl"; width = 46; height = 17; tabs = "30 37"; multiple_select = true; }
      : row { fixed_width = true; alignment = left;
        : button { key = "new"; label = "New"; width = 12; }
        : button { key = "del"; label = "Delete"; width = 12; }
        : button { key = "pck"; label = "Pick..."; width = 12; }
      }
    }
    : boxed_column { key = "tbx"; label = "Parameters";
      : column { fixed_height = true;
        : row { : rev_edit { key = "nam"; label = "Block:"; } }
        : row { : rev_edit { key = "rws"; label = "Rows:"; } }
        : row { : rev_pop { key = "fst"; label = "Row 1:"; } }
      }
      : spacer { }
      : column { fixed_height = true;
        : rev_line { key = "ln1"; }
        : text { label = "Row attributes:"; }
        : row { : rev_edit { key = "a3"; label = "Number:"; } }
        : row { : rev_edit { key = "a4"; label = "Date:"; } }
        : row { : rev_edit { key = "a5"; label = "Description:"; } }
        : row { : rev_edit { key = "a6"; label = "Issued to:"; } }
        : row { : rev_edit { key = "a7"; label = "Issued by:"; } }
      }
      : spacer { }
      : column { fixed_height = true;
        : rev_line { key = "ln2"; }
        : text { label = "Sheet attributes:"; }
        : row { : rev_edit { key = "a8"; label = "Current revision:"; } }
        : row { : rev_edit { key = "a9"; label = "Current date:"; } }
      }
      : spacer { }
    }
  }
  errtile;
  rev_buttons;
}
