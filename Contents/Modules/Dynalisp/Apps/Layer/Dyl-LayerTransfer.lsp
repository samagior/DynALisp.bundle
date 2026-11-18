;; LayerTransfer - Change selected object(s) from a selected layer group to a new one (layer must already be in file)
;; Copyright (C) 2023  Samuel Martineau
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

;; returns T if layer name lay is a candidate for transfer (same rule as the ssget layer filter)
;; Field: the layers with an NCS name (Dyl-LayTransfer-Ncs)
(defun Dyl-LayTransfer-Match (lay)
  (if (= "Field" *typ)
    (and (Dyl-LayTransfer-Ncs lay) T)
    (wcmatch (strcase lay)
             (strcase
               (if (= *typ "Phase")
                 "*-*"
                 (strcat "*" *pat "*")
               )
             )
    )
  )
)

;;-------------------------=={ NCS names }==------------------------;;

;; the parts of str divided by "-" ("A-Wall-Full-E" -> ("A" "Wall" "Full" "E"))
(defun Dyl-LayTransfer-Split (str / pos lst)
  (while (setq pos (vl-string-search "-" str))
    (setq lst (cons (substr str 1 pos) lst)
          str (substr str (+ pos 2))
    )
  )
  (reverse (cons str lst))
)

;; the fields of an NCS layer name (United States National CAD Standard):
;;   (discipline major (minor ...) status), status nil when the name has none
;;   "A-Wall-Full-E" -> ("A" "Wall" ("Full") "E"), "AD-Door" -> ("AD" "Door" nil nil)
;; discipline designator: 1 or 2 letters, major group: 4 characters, minor groups: 4
;; characters each (none or more), status: 1 character (optional). nil for any other name
;; and for the layers of the xrefs. Same rule as NcsName of the ribbon drop-downs
;; (Installer\Ribbon\Plugin\TransferCombos.cs).
(defun Dyl-LayTransfer-Ncs (lay / lst st)
  (if (not (wcmatch lay "*|*"))
    (progn
      (setq lst (Dyl-LayTransfer-Split lay))
      (if (and (< 2 (length lst)) (= 1 (strlen (last lst))))
        (setq st  (last lst)
              lst (reverse (cdr (reverse lst)))
        )
      )
      (if (and (<= 2 (length lst))
               (wcmatch (car lst) "@,@@")
               (vl-every '(lambda (x) (= 4 (strlen x))) (cdr lst))
          )
        (list (car lst) (cadr lst) (cddr lst) st)
      )
    )
  )
)

;; T when the value val of a field is the From value src (nil: any value)
(defun Dyl-LayTransfer-Is (val src)
  (or (null src) (= (strcase val) (strcase src)))
)

;; the target of lay for the Field transfer: the field *lt:fld ("Discipline", "Major",
;; "Minor" or "Status") of value *lt:src (nil: any, "": none) given the value *lt:dst ("":
;; none), the other fields kept. Minor group: the one of value *lt:src, the first one for
;; any (added after the major group when the name has none). lay itself when it does not
;; match:
(defun Dyl-LayTransfer-FieldTarget (lay / n d mj mn st i)
  (if (setq n (Dyl-LayTransfer-Ncs lay))
    (progn
      (setq d  (nth 0 n)
            mj (nth 1 n)
            mn (nth 2 n)
            st (cond ((nth 3 n)) (""))
      )
      (cond
        ((= "Discipline" *lt:fld) (if (Dyl-LayTransfer-Is d *lt:src) (setq d *lt:dst)))
        ((= "Major" *lt:fld) (if (Dyl-LayTransfer-Is mj *lt:src) (setq mj *lt:dst)))
        ((= "Status" *lt:fld) (if (Dyl-LayTransfer-Is st *lt:src) (setq st *lt:dst)))
        ((= "Minor" *lt:fld)
         (cond
           ((null *lt:src) (setq mn (cons *lt:dst (cdr mn))))
           ((= "" *lt:src) (if (not mn) (setq mn (list *lt:dst))))
           ((setq i (vl-position (strcase *lt:src) (mapcar 'strcase mn)))
            (setq mn (Remote>>Dyl:ListSubst mn i *lt:dst))
           )
         )
        )
      )
      (strcat d
              "-"
              mj
              (apply 'strcat (mapcar '(lambda (x) (if (/= "" x) (strcat "-" x) "")) mn))
              (if (/= "" st) (strcat "-" st) "")
      )
    )
    lay
  )
)

;; returns the target layer name for source layer name lay:
;;   - Phase + ends with -???? and not already *pat → append *new
;;   - all other cases                              → substitute *pat with *new
;;   - Field: the field *lt:fld given its new value (Dyl-LayTransfer-FieldTarget)
(defun Dyl-LayTransfer-Target (lay / len)
  (cond
   ((= "Field" *typ) (Dyl-LayTransfer-FieldTarget lay))
   ((and (= "Phase" *typ) 
         (wcmatch lay "*-????")
         (not (wcmatch lay (strcat "*" *pat)))
    )
    (strcat lay *new)
   )
   (T
      (cond
        ((= "Designator" *typ) (setq len 0))
        ((= "Major" *typ) (setq len 2))
        ((= "Minor" *typ) (setq len 7))
        ((= "Phase" *typ) (setq len (- (strlen lay) 2)))
        (T (setq len 0))
      )
      (vl-string-subst *new *pat lay len)
   )
  )
)

;; returns the layer name lay without its new phase suffix *new: the layer of its layer key
;;   ex. -E -> -D : "G-Detl-Exst-D" -> "G-Detl-Exst"; unphased (*new ""): lay itself
(defun Dyl-LayTransfer-Base (lay)
  (if (and (/= "" *new) (wcmatch (strcase lay) (strcat "*" (strcase *new))))
    (substr lay 1 (- (strlen lay) (strlen *new)))
    lay
  )
)

;; the phase code of the transfer ("-D" -> "D"), nil to unphased
(defun Dyl-LayTransfer-Code ()
  (if (wcmatch *new "-?*") (substr *new 2))
)

;; the target layer tgt of a phase transfer as its layer key says it should be (see
;; Remote>>Dyl:LayerKeyExpected): the key with the name tgt and the color of the phase (the
;; color of the key when it keeps it in every phase); nil when tgt is not the layer of a key
(defun Dyl-LayTransfer-Key (tgt)
  (if (and (or (= "Phase" *typ) (and (= "Field" *typ) (= "Status" *lt:fld))) Remote>>Dyl:LayerKeyExpected)
    (Remote>>Dyl:LayerKeyExpected tgt (Dyl-LayTransfer-Base tgt) (Dyl-LayTransfer-Code))
  )
)

;; returns T if layer name lay matches and its target is a different layer
(defun Dyl-LayTransfer-Changes (lay) 
  (and (Dyl-LayTransfer-Match lay) 
       (/= (strcase lay) (strcase (Dyl-LayTransfer-Target lay)))
  )
)

;; returns the name of the converted copy of block definition nam:
;;   an existing *pat suffix is replaced by *new, otherwise *new is appended ("-" added if missing)
;;   ex. E-N : "2X6" -> "2X6-N", "2X6-E" -> "2X6-N"
;;   ex. N-U : "2X6-N" -> "2X6", "2X6" -> "2X6" (unphased: *new is "", nothing appended)
(defun Dyl-LayTransfer-BlockName (nam / old new)
  (setq old (if (= "-" (substr *pat 1 1)) *pat (strcat "-" *pat))
        new (if (or (= "" *new) (= "-" (substr *new 1 1))) *new (strcat "-" *new))
  )
  ;; Field transfer of the status from any phase: the phase suffix of the name, whichever it is
  (if (and (= "Field" *typ) (= "Status" *lt:fld) (null *lt:src) Remote>>Dyl:PhaseOf
           (Remote>>Dyl:PhaseOf nam (Remote>>Dyl:PhaseList))
      )
    (setq old (substr nam (1- (strlen nam))))
  )
(if (wcmatch (strcase nam) (strcat "*" (strcase old))) 
    (strcat (substr nam 1 (- (strlen nam) (strlen old))) new)
    (strcat nam new)
  )
)

;; returns T if obj has to be transferred: its layer, its attributes or its block definition
;; layers to transfer are added to *lst
(defun Dyl-LayTransfer-Check (obj / flg) 
  (if (Dyl-LayTransfer-Changes (vla-get-layer obj)) 
    (progn 
      (if (not (member (vla-get-layer obj) *lst)) 
        (setq *lst (cons (vla-get-layer obj) *lst))
      )
      (setq flg T)
    )
  )
  (if (wcmatch (vla-get-objectname obj) "AcDbBlockReference,AcDbMInsertBlock") 
    (progn 
      (if (= :vlax-true (vla-get-hasattributes obj)) 
        (foreach att (vlax-invoke obj 'GetAttributes) 
          (if (Dyl-LayTransfer-Check att) (setq flg T))
        )
      )
      (if (Dyl-LayTransfer-Scan (vla-get-effectivename obj)) (setq flg T))
    )
  )
  flg
)

;; returns T if block definition nam holds entities to transfer (nested blocks included)
;; each definition is scanned once (*blks cache), xrefs and layouts are skipped
(defun Dyl-LayTransfer-Scan (nam / key blk flg) 
  (setq key (strcase nam))
  (if (assoc key *blks) 
    (cdr (assoc key *blks))
    (progn 
      (setq blk (vla-item *blocks nam))
      (if 
        (and (= :vlax-false (vla-get-isxref blk)) 
             (= :vlax-false (vla-get-islayout blk))
        )
        (vlax-for sub blk 
          (if (Dyl-LayTransfer-Check sub) (setq flg T))
        )
      )
      (setq *blks (cons (cons key flg) *blks))
      flg
    )
  )
)

;; copies block definition nam under the name new and returns the copy
;; the definition goes through an ObjectDBX document to be renamed (keeps dynamic block data)
(defun Dyl-LayTransfer-CopyDef (nam new / dbx) 
  (setq dbx (vla-getinterfaceobject 
              (vlax-get-acad-object)
              (strcat "ObjectDBX.AxDbDocument." (itoa (atoi (getvar "ACADVER"))))
            )
  )
  (vlax-invoke *doc 'CopyObjects (list (vla-item *blocks nam)) (vla-get-blocks dbx))
  (vla-put-name (vla-item (vla-get-blocks dbx) nam) new)
  (vlax-invoke dbx 'CopyObjects (list (vla-item (vla-get-blocks dbx) new)) *blocks)
  (vlax-release-object dbx)
  (vla-item *blocks new)
)

;; returns the name of the converted definition of block nam, created on first call (*map cache):
;;   the definition is copied under its new name and the copy's content is transferred
;;   a definition already named that way (previous run) is reused as is
;;   anonymous definitions (*U###) can't be named, they are transferred in place
;;   so are definitions whose new name is their own (unphased transfer of a name without suffix)
(defun Dyl-LayTransfer-Convert (nam / key new blk) 
  (setq key (strcase nam))
  (cond 
    ((cdr (assoc key *map)))
    (T
     (cond 
       ((or (wcmatch nam "`**") 
            (= key (strcase (setq new (Dyl-LayTransfer-BlockName nam))))
        )
        (setq new nam
              blk (vla-item *blocks nam)
        )
       )
       ((tblsearch "BLOCK" new))
       (T (setq blk (Dyl-LayTransfer-CopyDef nam new)))
     )
     (setq *map (cons (cons key new) *map))
     (if blk 
       (vlax-for sub blk 
         (Dyl-LayTransfer-Apply sub)
       )
     )
     new
    )
  )
)

;; points block reference ref to definition nam
;; dynamic blocks: the dynamic property values are restored on the new definition
(defun Dyl-LayTransfer-Swap (ref nam / dyn val) 
  (if (/= (strcase nam) (strcase (vla-get-name ref))) 
    (progn 
      (if (= :vlax-true (vla-get-isdynamicblock ref)) 
        (foreach prp (vlax-invoke ref 'GetDynamicBlockProperties) 
          (if 
            (and (= :vlax-false (vla-get-readonly prp)) 
                 (/= "ORIGIN" (strcase (vla-get-propertyname prp)))
            )
            (setq dyn (cons (cons (vla-get-propertyname prp) (vla-get-value prp)) dyn))
          )
        )
      )
      (vla-put-name ref nam)
      (if dyn 
        (foreach prp (vlax-invoke ref 'GetDynamicBlockProperties) 
          (if (setq val (assoc (vla-get-propertyname prp) (reverse dyn))) 
            (vl-catch-all-apply 'vla-put-value (list prp (cdr val)))
          )
        )
      )
    )
  )
)

;; transfers obj: its layer, its attributes, and points block references to their converted definition
(defun Dyl-LayTransfer-Apply (obj) 
  (if (Dyl-LayTransfer-Changes (vla-get-layer obj)) 
    (vla-put-layer obj (Dyl-LayTransfer-Target (vla-get-layer obj)))
  )
  (if (wcmatch (vla-get-objectname obj) "AcDbBlockReference,AcDbMInsertBlock") 
    (progn 
      (if (Dyl-LayTransfer-Scan (vla-get-effectivename obj)) 
        (Dyl-LayTransfer-Swap obj (Dyl-LayTransfer-Convert (vla-get-effectivename obj)))
      )
      (if (= :vlax-true (vla-get-hasattributes obj)) 
        (foreach att (vlax-invoke obj 'GetAttributes) 
          (Dyl-LayTransfer-Apply att)
        )
      )
    )
  )
)

(defun Dyl-LayTransfer (*pat *new / olderr *doc *layers *blocks *ss *objs *blks *map *lst *lck *tgt *src-obj *tgt-obj
                        *src-clr *key
                       ) 
  ;; *pat     - pattern string to match/replace in layer names (argument)
  ;; *new     - replacement string for the matched pattern (argument)
  ;; olderr   - saved *error* handler, restored on exit
  ;; *doc     - active VLA document object
  ;; *layers  - VLA layers collection of the active document
  ;; *blocks  - VLA blocks collection of the active document
  ;; *ss      - active selection set (VLA object)
  ;; *objs    - selected objects to transfer (own layer, attributes or block content)
  ;; *blks    - scanned block definitions : (NAME . T if content to transfer)
  ;; *map     - converted block definitions : (NAME . new name)
  ;; *lst     - list of unique layer names to transfer (selection + block content)
  ;; *lck     - list of source layers that are off, locked, or frozen
  ;; *tgt     - computed target layer name for each source layer during pre-pass
  ;; *src-obj - VLA layer object for the source layer (used when auto-creating target)
  ;; *tgt-obj - VLA layer object for the newly created target layer
  ;; *src-clr - ACI color number of the source layer, used to derive target layer color
  ;; *key     - the target as its layer key says it should be (Dyl-LayTransfer-Key), nil: not a key layer

  (setq olderr *error*)
  (defun *error* (*erm) 
    (princ 
      (strcat "\n--> Error in Dyl-LayTransfer application : " 
              *erm
              "\n"
      )
    )
    (command "undo" "end")
    (setq *error* olderr)
    (command "undo" "group")
    (prin1)
  )
  (vl-load-com)

  ;; build selection filter:
  ;;   Phase type - use "*-*" to accept both phase-suffix layers (*-E) and stacked layers (*-????)
  ;;                the loop decides replace-vs-append; the ssget just gates which objects are pickable
  ;;   Other types - keep the original exact-pattern filter
  ;;   Block references are always pickable (whatever their layer) so their content can be transferred
  (if 
    (ssget 
      (list 
        '(-4 . "<OR")
        (cons 8
              (if (member *typ '("Phase" "Field")) 
                "*-*"
                (strcat "*" *pat "*")
              )
        )
        '(0 . "INSERT")
        '(-4 . "OR>")
      )
    )
    (progn 
      (setq *doc (vla-get-activedocument (vlax-get-acad-object)))
      (setq *layers (vla-get-layers *doc))
      (setq *blocks (vla-get-blocks *doc))
      (setq *ss (vla-get-activeselectionset *doc))
      (setq *objs (list)
            *blks (list)
            *map  (list)
            *lst  (list)
      )
      (vlax-for obj *ss 
        (if (Dyl-LayTransfer-Check obj) 
          (setq *objs (cons obj *objs))
        )
      )

      ;; compute target layer name for each source layer, auto-create if missing; an existing
      ;; target of a layer key that differs from it: asked whether to update it to its key
      ;; (the window of the layer keys, see Remote>>Dyl:LayerKeyCheck)
      (foreach x *lst
        (setq *tgt (Dyl-LayTransfer-Target x)
              *key (Dyl-LayTransfer-Key *tgt)
        )
        (if (and (tblsearch "LAYER" *tgt) *key) (Remote>>Dyl:LayerKeyCheck *key))
        (if (not (tblsearch "LAYER" *tgt))
          (progn 
            (setq *src-obj (vla-item *layers x))
            (setq *tgt-obj (vla-add *layers *tgt))
            (setq *src-clr (vla-get-color *src-obj))
            (vla-put-color *tgt-obj
                           (cond
                             ;; the layer of a layer key: the color of its key in that phase (the
                             ;; color of the key when it keeps it in every phase)
                             (*key (atoi (nth 2 *key)))
                             ((= *new "-D") (atoi (strcat "2" (substr (itoa *src-clr) (strlen (itoa *src-clr))))))
                             ((= *new "-E") (atoi (strcat "20" (substr (itoa *src-clr) (strlen (itoa *src-clr))))))
                             ;; unphased from -D (2#) or -E (20#) : back to base color #
                             ((and (= *new "") (member *pat '("-D" "-E")))
                              (atoi (substr (itoa *src-clr) (strlen (itoa *src-clr))))
                             )
                             (T *src-clr)
                           )
            )
            (vla-put-linetype *tgt-obj (vla-get-linetype *src-obj))
            (vla-put-lineweight *tgt-obj (vla-get-lineweight *src-obj))
            (vla-put-plottable *tgt-obj (vla-get-plottable *src-obj))
            (if (vlax-property-available-p *src-obj 'Description) 
              (vla-put-description *tgt-obj (vla-get-description *src-obj))
            )
            (if (vlax-property-available-p *src-obj 'Transparency) 
              (vlax-put-property *tgt-obj 'Transparency (vlax-get-property *src-obj 'Transparency))
            )
          )
        )
        (if 
          (or (> 0 (cdr (assoc 62 (tblsearch "LAYER" x)))) 
              (/= 0 (cdr (assoc 70 (tblsearch "LAYER" x))))
          )
          (setq *lck (cons x *lck))
        )
      )

      (cond 
        ((not *objs)
         (princ "\nAucun objet à transférer")
        )
        (*lck
         (alert 
           (strcat "Error : Object(s) Turned Off, Locked or Freezed\n" 
                   (apply 'strcat (mapcar '(lambda (x) (strcat "\n" x)) *lck))
           )
         )
        )
        (T
         (vla-startundomark *doc)
         ;; blocks are not edited: their definition is copied under a new name (ex. "2X6" -> "2X6-N"),
         ;; the copy is transferred and only the selected references are switched to it
         (foreach obj *objs 
           (Dyl-LayTransfer-Apply obj)
         )
         (vla-endundomark *doc)
         ;; refresh block references so converted definitions display their new layers
         (if *map (vla-regen *doc acActiveViewport))
        )
      )
      (vla-delete *ss)
      (setq *error* olderr)
    )
    (progn 
      (princ "\nAucun objet sélectionné")
    )
  )
  (princ)
)



;;-------------------------=={ Commands }==------------------------;;

;;  The transfers are the child commands Pst-Transfer* below, run by their aliases
;;  (E-D, N-X...) or picked in the Dyl-LayerTransfer dialog. Pst-TransferField transfers any
;;  value of a level (field) of the NCS layer names to another one: it is the Layer Transfer
;;  button of the ribbon, which reads the Level, From and To drop-downs
;;  (Installer\Ribbon\Plugin\TransferCombos.cs).

;; Layer Transfer
;; Lists the layer transfers with their aliases and runs the one picked on the objects selected.

(defun c:Dyl-LayerTransfer ()
  (Dyl:ChildPicker "Dyl-LayerTransfer.lsp" "Layer Transfer" "Double-click a transfer (or OK), then select the objects." '*lt:last*)
)

;; Transfer Existing To Demolition
;; Moves the selected objects from their existing to remain phase layer to the matching existing to demolish layer.

(defun c:Pst-TransferExistingToDemolition (/ *pat *new) 
  (setq *pat "-E"
        *new "-D"
        *typ "Phase"
        *msg "Existing to remain transfer to... Existing to demolish"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Existing To New Work
;; Moves the selected objects from their existing to remain phase layer to the matching new work layer.

(defun c:Pst-TransferExistingToNewWork (/ *pat *new) 
  (setq *pat "-E"
        *new "-N"
        *typ "Phase"
        *msg "Existing to remain transfer to... New Work"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Existing To Refurbished
;; Moves the selected objects from their existing to remain phase layer to the matching being refurbished layer.

(defun c:Pst-TransferExistingToRefurbished (/ *pat *new) 
  (setq *pat "-E"
        *new "-R"
        *typ "Phase"
        *msg "Existing to remain transfer to... Being Refurbished"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Existing To Moved
;; Moves the selected objects from their existing to remain phase layer to the matching being moved layer.

(defun c:Pst-TransferExistingToMoved (/ *pat *new) 
  (setq *pat "-E"
        *new "-M"
        *typ "Phase"
        *msg "Existing to remain transfer to... Being Moved"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Existing To Saved
;; Moves the selected objects from their existing to remain phase layer to the matching to be saved layer.

(defun c:Pst-TransferExistingToSaved (/ *pat *new) 
  (setq *pat "-E"
        *new "-S"
        *typ "Phase"
        *msg "Existing to remain transfer to... To be Saved"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Existing To Abandoned
;; Moves the selected objects from their existing to remain phase layer to the matching abandoned layer.

(defun c:Pst-TransferExistingToAbandoned (/ *pat *new) 
  (setq *pat "-E"
        *new "-A"
        *typ "Phase"
        *msg "Existing to remain transfer to... Abandoned"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Existing To Future
;; Moves the selected objects from their existing to remain phase layer to the matching future work layer.

(defun c:Pst-TransferExistingToFuture (/ *pat *new) 
  (setq *pat "-E"
        *new "-F"
        *typ "Phase"
        *msg "Existing to remain transfer to... Future Work"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Existing To Temporary
;; Moves the selected objects from their existing to remain phase layer to the matching temporary work layer.

(defun c:Pst-TransferExistingToTemporary (/ *pat *new) 
  (setq *pat "-E"
        *new "-T"
        *typ "Phase"
        *msg "Existing to remain transfer to... Temporary Work"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Existing To Not In Contract
;; Moves the selected objects from their existing to remain phase layer to the matching not in contract layer.

(defun c:Pst-TransferExistingToNotInContract (/ *pat *new) 
  (setq *pat "-E"
        *new "-X"
        *typ "Phase"
        *msg "Existing to remain transfer to... Not in Contract"
  )
  (Dyl-LayTransfer *pat *new)
)






;; Transfer Demolition To Existing
;; Moves the selected objects from their existing to demolish phase layer to the matching existing to remain layer.

(defun c:Pst-TransferDemolitionToExisting (/ *pat *new) 
  (setq *pat "-D"
        *new "-E"
        *typ "Phase"
        *msg "Existing to demolish transfer to... Existing to remain"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Demolition To New Work
;; Moves the selected objects from their existing to demolish phase layer to the matching new work layer.

(defun c:Pst-TransferDemolitionToNewWork (/ *pat *new) 
  (setq *pat "-D"
        *new "-N"
        *typ "Phase"
        *msg "Existing to demolish transfer to... New Work"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Demolition To Refurbished
;; Moves the selected objects from their existing to demolish phase layer to the matching being refurbished layer.

(defun c:Pst-TransferDemolitionToRefurbished (/ *pat *new) 
  (setq *pat "-D"
        *new "-R"
        *typ "Phase"
        *msg "Existing to demolish transfer to... Being Refurbished"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Demolition To Moved
;; Moves the selected objects from their existing to demolish phase layer to the matching being moved layer.

(defun c:Pst-TransferDemolitionToMoved (/ *pat *new) 
  (setq *pat "-D"
        *new "-M"
        *typ "Phase"
        *msg "Existing to demolish transfer to... Being Moved"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Demolition To Saved
;; Moves the selected objects from their existing to demolish phase layer to the matching to be saved layer.

(defun c:Pst-TransferDemolitionToSaved (/ *pat *new) 
  (setq *pat "-D"
        *new "-S"
        *typ "Phase"
        *msg "Existing to demolish transfer to... To be Saved"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Demolition To Abandoned
;; Moves the selected objects from their existing to demolish phase layer to the matching abandoned layer.

(defun c:Pst-TransferDemolitionToAbandoned (/ *pat *new) 
  (setq *pat "-D"
        *new "-A"
        *typ "Phase"
        *msg "Existing to demolish transfer to... Abandoned"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Demolition To Future
;; Moves the selected objects from their existing to demolish phase layer to the matching future work layer.

(defun c:Pst-TransferDemolitionToFuture (/ *pat *new) 
  (setq *pat "-D"
        *new "-F"
        *typ "Phase"
        *msg "Existing to demolish transfer to... Future Work"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Demolition To Temporary
;; Moves the selected objects from their existing to demolish phase layer to the matching temporary work layer.

(defun c:Pst-TransferDemolitionToTemporary (/ *pat *new) 
  (setq *pat "-D"
        *new "-T"
        *typ "Phase"
        *msg "Existing to demolish transfer to... Temporary Work"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Demolition To Not In Contract
;; Moves the selected objects from their existing to demolish phase layer to the matching not in contract layer.

(defun c:Pst-TransferDemolitionToNotInContract (/ *pat *new) 
  (setq *pat "-D"
        *new "-X"
        *typ "Phase"
        *msg "Existing to demolish transfer to... Not in Contract"
  )
  (Dyl-LayTransfer *pat *new)
)





;; Transfer New Work To Demolition
;; Moves the selected objects from their new work phase layer to the matching existing to demolish layer.

(defun c:Pst-TransferNewWorkToDemolition (/ *pat *new) 
  (setq *pat "-N"
        *new "-D"
        *typ "Phase"
        *msg "New Work transfer to... Existing to demolish"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer New Work To Existing
;; Moves the selected objects from their new work phase layer to the matching existing to remain layer.

(defun c:Pst-TransferNewWorkToExisting (/ *pat *new) 
  (setq *pat "-N"
        *new "-E"
        *typ "Phase"
        *msg "New Work transfer to... Existing to remain"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer New Work To Refurbished
;; Moves the selected objects from their new work phase layer to the matching being refurbished layer.

(defun c:Pst-TransferNewWorkToRefurbished (/ *pat *new) 
  (setq *pat "-N"
        *new "-R"
        *typ "Phase"
        *msg "New Work transfer to... Being Refurbished"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer New Work To Moved
;; Moves the selected objects from their new work phase layer to the matching being moved layer.

(defun c:Pst-TransferNewWorkToMoved (/ *pat *new) 
  (setq *pat "-N"
        *new "-M"
        *typ "Phase"
        *msg "New Work transfer to... Being Moved"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer New Work To Saved
;; Moves the selected objects from their new work phase layer to the matching to be saved layer.

(defun c:Pst-TransferNewWorkToSaved (/ *pat *new) 
  (setq *pat "-N"
        *new "-S"
        *typ "Phase"
        *msg "New Work transfer to... To be Saved"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer New Work To Abandoned
;; Moves the selected objects from their new work phase layer to the matching abandoned layer.

(defun c:Pst-TransferNewWorkToAbandoned (/ *pat *new) 
  (setq *pat "-N"
        *new "-A"
        *typ "Phase"
        *msg "New Work transfer to... Abandoned"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer New Work To Future
;; Moves the selected objects from their new work phase layer to the matching future work layer.

(defun c:Pst-TransferNewWorkToFuture (/ *pat *new) 
  (setq *pat "-N"
        *new "-F"
        *typ "Phase"
        *msg "New Work transfer to... Future Work"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer New Work To Temporary
;; Moves the selected objects from their new work phase layer to the matching temporary work layer.

(defun c:Pst-TransferNewWorkToTemporary (/ *pat *new) 
  (setq *pat "-N"
        *new "-T"
        *typ "Phase"
        *msg "New Work transfer to... Temporary Work"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer New Work To Not In Contract
;; Moves the selected objects from their new work phase layer to the matching not in contract layer.

(defun c:Pst-TransferNewWorkToNotInContract (/ *pat *new) 
  (setq *pat "-N"
        *new "-X"
        *typ "Phase"
        *msg "New Work transfer to... Not in Contract"
  )
  (Dyl-LayTransfer *pat *new)
)





;; Transfer New Work To Unphased
;; Moves the selected objects from their new work phase layer to the matching unphased layer (phase suffix removed).

(defun c:Pst-TransferNewWorkToUnphased (/ *pat *new) 
  (setq *pat "-N"
        *new ""
        *typ "Phase"
        *msg "New Work transfer to... Unphased"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Demolition To Unphased
;; Moves the selected objects from their existing to demolish phase layer to the matching unphased layer (phase suffix removed).

(defun c:Pst-TransferDemolitionToUnphased (/ *pat *new) 
  (setq *pat "-D"
        *new ""
        *typ "Phase"
        *msg "Existing to demolish transfer to... Unphased"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Existing To Unphased
;; Moves the selected objects from their existing to remain phase layer to the matching unphased layer (phase suffix removed).

(defun c:Pst-TransferExistingToUnphased (/ *pat *new) 
  (setq *pat "-E"
        *new ""
        *typ "Phase"
        *msg "Existing to remain transfer to... Unphased"
  )
  (Dyl-LayTransfer *pat *new)
)







;; Transfer General To Architectural
;; Moves the selected objects from their general discipline layer to the matching architectural layer.

(defun c:Pst-TransferGeneralToArchitectural (/ *pat *new) 
  (setq *pat "G"
        *new "A"
        *typ "Designator"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer General To Structural
;; Moves the selected objects from their general discipline layer to the matching structural layer.

(defun c:Pst-TransferGeneralToStructural (/ *pat *new) 
  (setq *pat "G"
        *new "S"
        *typ "Designator"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Structural To Architectural
;; Moves the selected objects from their structural discipline layer to the matching architectural layer.

(defun c:Pst-TransferStructuralToArchitectural (/ *pat *new) 
  (setq *pat "S"
        *new "A"
        *typ "Designator"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Architectural To Structural
;; Moves the selected objects from their architectural discipline layer to the matching structural layer.

(defun c:Pst-TransferArchitecturalToStructural (/ *pat *new) 
  (setq *pat "A"
        *new "S"
        *typ "Designator"
  )
  (Dyl-LayTransfer *pat *new)
)





;; Transfer Line To Hidden
;; Moves the selected objects from their Line minor layer to the matching Hidd layer.

(defun c:Pst-TransferLineToHidden (/ *pat *new) 
  (setq *pat "Line"
        *new "Hidd"
        *typ "Minor"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Hidden To Line
;; Moves the selected objects from their Hidd minor layer to the matching Line layer.

(defun c:Pst-TransferHiddenToLine (/ *pat *new) 
  (setq *pat "Hidd"
        *new "Line"
        *typ "Minor"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Stack 0001 To 0002
;; Moves the selected objects from their stack 0001 layer to the matching stack 0002 layer.

(defun c:Pst-TransferStack0001To0002 (/ *pat *new) 
  (setq *pat "0001"
        *new "0002"
        *typ "Minor"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Stack 0001 To 0003
;; Moves the selected objects from their stack 0001 layer to the matching stack 0003 layer.

(defun c:Pst-TransferStack0001To0003 (/ *pat *new) 
  (setq *pat "0001"
        *new "0003"
        *typ "Minor"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Stack 0001 To 0004
;; Moves the selected objects from their stack 0001 layer to the matching stack 0004 layer.

(defun c:Pst-TransferStack0001To0004 (/ *pat *new) 
  (setq *pat "0001"
        *new "0004"
        *typ "Minor"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Stack 0001 To 0005
;; Moves the selected objects from their stack 0001 layer to the matching stack 0005 layer.

(defun c:Pst-TransferStack0001To0005 (/ *pat *new) 
  (setq *pat "0001"
        *new "0005"
        *typ "Minor"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Stack 0002 To 0001
;; Moves the selected objects from their stack 0002 layer to the matching stack 0001 layer.

(defun c:Pst-TransferStack0002To0001 (/ *pat *new) 
  (setq *pat "0002"
        *new "0001"
        *typ "Minor"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Stack 0002 To 0003
;; Moves the selected objects from their stack 0002 layer to the matching stack 0003 layer.

(defun c:Pst-TransferStack0002To0003 (/ *pat *new) 
  (setq *pat "0002"
        *new "0003"
        *typ "Minor"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Stack 0002 To 0004
;; Moves the selected objects from their stack 0002 layer to the matching stack 0004 layer.

(defun c:Pst-TransferStack0002To0004 (/ *pat *new) 
  (setq *pat "0002"
        *new "0004"
        *typ "Minor"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Stack 0002 To 0005
;; Moves the selected objects from their stack 0002 layer to the matching stack 0005 layer.

(defun c:Pst-TransferStack0002To0005 (/ *pat *new) 
  (setq *pat "0002"
        *new "0005"
        *typ "Minor"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Stack 0003 To 0001
;; Moves the selected objects from their stack 0003 layer to the matching stack 0001 layer.

(defun c:Pst-TransferStack0003To0001 (/ *pat *new) 
  (setq *pat "0003"
        *new "0001"
        *typ "Minor"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Stack 0003 To 0002
;; Moves the selected objects from their stack 0003 layer to the matching stack 0002 layer.

(defun c:Pst-TransferStack0003To0002 (/ *pat *new) 
  (setq *pat "0003"
        *new "0002"
        *typ "Minor"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Stack 0003 To 0004
;; Moves the selected objects from their stack 0003 layer to the matching stack 0004 layer.

(defun c:Pst-TransferStack0003To0004 (/ *pat *new) 
  (setq *pat "0003"
        *new "0004"
        *typ "Minor"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Stack 0003 To 0005
;; Moves the selected objects from their stack 0003 layer to the matching stack 0005 layer.

(defun c:Pst-TransferStack0003To0005 (/ *pat *new) 
  (setq *pat "0003"
        *new "0005"
        *typ "Minor"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Stack 0004 To 0001
;; Moves the selected objects from their stack 0004 layer to the matching stack 0001 layer.

(defun c:Pst-TransferStack0004To0001 (/ *pat *new) 
  (setq *pat "0004"
        *new "0001"
        *typ "Minor"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Stack 0004 To 0002
;; Moves the selected objects from their stack 0004 layer to the matching stack 0002 layer.

(defun c:Pst-TransferStack0004To0002 (/ *pat *new) 
  (setq *pat "0004"
        *new "0002"
        *typ "Minor"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Stack 0004 To 0003
;; Moves the selected objects from their stack 0004 layer to the matching stack 0003 layer.

(defun c:Pst-TransferStack0004To0003 (/ *pat *new) 
  (setq *pat "0004"
        *new "0003"
        *typ "Minor"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Stack 0004 To 0005
;; Moves the selected objects from their stack 0004 layer to the matching stack 0005 layer.

(defun c:Pst-TransferStack0004To0005 (/ *pat *new) 
  (setq *pat "0004"
        *new "0005"
        *typ "Minor"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Stack 0005 To 0001
;; Moves the selected objects from their stack 0005 layer to the matching stack 0001 layer.

(defun c:Pst-TransferStack0005To0001 (/ *pat *new) 
  (setq *pat "0005"
        *new "0001"
        *typ "Minor"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Stack 0005 To 0002
;; Moves the selected objects from their stack 0005 layer to the matching stack 0002 layer.

(defun c:Pst-TransferStack0005To0002 (/ *pat *new) 
  (setq *pat "0005"
        *new "0002"
        *typ "Minor"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Stack 0005 To 0003
;; Moves the selected objects from their stack 0005 layer to the matching stack 0003 layer.

(defun c:Pst-TransferStack0005To0003 (/ *pat *new) 
  (setq *pat "0005"
        *new "0003"
        *typ "Minor"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Stack 0005 To 0004
;; Moves the selected objects from their stack 0005 layer to the matching stack 0004 layer.

(defun c:Pst-TransferStack0005To0004 (/ *pat *new) 
  (setq *pat "0005"
        *new "0004"
        *typ "Minor"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Detail To Section
;; Moves the selected objects from their Detl major layer to the matching Sect layer.

(defun c:Pst-TransferDetailToSection (/ *pat *new) 
  (setq *pat "Detl"
        *new "Sect"
        *typ "Major"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Section To Detail
;; Moves the selected objects from their Sect major layer to the matching Detl layer.

(defun c:Pst-TransferSectionToDetail (/ *pat *new) 
  (setq *pat "Sect"
        *new "Detl"
        *typ "Major"
  )
  (Dyl-LayTransfer *pat *new)
)

;; Transfer Field
;; Moves the selected objects to the layers with another discipline designator, major group, minor group or status, the other fields kept.

;;  Run by the Transfer button of the ribbon (and its alias LTF): it transfers with the
;;  Level, From and To of the drop-downs, read with (Dyl:RibbonTransfer) of
;;  Resources\DynALisp.Ribbon.dll: (level from to), level "Discipline", "Major", "Minor" or
;;  "Status", from nil for any value, "" for the layers without one (minor group, status),
;;  to "" to remove the level. Without the drop-downs (AutoCAD before 2025) or before a To
;;  value is picked, it asks for them.
(defun c:Pst-TransferField (/ *pat *new *lt:fld *lt:src *lt:dst arg ok)
  (if Dyl:RibbonTransfer (setq arg (Dyl:RibbonTransfer)))
  (if arg
    (progn
      (setq *lt:fld (nth 0 arg)
            *lt:src (nth 1 arg)
            *lt:dst (nth 2 arg)
      )
      (princ (strcat "\nLayer transfer: "
                     *lt:fld
                     " "
                     (cond ((null *lt:src) "any") ((= "" *lt:src) "none") (*lt:src))
                     " to "
                     (if (= "" *lt:dst) "none" *lt:dst)
             )
      )
    )
    (progn
      (if Dyl:RibbonTransfer (princ "\nNo To value picked in the ribbon."))
      (initget "Discipline Major Minor Status")
      (setq *lt:fld (cond ((getkword "\nLevel of the layer names [Discipline/Major/Minor/Status] <Status>: ")) ("Status"))
            *lt:src (getstring "\nFrom value (Enter: any, None: the layers without one): ")
            *lt:src (cond ((= "" *lt:src) nil) ((wcmatch (strcase *lt:src) "NONE,UNPHASED") "") (*lt:src))
            *lt:dst (getstring "\nTo value (None: remove it): ")
      )
      (if (wcmatch (strcase *lt:dst) "NONE,UNPHASED") (setq *lt:dst ""))
    )
  )
  (setq ok (and (or (= "" *lt:dst) (snvalid *lt:dst))
                (cond
                  ((= "Discipline" *lt:fld) (wcmatch *lt:dst "@,@@"))
                  ((= "Major" *lt:fld) (= 4 (strlen *lt:dst)))
                  ((= "Minor" *lt:fld) (member (strlen *lt:dst) '(0 4)))
                  ((= "Status" *lt:fld) (<= (strlen *lt:dst) 1))
                )
           )
  )
  (if ok
    (progn
      (setq *typ "Field")
      (if (= "Status" *lt:fld)
        (setq *pat (if (and *lt:src (/= "" *lt:src)) (strcat "-" *lt:src) "")
              *new (if (/= "" *lt:dst) (strcat "-" *lt:dst) "")
        )
        (setq *pat (cond (*lt:src) (""))
              *new *lt:dst
        )
      )
      (Dyl-LayTransfer *pat *new)
    )
    (princ (strcat "\n" (if (= "" *lt:dst) "None" *lt:dst) " is not a value of the "
                   (cond ((= "Discipline" *lt:fld) "discipline designator (1 or 2 letters)")
                         ((= "Major" *lt:fld) "major group (4 characters)")
                         ((= "Minor" *lt:fld) "minor group (4 characters)")
                         ("status (1 character)")
                   )
                   "."
           )
    )
  )
  (princ)
)
