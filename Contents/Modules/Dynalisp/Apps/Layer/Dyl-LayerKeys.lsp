;; LayerKeys - Create and edit the Dynalisp layer keys used by the Apps
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

;;  The layer keys themselves (LayerKeys.csv, layer creation, dialog) are in
;;  Modules\Dynalisp\Remote\Dyl-LayerKey.lsp, loaded at startup for every App.

;;-------------------------=={ Commands }==------------------------;;

;; Layer Keys
;; Opens a dialog to create and edit the layer keys used by the Dynalisp Apps.

(defun c:Dyl-LayerKeys ()
  (Remote>>Dyl:LayerKeyDialog nil)
  (princ)
)
