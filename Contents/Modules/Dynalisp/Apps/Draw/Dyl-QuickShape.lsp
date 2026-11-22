;; QuickShape - Insert premade shapes from DWG libraries and fill them with a material
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

;;-------------------------=={ Shape libraries }==------------------------;;

;;  The shapes are the blocks of the library drawings: every .dwg of the Res\Shapes folder
;;  is a library, every block in it is a shape (layouts, xrefs and anonymous blocks
;;  excepted). A shape is named "<Library>|<Block>" (e.g. "Shapes|Stud-2x4"). The block base
;;  point is the insertion point, its units (Block Units) scale it to the drawing units.
;;  The libraries are read with ObjectDBX (not opened), or from the drawing itself when it
;;  is open in AutoCAD.
;;  *qs:folder* is the default folder of the libraries; they are read from its user copy once
;;  a shape was added (User\Modules\Dynalisp\Res\Shapes, see Dyl:QuickShapeDir):
(setq *qs:folder* (strcat (if *dyl:dylres *dyl:dylres (strcat *dyl:dyl "\\Res")) "\\Shapes")
      *qs:tmp*    "DynalispQuickShape"
)

;;  Shapes of the starter library Shapes.dwg, made when the Shapes folder has no library:
;;  (block (x y x y ...) ...), closed polylines in inches, base point at 0,0. An outline
;;  inside another one is an island (the hatch fills the space between them):
(setq *qs:starter*
  '(("Stud-2x4" (0. 0. 3.5 0. 3.5 1.5 0. 1.5))
    ("Stud-2x6" (0. 0. 5.5 0. 5.5 1.5 0. 1.5))
    ("Stud-2x8" (0. 0. 7.25 0. 7.25 1.5 0. 1.5))
    ("Brick-Modular" (0. 0. 3.625 0. 3.625 2.25 0. 2.25))
    ("CMU-8"
     (0. 0. 15.625 0. 15.625 7.625 0. 7.625)
     (1. 1.25 7.3125 1.25 7.3125 6.375 1. 6.375)
     (8.3125 1.25 14.625 1.25 14.625 6.375 8.3125 6.375)
    )
    ("HSS-4x4-0.25" (0. 0. 4. 0. 4. 4. 0. 4.) (0.25 0.25 3.75 0.25 3.75 3.75 0.25 3.75))
   )
)

