;; Dyl-LayerPhase - Dynalisp auto-phase reactors: new objects moved to the active phase
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
;;  The phases, the active phase and the auto-phase setting (DynalispPhaseAuto) are in
;;  Modules\Dynalisp\Remote\Dyl-LayerPhase.lsp, the commands in
;;  Modules\Dynalisp\Apps\Layer\Dyl-LayerPhase.lsp.

(vl-load-com)

;;-------------------------=={ Auto-phase }==------------------------;;

;;  The reactors only collect the objects added to the drawing: they are moved when the
;;  command (or the Lisp command) that created them ends, since an object cannot be
;;  changed while it is being added.
;;  *ph:new*   - objects added since the command started
;;  *ph:depth* - commands running (transparent commands are nested in another one)
;;  *ph:lisp*  - T while a Lisp command runs: its objects are moved when it ends
;;  *ph:off*   - T while the command running is one of the skipped commands
;;  *ph:busy*  - T while the objects are moved (the layers created are not collected)

;;  Commands whose new objects are left on their layer (wcmatch pattern):
(defun Reactor>>Dyl:PhaseSkip ()
  (strcase (cond ((getenv "DynalispPhaseSkip")) (*ph:skip*)))
)

(defun Reactor>>Dyl:PhaseOnAppend (rea args)
  (if (and (not *ph:off*) (not *ph:busy*) (= 'ENAME (type (cadr args))))
    (setq *ph:new* (cons (cadr args) *ph:new*))
  )
)

(defun Reactor>>Dyl:PhaseOnStart (rea args)
  (if (= 0 *ph:depth*) (setq *ph:off* (wcmatch (strcase (car args)) (Reactor>>Dyl:PhaseSkip))))
  (setq *ph:depth* (1+ *ph:depth*))
)

(defun Reactor>>Dyl:PhaseOnEnd (rea args)
  (setq *ph:depth* (max 0 (1- *ph:depth*)))
  (if (= 0 *ph:depth*)
    (progn
      (setq *ph:off* nil)
      (if (not *ph:lisp*) (Reactor>>Dyl:PhaseRunSafe))
    )
  )
)

(defun Reactor>>Dyl:PhaseOnLisp (rea args)
  (setq *ph:lisp* t)
)

(defun Reactor>>Dyl:PhaseOnLispEnd (rea args)
  (setq *ph:lisp*  nil
        *ph:depth* 0
        *ph:off*   nil
  )
  (Reactor>>Dyl:PhaseRunSafe)
)

;;  T when the entity data ed is in model space or in a layout (not in a block definition):
(defun Reactor>>Dyl:PhaseInSpace-p (ed / own)
  (and (setq own (cdr (assoc 330 ed)))
       (setq own (entget own))
       (= "BLOCK_RECORD" (cdr (assoc 0 own)))
       (wcmatch (strcase (cdr (assoc 2 own))) "`*MODEL_SPACE,`*PAPER_SPACE*")
  )
)

;;  Move an object to phase code, returns its new layer (nil when it stays on its layer):
(defun Reactor>>Dyl:PhaseMove (obj code codes bases / lay new)
  (setq lay (vla-get-Layer obj))
  (if
    (and (setq new (Remote>>Dyl:PhaseTarget lay code codes bases))
         (Remote>>Dyl:PhaseMake lay new (Remote>>Dyl:PhaseOf lay codes) code)
         (not (vl-catch-all-error-p (vl-catch-all-apply 'vla-put-Layer (list obj new))))
    )
    new
  )
)

;;  Move the objects collected by the reactors to the active phase:
(defun Reactor>>Dyl:PhaseRun (/ lst code codes bases ed obj new n hid)
  (setq lst      *ph:new*
        *ph:new* nil
  )
  (if (and lst (setq code (Remote>>Dyl:PhaseGet)))
    (progn
      (setq *ph:busy* t
            codes     (Remote>>Dyl:PhaseList)
            bases     (Remote>>Dyl:LayerKeyPhased)
            n         0
      )
      (foreach e lst
        (if
          (and (setq ed (entget e))
               (/= "VIEWPORT" (cdr (assoc 0 ed)))
               (Reactor>>Dyl:PhaseInSpace-p ed)
               (setq obj (vlax-ename->vla-object e))
          )
          (progn
            (if (setq new (Reactor>>Dyl:PhaseMove obj code codes bases))
              (progn
                (setq n (1+ n))
                (if
                  (and (not (member new hid))
                       (setq ed (tblsearch "LAYER" new))
                       (or (minusp (cdr (assoc 62 ed))) (= 1 (logand 1 (cdr (assoc 70 ed)))))
                  )
                  (setq hid (cons new hid))
                )
              )
            )
            ;;  The attributes of a block reference follow it:
            (if (and (= "AcDbBlockReference" (vla-get-ObjectName obj)) (= :vlax-true (vla-get-HasAttributes obj)))
              (foreach att (vlax-invoke obj 'GetAttributes) (Reactor>>Dyl:PhaseMove att code codes bases))
            )
          )
        )
      )
      (setq *ph:busy* nil)
      (if (< 0 n)
        (princ (strcat "\nAuto-phase " code ": " (itoa n) " object(s) moved to their phase layer."
                       (if hid (strcat " Layer off or frozen: " (Remote>>LM:lst->str (reverse hid) ", ")) "")
               )
        )
      )
    )
  )
  (princ)
)

;;  Reactor>>Dyl:PhaseRun called from a reactor: an error never stops the next commands:
(defun Reactor>>Dyl:PhaseRunSafe ()
  (vl-catch-all-apply 'Reactor>>Dyl:PhaseRun)
  (setq *ph:busy* nil)
)

;;  Create (on) or remove (nil) the auto-phase reactors of the drawing. None is created
;;  while the DynALisp reactors are off (Dyl-Settings):
(defun Reactor>>Dyl:PhaseReactors (on)
  (foreach r *ph:reactors* (vl-catch-all-apply 'vlr-remove (list r)))
  (setq *ph:reactors* nil
        *ph:new*      nil
        *ph:depth*    0
        *ph:lisp*     nil
        *ph:off*      nil
        *ph:busy*     nil
  )
  ;;  Only the reactors of the drawing in front run (see Dyl:ReactorLocal in dynalisp.mnl):
  (if (and on (Dyl:ReactorsOn-p))
    (setq *ph:reactors*
           (mapcar 'Dyl:ReactorLocal
                   (list (vlr-acdb-reactor "Dyl-LayerPhase" '((:vlr-objectAppended . Reactor>>Dyl:PhaseOnAppend)))
                         (vlr-editor-reactor "Dyl-LayerPhase"
                                             '((:vlr-commandWillStart . Reactor>>Dyl:PhaseOnStart)
                                               (:vlr-commandEnded . Reactor>>Dyl:PhaseOnEnd)
                                               (:vlr-commandCancelled . Reactor>>Dyl:PhaseOnEnd)
                                               (:vlr-commandFailed . Reactor>>Dyl:PhaseOnEnd)
                                               (:vlr-lispWillStart . Reactor>>Dyl:PhaseOnLisp)
                                               (:vlr-lispEnded . Reactor>>Dyl:PhaseOnLispEnd)
                                               (:vlr-lispCancelled . Reactor>>Dyl:PhaseOnLispEnd)
                                              )
                         )
                   )
           )
    )
  )
)

;;  A drawing made current follows the setting changed in another drawing and shows its
;;  own phase in the status bar. Every open drawing has this reactor: only the one of the
;;  drawing made current acts (each one wrote its own phase in the status bar).
;;  The DynALisp reactors turned off in another drawing: every reactor of this drawing
;;  is removed (see Dyl:ReactorsStop in dynalisp.mnl):
(defun Reactor>>Dyl:PhaseOnDoc (rea args)
  (cond
    ((not (Dyl:ReactorsOn-p)) (Dyl:ReactorsStop))
    ((Dyl:ThisDoc-p args)
     (if (not (eq (Remote>>Dyl:PhaseAuto-p) (and *ph:reactors* t)))
       (vl-catch-all-apply 'Reactor>>Dyl:PhaseReactors (list (Remote>>Dyl:PhaseAuto-p)))
     )
     (vl-catch-all-apply 'Remote>>Dyl:PhaseStatus)
    )
  )
)

;;  Remove every reactor of this file in the drawing (run by Dyl:ReactorsStop):
(defun Reactor>>Dyl:PhaseStop ()
  (Reactor>>Dyl:PhaseReactors nil)
  (if *ph:docreactor* (vl-catch-all-apply 'vlr-remove (list *ph:docreactor*)))
  (setq *ph:docreactor* nil)
)
(Dyl:ReactorsAdd 'Reactor>>Dyl:PhaseStop)

;;  Each drawing opened starts its auto-phase reactors. The document reactor is made again
;;  on each load (Dyl-Reload) so it always runs the functions of this file:
(Reactor>>Dyl:PhaseReactors (Remote>>Dyl:PhaseAuto-p))
(if *ph:docreactor* (vl-catch-all-apply 'vlr-remove (list *ph:docreactor*)))
(setq *ph:docreactor* (if (Dyl:ReactorsOn-p)
                        (vlr-docmanager-reactor "Dyl-LayerPhase"
                                                '((:vlr-documentBecameCurrent . Reactor>>Dyl:PhaseOnDoc))
                        )
                      )
)

(princ)
