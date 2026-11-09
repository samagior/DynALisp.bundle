;; LayerColorToObject - Applies the layer color directly to objects
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
;;; LayerColorToObject.lsp
;;;
;;; Reads the color of each selected object's layer and applies it directly
;;; to the object (replacing ByLayer / ByBlock / any explicit color).
;;;
;;; Color modes:
;;;   AsIs       - Copies the layer color exactly as defined on the layer
;;;                (ACI, true color or color book color).
;;;   Index      - Applies the layer color as an ACI index color. For layers
;;;                using a true color, the closest ACI stored by AutoCAD in
;;;                the layer record (DXF 62) is used.
;;;   TrueColor  - Applies the layer color as an RGB true color. ACI layer
;;;                colors are converted to their RGB equivalent.
;;;   ByLayer    - Reverts the selected objects to the ByLayer color.
;;;
;;; Commands:
;;;   LCOL         - Main command
;;;   LAYCOLTOOBJ  - Alias of LCOL
;;;
;;; Notes:
;;;   - Supports pre-selection (pickfirst).
;;;   - Objects on locked layers are filtered out of the selection.
;;;   - The last chosen mode is remembered for the current session.
;;;   - The whole operation is recorded as a single UNDO step.
;;; ==========================================================================

(vl-load-com)


;;; ==========================================================================
;;; SECTION 1 - GLOBAL SETTINGS
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; Session memory of the last color mode chosen by the user.
;;; Initialized to "AsIs" on first load only.
;;; --------------------------------------------------------------------------
(if (not *lcol:lastMode*)
  (setq *lcol:lastMode* "AsIs")
)


;;; ==========================================================================
;;; SECTION 2 - COLOR UTILITIES
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; lcol:new-color
;;;   Creates a new AcCmColor COM object matching the running AutoCAD
;;;   release (e.g. "AutoCAD.AcCmColor.25").
;;;   Returns : AcCmColor VLA object.
;;; --------------------------------------------------------------------------
(defun lcol:new-color ()
  (vla-GetInterfaceObject
    (vlax-get-acad-object)
    (strcat "AutoCAD.AcCmColor." (substr (getvar "ACADVER") 1 2))
  )
)

;;; --------------------------------------------------------------------------
;;; lcol:rgb-split
;;;   Splits a 24-bit true color integer (DXF 420) into its components.
;;;   Argument : rgbValue - integer (0xRRGGBB).
;;;   Returns  : list (red green blue).
;;; --------------------------------------------------------------------------
(defun lcol:rgb-split (rgbValue)
  (list (logand (lsh rgbValue -16) 255)
        (logand (lsh rgbValue -8)  255)
        (logand rgbValue           255))
)

;;; --------------------------------------------------------------------------
;;; lcol:get-layer-data
;;;   Reads the raw color data of a layer from its table record.
;;;   Argument : layerName - string.
;;;   Returns  : list (aciIndex rgbValue bookName)
;;;              aciIndex : integer 1-255 (absolute value, layer may be off)
;;;              rgbValue : integer (DXF 420) or nil if not a true color
;;;              bookName : string  (DXF 430) or nil if not a book color
;;; --------------------------------------------------------------------------
(defun lcol:get-layer-data (layerName / layerData)
  (setq layerData (entget (tblobjname "LAYER" layerName)))
  (list (abs (cdr (assoc 62 layerData)))
        (cdr (assoc 420 layerData))
        (cdr (assoc 430 layerData)))
)

