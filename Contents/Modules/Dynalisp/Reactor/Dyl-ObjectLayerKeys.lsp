;; Dyl-ObjectLayerKeys - Dynalisp reactors: new objects put on the layer key of their kind
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

;;  Loaded at startup from the Reactor folder, after the Remote files, only while the
;;  DynALisp reactors are on (Dyl-Settings, see Dyl:ReactorsOn-p in dynalisp.mnl). Off, this
;;  file is not loaded and no reactor of it is made.
;;
;;  The kinds of objects, their keys and the Auto layer keys setting (DynalispObjectKeys) are
;;  in Modules\Dynalisp\Remote\Dyl-LayerKey.lsp (Object layer keys), the window in
;;  Modules\Dynalisp\Apps\Layer\Dyl-ObjectLayerKeys.lsp.

(vl-load-com)

;;-------------------------=={ Auto layer keys }==------------------------;;

;;  As auto-phase, the reactors only collect the objects added to the drawing: they are moved
;;  to the layer of their key when the command that created them ends (an object cannot be
;;  changed while it is being added). The objects made by a Lisp command are left as they
;;  are: the DynALisp Apps put theirs on their own layer keys. With auto-phase, the layer of a
;;  key is in the active phase (see Remote>>Dyl:LayerKeyLayer).
;;  *olk:new*   - objects added since the command started
;;  *olk:cmd*   - the command running (upper case)
;;  *olk:depth* - commands running (transparent commands are nested in another one)
;;  *olk:lisp*  - T while a Lisp command runs: its objects are not collected
;;  *olk:off*   - T while the command running is one of the skipped commands
;;  *olk:busy*  - T while the objects are moved (the layers created are not collected)

