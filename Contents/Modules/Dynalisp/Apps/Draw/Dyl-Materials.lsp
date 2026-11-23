;; Materials - Create and edit the Dynalisp materials used by the drawing tools
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

;;  The materials (Materials.csv, their hatch presets, the hatching, the window
;;  Res\Dyl-Materials.xaml, the material written on the objects) are in
;;  Modules\Dynalisp\Remote\Dyl-Materials.lsp, loaded at startup for every App. The same
;;  window opens from the Quick Draw and Quick Shape windows (the open button beside
;;  Material). The child commands give, match and show the material of the objects of the
;;  drawing.

;;-------------------------=={ Commands }==------------------------;;

;; Materials
;; Opens a window to create and edit the materials used by Quick Draw and Quick Shape: their hatch presets and their data.

(defun c:Dyl-Materials ()
  (Remote>>Dyl:Manager "Materials")
  (princ)
)
;; Material Assign
;; Gives a material to the hatches and closed outlines selected, or takes it off (None), so a detail drawn without DynALisp can be simulated.

(defun c:Pst-MaterialAssign (/ ss id)
  (if (setq ss (Dyl:MaterialSel "\nSelect the hatches and closed outlines to give a material:" T))
    (if (setq id (Dyl:MaterialAssignDialog (Remote>>Dyl:MaterialOf (ssname ss 0)) (sslength ss)))
      (Dyl:MaterialGive ss id)
    )
  )
  (princ)
)

;; Material Match
;; Gives the material of an object to other hatches and closed outlines, as MATCHPROP does for properties.

(defun c:Pst-MaterialMatch (/ src id ss)
  (while (and (setq src (entsel "\nSelect the object whose material to give: "))
              (not (setq id (Remote>>Dyl:MaterialOf (car src))))
         )
    (princ "\nThis object has no material.")
  )
  (if id
    (progn
      (princ (strcat "\nMaterial: " (Dyl:MaterialLabel id)))
      (if (setq ss (Dyl:MaterialSel "\nSelect the objects to give it to:" nil))
        (progn
          (ssdel (car src) ss)
          (if (< 0 (sslength ss)) (Dyl:MaterialGive ss id))
        )
      )
    )
  )
  (princ)
)

;; Material Show
;; Shows the material of the objects selected, with its data, the tool and the preset that drew them.

(defun c:Pst-MaterialShow (/ ss)
  (if (setq ss (ssget "_I"))
    (sssetfirst nil nil)
    (progn
      (princ "\nSelect the objects whose material to show:")
      (setq ss (ssget))
    )
  )
  (if ss (Dyl:MaterialShow ss))
  (princ)
)

;;-------------------------=={ Material of an object }==------------------------;;

;;  The material of an object is written on it (its DynALisp data, see
;;  Remote>>Dyl:MaterialTags in Remote\Dyl-Materials.lsp): Quick Draw and Quick Shape write it
;;  on what they draw; the commands above write it on any hatch or closed outline, so a detail
;;  drawn without DynALisp can be simulated too.

;;  The objects picked that can carry a material (a hatch or a closed curve, see
;;  Remote>>Dyl:MaterialTaggable-p): those selected before the command when pre is T, else
;;  asked after the prompt msg. An open curve is left out, with a message. nil when none:
(defun Dyl:MaterialSel (msg pre / flt ss res i e skip)
  (setq flt (list (cons 0 *mt:tagtypes*)))
  (if (and pre (setq ss (ssget "_I" flt)))
    (sssetfirst nil nil)
    (progn
      (princ msg)
      (setq ss (ssget flt))
    )
  )
  (if ss
    (progn
      (setq res  (ssadd)
            i    0
            skip 0
      )
      (repeat (sslength ss)
        (setq e (ssname ss i)
              i (1+ i)
        )
        (if (Remote>>Dyl:MaterialTaggable-p e) (ssadd e res) (setq skip (1+ skip)))
      )
      (if (< 0 skip) (princ (strcat "\n" (itoa skip) " open object(s) left out: only a hatch or a closed outline has a material.")))
      (if (< 0 (sslength res)) res (progn (princ "\nNo hatch or closed outline selected.") nil))
    )
  )
)