;;  Item nam of a collection, nil when missing:
(defun Dyl:QuickShapeItem (coll nam / x)
  (if (not (vl-catch-all-error-p (setq x (vl-catch-all-apply 'vla-item (list coll nam))))) x)
)

;;  Database of the drawing path: (document nil) when it is open in AutoCAD, else
;;  (ObjectDBX-document T) to release once used (nil if it cannot be read). Without path:
;;  a new empty ObjectDBX document:
(defun Dyl:QuickShapeDb (path / acad doc)
  (setq acad (vlax-get-acad-object))
  (if path
    (vlax-for d (vla-get-Documents acad)
      (if (= (strcase (vla-get-FullName d)) (strcase path)) (setq doc d))
    )
  )
  (cond
    (doc (list doc nil))
    ((vl-catch-all-error-p
       (setq doc (vl-catch-all-apply 'vla-GetInterfaceObject
                                     (list acad (strcat "ObjectDBX.AxDbDocument." (itoa (atoi (getvar "ACADVER")))))
                 )
       )
     )
     nil
    )
    ((and path (vl-catch-all-error-p (vl-catch-all-apply 'vla-Open (list doc path))))
     (vlax-release-object doc)
     nil
    )
    ((list doc t))
  )
)

;;  Release a database of Dyl:QuickShapeDb:
(defun Dyl:QuickShapeRelease (db)
  (if (cadr db) (vlax-release-object (car db)))
)

;;  Folder of the libraries to read: the user copy when there is one, else the default
;;  folder (see Dyl:UserDir in dynalisp.mnl):
(defun Dyl:QuickShapeDir () (Dyl:UserDir *qs:folder*))

;;  Folder where the libraries are saved: the user copy, made from the default libraries
;;  the first time:
(defun Dyl:QuickShapeDirW () (Dyl:UserDirW *qs:folder*))

;;  Make the starter library Shapes.dwg (see *qs:starter*):
(defun Dyl:QuickShapeStarter (/ db blk dir)
  (setq dir (Dyl:QuickShapeDirW))
  (if (setq db (Dyl:QuickShapeDb nil))
    (progn
      (foreach s *qs:starter*
        (setq blk (vla-Add (vla-get-Blocks (car db)) (vlax-3d-point '(0. 0. 0.)) (car s)))
        (vla-put-Units blk 1) ; inches
        (foreach pts (cdr s) (vla-put-Closed (vlax-invoke blk 'AddLightWeightPolyline pts) :vlax-true))
      )
      (vl-catch-all-apply 'vla-SaveAs (list (car db) (strcat dir "\\Shapes.dwg")))
      (Dyl:QuickShapeRelease db)
    )
  )
)

;;  Library drawings (full paths). The starter library is made when there is none:
(defun Dyl:QuickShapeLibs (/ lst)
  (if (not (setq lst (vl-directory-files (Dyl:QuickShapeDir) "*.dwg" 1)))
    (progn
      (Dyl:QuickShapeStarter)
      (setq lst (vl-directory-files (Dyl:QuickShapeDir) "*.dwg" 1))
    )
  )
  (mapcar '(lambda (f) (strcat (Dyl:QuickShapeDir) "\\" f)) (acad_strlsort lst))
)

;;  Blocks of the library path, sorted. The blocks of a library read with ObjectDBX are kept
;;  in *qs:cache* until the file changes, so the libraries are only read again when edited:
(defun Dyl:QuickShapeBlocks (path / time hit db lst)
  (setq time (vl-file-systime path)
        hit  (assoc (strcase path) *qs:cache*)
  )
  (if (and hit (equal time (cadr hit)))
    (caddr hit)
    (progn
      (if (setq db (Dyl:QuickShapeDb path))
        (progn
          (vlax-for b (vla-get-Blocks (car db))
            (if
              (and (= :vlax-false (vla-get-IsLayout b))
                   (= :vlax-false (vla-get-IsXRef b))
                   (not (wcmatch (vla-get-Name b) "`**"))
              )
              (setq lst (cons (vla-get-Name b) lst))
            )
          )
          (setq lst (acad_strlsort lst))
          ;;  A library open in AutoCAD can change without being saved: it is not cached:
          (if (cadr db)
            (setq *qs:cache* (cons (list (strcase path) time lst) (vl-remove hit *qs:cache*)))
          )
          (Dyl:QuickShapeRelease db)
        )
      )
      lst
    )
  )
)

;;  Every shape of the libraries: ("<Library>|<Block>" ...):
(defun Dyl:QuickShapeList (/ lst)
  (foreach lib (Dyl:QuickShapeLibs)
    (foreach b (Dyl:QuickShapeBlocks lib)
      (setq lst (cons (strcat (vl-filename-base lib) "|" b) lst))
    )
  )
  (reverse lst)
)

;;  Shape "<Library>|<Block>" -> (library-path block):
(defun Dyl:QuickShapeSplit (ref / i)
  (if (setq i (vl-string-search "|" ref))
    (list (strcat (Dyl:QuickShapeDir) "\\" (substr ref 1 i) ".dwg") (substr ref (+ 2 i)))
    (list (strcat (Dyl:QuickShapeDir) "\\Shapes.dwg") ref)
  )
)

;;  Delete the temporary block of the shape from the current drawing (when it is not used):
(defun Dyl:QuickShapePurge (/ blk)
  (if (setq blk (Dyl:QuickShapeItem (vla-get-Blocks (vla-get-ActiveDocument (vlax-get-acad-object))) *qs:tmp*))
    (vl-catch-all-apply 'vla-Delete (list blk))
  )
)

;;  Copy the shape ref into the current drawing as the temporary block *qs:tmp* (its
;;  definition is renamed in an empty ObjectDBX document on the way, so the library is never
;;  changed and a block of the drawing with the same name is never used). Returns T on success:
(defun Dyl:QuickShapeDefine (ref / pr src tmp def ok)
  (setq pr (Dyl:QuickShapeSplit ref))
  (Dyl:QuickShapePurge)
  (if (and (findfile (car pr)) (setq src (Dyl:QuickShapeDb (car pr))))
    (progn
      (if
        (and (setq def (Dyl:QuickShapeItem (vla-get-Blocks (car src)) (cadr pr)))
             (setq tmp (Dyl:QuickShapeDb nil))
        )
        (progn
          (vlax-invoke (car src) 'CopyObjects (list def) (vla-get-Blocks (car tmp)))
          (vla-put-Name (vla-item (vla-get-Blocks (car tmp)) (cadr pr)) *qs:tmp*)
          (vlax-invoke (car tmp)
                       'CopyObjects
                       (list (vla-item (vla-get-Blocks (car tmp)) *qs:tmp*))
                       (vla-get-Blocks (vla-get-ActiveDocument (vlax-get-acad-object)))
          )
          (Dyl:QuickShapeRelease tmp)
          (setq ok t)
        )
      )
      (Dyl:QuickShapeRelease src)
    )
  )
  ok
)

;;  Ask the name of a new shape: a valid block name (Enter: nil):
(defun Dyl:QuickShapeAskName (/ nam)
  (while
    (and (/= "" (setq nam (vl-string-trim " " (getstring t "\nName of the shape <cancel>: "))))
         (not (snvalid nam))
    )
    (princ "\nInvalid block name (no < > / \\ \" : ; ? * | , = `).")
  )
  (if (/= "" nam) nam)
)

;;  Add the objects selected as a new shape (block) of the library path, with a base point and a
;;  name asked on the command line. A shape of the same name is replaced after confirmation.
;;  The library is saved (with ObjectDBX, or as an open drawing) in the user copy of the
;;  libraries folder, made the first time. Returns the new shape ref:
(defun Dyl:QuickShapeAdd (path / ss bp nam db blk objs old i res)
  (setq path (strcat (Dyl:QuickShapeDirW) "\\" (vl-filename-base path) ".dwg"))
  (princ (strcat "\nAdd a shape to " (vl-filename-base path) ".dwg - select its objects:"))
  (cond
    ((not (setq ss (ssget))))
    ((not (setq bp (getpoint "\nBase point of the shape (insertion point): "))))
    ((not (setq nam (Dyl:QuickShapeAskName))))
    ((not (setq db (Dyl:QuickShapeDb path)))
     (alert (strcat "\nError: the library could not be opened:\n" path))
    )
    ((and (setq blk (Dyl:QuickShapeItem (vla-get-Blocks (car db)) nam))
          (progn
            (initget "Yes No")
            (/= "Yes" (getkword (strcat "\nThe shape " nam " exists. Replace it? [Yes/No] <No>: ")))
          )
     )
     (Dyl:QuickShapeRelease db)
    )
    (t
     (if blk
       (progn
         (vlax-for e blk (setq old (cons e old)))
         (foreach e old (vla-Delete e))
       )
       (setq blk (vla-Add (vla-get-Blocks (car db)) (vlax-3d-point (trans bp 1 0)) nam))
     )
     (vla-put-Origin blk (vlax-3d-point (trans bp 1 0)))
     (vla-put-Units blk (getvar "INSUNITS"))
     (repeat (setq i (sslength ss)) (setq objs (cons (vlax-ename->vla-object (ssname ss (setq i (1- i)))) objs)))
     (vlax-invoke (vla-get-ActiveDocument (vlax-get-acad-object)) 'CopyObjects objs blk)
     (if
       (vl-catch-all-error-p
         (vl-catch-all-apply (if (cadr db) 'vla-SaveAs 'vla-Save) (if (cadr db) (list (car db) path) (list (car db))))
       )
       (alert (strcat "\nError: the library could not be saved:\n" path "\n(is it open by someone else?)"))
       (setq res (strcat (vl-filename-base path) "|" nam))
     )
     (Dyl:QuickShapeRelease db)
     (princ (strcat "\nShape " nam " added to " (vl-filename-base path) ".dwg."))
    )
  )
  res
)

;;  Open the library path in AutoCAD (or switch to it when it is open), to edit its shapes:
(defun Dyl:QuickShapeOpen (path / db)
  (if (setq db (Dyl:QuickShapeDb path))
    (if (cadr db)
      (progn
        (Dyl:QuickShapeRelease db)
        (vl-catch-all-apply
          'vla-Activate
          (list (vla-Open (vla-get-Documents (vlax-get-acad-object)) path :vlax-false))
        )
      )
      (vl-catch-all-apply 'vla-Activate (list (car db)))
    )
  )
)

;;-------------------------=={ Draw }==------------------------;;

;;  T when the entity e is a reference of the temporary block of the shape:
(defun Dyl:QuickShapeRef-p (e)
  (and e
       (= "INSERT" (cdr (assoc 0 (entget e))))
       (= (strcase *qs:tmp*) (strcase (cdr (assoc 2 (entget e)))))
  )
)

;;  Insert the shape of the preset rec until Enter / Esc: each one is dragged into place (point,
;;  then rotation), exploded, and its objects are hatched with the material mat (see
;;  Remote>>Dyl:MaterialHatch: the closed curves are hatched, the other objects are linework):
(defun Dyl:QuickShape (rec mat / *error* doc lyr scl prev ref obj n)

  (defun *error* (msg)
    (if lyr (setvar "CLAYER" lyr))
    (Dyl:QuickShapePurge)
    (vla-EndUndoMark doc)
    (if (not (wcmatch (strcase msg) "*BREAK*,*CANCEL*,*QUIT*,*EXIT*"))
      (princ (strcat "\nError: " msg))
    )
    (princ)
  )
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (vla-StartUndoMark doc)
  (if (not (Dyl:QuickShapeDefine (nth 4 rec)))
    (alert (strcat "\nError: the shape " (nth 4 rec) " of the preset \"" (nth 2 rec) "\" was not found."
                   "\nPick another one in Dyl-QuickShape."
           )
    )
    (progn
      (setq scl (cond ((distof (nth 5 rec))) (1.0))
            n   0
            lyr (getvar "CLAYER")
      )
      (vl-catch-all-apply 'setvar (list "CLAYER" (Remote>>Dyl:LayerKeyLayer (nth 7 mat))))
      (princ (strcat "\nQuick Shape - " (nth 2 rec) " (Enter or Esc to stop):"))
      (while
        (progn
          (setq prev (entlast))
          (command "_.-INSERT" *qs:tmp* "_S" scl pause pause)
          ;;  Enter at the insertion point: cancel what is left of the command:
          (if (= 1 (logand 1 (getvar "CMDACTIVE"))) (command))
          (and (not (equal prev (setq ref (entlast)))) (Dyl:QuickShapeRef-p ref))
        )
        (setq obj (vlax-ename->vla-object ref))
        (Remote>>Dyl:MaterialHatch mat (mapcar 'vlax-vla-object->ename (vlax-invoke obj 'Explode)))
        (vla-Delete obj)
        (setq n (1+ n))
      )
      (setvar "CLAYER" lyr)
      (setq lyr nil)
      (Dyl:QuickShapePurge)
      (princ (strcat "\n" (itoa n) " shape(s) inserted."))
    )
  )
  (vla-EndUndoMark doc)
  (princ)
)

;;  Draw a preset: its material gives the hatch, the preset its border (put in the border
;;  columns of the material, always a border):
(defun Dyl:QuickShapeRun (rec / mat)
  (if (setq mat (Remote>>Dyl:MaterialGet (nth 3 rec)))
    (Dyl:QuickShape rec (Dyl:QuickShapeMat mat rec))
    (alert (strcat "\nError: the material of the preset \""
                   (nth 2 rec)
                   "\" no longer exists ("
                   (nth 3 rec)
                   ").\nPick another one in Dyl-QuickShape."
           )
    )
  )
)

;;-------------------------=={ Presets }==------------------------;;

;;  A preset is a list of strings (see Remote\Dyl-Presets.lsp for the preset engine):
;;  (id group name material shape scale outline-key border-settings...)
;;  id is the id of a default preset (e.g. "qs-Stud2x4", run by Pst-QuickShapeStud2x4), or
;;  a custom id (cu-...). material is the id of a material (see Remote\Dyl-Materials.lsp), shape
;;  a shape "<Library>|<Block>", scale the insertion scale (on top of the block units).
;;  The border of the preset (outline-key and its optional settings, index 6 to 16: the values
;;  of the border columns of a material, see *mt:bordertiles*). A shape always has its border
;;  (no No border). A preset of an older file, without it, gets the border of its material.
;;  The presets are saved to Res\QuickShape.csv (spec in Remote\Dyl-QuickShapePresets.lsp).

;;  The border columns of a preset start at 6 (see Remote>>Dyl:MaterialBorderTiles):
(setq *qs:border* 6)

;;  The material mat with the border of the preset r (always a border):
(defun Dyl:QuickShapeMat (mat r)
  (Remote>>Dyl:MaterialBorderPut mat r *qs:border* nil)
)

;;  Values of a row of the presets file (its 17 columns): scale "1" when it is not a number
;;  greater than 0, the border checked as that of a material (see Remote>>Dyl:MaterialFix).
;;  A row of a file without the border columns (no outline key) gets the border of its
;;  material. Its group as in the groups (any case; a group not listed there is kept, see
;;  Remote>>Dyl:GroupCase):
(defun Dyl:QuickShapeFix (row)
  (while (< (length row) 17) (setq row (append row (list ""))))
  (setq row (Remote>>Dyl:ListSubst row 1 (Remote>>Dyl:GroupCase (nth 1 row))))
  (if (not (and (distof (nth 5 row)) (< 0 (distof (nth 5 row)))))
    (setq row (Remote>>Dyl:ListSubst row 5 "1"))
  )
  (if (= "" (nth *qs:border* row))
    (setq row (Remote>>Dyl:MaterialBorderOf row (cond ((Remote>>Dyl:MaterialGet (nth 3 row))) (*mt:new*)) *qs:border* nil))
  )
  (Remote>>Dyl:MaterialBorderOf row (Remote>>Dyl:MaterialFix (Dyl:QuickShapeMat *mt:new* row)) *qs:border* nil)
)

;;  A default preset (id group name material shape scale): the border of its default
;;  material (Res\Materials.csv as shipped, see Remote>>Dyl:MaterialDefs):
(defun Dyl:QuickShapeDefault (row)
  (while (< (length row) 17) (setq row (append row (list ""))))
  (Dyl:QuickShapeFix
    (Remote>>Dyl:MaterialBorderOf row (cond ((assoc (nth 3 row) (Remote>>Dyl:MaterialDefs))) (*mt:new*)) *qs:border* nil)
  )
)

;;  Default presets, restored by the Reset Selected and Reset All buttons:
(setq *qs:defaults*
  (mapcar 'Dyl:QuickShapeDefault
  '(("qs-Stud2x4" "Section" "Stud 2x4" "mt-WoodFrame" "Shapes|Stud-2x4" "1")
    ("qs-Stud2x6" "Section" "Stud 2x6" "mt-WoodFrame" "Shapes|Stud-2x6" "1")
    ("qs-Stud2x8" "Section" "Stud 2x8" "mt-WoodFrame" "Shapes|Stud-2x8" "1")
    ("qs-BrickModular" "Section" "Brick Modular" "mt-Brick" "Shapes|Brick-Modular" "1")
    ("qs-CMU8" "Section" "CMU 8 in" "mt-CMU" "Shapes|CMU-8" "1")
    ("qs-HSS4x4" "Section" "HSS 4x4x1/4" "mt-Steel" "Shapes|HSS-4x4-0.25" "1")
   )
  )
)

;;  Read the presets file. Default presets missing from the file are added with their default values:
(defun Dyl:QuickShapeRead ()
  (Remote>>Dyl:PresetRead "QuickShape" *qs:defaults* 'Dyl:QuickShapeFix)
)

;;  Return the preset id, with the values edited by the user:
(defun Dyl:QuickShapeGet (id)
  (Remote>>Dyl:PresetGet "QuickShape" *qs:defaults* 'Dyl:QuickShapeFix id)
)

;;-------------------------=={ Dialog }==------------------------;;

;;  The preset dialog is made by Remote>>Dyl:PresetDialog (Remote\Dyl-Presets.lsp): its
;;  Parameters column has the Material popup (made by the engine, see (material . 3)), then
;;  the tiles below and the Border settings box (Remote>>Dyl:MaterialBorderDcl, without Has a
;;  border). The functions below run inside it and use its local variables pst:lst, pst:idx
;;  and pst:mats, and the local variables of Dyl:QuickShapeDialog: qs:shapes (shapes of the
;;  libraries), qs:refs (shapes of the Shape popup), mt:keys (layer keys of the border popup).

;;  Tiles of Quick Shape and index of their value in a preset, then those of the border:
(setq *qs:tiles* (append '(("scl" . 5) ("shp" . 4)) (Remote>>Dyl:MaterialBorderTiles *qs:border*)))

;;  Popup tiles -> list of their values (nil for the other tiles):
(defun Dyl:QuickShapeDlgItems (key)
  (cond
    ((= "shp" key) qs:refs)
    ((assoc key *mt:bordertiles*) (Remote>>Dyl:MaterialDlgItems key))
  )
)

;;  Error message of an invalid value, nil when it is valid:
(defun Dyl:QuickShapeDlgCheck (key val)
  (cond
    ((and (= "scl" key) (not (and (distof val) (< 0 (distof val))))) "The scale must be a number greater than 0.")
    ((and (= "shp" key) (not (member val qs:shapes))) "This shape is not in the libraries: pick another one.")
    ((assoc key *mt:bordertiles*) (Remote>>Dyl:MaterialDlgCheck key val))
  )
)

;;  The border of the preset r (see Remote>>Dyl:MaterialDlgBorderState; always a border):
(defun Dyl:QuickShapeDlgState (r)
  (Remote>>Dyl:MaterialDlgBorderState (Dyl:QuickShapeMat (cond ((assoc (nth 3 r) pst:mats)) (*mt:new*)) r))
)

;;  Fill the Shape popup (each time the dialog is shown: a shape may have been added): the shapes
;;  of the libraries, then the shapes used by a preset but not found (marked missing):
(defun Dyl:QuickShapeDlgInit ()
  (setq qs:shapes (Dyl:QuickShapeList)
        qs:refs   qs:shapes
  )
  (foreach r pst:lst
    (if (not (member (nth 4 r) qs:refs)) (setq qs:refs (append qs:refs (list (nth 4 r)))))
  )
  (start_list "shp")
  (foreach s qs:refs
    (add_list (if (member s qs:shapes)
                (strcat (vl-string-subst ": " "|" s))
                (strcat (vl-string-subst ": " "|" s) "   (missing shape)")
              )
    )
  )
  (end_list)
  ;;  Add shape / Open library: close the dialog with code 3 / 4, see Dyl:QuickShapeDlgStatus.
  ;;  Also when the shape of the preset is missing (only the shape is then invalid):
  (action_tile "sad" "(if (or (Remote>>Dyl:PresetDlgCommit) (not (member (nth 4 (nth pst:idx pst:lst)) qs:shapes))) (done_dialog 3))")
  (action_tile "sop" "(if (or (Remote>>Dyl:PresetDlgCommit) (not (member (nth 4 (nth pst:idx pst:lst)) qs:shapes))) (done_dialog 4))")
  ;;  The Border settings box (no Has a border):
  (Remote>>Dyl:MaterialDlgBorderInit (mapcar '(lambda (r) (nth *qs:border* r)) (append *qs:defaults* pst:lst)))
)

;;  Code 3 = Add shape from selection: the new shape goes to the library of the shape of the
;;  preset and is given to the preset, then the dialog is shown again. Code 4 = Open library:
;;  the presets are saved and the dialog closed, then the library of the shape is opened.
;;  The open button of the border layer key: the Layer Keys window (see
;;  Remote>>Dyl:MaterialDlgBorderStatus):
(defun Dyl:QuickShapeDlgStatus (sta r / ref)
  (cond
    ((= *mt:borderkeypick* sta) (Remote>>Dyl:MaterialDlgBorderStatus sta r *qs:border*) nil)
    ((= 3 sta)
     ;;  To every preset selected (see Remote>>Dyl:PresetDlgPut):
     (if (setq ref (Dyl:QuickShapeAdd (car (Dyl:QuickShapeSplit (nth 4 r)))))
       (Remote>>Dyl:PresetDlgPut 4 ref)
     )
     nil
    )
    ((= 4 sta)
     (Dyl:QuickShapeOpen (car (Dyl:QuickShapeSplit (nth 4 r))))
     'save
    )
  )
)

;;  Text put in the new alias box:
(defun Dyl:QuickShapeDlgPrefix (r) "QS-")

;;  Show the preset dialog. Draw and Save write the presets file and the aliases.
;;  Returns the preset to draw, or nil on Save / Cancel:
(defun Dyl:QuickShapeDialog (/ qs:shapes qs:refs mt:keys)
  (Remote>>Dyl:PresetDialog
    "QuickShape"
    (list (cons 'defs *qs:defaults*)
          (cons 'fix 'Dyl:QuickShapeFix)
          (cons 'tiles *qs:tiles*)
          ;;  The Group popup of the Materials window (the other groups used by a preset
          ;;  are added to it); the Material popup lists the materials of the group:
          '(groups . T)
          '(material . 3)
          '(upper "out" "blt")
          ;;  The shape, then the border of the preset:
          (cons 'params
                (append
                  '("      : popup_list { key = \"shp\"; label = \"Shape:\"; edit_width = 32; }"
                    "      : row { alignment = right; fixed_width = true;"
                    "        : button { key = \"sad\"; label = \"Add shape from selection...\"; }"
                    "        : button { key = \"sop\"; label = \"Open library\"; }"
                    "      }"
                    "      : edit_box { key = \"scl\"; label = \"Scale:\"; edit_width = 12; }"
                    "      spacer;"
                   )
                  (Remote>>Dyl:MaterialBorderDcl)
                )
          )
          (cons 'new (Dyl:QuickShapeDefault '("" "" "New shape" "mt-Brick" "Shapes|Stud-2x4" "1")))
          '(items . Dyl:QuickShapeDlgItems)
          '(check . Dyl:QuickShapeDlgCheck)
          '(init . Dyl:QuickShapeDlgInit)
          '(state . Dyl:QuickShapeDlgState)
          '(status . Dyl:QuickShapeDlgStatus)
          '(prefix . Dyl:QuickShapeDlgPrefix)
          ;;  A list as tall as the Parameters column (the shape and the Border settings box):
          '(height . 20)
    )
  )
)

;;-------------------------=={ Commands }==------------------------;;

;; Quick Shape
;; Opens a dialog to edit, create and draw the quick shape presets.

(defun c:Dyl-QuickShape (/ rec)
  (if (setq rec (Dyl:QuickShapeDialog)) (Dyl:QuickShapeRun rec))
  (princ)
)

;; Quick Shape Stud 2x4
;; Inserts 2x4 studs in section, filled with the wood frame hatch.

(defun c:Pst-QuickShapeStud2x4 () (Dyl:QuickShapeRun (Dyl:QuickShapeGet "qs-Stud2x4")))

;; Quick Shape Stud 2x6
;; Inserts 2x6 studs in section, filled with the wood frame hatch.

(defun c:Pst-QuickShapeStud2x6 () (Dyl:QuickShapeRun (Dyl:QuickShapeGet "qs-Stud2x6")))

;; Quick Shape Stud 2x8
;; Inserts 2x8 studs in section, filled with the wood frame hatch.

(defun c:Pst-QuickShapeStud2x8 () (Dyl:QuickShapeRun (Dyl:QuickShapeGet "qs-Stud2x8")))

;; Quick Shape Brick Modular
;; Inserts modular bricks in section, filled with the brick hatch.

(defun c:Pst-QuickShapeBrickModular () (Dyl:QuickShapeRun (Dyl:QuickShapeGet "qs-BrickModular")))

;; Quick Shape CMU 8 in
;; Inserts 8 in concrete masonry units in plan section (with their cores), filled with the CMU hatch.

(defun c:Pst-QuickShapeCMU8 () (Dyl:QuickShapeRun (Dyl:QuickShapeGet "qs-CMU8")))

;; Quick Shape HSS 4x4
;; Inserts 4x4x1/4 steel tubes in section, filled with the steel hatch.

(defun c:Pst-QuickShapeHSS4x4 () (Dyl:QuickShapeRun (Dyl:QuickShapeGet "qs-HSS4x4")))