(defun Reactor>>Dyl:ObjectKeysOnAppend (rea args)
  (if (and (not *olk:off*) (not *olk:busy*) (not *olk:lisp*) (< 0 *olk:depth*) (= 'ENAME (type (cadr args))))
    (setq *olk:new* (cons (cadr args) *olk:new*))
  )
)

(defun Reactor>>Dyl:ObjectKeysOnStart (rea args)
  (if (= 0 *olk:depth*)
    (setq *olk:cmd* (strcase (car args))
          *olk:off* (wcmatch *olk:cmd* (strcase (Remote>>Dyl:ObjectKeysSkip)))
          *olk:new* nil
    )
  )
  (setq *olk:depth* (1+ *olk:depth*))
)

(defun Reactor>>Dyl:ObjectKeysOnEnd (rea args)
  (setq *olk:depth* (max 0 (1- *olk:depth*)))
  (if (= 0 *olk:depth*)
    (progn
      (if (not (or *olk:off* *olk:lisp*)) (Reactor>>Dyl:ObjectKeysRunSafe))
      (setq *olk:off* nil
            *olk:new* nil
      )
    )
  )
)

(defun Reactor>>Dyl:ObjectKeysOnLisp (rea args)
  (setq *olk:lisp* t)
)

(defun Reactor>>Dyl:ObjectKeysOnLispEnd (rea args)
  (setq *olk:lisp*  nil
        *olk:depth* 0
        *olk:off*   nil
        *olk:new*   nil
  )
)

;;  T when the entity data ed is in model space or in a layout (not in a block definition):
(defun Reactor>>Dyl:ObjectKeysInSpace-p (ed / own)
  (and (setq own (cdr (assoc 330 ed)))
       (setq own (entget own))
       (= "BLOCK_RECORD" (cdr (assoc 0 own)))
       (wcmatch (strcase (cdr (assoc 2 own))) "`*MODEL_SPACE,`*PAPER_SPACE*")
  )
)

;;  Put the objects collected on the layer of the key of their kind (see
;;  Remote>>Dyl:ObjectKeysKind; a kind without key: left on their layer). The layer of each
;;  key is found once (created, thawed when frozen, see Remote>>Dyl:LayerKeyLayer); no window
;;  is shown from a reactor (*lk:noask*: a layer that differs from its key is asked about the
;;  next time an App uses the key). The paper space of a layout (its first viewport) is left:
(defun Reactor>>Dyl:ObjectKeysRun (/ lst keys lays ed kind key lay n)
  (setq lst       *olk:new*
        *olk:new* nil
  )
  (if lst
    (progn
      (setq *olk:busy* t
            *lk:noask* t
            keys       (Remote>>Dyl:ObjectKeysRead)
            n          0
      )
      (foreach e (reverse lst)
        (if
          (and (setq ed (entget e))
               (Reactor>>Dyl:ObjectKeysInSpace-p ed)
               (not (and (= "VIEWPORT" (cdr (assoc 0 ed))) (= 1 (cdr (assoc 69 ed)))))
               (setq kind (Remote>>Dyl:ObjectKeysKind (cdr (assoc 0 ed)) *olk:cmd*))
               (/= "" (setq key (cond ((cadr (assoc (car kind) keys))) (""))))
          )
          (progn
            (if (not (assoc key lays)) (setq lays (cons (cons key (Remote>>Dyl:LayerKeyLayer key)) lays)))
            (setq lay (cdr (assoc key lays)))
            (if
              (and lay
                   (/= (strcase lay) (strcase (cdr (assoc 8 ed))))
                   (not (vl-catch-all-error-p
                          (vl-catch-all-apply 'vla-put-Layer (list (vlax-ename->vla-object e) lay))
                        )
                   )
              )
              (setq n (1+ n))
            )
          )
        )
      )
      (setq *olk:busy* nil
            *lk:noask* nil
      )
      (if (< 0 n) (princ (strcat "\nAuto layer keys: " (itoa n) " object(s) put on their layer key.")))
    )
  )
  (princ)
)

;;  Reactor>>Dyl:ObjectKeysRun called from a reactor: an error never stops the next commands:
(defun Reactor>>Dyl:ObjectKeysRunSafe ()
  (vl-catch-all-apply 'Reactor>>Dyl:ObjectKeysRun)
  (setq *olk:busy* nil
        *lk:noask* nil
  )
)

;;  Create (on) or remove (nil) the reactors of the drawing. None is created while the
;;  DynALisp reactors are off (Dyl-Settings):
(defun Reactor>>Dyl:ObjectKeysReactors (on)
  (foreach r *olk:reactors* (vl-catch-all-apply 'vlr-remove (list r)))
  (setq *olk:reactors* nil
        *olk:new*      nil
        *olk:cmd*      ""
        *olk:depth*    0
        *olk:lisp*     nil
        *olk:off*      nil
        *olk:busy*     nil
  )
  ;;  Only the reactors of the drawing in front run (see Dyl:ReactorLocal in dynalisp.mnl):
  (if (and on (Dyl:ReactorsOn-p))
    (setq *olk:reactors*
           (mapcar 'Dyl:ReactorLocal
                   (list (vlr-acdb-reactor "Dyl-ObjectLayerKeys" '((:vlr-objectAppended . Reactor>>Dyl:ObjectKeysOnAppend)))
                         (vlr-editor-reactor "Dyl-ObjectLayerKeys"
                                             '((:vlr-commandWillStart . Reactor>>Dyl:ObjectKeysOnStart)
                                               (:vlr-commandEnded . Reactor>>Dyl:ObjectKeysOnEnd)
                                               (:vlr-commandCancelled . Reactor>>Dyl:ObjectKeysOnEnd)
                                               (:vlr-commandFailed . Reactor>>Dyl:ObjectKeysOnEnd)
                                               (:vlr-lispWillStart . Reactor>>Dyl:ObjectKeysOnLisp)
                                               (:vlr-lispEnded . Reactor>>Dyl:ObjectKeysOnLispEnd)
                                               (:vlr-lispCancelled . Reactor>>Dyl:ObjectKeysOnLispEnd)
                                              )
                         )
                   )
           )
    )
  )
)

;;  A drawing made current follows the setting changed in another drawing. The DynALisp
;;  reactors turned off in another drawing: every reactor of this drawing is removed (see
;;  Dyl:ReactorsStop in dynalisp.mnl):
(defun Reactor>>Dyl:ObjectKeysOnDoc (rea args)
  (cond
    ((not (Dyl:ReactorsOn-p)) (Dyl:ReactorsStop))
    ((Dyl:ThisDoc-p args)
     (if (not (eq (Remote>>Dyl:ObjectKeysAuto-p) (and *olk:reactors* t)))
       (vl-catch-all-apply 'Reactor>>Dyl:ObjectKeysReactors (list (Remote>>Dyl:ObjectKeysAuto-p)))
     )
    )
  )
)

;;  Remove every reactor of this file in the drawing (run by Dyl:ReactorsStop):
(defun Reactor>>Dyl:ObjectKeysStop ()
  (Reactor>>Dyl:ObjectKeysReactors nil)
  (if *olk:docreactor* (vl-catch-all-apply 'vlr-remove (list *olk:docreactor*)))
  (setq *olk:docreactor* nil)
)
(Dyl:ReactorsAdd 'Reactor>>Dyl:ObjectKeysStop)

;;  Each drawing opened starts its reactors. The document reactor is made again on each load
;;  (Dyl-Reload) so it always runs the functions of this file:
(Reactor>>Dyl:ObjectKeysReactors (Remote>>Dyl:ObjectKeysAuto-p))
(if *olk:docreactor* (vl-catch-all-apply 'vlr-remove (list *olk:docreactor*)))
(setq *olk:docreactor* (if (Dyl:ReactorsOn-p)
                         (vlr-docmanager-reactor "Dyl-ObjectLayerKeys"
                                                 '((:vlr-documentBecameCurrent . Reactor>>Dyl:ObjectKeysOnDoc))
                         )
                       )
)

(princ)