;;  The material row of the id (as the Materials window edits it: id group name cut surface
;;  conductivity density resistance), nil when it no longer exists:
(defun Dyl:MaterialRowOf (id)
  (cond ((assoc id (cadr (Remote>>Dyl:MaterialBoth)))) ((assoc id (Remote>>Dyl:MaterialRowDefs))))
)

;;  The material id as the user reads it: "Name (Group)", "id (no longer exists)":
(defun Dyl:MaterialLabel (id / m)
  (if (setq m (Dyl:MaterialRowOf id))
    (strcat (nth 2 m) " (" (nth 1 m) ")")
    (strcat id " (no longer exists)")
  )
)

;;  The items of the Material list of the Assign Material window: (("" . "None") (id . "Group
;;  - Name") ...), by the order of the groups of the materials (a group that is not one of
;;  them after), then by name:
(defun Dyl:MaterialAssignList (/ grps rows)
  (setq grps (mapcar 'strcase (Remote>>Dyl:GroupsOf "Material"))
        rows (vl-sort (cadr (Remote>>Dyl:MaterialBoth))
                      '(lambda (a b / ga gb)
                         (setq ga (cond ((vl-position (strcase (cadr a)) grps)) (999))
                               gb (cond ((vl-position (strcase (cadr b)) grps)) (999))
                         )
                         (if (= ga gb)
                           (< (strcase (strcat (cadr a) " - " (caddr a))) (strcase (strcat (cadr b) " - " (caddr b))))
                           (< ga gb)
                         )
                       )
             )
  )
  (cons '("" . "None") (mapcar '(lambda (m) (cons (car m) (strcat (cadr m) " - " (caddr m)))) rows))
)

;;  The Assign Material window (Res\Dyl-MaterialAssign.xaml) for n objects, cur the id of the
;;  material of the first one (nil: none, None picked): its open button opens the Materials
;;  window (code 2), then this one again on the material picked. Returns the id picked, ""
;;  for None, nil on Cancel:
(defun Dyl:MaterialAssignDialog (cur n / lst res)
  (while
    (progn
      (setq lst (Dyl:MaterialAssignList)
            res (Dyl:WinShow "Dyl-MaterialAssign.xaml"
                             (append (Dyl:WinList "mat" (mapcar 'cdr lst) (cond ((vl-position cur (mapcar 'car lst))) (0)))
                                     (list (cons "cnt" (strcat (itoa n) (if (= 1 n) " object selected" " objects selected"))))
                             )
                )
      )
      (if (= 2 (car res))
        (progn
          (setq cur (car (nth (Dyl:WinIdx res "mat") lst)))
          (Remote>>Dyl:MaterialDialog nil)
          T
        )
      )
    )
  )
  (if (= 1 (car res)) (car (nth (Dyl:WinIdx res "mat") lst)))
)

