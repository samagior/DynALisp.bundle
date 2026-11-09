;Dyl-LayerShow - Additionnal layers to show from the defaul layer filter
;Copyright (C) 2023  Samuel Martineau
;
;This program is free software: you can redistribute it and/or modify
;it under the terms of the GNU General Public License as published by
;the Free Software Foundation, either version 3 of the License, or
;(at your option) any later version.
;
;This program is distributed in the hope that it will be useful,
;but WITHOUT ANY WARRANTY; without even the implied warranty of
;MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;GNU General Public License for more details.
;
;You should have received a copy of the GNU General Public License
;along with this program.  If not, see <https://www.gnu.org/licenses/>.


;///////////////////////////////////////////////////////////////////////////
;                        Directly Related Functions
;///////////////////////////////////////////////////////////////////////////


(defun Dyl:UtilDimText () 
  (setq *ent:nam (entsel "\nSelect dimension:"))
  (setq *ent:prp (entget (car *ent:nam)))
  (setq *ent:str (cdr (assoc 1 *ent:prp)))
  (if (= nil (wcmatch *ent:str (strcat "*" *val "*"))) 
    (progn 
      (if (= T (wcmatch *ent:str "*<>*")) 
        (progn 
          (setq *new (vl-string-subst (strcat *val "<>") "<>" *ent:str))
          (setq *ent:prp (subst (cons 1 *new) (assoc 1 *ent:prp) *ent:prp))
          (entmod *ent:prp)
        )
        (progn 
          (if (= T (wcmatch *ent:str "")) 
            (progn 
              (setq *new (strcat *val "<>"))
              (setq *ent:prp (subst (cons 1 *new) (assoc 1 *ent:prp) *ent:prp))
              (entmod *ent:prp)
            )
          )
        )
      )
    )
    (progn 
      (if (= *ent:str (strcat *val "<>")) 
        (progn 
          (setq *new "")
          (setq *ent:prp (subst (cons 1 *new) (assoc 1 *ent:prp) *ent:prp))
          (entmod *ent:prp)
        )
        (progn 
          (setq *new (vl-string-subst "<>" (strcat *val "<>") *ent:str))
          (setq *ent:prp (subst (cons 1 *new) (assoc 1 *ent:prp) *ent:prp))
          (entmod *ent:prp)
        )
      )
    )
  )
  (princ)
)


;///////////////////////////////////////////////////////////////////////////
;                         Externally defined commands
;///////////////////////////////////////////////////////////////////////////


;;  The presets are the child commands Pst-* below, run by their aliases or
;;  picked in the Dyl-QuickAddPrefixSuffix dialog (Dyl:ChildPicker).

;; Quick Add Prefix / Suffix
;; Lists the dimension text presets with their aliases and applies the one picked.

(defun c:Dyl-QuickAddPrefixSuffix ()
  (Dyl:ChildPicker "Dyl-QuickAddPrefixSufix.lsp" "Quick Add Prefix / Suffix" "Double-click a dimension text (or OK), then select the dimension." '*qa:last*)
)

;; Dimension Text Plus-Minus
;; Toggles the plus-minus prefix on the text of the selected dimension.

(defun c:Pst-DimensionTextPlusMinus () 
  (setq *typ "prefix"
        *val "± "
  )
  (Dyl:UtilDimText)
)

;; Dimension Text Diameter
;; Toggles the diameter prefix on the text of the selected dimension.

(defun c:Pst-DimensionTextDiameter ()
  (setq *typ "prefix"
        *val "%%c"
  )
  (Dyl:UtilDimText)
)

;; Dimension Text Maximum
;; Toggles the max. prefix on the text of the selected dimension.

(defun c:Pst-DimensionTextMaximum () 
  (setq *typ "prefix"
        *val "max. "
  )
  (Dyl:UtilDimText)
)

;; Dimension Text Minimum
;; Toggles the min. prefix on the text of the selected dimension.

(defun c:Pst-DimensionTextMinimum () 
  (setq *typ "prefix"
        *val "min. "
  )
  (Dyl:UtilDimText)
)

;; Dimension Text Typical
;; Toggles the (TYP) suffix on the text of the selected dimension.

(defun c:Pst-DimensionTextTypical () 
  (setq *typ "sufix"
        *val " (TYP)"
  )
  (Dyl:UtilDimText)
)

;; Dimension Text OB
;; Toggles the (OB) suffix on the text of the selected dimension.

(defun c:Pst-DimensionTextOB () 
  (setq *typ "sufix"
        *val " (OB)"
  )
  (Dyl:UtilDimText)
)

;; Dimension Text OL
;; Toggles the (OL) suffix on the text of the selected dimension.

(defun c:Pst-DimensionTextOL () 
  (setq *typ "sufix"
        *val " (OL)"
  )
  (Dyl:UtilDimText)
)