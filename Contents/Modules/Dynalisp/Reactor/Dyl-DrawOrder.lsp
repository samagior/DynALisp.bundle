;; Dyl-DrawOrder - Dynalisp auto draw order reactors: new objects put in their layer level
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
;;  Based on Layer Draw Order (LDOrder) by Lee Mac, Copyright (C) 2011 - www.lee-mac.com
;;
;;-------------------------=={ End of Licence }==------------------------;;

;;  Loaded at startup from the Reactor folder, after the Remote files, only while the
;;  DynALisp reactors are on (Dyl-Settings, see Dyl:ReactorsOn-p in dynalisp.mnl). Off, this
;;  file is not loaded and no reactor of it is made.
;;
;;  The levels, the restacking and the auto draw order setting (DynalispDrawOrderAuto) are
;;  in Modules\Dynalisp\Remote\Dyl-DrawOrder.lsp, the commands in
;;  Modules\Dynalisp\Apps\Layer\Dyl-DrawOrder.lsp.

(vl-load-com)

;;-------------------------=={ Auto draw order }==------------------------;;

;;  The reactors only collect the objects added to the drawing: they are restacked when
;;  the command (or the Lisp command) that created them ends, like auto-phase.
;;  *do:new*   - objects added since the command started
;;  *do:ref*   - T when a command that changes layers ran: the current space is restacked
;;  *do:depth* - commands running (transparent commands are nested in another one)
;;  *do:lisp*  - T while a Lisp command runs: its objects are restacked when it ends
;;  *do:off*   - T while the command running is one of the skipped commands
;;  *do:busy*  - T while the objects are restacked (the draw order tables created are not collected)
;;  *do:append* - the reactor of the objects added: active only while a command or a Lisp command runs
;;               (Reactor>>Dyl:DrawOrderWatch), see Reactor\Dyl-LayerPhase.lsp (objects added with no command
;;               running, by the palettes of AutoCAD Architecture, froze AutoCAD)

;;  Commands whose new objects are left where they are (wcmatch pattern):
(defun Reactor>>Dyl:DrawOrderSkip ()
  (strcase (cond ((getenv "DynalispDrawOrderSkip")) (*do:skip*)))
)

;;  Commands after which the current space is restacked (wcmatch pattern):
(defun Reactor>>Dyl:DrawOrderRefresh ()
  (strcase (cond ((getenv "DynalispDrawOrderRefresh")) (*do:refresh*)))
)

;;  Turn the reactor of the objects added on (a command or a Lisp command starts) or off:
(defun Reactor>>Dyl:DrawOrderWatch (on)
  (if (and *do:append* (not (eq (and on t) (vlr-added-p *do:append*))))
    (vl-catch-all-apply (if on 'vlr-add 'vlr-remove) (list *do:append*))
  )
)

