;; ViewportToPaperSpace - Recreates viewport content in paper space
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
;;; VP2PS.lsp  -  Viewport To Paper Space
;;;
;;; Purpose :
;;;   Recreates the model space objects visible through the selected
;;;   viewports directly in the current layout (paper space) at a 1:1
;;;   scale. Each copy is placed exactly where it appeared on the sheet,
;;;   so the sheet layout is preserved. The source viewports are then
;;;   deleted.
;;;
;;; Commands :
;;;   VP2PS   - Run the conversion on the selected viewports.
;;;
;;; Result modes :
;;;   Decouper (Clip)  - Copies are grouped in a block and clipped (XCLIP)
;;;                      with the viewport boundary. The result is visually
;;;                      identical to the viewport. (default)
;;;   Libre (Free)     - Copies are placed as loose objects in paper space.
;;;                      Objects crossing the viewport edge are NOT trimmed.
;;;
;;; What is handled :
;;;   - Any viewport scale, view center and twist angle.
;;;   - Rectangular and non-rectangular (clipped) viewports.
;;;   - Layers that are off, frozen, or frozen in the viewport are skipped.
;;;   - Objects on locked layers are copied normally.
;;;   - PSLTSCALE = 0 : linetype scales are adjusted to keep dash lengths.
;;;   - Dimensions keep their displayed value and their visual size.
;;;
;;; Limitations :
;;;   - Perspective viewports are skipped.
;;;   - 3D (non-plan) views keep their depth : use FLATTEN afterwards.
;;;   - Viewport layer overrides (VP color, linetype...) are not transferred.
;;;   - Annotative objects and multileaders should be checked visually.
;;;   - Copies are no longer associative (dimensions, hatches).
;;;
;;; The whole operation is recorded as a single UNDO group.
;;; ==========================================================================

(vl-load-com)


;;; ==========================================================================
;;; SECTION 1 - GLOBAL SETTINGS
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; Persistent settings (kept for the drawing session)
;;;   *vp2ps:mode*            Last result mode chosen : "Clip" or "Unclipped".
;;;   *vp2ps:arc-segments*    Segments used to approximate one polyline arc
;;;                           of a clipping boundary.
;;;   *vp2ps:curve-segments*  Segments used to approximate a circle, ellipse
;;;                           or spline clipping boundary.
;;;   *vp2ps:block-prefix*    Name prefix of the blocks created in Clip mode.
;;;   *vp2ps:relocked*        Layers temporarily unlocked, to be relocked.
;;; --------------------------------------------------------------------------
(if (not *vp2ps:mode*) (setq *vp2ps:mode* "Clip"))
(setq *vp2ps:arc-segments*   16
      *vp2ps:curve-segments* 128
      *vp2ps:block-prefix*   "VP2PS_"
      *vp2ps:relocked*       nil
)


;;; ==========================================================================
;;; SECTION 2 - MATRIX AND VECTOR HELPERS
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; vp2ps:transpose
;;;   Transposes a matrix given as a list of rows.
;;;   Arguments : matrix - list of rows
;;;   Returns   : transposed matrix
;;; --------------------------------------------------------------------------
(defun vp2ps:transpose (matrix) 
  (apply 'mapcar (cons 'list matrix))
)

;;; --------------------------------------------------------------------------
;;; vp2ps:mxv
;;;   Multiplies a matrix by a vector.
;;;   Arguments : matrix - list of rows
;;;               vector - list of numbers (same length as a row)
;;;   Returns   : resulting vector
;;; --------------------------------------------------------------------------
(defun vp2ps:mxv (matrix vector) 
  (mapcar '(lambda (row) (apply '+ (mapcar '* row vector))) matrix)
)

;;; --------------------------------------------------------------------------
;;; vp2ps:mxm
;;;   Multiplies two matrices (matrix-a x matrix-b).
;;;   Arguments : matrix-a, matrix-b - lists of rows
;;;   Returns   : resulting matrix
;;; --------------------------------------------------------------------------
(defun vp2ps:mxm (matrix-a matrix-b / columns-b) 
  (setq columns-b (vp2ps:transpose matrix-b))
  (mapcar '(lambda (row) (vp2ps:mxv columns-b row)) matrix-a)
)

;;; --------------------------------------------------------------------------
;;; vp2ps:vxs
;;;   Multiplies a vector by a scalar.
;;;   Arguments : vector - list of numbers
;;;               factor - number
;;;   Returns   : scaled vector
;;; --------------------------------------------------------------------------
(defun vp2ps:vxs (vector factor) 
  (mapcar '(lambda (x) (* x factor)) vector)
)

;;; --------------------------------------------------------------------------
;;; vp2ps:transform-point
;;;   Applies a 4x4 transformation matrix to a 2D or 3D point.
;;;   Arguments : matrix - 4x4 matrix (list of 4 rows)
;;;               point  - 2D or 3D point
;;;   Returns   : transformed 3D point
;;; --------------------------------------------------------------------------
(defun vp2ps:transform-point (matrix point / homogeneous) 
  (setq homogeneous (list (car point) 
                          (cadr point)
                          (if (caddr point) (caddr point) 0.0)
                          1.0
                    )
  )
  (reverse (cdr (reverse (vp2ps:mxv matrix homogeneous))))
)


;;; ==========================================================================
;;; SECTION 3 - GEOMETRY AND EXTENTS HELPERS
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; vp2ps:points-extents
;;;   Computes the 2D extents of a list of points.
;;;   Arguments : points - list of 2D or 3D points
;;;   Returns   : ((min-x min-y) (max-x max-y))
;;; --------------------------------------------------------------------------
(defun vp2ps:points-extents (points) 
  (list 
    (list (apply 'min (mapcar 'car points)) 
          (apply 'min (mapcar 'cadr points))
    )
    (list (apply 'max (mapcar 'car points)) 
          (apply 'max (mapcar 'cadr points))
    )
  )
)

