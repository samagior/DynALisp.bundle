;;  3 Point Rectangle, Dynamically construct a rectangle defined by three supplied points
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
;;  Author:  Lee Mac, Copyright © 2014  -  www.lee-mac.com
;;
;;----------------------------------------------------------------------;;
;;
;;  Modifications from original:
;;
;;  2023-10 - Initial integration to Dynalisp
;;      - Removed versionning references.
;;      - Removed codes executing on load to prevent overload startup.
;;      - Removed original heading with full description.
;;      - Added licence heading.
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

;; 3-Point Rectangle Help
;; Opens the Lee Mac 3-Point Rectangle help page in the web browser.

(defun c:Pst-ThreePointRectangleHelp () 
  (startapp "explorer" "http://www.lee-mac.com/3pointrectangle.html")
)

;; 3-Point Rectangle Dynamic Help
;; Opens the Lee Mac 3-Point Rectangle help page in the web browser.

(defun c:Pst-ThreePointRectangleDynamicHelp () 
  (startapp "explorer" "http://www.lee-mac.com/3pointrectangle.html")
)

;; 3-Point Rectangle
;; Draws a rectangle defined by three picked points.

(defun c:LM-ThreePointRectangle nil (3p-rec nil)) ;; Standard version

;; 3-Point Rectangle Dynamic
;; Draws a rectangle defined by three picked points with a dynamic preview.

(defun c:Pst-ThreePointRectangleDynamic nil (3p-rec t)) ;; Dynamic version

;;----------------------------------------------------------------------;;

