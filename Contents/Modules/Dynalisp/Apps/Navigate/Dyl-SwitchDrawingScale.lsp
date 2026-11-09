;; DylDrawingScale - Keyboard shortcuts to quickly change the drawing scale
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

;;-------------------------=={ Functions }==------------------------;;

;; Parses "N'", "N'-M\"", "A\"", "A/B\"", or "A B/C\"" to decimal inches.
(defun Dyl-ParseFtInches (s / nFtPos nFt sRem nSlashPos nSpacePos) 
  (setq s (vl-string-trim " " s))
  (cond 
    ((setq nFtPos (vl-string-search "'" s))
     (setq nFt  (* 12.0 (atof (substr s 1 nFtPos)))
           sRem (vl-string-trim " -" (substr s (+ nFtPos 2)))
     )
     (if 
       (and (> (strlen sRem) 0) 
            (= (substr sRem (strlen sRem)) "\"")
       )
       (setq sRem (substr sRem 1 (1- (strlen sRem))))
     )
     (+ nFt (if (> (strlen sRem) 0) (atof sRem) 0.0))
    )
    ((and (> (strlen s) 0) 
          (= (substr s (strlen s)) "\"")
     )
     (setq s (substr s 1 (1- (strlen s))))
     (cond 
       ((setq nSpacePos (vl-string-search " " s))
        (setq sRem      (substr s (+ nSpacePos 2))
              nSlashPos (vl-string-search "/" sRem)
        )
        (if nSlashPos 
          (+ (atof (substr s 1 nSpacePos)) 
             (/ 
               (atof (substr sRem 1 nSlashPos))
               (atof (substr sRem (+ nSlashPos 2)))
             )
          )
          (+ (atof (substr s 1 nSpacePos)) (atof sRem))
        )
       )
       ((setq nSlashPos (vl-string-search "/" s))
        (/ 
          (atof (substr s 1 nSlashPos))
          (atof (substr s (+ nSlashPos 2)))
        )
       )
       (t (atof s))
     )
    )
    (t nil)
  )
)

;; Adds a "N:M" or imperial "paper = draw" annotation scale via -SCALELISTEDIT.
(defun Dyl-EnsureAnnoScale (sName / nPos nEqPos nPaper nDraw n1 n2 a b r g) 
  (setq nPos   (vl-string-search ":" sName)
        nEqPos (vl-string-search " = " sName)
  )
  (cond 
    ((and nPos (> nPos 0) (< nPos (1- (strlen sName))))
     (setq nPaper (atof (substr sName 1 nPos))
           nDraw  (atof (substr sName (+ nPos 2)))
     )
    )
    (nEqPos
     (setq nPaper (Dyl-ParseFtInches (substr sName 1 nEqPos))
           nDraw  (Dyl-ParseFtInches (substr sName (+ nEqPos 4)))
     )
    )
  )
  (if (and nPaper nDraw (> nPaper 0) (> nDraw 0)) 
    (progn 
      ;; Multiply by 64 to turn all imperial fractional-inch paper values into
      ;; integers (smallest is 1/64"), then reduce to lowest terms via Euclidean GCD.
      (setq n1 (fix (+ 0.5 (* nPaper 64)))
            n2 (fix (+ 0.5 (* nDraw 64)))
            a  n1
            b  n2
      )
      (while (> b 0) 
        (setq r (rem a b)
              a b
              b r
        )
      )
      (setq g a)
      (vl-catch-all-apply 
        '(lambda () 
           (command "-SCALELISTEDIT" 
                    "A"
                    sName
                    (strcat (itoa (/ n1 g)) ":" (itoa (/ n2 g)))
                    "E"
           )
         )
      )
    )
  )
)

;; Regenerates the active viewport via ActiveX, with NOMUTT on to suppress "Regenerating model."
(defun Dyl-QuietRegen (/ nMutt) 
  (vl-load-com)
  (setq nMutt (getvar "nomutt"))
  (setvar "nomutt" 1)
  (vl-catch-all-apply 
    'vla-Regen
    (list (vla-get-ActiveDocument (vlax-get-acad-object)) acActiveViewport)
  )
  (setvar "nomutt" nMutt)
)