;;; --------------------------------------------------------------------------
;;; vp2ps:extents-overlap-p
;;;   Tests whether two 2D extents overlap (touching counts as overlap).
;;;   Arguments : extents-a, extents-b - ((min-x min-y) (max-x max-y))
;;;   Returns   : T if they overlap, nil otherwise
;;; --------------------------------------------------------------------------
(defun vp2ps:extents-overlap-p (extents-a extents-b) 
  (and (<= (car (car extents-a)) (car (cadr extents-b))) 
       (>= (car (cadr extents-a)) (car (car extents-b)))
       (<= (cadr (car extents-a)) (cadr (cadr extents-b)))
       (>= (cadr (cadr extents-a)) (cadr (car extents-b)))
  )
)

;;; --------------------------------------------------------------------------
;;; vp2ps:box-corners
;;;   Returns the 8 corners of a 3D bounding box.
;;;   Arguments : min-point, max-point - opposite corners of the box
;;;   Returns   : list of 8 3D points
;;; --------------------------------------------------------------------------
(defun vp2ps:box-corners (min-point max-point) 
  (mapcar 
    '(lambda (selector) 
       (mapcar '(lambda (flag low high) (if (= flag 0) low high)) 
               selector
               min-point
               max-point
       )
     )
    '((0 0 0) (1 0 0) (0 1 0) (1 1 0) (0 0 1) (1 0 1) (0 1 1) (1 1 1))
  )
)


;;; ==========================================================================
;;; SECTION 4 - VIEWPORT ANALYSIS
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; vp2ps:get-scale
;;;   Returns the viewport scale (paper units per model unit).
;;;   Example : a 1:50 viewport returns 0.02.
;;;   Arguments : vp-data - DXF data of the viewport (entget)
;;;   Returns   : real
;;; --------------------------------------------------------------------------
(defun vp2ps:get-scale (vp-data) 
  (/ 
    (cdr (assoc 41 vp-data)) ; viewport height (paper space)
    (cdr (assoc 45 vp-data))
  ) ; view height (model space)
)

;;; --------------------------------------------------------------------------
;;; vp2ps:perspective-p
;;;   Tests whether the viewport displays a perspective view.
;;;   Arguments : vp-data - DXF data of the viewport
;;;   Returns   : T if perspective, nil otherwise
;;; --------------------------------------------------------------------------
(defun vp2ps:perspective-p (vp-data) 
  (= 1 (logand 1 (cdr (assoc 90 vp-data))))
)

;;; --------------------------------------------------------------------------
;;; vp2ps:plan-view-p
;;;   Tests whether the viewport displays a plan (top) view of the WCS.
;;;   Arguments : vp-data - DXF data of the viewport
;;;   Returns   : T if plan view, nil otherwise
;;; --------------------------------------------------------------------------
(defun vp2ps:plan-view-p (vp-data / direction) 
  (setq direction (cdr (assoc 16 vp-data)))
  (and (equal (car direction) 0.0 1e-10) 
       (equal (cadr direction) 0.0 1e-10)
       (> (caddr direction) 0.0)
  )
)