;;; --------------------------------------------------------------------------
;;; lcol:build-color
;;;   Builds the AcCmColor object to apply for a given layer and mode.
;;;   Arguments : doc       - active document VLA object
;;;               layerName - string
;;;               mode      - "AsIs" | "Index" | "TrueColor" | "ByLayer"
;;;   Returns   : AcCmColor VLA object.
;;; --------------------------------------------------------------------------
(defun lcol:build-color (doc layerName mode / color layerInfo aciIndex rgbValue)
  (cond

    ;; ---- AsIs : copy the layer color object exactly as defined ----------
    ((= mode "AsIs")
     (setq color (vla-get-TrueColor
                   (vla-Item (vla-get-Layers doc) layerName)))
    )

    ;; ---- ByLayer : generic ByLayer color ---------------------------------
    ((= mode "ByLayer")
     (setq color (lcol:new-color))
     (vla-put-ColorMethod color acColorMethodByLayer)
    )

    ;; ---- Index / TrueColor : derived from the layer record ---------------
    (T
     (setq layerInfo (lcol:get-layer-data layerName)
           aciIndex  (car  layerInfo)
           rgbValue  (cadr layerInfo)
           color     (lcol:new-color))

     (if (= mode "Index")

       ;; Index : closest ACI stored by AutoCAD in DXF 62
       (vla-put-ColorIndex color aciIndex)

       ;; TrueColor : use DXF 420 if present, otherwise convert the ACI
       (progn
         (if rgbValue
           (apply 'vla-SetRGB (cons color (lcol:rgb-split rgbValue)))
           (progn
             (vla-put-ColorIndex color aciIndex)
             (vla-SetRGB color
                         (vla-get-Red   color)
                         (vla-get-Green color)
                         (vla-get-Blue  color))
           )
         )
       )
     )
    )
  )
  color
)

;;; --------------------------------------------------------------------------
;;; lcol:get-cached-color
;;;   Returns the color object for a layer, building it only once per layer.
;;;   The cache is an association list (layerName . AcCmColor) passed by
;;;   symbol so it can be updated in place.
;;;   Arguments : doc       - active document VLA object
;;;               layerName - string
;;;               mode      - color mode string
;;;               cacheSym  - quoted symbol holding the cache list
;;;   Returns   : AcCmColor VLA object.
;;; --------------------------------------------------------------------------
(defun lcol:get-cached-color (doc layerName mode cacheSym / key entry color)
  (setq key   (strcase layerName)
        entry (assoc key (eval cacheSym)))
  (if entry
    (cdr entry)
    (progn
      (setq color (lcol:build-color doc layerName mode))
      (set cacheSym (cons (cons key color) (eval cacheSym)))
      color
    )
  )
)

;;; --------------------------------------------------------------------------
;;; lcol:release-cache
;;;   Releases every COM color object stored in the cache.
;;;   Argument : cache - association list (layerName . AcCmColor).
;;; --------------------------------------------------------------------------
(defun lcol:release-cache (cache)
  (foreach entry cache
    (if (and (= (type (cdr entry)) 'VLA-OBJECT)
             (not (vlax-object-released-p (cdr entry))))
      (vlax-release-object (cdr entry))
    )
  )
)


;;; ==========================================================================
;;; SECTION 3 - USER INPUT
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; lcol:get-selection
;;;   Uses the pickfirst set if available, otherwise prompts the user.
;;;   Objects on locked layers are excluded.
;;;   Returns : selection set or nil.
;;; --------------------------------------------------------------------------
(defun lcol:get-selection (/ selSet)
  (setq selSet (ssget "_I"))
  (if selSet
    (sssetfirst nil nil)
    (progn
      (princ "\nSelect objects: ")
      (setq selSet (ssget "_:L"))
    )
  )
  selSet
)

;;; --------------------------------------------------------------------------
;;; lcol:get-mode
;;;   Prompts for the color mode. Enter keeps the last mode used.
;;;   Returns : "AsIs" | "Index" | "TrueColor" | "ByLayer".
;;; --------------------------------------------------------------------------
(defun lcol:get-mode (/ answer)
  (initget "AsIs Index TrueColor ByLayer")
  (setq answer
    (getkword
      (strcat "\nColor mode [AsIs/Index/TrueColor/ByLayer] <"
              *lcol:lastMode* ">: ")))
  (if answer
    (setq *lcol:lastMode* answer)
    *lcol:lastMode*
  )
)


;;; ==========================================================================
;;; SECTION 4 - PROCESSING
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; lcol:process-selection
;;;   Applies the color corresponding to each object's layer.
;;;   Arguments : doc      - active document VLA object
;;;               selSet   - selection set
;;;               mode     - color mode string
;;;               cacheSym - quoted symbol holding the color cache
;;;   Returns   : list (modifiedCount failedCount).
;;; --------------------------------------------------------------------------
(defun lcol:process-selection (doc selSet mode cacheSym
                               / index obj color result modified failed)
  (setq modified 0
        failed   0
        index    (sslength selSet))

  (repeat index
    (setq index (1- index)
          obj   (vlax-ename->vla-object (ssname selSet index))
          color (lcol:get-cached-color doc (vla-get-Layer obj) mode cacheSym)
          result (vl-catch-all-apply 'vla-put-TrueColor (list obj color)))

    (if (vl-catch-all-error-p result)
      (setq failed (1+ failed))
      (setq modified (1+ modified))
    )
  )
  (list modified failed)
)


;;; ==========================================================================
;;; SECTION 5 - COMMANDS
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; C:Dyl-LayerColorToObject
;;;   Main command: select objects, choose a mode, apply the layer color.
;;; --------------------------------------------------------------------------

;; Layer Color To Object
;; Gives the selected objects the color of their layer (as is, index, true color or ByLayer).

(defun c:Dyl-LayerColorToObject (/ *error* doc selSet mode colorCache counts)

  ;; ---- Local error handler: close UNDO group and free COM objects ------
  (defun *error* (msg)
    (if colorCache (lcol:release-cache colorCache))
    (if doc (vla-EndUndoMark doc))
    (if (and msg (not (wcmatch (strcase msg) "*BREAK*,*CANCEL*,*QUIT*")))
      (princ (strcat "\nError: " msg))
    )
    (princ)
  )

  ;; ---- Input -----------------------------------------------------------
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))

  (if (setq selSet (lcol:get-selection))
    (progn
      (setq mode (lcol:get-mode))

      ;; ---- Processing (single UNDO step) --------------------------------
      (vla-StartUndoMark doc)
      (setq counts (lcol:process-selection doc selSet mode 'colorCache))
      (vla-EndUndoMark doc)

      ;; ---- Cleanup ------------------------------------------------------
      (lcol:release-cache colorCache)
      (setq colorCache nil)

      ;; ---- Report -------------------------------------------------------
      (princ (strcat "\nLCOL (" mode "): "
                     (itoa (car counts)) " object(s) modified."))
      (if (> (cadr counts) 0)
        (princ (strcat "\n      " (itoa (cadr counts))
                       " object(s) could not be modified."))
      )
    )
    (princ "\nNothing selected.")
  )
  (princ)
)


;;; ==========================================================================
;;; LOAD MESSAGE
;;; ==========================================================================
(princ "\nLayerColorToObject.lsp loaded. Type Dyl-LayerColorToObject to run.")
(princ)
