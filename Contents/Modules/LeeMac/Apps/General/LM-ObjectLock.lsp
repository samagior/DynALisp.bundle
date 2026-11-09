;;  Object Lock
;;  Copyright (C) 2026  Samuel Martineau
;;
;;  This program is free software: you can redistribute it and/or modify
;;  it under the terms of the GNU General Public License as published by
;;  the Free Software Foundation, either version 3 of the License, or
;;  (at your option) any later version.
;;
;;  This program is distributed in the hope that it will be useful,
;;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;  GNU General Public License for more details.
;;
;;  You should have received a copy of the GNU General Public License
;;  along with this program.  If not, see <https://www.gnu.org/licenses/>.
;;
;;  Author licence applies on top of the above GPL licence, See
;;  the "Licences" folder or Author domain for more details.
;;
;;----------------------------------------------------------------------;;

;;---------------------=={ Object Lock }==--------------------;;
;;                                                            ;;
;;  Purely academic code demonstrating the ability to use     ;;
;;  reactors to prevent modification of a selection of        ;;
;;  objects, and furthermore retain such security between     ;;
;;  drawing sessions.                                         ;;
;;                                                            ;;
;;  The code is written for demonstration only since it quite ;;
;;  clearly isn't practical. The functionality can be         ;;
;;  matched by simply using a Locked Layer; and moreover      ;;
;;  don't get your hopes up in thinking that you can use this ;;
;;  code to prevent third party modification of your drawings ;;
;;  since the reactors need to be loaded before the lock is   ;;
;;  effective. And who's going to fall for that one... ;)     ;;
;;                                                            ;;
;;  The program uses two reactors: an Editor Reactor - to     ;;
;;  undo any modification of a selection of objects following ;;
;;  the completion of a command or LISP program; and a        ;;
;;  Drawing Reactor - to save the handles of the locked       ;;
;;  Objects in a dictionary so that the reactors may be       ;;
;;  rebuilt when the drawing is next opened.                  ;;
;;                                                            ;;
;;  The concept of 'undeleting' entities following a command  ;;
;;  was first proposed (to my knowledge) by Luis Esquivel in  ;;
;;  the following thread at TheSwamp:                         ;;
;;                                                            ;;
;;  http://www.theswamp.org/index.php?topic=6455.0            ;;
;;                                                            ;;
;;  I have expanded on this idea to undo, not only a deletion ;;
;;  but all changes made to an object by storing the DXF data ;;
;;  of the entity upon locking, and continuously reverting    ;;
;;  back to this data following modification.                 ;;
;;                                                            ;;
;;  I would also like to thank Gilles Chanteau, since with    ;;
;;  aid of his 'True Rectangle' program, I learnt a great     ;;
;;  deal with regard to saving data in Drawing Dictionaries.  ;;
;;  Merci!                                                    ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright � 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Version 1.0    -    08-05-2011                            ;;
;;------------------------------------------------------------;;

;;------------------------------------------------------------;;
;;  Lock Objects  -  Locks Selected Unlocked Objects          ;;
;;------------------------------------------------------------;;

;; Lock Objects
;; Prevents the modification of the selected objects with a persistent reactor.

