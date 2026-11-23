;; Manager - The windows that set up the drawing tools, as the tabs of one window
;; Copyright (C) 2026  Samuel Martineau
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.
;;
;;-------------------------=={ End of Licence }==------------------------;;


;;  The Manager (its tabs, the window of each tab) is in Modules\Dynalisp\Remote\Dyl-Manager.lsp,
;;  loaded at startup for every App: the main commands of its tools (Dyl-QuickDraw,
;;  Dyl-Materials, Dyl-HatchPresets) open it on their own tab, this one on the tab shown last.

;;-------------------------=={ Commands }==------------------------;;

;; Manager
;; Opens the Manager: the windows that set up the drawing tools (Quick Draw, Assembly Presets, Materials, Hatch Presets) as the tabs of one window.

(defun c:Dyl-Manager ()
  (Remote>>Dyl:Manager nil)
  (princ)
)

(princ)
