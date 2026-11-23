;; Batch Insert - Inserts every drawing of a folder side by side as blocks
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

;; Each drawing of the folder picked is inserted as a block (scale 1, rotation 0) in the
;; current space, on the current layer, from left to right: the bottom of each block on
;; the X axis, a gap of a tenth of the widest drawing so far between two blocks. A
;; drawing whose name is already a block of this drawing is skipped (its block would be
;; redefined), and so are the current drawing and the files that cannot be inserted.
;; One UNDO removes it all.

;; Batch Insert
;; Inserts every drawing of a folder side by side as blocks in the current drawing.

(defun c:Dyl-BatchInsert (/ *error* doc spc dir fls own x gap nam ful blk box mn mx w n skp)
  (defun *error* (msg)
    (if doc (vla-EndUndoMark doc))
    (if (not (wcmatch (strcase msg T) "*break*,*cancel*,*exit*"))
      (princ (strcat "\nError: " msg))
    )
    (princ)
  )
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object))
        own (strcase (strcat (getvar 'dwgprefix) (getvar 'dwgname)))
  )
  (cond
    ((not (setq dir (Local>>BatchInsertFolder "Select the folder of the drawings to insert")))
     (princ "\nNo folder selected.")
    )
    ((not (setq fls (acad_strlsort (vl-directory-files dir "*.dwg" 1))))
     (princ (strcat "\nNo drawing in " dir))
    )
    (T
     ;; Paper space when a layout is current and no viewport is active, else model space:
     (setq spc (if (and (= 0 (getvar 'tilemode)) (= 1 (getvar 'cvport)))
                 (vla-get-PaperSpace doc)
                 (vla-get-ModelSpace doc)
               )
           x   0.0
           gap 0.0
           n   0
           skp 0
     )
     (vla-StartUndoMark doc)
     (foreach fle fls
       (setq ful (strcat dir fle)
             nam (vl-filename-base fle)
       )
       (cond
         ((= (strcase ful) own) (setq skp (1+ skp)))
         ((or (tblsearch "BLOCK" nam) (not (snvalid nam)))
          (princ (strcat "\n" fle ": skipped, " (if (snvalid nam) "already a block of this drawing." "not a valid block name.")))
          (setq skp (1+ skp))
         )
         ((vl-catch-all-error-p
            (setq blk (vl-catch-all-apply 'vla-InsertBlock (list spc (vlax-3d-point x 0.0 0.0) ful 1.0 1.0 1.0 0.0)))
          )
          (princ (strcat "\n" fle ": not inserted, " (vl-catch-all-error-message blk)))
          (setq skp (1+ skp))
         )
         (T
          (setq n (1+ n))
          ;; Move the block so its left edge is at x and its bottom on the X axis:
          (if
            (not
              (vl-catch-all-error-p
                (setq box (vl-catch-all-apply 'vla-GetBoundingBox (list blk 'mn 'mx)))
              )
            )
            (progn
              (setq mn (vlax-safearray->list mn)
                    mx (vlax-safearray->list mx)
                    w  (- (car mx) (car mn))
                    gap (max gap (* 0.1 w))
              )
              (vla-Move blk
                        (vlax-3d-point (car mn) (cadr mn) 0.0)
                        (vlax-3d-point x 0.0 0.0)
              )
              (setq x (+ x w gap))
            )
          )
         )
       )
     )
     (vla-EndUndoMark doc)
     (if (> n 0) (vla-ZoomExtents (vlax-get-acad-object)))
     (princ (strcat "\n" (itoa n) " drawing(s) inserted" (if (> skp 0) (strcat ", " (itoa skp) " skipped.") ".")))
    )
  )
  (princ)
)


;; The folder picked in the folder browser of Windows (a path can be typed in it),
;; ending with a backslash, or nil. By Tony Tanzillo, modified by Tim Willey.
(defun Local>>BatchInsertFolder (msg / sh folder self result)
  (vl-load-com)
  (setq sh (vla-getInterfaceObject (vlax-get-acad-object) "Shell.Application"))
  ;; 16: the path can be typed in the browser
  (setq folder (vl-catch-all-apply 'vlax-invoke-method
                 (list sh 'BrowseForFolder (vla-get-HWND (vlax-get-acad-object)) msg 16)
               )
  )
  (vlax-release-object sh)
  (if (and folder (not (vl-catch-all-error-p folder)))
    (progn
      (setq self   (vlax-get-property folder 'Self)
            result (vlax-get-property self 'Path)
      )
      (vlax-release-object self)
      (vlax-release-object folder)
      (if (and result (vl-file-directory-p result))
        (if (= (substr result (strlen result)) "\\") result (strcat result "\\"))
      )
    )
  )
)
