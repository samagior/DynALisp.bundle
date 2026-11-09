;;  AddObjectsToBlock, ;; TODO: Add description
;;  Copyright (C) 2023  Samuel Martineau
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
;;
;;  Author:  Lee Mac, Copyright © 2011  -  www.lee-mac.com
;;
;;----------------------------------------------------------------------;;
;;
;;  Modifications from original:
;;
;;  2023-10 - Initial integration to Dynalisp ;; TODO: Make changes below
;;      - Removed versionning references.
;;      - Removed codes executing on load to prevent overload startup.
;;      - Removed original heading with full description.
;;      - Added licence heading.
;;      - Added link to help ressources.
;;
;;----------------------------------------------------------------------;;
;;
;;  IMPORTANT NOTICE :
;;  Exept for the modification listed above; this file is meant 
;;  to remain an exact copy of the original file:
;;  - No command, function or variable renaming
;;  - No reformating
;;  - No code addition or removal
;;
;;  Minor bug fixes and adjustements may be allowed to integrate into the
;;  Dynalisp repository if adequatly commneted and listed below :
;;  - YYYY-MM - Description
;;  
;;  Any other modification should be done as a FULL integration,
;;  see the CONTRIBUTING section for more details.
;;
;;----------------------------------------------------------------------;;
;;
;;  NOTES:
;;  - This is a PARTIAL interation.
;;  - To prevent conflict; any PARTIAL integration wont be loaded 
;;    automatically on startup unless specifically asked for by the user.
;;  - See the startup file and CONTRIBUTING section for more details.
;;
;;----------------------------------------------------------------------;;

;; Add Objects To Block
;; Adds the selected objects to the definition of a picked block.