(defun Reactor>>Dyl:DrawOrderOnAppend (rea args)
  (if (and (not *do:off*) (not *do:busy*) (= 'ENAME (type (cadr args))))
    (setq *do:new* (cons (cadr args) *do:new*))
  )
)

;;  A command started with no other one running starts the count again (see Dyl:CmdTop-p):
(defun Reactor>>Dyl:DrawOrderOnStart (rea args / cmd)
  (if (Dyl:CmdTop-p (car args)) (setq *do:depth* 0))
  (if (= 0 *do:depth*)
    (setq cmd      (strcase (car args))
          *do:off* (wcmatch cmd (Reactor>>Dyl:DrawOrderSkip))
          *do:ref* (or *do:ref* (wcmatch cmd (Reactor>>Dyl:DrawOrderRefresh)))
    )
  )
  (setq *do:depth* (1+ *do:depth*))
  (Reactor>>Dyl:DrawOrderWatch t)
)

(defun Reactor>>Dyl:DrawOrderOnEnd (rea args)
  (setq *do:depth* (max 0 (1- *do:depth*)))
  (if (= 0 *do:depth*)
    (progn
      (setq *do:off* nil)
      (if (not *do:lisp*)
        (progn
          (Reactor>>Dyl:DrawOrderWatch nil)
          (Reactor>>Dyl:DrawOrderRunSafe)
        )
      )
    )
  )
)

(defun Reactor>>Dyl:DrawOrderOnLisp (rea args)
  (setq *do:lisp* t)
  (Reactor>>Dyl:DrawOrderWatch t)
)

(defun Reactor>>Dyl:DrawOrderOnLispEnd (rea args)
  (setq *do:lisp*  nil
        *do:depth* 0
        *do:off*   nil
  )
  (Reactor>>Dyl:DrawOrderWatch nil)
  (Reactor>>Dyl:DrawOrderRunSafe)
)

;;  Space of the entity data ed, as taken by Remote>>Dyl:DrawOrderStack: the layout name
;;  of model space or a layout, the block record (ename) of a block definition restacked
;;  (see Remote>>Dyl:DrawOrderBlock-p). nil for anything else (attribute, vertex...):
(defun Reactor>>Dyl:DrawOrderSpaceOf (ed / own oed)
  (if
    (and (setq own (cdr (assoc 330 ed)))
         (setq oed (entget own))
         (= "BLOCK_RECORD" (cdr (assoc 0 oed)))
    )
    (cond
      ((wcmatch (strcase (cdr (assoc 2 oed))) "`*MODEL_SPACE,`*PAPER_SPACE*") (cdr (assoc 410 ed)))
      ((Remote>>Dyl:DrawOrderBlock-p (vlax-ename->vla-object own)) own)
    )
  )
)

;;  Put the objects collected by the reactors in their level. Per space (or block
;;  definition: BLOCK, BEDIT, REFEDIT...), only the new objects are moved, right below the
;;  levels that must stay above them (see Remote>>Dyl:DrawOrderPlace): a new line (order 0)
;;  goes under the annotation, a new hatch (order -4) under the lines, a new text on the
;;  top level moves nothing. The levels themselves are restacked only when the draw order
;;  cannot be read, and in the current space after a command that changes layers. A block
;;  definition restacked regenerates the drawing to show it in its references:
(defun Reactor>>Dyl:DrawOrderRun (/ lst ref rules ed tab s spc blk)
  (setq lst      *do:new*
        ref      *do:ref*
        *do:new* nil
        *do:ref* nil
  )
  (if (or lst ref)
    (progn
      (setq *do:busy* t
            rules     (Remote>>Dyl:DrawOrderRules)
      )
      ;;  spc: ((tab ename ...) ...), the new objects of each space:
      (foreach e lst
        (if
          (and (setq ed (entget e))
               (/= "VIEWPORT" (cdr (assoc 0 ed)))
               (setq tab (Reactor>>Dyl:DrawOrderSpaceOf ed))
          )
          (setq s   (cond ((assoc tab spc)) ((list tab)))
                spc (cons (append s (list e)) (vl-remove s spc))
          )
        )
      )
      (if (and ref (not (assoc (getvar "CTAB") spc))) (setq spc (cons (list (getvar "CTAB")) spc)))
      (foreach s spc
        (if
          (and (< 0
                  (cond
                    ((and ref (equal (car s) (getvar "CTAB"))) (Remote>>Dyl:DrawOrderStack (car s) 0 -1 rules))
                    ((Remote>>Dyl:DrawOrderPlaceSafe (car s) (cdr s) rules))
                    ((apply 'Remote>>Dyl:DrawOrderStack
                            (append (list (car s)) (Remote>>Dyl:DrawOrderBounds (cdr s) rules) (list rules))
                     )
                    )
                  )
               )
               (= 'ENAME (type (car s)))
          )
          (setq blk t)
        )
      )
      (if blk (vl-catch-all-apply 'vla-Regen (list (vla-get-ActiveDocument (vlax-get-acad-object)) acActiveViewport)))
      (setq *do:busy* nil)
    )
  )
  (princ)
)

;;  Reactor>>Dyl:DrawOrderRun called from a reactor: an error never stops the next commands:
(defun Reactor>>Dyl:DrawOrderRunSafe ()
  (vl-catch-all-apply 'Reactor>>Dyl:DrawOrderRun)
  (setq *do:busy* nil)
)

;;  Create (on) or remove (nil) the auto draw order reactors of the drawing. None is
;;  created while the DynALisp reactors are off (Dyl-Settings):
(defun Reactor>>Dyl:DrawOrderReactors (on)
  (foreach r *do:reactors* (vl-catch-all-apply 'vlr-remove (list r)))
  (setq *do:reactors* nil
        *do:append*   nil
        *do:new*      nil
        *do:ref*      nil
        *do:depth*    0
        *do:lisp*     nil
        *do:off*      nil
        *do:busy*     nil
  )
  ;;  Only the reactors of the drawing in front run (see Dyl:ReactorLocal in dynalisp.mnl).
  ;;  The reactor of the objects added waits for a command (Reactor>>Dyl:DrawOrderWatch):
  (if (and on (Dyl:ReactorsOn-p))
    (progn
    (setq *do:append*  (Dyl:ReactorLocal (vlr-acdb-reactor "Dyl-DrawOrder" '((:vlr-objectAppended . Reactor>>Dyl:DrawOrderOnAppend))))
          *do:reactors*
           (mapcar 'Dyl:ReactorLocal
                   (list *do:append*
                         (vlr-editor-reactor "Dyl-DrawOrder"
                                             '((:vlr-commandWillStart . Reactor>>Dyl:DrawOrderOnStart)
                                               (:vlr-commandEnded . Reactor>>Dyl:DrawOrderOnEnd)
                                               (:vlr-commandCancelled . Reactor>>Dyl:DrawOrderOnEnd)
                                               (:vlr-commandFailed . Reactor>>Dyl:DrawOrderOnEnd)
                                               (:vlr-lispWillStart . Reactor>>Dyl:DrawOrderOnLisp)
                                               (:vlr-lispEnded . Reactor>>Dyl:DrawOrderOnLispEnd)
                                               (:vlr-lispCancelled . Reactor>>Dyl:DrawOrderOnLispEnd)
                                              )
                         )
                   )
           )
    )
    (Reactor>>Dyl:DrawOrderWatch nil)
    )
  )
)

;;  A drawing made current follows the setting changed in another drawing:
;;  Every open drawing has this reactor: only the one of the drawing made current acts.
;;  The DynALisp reactors turned off in another drawing: every reactor of this drawing
;;  is removed (see Dyl:ReactorsStop in dynalisp.mnl):
(defun Reactor>>Dyl:DrawOrderOnDoc (rea args)
  (cond
    ((not (Dyl:ReactorsOn-p)) (Dyl:ReactorsStop))
    ((and (Dyl:ThisDoc-p args)
          (not (eq (Remote>>Dyl:DrawOrderAuto-p) (and *do:reactors* t)))
     )
     (vl-catch-all-apply 'Reactor>>Dyl:DrawOrderReactors (list (Remote>>Dyl:DrawOrderAuto-p)))
    )
  )
)

;;  Remove every reactor of this file in the drawing (run by Dyl:ReactorsStop):
(defun Reactor>>Dyl:DrawOrderStop ()
  (Reactor>>Dyl:DrawOrderReactors nil)
  (if *do:docreactor* (vl-catch-all-apply 'vlr-remove (list *do:docreactor*)))
  (setq *do:docreactor* nil)
)
(Dyl:ReactorsAdd 'Reactor>>Dyl:DrawOrderStop)

;;  Each drawing opened starts its auto draw order reactors. The document reactor is made
;;  again on each load (Dyl-Reload) so it always runs the functions of this file:
(Reactor>>Dyl:DrawOrderReactors (Remote>>Dyl:DrawOrderAuto-p))
(if *do:docreactor* (vl-catch-all-apply 'vlr-remove (list *do:docreactor*)))
(setq *do:docreactor* (if (Dyl:ReactorsOn-p)
                        (vlr-docmanager-reactor "Dyl-DrawOrder"
                                                '((:vlr-documentBecameCurrent . Reactor>>Dyl:DrawOrderOnDoc))
                        )
                      )
)

(princ)
