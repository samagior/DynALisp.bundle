;; UngroupNext - Dissolves every group association of a selection
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

;;;-----------------------------------------------------------------------
;;; UngroupNext.lsp
;;;
;;; Command: UNGROUPNEXT
;;;
;;; Purpose:
;;;   Fully dissolves every group association for a selection, including
;;;   objects that belong to MORE THAN ONE group at once (the situation
;;;   the native UNGROUP / -GROUP "Explode" command handles at the
;;;   command line with its "Next" sub-option, where you keep typing
;;;   Next to cycle through the additional groups a pick point belongs
;;;   to and ungroup each one in turn).
;;;
;;; Why not just script "Next" at the command line?
;;;   AutoLISP has no reliable way to read the dynamic command-line
;;;   prompt text of -GROUP/UNGROUP to know whether it should send
;;;   "Next" again or stop. Instead this routine talks to the drawing's
;;;   Group dictionary directly (via ActiveX): it repeatedly scans every
;;;   AcadGroup in the drawing, and for any group that still contains
;;;   one of your originally selected objects, it deletes (ungroups)
;;;   that group. It keeps looping until a full pass removes nothing
;;;   more - i.e. it recurses through every level/overlap of group
;;;   membership, exactly like manually repeating
;;;   UNGROUP -> pick -> (Next -> pick again) until nothing is left.
;;;
;;;   Note: "ungrouping" only deletes the group DEFINITION - it never
;;;   erases or otherwise changes the entities themselves, same as the
;;;   native UNGROUP command.
;;;
;;; Usage:
;;;   1. APPLOAD this file (or drag & drop it into the AutoCAD window).
;;;   2. Type UNGROUPNEXT at the command line.
;;;   3. Select one or more objects/groups (a single pick on any member
;;;      of a group is enough - you do not need to select every member).
;;;   4. Press Enter to finish selection. The routine reports each
;;;      group it removes, then confirms when the selection is fully
;;;      ungrouped at every level.
;;;-----------------------------------------------------------------------

;; Ungroup Nested
;; Removes every group, at every nesting level, that contains the selected objects.

(defun c:Dyl-UngroupNext (/ doc ss n i selentities anydeleted groups grouplist grp gname count j memberobj matched) 

  (vl-load-com)

  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))

  (princ "\nUNGROUPNEXT - select object(s)/group(s) to fully ungroup (all overlapping groups will be removed): ")
  (setq ss (ssget))

  (cond 
    ((null ss)
     (princ "\nNothing selected.")
    )
    (T
     ;; Collect entity names of the current selection for fast lookups.
     (setq selentities '())
     (setq n (sslength ss))
     (setq i 0)
     (while (< i n) 
       (setq selentities (cons (ssname ss i) selentities))
       (setq i (1+ i))
     )

     (setq anydeleted T)
     (while anydeleted 
       (setq anydeleted nil)
       (setq groups (vla-get-Groups doc))

       ;; Snapshot the current groups into a plain list so deleting one
       ;; mid-loop can't disturb the collection we're iterating over.
       (setq grouplist '())
       (vlax-for g groups (setq grouplist (cons g grouplist)))

       (foreach grp grouplist 
         (if 
           (not 
             (vl-catch-all-error-p 
               (vl-catch-all-apply 'vlax-erased-p (list grp))
             )
           )
           (if (not (vlax-erased-p grp)) 
             (progn 
               (setq count (vla-get-Count grp))
               (setq matched nil)
               (setq j 0)
               (while (and (not matched) (< j count)) 
                 (setq memberobj (vla-Item grp j))
                 (if (member (vlax-vla-object->ename memberobj) selentities) 
                   (setq matched T)
                 )
                 (setq j (1+ j))
               )
               (if matched 
                 (progn 
                   (setq gname (vla-get-Name grp))
                   (princ (strcat "\n  Ungrouping: " gname))
                   (vla-Delete grp)
                   (setq anydeleted T)
                 )
               )
             )
           )
         )
       )
     )
     (princ "\nDone: all group associations for the selection have been removed, recursively.")
    )
  )
  (princ)
)

(princ "\nUngroupNext.lsp loaded. Type Dyl-UngroupNext to run.")
(princ)