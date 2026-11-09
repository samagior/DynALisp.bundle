;; SetUnits - Sets the drawing units
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

; Set drawing units


;;  The presets are the child commands Pst-* below, run by their aliases or
;;  picked in the Dyl-SetUnits dialog (Dyl:ChildPicker). Their values are in
;;  Modules\Dynalisp\Remote\Dyl-DrawingSetup.lsp, where the default units of the imperial
;;  and metric drawings (chosen in Dyl-Settings) are checked when each drawing opens.

;; Set Units
;; Lists the unit settings with their aliases and applies the one picked.

(defun c:Dyl-SetUnits ()
  (Dyl:ChildPicker "Dyl-SetUnits.lsp" "Set Units" "Double-click a unit setting (or OK) to apply it." '*su:last*)
)

;;  Apply the unit preset key and confirm it:
(defun su:apply (key)
  (Remote>>Dyl:UnitsApply key)
  (princ (strcat "\nUnits set to " (Remote>>Dyl:UnitsName key) "."))
  (princ)
)

;; Units Metric 1 mm
;; Sets the drawing units to decimal with a 1 mm precision.

(defun c:Pst-UnitsMetricMm () (su:apply "MetricMm"))

;; Units Metric 0.1 mm
;; Sets the drawing units to decimal with a 0.1 mm precision.

(defun c:Pst-UnitsMetricTenthMm () (su:apply "MetricTenthMm"))

;; Units Metric 0.01 mm
;; Sets the drawing units to decimal with a 0.01 mm precision.

(defun c:Pst-UnitsMetricHundredthMm () (su:apply "MetricHundredthMm"))

;; Units Imperial 1/16 in
;; Sets the drawing units to architectural with a 1/16 in precision.

(defun c:Pst-UnitsImperialSixteenthIn () (su:apply "ImperialSixteenthIn"))