(defun Dyl-SetDrawingScale (/ scale) 
  (vl-load-com)
  (setq scale (if (= 1 (getvar "measurement")) met fti))
  (if (vl-catch-all-error-p (vl-catch-all-apply 'setvar (list "cannoscale" scale))) 
    (progn 
      ;; Scale missing from list: add it, then apply.
      (Dyl-EnsureAnnoScale scale)
      (if (vl-catch-all-error-p (vl-catch-all-apply 'setvar (list "cannoscale" scale))) 
        (princ (strcat "\nCould not apply scale \"" scale "\" — reload the drawing and try again."))
        (progn 
          (princ (strcat "\nScale \"" scale "\" added and applied."))
          (Dyl-QuietRegen)
        )
      )
    )
    (progn 
      ;; Scale already in list: just applied, regen.
      (princ (strcat "\nDrawing scale set to " scale))
      (Dyl-QuietRegen)
    )
  )
  (princ)
)

;;  The scale presets are the child commands Pst-DrawingScale1-<ratio> below,
;;  run by their aliases (1-100...) or through Dyl-SwitchDrawingScale.

;; Ratios of the scale presets defined, sorted: (1 2 5 ...)
(defun Dyl-DrawingScaleList (/ lst)
  (foreach s (atoms-family 1)
    (if (and (wcmatch (strcase s) "C:PST-DRAWINGSCALE1-#*") (eval (read s)))
      (setq lst (cons (atoi (substr s 21)) lst))
    )
  )
  (vl-sort lst '<)
)

;; Join a list of integers with a separator:
(defun Dyl-DrawingScaleJoin (lst sep / str)
  (foreach n lst (setq str (if str (strcat str sep (itoa n)) (itoa n))))
  (cond (str) (""))
)

;; Command symbol of the preset typed as "100", "1:100", "1-100" or "1/100" (nil if none):
(defun Dyl-DrawingScaleCmd (str / sym)
  (if (wcmatch str "1[:/`-]#*") (setq str (substr str 3)))
  (if
    (and (wcmatch str "#*")
         (not (wcmatch str "*[~0-9]*"))
         (setq sym (read (strcat "C:PST-DRAWINGSCALE1-" (itoa (atoi str)))))
         (eval sym)
    )
    sym
  )
)

;;-------------------------=={ Commands }==------------------------;;

;; Switch Drawing Scale
;; Asks for a drawing scale (e.g. 100 or 1:100) and sets it, as its preset commands 1-100, 1-48... do.

(defun c:Dyl-SwitchDrawingScale (/ lst str sym)
  (setq lst (Dyl-DrawingScaleList))
  (princ (strcat "\nCurrent annotation scale: " (getvar "cannoscale")))
  (while
    (= "?" (setq str (vl-string-trim " " (getstring "\nDrawing scale 1:<ratio>, e.g. 100 or 1:100 [?] <keep>: "))))
    (princ (strcat "\nDrawing scales: 1:" (Dyl-DrawingScaleJoin lst ", 1:")))
    (princ "\nIn an imperial drawing, the ratio picks the imperial scale (48 = 1/4\" = 1'-0\").")
  )
  (cond
    ((= "" str) (princ "\nDrawing scale unchanged."))
    ((setq sym (Dyl-DrawingScaleCmd str)) (eval (list sym)))
    ((princ (strcat "\nNo drawing scale \"" str "\". Type ? to list them.")))
  )
  (princ)
)


;#region metric

;; Drawing Scale 1:1
;; Sets the annotation scale to 1:1 in metric drawings or 1 ft = 1 ft in imperial drawings.

(defun c:Pst-DrawingScale1-1 () 
  (setq fti "1'-0\" = 1'-0\""
        meq "1:1"
        met "1:1"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 1:2
;; Sets the annotation scale to 1:2 in metric drawings or 6 in = 1 ft in imperial drawings.

(defun c:Pst-DrawingScale1-2 () 
  (setq fti "6\" = 1'-0\""
        meq "1:2"
        met "1:2"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 1:5
;; Sets the annotation scale to 1:5 in metric drawings or 3 in = 1 ft in imperial drawings.

(defun c:Pst-DrawingScale1-5 () 
  (setq fti "3\" = 1'-0\""
        meq "1:4"
        met "1:5"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 1:10
;; Sets the annotation scale to 1:10 in metric drawings or 1 1/2 in = 1 ft in imperial drawings.

(defun c:Pst-DrawingScale1-10 () 
  (setq fti "1 1/2\" = 1'-0\""
        meq "1:8"
        met "1:10"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 1:20
;; Sets the annotation scale to 1:20 in metric drawings or 3/4 in = 1 ft in imperial drawings.

(defun c:Pst-DrawingScale1-20 () 
  (setq fti "3/4\" = 1'-0\""
        meq "1:16"
        met "1:20"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 1:25
;; Sets the annotation scale to 1:25 in metric drawings or 1/2 in = 1 ft in imperial drawings.

(defun c:Pst-DrawingScale1-25 () 
  (setq fti "1/2\" = 1'-0\""
        meq "1:24"
        met "1:25"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 1:40
;; Sets the annotation scale to 1:40 in metric drawings or 3/8 in = 1 ft in imperial drawings.

(defun c:Pst-DrawingScale1-40 () 
  (setq fti "3/8\" = 1'-0\""
        meq "1:32"
        met "1:40"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 1:50
;; Sets the annotation scale to 1:50 in metric drawings or 1/4 in = 1 ft in imperial drawings.

(defun c:Pst-DrawingScale1-50 () 
  (setq fti "1/4\" = 1'-0\""
        meq "1:48"
        met "1:50"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 1:75
;; Sets the annotation scale to 1:75 in metric drawings or 3/16 in = 1 ft in imperial drawings.

(defun c:Pst-DrawingScale1-75 () 
  (setq fti "3/16\" = 1'-0\""
        meq "1:64"
        met "1:75"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 1:100
;; Sets the annotation scale to 1:100 in metric drawings or 1/8 in = 1 ft in imperial drawings.

(defun c:Pst-DrawingScale1-100 () 
  (setq fti "1/8\" = 1'-0\""
        meq "1:96"
        met "1:100"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 1:125
;; Sets the annotation scale to 1:125 in metric drawings or 3/32 in = 1 ft in imperial drawings.

(defun c:Pst-DrawingScale1-125 () 
  (setq fti "3/32\" = 1'-0\""
        meq "1:128"
        met "1:125"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 1:150
;; Sets the annotation scale to 1:150 in metric drawings or 5/64 in = 1 ft in imperial drawings.

(defun c:Pst-DrawingScale1-150 () 
  (setq fti "5/64\" = 1'-0\""
        meq "1:153.6"
        met "1:150"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 1:200
;; Sets the annotation scale to 1:200 in metric drawings or 1/16 in = 1 ft in imperial drawings.

(defun c:Pst-DrawingScale1-200 () 
  (setq fti "1/16\" = 1'-0\""
        meq "1:192"
        met "1:200"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 1:250
;; Sets the annotation scale to 1:250 in metric drawings or 3/64 in = 1 ft in imperial drawings.

(defun c:Pst-DrawingScale1-250 () 
  (setq fti "3/64\" = 1'-0\""
        meq "1:256"
        met "1:250"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 1:500
;; Sets the annotation scale to 1:500 in metric drawings or 1/32 in = 1 ft in imperial drawings.

(defun c:Pst-DrawingScale1-500 () 
  (setq fti "1/32\" = 1'-0\""
        meq "1:384"
        met "1:500"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 1:750
;; Sets the annotation scale to 1:750 in metric drawings or 1/64 in = 1 ft in imperial drawings.

(defun c:Pst-DrawingScale1-750 () 
  (setq fti "1/64\" = 1'-0\""
        meq "1:768"
        met "1:750"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 1:1000
;; Sets the annotation scale to 1:1000 in metric drawings or 1 in = 80 ft in imperial drawings.

(defun c:Pst-DrawingScale1-1000 () 
  (setq fti "1\" = 80'"
        meq "1:960"
        met "1:1000"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 1:1250
;; Sets the annotation scale to 1:1250 in metric drawings or 1 in = 100 ft in imperial drawings.

(defun c:Pst-DrawingScale1-1250 () 
  (setq fti "1\" = 100'"
        meq "1:1200"
        met "1:1250"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 1:2000
;; Sets the annotation scale to 1:2000 in metric drawings or 1 in = 160 ft in imperial drawings.

(defun c:Pst-DrawingScale1-2000 () 
  (setq fti "1\" = 160'"
        meq "1:1920"
        met "1:2000"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 1:2500
;; Sets the annotation scale to 1:2500 in metric drawings or 1 in = 200 ft in imperial drawings.

(defun c:Pst-DrawingScale1-2500 () 
  (setq fti "1\" = 200'"
        meq "1:2400"
        met "1:2500"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 1:5000
;; Sets the annotation scale to 1:5000 in metric drawings or 1 in = 400 ft in imperial drawings.

(defun c:Pst-DrawingScale1-5000 () 
  (setq fti "1\" = 400'"
        meq "1:4800"
        met "1:5000"
  )
  (Dyl-SetDrawingScale)
)
;#endregion

;#region Imerial

;; Drawing Scale 3 in = 1 ft
;; Sets the annotation scale to 3 in = 1 ft (1:4) in imperial drawings or 1:5 in metric drawings.

(defun c:Pst-DrawingScale1-4 () 
  (setq fti "3\" = 1'-0\""
        meq "1:4"
        met "1:5"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 1 1/2 in = 1 ft
;; Sets the annotation scale to 1 1/2 in = 1 ft (1:8) in imperial drawings or 1:10 in metric drawings.

(defun c:Pst-DrawingScale1-8 () 
  (setq fti "1 1/2\" = 1'-0\""
        meq "1:8"
        met "1:10"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 1 in = 1 ft
;; Sets the annotation scale to 1 in = 1 ft (1:12) in imperial drawings or 1:10 in metric drawings.

(defun c:Pst-DrawingScale1-12 () 
  (setq fti "1\" = 1'-0\""
        meq "1:12"
        met "1:10"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 3/4 in = 1 ft
;; Sets the annotation scale to 3/4 in = 1 ft (1:16) in imperial drawings or 1:20 in metric drawings.

(defun c:Pst-DrawingScale1-16 () 
  (setq fti "3/4\" = 1'-0\""
        meq "1:16"
        met "1:20"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 1/2 in = 1 ft
;; Sets the annotation scale to 1/2 in = 1 ft (1:24) in imperial drawings or 1:25 in metric drawings.

(defun c:Pst-DrawingScale1-24 () 
  (setq fti "1/2\" = 1'-0\""
        meq "1:24"
        met "1:25"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 3/8 in = 1 ft
;; Sets the annotation scale to 3/8 in = 1 ft (1:32) in imperial drawings or 1:40 in metric drawings.

(defun c:Pst-DrawingScale1-32 () 
  (setq fti "3/8\" = 1'-0\""
        meq "1:32"
        met "1:40"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 1/4 in = 1 ft
;; Sets the annotation scale to 1/4 in = 1 ft (1:48) in imperial drawings or 1:50 in metric drawings.

(defun c:Pst-DrawingScale1-48 () 
  (setq fti "1/4\" = 1'-0\""
        meq "1:48"
        met "1:50"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 3/16 in = 1 ft
;; Sets the annotation scale to 3/16 in = 1 ft (1:64) in imperial drawings or 1:75 in metric drawings.

(defun c:Pst-DrawingScale1-64 () 
  (setq fti "3/16\" = 1'-0\""
        meq "1:64"
        met "1:75"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 1/8 in = 1 ft
;; Sets the annotation scale to 1/8 in = 1 ft (1:96) in imperial drawings or 1:100 in metric drawings.

(defun c:Pst-DrawingScale1-96 () 
  (setq fti "1/8\" = 1'-0\""
        meq "1:96"
        met "1:100"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 3/32 in = 1 ft
;; Sets the annotation scale to 3/32 in = 1 ft (1:128) in imperial drawings or 1:125 in metric drawings.

(defun c:Pst-DrawingScale1-128 () 
  (setq fti "3/32\" = 1'-0\""
        meq "1:128"
        met "1:125"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 1/16 in = 1 ft
;; Sets the annotation scale to 1/16 in = 1 ft (1:192) in imperial drawings or 1:200 in metric drawings.

(defun c:Pst-DrawingScale1-192 () 
  (setq fti "1/16\" = 1'-0\""
        meq "1:192"
        met "1:200"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 1/32 in = 1 ft
;; Sets the annotation scale to 1/32 in = 1 ft (1:384) in imperial drawings or 1:500 in metric drawings.

(defun c:Pst-DrawingScale1-384 () 
  (setq fti "1\" = 1'-0\""
        meq "1:384"
        met "1:500"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 1/64 in = 1 ft
;; Sets the annotation scale to 1/64 in = 1 ft (1:768) in imperial drawings or 1:750 in metric drawings.

(defun c:Pst-DrawingScale1-768 () 
  (setq fti "1/64\" = 1'-0\""
        meq "1:768"
        met "1:750"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 1 in = 80 ft
;; Sets the annotation scale to 1 in = 80 ft (1:960) in imperial drawings or 1:1000 in metric drawings.

(defun c:Pst-DrawingScale1-960 () 
  (setq fti "1\" = 80'"
        meq "1:960"
        met "1:1000"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 1 in = 100 ft
;; Sets the annotation scale to 1 in = 100 ft (1:1200) in imperial drawings or 1:1250 in metric drawings.

(defun c:Pst-DrawingScale1-1200 () 
  (setq fti "1\" = 100'"
        meq "1:1200"
        met "1:1250"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 1 in = 160 ft
;; Sets the annotation scale to 1 in = 160 ft (1:1920) in imperial drawings or 1:2000 in metric drawings.

(defun c:Pst-DrawingScale1-1920 () 
  (setq fti "1\" = 160'"
        meq "1:1920"
        met "1:2000"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 1 in = 200 ft
;; Sets the annotation scale to 1 in = 200 ft (1:2400) in imperial drawings or 1:2500 in metric drawings.

(defun c:Pst-DrawingScale1-2400 () 
  (setq fti "1\" = 200'"
        meq "1:2400"
        met "1:2500"
  )
  (Dyl-SetDrawingScale)
)

;; Drawing Scale 1 in = 400 ft
;; Sets the annotation scale to 1 in = 400 ft (1:4800) in imperial drawings or 1:5000 in metric drawings.

(defun c:Pst-DrawingScale1-4800 () 
  (setq fti "1\" = 400'"
        meq "1:4800"
        met "1:5000"
  )
  (Dyl-SetDrawingScale)
)
;#endregion