;; LineToPline - Converts lines into polylines
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

;; Line To Polyline
;; Converts each selected line into a polyline, optionally joining the touching ones.

(defun c:Dyl-LineToPolyline (/ ss i e join pl) 
  (initget "Yes No")
  (setq join (getkword "\nJoin touching polylines? [Yes/No] <No>: "))
  (if (setq ss (ssget '((0 . "LINE")))) 
    (progn 
      (setq pl (ssadd))
      (repeat (setq i (sslength ss)) 
        (setq e (ssname ss (setq i (1- i))))
        (command "PEDIT" e "Y" "")
        (ssadd (entlast) pl)
      )
      (if (and (= join "Yes") (> (sslength pl) 1)) 
        (command "_.JOIN" pl "")
      )
    )
  )
  (princ)
)
