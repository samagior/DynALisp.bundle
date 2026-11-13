;; MLList - Lists multileaders and blocks grouped by attribute values
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

;;; ===========================================================
;;; MLLIST - List selected multileaders and/or block inserts
;;;          grouped by attribute values, with count per group
;;;
;;; Usage : MLLIST -> runs on pre-selected entities, or
;;;                   prompts for selection if none selected
;;; Output: one compact line per unique group + count
;;; ===========================================================

;; Multileader and Block List
;; Lists the selected multileaders and blocks grouped by attribute values with a count per group.

(defun c:Dyl-MultileaderList (/ ss i ent obj doc blocks blkname blkdef tag val key disp entry tally total count atts) 
  (vl-load-com)
  (setq ss (ssget "_I" '((-4 . "<OR") (0 . "MULTILEADER") (0 . "INSERT") (-4 . "OR>"))))
  (if (not ss) 
    (progn 
      (princ "\nSelect multileaders or blocks: ")
      (setq ss (ssget '((-4 . "<OR") (0 . "MULTILEADER") (0 . "INSERT") (-4 . "OR>"))))
    )
  )
  (if ss 
    (progn 
      (setq doc    (vla-get-ActiveDocument (vlax-get-acad-object))
            blocks (vla-get-Blocks doc)
            i      0
            tally  nil
            total  0
      )
      (repeat (sslength ss) 
        (setq ent   (ssname ss i)
              obj   (vlax-ename->vla-object ent)
              key   ""
              disp  ""
              total (1+ total)
        )
        (cond 
          ;; --- Block insert ---
          ((= (vla-get-ObjectName obj) "AcDbBlockReference")
           (setq blkname (vla-get-Name obj)
                 key     (strcat "BLK:" blkname)
                 disp    ""
           )
           (if (= (vla-get-HasAttributes obj) :vlax-true) 
             (foreach attref (vlax-safearray->list (vlax-variant-value (vla-GetAttributes obj))) 
               (setq tag (vla-get-TagString attref)
                     val (vla-get-TextString attref)
               )
               (setq key  (strcat key "|" tag "=" val)
                     disp (strcat disp 
                                  (if (= disp "") "" "  ")
                                  tag
                                  "=\""
                                  val
                                  "\""
                          )
               )
             )
           )
           (if (= disp "") (setq disp (strcat blkname " (no attributes)")))
          )
          ;; --- Multileader with block content ---
          ((= (vla-get-ContentType obj) acBlockContent)
           (setq blkname (vla-get-ContentBlockName obj)
                 key     (strcat "BLK:" blkname)
           )
           (setq blkdef (vla-Item blocks blkname))
           (vlax-for sub blkdef 
             (if (= (vla-get-ObjectName sub) "AcDbAttributeDefinition") 
               (progn 
                 (setq tag (vla-get-TagString sub)
                       val (vl-catch-all-apply 
                             'vla-GetBlockAttributeValue
                             (list obj (vla-get-ObjectID sub))
                           )
                       val (if (vl-catch-all-error-p val) "<error>" val)
                 )
                 (setq key  (strcat key "|" tag "=" val)
                       disp (strcat disp 
                                    (if (= disp "") "" "  ")
                                    tag
                                    "=\""
                                    val
                                    "\""
                            )
                 )
               )
             )
           )
           (if (= disp "") (setq disp "(no attributes)"))
          )
          ;; --- Multileader with text content ---
          ((= (vla-get-ContentType obj) acMTextContent)
           (setq val  (vla-get-TextString obj)
                 key  (strcat "TXT:" val)
                 disp (strcat "\"" val "\"")
           )
          )
          (T
           (setq key  "NONE"
                 disp "<no content>"
           )
          )
        )
        (setq entry (assoc key tally))
        (if entry 
          (setq tally (subst (list key (1+ (cadr entry)) disp) entry tally))
          (setq tally (append tally (list (list key 1 disp))))
        )
        (setq i (1+ i))
      )
      (setq tally (vl-sort tally (function (lambda (a b) (< (caddr a) (caddr b))))))
      (foreach entry tally 
        (setq count (cadr entry)
              disp  (caddr entry)
        )
        (princ (strcat "\n" disp "  [x" (itoa count) "]"))
      )
      (princ (strcat "\n\nTotal: " (itoa total) " | Groups: " (itoa (length tally))))
    )
    (princ "\nNo multileaders or blocks selected.")
  )
  (princ)
)
(princ "\nMLLIST loaded. Type Dyl-MultileaderList to run.")
(princ)
