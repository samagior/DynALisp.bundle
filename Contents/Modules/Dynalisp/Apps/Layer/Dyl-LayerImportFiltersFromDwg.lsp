;; LayerImportFiltersFromDwg - Imports layer property filters from another drawing
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

;;; ==========================================================================
;;; ImportLayerFilters.lsp
;;;
;;; Imports layer property filters from a selected source drawing into the
;;; current drawing.
;;;
;;; Scope:
;;;   - Layer property filters (AcLyLayerFilter), including their nested
;;;     property filters (hierarchy is preserved).
;;;   - Layer group filters (AcLyLayerGroup) are NOT imported: they reference
;;;     layers by handle, which only make sense in the source drawing. Anything
;;;     nested under a group filter is therefore skipped as well.
;;;   - Layers themselves are NOT imported, only the filter definitions.
;;;   - The source drawing is never modified.
;;;
;;; Commands:
;;;   LFIMP              - import filters from a source drawing
;;;   IMPORTLAYERFILTER  - alias of LFIMP
;;;   LFLIST             - list the filter tree of the current drawing
;;;
;;; Storage (undocumented by Autodesk, observed):
;;;   Layer table > extension dictionary > ACLYDICTIONARY
;;;     XRECORD: (1 . "AcLyLayerFilter") (90 . 1) (300 . name) (301 . expr)
;;;   Nested filters: extension dictionary of the parent XRECORD
;;;     > ACLYDICTIONARY > XRECORD ...
;;;   Data is copied as-is (minus pointers), so any extra group codes used
;;;   by a given AutoCAD version are preserved.
;;;
;;; Duplicate names (checked against the whole current filter tree):
;;;   Overwrite - the existing filter (and its nested filters) is deleted,
;;;               then replaced by the source filter.
;;;   Skip      - the source filter (and its nested filters) is not imported.
;;;   Rename    - the source filter is imported with a _1, _2, ... suffix.
;;;
;;; Notes:
;;;   The source is read through ObjectDBX, or directly if the drawing is
;;;   already open in the session.
;;;   The Layer Properties Manager is closed before writing: if left open,
;;;   it could rewrite the filter tree from its in-memory copy and wipe out
;;;   the imported filters.
;;;   The operation is recorded as a single UNDO group.
;;; ==========================================================================

(vl-load-com)

