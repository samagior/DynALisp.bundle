;; ResetLtScale - Resets the linetype scale of all objects to 1.0
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
;;; ResetLtScale.lsp
;;;
;;; Remet l'echelle de type de ligne (LinetypeScale / code DXF 48) a 1.0 sur
;;; tous les objets du dessin : espace objet + tous les onglets de
;;; presentation, y compris les attributs des references de blocs.
;;;
;;; Portee : objets du dessin uniquement.
;;;   - Les definitions de blocs ne sont PAS parcourues.
;;;   - Les variables systeme LTSCALE / CELTSCALE ne sont PAS modifiees.
;;;   - Les references externes (xrefs) sont ignorees.
;;;
;;; Commandes :
;;;   LTS1            - execute la remise a 1.0
;;;   RESETLTSCALE    - alias de LTS1
;;;
;;; Notes :
;;;   Utilise ActiveX : les objets sur des calques verrouilles, geles ou
;;;   desactives sont egalement traites.
;;;   L'operation est enregistree comme une seule transaction UNDO.
;;; ==========================================================================

(vl-load-com)

;;; --------------------------------------------------------------------------
;;; rlts:fix-object
;;;   Remet a 1.0 l'echelle de type de ligne d'un objet VLA.
;;;   Retourne T si l'objet a ete modifie, nil sinon.
;;; --------------------------------------------------------------------------
(defun rlts:fix-object (obj / cur res) 
  (setq res nil)
  (if (vlax-property-available-p obj 'LinetypeScale T) 
    (progn 
      (setq cur (vl-catch-all-apply 'vlax-get (list obj 'LinetypeScale)))
      (if 
        (and (numberp cur) 
             (not (equal cur 1.0 1e-8))
             (not 
               (vl-catch-all-error-p 
                 (vl-catch-all-apply 'vlax-put (list obj 'LinetypeScale 1.0))
               )
             )
        )
        (setq res T)
      )
    )
  )
  res
)

;;; --------------------------------------------------------------------------
;;; rlts:fix-attributes
;;;   Traite les attributs d'une reference de bloc (INSERT).
;;;   Retourne le nombre d'attributs modifies.
;;; --------------------------------------------------------------------------
(defun rlts:fix-attributes (obj / atts n) 
  (setq n 0)
  (if 
    (and (member (vla-get-ObjectName obj) '("AcDbBlockReference" "AcDbMInsertBlock")) 
         (= (vla-get-HasAttributes obj) :vlax-true)
    )
    (progn 
      (setq atts (vl-catch-all-apply 'vlax-invoke (list obj 'GetAttributes)))
      (if (listp atts) 
        (foreach a atts 
          (if (rlts:fix-object a) (setq n (1+ n)))
        )
      )
    )
  )
  n
)

;;; --------------------------------------------------------------------------
;;; rlts:process-block
;;;   Parcourt un conteneur (espace objet ou presentation) et traite
;;;   chaque objet. Retourne le nombre d'objets modifies.
;;; --------------------------------------------------------------------------
(defun rlts:process-block (blk / n) 
  (setq n 0)
  (vlax-for obj blk 
    (if (rlts:fix-object obj) (setq n (1+ n)))
    (setq n (+ n (rlts:fix-attributes obj)))
  )
  n
)

;; Reset Linetype Scale
;; Resets the linetype scale of every object in model space and all layouts to 1.0.

(defun c:Dyl-ResetLinetypeScale (/ *error* doc total spaces oldcmd) 

  (defun *error* (msg) 
    (if oldcmd (setvar "CMDECHO" oldcmd))
    (if doc (vla-EndUndoMark doc))
    (if (and msg (not (wcmatch (strcase msg) "*BREAK*,*CANCEL*,*QUIT*"))) 
      (princ (strcat "\nErreur : " msg))
    )
    (princ)
  )

  (setq oldcmd (getvar "CMDECHO"))
  (setvar "CMDECHO" 0)

  (setq doc    (vla-get-ActiveDocument (vlax-get-acad-object))
        total  0
        spaces 0
  )

  (vla-StartUndoMark doc)

  ;; Parcourt uniquement les blocs de presentation (espace objet + onglets),
  ;; en excluant les definitions de blocs ordinaires et les xrefs.
  (vlax-for blk (vla-get-Blocks doc) 
    (if 
      (and (= (vla-get-IsLayout blk) :vlax-true) 
           (= (vla-get-IsXref blk) :vlax-false)
      )
      (progn 
        (setq spaces (1+ spaces))
        (setq total (+ total (rlts:process-block blk)))
      )
    )
  )

  (vla-EndUndoMark doc)
  (setvar "CMDECHO" oldcmd)

  (if (> total 0) (command "_.REGENALL"))

  (princ 
    (strcat "\nLTS1 : " 
            (itoa total)
            " objet(s) remis a une echelle de type de ligne de 1.0 dans "
            (itoa spaces)
            " espace(s)."
    )
  )
  (if (zerop total) 
    (princ "\n      Aucun objet a corriger.")
  )
  (princ)
)

(princ "\nResetLtScale.lsp charge. Tapez Dyl-ResetLinetypeScale pour executer.")
(princ)