;;  Give the material id ("": none) to the objects of the selection ss, in place of the one
;;  they have and of the tool and preset that drew them (the data of another tool are kept),
;;  in one undo step, with a message:
(defun Dyl:MaterialGive (ss id / doc i n bad)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object))
        i   0
        n   0
        bad 0
  )
  (vla-StartUndoMark doc)
  (repeat (sslength ss)
    (if (Remote>>Dyl:MaterialTagPut (ssname ss i) (list (cons "Material" id) '("Tool") '("Preset") '("Assembly") '("Layer") '("Role")))
      (setq n (1+ n))
      (setq bad (1+ bad))
    )
    (setq i (1+ i))
  )
  (vla-EndUndoMark doc)
  (princ (if (= "" id)
           (strcat "\nMaterial taken off " (itoa n) " object(s).")
           (strcat "\n" (itoa n) " object(s) made of " (Dyl:MaterialLabel id) ".")
         )
  )
  (if (< 0 bad) (princ (strcat "\n--> " (itoa bad) " object(s) not changed (on a locked layer).")))
)

;;  The data of the material row m as text, in the units of the drawing as the Materials window
;;  shows them (see *mt:data*), "" when it has none:
(defun Dyl:MaterialDataText (m / imp lst v)
  (setq imp (Remote>>Dyl:MaterialImperial-p))
  (foreach d (list (list 5 "Conductivity" "W/m.K" "Btu.in/h.ft2.F")
                   (list 6 "Density" "kg/m3" "lb/ft3")
                   (list 7 "Resistance" "RSI" "R")
                   (list 8 "Vapour permeability" "ng/Pa.s.m" "perm-in")
                   (list 9 "Vapour permeance" "ng/Pa.s.m2" "perm")
             )
    (if (setq v (distof (cond ((nth (car d) m)) ("")) 2))
      (setq lst (cons (strcat (cadr d) " "
                              (Remote>>Dyl:MaterialSig (if imp (* v (cadr (assoc (car d) *mt:data*))) v))
                              " " (if imp (cadddr d) (caddr d))
                      )
                      lst
                )
      )
    )
  )
  (Remote>>LM:lst->str (reverse lst) ", ")
)

;;  Show the material of the objects of the selection ss on the command line: for one object,
;;  its material, its data and what drew it; for several, how many of each material:
(defun Dyl:MaterialShow (ss / e id m d tg cnt i k)
  (if (= 1 (sslength ss))
    (progn
      (setq e  (ssname ss 0)
            id (Remote>>Dyl:MaterialOf e)
            tg (Remote>>Dyl:MaterialTags e)
      )
      (cond
        ((not id)
         (princ (strcat "\n" (cdr (assoc 0 (entget e)))
                        (if (Remote>>Dyl:MaterialTaggable-p e) ": no material." ": no material (only a hatch or a closed outline has one).")
                )
         )
        )
        (T
         (princ (strcat "\n" (cdr (assoc 0 (entget e))) ": " (Dyl:MaterialLabel id)))
         (if (and (setq m (Dyl:MaterialRowOf id)) (/= "" (setq d (Dyl:MaterialDataText m))))
           (princ (strcat "\n  " d))
           (if m (princ "\n  No data for this material (see the Materials window)."))
         )
         (if (setq k (cdr (assoc "Tool" tg)))
           (princ (strcat "\n  Drawn by " (cond ((= "QuickDraw" k) "Quick Draw") ((= "QuickShape" k) "Quick Shape") (k))
                          (if (cdr (assoc "Preset" tg)) (strcat ", preset " (cdr (assoc "Preset" tg))) "")
                          (if (cdr (assoc "Layer" tg))
                            (strcat ", layer " (cdr (assoc "Layer" tg))
                                    (if (cdr (assoc "Assembly" tg)) (strcat " of the assembly " (cdr (assoc "Assembly" tg))) "")
                            )
                            ""
                          )
                  )
           )
         )
         (if (= "Legend" (cdr (assoc "Role" tg))) (princ "\n  A box of a legend: not a part of a detail."))
        )
      )
    )
    (progn
      (setq i 0)
      (repeat (sslength ss)
        (setq k   (cond ((Remote>>Dyl:MaterialOf (ssname ss i))) (""))
              cnt (if (assoc k cnt) (subst (cons k (1+ (cdr (assoc k cnt)))) (assoc k cnt) cnt) (cons (cons k 1) cnt))
              i   (1+ i)
        )
      )
      (princ (strcat "\n" (itoa (sslength ss)) " objects:"))
      (foreach x (reverse cnt)
        (princ (strcat "\n  " (if (= "" (car x)) "No material" (Dyl:MaterialLabel (car x))) ": " (itoa (cdr x))))
      )
    )
  )
)

(princ)
