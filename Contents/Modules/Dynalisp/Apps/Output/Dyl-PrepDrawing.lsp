;; Dyl-PrepDrawing - Prepares the drawing before output: layers, hidden objects, xrefs, data links, tables, draw order, regen
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

;;  The output prep steps (MAJ:PrepDrawing) run by the commands redefined in
;;  Dyl-CmdOptimizer.lsp, with the steps checked for each one in Dyl-Settings, and
;;  all of them by Dyl-PrepDrawing. The step list (MAJ:steps), PrepSuite.csv, the
;;  redefinition and MAJ:cmd-silent stay in Resources\dynalisp.mnl (PrepBeforeOutput
;;  region): MAJ:PrepLoad loads this file the first time a redefined command needs it.

;;-------------------------=={ Functions }==------------------------;;

;;; ---------------------------------------------------------------------------
;;; Detects whether the drawing contains at least one xref
;;; ---------------------------------------------------------------------------
(defun MAJ:has-xrefs (/ doc res) 
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (vlax-for blk (vla-get-Blocks doc) 
    (if (= (vla-get-IsXref blk) :vlax-true) 
      (setq res T)
    )
  )
  res
)

;;; ---------------------------------------------------------------------------
;;; Counts the data links (datalinks) in the drawing
;;; ---------------------------------------------------------------------------
(defun MAJ:datalink-count (/ dict) 
  (setq dict (dictsearch (namedobjdict) "ACAD_DATALINK"))
  (if dict 
    (length (vl-remove-if-not '(lambda (x) (= (car x) 3)) dict))
    0
  )
)

;;; ---------------------------------------------------------------------------
;;; Capture the active layout tab, view centre, and view height.
;;; If inside a floating viewport, steps out to paper space first so we
;;; record the paper-space view rather than the model-space view inside
;;; the viewport.
;;; ---------------------------------------------------------------------------
(defun MAJ:GetViewState () 
  ;; Exit a floating viewport via sysvar — fires no command event.
  (if (and (= (getvar "TILEMODE") 0) (> (getvar "CVPORT") 1)) 
    (setvar "CVPORT" 1)
  )
  (list (getvar "CTAB") 
        (getvar "VIEWCTR")
        (getvar "VIEWSIZE")
  )
)

;;; ---------------------------------------------------------------------------
;;; Restore a view state produced by MAJ:GetViewState.
;;; ---------------------------------------------------------------------------
(defun MAJ:RestoreViewState (state / acad doc tab ctr ht) 
  (setq tab  (nth 0 state)
        ctr  (nth 1 state)
        ht   (nth 2 state)
        acad (vlax-get-acad-object)
        doc  (vla-get-ActiveDocument acad)
  )
  ;; Switch layout via VLA — no command event fired, TBL:busy is never reset.
  (vlax-for layout (vla-get-Layouts doc) 
    (if (= (strcase (vla-get-Name layout)) (strcase tab)) 
      (vl-catch-all-apply 'vla-put-ActiveLayout (list doc layout))
    )
  )
  ;; Restore view via ZOOM C.  This fires a commandEnded event, but TBL:pending
  ;; is guaranteed empty at this point (TBL:busy was held through the entire
  ;; pre-save zoom loop), so no post-save modification can occur.
  (MAJ:cmd-silent (list "_.ZOOM" "_C" ctr ht))
)

;;; ---------------------------------------------------------------------------
;;; Returns T if the active viewport is already showing the drawing extents
;;; of the current space (within a ±10 % centre tolerance and ±25 % size
;;; tolerance to account for the small margin ZOOM E adds).
;;; Returns T also when the space is empty / extents are invalid so that an
;;; unnecessary zoom is never triggered on a blank layout.
;;; ---------------------------------------------------------------------------
(defun MAJ:IsAtZoomExtents (/ extmin extmax ext-cx ext-cy ext-w ext-h vc vh vw scr) 
  (setq extmin (getvar "EXTMIN")
        extmax (getvar "EXTMAX")
  )
  ;; Invalid extents (empty space): treat as already correct
  (if 
    (or (> (car extmin) (car extmax)) 
        (> (cadr extmin) (cadr extmax))
    )
    T
    (progn 
      (setq ext-cx (/ (+ (car extmin) (car extmax)) 2.0)
            ext-cy (/ (+ (cadr extmin) (cadr extmax)) 2.0)
            ext-w  (- (car extmax) (car extmin))
            ext-h  (- (cadr extmax) (cadr extmin))
            vc     (getvar "VIEWCTR")
            vh     (getvar "VIEWSIZE")
            scr    (getvar "SCREENSIZE")
            vw     (* vh (/ (float (car scr)) (max (float (cadr scr)) 1.0)))
      )
      (and 
        ;; Centre within 10 % of the extents span from the extents centre
        (< (abs (- (car vc) ext-cx)) (* 0.1 (max ext-w 1.0)))
        (< (abs (- (cadr vc) ext-cy)) (* 0.1 (max ext-h 1.0)))
        ;; View must contain the full extents
        (<= ext-w vw)
        (<= ext-h vh)
        ;; View must not be more than 25 % larger than the extents
        (<= vw (* 1.25 (max ext-w 1.0)))
        (<= vh (* 1.25 (max ext-h 1.0)))
      )
    )
  )
)

;;; Entity-count cache for paper-space layouts: ((handle count) ...)
;;; count = number of entities in the layout (ssget "_X" group-code-410).
;;; A count match means no entities were added or deleted → skip switch + zoom.
;;; Loaded from / saved to the drawing's NOD so it persists across sessions.
;;; Written before _.QSAVE so no post-save dirty mark is introduced.
(setq *MAJ:extcache* nil)

;;; Store entity COUNT for HANDLE in the session cache.
(defun MAJ:CacheExtents (handle count / old) 
  (setq old (assoc handle *MAJ:extcache*))
  (setq *MAJ:extcache* (cons (list handle count) 
                             (if old (vl-remove old *MAJ:extcache*) *MAJ:extcache*)
                       )
  )
)

;;; ---------------------------------------------------------------------------
;;; Zoom extents in Model space then in every paper-space layout sorted by
;;; tab order.  A paper-space layout is skipped entirely when its entity count
;;; (ssget group-code 410) matches the cached value — one fast native query
;;; per layout instead of iterating all bounding boxes.
;;; TBL:busy is held active throughout so ZoomExtents does not re-flag tables.
;;; ---------------------------------------------------------------------------
(defun MAJ:ZoomExtentsAllTabs (/ acad doc model-lyt paper-lyts layout hnd tab ss cur-count cached-count) 
  (setq acad       (vlax-get-acad-object)
        doc        (vla-get-ActiveDocument acad)
        model-lyt  nil
        paper-lyts nil
  )
  ;; Reload cache from drawing data — handles session restarts and doc switches.
  (setq *MAJ:extcache* (or (vlax-ldata-get "MAJ:PrepDrawing" "extcache") nil))
  ;; Collect model and paper-space layouts in one pass
  (vlax-for layout (vla-get-Layouts doc) 
    (if (= (strcase (vla-get-Name layout)) "MODEL") 
      (setq model-lyt layout)
      (setq paper-lyts (cons (list (vla-get-TabOrder layout) layout) paper-lyts))
    )
  )
  (setq TBL:busy T)
  ;; --- Model space: always switch and check ---
  (if model-lyt 
    (progn 
      (vl-catch-all-apply 'vla-put-ActiveLayout (list doc model-lyt))
      (if (not (MAJ:IsAtZoomExtents)) 
        (vl-catch-all-apply 'vla-ZoomExtents (list acad))
      )
    )
  )
  ;; --- Paper-space layouts sorted by tab order ---
  (foreach entry (vl-sort paper-lyts '(lambda (a b) (< (car a) (car b)))) 
    (setq layout       (cadr entry)
          hnd          (vla-get-Handle layout)
          tab          (vla-get-Name layout)
          ss           (ssget "_X" (list (cons 410 tab)))
          cur-count    (if ss (sslength ss) 0)
          cached-count (cadr (assoc hnd *MAJ:extcache*))
    )
    (if (and cached-count (= cached-count cur-count)) 
      nil ; entity count unchanged — layout already at zoom extents, skip
      (progn 
        (vl-catch-all-apply 'vla-put-ActiveLayout (list doc layout))
        (vl-catch-all-apply 'vla-ZoomExtents (list acad))
        (MAJ:CacheExtents hnd cur-count)
      )
    )
  )
  ;; Persist cache to drawing NOD — written before _.QSAVE so it is included
  ;; in the save and does not introduce a post-save dirty mark.
  (vlax-ldata-put "MAJ:PrepDrawing" "extcache" *MAJ:extcache*)
  (setq TBL:busy nil)
)

;;; ---------------------------------------------------------------------------
;;; Base drawing preparation — layers, visibility, xrefs, datalinks, tables,
;;; draw order, regen.  Called before every command redefined (save, plot,
;;; publish, preview, regen)
;;; with the steps turned on for it (see MAJ:steps); nothing is run if none.
;;; ---------------------------------------------------------------------------
(defun MAJ:PrepDrawing (steps / echo ss doc n)
  (if steps 
    (progn 
      (setq echo (getvar "CMDECHO"))
      (setvar "CMDECHO" 0)
      (princ "\n[PrepBeforeOutput] Preparing drawing...")

      ;; 1. Turn on and thaw all layers
      (if (member "LAYERS" steps) 
        (MAJ:cmd-silent '("_.-LAYER" "_ON" "*" "_THAW" "*" ""))
      )

      ;; 2. Unhide hidden / isolated objects
      ;;    (UNISOLATEOBJECTS exists since AutoCAD 2011; harmless otherwise)
      (if (member "UNHIDE" steps) 
        (MAJ:cmd-silent '("_.UNISOLATEOBJECTS"))
      )

      ;; 3. Reload all xrefs, only if there are any
      (if (and (member "XREFS" steps) (MAJ:has-xrefs)) 
        (progn 
          (princ "\n[PrepBeforeOutput] Reloading xrefs...")
          (MAJ:cmd-silent '("_.-XREF" "_RELOAD" "*"))
        )
      )

      ;; 4. Update all datalinks, only if there are any.
      ;;    The "all data links" keyword proved unreliable across versions and
      ;;    locales, so instead we pass the Update option followed by a
      ;;    selection set of EVERY table in the drawing (model + layouts).
      ;;    The command therefore never asks for a manual selection.
      (if 
        (and (member "DATALINKS" steps) 
             (> (MAJ:datalink-count) 0)
             (setq ss (ssget "_X" '((0 . "ACAD_TABLE"))))
        )
        (progn 
          (princ "\n[PrepBeforeOutput] Updating data links...")
          (MAJ:cmd-silent (list "_.DATALINKUPDATE" "_U" ss ""))
        )
      )

      ;; 5. Fit the table rows to their text height (see TBL:ShrinkAllTables in dynalisp.mnl)
      (if (and (member "TABLES" steps) TBL:ShrinkAllTables) 
        (progn 
          (princ "\n[PrepBeforeOutput] Fitting table row heights...")
          (TBL:ShrinkAllTables)
        )
      )

      ;; 6. Apply the draw order preset to the whole drawing, while auto draw order
      ;;    is on (Modules\Dynalisp\Remote\Dyl-DrawOrder.lsp), in one undo step.
      ;;    DRAWORDERCLEAN rebuilds it instead: the draw order tables are deleted
      ;;    first, so the entries piled up since the last time are dropped.
      ;;    *do:busy* left on by an error would stop auto draw order.
      (if
        (and (or (member "DRAWORDER" steps) (member "DRAWORDERCLEAN" steps))
             Remote>>Dyl:DrawOrderAuto-p
             (Remote>>Dyl:DrawOrderAuto-p)
        )
        (progn
          (princ (if (member "DRAWORDERCLEAN" steps)
                   "\n[PrepBeforeOutput] Rebuilding the draw order..."
                   "\n[PrepBeforeOutput] Applying the draw order..."
                 )
          )
          (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
          (vla-StartUndoMark doc)
          (setq n (vl-catch-all-apply
                    (if (member "DRAWORDERCLEAN" steps) 'Remote>>Dyl:DrawOrderRebuild 'Remote>>Dyl:DrawOrderApply)
                    '(nil nil)
                  )
          )
          (setq *do:busy* nil)
          (vla-EndUndoMark doc)
          (if (vl-catch-all-error-p n)
            (princ (strcat "\n--> Draw order not applied: " (vl-catch-all-error-message n)))
          )
        )
      )

      ;; 7. Full regeneration
      (if (member "REGEN" steps) 
        (progn 
          (MAJ:cmd-silent '("_.REGENALL"))
        )
      )

      (setvar "CMDECHO" echo)
      (princ "\n[PrepBeforeOutput] Drawing ready.")
    )
  )
  (princ)
)

;;; ---------------------------------------------------------------------------
;;; Extended preparation for save commands (QSAVE / SAVE).
;;; Saves the current view, runs the base prep, then zooms extents in every
;;; layout so that zoom state is baked into the file.
;;; The caller is responsible for restoring the view after the save.
;;; ---------------------------------------------------------------------------
(defun MAJ:PrepDrawingForSave () 
  (setq *MAJ:viewstate (MAJ:GetViewState))
  (MAJ:PrepDrawing (mapcar 'car MAJ:steps))
  (princ "\n[PrepBeforeOutput] Setting zoom extents in all layouts...")
  (MAJ:ZoomExtentsAllTabs)
  (princ)
)

;;-------------------------=={ Commands }==------------------------;;

;; Prep Drawing
;; Runs every output prep step now: layers, hidden objects, xrefs, data links, tables, draw order and regen.
(defun c:Dyl-PrepDrawing ()
  (MAJ:PrepDrawing (mapcar 'car MAJ:steps))
  (princ)
)

(princ)
