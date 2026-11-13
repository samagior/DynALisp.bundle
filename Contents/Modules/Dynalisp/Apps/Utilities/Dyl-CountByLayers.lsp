;;-------------------=={ Count by Layers }==-------------------;;
;;                                                            ;;
;;  Displays the total length of selected curves, and the     ;;
;;  total area of the closed ones, at the command line,       ;;
;;  grouped by layer, with conversions to meters/feet based   ;;
;;  on INSUNITS. The precision of the drawing-unit values is  ;;
;;  dependent on the setting of the LUPREC system variable.   ;;
;;  Also labels each object with an MText on its layer:       ;;
;;    - open objects: length, aligned above the midpoint      ;;
;;    - closed objects: area and perimeter, centered          ;;
;;  Labels are scaled to fit the object size (cbl:fill).      ;;
;;  Optionally inserts the results as a table or exports      ;;
;;  them to a CSV file.                                       ;;
;;------------------------------------------------------------;;
;;  Based on Total Area by Lee Mac, Copyright © 2013          ;;
;;  www.lee-mac.com                                           ;;
;;------------------------------------------------------------;;

;; Count By Layers
;; Totals the length and area of the selected curves by layer, labels them and exports the results.


(defun c:Dyl-CountByLayers (/ a c d e f i l lst n o p rows s u)
  (if 
    (setq s (ssget 
              '((0 . "LINE,ARC,CIRCLE,ELLIPSE,*POLYLINE,SPLINE")
                (-4 . "<NOT")
                (-4 . "<AND")
                (0 . "POLYLINE")
                (-4 . "&")
                (70 . 80)
                (-4 . "AND>")
                (-4 . "NOT>")
               )
            )
    )
    (progn 
      (setq u (cbl:units)
            d (vla-get-activedocument (vlax-get-acad-object))
      )
      (vla-startundomark d)
      ;; Build list of (layer count length area) and label each object
      (repeat (setq i (sslength s)) 
        (setq e (ssname s (setq i (1- i)))
              l (cdr (assoc 8 (entget e)))
              c (vlax-curve-getdistatparam e (vlax-curve-getendparam e))
              a (if (cbl:closed-p e c) (vlax-curve-getarea e))
        )
        (if (setq n (assoc l lst)) 
          (setq lst (subst 
                      (list l (1+ (cadr n)) (+ c (caddr n)) (+ (cond (a) (0.0)) (cadddr n)))
                      n
                      lst
                    )
          )
          (setq lst (cons (list l 1 c (cond (a) (0.0))) lst))
        )
        (cbl:label e l c a u)
      )
      (vla-endundomark d)
      (setq lst (vl-sort lst '(lambda (x y) (< (strcase (car x)) (strcase (car y)))))
            c   0.0
            a   0.0
      )
      (foreach x lst 
        (setq c (+ c (caddr x))
              a (+ a (cadddr x))
        )
      )
      (setq rows (append 
                   (list 
                     (append 
                       (list "Layer" 
                             "Qty"
                             (if u (strcat "Length (" (cadr u) ")") "Length")
                       )
                       (if u '("m" "ft"))
                       (list (if u (strcat "Area (" (cadr u) "2)") "Area"))
                       (if u '("m2" "ft2"))
                     )
                   )
                   (mapcar '(lambda (x) (cbl:row (car x) (cadr x) (caddr x) (cadddr x) u)) lst)
                   (list (cbl:row "Total" (sslength s) c a u))
                 )
      )
      (princ 
        (if u 
          (strcat "\nDrawing units: " (car u))
          "\nDrawing units: Unitless - set INSUNITS for m/ft conversion."
        )
      )
      (cbl:print rows)
      (initget "Table Csv None")
      (setq o (getkword "\nOutput [Table/Csv/None] <None>: "))
      (cond
        ((= o "Table")
         (graphscr)
         (if (setq p (getpoint "\nTable insertion point: "))
           (cbl:table d
                      (trans p 1 0)
                      (strcat "Count by Layers" (if u (strcat " - Units: " (car u)) ""))
                      rows
           )
         )
        )
        ((= o "Csv")
         (if
           (setq f (getfiled "Export CSV"
                             (strcat (getvar 'dwgprefix)
                                     (vl-filename-base (getvar 'dwgname))
                                     "-CountByLayers"
                             )
                             "csv"
                             1
                   )
           )
           (cbl:csv f rows)
         )
        )
        ((textscr))
      )
    )
  )
  (princ)
)

;; Inserts an AutoCAD table at WCS point pt in the current space, with a title row
;; followed by rows (header first), sized from TEXTSIZE
(defun cbl:table (doc pt title rows / c h r tbl w)
  (setq h   (getvar 'textsize)
        tbl (vla-addtable
              (if (= 1 (getvar 'cvport))
                (vla-get-paperspace doc)
                (vla-get-modelspace doc)
              )
              (vlax-3d-point pt)
              (1+ (length rows))
              (length (car rows))
              (* 2.0 h)
              (* 10.0 h)
            )
  )
  (vla-put-regeneratetablesuppressed tbl :vlax-true)
  (vla-settextheight tbl (+ actitlerow acheaderrow acdatarow) h)
  (vla-setalignment tbl (+ actitlerow acheaderrow acdatarow) acmiddlecenter)
  (vla-settext tbl 0 0 title)
  (setq r 1)
  (foreach row rows
    (setq c 0)
    (foreach x row
      (vla-settext tbl r c x)
      (setq c (1+ c))
    )
    (setq r (1+ r))
  )
  ;; Column widths from the longest entry in each column
  (setq w (mapcar 'strlen (car rows))
        c 0
  )
  (foreach row (cdr rows)
    (setq w (mapcar '(lambda (n x) (max n (strlen x))) w row))
  )
  (foreach n w
    (vla-setcolumnwidth tbl c (* h (+ 2.0 n)))
    (setq c (1+ c))
  )
  (vla-put-regeneratetablesuppressed tbl :vlax-false)
  tbl
)

;; Writes rows to file fn as comma separated values
(defun cbl:csv (fn rows / f)
  (if (setq f (open fn "w"))
    (progn
      (foreach row rows
        (write-line (cbl:csv-line row) f)
      )
      (close f)
      (princ (strcat "\nExported to " fn))
    )
    (princ (strcat "\nUnable to write " fn))
  )
)

;; Joins a row of strings with commas, quoting fields that contain commas
(defun cbl:csv-line (row / s)
  (setq row (mapcar
              '(lambda (x)
                 (if (vl-string-search "," x)
                   (strcat "\"" x "\"")
                   x
                 )
               )
              row
            )
        s   (car row)
  )
  (foreach x (cdr row) (setq s (strcat s "," x)))
  s
)

;; Returns T if curve e (of length len) is closed, either flagged or with coincident ends
(defun cbl:closed-p (e len) 
  (or (vlax-curve-isclosed e) 
      (and (< 0.0 len) 
           (equal (vlax-curve-getstartpoint e) (vlax-curve-getendpoint e) 1e-8)
      )
  )
)

;; Returns (name abbreviation meters-per-unit) for the current INSUNITS, or nil if unitless
(defun cbl:units () 
  (cdr 
    (assoc (getvar 'insunits) 
           '((1 "Inches" "in" 0.0254)
             (2 "Feet" "ft" 0.3048)
             (3 "Miles" "mi" 1609.344)
             (4 "Millimeters" "mm" 0.001)
             (5 "Centimeters" "cm" 0.01)
             (6 "Meters" "m" 1.0)
             (7 "Kilometers" "km" 1000.0)
             (8 "Microinches" "uin" 2.54e-8)
             (9 "Mils" "mil" 2.54e-5)
             (10 "Yards" "yd" 0.9144)
             (11 "Angstroms" "A" 1e-10)
             (12 "Nanometers" "nm" 1e-9)
             (13 "Microns" "um" 1e-6)
             (14 "Decimeters" "dm" 0.1)
             (15 "Decameters" "dam" 10.0)
             (16 "Hectometers" "hm" 100.0)
             (17 "Gigameters" "Gm" 1e9)
             (18 "Astronomical Units" "AU" 1.495978707e11)
             (19 "Light Years" "ly" 9.4607304725808e15)
             (20 "Parsecs" "pc" 3.0856775814914e16)
             (21 "US Survey Feet" "ft" 0.3048006096)
            )
    )
  )
)

;; Returns a table row of strings: layer, qty, length [, m, ft], area [, m2, ft2]
(defun cbl:row (lay qty len area u / m) 
  (append 
    (list lay (itoa qty) (rtos len 2))
    (if u 
      (progn 
        (setq m (* len (caddr u)))
        (list (rtos m 2 2) (rtos (/ m 0.3048) 2 2))
      )
    )
    (list (rtos area 2))
    (if u 
      (progn 
        (setq m (* area (expt (caddr u) 2)))
        (list (rtos m 2 2) (rtos (/ m 0.09290304) 2 2))
      )
    )
  )
)

;; Formats a length (pow 1) or area (pow 2) as "x ft (y m)" for MText,
;; or in drawing units if unitless
(defun cbl:fmt (val u pow / m) 
  (if u 
    (progn 
      (setq m (* val (expt (caddr u) pow)))
      (if (= 1 pow) 
        (strcat (rtos (/ m 0.3048) 2 2) " ft (" (rtos m 2 2) " m)")
        (strcat (rtos (/ m 0.09290304) 2 2) " ft\\U+00B2 (" (rtos m 2 2) " m\\U+00B2)")
      )
    )
    (rtos val 2)
  )
)

;; Fraction of the object size the label is scaled to fill
(setq cbl:fill 0.35)

;; Creates an MText label for curve e on layer lay, scaled to fit the object:
;; closed (area non-nil) - area and perimeter, centered on the bounding box
;; open (area nil)       - length, aligned with the curve just above its midpoint
(defun cbl:label (e lay len area u / ang ext h lines mn mx par pt str txt) 
  (setq lines (if area 
                (list (strcat "Area: " (cbl:fmt area u 2)) (strcat "Length: " (cbl:fmt len u 1)))
                (list (cbl:fmt len u 1))
              )
        str   (car lines)
        ext   (cbl:extents lines)
  )
  (foreach x (cdr lines) (setq str (strcat str "\\P" x)))
  ;; Text height so the label fills cbl:fill of the object size
  (if area 
    (progn 
      (vla-getboundingbox (vlax-ename->vla-object e) 'mn 'mx)
      (setq mn (vlax-safearray->list mn)
            mx (vlax-safearray->list mx)
            pt (mapcar '(lambda (a b) (/ (+ a b) 2.0)) mn mx)
      )
      (if (< 0.0 (car ext)) 
        (setq h (min (/ (* cbl:fill (- (car mx) (car mn))) (car ext)) 
                     (/ (* cbl:fill (- (cadr mx) (cadr mn))) (cadr ext))
                )
        )
      )
    )
    (progn 
      (setq par (vlax-curve-getparamatdist e (/ len 2.0))
            pt  (vlax-curve-getpointatparam e par)
            ang (angle '(0.0 0.0 0.0) (vlax-curve-getfirstderiv e par))
      )
      ;; Keep the text reading left-to-right / bottom-to-top
      (if (< (/ pi 2.0) ang (* 1.5 pi)) (setq ang (+ ang pi)))
      (if (< 0.0 (car ext)) (setq h (/ (* cbl:fill len) (car ext))))
    )
  )
  (if (not (and h (< 0.0 h))) (setq h (getvar 'textsize)))
  ;; Open curves: lift the text off the line by a quarter of its height
  (if (not area) 
    (setq pt (polar pt (+ ang (/ pi 2.0)) (* 0.25 h)))
  )
  (setq txt (vla-addmtext 
              (vlax-ename->vla-object (cdr (assoc 330 (entget e))))
              (vlax-3d-point pt)
              0.0
              str
            )
  )
  (vla-put-layer txt lay)
  (vla-put-height txt h)
  (vla-put-attachmentpoint txt 
                           (if area 
                             acattachmentpointmiddlecenter
                             acattachmentpointbottomcenter
                           )
  )
  (if ang (vla-put-rotation txt ang))
  (vla-put-insertionpoint txt (vlax-3d-point pt))
  txt
)

;; Returns (width height) of MText lines at text height 1.0 in the current text style,
;; measured with textbox (MText codes like \U+00B2 are measured as "2")
(defun cbl:extents (lines / b s w) 
  (setq w 0.0)
  (foreach x lines 
    (setq s x)
    (while (vl-string-search "\\U+00B2" s) 
      (setq s (vl-string-subst "2" "\\U+00B2" s))
    )
    (if 
      (setq b (textbox 
                (list '(0 . "TEXT") (cons 1 s) '(40 . 1.0) (cons 7 (getvar 'textstyle)))
              )
      )
      (setq w (max w (- (car (cadr b)) (car (car b)))))
    )
  )
  ;; Default MText line spacing is 5/3 of the text height
  (list w (+ 1.0 (* (1- (length lines)) (/ 5.0 3.0))))
)

;; Prints rows as a table: header, separator, body, separator, total
(defun cbl:print (rows / sep w) 
  (setq w (mapcar 'strlen (car rows)))
  (foreach r (cdr rows) 
    (setq w (mapcar '(lambda (n c) (max n (strlen c))) w r))
  )
  (setq sep (strcat "\n" 
                    (cbl:pad "" (+ (apply '+ w) (* 2 (1- (length w)))) "-" nil)
            )
  )
  (princ (strcat "\n" (cbl:line (car rows) w)))
  (princ sep)
  (foreach r (cdr (reverse (cdr (reverse rows)))) 
    (princ (strcat "\n" (cbl:line r w)))
  )
  (princ sep)
  (princ (strcat "\n" (cbl:line (last rows) w)))
)

;; Formats a row: first column left-aligned, the rest right-aligned
(defun cbl:line (r w / s) 
  (setq s (cbl:pad (car r) (car w) " " nil))
  (mapcar '(lambda (c n) (setq s (strcat s "  " (cbl:pad c n " " t)))) 
          (cdr r)
          (cdr w)
  )
  s
)

;; Pads string str to width w using character ch, on the left if lft is non-nil
(defun cbl:pad (str w ch lft) 
  (while (< (strlen str) w) 
    (setq str (if lft (strcat ch str) (strcat str ch)))
  )
  str
)
;;; (vl-load-com)
;;; (princ)