(defun c:LM-AddObjectsToBlock (/ *error* bln bnl btr def ent enx idx lst sel tmp) 
  (vl-load-com)
  (defun *error* (msg) 
    (LM:endundo (LM:acdoc))
    (if (not (wcmatch (strcase msg t) "*break,*cancel*,*exit*")) 
      (princ (strcat "\nError: " msg))
    )
    (princ)
  )

  (LM:startundo (LM:acdoc))
  (cond 
    ((not (setq sel (LM:ssget "\nSelect objects to add to block: " '("_:L")))))
    ((progn 
       (repeat (setq idx (sslength sel)) 
         (setq idx (1- idx)
               ent (ssname sel idx)
               enx (entget ent)
               lst (cons (vlax-ename->vla-object ent) lst)
         )
         (if 
           (and (= "INSERT" (cdr (assoc 0 enx))) 
                (not (member (setq bln (strcase (cdr (assoc 2 enx)))) bnl))
           )
           (setq bnl (cons bln bnl))
         )
       )
       (while (setq def (tblnext "block" (not def))) 
         (setq ent (tblobjname "block" (cdr (assoc 2 def))))
         (while (setq ent (entnext ent)) 
           (if (= "INSERT" (cdr (assoc 0 (setq enx (entget ent))))) 
             (setq tmp (cons (strcase (cdr (assoc 2 enx))) tmp))
           )
         )
         (if tmp 
           (setq btr (cons (cons (strcase (cdr (assoc 2 def))) tmp) btr)
                 tmp nil
           )
         )
       )
       (while 
         (progn (setvar 'errno 0) 
                (setq ent (car (entsel "\nSelect block: ")))
                (cond 
                  ((= 7 (getvar 'errno))
                   (princ "\nMissed, try again.")
                  )
                  ((null ent)
                   nil
                  )
                  ((/= "INSERT" (cdr (assoc 0 (setq enx (entget ent)))))
                   (princ "\nThe selected object is not a block.")
                  )
                  ((not 
                     (and 
                       (equal (abs (cdr (assoc 41 enx))) 
                              (abs (cdr (assoc 42 enx)))
                              1e-8
                       )
                       (equal (abs (cdr (assoc 41 enx))) 
                              (abs (cdr (assoc 43 enx)))
                              1e-8
                       )
                     )
                   )
                   (princ "\nThis program is not currently compatible with non-uniformly scaled blocks - sorry.")
                  )
                  ((= :vlax-true (vla-get-isdynamicblock (vlax-ename->vla-object ent)))
                   (princ "\nThis program is not currently compatible with dynamic blocks - sorry.")
                  )
                  ((vl-some '(lambda (bln) (member bln bnl)) 
                            ((lambda (/ rtn) 
                               (setq bln (strcase (cdr (assoc 2 enx))))
                               (foreach def btr 
                                 (cond 
                                   ((= bln (car def)))
                                   ((member (car def) rtn))
                                   ((addtoblock:referenced-p bln (cdr def) btr)
                                    (setq rtn (cons (car def) rtn))
                                   )
                                 )
                               )
                               (cons bln rtn)
                             ) 
                            )
                   )
                   (princ "\nThe selected block is referenced by a block in the selection.")
                  )
                )
         )
       )
       ent
     )
     ((lambda (mat) 
        (foreach obj lst (vla-transformby obj mat))
        (vla-copyobjects (LM:acdoc) 
                         (vlax-make-variant 
                           (vlax-safearray-fill 
                             (vlax-make-safearray vlax-vbobject 
                                                  (cons 0 (1- (length lst)))
                             )
                             lst
                           )
                         )
                         (vla-item (vla-get-blocks (LM:acdoc)) (cdr (assoc 2 (entget ent))))
        )
        (foreach obj lst (vla-delete obj))
        (vla-regen (LM:acdoc) acallviewports)
      ) 
       (apply 
         (function 
           (lambda (mat vec) 
             (vlax-tmatrix 
               (append 
                 (mapcar 
                   (function 
                     (lambda (x v) 
                       (append x (list v))
                     )
                   )
                   mat
                   vec
                 )
                 '((0.0 0.0 0.0 1.0))
               )
             )
           )
         )
         (revrefgeom ent)
       )
     )
    )
  )
  (LM:endundo (LM:acdoc))
  (princ)
)

(defun addtoblock:referenced-p (bln def lst) 
  (or (member bln def) 
      (vl-some '(lambda (nst) (addtoblock:referenced-p bln (cdr (assoc nst lst)) lst)) def)
  )
)

;; RevRefGeom (gile)
;; The inverse of RefGeom

(defun revrefgeom (ent / ang enx mat ocs) 
  (setq enx (entget ent)
        ang (cdr (assoc 050 enx))
        ocs (cdr (assoc 210 enx))
  )
  (list 
    (setq mat (mxm 
                (list 
                  (list (/ 1.0 (cdr (assoc 41 enx))) 0.0 0.0)
                  (list 0.0 (/ 1.0 (cdr (assoc 42 enx))) 0.0)
                  (list 0.0 0.0 (/ 1.0 (cdr (assoc 43 enx))))
                )
                (mxm 
                  (list 
                    (list (cos ang) (sin ang) 0.0)
                    (list (- (sin ang)) (cos ang) 0.0)
                    '(0.0 0.0 1.0)
                  )
                  (mapcar '(lambda (v) (trans v ocs 0 t)) 
                          '((1.0 0.0 0.0)
                            (0.0 1.0 0.0)
                            (0.0 0.0 1.0)
                           )
                  )
                )
              )
    )
    (mapcar '- 
            (cdr (assoc 10 (tblsearch "block" (cdr (assoc 2 enx)))))
            (mxv mat (trans (cdr (assoc 10 enx)) ocs 0))
    )
  )
)

;; Matrix Transpose  -  Doug Wilson
;; Args: m - nxn matrix

(defun trp (m) 
  (apply 'mapcar (cons 'list m))
)

;; Matrix x Matrix  -  Vladimir Nesterovsky
;; Args: m,n - nxn matrices

(defun mxm (m n) 
  ((lambda (a) (mapcar '(lambda (r) (mxv a r)) m)) (trp n))
)

;; Matrix x Vector  -  Vladimir Nesterovsky
;; Args: m - nxn matrix, v - vector in R^n

(defun mxv (m v) 
  (mapcar '(lambda (r) (apply '+ (mapcar '* r v))) m)
)

;; ssget  -  Lee Mac
;; A wrapper for the ssget function to permit the use of a custom selection prompt
;; msg - [str] selection prompt
;; arg - [lst] list of ssget arguments

(defun LM:ssget (msg arg / sel) 
  (princ msg)
  (setvar 'nomutt 1)
  (setq sel (vl-catch-all-apply 'ssget arg))
  (setvar 'nomutt 0)
  (if (not (vl-catch-all-error-p sel)) sel)
)

;; Start Undo  -  Lee Mac
;; Opens an Undo Group.

(defun LM:startundo (doc) 
  (LM:endundo doc)
  (vla-startundomark doc)
)

;; End Undo  -  Lee Mac
;; Closes an Undo Group.

(defun LM:endundo (doc) 
  (while (= 8 (logand 8 (getvar 'undoctl))) 
    (vla-endundomark doc)
  )
)

;; Active Document  -  Lee Mac
;; Returns the VLA Active Document Object

(defun LM:acdoc nil 
  (eval (list 'defun 'LM:acdoc 'nil (vla-get-activedocument (vlax-get-acad-object))))
  (LM:acdoc)
)

;;----------------------------------------------------------------------;;

;;; (vl-load-com)
;;; (princ
;;;     (strcat
;;;         "\n:: AddObjectsToBlock.lsp | Version 1.2 | \\U+00A9 Lee Mac "
;;;         ((lambda ( y ) (if (= y (menucmd "m=$(edtime,0,yyyy)")) y (strcat y "-" (menucmd "m=$(edtime,0,yyyy)")))) "2011")
;;;         " www.lee-mac.com ::"
;;;         "\n:: Type \"addtoblock\" to Invoke ::"
;;;     )
;;; )
;;; (princ)

;;----------------------------------------------------------------------;;
;;                             End of File                              ;;
;;----------------------------------------------------------------------;;