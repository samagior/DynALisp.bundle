;; StandardGrid - Switches between grid configurations in model space
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

; switch between grid configuration in model space. 
;
;---------------------------------------------------------------------------------------------------

;;  The presets are the child commands Pst-* below, run by their aliases or
;;  picked in the Dyl-StandardGrid dialog (Dyl:ChildPicker). Their values are in
;;  Modules\Dynalisp\Remote\Dyl-DrawingSetup.lsp, where the default grid of the imperial
;;  and metric drawings (chosen in Dyl-Settings) is checked when each drawing opens.

;; Standard Grid
;; Lists the grid settings with their aliases and applies the one picked.

(defun c:Dyl-StandardGrid ()
  (Dyl:ChildPicker "Dyl-StandardGrid.lsp" "Standard Grid" "Double-click a grid (or OK) to apply it." '*sg:last*)
)

;;  Apply the grid preset key and confirm it:
(defun sg:apply (key)
  (Remote>>Dyl:GridApply key)
  (princ (strcat "\nGrid set to " (Remote>>Dyl:GridName key) "."))
  (princ)
)

;; Grid Inch
;; Sets a 1/4 in grid with a 1 in major grid and a 1/8 in snap, converted in metric drawings.

(defun c:Pst-GridInch () (sg:apply "Inch"))

;; Grid Foot
;; Sets a 1 in grid with a 1 ft major grid and a 1/8 in snap, converted in metric drawings.

(defun c:Pst-GridFoot () (sg:apply "Foot"))

;; Grid Centimeter
;; Sets a 2 mm grid with a 1 cm major grid and a 1 mm snap, converted in imperial drawings.

(defun c:Pst-GridCentimeter () (sg:apply "Centimeter"))

;; Grid Meter
;; Sets a 100 mm grid with a 1 m major grid and a 25 mm snap, converted in imperial drawings.

(defun c:Pst-GridMeter () (sg:apply "Meter"))