;;; --------------------------------------------------------------------------
;;; vp2ps:get-transform
;;;   Builds the 4x4 matrix that maps model space (WCS) coordinates to
;;;   paper space coordinates, exactly as the viewport displays them.
;;;
;;;   paper = vp-center + scale * ( Rz(twist) * WCS->OCS * (p - target)
;;;                                 - view-center )
;;;
;;;   Arguments : vp-data - DXF data of the viewport
;;;   Returns   : 4x4 matrix (list of 4 rows)
;;; --------------------------------------------------------------------------
(defun vp2ps:get-transform (vp-data / view-dir target twist scale view-center vp-center wcs-to-ocs twist-rotation linear 
                            offset
                           ) 
  (setq view-dir    (cdr (assoc 16 vp-data)) ; view direction (WCS)
        target      (cdr (assoc 17 vp-data)) ; view target (WCS)
        twist       (cdr (assoc 51 vp-data)) ; view twist angle
        view-center (cdr (assoc 12 vp-data)) ; view center (DCS)
        vp-center   (cdr (assoc 10 vp-data)) ; viewport center (paper)
        scale       (vp2ps:get-scale vp-data)
  )

  ;; Rows = view coordinate system axes expressed in WCS  ->  WCS to OCS
  (setq wcs-to-ocs (list (trans '(1.0 0.0 0.0) view-dir 0 T) 
                         (trans '(0.0 1.0 0.0) view-dir 0 T)
                         (trans '(0.0 0.0 1.0) view-dir 0 T)
                   )
  )

  ;; Rotation around the line of sight (view twist)
  (setq twist-rotation (list (list (cos twist) (- (sin twist)) 0.0) 
                             (list (sin twist) (cos twist) 0.0)
                             '(0.0 0.0 1.0)
                       )
  )

  ;; Linear part : rotation + uniform scale
  (setq linear (mapcar '(lambda (row) (vp2ps:vxs row scale)) 
                       (vp2ps:mxm twist-rotation wcs-to-ocs)
               )
  )

  ;; Translation part
  (setq offset (mapcar '- 
                       (list (- (car vp-center) (* scale (car view-center))) 
                             (- (cadr vp-center) (* scale (cadr view-center)))
                             0.0
                       )
                       (vp2ps:mxv linear target)
               )
  )

  ;; Assemble the 4x4 matrix
  (append (mapcar '(lambda (row delta) (append row (list delta))) linear offset) 
          (list '(0.0 0.0 0.0 1.0))
  )
)

;;; --------------------------------------------------------------------------
;;; vp2ps:rectangle-points
;;;   Returns the 4 corners of a rectangular viewport (paper space).
;;;   Arguments : vp-data - DXF data of the viewport
;;;   Returns   : list of 4 2D points (counter-clockwise)
;;; --------------------------------------------------------------------------
(defun vp2ps:rectangle-points (vp-data / center half-width half-height) 
  (setq center      (cdr (assoc 10 vp-data))
        half-width  (/ (cdr (assoc 40 vp-data)) 2.0)
        half-height (/ (cdr (assoc 41 vp-data)) 2.0)
  )
  (list (list (- (car center) half-width) (- (cadr center) half-height)) 
        (list (+ (car center) half-width) (- (cadr center) half-height))
        (list (+ (car center) half-width) (+ (cadr center) half-height))
        (list (- (car center) half-width) (+ (cadr center) half-height))
  )
)

;;; --------------------------------------------------------------------------
;;; vp2ps:curve-points
;;;   Converts a closed curve (clipping boundary) into a list of points.
;;;   Straight polyline segments keep their vertices; arcs, circles,
;;;   ellipses and splines are approximated by short segments.
;;;   Arguments : curve-ename - entity name of the curve
;;;   Returns   : list of 2D points
;;; --------------------------------------------------------------------------
(defun vp2ps:curve-points (curve-ename / curve-obj start-param end-param points index step bulge) 
  (setq curve-obj   (vlax-ename->vla-object curve-ename)
        start-param (vlax-curve-getStartParam curve-ename)
        end-param   (vlax-curve-getEndParam curve-ename)
  )

  (if (member (vla-get-ObjectName curve-obj) '("AcDbPolyline" "AcDb2dPolyline")) 

    ;; Polyline : one point per straight segment, several per arc segment
    (progn 
      (setq index 0)
      (while (< index (fix (+ end-param 0.5))) 
        (setq bulge (vla-GetBulge curve-obj index))
        (if (equal bulge 0.0 1e-10) 
          (setq points (cons (vlax-curve-getPointAtParam curve-ename index) points))
          (progn 
            (setq step 0)
            (while (< step *vp2ps:arc-segments*) 
              (setq points (cons 
                             (vlax-curve-getPointAtParam 
                               curve-ename
                               (+ index (/ (float step) *vp2ps:arc-segments*))
                             )
                             points
                           )
              )
              (setq step (1+ step))
            )
          )
        )
        (setq index (1+ index))
      )
    )

    ;; Other curves : regular sampling along the curve parameter
    (progn 
      (setq step 0)
      (while (< step *vp2ps:curve-segments*) 
        (setq points (cons 
                       (vlax-curve-getPointAtParam 
                         curve-ename
                         (+ start-param 
                            (* (- end-param start-param) 
                               (/ (float step) *vp2ps:curve-segments*)
                            )
                         )
                       )
                       points
                     )
        )
        (setq step (1+ step))
      )
    )
  )
  (mapcar '(lambda (point) (list (car point) (cadr point))) (reverse points))
)

;;; --------------------------------------------------------------------------
;;; vp2ps:boundary-points
;;;   Returns the visible boundary of a viewport in paper space.
;;;   Uses the clipping object for non-rectangular viewports.
;;;   Arguments : vp-data - DXF data of the viewport
;;;   Returns   : list of 2D points
;;; --------------------------------------------------------------------------
(defun vp2ps:boundary-points (vp-data / clip-ename) 
  (setq clip-ename (cdr (assoc 340 vp-data)))
  (if 
    (and clip-ename 
         (= 65536 (logand 65536 (cdr (assoc 90 vp-data)))) ; non-rect clipping on
         (entget clip-ename)
    )
    (vp2ps:curve-points clip-ename)
    (vp2ps:rectangle-points vp-data)
  )
)

;;; --------------------------------------------------------------------------
;;; vp2ps:vp-frozen-layers
;;;   Lists the layers frozen in the viewport (VP Freeze).
;;;   Arguments : vp-data - DXF data of the viewport
;;;   Returns   : list of upper-case layer names
;;; --------------------------------------------------------------------------
(defun vp2ps:vp-frozen-layers (vp-data) 
  (mapcar '(lambda (pair) (strcase (cdr (assoc 2 (entget (cdr pair)))))) 
          (vl-remove-if-not '(lambda (pair) (= 341 (car pair))) vp-data)
  )
)


;;; ==========================================================================
;;; SECTION 5 - MODEL SPACE OBJECT SELECTION
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; vp2ps:collect-model-objects
;;;   Reads every model space object once and caches its bounding box,
;;;   so that several viewports can be processed without re-reading.
;;;   Arguments : doc - active document (VLA)
;;;   Returns   : list of (object min-point max-point)
;;;               min-point / max-point are nil for unbounded objects
;;;               (XLINE, RAY) or objects without extents.
;;; --------------------------------------------------------------------------
(defun vp2ps:collect-model-objects (doc / result min-point max-point status) 
  (vlax-for obj (vla-get-ModelSpace doc) 
    (setq status (vl-catch-all-apply 'vla-GetBoundingBox 
                                     (list obj 'min-point 'max-point)
                 )
    )
    (setq result (cons 
                   (if (vl-catch-all-error-p status) 
                     (list obj nil nil)
                     (list obj 
                           (vlax-safearray->list min-point)
                           (vlax-safearray->list max-point)
                     )
                   )
                   result
                 )
    )
  )
  (reverse result)
)

;;; --------------------------------------------------------------------------
;;; vp2ps:layer-visible-p
;;;   Tests whether a layer is displayed in a given viewport
;;;   (on, thawed, and not frozen in the viewport).
;;;   Arguments : doc          - active document (VLA)
;;;               layer-name   - layer name
;;;               vp-frozen    - list of layers frozen in the viewport
;;;   Returns   : T if visible, nil otherwise
;;; --------------------------------------------------------------------------
(defun vp2ps:layer-visible-p (doc layer-name vp-frozen / layer) 
  (setq layer (vl-catch-all-apply 'vla-Item (list (vla-get-Layers doc) layer-name)))
  (and (not (vl-catch-all-error-p layer)) 
       (= (vla-get-LayerOn layer) :vlax-true)
       (= (vla-get-Freeze layer) :vlax-false)
       (not (member (strcase layer-name) vp-frozen))
  )
)

;;; --------------------------------------------------------------------------
;;; vp2ps:select-visible-objects
;;;   Selects the cached model space objects that are visible through
;;;   the viewport : visible layer + extents overlapping the boundary.
;;;   Arguments : doc             - active document (VLA)
;;;               cache           - result of vp2ps:collect-model-objects
;;;               matrix          - model to paper 4x4 matrix
;;;               bounds          - paper space extents of the viewport
;;;               vp-frozen       - layers frozen in the viewport
;;;               allow-unbounded - T to include XLINE and RAY objects
;;;   Returns   : list of VLA objects
;;; --------------------------------------------------------------------------
(defun vp2ps:select-visible-objects (doc cache matrix bounds vp-frozen allow-unbounded / result obj paper-extents) 
  (foreach item cache 
    (setq obj (car item))
    (if (vp2ps:layer-visible-p doc (vla-get-Layer obj) vp-frozen) 
      (cond 
        ;; Bounded object : compare its paper space extents
        ((cadr item)
         (setq paper-extents (vp2ps:points-extents 
                               (mapcar '(lambda (corner) (vp2ps:transform-point matrix corner)) 
                                       (vp2ps:box-corners (cadr item) (caddr item))
                               )
                             )
         )
         (if (vp2ps:extents-overlap-p paper-extents bounds) 
           (setq result (cons obj result))
         )
        )

        ;; Unbounded object : only kept when the result will be clipped
        ((and allow-unbounded 
              (member (vla-get-ObjectName obj) '("AcDbXline" "AcDbRay"))
         )
         (setq result (cons obj result))
        )
      )
    )
  )
  (reverse result)
)


;;; ==========================================================================
;;; SECTION 6 - COPY AND POST-PROCESSING
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; vp2ps:get-property
;;;   Safely reads a property of a VLA object.
;;;   Arguments : obj      - VLA object
;;;               property - property name (quoted symbol)
;;;   Returns   : property value, or nil if unavailable
;;; --------------------------------------------------------------------------
(defun vp2ps:get-property (obj property / value) 
  (if (vlax-property-available-p obj property) 
    (progn 
      (setq value (vl-catch-all-apply 'vlax-get (list obj property)))
      (if (vl-catch-all-error-p value) nil value)
    )
  )
)

;;; --------------------------------------------------------------------------
;;; vp2ps:copy-objects
;;;   Copies objects into a target container (block definition or layout).
;;;   Tries one batch copy first; falls back to one-by-one copies if an
;;;   object refuses to be copied.
;;;   Arguments : doc     - active document (VLA)
;;;               objects - list of VLA objects
;;;               owner   - target block / layout block (VLA)
;;;   Returns   : list of the new VLA objects
;;; --------------------------------------------------------------------------
(defun vp2ps:copy-objects (doc objects owner / copies single-copy) 
  (setq copies (vl-catch-all-apply 'vlax-invoke (list doc 'CopyObjects objects owner)))
  (if (vl-catch-all-error-p copies) 
    (progn 
      (setq copies nil)
      (foreach obj objects 
        (setq single-copy (vl-catch-all-apply 'vlax-invoke (list doc 'CopyObjects (list obj) owner)))
        (if (not (vl-catch-all-error-p single-copy)) 
          (setq copies (append copies single-copy))
        )
      )
    )
  )
  copies
)

;;; --------------------------------------------------------------------------
;;; vp2ps:dimension-state
;;;   Records the dimension values needed to restore its appearance after
;;;   scaling.
;;;   Arguments : obj - VLA object
;;;   Returns   : (measurement scale-factor text-height), or nil if the
;;;               object is not a dimension
;;; --------------------------------------------------------------------------
(defun vp2ps:dimension-state (obj) 
  (if (wcmatch (vla-get-ObjectName obj) "AcDb*Dimension*") 
    (list (vp2ps:get-property obj 'Measurement) 
          (vp2ps:get-property obj 'ScaleFactor)
          (vp2ps:get-property obj 'TextHeight)
    )
  )
)

;;; --------------------------------------------------------------------------
;;; vp2ps:restore-dimension
;;;   After scaling, keeps the dimension identical on the sheet :
;;;     - displayed value  : compensated with LinearScaleFactor (DIMLFAC)
;;;     - text/arrow size  : compensated with ScaleFactor (DIMSCALE), only
;;;                          if the transformation did not already do it
;;;   Arguments : obj    - dimension (VLA)
;;;               before - result of vp2ps:dimension-state before scaling
;;;               scale  - viewport scale
;;;   Returns   : nothing meaningful
;;; --------------------------------------------------------------------------
(defun vp2ps:restore-dimension (obj before scale / measure-before factor-before height-before measure-after factor-after 
                                height-after linear-factor
                               ) 
  (setq measure-before (car before)
        factor-before  (cadr before)
        height-before  (caddr before)
        measure-after  (vp2ps:get-property obj 'Measurement)
        factor-after   (vp2ps:get-property obj 'ScaleFactor)
        height-after   (vp2ps:get-property obj 'TextHeight)
  )

  ;; Keep the displayed measurement value
  (if 
    (and measure-before 
         measure-after
         (not (equal measure-after 0.0 1e-12))
         (not (equal measure-before measure-after 1e-9))
         (setq linear-factor (vp2ps:get-property obj 'LinearScaleFactor))
    )
    (vl-catch-all-apply 'vlax-put 
                        (list obj 'LinearScaleFactor (* linear-factor (/ measure-before measure-after)))
    )
  )

  ;; Keep the visual size of text and arrows
  (if 
    (and factor-before 
         factor-after
         height-before
         height-after
         (> factor-before 0.0)
         (equal (* factor-after height-after) (* factor-before height-before) 1e-9)
    )
    (vl-catch-all-apply 'vlax-put (list obj 'ScaleFactor (* factor-after scale)))
  )
)

;;; --------------------------------------------------------------------------
;;; vp2ps:transform-copies
;;;   Moves, rotates and scales the copied objects from model space
;;;   coordinates to their paper space position, then fixes linetype
;;;   scales and dimensions.
;;;   Arguments : copies         - list of VLA objects
;;;               tmatrix        - transformation matrix (vlax-tmatrix)
;;;               scale          - viewport scale
;;;               adjust-ltscale - T when PSLTSCALE = 0
;;;   Returns   : nothing meaningful
;;; --------------------------------------------------------------------------
(defun vp2ps:transform-copies (copies tmatrix scale adjust-ltscale / dim-state current-ltscale) 
  (foreach obj copies 
    (setq dim-state (vp2ps:dimension-state obj))

    ;; Geometric transformation (model -> paper)
    (vl-catch-all-apply 'vla-TransformBy (list obj tmatrix))

    ;; With PSLTSCALE = 0, dashes were scaled by the viewport : keep them
    (if 
      (and adjust-ltscale 
           (setq current-ltscale (vp2ps:get-property obj 'LinetypeScale))
      )
      (vl-catch-all-apply 'vlax-put (list obj 'LinetypeScale (* current-ltscale scale)))
    )

    ;; Dimensions : keep displayed value and visual size
    (if dim-state (vp2ps:restore-dimension obj dim-state scale))
  )
)


;;; ==========================================================================
;;; SECTION 7 - CLIPPING (CLIP MODE)
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; vp2ps:pad-number
;;;   Left-pads an integer with zeros.
;;;   Arguments : number - integer
;;;               width  - minimum number of characters
;;;   Returns   : string (e.g. 7, 3 -> "007")
;;; --------------------------------------------------------------------------
(defun vp2ps:pad-number (number width / text) 
  (setq text (itoa number))
  (while (< (strlen text) width) (setq text (strcat "0" text)))
  text
)

;;; --------------------------------------------------------------------------
;;; vp2ps:unique-block-name
;;;   Returns a block name not yet used in the drawing (VP2PS_001...).
;;;   Arguments : none
;;;   Returns   : string
;;; --------------------------------------------------------------------------
(defun vp2ps:unique-block-name (/ index name) 
  (setq index 1)
  (while 
    (tblsearch "BLOCK" 
               (setq name (strcat *vp2ps:block-prefix* (vp2ps:pad-number index 3)))
    )
    (setq index (1+ index))
  )
  name
)

;;; --------------------------------------------------------------------------
;;; vp2ps:make-temp-polyline
;;;   Creates a closed temporary polyline on layer 0 in the current layout,
;;;   used as the XCLIP boundary.
;;;   Arguments : points - list of 2D points (paper space)
;;;   Returns   : entity name of the polyline
;;; --------------------------------------------------------------------------
(defun vp2ps:make-temp-polyline (points) 
  (entmakex 
    (append 
      (list '(0 . "LWPOLYLINE") 
            '(100 . "AcDbEntity")
            '(8 . "0")
            (cons 410 (getvar "CTAB"))
            '(100 . "AcDbPolyline")
            (cons 90 (length points))
            '(70 . 1)
      )
      (mapcar '(lambda (point) (cons 10 point)) points)
    )
  )
)

;;; --------------------------------------------------------------------------
;;; vp2ps:clip-reference
;;;   Clips a block reference with a boundary (XCLIP), then removes the
;;;   temporary boundary polyline.
;;;   Arguments : block-ref - block reference (VLA)
;;;               points    - boundary points (paper space)
;;;   Returns   : nothing meaningful
;;; --------------------------------------------------------------------------
(defun vp2ps:clip-reference (block-ref points / boundary) 
  (setq boundary (vp2ps:make-temp-polyline points))
  (command "_.XCLIP" (vlax-vla-object->ename block-ref) "" "_New" "_Select" boundary)
  (while (> (getvar "CMDACTIVE") 0) (command ""))
  (if (entget boundary) (entdel boundary))
)

;;; --------------------------------------------------------------------------
;;; vp2ps:build-clipped-result
;;;   Clip mode : copies the objects into a new block definition,
;;;   transforms them, inserts the block at 0,0 in paper space and clips
;;;   it with the viewport boundary.
;;;   Arguments : doc            - active document (VLA)
;;;               paper-space    - current layout block (VLA)
;;;               objects        - model space objects to copy
;;;               tmatrix        - transformation matrix (vlax-tmatrix)
;;;               scale          - viewport scale
;;;               adjust-ltscale - T when PSLTSCALE = 0
;;;               points         - viewport boundary (paper space)
;;;   Returns   : number of objects recreated
;;; --------------------------------------------------------------------------
(defun vp2ps:build-clipped-result (doc paper-space objects tmatrix scale adjust-ltscale points / block-name block-def 
                                   copies block-ref
                                  ) 
  (setq block-name (vp2ps:unique-block-name)
        block-def  (vla-Add (vla-get-Blocks doc) (vlax-3d-point 0.0 0.0 0.0) block-name)
        copies     (vp2ps:copy-objects doc objects block-def)
  )

  (if copies 
    (progn 
      (vp2ps:transform-copies copies tmatrix scale adjust-ltscale)
      (setq block-ref (vla-InsertBlock paper-space 
                                       (vlax-3d-point 0.0 0.0 0.0)
                                       block-name
                                       1.0
                                       1.0
                                       1.0
                                       0.0
                      )
      )
      ;; Layer 0 so that objects on layer 0 keep their own properties
      (vla-put-Layer block-ref "0")
      (vp2ps:clip-reference block-ref points)
    )
    ;; Nothing copied : remove the empty block definition
    (vl-catch-all-apply 'vla-Delete (list block-def))
  )
  (length copies)
)

;;; --------------------------------------------------------------------------
;;; vp2ps:build-unclipped-result
;;;   Free mode : copies the objects directly into paper space and
;;;   transforms them. Objects are not trimmed at the viewport edge.
;;;   Arguments : same as vp2ps:build-clipped-result, without points
;;;   Returns   : number of objects recreated
;;; --------------------------------------------------------------------------
(defun vp2ps:build-unclipped-result (doc paper-space objects tmatrix scale adjust-ltscale / copies) 
  (setq copies (vp2ps:copy-objects doc objects paper-space))
  (vp2ps:transform-copies copies tmatrix scale adjust-ltscale)
  (length copies)
)


;;; ==========================================================================
;;; SECTION 8 - LAYER LOCK MANAGEMENT
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; vp2ps:unlock-layer
;;;   Temporarily unlocks a layer and remembers it for relocking.
;;;   Arguments : doc        - active document (VLA)
;;;               layer-name - layer name
;;;   Returns   : nothing meaningful
;;; --------------------------------------------------------------------------
(defun vp2ps:unlock-layer (doc layer-name / layer) 
  (setq layer (vl-catch-all-apply 'vla-Item (list (vla-get-Layers doc) layer-name)))
  (if 
    (and (not (vl-catch-all-error-p layer)) 
         (= (vla-get-Lock layer) :vlax-true)
    )
    (progn 
      (vla-put-Lock layer :vlax-false)
      (setq *vp2ps:relocked* (cons layer *vp2ps:relocked*))
    )
  )
)

;;; --------------------------------------------------------------------------
;;; vp2ps:relock-layers
;;;   Relocks every layer unlocked by vp2ps:unlock-layer.
;;;   Arguments : none
;;;   Returns   : nothing meaningful
;;; --------------------------------------------------------------------------
(defun vp2ps:relock-layers () 
  (foreach layer *vp2ps:relocked* 
    (vl-catch-all-apply 'vla-put-Lock (list layer :vlax-true))
  )
  (setq *vp2ps:relocked* nil)
)


;;; ==========================================================================
;;; SECTION 9 - VIEWPORT PROCESSING
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; vp2ps:delete-viewport
;;;   Deletes a viewport and its clipping object (if any), unlocking
;;;   their layers when needed.
;;;   Arguments : doc       - active document (VLA)
;;;               vp-ename  - viewport entity name
;;;               vp-data   - DXF data of the viewport
;;;   Returns   : nothing meaningful
;;; --------------------------------------------------------------------------
(defun vp2ps:delete-viewport (doc vp-ename vp-data / clip-ename) 
  (setq clip-ename (cdr (assoc 340 vp-data)))

  (vp2ps:unlock-layer doc (cdr (assoc 8 vp-data)))
  (if (entget vp-ename) (entdel vp-ename))

  (if (and clip-ename (entget clip-ename)) 
    (progn 
      (vp2ps:unlock-layer doc (cdr (assoc 8 (entget clip-ename))))
      (entdel clip-ename)
    )
  )
)

;;; --------------------------------------------------------------------------
;;; vp2ps:format-scale
;;;   Formats a viewport scale for messages (0.02 -> "1:50").
;;;   Arguments : scale - viewport scale
;;;   Returns   : string
;;; --------------------------------------------------------------------------
(defun vp2ps:format-scale (scale) 
  (if (<= scale 1.0) 
    (strcat "1:" (rtos (/ 1.0 scale) 2 4))
    (strcat (rtos scale 2 4) ":1")
  )
)

;;; --------------------------------------------------------------------------
;;; vp2ps:process-viewport
;;;   Converts one viewport : selects the visible model space objects,
;;;   recreates them in paper space, then deletes the viewport.
;;;   Arguments : doc            - active document (VLA)
;;;               paper-space    - current layout block (VLA)
;;;               cache          - cached model space objects
;;;               vp-ename       - viewport entity name
;;;               mode           - "Clip" or "Unclipped"
;;;               adjust-ltscale - T when PSLTSCALE = 0
;;;               number         - viewport number (for messages)
;;;   Returns   : number of objects recreated, or nil if skipped
;;; --------------------------------------------------------------------------
(defun vp2ps:process-viewport (doc paper-space cache vp-ename mode adjust-ltscale number / vp-data scale matrix tmatrix 
                               points bounds vp-frozen objects count
                              ) 
  (setq vp-data (entget vp-ename))

  (if (vp2ps:perspective-p vp-data) 

    ;; Perspective views cannot be reproduced with a linear transformation
    (progn 
      (princ 
        (strcat "\n  Fenetre " 
                (itoa number)
                " : vue en perspective, ignoree (non supprimee)."
        )
      )
      nil
    )

    (progn 
      (if (not (vp2ps:plan-view-p vp-data)) 
        (princ 
          (strcat "\n  Fenetre " 
                  (itoa number)
                  " : vue 3D, les objets gardent leur profondeur (utiliser FLATTEN)."
          )
        )
      )

      ;; Viewport geometry
      (setq scale     (vp2ps:get-scale vp-data)
            matrix    (vp2ps:get-transform vp-data)
            tmatrix   (vlax-tmatrix matrix)
            points    (vp2ps:boundary-points vp-data)
            bounds    (vp2ps:points-extents points)
            vp-frozen (vp2ps:vp-frozen-layers vp-data)
      )

      ;; Objects visible through the viewport
      (setq objects (vp2ps:select-visible-objects 
                      doc
                      cache
                      matrix
                      bounds
                      vp-frozen
                      (= mode "Clip")
                    )
      )

      ;; Recreate them in paper space
      (setq count (cond 
                    ((null objects) 0)
                    ((= mode "Clip")
                     (vp2ps:build-clipped-result doc paper-space objects tmatrix scale adjust-ltscale points)
                    )
                    (T
                     (vp2ps:build-unclipped-result doc paper-space objects tmatrix scale adjust-ltscale)
                    )
                  )
      )

      ;; Remove the source viewport
      (vp2ps:delete-viewport doc vp-ename vp-data)

      (princ 
        (strcat "\n  Fenetre " 
                (itoa number)
                " ("
                (vp2ps:format-scale scale)
                ") : "
                (itoa count)
                " objet(s) recree(s)."
        )
      )
      count
    )
  )
)


;;; ==========================================================================
;;; SECTION 10 - USER INPUT
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; vp2ps:ask-mode
;;;   Asks for the result mode; the last choice is the default.
;;;   Arguments : none
;;;   Returns   : "Clip" or "Unclipped"
;;; --------------------------------------------------------------------------
(defun vp2ps:ask-mode (/ answer default-keyword) 
  (setq default-keyword (if (= *vp2ps:mode* "Clip") "Decouper" "Libre"))
  (initget "Decouper Libre")
  (setq answer (getkword 
                 (strcat "\nMode de resultat [Decouper/Libre] <" 
                         default-keyword
                         ">: "
                 )
               )
  )
  (cond 
    ((= answer "Decouper") (setq *vp2ps:mode* "Clip"))
    ((= answer "Libre") (setq *vp2ps:mode* "Unclipped"))
  )
  *vp2ps:mode*
)

;;; --------------------------------------------------------------------------
;;; vp2ps:select-viewports
;;;   Prompts for viewports of the current layout, excluding the paper
;;;   space overall viewport (ID 1).
;;;   Arguments : none
;;;   Returns   : selection set, or nil
;;; --------------------------------------------------------------------------
(defun vp2ps:select-viewports () 
  (princ "\nSelectionnez les fenetres a convertir : ")
  (ssget 
    (list '(0 . "VIEWPORT") 
          (cons 410 (getvar "CTAB"))
          '(-4 . "<NOT")
          '(69 . 1)
          '(-4 . "NOT>")
    )
  )
)


;;; ==========================================================================
;;; SECTION 11 - MAIN COMMAND
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; C:Dyl-ViewportToPaperSpace
;;;   Main command. Steps :
;;;     1. Check that a layout is active and switch to paper space.
;;;     2. Ask for the result mode and select the viewports.
;;;     3. Cache model space objects once.
;;;     4. Process each viewport (recreate objects + delete viewport).
;;;     5. Restore layer locks and system variables, then report.
;;; --------------------------------------------------------------------------

;; Viewport To Paper Space
;; Recreates the model space objects seen through the selected viewports in paper space, then deletes the viewports.

(defun c:Dyl-ViewportToPaperSpace (/ *error* doc paper-space old-cmdecho undo-open mode selection cache adjust-ltscale index result total 
                processed skipped
               ) 

  ;; ---- Error handler : restore the drawing state -------------------------
  (defun *error* (msg) 
    (vp2ps:relock-layers)
    (if old-cmdecho (setvar "CMDECHO" old-cmdecho))
    (if undo-open (vla-EndUndoMark doc))
    (if (and msg (not (wcmatch (strcase msg) "*BREAK*,*CANCEL*,*QUIT*"))) 
      (princ (strcat "\nErreur : " msg))
    )
    (princ)
  )

  ;; ---- 1. Context validation ----------------------------------------------
  (if (= 1 (getvar "TILEMODE")) 
    (princ "\nVP2PS : lancer la commande depuis un onglet de presentation.")

    (progn 
      (setq doc         (vla-get-ActiveDocument (vlax-get-acad-object))
            old-cmdecho (getvar "CMDECHO")
      )
      (setvar "CMDECHO" 0)
      (if (/= 1 (getvar "CVPORT")) (command "_.PSPACE"))

      ;; ---- 2. User input ----------------------------------------------------
      (setq mode (vp2ps:ask-mode))

      (if (not (setq selection (vp2ps:select-viewports))) 
        (princ "\nAucune fenetre selectionnee.")

        (progn 
          (vla-StartUndoMark doc)
          (setq undo-open T)

          ;; ---- 3. Preparation -----------------------------------------------
          (setq paper-space    (vla-get-Block (vla-get-ActiveLayout doc))
                adjust-ltscale (= 0 (getvar "PSLTSCALE"))
                cache          (vp2ps:collect-model-objects doc)
                total          0
                processed      0
                skipped        0
                index          0
          )

          ;; Layer 0 receives the clipped block and the temporary boundary
          (if (= mode "Clip") (vp2ps:unlock-layer doc "0"))

          ;; ---- 4. Viewport loop ---------------------------------------------
          (while (< index (sslength selection)) 
            (setq result (vp2ps:process-viewport 
                           doc
                           paper-space
                           cache
                           (ssname selection index)
                           mode
                           adjust-ltscale
                           (1+ index)
                         )
            )
            (if result 
              (setq processed (1+ processed)
                    total     (+ total result)
              )
              (setq skipped (1+ skipped))
            )
            (setq index (1+ index))
          )

          ;; ---- 5. Cleanup and report ----------------------------------------
          (vp2ps:relock-layers)
          (vla-EndUndoMark doc)
          (setq undo-open nil)
          (command "_.REGEN")

          (princ 
            (strcat "\nVP2PS : " 
                    (itoa processed)
                    " fenetre(s) convertie(s), "
                    (itoa total)
                    " objet(s) recree(s) a l'echelle 1:1."
            )
          )
          (if (> skipped 0) 
            (princ (strcat "\n        " (itoa skipped) " fenetre(s) ignoree(s)."))
          )
        )
      )
      (setvar "CMDECHO" old-cmdecho)
    )
  )
  (princ)
)


;;; ==========================================================================
;;; LOAD MESSAGE
;;; ==========================================================================
(princ "\nVP2PS.lsp charge. Tapez Dyl-ViewportToPaperSpace pour executer.")
(princ)
