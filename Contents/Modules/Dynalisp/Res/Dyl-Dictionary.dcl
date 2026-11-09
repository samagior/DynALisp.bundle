// Dyl-Dictionary.dcl - Dynalisp dictionary window (Dyl-Dictionary command)
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
// The words of a definitions file (Res\Dictionaries\<code>-def.csv, see
// Modules\Dynalisp\Apps\Utilities\Dyl-Dictionary.lsp), searched and filtered. The
// columns of the lists: word, type, category, subcategory.


dic_text : text {width = 112; fixed_width = true;}

dyl_dictionary
: dialog {label = "DynALisp - Dictionary";
  : boxed_column {label = "Search";
    : row {
      : popup_list {key = "dic"; label = "Dictionary:"; edit_width = 16; fixed_width = true;}
      : edit_box {key = "src"; label = "Words:"; edit_width = 40; edit_limit = 128; fixed_width = true;}
      : button {key = "go"; label = "Search"; width = 12; fixed_width = true; is_default = true;}
      : toggle {key = "ind"; label = "Also in the definitions";}
    }
    : row {
      : popup_list {key = "cat"; label = "Category:"; edit_width = 30; fixed_width = true;}
      : popup_list {key = "sub"; label = "Subcategory:"; edit_width = 36; fixed_width = true;}
      : popup_list {key = "typ"; label = "Type:"; edit_width = 12; fixed_width = true;}
      : button {key = "clr"; label = "Clear"; width = 12; fixed_width = true;}
    }
    : text {label = "Accents and case are ignored (equarri finds the accented word). Every word typed must match the word or one of its forms.";}
  }
  : list_box {key = "hdr"; width = 116; height = 2; fixed_height = true; tabs = "30 44 72"; is_enabled = false;}
  : list_box {key = "lst"; width = 116; height = 18; tabs = "30 44 72";}
  : dic_text {key = "cnt";}
  : boxed_column {label = "Definition";
    : dic_text {key = "wrd";}
    : dic_text {key = "frm";}
    : dic_text {key = "d1";}
    : dic_text {key = "d2";}
    : dic_text {key = "d3";}
    : dic_text {key = "cls";}
    : row {
      : popup_list {key = "see"; label = "See also:"; edit_width = 40; fixed_width = true;}
      : button {key = "jmp"; label = "Go to"; width = 12; fixed_width = true;}
      : text {key = "msg"; width = 50;}
    }
  }
  : row {
    : button {key = "cpy"; label = "Copy word"; width = 14; fixed_width = true; mnemonic = "C";}
    : button {key = "edt"; label = "Edit list..."; width = 14; fixed_width = true; mnemonic = "E";}
    : text {label = "Double-click a word copies it.";}
    : button {key = "cancel"; label = "Close"; width = 12; fixed_width = true; is_cancel = true;}
    : button {label = "Open Docs"; key = "docs"; width = 12; fixed_width = true;}
  }
}
