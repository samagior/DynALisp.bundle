;;  Count Attribute Values
;;  Copyright (C) 2026  Samuel Martineau
;;
;;  This program is free software: you can redistribute it and/or modify
;;  it under the terms of the GNU General Public License as published by
;;  the Free Software Foundation, either version 3 of the License, or
;;  (at your option) any later version.
;;
;;  This program is distributed in the hope that it will be useful,
;;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;  GNU General Public License for more details.
;;
;;  You should have received a copy of the GNU General Public License
;;  along with this program.  If not, see <https://www.gnu.org/licenses/>.
;;
;;  Author licence applies on top of the above GPL licence, See
;;  the "Licences" folder or Author domain for more details.
;;
;;----------------------------------------------------------------------;;

;;-----------------=={ Count Attribute Values }==-------------;;
;;                                                            ;;
;;  Counts the number of occurrences of attribute values in a ;;
;;  selection of attributed blocks. Displays result in an     ;;
;;  AutoCAD Table object.                                     ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright � 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;

;; Count Attribute Values
;; Counts the occurrences of attribute values in the selected blocks and lists them in a table.

(defun c:LM-CountAttributeValues ( / _Dxf _Assoc++ _SumAttributes ss i alist )

  (defun _Dxf ( key alist ) (cdr (assoc key alist)))

  (defun _Assoc++ ( key alist )
    (
      (lambda ( pair )
        (if pair
          (subst (list key (1+ (cadr pair))) pair alist)
          (cons  (list key 1) alist)
        )
      )
      (assoc key alist)
    )
  )

  (defun _SumAttributes ( entity alist )
    (while
      (not
        (eq "SEQEND"
          (_dxf 0
            (entget
              (setq entity
                (entnext entity)
              )
            )
          )
        )
      )
      (setq alist (_Assoc++ (_Dxf 1 (reverse (entget entity))) alist))
    )
  )

  (cond
    (
      (not
        (vlax-method-applicable-p
          (setq space
            (vlax-get-property
              (setq doc
                (vla-get-ActiveDocument (vlax-get-acad-object))
              )
              (if (= 1 (getvar 'CVPORT)) 'Paperspace 'Modelspace)
            )
          )
          'AddTable
        )
      )

      (princ "\n** This Version of AutoCAD Does not Support Tables **")
    )
    (
      (and (setq ss (ssget '((0 . "INSERT") (66 . 1))))
        (repeat (setq i (sslength ss))
          (setq alist (_SumAttributes (ssname ss (setq i (1- i))) alist))
        )
        (setq pt (getpoint "\nPick Point for Table: "))
      )
     
      (LM:AddTable space (trans pt 1 0) "Attribute Totals"
        (cons '("Value" "Total")
          (vl-sort
            (mapcar
              (function
                (lambda ( pair )
                  (list (car pair) (itoa (cadr pair)))
                )
              )
              alist
            )
            (function (lambda ( a b ) (< (strcase (car a)) (strcase (car b)))))
          )
        )
      )
    )
  )

  (princ)
)

;;---------------------=={ Add Table }==----------------------;;
;;                                                            ;;
;;  Creates a VLA Table Object at the specified point,        ;;
;;  populated with title and data                             ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright � 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  space - VLA Block Object                                  ;;
;;  pt    - Insertion Point for Table                         ;;
;;  title - Table title                                       ;;
;;  data  - List of data to populate the table                ;;
;;------------------------------------------------------------;;
;;  Returns:  VLA Table Object                                ;;
;;------------------------------------------------------------;;

(defun LM:AddTable ( space pt title data / _itemp ) (vl-load-com)

  (defun _itemp ( collection item )
    (if
      (not
        (vl-catch-all-error-p
          (setq item
            (vl-catch-all-apply 'vla-item (list collection item))
          )
        )
      )
      item
    )
  )

  (
    (lambda ( table ) (vla-put-StyleName table (getvar 'CTABLESTYLE)) (vla-SetText table 0 0 title)
      (
        (lambda ( row )
          (mapcar
            (function
              (lambda ( rowitem ) (setq row (1+ row))
                (
                  (lambda ( column )
                    (mapcar
                      (function
                        (lambda ( item )
                          (vla-SetText table row
                            (setq column (1+ column)) item
                          )
                        )
                      )
                      rowitem
                    )
                  )
                  -1
                )
              )
            )
            data
          )
        )
        0
      )
      table
    )
    (
      (lambda ( textheight )
        (vla-AddTable space (vlax-3D-point pt) (1+ (length data)) (length (car data)) (* 1.8 textheight)
          (* textheight
            (apply 'max
              (cons (/ (strlen title) (length (car data)))
                (mapcar 'strlen (apply 'append data))
              )
            )
          )
        )
      )
      (vla-getTextHeight
        (_itemp
          (_itemp
            (vla-get-Dictionaries
              (vla-get-ActiveDocument (vlax-get-acad-object))
            )
            "ACAD_TABLESTYLE"
          )
          (getvar 'CTABLESTYLE)
        )
        acDataRow
      )
    )
  )
)

;(princ)