;;; --------------------------------------------------------------------------
;;; lfi:item
;;;   Returns item KEY of a VLA collection or dictionary, or nil if missing.
;;; --------------------------------------------------------------------------
(defun lfi:item (coll key / r)
  (setq r (vl-catch-all-apply 'vla-Item (list coll key)))
  (if (vl-catch-all-error-p r) nil r)
)

;;; --------------------------------------------------------------------------
;;; lfi:get-filter-dict
;;;   Returns the ACLYDICTIONARY attached to OBJ (layer table or filter
;;;   XRECORD) through its extension dictionary.
;;;   Creates nothing (safe on the source drawing). Returns nil if missing.
;;; --------------------------------------------------------------------------
(defun lfi:get-filter-dict (obj / r)
  (setq r (vl-catch-all-apply
            '(lambda ()
               (if (= (vla-get-HasExtensionDictionary obj) :vlax-true)
                 (lfi:item (vla-GetExtensionDictionary obj) "ACLYDICTIONARY")
               )
             )
          )
  )
  (if (vl-catch-all-error-p r) nil r)
)

;;; --------------------------------------------------------------------------
;;; lfi:ensure-filter-dict
;;;   Same as lfi:get-filter-dict, but creates the extension dictionary and
;;;   ACLYDICTIONARY when needed. Current drawing only.
;;; --------------------------------------------------------------------------
(defun lfi:ensure-filter-dict (obj / xd)
  (setq xd (vla-GetExtensionDictionary obj))
  (cond
    ((lfi:item xd "ACLYDICTIONARY"))
    ((vla-AddObject xd "ACLYDICTIONARY" "AcDbDictionary"))
  )
)

;;; --------------------------------------------------------------------------
;;; lfi:xrec-data
;;;   Reads XRECORD data through ActiveX (also works on an ObjectDBX
;;;   document). Returns a list of DXF pairs, or nil.
;;; --------------------------------------------------------------------------
(defun lfi:xrec-data (xr / typ val res)
  (setq res
    (vl-catch-all-apply
      '(lambda ()
         (vla-GetXRecordData xr 'typ 'val)
         (if (= (type typ) 'VARIANT) (setq typ (vlax-variant-value typ)))
         (if (= (type val) 'VARIANT) (setq val (vlax-variant-value val)))
         (mapcar
           '(lambda (k v / x)
              (setq x (if (= (type v) 'VARIANT) (vlax-variant-value v) v))
              (if (= (type x) 'SAFEARRAY) (setq x (vlax-safearray->list x)))
              (cons k x)
            )
           (vlax-safearray->list typ)
           (vlax-safearray->list val)
         )
       )
    )
  )
  (if (vl-catch-all-error-p res) nil res)
)

;;; --------------------------------------------------------------------------
;;; lfi:clean-data
;;;   Removes header codes and pointers (handles / object ids) from DATA,
;;;   since they are meaningless in another drawing.
;;; --------------------------------------------------------------------------
(defun lfi:clean-data (data)
  (vl-remove-if
    '(lambda (p / k)
       (setq k (car p))
       (or (not (numberp k))
           (< k 1)
           (member k '(5 100 102 105))
           (<= 320 k 369)
           (<= 390 k 399)
           (<= 480 k 481)
       )
     )
    data
  )
)

;;; --------------------------------------------------------------------------
;;; lfi:read-tree
;;;   Recursively reads an ACLYDICTIONARY.
;;;   Returns a list of nodes: (class name data children)
;;;     class : "AcLyLayerFilter", "AcLyLayerGroup", ...
;;;     data  : cleaned DXF pairs, ready for entmakex
;;; --------------------------------------------------------------------------
(defun lfi:read-tree (dict / lst data cls)
  (if dict
    (vlax-for xr dict
      (if (and (= (vla-get-ObjectName xr) "AcDbXrecord")
               (setq data (lfi:xrec-data xr))
               (= (type (setq cls (cdr (assoc 1 data)))) 'STR))
        (setq lst (cons (list cls
                              (cdr (assoc 300 data))
                              (lfi:clean-data data)
                              (lfi:read-tree (lfi:get-filter-dict xr)))
                        lst))
      )
    )
  )
  (reverse lst)
)

;;; --------------------------------------------------------------------------
;;; lfi:prop-p
;;;   T if NODE is a named layer property filter.
;;; --------------------------------------------------------------------------
(defun lfi:prop-p (node)
  (and (= (type (car node)) 'STR)
       (= (strcase (car node)) "ACLYLAYERFILTER")
       (= (type (cadr node)) 'STR))
)

;;; --------------------------------------------------------------------------
;;; lfi:prop-names
;;;   Names of the importable property filters in NODES: each property
;;;   filter and, recursively, its nested property filters.
;;; --------------------------------------------------------------------------
(defun lfi:prop-names (nodes / res)
  (foreach n nodes
    (if (lfi:prop-p n)
      (setq res (append res (list (cadr n)) (lfi:prop-names (cadddr n))))
    )
  )
  res
)

;;; --------------------------------------------------------------------------
;;; lfi:print-tree
;;;   Prints a node tree with indentation.
;;; --------------------------------------------------------------------------
(defun lfi:print-tree (nodes indent)
  (foreach n nodes
    (princ (strcat "\n" indent
                   (if (= (type (cadr n)) 'STR) (cadr n) "<unnamed>")
                   (cond ((lfi:prop-p n) "")
                         ((= (strcase (car n)) "ACLYLAYERGROUP") "   [group filter]")
                         (T (strcat "   [" (car n) "]")))))
    (lfi:print-tree (cadddr n) (strcat indent "   "))
  )
)

;;; --------------------------------------------------------------------------
;;; lfi:dest-index
;;;   Index of every filter (all types, all levels) in an ACLYDICTIONARY:
;;;   list of (UPPERCASE-NAME . vla-xrecord).
;;; --------------------------------------------------------------------------
(defun lfi:dest-index (dict / res nm)
  (if dict
    (vlax-for xr dict
      (if (= (vla-get-ObjectName xr) "AcDbXrecord")
        (progn
          (if (= (type (setq nm (cdr (assoc 300 (lfi:xrec-data xr))))) 'STR)
            (setq res (cons (cons (strcase nm) xr) res))
          )
          (setq res (append (lfi:dest-index (lfi:get-filter-dict xr)) res))
        )
      )
    )
  )
  res
)

;;; --------------------------------------------------------------------------
;;; lfi:rebuild-dest
;;;   Rebuilds the index and name list of the current drawing.
;;; --------------------------------------------------------------------------
(defun lfi:rebuild-dest (layers)
  (setq lfi:*index* (lfi:dest-index (lfi:get-filter-dict layers))
        lfi:*names* (mapcar 'car lfi:*index*))
)

;;; --------------------------------------------------------------------------
;;; lfi:delete-node
;;;   Deletes a filter XRECORD and, recursively, its nested filters.
;;; --------------------------------------------------------------------------
(defun lfi:delete-node (xr / sub kids)
  (if (setq sub (lfi:get-filter-dict xr))
    (progn
      (vlax-for c sub (setq kids (cons c kids)))
      (foreach c kids (lfi:delete-node c))
      (vl-catch-all-apply 'vla-Delete (list sub))
    )
  )
  (vl-catch-all-apply 'vla-Delete (list xr))
)

;;; --------------------------------------------------------------------------
;;; lfi:unique-key
;;;   Generates a free dictionary key (*A1, *A2, ...) in DICT.
;;; --------------------------------------------------------------------------
(defun lfi:unique-key (dict / keys n key)
  (setq keys (mapcar '(lambda (p) (strcase (cdr p)))
                     (vl-remove-if-not '(lambda (p) (= (car p) 3))
                                       (entget (vlax-vla-object->ename dict))))
        n    (1+ (length keys)))
  (while (member (setq key (strcat "*A" (itoa n))) keys)
    (setq n (1+ n))
  )
  key
)

;;; --------------------------------------------------------------------------
;;; lfi:unique-name
;;;   Returns NAME with a suffix (_1, _2, ...) so it is unused in the drawing.
;;; --------------------------------------------------------------------------
(defun lfi:unique-name (name / n new)
  (setq n 1)
  (while (member (strcase (setq new (strcat name "_" (itoa n)))) lfi:*names*)
    (setq n (1+ n))
  )
  new
)

;;; --------------------------------------------------------------------------
;;; lfi:make-xrec
;;;   Creates a filter XRECORD from DATA and adds it to DICT.
;;;   Returns the new VLA object, or nil.
;;; --------------------------------------------------------------------------
(defun lfi:make-xrec (dict data / key en)
  (setq key (lfi:unique-key dict))
  (if (setq en (entmakex (append '((0 . "XRECORD") (100 . "AcDbXrecord") (280 . 1))
                                 data)))
    (if (dictadd (vlax-vla-object->ename dict) key en)
      (vlax-ename->vla-object en)
    )
  )
)

;;; --------------------------------------------------------------------------
;;; lfi:import-node
;;;   Imports a node (and its children) under PARENT: the current drawing's
;;;   layer table (root) or a filter XRECORD created by this import.
;;;   Uses the lfi:* variables local to C:LFIMP (dynamic scope).
;;; --------------------------------------------------------------------------
(defun lfi:import-node (node parent / name data kids newname dict xr)
  (setq name (cadr node)
        data (caddr node)
        kids (cadddr node))
  (cond
    ;; Group filter or other type: not imported, descendants included
    ((not (lfi:prop-p node))
     (setq lfi:*n-group* (1+ lfi:*n-group*))
    )
    (T
     (setq newname name)
     (if (member (strcase name) lfi:*names*)
       (cond
         ((= lfi:*mode* "Skip")
          (setq newname      nil
                lfi:*n-skip* (1+ lfi:*n-skip*))
         )
         ;; Overwrite, unless the duplicate was created by this import
         ((and (= lfi:*mode* "Overwrite")
               (not (member (strcase name) lfi:*created*)))
          (foreach p lfi:*index*
            (if (= (car p) (strcase name)) (lfi:delete-node (cdr p)))
          )
          (lfi:rebuild-dest lfi:*layers*)
          (setq lfi:*n-rep* (1+ lfi:*n-rep*))
         )
         (T
          (setq newname     (lfi:unique-name name)
                lfi:*n-ren* (1+ lfi:*n-ren*))
         )
       )
     )
     (if newname
       (progn
         (setq data (subst (cons 300 newname) (assoc 300 data) data))
         (if (and (setq dict (lfi:ensure-filter-dict parent))
                  (setq xr (lfi:make-xrec dict data)))
           (progn
             (setq lfi:*names*   (cons (strcase newname) lfi:*names*)
                   lfi:*created* (cons (strcase newname) lfi:*created*)
                   lfi:*n-ok*    (1+ lfi:*n-ok*))
             (foreach k kids (lfi:import-node k xr))
           )
           (setq lfi:*n-fail* (1+ lfi:*n-fail*))
         )
       )
     )
    )
  )
)

;;; --------------------------------------------------------------------------
;;; lfi:has-legacy
;;;   T if the layer table holds pre-2005 filters (ACAD_LAYERFILTERS).
;;;   Creates nothing.
;;; --------------------------------------------------------------------------
(defun lfi:has-legacy (layers / r)
  (setq r (vl-catch-all-apply
            '(lambda (/ d)
               (and (= (vla-get-HasExtensionDictionary layers) :vlax-true)
                    (setq d (lfi:item (vla-GetExtensionDictionary layers)
                                      "ACAD_LAYERFILTERS"))
                    (> (vla-get-Count d) 0))
             )
          )
  )
  (and (not (vl-catch-all-error-p r)) r)
)

;;; --------------------------------------------------------------------------
;;; lfi:open-source
;;;   Returns (document release-p) for file PATH:
;;;     - the session document if already open (must not be released);
;;;     - otherwise an ObjectDBX document (must be released after use).
;;;   Returns nil on failure (message printed).
;;; --------------------------------------------------------------------------
(defun lfi:open-source (path / acad doc dbx ver r)
  (setq acad (vlax-get-acad-object))
  (vlax-for d (vla-get-Documents acad)
    (setq r (vl-catch-all-apply 'vla-get-FullName (list d)))
    (if (and (not doc) (= (type r) 'STR) (= (strcase r) (strcase path)))
      (setq doc d)
    )
  )
  (cond
    (doc (list doc nil))
    ((progn
       (setq ver (atoi (getvar "ACADVER"))
             dbx (vl-catch-all-apply
                   'vla-GetInterfaceObject
                   (list acad
                         (if (< ver 16)
                           "ObjectDBX.AxDbDocument"
                           (strcat "ObjectDBX.AxDbDocument." (itoa ver))))))
       (vl-catch-all-error-p dbx)
     )
     (princ "\nLFIMP: ObjectDBX interface not available.")
     nil
    )
    ((vl-catch-all-error-p (vl-catch-all-apply 'vla-Open (list dbx path)))
     (vl-catch-all-apply 'vlax-release-object (list dbx))
     (princ "\nLFIMP: unable to open the source drawing (inaccessible, corrupt or newer version).")
     nil
    )
    (T (list dbx T))
  )
)

;; Import Layer Filters
;; Imports the layer filters of another drawing into the current drawing.

(defun c:Dyl-LayerImportFiltersFromDwg (/ *error* doc cur path res srcdoc release srclay nodes legacy
                  pat sel conflicts i undo oldcmd lpm
                  lfi:*layers* lfi:*index* lfi:*names* lfi:*created* lfi:*mode*
                  lfi:*n-ok* lfi:*n-rep* lfi:*n-ren* lfi:*n-skip*
                  lfi:*n-group* lfi:*n-fail*)

  (defun *error* (msg)
    (if (and release srcdoc)
      (vl-catch-all-apply 'vlax-release-object (list srcdoc))
    )
    (if undo (vla-EndUndoMark doc))
    (if oldcmd (setvar "CMDECHO" oldcmd))
    (if (and msg (not (wcmatch (strcase msg) "*BREAK*,*CANCEL*,*QUIT*")))
      (princ (strcat "\nError: " msg))
    )
    (princ)
  )

  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object))
        cur (strcase (strcat (getvar "DWGPREFIX") (getvar "DWGNAME"))))

  (cond
    ;; 1. Select the source drawing
    ((not (setq path (getfiled "Source drawing for layer filters"
                               (getvar "DWGPREFIX") "dwg;dwt;dws" 16)))
     (princ "\nLFIMP: cancelled.")
    )
    ((= (strcase path) cur)
     (princ "\nLFIMP: the source drawing is the current drawing.")
    )

    ;; 2. Open the source (message already printed on failure)
    ((not (setq res (lfi:open-source path))))

    ;; 3. Read the filter tree, then release the source right away
    ((progn
       (setq srcdoc  (car res)
             release (cadr res)
             srclay  (vla-get-Layers srcdoc)
             nodes   (lfi:read-tree (lfi:get-filter-dict srclay))
             legacy  (and (not nodes) (lfi:has-legacy srclay))
             srclay  nil)
       (if release (vl-catch-all-apply 'vlax-release-object (list srcdoc)))
       (setq srcdoc nil)
       (not (lfi:prop-names nodes))
     )
     (if legacy
       (princ (strcat "\nLFIMP: the source drawing only contains pre-2005 layer filters."
                      "\n       Open and save it in AutoCAD, then run LFIMP again."))
       (princ "\nLFIMP: no layer property filters found in the source drawing.")
     )
    )

    ;; 4. Select the root filters to import
    ((progn
       (princ (strcat "\nFilters in source drawing (" (vl-filename-base path) "):"))
       (lfi:print-tree nodes "  ")
       (princ "\n(Group filters are not imported.)")
       (setq pat (getstring T "\nFilters to import (name or wildcard, comma-separated) <*>: "))
       (if (= pat "") (setq pat "*"))
       (setq sel (vl-remove-if-not
                   '(lambda (n)
                      (and (= (type (cadr n)) 'STR)
                           (wcmatch (strcase (cadr n)) (strcase pat))))
                   nodes))
       (not (lfi:prop-names sel))
     )
     (princ "\nLFIMP: no layer property filter matches.")
    )

    ;; 5. Duplicates, write and report
    (T
     (setq lfi:*layers* (vla-get-Layers doc))
     (lfi:rebuild-dest lfi:*layers*)
     (setq lfi:*mode* "Skip"
           conflicts  (vl-remove-if-not
                        '(lambda (nm) (member (strcase nm) lfi:*names*))
                        (lfi:prop-names sel)))

     (if conflicts
       (progn
         (princ (strcat "\n" (itoa (length conflicts))
                        " filter name(s) already exist in the current drawing:"))
         (setq i 0)
         (foreach nm conflicts
           (if (< i 15) (princ (strcat "\n  " nm)))
           (setq i (1+ i))
         )
         (if (> i 15) (princ (strcat "\n  ... and " (itoa (- i 15)) " more")))
         (initget "Overwrite Skip Rename")
         (setq lfi:*mode*
           (cond
             ((getkword "\nDuplicate names [Overwrite/Skip/Rename] <Skip>: "))
             ("Skip")
           )
         )
       )
     )

     ;; Close the Layer Properties Manager if it is open
     (setq oldcmd (getvar "CMDECHO"))
     (setvar "CMDECHO" 0)
     (if (and (setq lpm (getvar "LAYERMANAGERSTATE")) (/= lpm 0))
       (progn
         (command "_.LAYERCLOSE")
         (princ "\nLayer Properties Manager closed.")
       )
     )

     (setq lfi:*created* nil
           lfi:*n-ok*    0
           lfi:*n-rep*   0
           lfi:*n-ren*   0
           lfi:*n-skip*  0
           lfi:*n-group* 0
           lfi:*n-fail*  0)

     (vla-StartUndoMark doc)
     (setq undo T)
     (foreach n sel (lfi:import-node n lfi:*layers*))
     (vla-EndUndoMark doc)
     (setq undo nil)

     (setvar "CMDECHO" oldcmd)
     (setq oldcmd nil)

     ;; Report
     (princ (strcat "\nLFIMP: " (itoa lfi:*n-ok*)
                    " layer property filter(s) imported."))
     (if (> lfi:*n-rep* 0)
       (princ (strcat "\n       " (itoa lfi:*n-rep*)
                      " existing filter(s) overwritten.")))
     (if (> lfi:*n-ren* 0)
       (princ (strcat "\n       " (itoa lfi:*n-ren*)
                      " filter(s) renamed (_n suffix).")))
     (if (> lfi:*n-skip* 0)
       (princ (strcat "\n       " (itoa lfi:*n-skip*)
                      " filter(s) skipped (name already in use).")))
     (if (> lfi:*n-group* 0)
       (princ (strcat "\n       " (itoa lfi:*n-group*)
                      " group (or other type) filter(s) not imported.")))
     (if (> lfi:*n-fail* 0)
       (princ (strcat "\n       " (itoa lfi:*n-fail*)
                      " filter(s) could not be created.")))
     (if (> lfi:*n-ok* 0)
       (princ "\n       Open the Layer Properties Manager to see them."))
    )
  )
  (princ)
)

;; List Layer Filters
;; Lists the layer filter tree of the current drawing at the command line.

(defun c:Pst-ListLayerFilters (/ nodes)
  (setq nodes (lfi:read-tree
                (lfi:get-filter-dict
                  (vla-get-Layers (vla-get-ActiveDocument (vlax-get-acad-object))))))
  (if nodes
    (progn
      (princ "\nLayer filters in the current drawing:")
      (lfi:print-tree nodes "  ")
    )
    (princ "\nNo layer filters in the current drawing.")
  )
  (princ)
)

(princ "\nImportLayerFilters.lsp loaded. Type Dyl-LayerImportFiltersFromDwg (LFIMP) to import, LFLIST to list.")
(princ)
