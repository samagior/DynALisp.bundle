; Written By: Tom Beauford
; Changes all block entities to layer "0" with color, linetype & lineweight ByBlock
(vl-load-com)

;; Fix Blocks ByBlock
;; Moves the entities of the selected block definitions to layer 0 with ByBlock color, linetype and lineweight.

(defun c:Dyl-FixBlocksByBlock (/ SSET intCount ENAM ELST BNAM FLST FIX1) 
  (defun FIX1 (BNAM / BENAM BONAM) 
    (if (not (member BNAM FLST)) 
      (progn 
        (setq FLST  (cons BNAM FLST)
              BENAM (tblobjname "block" BNAM)
        )
        (while (setq BENAM (entnext BENAM)) 
          (if (= (cdr (assoc 0 (entget BENAM))) "INSERT") 
            (fix1 (cdr (assoc 2 (entget BENAM))))
            (progn 
              (setq BONAM (vlax-ename->vla-object BENAM))
              (vl-catch-all-apply 'vla-put-layer (list BONAM "0"))
              (vl-catch-all-apply 'vla-put-color (list BONAM 0))
              (vl-catch-all-apply 'vla-put-linetype (list BONAM "Byblock"))
              (vl-catch-all-apply 'vla-put-Lineweight (list BONAM -2))
              ;                (vl-catch-all-apply 'vla-put-PlotStyleName (list BONAM "Byblock"))
            )
          )
        )
      )
    )
  )
  (setq SSET (ssget (list (cons 0 "INSERT"))))
  (vl-cmdf "undo" "BEgin")
  (repeat (setq intCount (sslength SSET)) 
    (setq intCount (1- intCount)
          ENAM     (ssname SSET intCOunt)
          ELST     (entget ENAM)
          BNAM     (cdr (assoc 2 ELST))
          FLST     nil
    )
    (fix1 BNAM)
  )
  (vl-cmdf "undo" "End")
  (vl-cmdf "_.regen")
  (princ)
)

;; Select All Blocks
;; Selects every block reference in the drawing.

(defun c:Pst-SelectAllBlocks (/ ss)
  (setq ss (ssget "_X" '((0 . "INSERT"))))
  (command "_.PSELECT" ss "")
)