(defun 3p-rec (dyn / *error* gr1 gr2 len lst msg ocs osf osm pt1 pt2 pt3 pt4 pt5 pt6 str tmp vec) 
  (vl-load-com)
  (defun *error* (msg) 
    (LM:endundo (LM:acdoc))
    (if (not (wcmatch (strcase msg t) "*break,*cancel*,*exit*")) 
      (princ (strcat "\nError: " msg))
    )
    (redraw)
    (princ)
  )

  (if 
    (and 
      (setq pt1 (getpoint "\nSpecify 1st point: "))
      (setq pt2 (getpoint "\nSpecify 2nd point: " pt1))
      (or dyn (setq pt3 (getpoint "\nSpecify 3rd point: " pt1)))
      (setq vec (trans (mapcar '- pt2 pt1) 1 0 t)
            ocs (trans '(0.0 0.0 1.0) 1 0 t)
            pt4 (trans pt1 1 vec)
            pt5 (trans pt2 1 vec)
      )
      (if dyn 
        (progn 
          (setq osf (LM:grsnap:snapfunction)
                osm (getvar 'osmode)
                msg "\nSpecify 3rd point: "
                str ""
          )
          (princ msg)
          (while 
            (progn 
              (setq gr1 (grread t 15 0)
                    gr2 (cadr gr1)
                    gr1 (car gr1)
              )
              (cond 
                ((or (= 5 gr1) (= 3 gr1))
                 (redraw)
                 (osf gr2 osm)
                 (setq pt6 (trans gr2 1 vec))
                 (mapcar '(lambda (a b) (grdraw a b 1 1)) 
                         (setq lst (list pt1 
                                         pt2
                                         (trans 
                                           (list (car pt6) 
                                                 (cadr pt6)
                                                 (caddr pt5)
                                           )
                                           vec
                                           1
                                         )
                                         (trans 
                                           (list (car pt6) 
                                                 (cadr pt6)
                                                 (caddr pt4)
                                           )
                                           vec
                                           1
                                         )
                                   )
                         )
                         (cons (last lst) lst)
                 )
                 (= 5 gr1)
                )
                ((= 2 gr1)
                 (cond 
                   ((= 6 gr2)
                    (if 
                      (zerop 
                        (logand 16384 
                                (setq osm (setvar 'osmode 
                                                  (boole 6 
                                                         16384
                                                         (getvar 'osmode)
                                                  )
                                          )
                                )
                        )
                      )
                      (princ "\n<Osnap on>")
                      (princ "\n<Osnap off>")
                    )
                    (princ msg)
                   )
                   ((= 8 gr2)
                    (if (< 0 (strlen str)) 
                      (progn 
                        (princ "\010\040\010")
                        (setq str (substr str 1 (1- (strlen str))))
                      )
                    )
                    t
                   )
                   ((< 32 gr2 127)
                    (setq str (strcat str (princ (chr gr2))))
                   )
                   ((member gr2 '(13 32))
                    (cond 
                      ((= "" str) nil)
                      ((setq gr2 (LM:grsnap:parsepoint pt1 str))
                       (setq osm 16384)
                       nil
                      )
                      ((setq tmp (LM:grsnap:snapmode str))
                       (setq osm tmp
                             str ""
                       )
                      )
                      ((and pt6 
                            (setq len (distof str))
                            (setq pt6 (list (car pt6) (cadr pt6) (caddr pt4)))
                            (not 
                              (equal 0.0 (setq tmp (distance pt4 pt6)) 1e-8)
                            )
                       )
                       (setq gr2 (trans 
                                   (mapcar 
                                     '(lambda (a b) 
                                        (+ b (* len (/ (- a b) tmp)))
                                      )
                                     pt6
                                     pt4
                                   )
                                   vec
                                   1
                                 )
                             osm 16384
                       )
                       nil
                      )
                      ((setq str "")
                       (princ (strcat "\n2D / 3D Point Required." msg))
                      )
                    )
                   )
                 )
                )
              )
            )
          )
          (if (listp gr2) 
            (setq pt6 (trans (osf gr2 osm) 1 vec))
          )
        )
        (setq pt6 (trans pt3 1 vec))
      )
    )
    (progn 
      (LM:startundo (LM:acdoc))
      (entmake 
        (list 
          '(000 . "LWPOLYLINE")
          '(100 . "AcDbEntity")
          '(100 . "AcDbPolyline")
          '(090 . 4)
          '(070 . 1)
          (cons 038 (caddr (trans pt1 1 ocs)))
          (cons 010 (trans pt1 1 ocs))
          (cons 010 (trans pt2 1 ocs))
          (cons 010 (trans (list (car pt6) (cadr pt6) (caddr pt5)) vec ocs))
          (cons 010 (trans (list (car pt6) (cadr pt6) (caddr pt4)) vec ocs))
          (cons 210 ocs)
        )
      )
      (LM:endundo (LM:acdoc))
    )
  )
  (redraw)
  (princ)
)

;; Object Snap for grread: Snap Function  -  Lee Mac
;; Returns: [fun] A function requiring two arguments:
;; p - [lst] UCS Point to be snapped
;; o - [int] Object Snap bit code
;; The returned function returns either the snapped point (displaying an appropriate snap symbol)
;; or the supplied point if the snap failed for the given Object Snap bit code.

(defun LM:grsnap:snapfunction () 
  (eval 
    (list 'lambda 
          '(p o / q)
          (list 'if 
                '(zerop (logand 16384 o))
                (list 'if 
                      '(setq q (cdar 
                                 (vl-sort 
                                   (vl-remove-if 'null 
                                                 (mapcar 
                                                   (function 
                                                     (lambda (a / b) 
                                                       (if 
                                                         (and 
                                                           (= (car a) 
                                                              (logand (car a) o)
                                                           )
                                                           (setq b (osnap p 
                                                                          (cdr a)
                                                                   )
                                                           )
                                                         )
                                                         (list (distance p b) 
                                                               b
                                                               (car a)
                                                         )
                                                       )
                                                     )
                                                   )
                                                   '((0001 . "_end")
                                                     (0002 . "_mid")
                                                     (0004 . "_cen")
                                                     (0008 . "_nod")
                                                     (0016 . "_qua")
                                                     (0032 . "_int")
                                                     (0064 . "_ins")
                                                     (0128 . "_per")
                                                     (0256 . "_tan")
                                                     (0512 . "_nea")
                                                     (2048 . "_app")
                                                     (8192 . "_par")
                                                    )
                                                 )
                                   )
                                   '(lambda (a b) (< (car a) (car b)))
                                 )
                               )
                       )
                      (list 'LM:grsnap:displaysnap 
                            '(car q)
                            (list 'cdr 
                                  (list 'assoc 
                                        '(cadr q)
                                        (list 'quote 
                                              (LM:grsnap:snapsymbols 
                                                (atoi (cond ((getenv "AutoSnapSize")) ("5")))
                                              )
                                        )
                                  )
                            )
                            (LM:OLE->ACI 
                              (if (= 1 (getvar 'cvport)) 
                                (atoi (cond ((getenv "Layout AutoSnap Color")) ("117761")))
                                (atoi (cond ((getenv "Model AutoSnap Color")) ("104193")))
                              )
                            )
                      )
                )
          )
          '(cond ((car q)) (p))
    )
  )
)

;; Object Snap for grread: Display Snap  -  Lee Mac
;; pnt - [lst] UCS point at which to display the symbol
;; lst - [lst] grvecs vector list
;; col - [int] ACI colour for displayed symbol
;; Returns nil

(defun LM:grsnap:displaysnap (pnt lst col / scl) 
  (setq scl (/ (getvar 'viewsize) (cadr (getvar 'screensize)))
        pnt (trans pnt 1 2)
  )
  (grvecs (cons col lst) 
          (list 
            (list scl 0.0 0.0 (car pnt))
            (list 0.0 scl 0.0 (cadr pnt))
            (list 0.0 0.0 scl 0.0)
            '(0.0 0.0 0.0 1.0)
          )
  )
)

;; Object Snap for grread: Snap Symbols  -  Lee Mac
;; p - [int] Size of snap symbol in pixels
;; Returns: [lst] List of vector lists describing each Object Snap symbol

(defun LM:grsnap:snapsymbols (p / -p -q -r a c i l q r) 
  (setq -p (- p)
        q  (1+ p)
        -q (- q)
        r  (+ 2 p)
        -r (- r)
        i  (/ pi 6.0)
        a  0.0
  )
  (repeat 12 
    (setq l (cons (list (* r (cos a)) (* r (sin a))) l)
          a (- a i)
    )
  )
  (setq c (apply 'append (mapcar 'list (cons (last l) l) l)))
  (list 
    (list 1 
          (list -p -p)
          (list p -p)
          (list p -p)
          (list p p)
          (list p p)
          (list -p p)
          (list -p p)
          (list -p -p)
          (list -q -q)
          (list q -q)
          (list q -q)
          (list q q)
          (list q q)
          (list -q q)
          (list -q q)
          (list -q -q)
    )
    (list 2 
          (list -r -q)
          (list 0 r)
          (list 0 r)
          (list r -q)
          (list -p -p)
          (list p -p)
          (list p -p)
          (list 0 p)
          (list 0 p)
          (list -p -p)
          (list -q -q)
          (list q -q)
          (list q -q)
          (list 0 q)
          (list 0 q)
          (list -q -q)
    )
    (cons 4 c)
    (vl-list* 8 (list -r -r) (list r r) (list r -r) (list -r r) c)
    (list 16 
          (list p 0)
          (list 0 p)
          (list 0 p)
          (list -p 0)
          (list -p 0)
          (list 0 -p)
          (list 0 -p)
          (list p 0)
          (list q 0)
          (list 0 q)
          (list 0 q)
          (list -q 0)
          (list -q 0)
          (list 0 -q)
          (list 0 -q)
          (list q 0)
          (list r 0)
          (list 0 r)
          (list 0 r)
          (list -r 0)
          (list -r 0)
          (list 0 -r)
          (list 0 -r)
          (list r 0)
    )
    (list 32 
          (list r r)
          (list -r -r)
          (list r q)
          (list -q -r)
          (list q r)
          (list -r -q)
          (list -r r)
          (list r -r)
          (list -q r)
          (list r -q)
          (list -r q)
          (list q -r)
    )
    (list 64 
          '(0 1)
          (list 0 p)
          (list 0 p)
          (list -p p)
          (list -p p)
          (list -p -1)
          (list -p -1)
          '(0 -1)
          '(0 -1)
          (list 0 -p)
          (list 0 -p)
          (list p -p)
          (list p -p)
          (list p 1)
          (list p 1)
          '(0 1)
          '(1 2)
          (list 1 q)
          (list 1 q)
          (list -q q)
          (list -q q)
          (list -q -2)
          (list -q -2)
          '(-1 -2)
          '(-1 -2)
          (list -1 -q)
          (list -1 -q)
          (list q -q)
          (list q -q)
          (list q 2)
          (list q 2)
          '(1 2)
    )
    (list 128 
          (list (1+ -p) 0)
          '(0 0)
          '(0 0)
          (list 0 (1+ -p))
          (list (1+ -p) 1)
          '(1 1)
          '(1 1)
          (list 1 (1+ -p))
          (list -p q)
          (list -p -p)
          (list -p -p)
          (list q -p)
          (list -q q)
          (list -q -q)
          (list -q -q)
          (list q -q)
    )
    (vl-list* 256 (list -r r) (list r r) (list -r (1+ r)) (list r (1+ r)) c)
    (list 512 
          (list -p -p)
          (list p -p)
          (list -p p)
          (list p p)
          (list -q -q)
          (list q -q)
          (list q -q)
          (list -q q)
          (list -q q)
          (list q q)
          (list q q)
          (list -q -q)
    )
    (list 2048 
          (list -p -p)
          (list p p)
          (list -p p)
          (list p -p)
          (list (+ p 05) -p)
          (list (+ p 06) -p)
          (list (+ p 05) -q)
          (list (+ p 06) -q)
          (list (+ p 09) -p)
          (list (+ p 10) -p)
          (list (+ p 09) -q)
          (list (+ p 10) -q)
          (list (+ p 13) -p)
          (list (+ p 14) -p)
          (list (+ p 13) -q)
          (list (+ p 14) -q)
          (list -p -p)
          (list p -p)
          (list p -p)
          (list p p)
          (list p p)
          (list -p p)
          (list -p p)
          (list -p -p)
          (list -q -q)
          (list q -q)
          (list q -q)
          (list q q)
          (list q q)
          (list -q q)
          (list -q q)
          (list -q -q)
    )
    (list 8192 
          (list r 1)
          (list -r -q)
          (list r 0)
          (list -r -r)
          (list r q)
          (list -r -1)
          (list r r)
          (list -r 0)
    )
  )
)

;; Object Snap for grread: Parse Point  -  Lee Mac
;; bpt - [lst] Basepoint for relative point input, e.g. @5,5
;; str - [str] String representing point input
;; Returns: [lst] Point represented by the given string, else nil

(defun LM:grsnap:parsepoint (bpt str / str->lst lst) 

  (defun str->lst (str / pos) 
    (if (setq pos (vl-string-position 44 str)) 
      (cons (substr str 1 pos) (str->lst (substr str (+ pos 2))))
      (list str)
    )
  )

  (if (wcmatch str "`@*") 
    (setq str (substr str 2))
    (setq bpt '(0.0 0.0 0.0))
  )

  (if 
    (and 
      (setq lst (mapcar 'distof (str->lst str)))
      (vl-every 'numberp lst)
      (< 1 (length lst) 4)
    )
    (mapcar '+ bpt lst)
  )
)

;; Object Snap for grread: Snap Mode  -  Lee Mac
;; str - [str] Object Snap modifier
;; Returns: [int] Object Snap bit code for the given modifier, else nil

(defun LM:grsnap:snapmode (str) 
  (vl-some 
    (function 
      (lambda (x) 
        (if (wcmatch (car x) (strcat (strcase str t) "*")) 
          (progn 
            (princ (cadr x))
            (caddr x)
          )
        )
      )
    )
    '(("endpoint" " of " 00001)
      ("midpoint" " of " 00002)
      ("center" " of " 00004)
      ("node" " of " 00008)
      ("quadrant" " of " 00016)
      ("intersection" " of " 00032)
      ("insert" " of " 00064)
      ("perpendicular" " to " 00128)
      ("tangent" " to " 00256)
      ("nearest" " to " 00512)
      ("appint" " of " 02048)
      ("parallel" " to " 08192)
      ("none" "" 16384)
     )
  )
)

;; OLE -> ACI  -  Lee Mac
;; Args: c - [int] OLE Colour

(defun LM:OLE->ACI (c) 
  (apply 'LM:RGB->ACI (LM:OLE->RGB c))
)

;; OLE -> RGB  -  Lee Mac
;; Args: c - [int] OLE Colour

(defun LM:OLE->RGB (c) 
  (mapcar '(lambda (x) (lsh (lsh (fix c) x) -24)) '(24 16 8))
)

;; RGB -> ACI  -  Lee Mac
;; Args: r,g,b - [int] Red, Green, Blue values

(defun LM:RGB->ACI (r g b / c o) 
  (if 
    (setq o (vla-getinterfaceobject (LM:acapp) 
                                    (strcat "autocad.accmcolor." 
                                            (substr (getvar 'acadver) 1 2)
                                    )
            )
    )
    (progn 
      (setq c (vl-catch-all-apply '(lambda () (vla-setrgb o r g b) (vla-get-colorindex o))))
      (vlax-release-object o)
      (if (vl-catch-all-error-p c) 
        (prompt (strcat "\nError: " (vl-catch-all-error-message c)))
        c
      )
    )
  )
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

;; Application Object  -  Lee Mac
;; Returns the VLA Application Object

(defun LM:acapp nil 
  (eval (list 'defun 'LM:acapp 'nil (vlax-get-acad-object)))
  (LM:acapp)
)

;;----------------------------------------------------------------------;;

;; (vl-load-com)
;; (princ
;;     (strcat
;;         "\n:: 3P-Rec.lsp | Version 1.2 | \\U+00A9 Lee Mac "
;;         ((lambda ( y ) (if (= y (menucmd "m=$(edtime,0,yyyy)")) y (strcat y "-" (menucmd "m=$(edtime,0,yyyy)")))) "2013")
;;         " www.lee-mac.com ::"
;;         "\n:: \"3pr\" - Standard | \"3prd\" - Dynamic ::"
;;     )
;; )
;; (princ)

;;----------------------------------------------------------------------;;
;;                             End of File                              ;;
;;----------------------------------------------------------------------;;