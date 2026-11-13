;; LayerList - Draw lines and text for each layer in the drawing (for layer backup and standard making)
;; Copyright (C) 2024  Samuel Martineau
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

;; Layer Drawing List
;; Draws a line and a label with the description of each layer of the drawing or of the selection.

(defun c:Dyl-LayerList (/ pt rsp dat ln lst desln) 
  (initget "All Select")
  (setq pt (getpoint "\nSelect insertion point: "))
  (initget "Select All")
  (setq rsp (getkword "\nSpecify option [Select / All] <All>:"))
  (cond 
    ((= rsp "Select")
     (mapcar '(lambda (x) (setq pt (lnd-list pt x))) 
             (progn 
               (acad_strlsort 
                 (mapcar '(lambda (x) (and (null (member x lst)) (setq lst (cons x lst)))) 
                         (mapcar '(lambda (x) (cdr (assoc 8 (entget x)))) 
                                 (vl-remove-if 'listp (mapcar 'cadr (ssnamex (ssget))))
                         )
                 )
               )
               lst
             )
     )
    )
    (t (while (setq dat (tblnext "layer" (null dat))) (setq pt (lnd-list pt (cdr (assoc 2 dat))))))
  )
  (princ)
)


(defun lnd-list (pt ln / desln) 
  (entmake (list '(0 . "line") (cons 10 pt) (cons 11 (mapcar '+ pt '(200 0))) (cons 8 ln)))
  (entmake (list '(0 . "text") (cons 10 (mapcar '+ pt '(0 1))) '(40 . 2.25) (cons 1 ln) (cons 8 ln)))
  (if (zerop (strlen (setq desln (getpropertyvalue (tblobjname "layer" ln) "Description")))) 
    ()
    (entmake (list '(0 . "text") (cons 10 (mapcar '+ pt '(75 1))) '(40 . 2.25) (cons 1 desln) (cons 8 ln)))
  )
  (mapcar '- pt '(0 7.5))
)