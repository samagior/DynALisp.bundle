;; Dyl-Diagnostics - Dynalisp diagnostics reactors: count the events a drawing sends to the reactors
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
;;  file is not loaded: the DynALisp reactors then run on no event, there is nothing to count.
;;
;;  Makes no reactor at startup: Pst-DiagnosticsReactorEvents (Modules\Dynalisp\Apps\
;;  Troubleshooting\Dyl-Diagnostics.lsp) starts the count, and stops it the next time it
;;  runs. Made on demand for a moment, these reactors have no setting of their own; the
;;  DynALisp reactors turned off remove them with the others (Dyl:ReactorsStop).
;;
;;  *dge:reactors* - the counting reactors while the count runs
;;  *dge:counts*   - ((event . count) ...) since it started
;;  *dge:t0*       - MILLISECS when it started

(vl-load-com)

(defun Reactor>>Dyl:DiagInc (key / e)
  (setq e            (assoc key *dge:counts*)
        *dge:counts* (if e (subst (cons key (1+ (cdr e))) e *dge:counts*) (cons (cons key 1) *dge:counts*))
  )
)

;;  The kind of object of an ename (its entity type), "?" when it cannot be read:
(defun Reactor>>Dyl:DiagType (e / d)
  (if (and (= 'ENAME (type e)) (not (vl-catch-all-error-p (setq d (vl-catch-all-apply 'entget (list e))))))
    (cond ((cdr (assoc 0 d))) ("?"))
    "?"
  )
)

(defun Reactor>>Dyl:DiagOnAppend (r a) (Reactor>>Dyl:DiagInc (strcat "objectAppended " (Reactor>>Dyl:DiagType (cadr a)))))
(defun Reactor>>Dyl:DiagOnModify (r a) (Reactor>>Dyl:DiagInc (strcat "objectModified " (Reactor>>Dyl:DiagType (cadr a)))))
(defun Reactor>>Dyl:DiagOnErase (r a) (Reactor>>Dyl:DiagInc "objectErased"))
(defun Reactor>>Dyl:DiagOnCommand (r a) (Reactor>>Dyl:DiagInc (strcat "commandWillStart " (car a))))
(defun Reactor>>Dyl:DiagOnLisp (r a) (Reactor>>Dyl:DiagInc "lispWillStart"))
(defun Reactor>>Dyl:DiagOnSysVar (r a) (Reactor>>Dyl:DiagInc (strcat "sysVarChanged " (car a))))

;;  T while the count runs:
(defun Reactor>>Dyl:DiagEventsOn-p () (and *dge:reactors* t))

;;  Start counting the events of this drawing. Nothing is made while the DynALisp
;;  reactors are off. Returns T when the count started:
(defun Reactor>>Dyl:DiagEventsStart ()
  (Reactor>>Dyl:DiagEventsStop)
  (if (Dyl:ReactorsOn-p)
    (setq *dge:counts*   nil
          *dge:t0*       (getvar "MILLISECS")
          *dge:reactors* (mapcar 'Dyl:ReactorLocal
                                 (list (vlr-acdb-reactor "Dyl-Diagnostics"
                                                         '((:vlr-objectAppended . Reactor>>Dyl:DiagOnAppend)
                                                           (:vlr-objectModified . Reactor>>Dyl:DiagOnModify)
                                                           (:vlr-objectErased . Reactor>>Dyl:DiagOnErase)
                                                          )
                                       )
                                       (vlr-editor-reactor "Dyl-Diagnostics"
                                                           '((:vlr-commandWillStart . Reactor>>Dyl:DiagOnCommand)
                                                             (:vlr-lispWillStart . Reactor>>Dyl:DiagOnLisp)
                                                             (:vlr-sysVarChanged . Reactor>>Dyl:DiagOnSysVar)
                                                            )
                                       )
                                 )
                         )
    )
  )
)

;;  Stop counting. Returns (ms (event . count) ...), the most frequent first, nil when the
;;  count was not running:
(defun Reactor>>Dyl:DiagEventsStop (/ res)
  (if *dge:reactors*
    (setq res (cons (- (getvar "MILLISECS") *dge:t0*) (vl-sort *dge:counts* '(lambda (a b) (> (cdr a) (cdr b))))))
  )
  (foreach r *dge:reactors* (vl-catch-all-apply 'vlr-remove (list r)))
  (setq *dge:reactors* nil
        *dge:counts*   nil
  )
  res
)
(Dyl:ReactorsAdd 'Reactor>>Dyl:DiagEventsStop)

;;  A count left running by an earlier load (Dyl-Reload) is stopped:
(Reactor>>Dyl:DiagEventsStop)

(princ)