(defun c:Pst-LockObjects ( / ss i j h e )  
  (if (setq ss (ssget))
    (progn
      (repeat (setq j 0 i (sslength ss))
        (if
          (not
            (member
              (setq h
                (cdr
                  (assoc 5
                    (setq e
                      (entget
                        (ssname ss (setq i (1- i)))
                      )
                    )
                  )
                )
              )
              *handle*
            )
          )
          (setq *handle* (cons h *handle*) *elist* (cons e *elist*) j (1+ j))
        )
      )
      (if
        (not
          (vl-some
            (function
              (lambda ( r )
                (eq "ObjectLock" (vlr-data r))
              )
            )
            (cdar (vlr-reactors :vlr-editor-reactor))
          )
        )
        (vlr-editor-reactor "ObjectLock"
          (list
            (cons :vlr-commandended 'ObjectLockCallBack)
            (cons :vlr-lispended    'ObjectLockCallBack)
          )
        )
      )
      (if
        (not
          (vl-some
            (function
              (lambda ( r )
                (eq "ObjectLock" (vlr-data r))
              )
            )
            (cdar (vlr-reactors :vlr-dwg-reactor))
          )
        )
        (vlr-dwg-reactor "ObjectLock"
          (list
            (cons :vlr-beginsave 'ObjectLockSave)
          )
        )
      )          
      (princ
        (strcat "\n"
          (itoa j) " Object(s) Locked, Total: " (itoa (length *handle*)) " Locked."
        )
      )
    )
  )
  (princ)
)

;;------------------------------------------------------------;;
;;  Unlock Objects  -  Unlocks Selected Locked Objects        ;;
;;------------------------------------------------------------;;

;; Unlock Objects
;; Removes the modification lock from the selected objects.

(defun c:Pst-UnlockObjects ( / ss i j r )
  (if *handle*
    (if (setq ss (ssget))
      (progn
        (repeat (setq j 0 i (sslength ss))
          (if
            (member
              (setq h
                (cdr
                  (assoc 5
                    (setq e
                      (entget
                        (ssname ss (setq i (1- i)))
                      )
                    )
                  )
                )
              )
              *handle*
            )
            (setq *handle* (vl-remove h *handle*) *elist* (vl-remove e *elist*) j (1+ j))
          )
        )
        (princ
          (strcat "\n"
            (itoa j) " Object(s) Unlocked, Total: " (itoa (length *handle*)) " Locked."
          )
        )
      )
    )
    (princ "\n--> No Objects Locked.")
  )
  (if (null *handle*)
    (mapcar
      (function
        (lambda ( r )
          (if (eq "ObjectLock" (vlr-data r)) (vlr-remove r))
        )
      )
      (apply 'append (mapcar 'cdr (vlr-reactors)))
    )
  )
  (princ)
)

;;------------------------------------------------------------;;
;;  Disable Lock  -  Unlocks Everything                       ;;
;;------------------------------------------------------------;;

;; Disable Object Lock
;; Removes the object lock reactor and its data from the drawing.

(defun c:Pst-DisableObjectLock ( / acdic dic )
  (mapcar
    (function
      (lambda ( r )
        (if (eq "ObjectLock" (vlr-data r)) (vlr-remove r))
      )
    )
    (apply 'append (mapcar 'cdr (vlr-reactors)))
  )
  (setq acdic
    (vla-get-dictionaries
      (vla-get-activedocument (vlax-get-acad-object))
    )
  )
  (if (setq dic (ObjectLockGetItem acdic "ObjectLock"))
    (vla-delete dic)
  )
  (setq *handle* nil *elist* nil)
  (princ)
)

;;------------------------------------------------------------;;

(defun ObjectLockCallBack ( a b )
  (mapcar
    (function
      (lambda ( h )
        (or (entget (handent h)) (entdel (handent h)))
      )
    )
    *handle*
  )
  (mapcar 'entmod *elist*)
  (princ)
)

;;------------------------------------------------------------;;

(defun ObjectLockGetItem ( collection item )
  (if
    (not
      (vl-catch-all-error-p
        (setq item
          (vl-catch-all-apply 'vla-item (list collection item))
        )
      )
    )
    item
  )
)

;;------------------------------------------------------------;;
;;                           Saving                           ;;
;;------------------------------------------------------------;;

(defun ObjectLockSave ( a b / acdic dic xrec l )
  (if *handle*
    (progn
      (setq acdic
        (vla-get-dictionaries
          (vla-get-activedocument (vlax-get-acad-object))
        )
      )
      (if (not (setq dic (ObjectLockGetItem acdic "ObjectLock")))
        (setq dic (vla-add acdic "ObjectLock"))
      )
      (if (not (setq xrec (ObjectLockGetItem dic "Handles")))
        (setq xrec (vla-addxrecord dic "Handles"))
      )
      (vla-setxrecorddata xrec
        (vlax-safearray-fill
          (vlax-make-safearray vlax-vbinteger (cons 0 (1- (length *handle*))))
          (repeat (length *handle*) (setq l (cons 1 l)))
        )
        (vlax-safearray-fill
          (vlax-make-safearray vlax-vbvariant (cons 0 (1- (length *handle*))))
          (mapcar '(lambda ( h ) (vlax-make-variant h vlax-vbstring)) *handle*)
        )
      )
    )
  )
  (princ)
)

;;------------------------------------------------------------;;
;;                          Loading                           ;;
;;------------------------------------------------------------;;

(
  (lambda ( / dic xrec typ val ) (vl-load-com)
    (mapcar
      (function
        (lambda ( r )
          (if (eq "ObjectLock" (vlr-data r)) (vlr-remove r))
        )
      )
      (apply 'append (mapcar 'cdr (vlr-reactors)))
    )
    (if
      (and
        (setq dic
          (ObjectLockGetItem
            (vla-get-dictionaries
              (vla-get-activedocument (vlax-get-acad-object))
            )
            "ObjectLock"
          )
        )
        (setq xrec (ObjectLockGetItem dic "Handles"))
        (progn (vla-getxrecorddata xrec 'typ 'val) val)
      )
      (if
        (and
          (setq *handle*
            (vl-remove-if-not
              (function
                (lambda ( h ) (entget (handent h)))
              )
              (mapcar 'vlax-variant-value (vlax-safearray->list val))
            )
          )
          (setq *elist* (mapcar '(lambda ( h ) (entget (handent h))) *handle*))
        )
        (progn
          (vlr-editor-reactor "ObjectLock"
            (list
              (cons :vlr-commandended 'ObjectLockCallBack)
              (cons :vlr-lispended    'ObjectLockCallBack)
            )
          )
          (vlr-dwg-reactor "ObjectLock"
            (list
              (cons :vlr-beginsave 'ObjectLockSave)
            )
          )
        )
      )
    )
  )
)

;;; (princ)

;;------------------------------------------------------------;;
;;                         End of File                        ;;
;;------------------------------------------------------------;;

;;-------------------------=={ DynALisp }==------------------------;;

;;  The commands above are child commands (Pst-*) of LM-ObjectLock, run by their
;;  aliases or picked in its dialog (Dyl:ChildPicker, dynalisp.mnl).

;; Object Lock
;; Lists the Object Lock commands with their aliases and runs the one picked.

(defun c:LM-ObjectLock ()
  (Dyl:ChildPicker "LM-ObjectLock.lsp" "Object Lock" "Double-click an action (or OK)." '*lm-objectlock:last*)
)
(princ)
