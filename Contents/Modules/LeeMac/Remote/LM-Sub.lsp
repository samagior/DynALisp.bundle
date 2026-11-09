;; LM-Sub - LeeMac remote subfunction
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


;;----------------------------------------------------------------------;;

;#region remote sub
;#region 3-Point Circle & Arc Functions
;;  http://www.lee-mac.com/3pointarccircle.html


;; 3-Point Circle  -  Lee Mac
;; Returns the center (UCS) and radius of the circle defined by three supplied points (UCS).

(defun Remote>>LM:3pcircle (pt1 pt2 pt3 / cen md1 md2 vc1 vc2) 
  (if 
    (setq md1 (mapcar '(lambda (a b) (/ (+ a b) 2.0)) pt1 pt2)
          md2 (mapcar '(lambda (a b) (/ (+ a b) 2.0)) pt2 pt3)
          vc1 (mapcar '- pt2 pt1)
          vc2 (mapcar '- pt3 pt2)
          cen (inters md1 
                      (mapcar '+ md1 (list (- (cadr vc1)) (car vc1) 0))
                      md2
                      (mapcar '+ md2 (list (- (cadr vc2)) (car vc2) 0))
                      nil
              )
    )
    (list cen (distance cen pt1))
  )
)


;; 3-Point Circle (Cartesian)  -  Lee Mac
;; Returns the center (UCS) and radius of the circle defined by three supplied points (UCS).

(defun Remote>>LM:3pcircle-c (pt1 pt2 pt3 / a b c d) 
  (setq pt2 (mapcar '- pt2 pt1)
        pt3 (mapcar '- pt3 pt1)
        a   (* 2.0 (- (* (car pt2) (cadr pt3)) (* (cadr pt2) (car pt3))))
        b   (distance '(0.0 0.0) pt2)
        c   (distance '(0.0 0.0) pt3)
        b   (* b b)
        c   (* c c)
  )
  (if (not (equal 0.0 a 1e-8)) 
    (list 
      (setq d (mapcar '+ 
                      pt1
                      (list 
                        (/ (- (* (cadr pt3) b) (* (cadr pt2) c)) a)
                        (/ (- (* (car pt2) c) (* (car pt3) b)) a)
                        0.0
                      )
              )
      )
      (distance d pt1)
    )
  )
)


;#endregion
;#region 5 Point Ellipse
;;  http://www.lee-mac.com/5pointellipse.html


;; 5-Point Ellipse  -  Lee Mac
;; Args: p1,p2,p3,p4,p5 - UCS points defining Ellipse
;; Returns a list of: ((10 <WCS Center>) (11 <WCS Major Axis Endpoint from Center>) (40 . <Minor/Major Ratio>))

(defun Remote>>LM:5P-Ellipse (p1 p2 p3 p4 p5 / a av b c cf cx cy d e f i m1 m2 rl v x) 
  (setq m1 (Remote>>LM:trp 
             (mapcar 
               (function 
                 (lambda (p) 
                   (list 
                     (* (car p) (car p))
                     (* (car p) (cadr p))
                     (* (cadr p) (cadr p))
                     (car p)
                     (cadr p)
                     1.0
                   )
                 )
               )
               (list p1 p2 p3 p4 p5)
             )
           )
  )
  (setq i -1.0)
  (repeat 6 
    (setq cf (cons (* (setq i (- i)) (Remote>>LM:detm (Remote>>LM:trp (append (reverse m2) (cdr m1))))) cf)
          m2 (cons (car m1) m2)
          m1 (cdr m1)
    )
  )
  (mapcar 'set '(f e d c b a) cf) ;; Coefficients of Conic equation ax^2 + bxy + cy^2 + dx + ey + f = 0
  (if (< 0 (setq x (- (* 4.0 a c) (* b b)))) 
    (progn 
      (if (equal 0.0 b 1e-8)  ;; Ellipse parallel to coordinate axes
        (setq av '((1.0 0.0) (0.0 1.0))) ;; Axis vectors
        (setq av (mapcar 
                   (function 
                     (lambda (v / d) 
                       (setq v (list (/ b 2.0) (- v a)) ;; Eigenvectors
                             d (distance '(0.0 0.0) v)
                       )
                       (mapcar '/ v (list d d))
                     )
                   )
                   (Remote>>LM:quad 1.0 (- (+ a c)) (- (* a c) (* 0.25 b b))) ;; Eigenvalues
                 )
        )
      )
      (setq cx (/ (- (* b e) (* 2.0 c d)) x) ;; Ellipse Center
            cy (/ (- (* b d) (* 2.0 a e)) x)
      )
      ;; For radii, solve intersection of axis vectors with Conic Equation:
      ;; ax^2 + bxy + cy^2 + dx + ey + f = 0  }
      ;; x = cx + vx(t)                       }- solve for t
      ;; y = cy + vy(t)                       }
      (setq rl (mapcar 
                 (function 
                   (lambda (v / vv vx vy) 
                     (setq vv (mapcar '* v v)
                           vx (car v)
                           vy (cadr v)
                     )
                     (apply 'max 
                            (quad 
                              (+ (* a (car vv)) (* b vx vy) (* c (cadr vv)))
                              (+ (* 2.0 a cx vx) 
                                 (* b (+ (* cx vy) (* cy vx)))
                                 (* c 2.0 cy vy)
                                 (* d vx)
                                 (* e vy)
                              )
                              (+ (* a cx cx) 
                                 (* b cx cy)
                                 (* c cy cy)
                                 (* d cx)
                                 (* e cy)
                                 f
                              )
                            )
                     )
                   )
                 )
                 av
               )
      )
      (if (apply '> rl) 
        (setq rl (reverse rl)
              av (reverse av)
        )
      )
      (list 
        (cons 10 (trans (list cx cy) 1 0)) ;; WCS Ellipse Center
        (cons 11 (trans (mapcar '(lambda (v) (* v (cadr rl))) (cadr av)) 1 0)) ;; WCS Major Axis Endpoint from Center
        (cons 40 (apply '/ rl)) ;; minor/major ratio
      )
    )
  )
)


;#endregion
;#region Active Space
;;  http://www.lee-mac.com/activespace.html


;; Active Space  -  Lee Mac
;; Retrieves pointers to the Active Document and Space.
;; *doc - quoted symbol (other than *doc)
;; *spc - quoted symbol (other than *spc)

(defun Remote>>LM:activespace (*doc *spc) 
  (set *doc (vla-get-activedocument (vlax-get-acad-object)))
  (set *spc (vlax-get-property (eval *doc) (if (= 1 (getvar 'cvport)) 'paperspace 'modelspace)))
  nil
)


;#endregion
;#region Add & Remove Support File Search Paths
;;  http://www.lee-mac.com/addremovesupportpaths.html


;; Add Support File Search Paths  -  Lee Mac
;; Adds a list of Support File Search Paths, excluding duplicates and invalid paths.
;; lst - [lst] list of paths to add, e.g. '("C:\\Folder1" "C:\\Folder2" ... )
;; Returns: [str] "ACAD" Environment String following modification

(defun Remote>>LM:sfsp+ (lst) 
  ((lambda (str lst) 
     (if 
       (setq lst (vl-remove-if 
                   '(lambda (x) 
                      (or (vl-string-search (strcase x) (strcase str)) 
                          (not (findfile x))
                      )
                    )
                   lst
                 )
       )
       (setenv "ACAD" 
               (strcat str ";" (apply 'strcat (mapcar '(lambda (x) (strcat x ";")) lst)))
       )
     )
   ) 
    (vl-string-right-trim ";" (getenv "ACAD"))
    (mapcar '(lambda (x) (vl-string-right-trim "\\" (vl-string-translate "/" "\\" x))) lst)
  )
)


;;  Add Support File Search Paths at 'n'  -  Lee Mac
;;  Adds a list of Support File Search Paths, excluding duplicates and invalid paths.
;;  lst - [lst] list of paths to add, e.g. '("C:\\Folder1" "C:\\Folder2" ... )
;;  idx - [int] [optional] zero-based index at which to add new paths
;;  Returns: [str] "ACAD" Environment String following modification

(defun Remote>>LM:sfsp+n (lst idx / add) 

  (defun add (str new idx / pos) 
    (if (< 0 idx) 
      (if (setq pos (vl-string-position 59 str)) 
        (strcat (substr str 1 (1+ pos)) (add (substr str (+ pos 2)) new (1- idx)))
        (strcat ";" new)
      )
      (strcat new str ";")
    )
  )
  ((lambda (str lst) 
     (if 
       (setq lst (vl-remove-if 
                   '(lambda (x) 
                      (or (vl-string-search (strcase x) (strcase str)) 
                          (not (findfile x))
                      )
                    )
                   lst
                 )
       )
       (setenv "ACAD" 
               (add str (apply 'strcat (mapcar '(lambda (x) (strcat x ";")) lst)) idx)
       )
     )
   ) 
    (vl-string-right-trim ";" (getenv "ACAD"))
    (mapcar '(lambda (x) (vl-string-right-trim "\\" (vl-string-translate "/" "\\" x))) lst)
  )
)


;; Remove Support File Search Paths  -  Lee Mac
;; Removes a list of Support File Search Paths if present.
;; lst - [lst] list of paths to remove (case-insensitive), e.g. '("C:\\Folder1" "C:\\Folder2" ... )
;; Returns: [str] "ACAD" Environment String following modification

(defun Remote>>LM:sfsp- (lst / pos str tmp) 
  (setq str (strcat (vl-string-right-trim ";" (getenv "ACAD")) ";")
        tmp str
  )
  (foreach pth lst 
    (if (/= "" pth) 
      (while (setq pos (vl-string-search (strcase (strcat pth ";")) (strcase str))) 
        (setq str (strcat (substr str 1 pos) (substr str (+ pos (strlen pth) 2))))
      )
    )
  )
  (if (/= tmp str) (setenv "ACAD" str))
)


;; Wildcard Remove Support File Search Paths  -  Lee Mac
;; Removes all Support File Search Paths matching a supplied wildcard pattern.
;; pat - [str] Wildcard pattern (case-insensitive)
;; Returns: [str] "ACAD" Environment String following modification, else nil if unchanged

(defun Remote>>LM:wcsfsp- (pat / wcsfsp- str tmp) 

  (defun wcsfsp- (str pat / pos) 
    (cond 
      ((or (= "" str) (not (setq pos (vl-string-position 59 str))))
       str
      )
      ((wcmatch (strcase (substr str 1 pos)) (strcase pat))
       (wcsfsp- (substr str (+ pos 2)) pat)
      )
      ((strcat (substr str 1 (+ 1 pos)) (wcsfsp- (substr str (+ pos 2)) pat)))
    )
  )

  (setq tmp (strcat (vl-string-right-trim ";" (getenv "ACAD")) ";")
        str (wcsfsp- tmp pat)
  )
  (if (/= tmp str) (setenv "ACAD" str))
)


;#endregion
;#region Apply to Block Objects


;; Apply to Block Objects  -  Lee Mac
;; Evaluates a supplied function on all objects in a block definition.
;; Arguments:
;; blks - VLA Block Collection in which block resides
;; name - Block name
;; func - function to apply to all objects in block
;; Returns a list of results of evaluating the function, else nil.

(defun Remote>>LM:ApplytoBlockObjects (blks name func / def result) 
  (setq func (eval func))
  (if (not (vl-catch-all-error-p (setq def (vl-catch-all-apply 'vla-item (list blks name))))) 
    (vlax-for obj def (setq result (cons (func obj) result)))
  )
  (reverse result)
)


;#endregion
;#region Assoc++ Functions
;;  http://www.lee-mac.com/assocplusplus.html


;; Assoc++  -  Lee Mac
;; Increments the value of a key in an association list if present, else adds key to the list.
;; key - [any] Key of an element in the list
;; lst - [lst] Association list (may be nil)

(defun Remote>>LM:assoc++ (key lst / itm) 
  (if (setq itm (assoc key lst)) 
    (subst (cons key (1+ (cdr itm))) itm lst)
    (cons (cons key 1) lst)
  )
)


;; Nested Assoc++  -  Lee Mac
;; Increments the value of a key in an association list with possible nested structure,
;; or adds the set of keys to the list if not present.
;; key - [lst] List of keys & subkeys
;; lst - [lst] Association list (may be nil)

(defun Remote>>LM:nassoc++ (key lst / itm) 
  (if key 
    (if (setq itm (assoc (car key) lst)) 
      (subst (cons (car key) (Remote>>LM:nassoc++ (cdr key) (cdr itm))) itm lst)
      (cons (cons (car key) (Remote>>LM:nassoc++ (cdr key) nil)) lst)
    )
    (if lst (list (1+ (car lst))) '(1))
  )
)


;#endregion
;#region Attribute Functions
;;  http://www.lee-mac.com/attributefunctions.html


;; Get Attribute Value  -  Lee Mac
;; Returns the value held by the specified tag within the supplied block, if present.
;; blk - [vla] VLA Block Reference Object
;; tag - [str] Attribute TagString
;; Returns: [str] Attribute value, else nil if tag is not found.

(defun Remote>>LM:vl-getattributevalue (blk tag) 
  (setq tag (strcase tag))
  (vl-some 
    '(lambda (att) (if (= tag (strcase (vla-get-tagstring att))) (vla-get-textstring att)))
    (vlax-invoke blk 'getattributes)
  )
)


;; Set Attribute Value  -  Lee Mac
;; Sets the value of the first attribute with the given tag found within the block, if present.
;; blk - [vla] VLA Block Reference Object
;; tag - [str] Attribute TagString
;; val - [str] Attribute Value
;; Returns: [str] Attribute value if successful, else nil.

(defun Remote>>LM:vl-setattributevalue (blk tag val) 
  (setq tag (strcase tag))
  (vl-some 
    '(lambda (att) 
       (if (= tag (strcase (vla-get-tagstring att))) 
         (progn (vla-put-textstring att val) val)
       )
     )
    (vlax-invoke blk 'getattributes)
  )
)


;; Get Attribute Values  -  Lee Mac
;; Returns an association list of attributes present in the supplied block.
;; blk - [vla] VLA Block Reference Object
;; Returns: [lst] Association list of ((<tag> . <value>) ... )

(defun Remote>>LM:vl-getattributevalues (blk) 
  (mapcar '(lambda (att) (cons (vla-get-tagstring att) (vla-get-textstring att))) 
          (vlax-invoke blk 'getattributes)
  )
)


;; Set Attribute Values  -  Lee Mac
;; Sets attributes with tags found in the association list to their associated values.
;; blk - [vla] VLA Block Reference Object
;; lst - [lst] Association list of ((<tag> . <value>) ... )
;; Returns: nil

(defun Remote>>LM:vl-setattributevalues (blk lst / itm) 
  (foreach att (vlax-invoke blk 'getattributes) 
    (if (setq itm (assoc (vla-get-tagstring att) lst)) 
      (vla-put-textstring att (cdr itm))
    )
  )
)


;; Get Attribute Value  -  Lee Mac
;; Returns the value held by the specified tag within the supplied block, if present.
;; blk - [ent] Block (Insert) Entity Name
;; tag - [str] Attribute TagString
;; Returns: [str] Attribute value, else nil if tag is not found.

(defun Remote>>LM:getattributevalue-r (blk tag / enx) 
  (if (and (setq blk (entnext blk)) (= "ATTRIB" (cdr (assoc 0 (setq enx (entget blk)))))) 
    (if (= (strcase tag) (strcase (cdr (assoc 2 enx)))) 
      (cdr (assoc 1 (reverse enx)))
      (Remote>>LM:getattributevalue-r blk tag)
    )
  )
)


;; Get Attribute Value  -  Lee Mac
;; Returns the value held by the specified tag within the supplied block, if present.
;; blk - [ent] Block (Insert) Entity Name
;; tag - [str] Attribute TagString
;; Returns: [str] Attribute value, else nil if tag is not found.

(defun Remote>>LM:getattributevalue (blk tag / val enx) 
  (while 
    (and 
      (null val)
      (setq blk (entnext blk))
      (= "ATTRIB" (cdr (assoc 0 (setq enx (entget blk)))))
    )
    (if (= (strcase tag) (strcase (cdr (assoc 2 enx)))) 
      (setq val (cdr (assoc 1 (reverse enx))))
    )
  )
)


;; Set Attribute Value (recursive)  -  Lee Mac
;; Sets the value of the first attribute with the given tag found within the block, if present.
;; blk - [ent] Block (Insert) Entity Name
;; tag - [str] Attribute TagString
;; val - [str] Attribute Value
;; Returns: [str] Attribute value if successful, else nil.

(defun Remote>>LM:setattributevalue-r (blk tag val / enx) 
  (if (and (setq blk (entnext blk)) (= "ATTRIB" (cdr (assoc 0 (setq enx (entget blk)))))) 
    (if (= (strcase tag) (strcase (cdr (assoc 2 enx)))) 
      (if (entmod (subst (cons 1 val) (assoc 1 (reverse enx)) enx)) 
        (progn 
          (entupd blk)
          val
        )
      )
      (Remote>>LM:setattributevalue-r blk tag val)
    )
  )
)


;; Set Attribute Value  -  Lee Mac
;; Sets the value of the first attribute with the given tag found within the block, if present.
;; blk - [ent] Block (Insert) Entity Name
;; tag - [str] Attribute TagString
;; val - [str] Attribute Value
;; Returns: [str] Attribute value if successful, else nil.

(defun Remote>>LM:setattributevalue (blk tag val / end enx) 
  (while 
    (and 
      (null end)
      (setq blk (entnext blk))
      (= "ATTRIB" (cdr (assoc 0 (setq enx (entget blk)))))
    )
    (if (= (strcase tag) (strcase (cdr (assoc 2 enx)))) 
      (if (entmod (subst (cons 1 val) (assoc 1 (reverse enx)) enx)) 
        (progn 
          (entupd blk)
          (setq end val)
        )
      )
    )
  )
)


;; Get Attribute Values (recursive)  -  Lee Mac
;; Returns an association list of attributes present in the supplied block.
;; blk - [ent] Block (Insert) Entity Name
;; Returns: [lst] Association list of ((<tag> . <value>) ... )

(defun Remote>>LM:getattributevalues-r (blk / enx) 
  (if (and (setq blk (entnext blk)) (= "ATTRIB" (cdr (assoc 0 (setq enx (entget blk)))))) 
    (cons 
      (cons 
        (cdr (assoc 2 enx))
        (cdr (assoc 1 (reverse enx)))
      )
      (Remote>>LM:getattributevalues-r blk)
    )
  )
)


;; Get Attribute Values  -  Lee Mac
;; Returns an association list of attributes present in the supplied block.
;; blk - [ent] Block (Insert) Entity Name
;; Returns: [lst] Association list of ((<tag> . <value>) ... )

(defun Remote>>LM:getattributevalues (blk / enx lst) 
  (while (and (setq blk (entnext blk)) (= "ATTRIB" (cdr (assoc 0 (setq enx (entget blk)))))) 
    (setq lst (cons 
                (cons 
                  (cdr (assoc 2 enx))
                  (cdr (assoc 1 (reverse enx)))
                )
                lst
              )
    )
  )
  (reverse lst)
)


;; Set Attribute Values (recusrsive) -  Lee Mac
;; Sets attributes with tags found in the association list to their associated values.
;; blk - [ent] Block (Insert) Entity Name
;; lst - [lst] Association list of ((<tag> . <value>) ... )
;; Returns: nil

(defun Remote>>LM:setattributevalues-r (blk lst / enx itm) 
  (if (and (setq blk (entnext blk)) (= "ATTRIB" (cdr (assoc 0 (setq enx (entget blk)))))) 
    (if (setq itm (assoc (cdr (assoc 2 enx)) lst)) 
      (progn 
        (if (entmod (subst (cons 1 (cdr itm)) (assoc 1 (reverse enx)) enx)) 
          (entupd blk)
        )
        (Remote>>LM:setattributevalues-r blk lst)
      )
      (Remote>>LM:setattributevalues-r blk lst)
    )
  )
)


;; Set Attribute Values  -  Lee Mac
;; Sets attributes with tags found in the association list to their associated values.
;; blk - [ent] Block (Insert) Entity Name
;; lst - [lst] Association list of ((<tag> . <value>) ... )
;; Returns: nil

(defun Remote>>LM:setattributevalues (blk lst / enx itm) 
  (while (and (setq blk (entnext blk)) (= "ATTRIB" (cdr (assoc 0 (setq enx (entget blk)))))) 
    (if 
      (and 
        (setq itm (assoc (cdr (assoc 2 enx)) lst))
        (entmod (subst (cons 1 (cdr itm)) (assoc 1 (reverse enx)) enx))
      )
      (entupd blk)
    )
  )
  nil
)


;#endregion
;#region Base Conversion Functions
;;  http://www.lee-mac.com/baseconversion.html


;; Decimal to Base  -  Lee Mac
;; Converts a decimal number to another base.
;; n - [int] decimal integer
;; b - [int] non-zero positive integer base
;; Returns: [str] Representation of decimal in specified base

(defun Remote>>LM:dec->base (n b) 
  (if (< n b) 
    (chr (+ n (if (< n 10) 48 55)))
    (strcat (Remote>>LM:dec->base (/ n b) b) (Remote>>LM:dec->base (rem n b) b))
  )
)


;; Base to Decimal  -  Lee Mac
;; Converts an number in an arbitrary base to decimal.
;; n - [str] string representing number to convert
;; b - [int] base of input string
;; Returns: [int] Decimal representation of supplied number

(defun Remote>>LM:base->dec (n b / l) 
  (if (= 1 (setq l (strlen n))) 
    (- (ascii n) (if (< (ascii n) 65) 48 55))
    (+ (* b (Remote>>LM:base->dec (substr n 1 (1- l)) b)) (Remote>>LM:base->dec (substr n l) b))
  )
)


;; Base to Decimal  -  Lee Mac
;; Converts an number in an arbitrary base to decimal.
;; n - [str] string representing number to convert
;; b - [int] base of input string
;; Returns: [int] Decimal representation of supplied number

(defun Remote>>LM:vl-base->dec (n b) 
  ((lambda (f) 
     (f (mapcar '(lambda (x) (- x (if (< x 65) 48 55))) (reverse (vl-string->list n))))
   ) 
    (lambda (c) (if c (+ (* b (f (cdr c))) (car c)) 0))
  )
)


;; Base to Base  -  Lee Mac
;; Converts an number from one base to another.
;; n  - [str] string representing number to convert
;; b1 - [int] input base
;; b2 - [int] output base

(defun Remote>>LM:base->base (n b1 b2) 
  (Remote>>LM:dec->base (Remote>>LM:base->dec n b1) b2)
)


;#endregion
;#region Bounding Box
;;  http://www.lee-mac.com/boundingbox.html


;; Bounding Box  -  Lee Mac
;; Returns the point list describing the rectangular frame bounding the supplied object.
;; obj - [vla] VLA-Object

(defun Remote>>LM:boundingbox (obj / a b lst) 
  (if 
    (and 
      (vlax-method-applicable-p obj 'getboundingbox)
      (not (vl-catch-all-error-p (vl-catch-all-apply 'vla-getboundingbox (list obj 'a 'b))))
      (setq lst (mapcar 'vlax-safearray->list (list a b)))
    )
    (mapcar '(lambda (a) (mapcar '(lambda (b) ((eval b) lst)) a)) 
            '((caar cadar)
              (caadr cadar)
              (caadr cadadr)
              (caar cadadr)
             )
    )
  )
)


;#endregion
;#region Browse for Folder
;;  http://www.lee-mac.com/directorydialog.html


;; Browse for Folder  -  Lee Mac
;; Displays a dialog prompting the user to select a folder.
;; msg - [str] message to display at top of dialog
;; dir - [str] [optional] root directory (or nil)
;; bit - [int] bit-coded flag specifying dialog display settings
;; Returns: [str] Selected folder filepath, else nil.

(defun Remote>>LM:browseforfolder (msg dir bit / err fld pth shl slf) 
  (setq err (vl-catch-all-apply 
              (function 
                (lambda (/ app hwd) 
                  (if 
                    (setq app (vlax-get-acad-object)
                          shl (vla-getinterfaceobject app "shell.application")
                          hwd (vl-catch-all-apply 'vla-get-hwnd (list app))
                          fld (vlax-invoke-method shl 
                                                  'browseforfolder
                                                  (if (vl-catch-all-error-p hwd) 0 hwd)
                                                  msg
                                                  bit
                                                  dir
                              )
                    )
                    (setq slf (vlax-get-property fld 'self)
                          pth (vlax-get-property slf 'path)
                          pth (vl-string-right-trim "\\" 
                                                    (vl-string-translate "/" "\\" pth)
                              )
                    )
                  )
                )
              )
            )
  )
  (if slf (vlax-release-object slf))
  (if fld (vlax-release-object fld))
  (if shl (vlax-release-object shl))
  (if (vl-catch-all-error-p err) 
    (prompt (vl-catch-all-error-message err))
    pth
  )
)


;#endregion
;#region Bulge Conversion Functions
;;  http://www.lee-mac.com/bulgeconversion.html


;; Arc to Bulge  -  Lee Mac
;; c     - center
;; a1,a2 - start, end angle
;; r     - radius
;; Returns: (<vertex> <bulge> <vertex>)

(defun Remote>>LM:arc->bulge (c a1 a2 r) 
  (list 
    (polar c a1 r)
    ((lambda (a) (/ (sin a) (cos a))) 
      (/ (rem (+ pi pi (- a2 a1)) (+ pi pi)) 4.0)
    )
    (polar c a2 r)
  )
)


;; 3-Points to Bulge  -  Lee Mac

(defun Remote>>LM:3p->bulge (pt1 pt2 pt3) 
  ((lambda (a) (/ (sin a) (cos a))) (/ (+ (- pi (angle pt2 pt1)) (angle pt2 pt3)) 2))
)


;; Bulge to Arc  -  Lee Mac
;; p1 - start vertex
;; p2 - end vertex
;; b  - bulge
;; Returns: (<center> <start angle> <end angle> <radius>)

(defun Remote>>LM:Bulge->Arc (p1 p2 b / a c r) 
  (setq a (* 2 (atan b))
        r (/ (distance p1 p2) 2 (sin a))
        c (polar p1 (+ (- (/ pi 2) a) (angle p1 p2)) r)
  )
  (if (minusp b) 
    (list c (angle c p2) (angle c p1) (abs r))
    (list c (angle c p1) (angle c p2) (abs r))
  )
)


;; Bulge to Arc  -  Lee Mac
;; p1 - start vertex
;; p2 - end vertex
;; b  - bulge
;; Returns: (<center> <start angle> <end angle> <radius>)

(defun Remote>>LM:Bulge->Arc~ (p1 p2 b / c r) 
  (setq r (/ (* (distance p1 p2) (1+ (* b b))) 4 b)
        c (polar p1 (+ (angle p1 p2) (- (/ pi 2) (* 2 (atan b)))) r)
  )
  (if (minusp b) 
    (list c (angle c p2) (angle c p1) (abs r))
    (list c (angle c p1) (angle c p2) (abs r))
  )
)


;; Bulge Center  -  Lee Mac
;; p1 - start vertex
;; p2 - end vertex
;; b  - bulge
;; Returns the center of the arc described by the given bulge and vertices
 
(defun Remote>>LM:BulgeCenter (p1 p2 b) 
  (polar p1 
         (+ (angle p1 p2) (- (/ pi 2) (* 2 (atan b))))
         (/ (* (distance p1 p2) (1+ (* b b))) 4 b)
  )
)


;; Bulge Radius  -  Lee Mac
;; p1 - start vertex
;; p2 - end vertex
;; b  - bulge
;; Returns the radius of the arc described by the given bulge and vertices
 
(defun Remote>>LM:BulgeRadius (p1 p2 b) 
  (/ (* (distance p1 p2) (1+ (* b b))) 4 (abs b))
)


;#endregion
;#region Clockwise-p
;;  http://www.lee-mac.com/clockwisep.html


;; Clockwise-p (Standard - Version 1)  -  Lee Mac
;; Returns T if p1,p2,p3 are clockwise oriented

(defun Remote>>LM:Clockwise-p (p1 p2 p3) 
  ((lambda (n) (< (car (trans p2 0 n)) (car (trans p1 0 n)))) (mapcar '- p1 p3))
)


;; Clockwise-p (Version 1)  -  Lee Mac
;; Returns T if p1,p2,p3 are clockwise oriented

(defun Remote>>LM:Clockwise-p1 (p1 p2 p3) 
  ((lambda (n) (< (car (trans p2 0 n)) (car (trans p1 0 n)))) (mapcar '- p1 p3))
)


;; Clockwise-p (Version 2)  -  Lee Mac
;; Returns T if p1,p2,p3 are clockwise oriented

(defun Remote>>LM:Clockwise-p2 (p1 p2 p3) 
  (< (* (- (car p2) (car p1)) (- (cadr p3) (cadr p1))) 
     (* (- (cadr p2) (cadr p1)) (- (car p3) (car p1)))
  )
)


;; Clockwise-p (Version 3)  -  gile
;; Returns T if p1,p2,p3 are clockwise oriented

(defun Remote>>LM:clockwise-p3 (p1 p2 p3) 
  (< (sin (- (angle p1 p3) (angle p1 p2))) -1e-14)
)


;#endregion
;#region Collection Functions
;;-------------------------=={ Collection Functions }==------------------------;;

;; VLA-Collection: Get Item  -  Lee Mac
;; Retrieves the item with index 'idx' if present in the supplied collection
;; col - [vla]     VLA Collection Object
;; idx - [str/int] Index of the item to be retrieved

(defun Remote>>LM:getitem (col idx / obj) 
  (if (not (vl-catch-all-error-p (setq obj (vl-catch-all-apply 'vla-item (list col idx))))) 
    obj
  )
)

;; VLA-Collection: Get All Items  -  Lee Mac
;; Returns a list of all items in the supplied collection
;; col - [vla] VLA Collection Object

(defun Remote>>LM:getallitems (col / rtn) 
  (vlax-for obj col (setq rtn (cons obj rtn)))
  (reverse rtn)
)


;#endregion
;#region Colour Conversion Functions
;;-------------------------=={ Colour Conversion Functions }==------------------------;;

;; RGB -> OLE  -  Lee Mac
;; Args: r,g,b - [int] Red, Green, Blue values

(defun Remote>>LM:RGB->OLE (r g b) 
  (logior (fix r) (lsh (fix g) 8) (lsh (fix b) 16))
)


;; OLE -> RGB  -  Lee Mac
;; Args: c - [int] OLE Colour

(defun Remote>>LM:OLE->RGB (c) 
  (mapcar '(lambda (x) (lsh (lsh (fix c) x) -24)) '(24 16 8))
)


;; RGB -> True  -  Lee Mac
;; Args: r,g,b - [int] Red, Green, Blue values

(defun Remote>>LM:RGB->True (r g b) 
  (logior (lsh (fix r) 16) (lsh (fix g) 8) (fix b))
)


;; True -> RGB  -  Lee Mac
;; Args: c - [int] True Colour

(defun Remote>>LM:True->RGB (c) 
  (mapcar '(lambda (x) (lsh (lsh (fix c) x) -24)) '(8 16 24))
)


;; RGB -> ACI  -  Lee Mac
;; Args: r,g,b - [int] Red, Green, Blue values

(defun Remote>>LM:RGB->ACI (r g b / c o) 
  (if 
    (setq o (vla-getinterfaceobject (Remote>>LM:acapp) 
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


;; ACI -> RGB  -  Lee Mac
;; Args: c - [int] ACI (AutoCAD Colour Index) Colour (1<=c<=255)

(defun Remote>>LM:ACI->RGB (c / o r) 
  (if 
    (setq o (vla-getinterfaceobject (Remote>>LM:acapp) 
                                    (strcat "autocad.accmcolor." 
                                            (substr (getvar 'acadver) 1 2)
                                    )
            )
    )
    (progn 
      (setq r (vl-catch-all-apply 
                '(lambda () 
                   (vla-put-colorindex o c)
                   (list (vla-get-red o) (vla-get-green o) (vla-get-blue o))
                 )
              )
      )
      (vlax-release-object o)
      (if (vl-catch-all-error-p r) 
        (prompt (strcat "\nError: " (vl-catch-all-error-message r)))
        r
      )
    )
  )
)


;; RGB -> HSL  -  Lee Mac
;; Args: r,g,b - [int] Red, Green, Blue values

(defun Remote>>LM:RGB->HSL (r g b / d h l m n s) 
  (setq r (/ r 255.0)
        g (/ g 255.0)
        b (/ b 255.0)
        n (min r g b)
        m (max r g b)
  )
  (if (zerop (setq d (- m n))) 
    (list 0 0 (fix (+ 0.5 (* m 100))))
    (progn 
      (if (< (setq l (/ (+ m n) 2.0)) 0.5) 
        (setq s (/ d (+ m n)))
        (setq s (/ d (- 2.0 m n)))
      )
      (cond 
        ((= g m) (setq h (+ (/ (- b r) d) 2)))
        ((= b m) (setq h (+ (/ (- r g) d) 4)))
        ((setq h (/ (- g b) d)))
      )
      (list 
        (fix (+ 0.5 (rem (+ 360 (* h 60)) 360)))
        (fix (+ 0.5 (* s 100)))
        (fix (+ 0.5 (* l 100)))
      )
    )
  )
)


;; HSL -> RGB  -  Lee Mac
;; Args: [int] 0<=h<=360, 0<=s<=100, 0<=l<=100

(defun Remote>>LM:HSL->RGB (h s l / u v) 
  (setq h (/ h 360.0)
        s (/ s 100.0)
        l (/ l 100.0)
  )
  (mapcar '(lambda (x) (fix (+ 0.5 (* 255 x)))) 
          (cond 
            ((zerop s) (list l l l))
            ((zerop l) '(0 0 0))
            ((setq v (if (< l 0.5) (* l (1+ s)) (- (+ l s) (* l s)))
                   u (- (* 2.0 l) v)
             )
             (mapcar 
               '(lambda (h) 
                  (setq h (rem (1+ h) 1))
                  (cond 
                    ((< (* 6.0 h) 1.0) (+ u (* 6.0 h (- v u))))
                    ((< (* 2.0 h) 1.0) v)
                    ((< (* 3.0 h) 2.0) (+ u (* 6.0 (- (/ 2.0 3.0) h) (- v u))))
                    (u)
                  )
                )
               (list (+ h (/ 1.0 3.0)) h (- h (/ 1.0 3.0)))
             )
            )
          )
  )
)


;; OLE -> True  -  Lee Mac
;; Args: c - [int] OLE Colour

(defun Remote>>LM:OLE->True (c) 
  (apply 'logior 
         (mapcar 
           '(lambda (x) (lsh (lsh (lsh (fix c) x) -24) (- x 8)))
           '(24 16 08)
         )
  )
)

;; True -> OLE  -  Lee Mac
;; Args: c - [int] True Colour

(defun Remote>>LM:True->OLE (c) 
  (apply 'logior 
         (mapcar 
           '(lambda (x) (lsh (lsh (lsh (fix c) x) -24) (- x 8)))
           '(08 16 24)
         )
  )
)


;; OLE -> ACI  -  Lee Mac
;; Args: c - [int] OLE Colour

(defun Remote>>LM:OLE->ACI (c) 
  (apply 'Remote>>LM:RGB->ACI (Remote>>LM:OLE->RGB c))
)


;; ACI -> OLE  -  Lee Mac
;; Args: c - [int] ACI (AutoCAD Colour Index) Colour (1<=c<=255)

(defun Remote>>LM:ACI->OLE (c) 
  (apply 'Remote>>LM:RGB->OLE (Remote>>LM:ACI->RGB c))
)


;; OLE -> HSL  -  Lee Mac
;; Args: c - [int] OLE Colour

(defun Remote>>LM:OLE->HSL (c) 
  (apply 'Remote>>LM:RGB->HSL (Remote>>LM:OLE->RGB c))
)


;; HSL -> OLE  -  Lee Mac
;; Args: [int] 0<=h<=360, 0<=s<=100, 0<=l<=100

(defun Remote>>LM:HSL->OLE (h s l) 
  (apply 'Remote>>LM:RGB->OLE (Remote>>LM:HSL->RGB h s l))
)


;; True -> ACI  -  Lee Mac
;; Args: c - [int] True Colour

(defun Remote>>LM:True->ACI (c / o r) 
  (apply 'Remote>>LM:RGB->ACI (Remote>>LM:True->RGB c))
)


;; ACI -> True  -  Lee Mac
;; Args: c - [int] ACI (AutoCAD Colour Index) Colour (1<=c<=255)

(defun Remote>>LM:ACI->True (c / o r) 
  (apply 'Remote>>LM:RGB->True (Remote>>LM:ACI->RGB c))
)


;; True -> HSL  -  Lee Mac
;; Args: c - [int] True Colour

(defun Remote>>LM:True->HSL (c) 
  (apply 'Remote>>LM:RGB->HSL (Remote>>LM:True->RGB c))
)


;; HSL -> True  -  Lee Mac
;; Args: [int] 0<=h<=360, 0<=s<=100, 0<=l<=100

(defun Remote>>LM:HSL->True (h s l) 
  (apply 'Remote>>LM:RGB->True (Remote>>LM:HSL->RGB h s l))
)


;; ACI -> HSL  -  Lee Mac
;; Args: c - [int] ACI (AutoCAD Colour Index) Colour (1<=c<=255)

(defun Remote>>LM:ACI->HSL (c) 
  (apply 'Remote>>LM:RGB->HSL (Remote>>LM:ACI->RGB c))
)


;; HSL -> ACI  -  Lee Mac
;; Args: [int] 0<=h<=360, 0<=s<=100, 0<=l<=100

(defun Remote>>LM:HSL->ACI (h s l) 
  (apply 'Remote>>LM:RGB->ACI (Remote>>LM:HSL->RGB h s l))
)


;#endregion
;#region Column Reference Functions
;;-------------------------=={ Column Reference Functions }==------------------------;;

;; Number to Column  -  Lee Mac
;; Converts an integer into a column reference, e.g. 27 -> AA
;; n - [int] positive non-zero integer

(defun Remote>>LM:num->col (n) 
  (if (< n 27) 
    (chr (+ 64 n))
    (strcat (Remote>>LM:num->col (/ (1- n) 26)) (Remote>>LM:num->col (1+ (rem (1- n) 26))))
  )
)


;; Column to Number  -  Lee Mac
;; Converts a column reference into an integer, e.g. AA -> 27
;; c - [str] upper-case string representing column reference

(defun Remote>>LM:col->num (c / n) 
  (if (= 1 (setq n (strlen c))) 
    (- (ascii c) 64)
    (+ (* 26 (Remote>>LM:col->num (substr c 1 (1- n)))) (Remote>>LM:col->num (substr c n)))
  )
)


;; Column to Number  -  Lee Mac
;; Converts a column reference into an integer, e.g. AA -> 27
;; c - [str] upper-case string representing column reference

(defun Remote>>LM:col->num~ (c) 
  ((lambda (f) (f (reverse (vl-string->list c)))) 
    (lambda (l) (if l (+ (* 26 (f (cdr l))) (- (car l) 64)) 0))
  )
)


;; Increment Alpha  -  Lee Mac
;; Increments an uppercase alphabetical string by a given number of units, e.g. AX + 4 = BB
;; a - [str] uppercase alphabetical string
;; i - [int] integer increment

(defun Remote>>LM:incalpha (a i / c n) 
  (if (< 0 i) 
    (if (zerop (setq n (strlen a))) 
      (Remote>>LM:incalpha "A" (1- i))
      (if (= 90 (setq c (ascii (substr a n)))) 
        (Remote>>LM:incalpha (strcat (Remote>>LM:incalpha (substr a 1 (1- n)) 1) "A") (1- i))
        (strcat (Remote>>LM:incalpha (substr a 1 (1- n)) (/ (+ i c -65) 26)) 
                (chr (+ 65 (rem (+ i c -65) 26)))
        )
      )
    )
    a
  )
)


;; Increment Alpha  -  Lee Mac
;; Increments an uppercase alphabetical string by a given number of units, e.g. AX + 4 = BB
;; a - [str] uppercase alphabetical string
;; i - [int] integer increment

(defun Remote>>LM:incalpha~ (a i) 
  ((lambda (f) (vl-list->string (reverse (f (reverse (vl-string->list a)) i)))) 
    (lambda (l i) 
      (if (< 0 i) 
        (if (car l) 
          (if (= 90 (car l)) 
            (f (cons 65 (f (cdr l) 1)) (1- i))
            (cons (+ 65 (rem (+ i (car l) -65) 26)) 
                  (f (cdr l) (/ (+ i (car l) -65) 26))
            )
          )
          (f '(65) (1- i))
        )
        l
      )
    )
  )
)


;; Increment Alpha  -  Lee Mac
;; Increments an uppercase alphabetical string by a given number of units, e.g. AX + 4 = BB
;; a - [str] uppercase alphabetical string
;; i - [int] integer increment

(defun Remote>>LM:incalphacol (a i) 
  (Remote>>LM:num->col (+ i (Remote>>LM:col->num a)))
)


;; Alpha++  -  Lee Mac
;; Increments an uppercase alphabetical string by one, e.g. AZ => BA
;; a - [str] uppercase alphabetical string

(defun Remote>>LM:alpha++ (a / n) 
  (if (= "" a) 
    "A"
    (if (= "Z" (substr a (setq n (strlen a)))) 
      (strcat (Remote>>LM:alpha++ (substr a 1 (1- n))) "A")
      (strcat (substr a 1 (1- n)) (chr (1+ (ascii (substr a n)))))
    )
  )
)


;; Alpha++  -  Lee Mac
;; Increments an uppercase alphabetical string by one, e.g. AZ => BA
;; a - [str] uppercase alphabetical string

(defun Remote>>LM:alpha++~ (a) 
  ((lambda (f) (vl-list->string (reverse (f (reverse (vl-string->list a)))))) 
    (lambda (l) 
      (if l 
        (if (= 90 (car l)) 
          (cons 65 (f (cdr l)))
          (cons (1+ (car l)) (cdr l))
        )
        '(65)
      )
    )
  )
)


;#endregion
;#region Consistent rtos
;;-------------------------=={ Consistent rtos }==------------------------;;

;; rtos wrapper  -  Lee Mac
;; A wrapper for the rtos function to negate the effect of DIMZIN

(defun Remote>>LM:rtos (real units prec / dimzin result) 
  (setq dimzin (getvar 'dimzin))
  (setvar 'dimzin 0)
  (setq result (vl-catch-all-apply 'rtos (list real units prec)))
  (setvar 'dimzin dimzin)
  (if (not (vl-catch-all-error-p result)) 
    result
  )
)
;#endregion
;#region Convex Hull
;;-------------------------=={ Convex Hull }==------------------------;;

;; Convex Hull  -  Lee Mac
;; Implements the Graham Scan Algorithm to return the Convex Hull of a list of points.
 
(defun Remote>>LM:ConvexHull (lst / ch p0) 
  (cond 
    ((< (length lst) 4) lst)
    ((setq p0 (car lst))
     (foreach p1 (cdr lst) 
       (if 
         (or (< (cadr p1) (cadr p0)) 
             (and (equal (cadr p1) (cadr p0) 1e-8) (< (car p1) (car p0)))
         )
         (setq p0 p1)
       )
     )
     (setq lst (vl-sort lst 
                        (function 
                          (lambda (a b / c d) 
                            (if (equal (setq c (angle p0 a)) (setq d (angle p0 b)) 1e-8) 
                              (< (distance p0 a) (distance p0 b))
                              (< c d)
                            )
                          )
                        )
               )
     )
     (setq ch (list (caddr lst) (cadr lst) (car lst)))
     (foreach pt (cdddr lst) 
       (setq ch (cons pt ch))
       (while (and (caddr ch) (Remote>>LM:Clockwise-p (caddr ch) (cadr ch) pt)) 
         (setq ch (cons pt (cddr ch)))
       )
     )
     ch
    )
  )
)


;#endregion
;#region Copy Block Definition
;;-------------------------=={ Copy Block Definition }==------------------------;;

;; Copy Block Definition  -  Lee Mac
;; Duplicates a block definition, with the copied definition assigned the name provided.
;; blk - [str] name of block definition to be duplicated
;; new - [str] name to be assigned to copied block definition
;; Returns the copied VLA Block Definition Object, else nil
 
(defun Remote>>LM:CopyBlockDefinition (blk new / abc app dbc dbx def doc rtn vrs) 
  (setq dbx (vl-catch-all-apply 'vla-getinterfaceobject 
                                (list (setq app (vlax-get-acad-object)) 
                                      (if (< (setq vrs (atoi (getvar 'acadver))) 16) 
                                        "objectdbx.axdbdocument"
                                        (strcat "objectdbx.axdbdocument." (itoa vrs))
                                      )
                                )
            )
  )
  (cond 
    ((or (null dbx) (vl-catch-all-error-p dbx))
     (prompt "\nUnable to interface with ObjectDBX.")
    )
    ((and 
       (setq doc (vla-get-activedocument app)
             abc (vla-get-blocks doc)
             dbc (vla-get-blocks dbx)
             def (Remote>>LM:getitem abc blk)
       )
       (not (Remote>>LM:getitem abc new))
     )
     (vlax-invoke doc 'copyobjects (list def) dbc)
     (vla-put-name (setq def (Remote>>LM:getitem dbc blk)) new)
     (vlax-invoke dbx 'copyobjects (list def) abc)
     (setq rtn (Remote>>LM:getitem abc new))
    )
  )
  (if (= 'vla-object (type dbx)) 
    (vlax-release-object dbx)
  )
  rtn
)


;#endregion
;#region Copy Folder
;;-------------------------=={ Copy Folder }==------------------------;;

;; Copy Folder  -  Lee Mac
;; Uses the CopyFolder method of the FileSystemObject (FSO) to recursively
;; copy a folder from one location to another.
;; src - [str] Directory to be copied
;; des - [str] Destination directory
;; ovr - [bol] T=overwrite existing files, nil=do not overwrite
;; Returns T if copy was successful, else nil

(defun Remote>>LM:copyfolder (src des ovr / fso rtn) 
  (if (setq fso (vlax-create-object "scripting.filesystemobject")) 
    (progn 
      (setq rtn (not 
                  (or (zerop (vlax-invoke fso 'folderexists src)) 
                      (vl-catch-all-error-p 
                        (vl-catch-all-apply 'vlax-invoke 
                                            (list fso 
                                                  'copyfolder
                                                  src
                                                  des
                                                  (if ovr :vlax-true :vlax-false)
                                            )
                        )
                      )
                  )
                )
      )
      (vlax-release-object fso)
      rtn
    )
  )
)


;; Copy Folder  -  Lee Mac
;; Recursively copies the contents of a folder and the contents of any
;; subfolders to a destination directory; will not overwrite existing files.
;; src - [str] Directory to be copied
;; des - [str] Destination directory
;; Returns T if all files were copied successfully, else nil
;;  alternative to the above function

(defun Remote>>LM:copyfolder~ (src des) 
  (vl-mkdir des)
  (apply 'and 
         (append 
           (mapcar 
             (function 
               (lambda (file) 
                 (vl-file-copy (strcat src "\\" file) (strcat des "\\" file))
               )
             )
             (vl-directory-files src nil 1)
           )
           (mapcar 
             (function 
               (lambda (dir) 
                 (Remote>>LM:copyfolder (strcat src "\\" dir) (strcat des "\\" dir))
               )
             )
             (vl-remove "." (vl-remove ".." (vl-directory-files src nil -1)))
           )
         )
  )
)


;#endregion
;#region Create Directory
;;-------------------------=={ Create Directory }==------------------------;;

;; Create Directory  -  Lee Mac
;; dir - [str] directory to create ("C:\\Folder1\\Folder2")
;; Returns:  T if directory creation is successful, else nil

(defun Remote>>LM:createdirectory (dir) 
  ((lambda (fun) 
     ((lambda (lst) (fun (car lst) (cdr lst))) 
       (vl-remove "" (Remote>>LM:str->lst (vl-string-translate "/" "\\" dir) "\\"))
     )
   ) 
    (lambda (root lst / dir) 
      (if lst 
        (if 
          (or (vl-file-directory-p (setq dir (strcat root "\\" (car lst)))) 
              (vl-mkdir dir)
          )
          (fun dir (cdr lst))
        )
      )
    )
  )
  (vl-file-directory-p dir)
)


;#endregion
;#region DCL List Tile Dependency
;;-------------------------=={ DCL List Tile Dependency }==------------------------;;

;; DCL List-Tile Dependency  -  Lee Mac
;; Configures action_tile statements for the list of keys to enabled dependency between the DCL tiles.
;; key     - [lst] List of DCL tile keys in order of dependency
;; lst-sym - [sym] Quoted variable containing list data
;; rtn-sym - [sym] Quoted variable containing initial selection indexes
 
(defun Remote>>LM:dcld:action (key lst-sym rtn-sym) 

  (defun Remote>>LM:dcld:addlist (key lst) 
    (start_list key)
    (foreach itm lst (add_list itm))
    (end_list)
  )
  (defun Remote>>LM:dcld:getlists (idx lst) 
    (if (cdr idx) 
      (cons (mapcar 'car lst) (Remote>>LM:dcld:getlists (cdr idx) (cdr (nth (car idx) lst))))
      lst
    )
  )
  (defun Remote>>LM:substnth (itm idx lst) 
    (if lst 
      (if (zerop idx) 
        (cons itm (mapcar '(lambda (x) 0) (cdr lst)))
        (cons (car lst) (Remote>>LM:substnth itm (1- idx) (cdr lst)))
      )
    )
  )
  (defun Remote>>LM:dcld:actions (key lst-sym rtn-sym lvl / fun) 
    (setq fun (if (cdr key) 
                (list 'lambda 
                      '(val lst)
                      (list 'setq rtn-sym (list 'Remote>>LM:substnth '(atoi val) lvl rtn-sym))
                      (list 'Remote>>LM:dcld:addlist 
                            (cadr key)
                            (list 'nth (1+ lvl) (list 'Remote>>LM:dcld:getlists rtn-sym 'lst))
                      )
                      (list 
                        (Remote>>LM:dcld:actions (cdr key) lst-sym rtn-sym (1+ lvl))
                        (list 'set_tile (cadr key) "0")
                        'lst
                      )
                )
                (list 'lambda 
                      '(val lst)
                      (list 'setq rtn-sym (list 'Remote>>LM:substnth '(atoi val) lvl rtn-sym))
                )
              )
    )
    (action_tile (car key) (vl-prin1-to-string (list fun '$value lst-sym)))
    fun
  )
  (mapcar 'Remote>>LM:dcld:addlist key (Remote>>LM:dcld:getlists (eval rtn-sym) (eval lst-sym)))
  ((eval (Remote>>LM:dcld:actions key lst-sym rtn-sym 0)) 
    (set_tile (car key) (itoa (car (eval rtn-sym))))
    (eval lst-sym)
  )
  (princ)
)


;; DCL List-Tile Dependency  -  Get Items  -  Lee Mac
;; Returns a list of the items selected from each dependent list tile.
;; idx - [lst] List of selection indexes
;; lst - [lst] List data
 
(defun Remote>>LM:dcld:getitems (idx lst / tmp) 
  (if (cdr idx) 
    (cons (car (setq tmp (nth (car idx) lst))) (Remote>>LM:dcld:getitems (cdr idx) (cdr tmp)))
    (list (nth (car idx) (car lst)))
  )
)


;#endregion
;#region Directory Files
;;-------------------------=={ Directory Files }==------------------------;;

;; Directory Files  -  Lee Mac
;; Retrieves all files of a specified filetype residing in a directory (and subdirectories)
;; dir - [str] Root directory for which to return filenames
;; typ - [str] Optional filetype filter (DOS pattern)
;; sub - [bol] If T, subdirectories of the root directory are included
;; Returns: [lst] List of files matching the filetype criteria, else nil if none are found

(defun Remote>>LM:directoryfiles (dir typ sub) 
  (setq dir (vl-string-right-trim "\\" (vl-string-translate "/" "\\" dir)))
  (append (mapcar '(lambda (x) (strcat dir "\\" x)) (vl-directory-files dir typ 1)) 
          (if sub 
            (apply 'append 
                   (mapcar 
                     '(lambda (x) 
                        (if (not (wcmatch x "`.,`.`.")) 
                          (Remote>>LM:directoryfiles (strcat dir "\\" x) typ sub)
                        )
                      )
                     (vl-directory-files dir nil -1)
                   )
            )
          )
  )
)


;#endregion
;#region Draw Order Functions
;;-------------------------=={ Draw Order Functions }==------------------------;;

;; Move to Top  -  Lee Mac
;; Moves a set of objects to the top of the draw order.
;; obs - [lst/sel] Selection set or list of objects with same owner
;; Returns: T if successful, else nil
 
(defun Remote>>LM:movetotop (obs / tab) 
  (if 
    (and (or (= 'list (type obs)) (setq obs (Remote>>LM:ss->vla obs))) 
         (setq tab (Remote>>LM:sortentstable (Remote>>LM:getowner (car obs))))
    )
    (not (vla-movetotop tab (Remote>>LM:safearrayvariant vlax-vbobject obs)))
  )
)


;; Move to Bottom  -  Lee Mac
;; Moves a set of objects to the bottom of the draw order.
;; obs - [lst/sel] Selection set or list of objects with same owner
;; Returns: T if successful, else nil
 
(defun Remote>>LM:movetobottom (obs / tab) 
  (if 
    (and (or (= 'list (type obs)) (setq obs (Remote>>LM:ss->vla obs))) 
         (setq tab (Remote>>LM:sortentstable (Remote>>LM:getowner (car obs))))
    )
    (not (vla-movetobottom tab (Remote>>LM:safearrayvariant vlax-vbobject obs)))
  )
)


;; Move Above  -  Lee Mac
;; Moves a set of objects above a supplied object in the draw order.
;; obs - [lst/sel] Selection set or list of objects with same owner
;; obj - [vla] Object above which to move supplied objects
;; Returns: T if successful, else nil
 
(defun Remote>>LM:moveabove (obs obj / tab) 
  (if 
    (and (or (= 'list (type obs)) (setq obs (Remote>>LM:ss->vla obs))) 
         (setq tab (Remote>>LM:sortentstable (Remote>>LM:getowner (car obs))))
    )
    (not (vla-moveabove tab (Remote>>LM:safearrayvariant vlax-vbobject obs) obj))
  )
)


;; Move Below  -  Lee Mac
;; Moves a set of objects below a supplied object in the draw order.
;; obs - [lst/sel] Selection set or list of objects with same owner
;; obj - [vla] Object below which to move supplied objects
;; Returns: T if successful, else nil
 
(defun Remote>>LM:movebelow (obs obj / tab) 
  (if 
    (and (or (= 'list (type obs)) (setq obs (Remote>>LM:ss->vla obs))) 
         (setq tab (Remote>>LM:sortentstable (Remote>>LM:getowner (car obs))))
    )
    (not (vla-movebelow tab (Remote>>LM:safearrayvariant vlax-vbobject obs) obj))
  )
)


;; Swap Order  -  Lee Mac
;; Swaps the draw order of two objects (may require regen).
;; ob1,ob2 - [vla] Objects to swap
;; Returns: T if successful, else nil
 
(defun Remote>>LM:swaporder (ob1 ob2 / tab) 
  (if (setq tab (Remote>>LM:sortentstable (Remote>>LM:getowner ob1))) 
    (not (vla-swaporder tab ob1 ob2))
  )
)


;#endregion
;#region Drawing Version
;;-------------------------=={ Drawing Version }==------------------------;;

;; Drawing Version  -  Lee Mac
;; Returns the version of the supplied filename (dwg/dws/dwt/dxf)
;; dwg - [str] Drawing filename
 
(defun Remote>>LM:dwgversion (dwg / des vrs) 
  (cond 
    ((not 
       (and 
         (setq dwg (findfile dwg))
         (setq des (open dwg "r"))
       )
     )
    )
    ((wcmatch (strcase dwg t) "*`.dw[gst]")
     (setq vrs (strcase (substr (read-line des) 1 6)))
    )
    ((wcmatch (strcase dwg t) "*`.dxf")
     (repeat 7 (read-line des))
     (setq vrs (strcase (read-line des)))
    )
  )
  (if (= 'file (type des)) (close des))
  (cdr 
    (assoc vrs 
           '(("AC1032" . "2018")
             ("AC1027" . "2013-2015")
             ("AC1024" . "2010-2012")
             ("AC1021" . "2007-2009")
             ("AC1018" . "2004-2006")
             ("AC1015" . "2000-2002")
             ("AC1014" . "Release 14")
             ("AC1012" . "Release 13")
             ("AC1009" . "Release 11/12")
             ("AC1006" . "Release 10")
             ("AC1004" . "Release 9")
             ("AC1003" . "Release 2.60")
             ("AC1002" . "Release 2.50")
             ("AC1001" . "Release 2.22")
             ("AC2.22" . "Release 2.22")
             ("AC2.21" . "Release 2.21")
             ("AC2.10" . "Release 2.10")
             ("AC1.50" . "Release 2.05")
             ("AC1.40" . "Release 1.40")
             ("AC1.2" . "Release 1.2")
             ("MC0.0" . "Release 1.0")
            )
    )
  )
)


;#endregion
;#region Dynamic Block Functions
;;-------------------------=={ Dynamic Block Functions }==------------------------;;

;; Get Dynamic Block Property Value  -  Lee Mac
;; Returns the value of a Dynamic Block property (if present)
;; blk - [vla] VLA Dynamic Block Reference object
;; prp - [str] Dynamic Block property name (case-insensitive)

(defun Remote>>LM:getdynpropvalue (blk prp) 
  (setq prp (strcase prp))
  (vl-some '(lambda (x) (if (= prp (strcase (vla-get-propertyname x))) (vlax-get x 'value))) 
           (vlax-invoke blk 'getdynamicblockproperties)
  )
)


;; Set Dynamic Block Property Value  -  Lee Mac
;; Modifies the value of a Dynamic Block property (if present)
;; blk - [vla] VLA Dynamic Block Reference object
;; prp - [str] Dynamic Block property name (case-insensitive)
;; val - [any] New value for property
;; Returns: [any] New value if successful, else nil

(defun Remote>>LM:setdynpropvalue (blk prp val) 
  (setq prp (strcase prp))
  (vl-some 
    '(lambda (x) 
       (if (= prp (strcase (vla-get-propertyname x))) 
         (progn 
           (vla-put-value x 
                          (vlax-make-variant val (vlax-variant-type (vla-get-value x)))
           )
           (cond (val) (t))
         )
       )
     )
    (vlax-invoke blk 'getdynamicblockproperties)
  )
)


;; Set Dynamic Block Properties  -  Lee Mac
;; Modifies values of Dynamic Block properties using a supplied association list.
;; blk - [vla] VLA Dynamic Block Reference object
;; lst - [lst] Association list of ((<Property> . <Value>) ... )
;; Returns: nil

(defun Remote>>LM:setdynprops (blk lst / itm) 
  (setq lst (mapcar '(lambda (x) (cons (strcase (car x)) (cdr x))) lst))
  (foreach x (vlax-invoke blk 'getdynamicblockproperties) 
    (if (setq itm (assoc (strcase (vla-get-propertyname x)) lst)) 
      (vla-put-value x (vlax-make-variant (cdr itm) (vlax-variant-type (vla-get-value x))))
    )
  )
)


;; Get Dynamic Block Property Allowed Values  -  Lee Mac
;; Returns the allowed values for a specific Dynamic Block property.
;; blk - [vla] VLA Dynamic Block Reference object
;; prp - [str] Dynamic Block property name (case-insensitive)
;; Returns: [lst] List of allowed values for property, else nil if no restrictions

(defun Remote>>LM:getdynpropallowedvalues (blk prp) 
  (setq prp (strcase prp))
  (vl-some 
    '(lambda (x) (if (= prp (strcase (vla-get-propertyname x))) (vlax-get x 'allowedvalues)))
    (vlax-invoke blk 'getdynamicblockproperties)
  )
)


;; Get Visibility Parameter Name  -  Lee Mac
;; Returns the name of the Visibility Parameter of a Dynamic Block (if present)
;; blk - [vla] VLA Dynamic Block Reference object
;; Returns: [str] Name of Visibility Parameter, else nil

(defun Remote>>LM:getvisibilityparametername (blk / vis) 
  (if 
    (and 
      (vlax-property-available-p blk 'effectivename)
      (setq blk (vla-item 
                  (vla-get-blocks (vla-get-document blk))
                  (vla-get-effectivename blk)
                )
      )
      (= :vlax-true (vla-get-isdynamicblock blk))
      (= :vlax-true (vla-get-hasextensiondictionary blk))
      (setq vis (vl-some 
                  '(lambda (pair) 
                     (if 
                       (and 
                         (= 360 (car pair))
                         (= "BLOCKVISIBILITYPARAMETER" 
                            (cdr (assoc 0 (entget (cdr pair))))
                         )
                       )
                       (cdr pair)
                     )
                   )
                  (dictsearch 
                    (vlax-vla-object->ename (vla-getextensiondictionary blk))
                    "ACAD_ENHANCEDBLOCK"
                  )
                )
      )
    )
    (cdr (assoc 301 (entget vis)))
  )
)


;; Get Dynamic Block Visibility State  -  Lee Mac
;; Returns the value of the Visibility Parameter of a Dynamic Block (if present)
;; blk - [vla] VLA Dynamic Block Reference object
;; Returns: [str] Value of Visibility Parameter, else nil

(defun Remote>>LM:getvisibilitystate (blk / vis) 
  (if (setq vis (Remote>>LM:getvisibilityparametername blk)) 
    (Remote>>LM:getdynpropvalue blk vis)
  )
)


;; Set Dynamic Block Visibility State  -  Lee Mac
;; Sets the Visibility Parameter of a Dynamic Block (if present) to a specific value (if allowed)
;; blk - [vla] VLA Dynamic Block Reference object
;; val - [str] Visibility State Parameter value
;; Returns: [str] New value of Visibility Parameter, else nil

(defun Remote>>LM:SetVisibilityState (blk val / vis) 
  (if 
    (and 
      (setq vis (Remote>>LM:getvisibilityparametername blk))
      (member (strcase val) (mapcar 'strcase (Remote>>LM:getdynpropallowedvalues blk vis)))
    )
    (Remote>>LM:setdynpropvalue blk vis val)
  )
)


;#endregion
;#region Edit Box
;;-------------------------=={ Edit Box }==------------------------;;

;; Edit Box  -  Lee Mac
;; Displays a DCL Edit Box to obtain a string from the user
;; str - [str] Initial value to display ("" for none)
;; Returns: [str] Edit box contents if user pressed OK, else nil

(defun Remote>>LM:editbox (str / han) 
  (and (< 0 (setq han (load_dialog "acad"))) 
       (new_dialog "acad_txtedit" han)
       (set_tile "text_edit" str)
       (action_tile "text_edit" "(setq str $value)")
       (if (zerop (start_dialog)) (setq str nil))
  )
  (if (< 0 han) (unload_dialog han))
  str
)


;#endregion
;#region Effective Block Name
;;-------------------------=={ Effective Block Name }==------------------------;;

;; Effective Block Name  -  Lee Mac
;; obj - [vla] VLA Block Reference object

(defun Remote>>LM:effectivename (obj) 
  (vlax-get-property obj 
                     (if (vlax-property-available-p obj 'effectivename) 
                       'effectivename
                       'name
                     )
  )
)


;; Effective Block Name  -  Lee Mac
;; ent - [ent] Block Reference entity

(defun Remote>>LM:al-effectivename (ent / blk rep) 
  (if (wcmatch (setq blk (cdr (assoc 2 (entget ent)))) "`**") 
    (if 
      (and 
        (setq rep (cdadr 
                    (assoc -3 
                           (entget 
                             (cdr 
                               (assoc 330 
                                      (entget 
                                        (tblobjname "block" blk)
                                      )
                               )
                             )
                             '("AcDbBlockRepBTag")
                           )
                    )
                  )
        )
        (setq rep (handent (cdr (assoc 1005 rep))))
      )
      (setq blk (cdr (assoc 2 (entget rep))))
    )
  )
  blk
)


;#endregion
;#region Entity to Point List
;;-------------------------=={ Entity to Point List }==------------------------;;

;; Entity to Point List  -  Lee Mac
;; Returns a list of WCS points describing or approximating the supplied entity, else nil if the entity is not supported.
;; ent - [ent] Entity name to be described by point list (POINT/LINE/ARC/CIRCLE/LWPOLYLINE/POLYLINE/ELLIPSE/SPLINE)
;; acc - [num] Positive number determining the point density for non-linear objects
 
(defun Remote>>LM:ent->pts (ent acc / ang bul cen cls di1 di2 enx inc itm lst num ocs rad tot typ vt1 vt2 vtl) 
  (setq enx (entget ent)
        typ (cdr (assoc 0 enx))
  )
  (cond 
    ((= "POINT" typ)
     (list (cdr (assoc 10 enx)))
    )
    ((= "LINE" typ)
     (mapcar '(lambda (x) (cdr (assoc x enx))) '(10 11))
    )
    ((or (= "ARC" typ) (= "CIRCLE" typ))
     (if (= "ARC" typ) 
       (setq ang (cdr (assoc 50 enx))
             tot (rem (+ pi pi (- (cdr (assoc 51 enx)) ang)) (+ pi pi))
             num (fix (+ 1.0 1e-8 (* acc (/ tot (+ pi pi)))))
             inc (/ tot (float num))
             num (1+ num)
       )
       (setq ang 0.0
             tot (+ pi pi)
             num (fix (+ 1e-8 acc))
             inc (/ tot (float num))
       )
     )
     (setq cen (cdr (assoc 010 enx))
           rad (cdr (assoc 040 enx))
           ocs (cdr (assoc 210 enx))
     )
     (repeat num 
       (setq lst (cons (trans (polar cen ang rad) ocs 0) lst)
             ang (+ ang inc)
       )
     )
     (reverse lst)
    )
    ((or (= "LWPOLYLINE" typ) 
         (and (= "POLYLINE" typ) (zerop (logand (logior 16 64) (cdr (assoc 70 enx)))))
     )
     (if (= "LWPOLYLINE" typ) 
       (setq vtl (Remote>>LM:ent->pts:lwpolyvertices enx))
       (setq vtl (Remote>>LM:ent->pts:polyvertices ent))
     )
     (if 
       (setq ocs (cdr (assoc 210 enx))
             cls (= 1 (logand 1 (cdr (assoc 70 enx))))
       )
       (setq vtl (append vtl (list (cons (caar vtl) 0.0))))
     )
     (while (setq itm (car vtl)) 
       (setq vtl (cdr vtl)
             vt1 (car itm)
             bul (cdr itm)
             lst (cons (trans vt1 ocs 0) lst)
       )
       (if (and (not (equal 0.0 bul 1e-8)) (setq vt2 (caar vtl))) 
         (progn 
           (setq rad (/ (* (distance vt1 vt2) (1+ (* bul bul))) 4.0 bul)
                 cen (polar vt1 
                            (+ (angle vt1 vt2) (- (/ pi 2.0) (* 2.0 (atan bul))))
                            rad
                     )
                 rad (abs rad)
                 tot (* 4.0 (atan bul))
                 num (fix (+ 1.0 1e-8 (* acc (/ (abs tot) (+ pi pi)))))
                 inc (/ tot (float num))
                 ang (+ (angle cen vt1) inc)
           )
           (repeat (1- num) 
             (setq lst (cons (trans (polar cen ang rad) ocs 0) lst)
                   ang (+ ang inc)
             )
           )
         )
       )
     )
     (reverse (if cls (cdr lst) lst))
    )
    ((= "ELLIPSE" typ)
     (setq di1 (vlax-curve-getdistatparam ent (vlax-curve-getstartparam ent))
           di2 (vlax-curve-getdistatparam ent (vlax-curve-getendparam ent))
           di2 (- di2 1e-8)
     )
     (while (< di1 di2) 
       (setq lst (cons (vlax-curve-getpointatdist ent di1) lst)
             rad (distance '(0.0 0.0) 
                           (vlax-curve-getfirstderiv ent 
                                                     (vlax-curve-getparamatdist ent di1)
                           )
                 )
             di1 (+ di1 (/ di2 (1+ (fix (* acc (/ di2 rad (+ pi pi)))))))
       )
     )
     (reverse (if (vlax-curve-isclosed ent) lst (cons (vlax-curve-getendpoint ent) lst)))
    )
    ((= "SPLINE" typ)
     (setq di1 (vlax-curve-getdistatparam ent (vlax-curve-getstartparam ent))
           di2 (vlax-curve-getdistatparam ent (vlax-curve-getendparam ent))
           lst (list (vlax-curve-getstartpoint ent))
           inc (/ (- di2 di1) (float acc))
           di1 (+ di1 inc)
     )
     (repeat (1- (fix (+ 1e-8 acc))) 
       (setq lst (cons (vlax-curve-getpointatdist ent di1) lst)
             di1 (+ di1 inc)
       )
     )
     (reverse (if (vlax-curve-isclosed ent) lst (cons (vlax-curve-getendpoint ent) lst)))
    )
  )
)

(defun Remote>>LM:ent->pts:lwpolyvertices (enx / elv lst vtx) 
  (setq elv (list (cdr (assoc 38 enx))))
  (while (setq vtx (assoc 10 enx)) 
    (setq enx (cdr (member vtx enx))
          lst (cons (cons (append (cdr vtx) elv) (cdr (assoc 42 enx))) lst)
    )
  )
  (reverse lst)
)

(defun Remote>>LM:ent->pts:polyvertices (ent / lst vte vtx) 
  (setq vte (entnext ent)
        vtx (entget vte)
  )
  (while (= "VERTEX" (cdr (assoc 0 vtx))) 
    (setq lst (cons (cons (cdr (assoc 10 vtx)) (cdr (assoc 42 vtx))) lst)
          vte (entnext vte)
          vtx (entget vte)
    )
  )
  (reverse lst)
)


;#endregion
;#region Escape Wildcards
;;-------------------------=={ Escape Wildcards }==------------------------;;

;; Escape Wildcards (Iterative)  -  Lee Mac
;; Escapes wildcard special characters in a supplied string

(defun Remote>>LM:escapewildcards (str) 
  (vl-list->string 
    (apply 'append 
           (mapcar 
             '(lambda (c) 
                (if (member c '(35 64 46 42 63 126 91 93 45 44)) 
                  (list 96 c)
                  (list c)
                )
              )
             (vl-string->list str)
           )
    )
  )
)


;; Escape Wildcards (Recursive)  -  Lee Mac
;; Escapes wildcard special characters in a supplied string

(defun Remote>>LM:escapewildcards-r (str) 
  (if (wcmatch str "*[-#@.*?~`[`,]*,*`]*") 
    (if (wcmatch str "[-#@.*?~`[`,]*,`]*") 
      (strcat "`" (substr str 1 1) (Remote>>LM:escapewildcards (substr str 2)))
      (strcat (substr str 1 1) (Remote>>LM:escapewildcards (substr str 2)))
    )
    str
  )
)


;#endregion
;#region Evaluate Once on Startup
;;-------------------------=={ Evaluate Once on Startup }==------------------------;;

;; Evaluate Once on Startup  -  Lee Mac
;; Writes expressions to an existing or temporary acaddoc.lsp to be evaluated on drawing startup,
;; with the acaddoc.lsp restored to its original state or deleted following evaluation.
;; 
;; Call with quoted expressions to be evaluated, e.g.:
;; (Remote>>LM:evalonceonstartup '((lambda ( / foo ) (setq foo 10.0) (print foo) (princ))))
;; 
;; Function returns T if expressions are written successfully.
 
(defun Remote>>LM:evalonceonstartup (expr / *error* cnt des lsp tmp) 

  (defun *error* (msg) 
    (if (= 'file (type des)) (close des))
    (if (not (wcmatch (strcase msg t) "*break,*cancel*,*exit*")) 
      (princ (strcat "\nError: " msg))
    )
    (princ)
  )

  ;; If acaddoc.lsp already exists, check how many lines it has
  (if 
    (and (setq lsp (findfile "acaddoc.lsp")) 
         (setq des (open lsp "r"))
    )
    (progn 
      (setq cnt 0)
      (while (read-line des) (setq cnt (1+ cnt)))
      (setq des (close des))
    )
  )

  ;; Write expressions to new/existing acaddoc.lsp
  (if 
    (or (and lsp (setq des (open lsp "a"))) 
        (setq des (open 
                    (setq tmp (strcat 
                                (vl-string-right-trim "\\" 
                                                      (vl-string-translate "/" 
                                                                           "\\"
                                                                           (getvar 'roamablerootprefix)
                                                      )
                                )
                                "\\Support\\acaddoc.lsp"
                              )
                    )
                    "w"
                  )
        )
    )
    (progn 
      ;; Write blank line in case we are appending
      (write-line "" des)

      ;; Write expressions to be evaluated on startup
      (write-line 
        (strcat 
          "(defun Remote>>LM:evalonceonstartup:eval nil "
          (vl-prin1-to-string expr)
          ")"
        )
        des
      )

      ;; If acaddoc.lsp already existed, construct expressions to restore it
      (if (= 'str (type lsp)) 
        (write-line 
          (strcat 
            "(defun Remote>>LM:evalonceonstartup:clean ( / des lsp lst )"
            "    (if"
            "        (and"
            "            (setq lsp (findfile "
            (vl-prin1-to-string lsp)
            "))"
            "            (setq des (open lsp \"r\"))"
            "        )"
            "        (progn"
            "            (repeat "
            (itoa cnt)
            "                (setq lst (cons (read-line des) lst))"
            "            )"
            "            (close des)"
            "            (if (setq des (open lsp \"w\"))"
            "                (progn"
            "                    (foreach x (reverse lst) (write-line x des))"
            "                    (close des)"
            "                )"
            "            )"
            "        )"
            "    )"
            ")"
          )
          des
        )
        ;; Else delete it
        (write-line 
          (strcat 
            "(defun Remote>>LM:evalonceonstartup:clean ( / lsp )"
            "    (if (setq lsp (findfile "
            (vl-prin1-to-string tmp)
            "))"
            "        (vl-file-delete lsp)"
            "    )"
            ")"
          )
          des
        )
      )

      ;; Construct s::startup function
      (write-line 
        (vl-prin1-to-string 
          (quote 
            (if (= 'list (type s::startup)) 
              (setq s::startup (append s::startup 
                                       '((Remote>>LM:evalonceonstartup:eval)
                                         (Remote>>LM:evalonceonstartup:clean)
                                        )
                               )
              )
              (defun-q s::startup nil 
                (Remote>>LM:evalonceonstartup:eval)
                (Remote>>LM:evalonceonstartup:clean)
              )
            )
          )
        )
        des
      )

      (setq des (close des))
      t
    )
  )
)


;#endregion
;#region Explore
;;-------------------------=={ Explore }==------------------------;;

;; Explore  -  Lee Mac
;; Opens a specified folder in a Windows Explorer window.
;; target - [int/str] Directory or ShellSpecialFolderConstants enum

(defun Remote>>LM:explore (Remote>>LM:target / rtn shl) 
  (if 
    (and (or (= 'int (type target)) (vl-file-directory-p target)) 
         (setq shl (vla-getinterfaceobject (vlax-get-acad-object) "shell.application"))
    )
    (progn 
      (setq rtn (vl-catch-all-apply 'vlax-invoke (list shl 'explore target)))
      (vlax-release-object shl)
      (if (vl-catch-all-error-p rtn) 
        (prompt (vl-catch-all-error-message rtn))
        t
      )
    )
  )
)
;#endregion
;#region Field Code
;;-------------------------=={ Field Code }==------------------------;;

;; Field Code  -  Lee Mac
;; Returns the field expression associated with an entity
 
(defun Remote>>LM:fieldcode (ent / replacefield replaceobject fieldstring enx) 

  (defun replacefield (str enx / ent fld pos) 
    (if (setq pos (vl-string-search "\\_FldIdx" (setq str (replaceobject str enx)))) 
      (progn 
        (setq ent (assoc 360 enx)
              fld (entget (cdr ent))
        )
        (strcat 
          (substr str 1 pos)
          (replacefield (fieldstring fld) fld)
          (replacefield 
            (substr str (1+ (vl-string-search ">%" str pos)))
            (cdr (member ent enx))
          )
        )
      )
      str
    )
  )

  (defun replaceobject (str enx / ent pos) 
    (if (setq pos (vl-string-search "ObjIdx" str)) 
      (strcat 
        (substr str 1 (+ pos 5))
        " "
        (Remote>>LM:ObjectID (vlax-ename->vla-object (cdr (setq ent (assoc 331 enx)))))
        (replaceobject 
          (substr str (1+ (vl-string-search ">%" str pos)))
          (cdr (member ent enx))
        )
      )
      str
    )
  )

  (defun fieldstring (enx / itm) 
    (if (setq itm (assoc 3 enx)) 
      (strcat (cdr itm) (fieldstring (cdr (member itm enx))))
      (cond ((cdr (assoc 2 enx))) (""))
    )
  )

  (if 
    (and 
      (wcmatch (cdr (assoc 0 (setq enx (entget ent)))) 
               "TEXT,MTEXT,ATTRIB,MULTILEADER,*DIMENSION"
      )
      (setq enx (cdr (assoc 360 enx)))
      (setq enx (dictsearch enx "ACAD_FIELD"))
      (setq enx (dictsearch (cdr (assoc -1 enx)) "TEXT"))
    )
    (replacefield (fieldstring enx) enx)
  )
)
;#endregion
;#region Field Objects
;;-------------------------=={ Field Objects }==------------------------;;

;; Field Objects  -  Lee Mac
;; Returns a list of entities referenced by a supplied field
;; ent - [ent] Entity containing field (Text / MText / Attribute)
;; Returns: [lst] List of entities referenced by Field, else nil

(defun Remote>>LM:fieldobjects (ent / _getfieldobjects) 

  (defun _getfieldobjects (a) 
    (apply 'append 
           (mapcar 
             '(lambda (a) 
                (if (= 360 (car a)) 
                  (_getfieldobjects (cdr a))
                  (if (= 331 (car a)) (list (cdr a)))
                )
              )
             (entget a)
           )
    )
  )

  (if 
    (and (wcmatch (cdr (assoc 0 (setq ent (entget ent)))) "TEXT,MTEXT,ATTRIB") 
         (setq ent (cdr (assoc 360 ent)))
         (setq ent (dictsearch ent "acad_field"))
         (setq ent (dictsearch (cdr (assoc -1 ent)) "text"))
    )
    (_getfieldobjects (cdr (assoc -1 ent)))
  )
)
;#endregion
;#region Find File
;;-------------------------=={ Find File }==------------------------;;

;; Findfile  -  Lee Mac
;; Searches the supplied directory and all subdirectories of the supplied directory for the specified file.
;; fnm - [str] File to search, e.g. "MyFile.txt"
;; dir - [str] Root directory
;; Returns: [str] Full filename of file if found, else nil.

(defun Remote>>LM:findfile (fnm dir) 
  (setq dir (vl-string-right-trim "\\" (vl-string-translate "/" "\\" dir)))
  (cond 
    ((findfile (strcat dir "\\" fnm)))
    ((vl-some '(lambda (x) (Remote>>LM:findfile fnm (strcat dir "\\" x))) 
              (vl-remove "." (vl-remove ".." (vl-directory-files dir nil -1)))
     )
    )
  )
)
;#endregion
;#region Flatten List
;;-------------------------=={ Flatten List }==------------------------;;

;; Flatten List  -  Lee Mac
;; Transforms a nested list into a non-nested list

(defun Remote>>LM:flatten (l) 
  (if (atom l) 
    (list l)
    (append (Remote>>LM:flatten (car l)) (if (cdr l) (Remote>>LM:flatten (cdr l))))
  )
)

;; Flatten List  -  Lee Mac
;; Transforms a nested list into a non-nested list with null values removed

(defun Remote>>LM:flatten-nils (l) 
  (if l 
    (if (atom l) 
      (list l)
      (append (Remote>>LM:flatten-nils (car l)) (Remote>>LM:flatten-nils (cdr l)))
    )
  )
)
;#endregion
;#region Get Anonymous References
;;-------------------------=={ Get Anonymous References }==------------------------;;

;; Get Anonymous References  -  Lee Mac
;; Returns the names of all anonymous references of a block.
;; blk - [str] Block name/wildcard pattern for which to return anon. references

(defun Remote>>LM:getanonymousreferences (blk / ano def lst rec ref) 
  (setq blk (strcase blk))
  (while (setq def (tblnext "block" (null def))) 
    (if 
      (and (= 1 (logand 1 (cdr (assoc 70 def)))) 
           (setq rec (entget 
                       (cdr 
                         (assoc 330 
                                (entget 
                                  (tblobjname "block" 
                                              (setq ano (cdr (assoc 2 def)))
                                  )
                                )
                         )
                       )
                     )
           )
      )
      (while 
        (and 
          (not (member ano lst))
          (setq ref (assoc 331 rec))
        )
        (if 
          (and 
            (entget (cdr ref))
            (wcmatch (strcase (Remote>>LM:al-effectivename (cdr ref))) blk)
          )
          (setq lst (cons ano lst))
        )
        (setq rec (cdr (member (assoc 331 rec) rec)))
      )
    )
  )
  (reverse lst)
)
                        
;; Effective Block Name  -  Lee Mac
;; ent - [ent] Block Reference entity

(defun Remote>>LM:al-effectivename (ent / blk rep) 
  (if (wcmatch (setq blk (cdr (assoc 2 (entget ent)))) "`**") 
    (if 
      (and 
        (setq rep (cdadr 
                    (assoc -3 
                           (entget 
                             (cdr 
                               (assoc 330 
                                      (entget 
                                        (tblobjname "block" blk)
                                      )
                               )
                             )
                             '("acdbblockrepbtag")
                           )
                    )
                  )
        )
        (setq rep (handent (cdr (assoc 1005 rep))))
      )
      (setq blk (cdr (assoc 2 (entget rep))))
    )
  )
  blk
)

;#endregion
;#region Get Files Dialog
;;-------------------------=={ Get Files Dialog }==------------------------;;

;;  GetFiles  -  Lee Mac
;;  An analog of the 'getfiled' function for multiple file selection.
;;  msg - [str/nil] Dialog box label; 'Select Files' if nil or "".
;;  def - [str/nil] Default directory; dwgprefix if nil or "".
;;  ext - [str/nil] File extension filter (e.g. "dwg;lsp"); "*" if nil 
;;  Returns: List of selected files, else nil  
;;  Author:  Lee Mac, Copyright © 2012  -  www.lee-mac.com              ;;

 
(defun Remote>>LM:getfiles (msg def ext / *error* dch dcl des dir dirdata lst rtn) 

  (defun *error* (msg) 
    (if (= 'file (type des)) 
      (close des)
    )
    (if (and (= 'int (type dch)) (< 0 dch)) 
      (unload_dialog dch)
    )
    (if (and (= 'str (type dcl)) (findfile dcl)) 
      (vl-file-delete dcl)
    )
    (if (and msg (not (wcmatch (strcase msg t) "*break,*cancel*,*exit*"))) 
      (princ (strcat "\nError: " msg))
    )
    (princ)
  )

  (if 
    (and 
      (setq dcl (vl-filename-mktemp nil nil ".dcl"))
      (setq des (open dcl "w"))
      (progn 
        (foreach x 
          '("lst : list_box" "{" "    width = 40.0;" "    height = 20.0;" "    fixed_width = true;" 
            "    fixed_height = true;" "    alignment = centered;" "    multiple_select = true;" "}" "but : button" "{" 
            "    width = 20.0;" "    height = 1.8;" "    fixed_width = true;" "    fixed_height = true;" 
            "    alignment = centered;" "}" "getfiles : dialog" "{" "    key = \"title\"; spacer;" "    : row" "    {" 
            "        alignment = centered;" "        : edit_box { key = \"dir\"; label = \"Folder:\"; }" 
            "        : button" "        {" "            key = \"brw\";" "            label = \"Browse\";" 
            "            fixed_width = true;" "        }" "    }" "    spacer;" "    : row" "    {" "        : column" 
            "        {" "            : lst { key = \"box1\"; }" 
            "            : but { key = \"add\" ; label = \"Add Files\"; }" "        }" "        : column {" 
            "            : lst { key = \"box2\"; }" "            : but { key = \"del\" ; label = \"Remove Files\"; }" 
            "        }" "    }" "    spacer; ok_cancel;" "}"
           )
          (write-line x des)
        )
        (setq des (close des))
        (< 0 (setq dch (load_dialog dcl)))
      )
      (new_dialog "getfiles" dch)
    )
    (progn 
      (setq ext (if (= 'str (type ext)) (Remote>>LM:getfiles:str->lst (strcase ext) ";") '("*")))
      (set_tile "title" (if (member msg '(nil "")) "Select Files" msg))
      (set_tile "dir" 
                (setq dir (Remote>>LM:getfiles:fixdir 
                            (if 
                              (or (member def '(nil "")) 
                                  (not (vl-file-directory-p (Remote>>LM:getfiles:fixdir def)))
                              )
                              (getvar 'dwgprefix)
                              def
                            )
                          )
                )
      )
      (setq lst (Remote>>LM:getfiles:updatefilelist dir ext nil))
      (mode_tile "add" 1)
      (mode_tile "del" 1)

      (action_tile "brw" 
                   (vl-prin1-to-string 
                     '(if (setq tmp (Remote>>LM:getfiles:browseforfolder "" nil 512)) 
                        (setq lst (Remote>>LM:getfiles:updatefilelist 
                                    (set_tile "dir" (setq dir tmp))
                                    ext
                                    rtn
                                  )
                              rtn (Remote>>LM:getfiles:updateselected dir rtn)
                        )
                      )
                   )
      )

      (action_tile "dir" 
                   (vl-prin1-to-string 
                     '(if (= 1 $reason) 
                        (setq lst (Remote>>LM:getfiles:updatefilelist 
                                    (set_tile "dir" 
                                              (setq dir (Remote>>LM:getfiles:fixdir $value))
                                    )
                                    ext
                                    rtn
                                  )
                              rtn (Remote>>LM:getfiles:updateselected dir rtn)
                        )
                      )
                   )
      )

      (action_tile "box1" 
                   (vl-prin1-to-string 
                     '((lambda (/ itm tmp) 
                         (if 
                           (setq itm (mapcar '(lambda (n) (nth n lst)) 
                                             (read (strcat "(" $value ")"))
                                     )
                           )
                           (if (= 4 $reason) 
                             (cond 
                               ((equal '("..") itm)
                                (setq lst (Remote>>LM:getfiles:updatefilelist 
                                            (set_tile "dir" 
                                                      (setq dir (Remote>>LM:getfiles:updir 
                                                                  dir
                                                                )
                                                      )
                                            )
                                            ext
                                            rtn
                                          )
                                      rtn (Remote>>LM:getfiles:updateselected dir rtn)
                                )
                               )
                               ((vl-file-directory-p 
                                  (setq tmp (Remote>>LM:getfiles:checkredirect 
                                              (strcat dir "\\" (car itm))
                                            )
                                  )
                                )
                                (setq lst (Remote>>LM:getfiles:updatefilelist 
                                            (set_tile "dir" (setq dir tmp))
                                            ext
                                            rtn
                                          )
                                      rtn (Remote>>LM:getfiles:updateselected dir rtn)
                                )
                               )
                               ((setq rtn (Remote>>LM:getfiles:sort 
                                            (append rtn 
                                                    (mapcar 
                                                      '(lambda (x) 
                                                         (strcat dir "\\" x)
                                                       )
                                                      itm
                                                    )
                                            )
                                          )
                                      rtn (Remote>>LM:getfiles:updateselected dir rtn)
                                      lst (Remote>>LM:getfiles:updatefilelist 
                                            dir
                                            ext
                                            rtn
                                          )
                                )
                               )
                             )
                             (if 
                               (vl-every 
                                 '(lambda (x) 
                                    (vl-file-directory-p (strcat dir "\\" x))
                                  )
                                 itm
                               )
                               (mode_tile "add" 1)
                               (mode_tile "add" 0)
                             )
                           )
                         )
                       )
                      )
                   )
      )

      (action_tile "box2" 
                   (vl-prin1-to-string 
                     '((lambda (/ itm) 
                         (if 
                           (setq itm (mapcar '(lambda (n) (nth n rtn)) 
                                             (read (strcat "(" $value ")"))
                                     )
                           )
                           (if (= 4 $reason) 
                             (setq rtn (Remote>>LM:getfiles:updateselected 
                                         dir
                                         (vl-remove (car itm) rtn)
                                       )
                                   lst (Remote>>LM:getfiles:updatefilelist dir ext rtn)
                             )
                             (mode_tile "del" 0)
                           )
                         )
                       )
                      )
                   )
      )

      (action_tile "add" 
                   (vl-prin1-to-string 
                     '((lambda (/ itm) 
                         (if 
                           (setq itm (vl-remove-if 'vl-file-directory-p 
                                                   (mapcar '(lambda (n) (nth n lst)) 
                                                           (read 
                                                             (strcat "(" 
                                                                     (get_tile "box1")
                                                                     ")"
                                                             )
                                                           )
                                                   )
                                     )
                           )
                           (setq rtn (Remote>>LM:getfiles:sort 
                                       (append rtn 
                                               (mapcar 
                                                 '(lambda (x) (strcat dir "\\" x))
                                                 itm
                                               )
                                       )
                                     )
                                 rtn (Remote>>LM:getfiles:updateselected dir rtn)
                                 lst (Remote>>LM:getfiles:updatefilelist dir ext rtn)
                           )
                         )
                         (mode_tile "add" 1)
                         (mode_tile "del" 1)
                       )
                      )
                   )
      )

      (action_tile "del" 
                   (vl-prin1-to-string 
                     '((lambda (/ itm) 
                         (if (setq itm (read (strcat "(" (get_tile "box2") ")"))) 
                           (setq rtn (Remote>>LM:getfiles:updateselected 
                                       dir
                                       (Remote>>LM:getfiles:removeitems itm rtn)
                                     )
                                 lst (Remote>>LM:getfiles:updatefilelist dir ext rtn)
                           )
                         )
                         (mode_tile "add" 1)
                         (mode_tile "del" 1)
                       )
                      )
                   )
      )

      (if (zerop (start_dialog)) 
        (setq rtn nil)
      )
    )
  )
  (*error* nil)
  rtn
)
 
(defun Remote>>LM:getfiles:listbox (key lst) 
  (start_list key)
  (foreach x lst (add_list x))
  (end_list)
  lst
)
 
(defun Remote>>LM:getfiles:listfiles (dir ext lst) 
  (vl-remove-if '(lambda (x) (member (strcat dir "\\" x) lst)) 
                (cond 
                  ((cdr (assoc dir dirdata)))
                  ((cdar 
                     (setq dirdata (cons 
                                     (cons dir 
                                           (append 
                                             (Remote>>LM:getfiles:sortlist 
                                               (vl-remove "." 
                                                          (vl-directory-files dir 
                                                                              nil
                                                                              -1
                                                          )
                                               )
                                             )
                                             (Remote>>LM:getfiles:sort 
                                               (if (member ext '(("") ("*"))) 
                                                 (vl-directory-files dir nil 1)
                                                 (vl-remove-if-not 
                                                   (function 
                                                     (lambda (x / e) 
                                                       (and 
                                                         (setq e (vl-filename-extension 
                                                                   x
                                                                 )
                                                         )
                                                         (setq e (strcase 
                                                                   (substr e 
                                                                           2
                                                                   )
                                                                 )
                                                         )
                                                         (vl-some 
                                                           '(lambda (w) 
                                                              (wcmatch e 
                                                                       w
                                                              )
                                                            )
                                                           ext
                                                         )
                                                       )
                                                     )
                                                   )
                                                   (vl-directory-files dir nil 1)
                                                 )
                                               )
                                             )
                                           )
                                     )
                                     dirdata
                                   )
                     )
                   )
                  )
                )
  )
)
 
(defun Remote>>LM:getfiles:checkredirect (dir / itm pos) 
  (cond 
    ((vl-directory-files dir) dir)
    ((and 
       (= (strcase (getenv "UserProfile")) 
          (strcase (substr dir 1 (setq pos (vl-string-position 92 dir nil t))))
       )
       (setq itm (cdr 
                   (assoc (substr (strcase dir t) (+ pos 2)) 
                          '(("my documents" . "Documents")
                            ("my pictures" . "Pictures")
                            ("my videos" . "Videos")
                            ("my music" . "Music")
                           )
                   )
                 )
       )
       (vl-file-directory-p (setq itm (strcat (substr dir 1 pos) "\\" itm)))
     )
     itm
    )
    (dir)
  )
)
 
(defun Remote>>LM:getfiles:sort (lst) 
  (apply 'append 
         (mapcar 'Remote>>LM:getfiles:sortlist 
                 (vl-sort 
                   (Remote>>LM:getfiles:groupbyfunction 
                     lst
                     (lambda (a b / x y) 
                       (and 
                         (setq x (vl-filename-extension a))
                         (setq y (vl-filename-extension b))
                         (= (strcase x) (strcase y))
                       )
                     )
                   )
                   (function 
                     (lambda (a b / x y) 
                       (and 
                         (setq x (vl-filename-extension (car a)))
                         (setq y (vl-filename-extension (car b)))
                         (< (strcase x) (strcase y))
                       )
                     )
                   )
                 )
         )
  )
)
 
(defun Remote>>LM:getfiles:sortlist (lst) 
  (mapcar (function (lambda (n) (nth n lst))) 
          (vl-sort-i (mapcar 'Remote>>LM:getfiles:splitstring lst) 
                     (function 
                       (lambda (a b / x y) 
                         (while 
                           (and 
                             (setq x (car a))
                             (setq y (car b))
                             (= x y)
                           )
                           (setq a (cdr a)
                                 b (cdr b)
                           )
                         )
                         (cond 
                           ((null x) b)
                           ((null y) nil)
                           ((and (numberp x) (numberp y)) (< x y))
                           ((numberp x))
                           ((numberp y) nil)
                           ((< x y))
                         )
                       )
                     )
          )
  )
)
 
(defun Remote>>LM:getfiles:groupbyfunction (lst fun / tmp1 tmp2 x1) 
  (if (setq x1 (car lst)) 
    (progn 
      (foreach x2 (cdr lst) 
        (if (fun x1 x2) 
          (setq tmp1 (cons x2 tmp1))
          (setq tmp2 (cons x2 tmp2))
        )
      )
      (cons (cons x1 (reverse tmp1)) (Remote>>LM:getfiles:groupbyfunction (reverse tmp2) fun))
    )
  )
)
 
(defun Remote>>LM:getfiles:splitstring (str) 
  ((lambda (l) 
     (read 
       (strcat "(" 
               (vl-list->string 
                 (apply 'append 
                        (mapcar 
                          (function 
                            (lambda (a b c) 
                              (cond 
                                ((member b '(45 46 92))
                                 (list 32)
                                )
                                ((< 47 b 58)
                                 (list b)
                                )
                                ((list 32 34 b 34 32))
                              )
                            )
                          )
                          (cons nil l)
                          l
                          (append (cdr l) '(()))
                        )
                 )
               )
               ")"
       )
     )
   ) 
    (vl-string->list (strcase str))
  )
)
 
(defun Remote>>LM:getfiles:browseforfolder (msg dir flg / err fld pth shl slf) 
  (setq err (vl-catch-all-apply 
              (function 
                (lambda (/ app hwd) 
                  (if 
                    (setq app (vlax-get-acad-object)
                          shl (vla-getinterfaceobject app "shell.application")
                          hwd (vl-catch-all-apply 'vla-get-hwnd (list app))
                          fld (vlax-invoke-method shl 
                                                  'browseforfolder
                                                  (if (vl-catch-all-error-p hwd) 0 hwd)
                                                  msg
                                                  flg
                                                  dir
                              )
                    )
                    (setq slf (vlax-get-property fld 'self)
                          pth (Remote>>LM:getfiles:fixdir (vlax-get-property slf 'path))
                    )
                  )
                )
              )
            )
  )
  (if slf (vlax-release-object slf))
  (if fld (vlax-release-object fld))
  (if shl (vlax-release-object shl))
  (if (vl-catch-all-error-p err) 
    (prompt (vl-catch-all-error-message err))
    pth
  )
)
 
(defun Remote>>LM:getfiles:full->relative (dir path / p q) 
  (setq dir (vl-string-right-trim "\\" dir))
  (cond 
    ((and 
       (setq p (vl-string-position 58 dir))
       (setq q (vl-string-position 58 path))
       (/= (strcase (substr dir 1 p)) (strcase (substr path 1 q)))
     )
     path
    )
    ((and 
       (setq p (vl-string-position 92 dir))
       (setq q (vl-string-position 92 path))
       (= (strcase (substr dir 1 p)) (strcase (substr path 1 q)))
     )
     (Remote>>LM:getfiles:full->relative (substr dir (+ 2 p)) (substr path (+ 2 q)))
    )
    ((and 
       (setq q (vl-string-position 92 path))
       (= (strcase dir) (strcase (substr path 1 q)))
     )
     (strcat ".\\" (substr path (+ 2 q)))
    )
    ((= "" dir)
     path
    )
    ((setq p (vl-string-position 92 dir))
     (Remote>>LM:getfiles:full->relative (substr dir (+ 2 p)) (strcat "..\\" path))
    )
    ((Remote>>LM:getfiles:full->relative "" (strcat "..\\" path)))
  )
)
 
(defun Remote>>LM:getfiles:str->lst (str del / pos) 
  (if (setq pos (vl-string-search del str)) 
    (cons (substr str 1 pos) (Remote>>LM:getfiles:str->lst (substr str (+ pos 1 (strlen del))) del))
    (list str)
  )
)
 
(defun Remote>>LM:getfiles:updatefilelist (dir ext lst) 
  (Remote>>LM:getfiles:listbox "box1" (Remote>>LM:getfiles:listfiles dir ext lst))
)
 
(defun Remote>>LM:getfiles:updateselected (dir lst) 
  (Remote>>LM:getfiles:listbox "box2" (mapcar '(lambda (x) (Remote>>LM:getfiles:full->relative dir x)) lst))
  lst
)
 
(defun Remote>>LM:getfiles:updir (dir) 
  (substr dir 1 (vl-string-position 92 dir nil t))
)
 
(defun Remote>>LM:getfiles:fixdir (dir) 
  (vl-string-right-trim "\\" (vl-string-translate "/" "\\" dir))
)
 
(defun Remote>>LM:getfiles:removeitems (itm lst / idx) 
  (setq idx -1)
  (vl-remove-if '(lambda (x) (member (setq idx (1+ idx)) itm)) lst)
)
;#endregion
;#region Get Layer Status
;;-------------------------=={ Get Layer Status }==------------------------;;

;;  GetLayerStatus  -  Lee Mac
;;  Returns a list of dotted pairs detailing the status of each layer in a drawing.
;;  Returns: [str] Full filename of file if found, else nil.
;;  Author: Lee Mac, Copyright © 2010 - www.lee-mac.com


(defun Remote>>LM:GetLayerStatus (/ FindBits List->String cAssoc IterateLayers) 

  (defun FindBits (n / b) 
    (if (< 0 n) 
      (cons 
        (setq b (expt 2 
                      (fix (/ (log n) (log 2)))
                )
        )
        (FindBits (- n b))
      )
    )
  )

  (defun List->String (lst del) 
    (if (cdr lst) 
      (strcat (car lst) del (List->String (cdr lst) del))
      (car lst)
    )
  )

  (defun cAssoc (key lst) (cdr (assoc key lst)))

  (defun IterateLayers (def) 
    ((lambda (status) 
       (if def 
         (cons 
           (cons (cAssoc 2 def) 
                 (List->String 
                   (apply 'append 
                          (cons (list (if (minusp (cAssoc 62 def)) "Off" "On")) 
                                (mapcar 
                                  (function 
                                    (lambda (c) (list (cAssoc c status)))
                                  )
                                  (FindBits (logand (cAssoc 70 def) (~ 112)))
                                )
                          )
                   )
                   ","
                 )
           )
           (IterateLayers (tblnext "LAYER"))
         )
       )
     ) 
      '((1 . "Frozen")
        (2 . "Frozen in VP")
        (4 . "Locked")
       )
    )
  )

  (foreach x (IterateLayers (tblnext "LAYER" T)) 
    (if (cdr x) (print x))
  )
  (princ)
)

;#endregion
;#region Get Syntax
;;-------------------------=={ Get Syntax }==------------------------;;

;;--------------------=={ Get Syntax }==----------------------;;
;;                                                            ;;
;;  Returns a list of syntax for all defined commands in a    ;;
;;  supplied LISP file.                                       ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  file - filename of LISP file to read                      ;;
;;------------------------------------------------------------;;
;;  Returns:  List of defined commands in supplied LISP file  ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:GetSyntax (file / _GetSyntax line syntax) 

  (defun _GetSyntax (p s / x) 
    (if (setq x (vl-string-search p s)) 
      (cons 
        (substr (setq s (substr s (+ x 1 (strlen p)))) 
                1
                (setq x (car 
                          (vl-sort 
                            (vl-remove 'nil 
                                       (mapcar 
                                         (function 
                                           (lambda (d) (vl-string-position d s))
                                         )
                                         '(32 9 40 41)
                                       )
                            )
                            '<
                          )
                        )
                )
        )
        (if x (_GetSyntax p (substr s (1+ x))))
      )
    )
  )

  (if (setq file (open file "r")) 
    (apply 'append 
           (progn 
             (while (setq line (read-line file)) 
               (setq syntax (cons (_GetSyntax "(DEFUN C:" (strcase line)) syntax))
             )
             (setq file (close file))
             (reverse syntax)
           )
    )
  )
)

;#endregion
;#region Get True Content
;;-------------------------=={ Get True Content }==------------------------;;

;;------------------=={ Get True Content }==------------------;;
;;                                                            ;;
;;  Returns the unformatted string associated with the        ;;
;;  supplied entity, in formats compatible with Text & MText  ;;
;;  objects.                                                  ;;
;;                                                            ;;
;;  The arguments *dtextstring & *mtextstring should be       ;;
;;  supplied with quoted symbols (other than those symbols    ;;
;;  used by the arguments themselves). The unformatted        ;;
;;  strings suitable for Text & MText objects will henceforth ;;
;;  be bound to the supplied symbol arguments respectively.   ;;
;;                                                            ;;
;;  Note that it is the caller's responsibility to create and ;;
;;  release the RegularExpressions (Remote>>gc:RegExp) object. This      ;;
;;  object may be created using the                           ;;
;;  Programmatic Identifier: "VBScript.RegExp".               ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2010 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  RegExp       - RegularExpressions (Remote>>gc:RegExp) Object         ;;
;;  entity       - Ename whose text content is to be returned ;;
;;  *dtextstring - (output) Unformatted string compatible     ;;
;;                 with Text entities                         ;;
;;  *mtextstring - (output) Unformatted string compatible     ;;
;;                 with MText entities                        ;;
;;------------------------------------------------------------;;
;;  Returns:    This function always returns nil              ;;
;;------------------------------------------------------------;;
 
(defun Remote>>LM:GetTrueContent (Remote>>gc:RegExp entity *dtextstring *mtextstring / _Replace _AllowsFormatting 
                                  _GetTextString
                                 ) 

  (defun _Replace (new old string) 
    (vlax-put-property RegExp 'pattern old)
    (vlax-invoke RegExp 'replace string new)
  )

  (defun _AllowsFormatting (entity / object) 
    (or (wcmatch (cdr (assoc 0 (entget entity))) "MTEXT,MULTILEADER") 
        (and 
          (eq "ATTRIB" (cdr (assoc 0 (entget entity))))
          (vlax-property-available-p (setq object (vlax-ename->vla-object entity)) 'MTextAttribute)
          (eq :vlax-true (vla-get-MTextAttribute object))
        )
    )
  )

  (defun _GetTextString (entity) 
    ((lambda (entity / _type elist) 
       (cond 
         ((wcmatch (setq _type (cdr (assoc 0 (setq elist (entget entity))))) "TEXT,*DIMENSION")

          (cdr (assoc 1 (reverse elist)))
         )
         ((eq "MULTILEADER" _type)

          (cdr (assoc 304 elist))
         )
         ((wcmatch _type "ATTRIB,MTEXT")

          ((lambda (string) 
             (mapcar 
               (function 
                 (lambda (pair) 
                   (if (member (car pair) '(1 3)) 
                     (setq string (strcat string (cdr pair)))
                   )
                 )
               )
               elist
             )
             string
           ) 
            ""
          )
         )
       )
     ) 
      (if (eq 'VLA-OBJECT (type entity)) 
        (vlax-vla-object->ename entity)
        entity
      )
    )
  )

  ((lambda (string) 
     (if string 
       (progn 
         (mapcar 
           (function 
             (lambda (x) (vlax-put-property RegExp (car x) (cdr x)))
           )
           (list (cons 'global actrue) (cons 'ignorecase acfalse) (cons 'multiline actrue))
         )
         (if (_AllowsFormatting entity) 
           (mapcar 
             (function 
               (lambda (x) (setq string (_Replace (car x) (cdr x) string)))
             )
             '(("Ð" . "\\\\\\\\")
               (" " . "\\\\P|\\n|\\t")
               ("$1" . "\\\\(\\\\[ACcFfHLlOopQTW])|\\\\[ACcFfHLlOopQTW][^\\\\;]*;|\\\\[ACcFfHLlOopQTW]")
               ("$1$2/$3" . "([^\\\\])\\\\S([^;]*)[/#\\^]([^;]*);")
               ("$1$2" . "\\\\(\\\\S)|[\\\\](})|}")
               ("$1" . "[\\\\]({)|{")
              )
           )
           (setq string (_Replace "" "%%[OoUu]" (_Replace "Ð" "\\\\" string)))
         )
         (set *mtextstring (_Replace "\\\\" "Ð" (_Replace "\\$1$2$3" "(\\\\[ACcFfHLlOoPpQSTW])|({)|(})" string)))
         (set *dtextstring (_Replace "\\" "Ð" string))
       )
     )
   ) 
    (_GetTextString entity)
  )
  nil
)

;#endregion
;#region Group List by Number
;;-------------------------=={ Group List by Number }==------------------------;;

;; Group by Number (Recursive)  -  Lee Mac
;; Groups a list 'l' into a list of lists, each of max length 'n'

(defun Remote>>LM:group<n-r (l n) 
  (if l (Remote>>LM:group<n-sub (cons nil l) n n))
)


(defun Remote>>LM:group<n-sub (l m n) 
  (if (and (cdr l) (< 0 n)) 
    (Remote>>LM:group<n-sub (cons (cons (cadr l) (car l)) (cddr l)) m (1- n))
    (cons (reverse (car l)) (Remote>>LM:group<n (cdr l) m))
  )
)


;; Group by Number  -  Lee Mac
;; Groups a list 'l' into a list of lists, each of max length 'n'

(defun Remote>>LM:group<n (l n / a b m) 
  (while l 
    (setq m n)
    (while (and l (< 0 m)) 
      (setq a (cons (car l) a)
            l (cdr l)
            m (1- m)
      )
    )
    (setq b (cons (reverse a) b)
          a nil
    )
  )
  (reverse b)
)


;; Group by Number (Recursive)  -  Lee Mac
;; Groups a list 'l' into a list of lists, each of length 'n'

(defun Remote>>LM:group-n-r (l n / r) 
  (if l 
    (cons 
      (reverse 
        (repeat n 
          (setq r (cons (car l) r)
                l (cdr l)
          )
          r
        )
      )
      (Remote>>LM:group-n l n)
    )
  )
)


;; Group by Number  -  Lee Mac
;; Groups a list 'l' into a list of lists, each of length 'n'

(defun Remote>>LM:group-n (l n / a b) 
  (while l 
    (repeat n 
      (setq a (cons (car l) a)
            l (cdr l)
      )
    )
    (setq b (cons (reverse a) b)
          a nil
    )
  )
  (reverse b)
)

;#endregion
;#region GrSnap
;;-------------------------=={ GrSnap }==------------------------;;

;; Object Snap for grread: Snap Function  -  Lee Mac
;; Returns: [fun] A function requiring two arguments:
;; p - [lst] UCS Point to be snapped
;; o - [int] Object Snap bit code
;; The returned function returns either the snapped point (displaying an appropriate snap symbol)
;; or the supplied point if the snap failed for the given Object Snap bit code.
 
(defun Remote>>LM:grsnap:snapfunction () 
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
                                                         (and (= (car a) (logand (car a) o)) 
                                                              (setq b (osnap p (cdr a)))
                                                         )
                                                         (list (distance p b) b (car a))
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
                      (list 'Remote>>LM:grsnap:displaysnap 
                            '(car q)
                            (list 'cdr 
                                  (list 'assoc 
                                        '(cadr q)
                                        (list 'quote 
                                              (Remote>>LM:grsnap:snapsymbols 
                                                (atoi (cond ((getenv "AutoSnapSize")) ("5")))
                                              )
                                        )
                                  )
                            )
                            (Remote>>LM:OLE->ACI 
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
 
(defun Remote>>LM:grsnap:displaysnap (pnt lst col / scl) 
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
 
(defun Remote>>LM:grsnap:snapsymbols (p / -p -q -r a c i l q r) 
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
    (list 8192 (list r 1) (list -r -q) (list r 0) (list -r -r) (list r q) (list -r -1) (list r r) (list -r 0))
  )
)
 
;; Object Snap for grread: Parse Point  -  Lee Mac
;; bpt - [lst] Basepoint for relative point input, e.g. @5,5
;; str - [str] String representing point input
;; Returns: [lst] Point represented by the given string, else nil
 
(defun Remote>>LM:grsnap:parsepoint (bpt str / str->lst lst) 

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
 
(defun Remote>>LM:grsnap:snapmode (str) 
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

;#endregion
;#region GrText
;;-------------------------=={ GrText }==------------------------;;

;;-----------------------=={ GrText }==-----------------------;;
;;                                                            ;;
;;  Returns a grvecs pixel vector list relative to the origin ;;
;;  encoding the supplied string.                             ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2013 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  With thanks to ElpanovEvgeniy for the method of vector    ;;
;;  encoding to save me a lot of typing.                      ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  str - String to be expressed in vector list format.       ;;
;;------------------------------------------------------------;;
;;  Returns:  GrVecs Pixel Vector List relative to the Origin ;;
;;------------------------------------------------------------;;
;;  Version 1.1    -    26-03-2011                            ;;
;;------------------------------------------------------------;;
 
(defun Remote>>LM:GrText (str / asc lst vec xco yco) 
  (setq vec '((033 045 045 065 135)
              (034 104 134 107 137)
              (035 043 063 046 066 084 094 087 097 115 135 118 138 072 078 103 109)
              (036 025 035 052 052 043 047 058 078 083 087 092 112 123 127 118 118 135 135)
              (037 052 052 063 063 074 074 085 085 096 096 107 107 118 118 129 129 047 048 067 068 056 056 059 059 113 
                   114 133 134 122 122 125 125
              )
              (038 043 046 049 049 052 072 057 058 067 068 076 076 079 079 083 083 085 085 094 094 103 123 134 136 127 
                   127
              )
              (039 105 135)
              (040 017 017 026 036 045 105 116 126 137 137)
              (041 014 014 025 035 046 106 115 125 134 134)
              (042 073 074 076 077 084 086 092 098 104 106 113 114 116 117)
              (043 055 115 082 084 086 088)
              (044 034 035 045 046 055 057)
              (045 083 088)
              (046 045 046 055 056)
              (047 052 052 063 063 074 074 085 085 096 096 107 107 118 118 129 129)
              (048 044 047 134 137 053 123 058 128)
              (049 044 048 124 125 056 136)
              (050 043 048 053 053 064 064 075 075 086 086 097 097 108 128 134 137 123 123)
              (051 053 053 044 047 058 088 095 097 108 128 134 137 123 123)
              (052 046 048 057 137 078 078 073 076 083 083 094 094 105 115 126 126)
              (053 053 053 044 047 058 088 094 097 093 133 134 138)
              (054 044 047 058 088 095 097 084 084 053 113 124 124 135 137)
              (055 044 054 065 075 086 096 107 117 128 138 133 137 123 123)
              (056 044 047 094 097 134 137 053 083 058 088 103 123 108 128)
              (057 044 046 057 057 068 128 097 097 084 086 134 137 093 123)
              (058 045 046 055 056 095 096 105 106)
              (059 034 035 045 046 055 057 095 096 105 106)
              (060 047 047 056 056 065 065 074 074 083 083 094 094 105 105 116 116 127 127)
              (061 073 078 093 098)
              (062 043 043 054 054 065 065 076 076 087 087 096 096 105 105 114 114 123 123)
              (063 045 045 065 075 086 086 097 097 108 128 134 137 123 123)
              (064 034 038 043 043 052 112 123 123 134 137 128 128 079 119 068 068 065 066 105 106 077 107 074 094)
              (065 041 043 047 049 052 062 058 068 073 077 083 093 087 097 104 114 106 116 125 135 133 134)
              (066 042 047 053 123 058 088 108 128 094 097 132 137)
              (067 044 047 053 053 058 058 062 112 123 123 134 136 127 127 108 138)
              (068 042 046 057 057 127 127 132 136 068 118 053 123)
              (069 042 048 058 058 094 095 086 106 132 137 128 138 053 123)
              (070 042 045 094 095 086 106 132 137 128 138 053 123)
              (071 044 047 053 053 058 078 086 089 062 112 123 123 134 136 127 127 108 138)
              (072 041 043 047 049 131 133 137 139 093 097 052 122 058 128)
              (073 043 047 133 137 055 125)
              (074 052 062 043 046 057 127 135 139)
              (075 042 044 048 049 132 134 136 138 053 123 084 085 095 095 106 116 127 127 076 076 067 067 058 058)
              (076 042 047 048 058 053 123 132 135)
              (077 041 043 047 049 052 122 058 128 131 132 138 139 103 113 107 117 084 094 086 096 065 075)
              (078 041 044 131 132 136 139 052 122 048 128 113 113 094 104 085 085 066 076 057 057)
              (079 044 046 053 053 057 057 123 123 127 127 134 136 062 112 068 118)
              (080 042 045 084 087 132 137 053 123 098 128)
              (081 134 136 123 123 127 127 112 062 118 068 053 053 057 057 044 046 035 036 023 024 027 028)
              (082 042 044 048 049 132 137 123 053 128 098 084 087 076 076 067 067 058 058)
              (083 042 062 053 053 044 047 058 078 086 087 093 095 102 122 133 136 127 127 118 138)
              (084 043 047 055 125 132 138 131 121 139 129)
              (085 044 046 052 053 057 058 062 122 068 128 131 133 137 139)
              (086 045 055 064 074 066 076 083 103 087 107 112 122 118 128 131 133 137 139)
              (087 043 063 047 067 072 092 074 094 076 096 078 098 101 121 105 115 109 129 131 132 138 139)
              (088 041 043 047 049 131 133 137 139 052 052 058 058 063 063 067 067 074 074 076 076 085 095 104 104 106 
                   106 113 113 117 117 122 122 128 128
              )
              (089 043 047 055 085 094 094 096 096 103 113 107 117 122 122 128 128 131 133 137 139)
              (090 122 122 058 058 132 138 042 048 128 128 052 052 063 063 074 074 085 095 106 106 117 117)
              (091 015 017 135 137 025 125)
              (092 122 122 113 113 104 104 095 095 086 086 077 077 068 068 059 059)
              (093 014 016 134 136 026 126)
              (094 102 102 113 113 124 124 135 135 126 126 117 117 108 108)
              (095 021 029)
              (096 125 125 134 134)
              (097 043 046 048 048 052 072 057 097 083 086 103 106)
              (098 042 043 045 046 054 054 057 058 068 098 097 097 105 106 094 094 132 132 053 133)
              (099 044 046 053 053 057 058 052 092 093 093 104 106 097 098 108 108)
              (100 044 045 047 048 052 092 053 053 056 056 093 093 104 105 096 096 136 136 057 137)
              (101 044 046 053 053 057 058 052 092 093 093 104 106 097 098 088 088 073 078)
              (102 043 046 054 124 093 093 095 096 135 137 128 128)
              (103 013 016 022 032 027 097 107 108 066 066 096 096 054 055 104 105 063 063 093 093 062 092)
              (104 042 044 046 048 057 097 053 133 132 132 094 094 105 106)
              (105 043 047 055 105 103 104 135 135)
              (106 022 022 013 015 026 106 104 105 136 136)
              (107 042 044 046 048 053 133 132 132 057 057 066 066 074 075 085 085 096 106 107 108)
              (108 043 047 055 135 133 134)
              (109 041 043 045 046 048 049 052 102 055 105 058 108 101 101 093 093 104 104 096 096 107 107)
              (110 042 044 046 048 053 103 057 097 102 102 094 094 105 106)
              (111 044 046 104 106 053 053 057 057 093 093 097 097 052 092 058 098)
              (112 012 015 023 103 102 102 054 054 094 094 045 046 105 106 057 058 097 098 068 088)
              (113 015 018 027 107 108 108 056 056 096 096 044 045 104 105 052 053 092 093 062 082)
              (114 042 046 054 104 102 103 095 095 106 108 099 099)
              (115 052 052 043 047 058 068 073 077 082 092 103 107 098 098)
              (116 045 047 058 058 054 124 102 103 105 107)
              (117 102 102 106 106 053 103 056 056 044 045 047 107 048 048)
              (118 045 045 054 064 056 066 073 083 077 087 092 092 098 098 101 103 107 109)
              (119 043 053 047 057 062 092 064 084 066 086 068 098 101 103 095 105 107 109)
              (120 042 044 046 048 102 104 106 108 053 053 057 057 093 093 097 097 064 064 066 066 084 084 086 086 075 
                   075
              )
              (121 012 013 024 024 035 045 054 064 056 066 073 083 077 087 092 092 098 098 101 103 107 109)
              (122 092 092 058 058 102 108 042 048 097 097 086 086 075 075 064 064 053 053)
              (123 016 017 025 065 073 074 085 125 136 137)
              (124 015 135)
              (125 014 015 026 066 077 078 086 126 134 135)
              (126 112 122 133 134 125 125 116 117 128 138)
              (145 114 116 125 126 136 137)
              (146 114 115 125 126 135 137)
              (161 045 115 135 135)
              (162 026 036 045 047 058 058 054 054 053 093 094 094 098 098 105 107 116 126)
              (163 043 048 054 074 083 086 094 094 103 123 134 136 117 127)
              (164 083 083 088 088 133 133 138 138 094 097 124 127 104 114 107 117)
              (165 044 046 055 075 081 089 094 094 096 096 101 103 107 109 113 113 117 117 122 122 128 128 131 133 137 
                   139
              )
              (166 015 055 095 135)
              (167 042 042 032 036 047 047 056 057 065 065 074 074 083 083 092 102 068 078 087 087 096 096 105 105 113 
                   114 123 123 134 138 128 128
              )
              (168 134 134 137 137)
              (169 054 057 063 063 068 068 072 122 079 129 133 133 138 138 144 147 075 076 087 087 084 114 125 126 117 
                   117
              )
              (170 063 067 084 086 088 088 093 103 097 127 114 116 134 136)
              (171 055 055 064 064 073 073 082 082 093 093 104 104 115 115 058 058 067 067 076 076 085 085 096 096 107 
                   107 118 118
              )
              (172 068 098 092 097)
              (173 083 088)
              (174 054 057 063 063 068 068 072 122 079 129 133 133 138 138 144 147 074 124 095 096 125 126 077 087 107 
                   117
              )
              (175 151 159)
              (176 105 106 114 124 117 127 135 136)
              (177 042 048 092 098 065 085 105 125)
              (178 084 087 095 095 106 106 117 127 135 136 124 124)
              (179 094 094 085 086 097 107 116 116 127 127 135 136 124 124)
              (180 125 125 136 136)
              (181 012 012 023 113 044 047 049 049 058 118)
              (182 045 045 049 049 048 128 046 126 133 139 122 125 112 115 102 105 092 095 083 085)
              (183 085 086 095 096)
              (184 014 015 026 026 035 035)
              (185 084 086 124 124 095 135)
              (186 063 067 084 086 134 136 093 123 097 127)
              (187 052 052 063 063 074 074 085 085 094 094 103 103 112 112 055 055 066 066 077 077 088 088 097 097 106 
                   106 115 115
              )
              (188 048 098 059 059 055 057 065 065 076 076 087 087 083 133 122 122 052 052 063 063 074 074 085 085 096 
                   096 107 107 118 118 129 129
              )
              (189 046 049 057 057 068 068 079 089 097 098 086 086 083 133 122 122 052 052 063 063 074 074 085 085 096 
                   096 107 107 118 118 129 129
              )
              (190 048 098 059 059 055 057 065 065 076 076 087 087 092 092 083 084 095 105 114 114 125 125 133 134 122 
                   122 052 052 063 063 074 074 085 085 096 096 107 107 118 118 129 129
              )
              (191 044 047 058 058 053 073 084 084 095 095 106 116 136 136)
              (192 041 043 047 049 052 062 058 068 073 077 083 093 087 097 104 114 106 116 125 135 133 134 155 155 164 
                   164
              )
              (193 041 043 047 049 052 062 058 068 073 077 083 093 087 097 104 114 106 116 125 135 133 134 155 155 166 
                   166
              )
              (194 041 043 047 049 052 062 058 068 073 077 083 093 087 097 104 114 106 116 125 135 133 134 154 154 165 
                   165 156 156
              )
              (195 041 043 047 049 052 062 058 068 073 077 083 093 087 097 104 114 106 116 125 135 133 134 152 152 163 
                   165 155 157 168 168
              )
              (196 041 043 047 049 052 062 058 068 073 077 083 093 087 097 104 114 106 116 125 135 133 134 163 163 167 
                   167
              )
              (197 041 043 047 049 052 062 058 068 073 077 083 093 087 097 104 114 106 116 125 135 133 134 145 145 154 
                   154 165 165 156 156
              )
              (198 041 043 045 049 052 062 073 093 104 114 125 125 084 085 059 059 056 126 097 098 088 088 108 108 134 
                   139 129 129
              )
              (199 044 047 053 053 058 058 062 112 123 123 134 136 127 127 108 138 014 015 026 026 035 035)
              (200 042 048 058 058 094 095 086 106 132 137 128 138 053 123 156 156 165 165)
              (201 042 048 058 058 094 095 086 106 132 137 128 138 053 123 155 155 166 166)
              (202 042 048 058 058 094 095 086 106 132 137 128 138 053 123 154 154 165 166 157 157)
              (203 042 048 058 058 094 095 086 106 132 137 128 138 053 123 164 164 167 167)
              (204 043 047 133 137 055 125 155 155 164 164)
              (205 043 047 133 137 055 125 155 155 166 166)
              (206 043 047 133 137 055 125 154 154 165 165 156 156)
              (207 043 047 133 137 055 125 163 163 167 167)
              (208 042 046 057 057 127 127 132 136 068 118 053 123 091 092 094 095)
              (209 041 044 131 132 137 139 052 122 048 128 113 113 094 104 085 085 066 076 057 057 152 152 163 165 155 
                   157 168 168
              )
              (210 044 046 053 053 057 057 123 123 127 127 134 136 062 112 068 118 155 155 164 164)
              (211 044 046 053 053 057 057 123 123 127 127 134 136 062 112 068 118 155 155 166 166)
              (212 044 046 053 053 057 057 123 123 127 127 134 136 062 112 068 118 154 154 165 165 156 156)
              (213 044 046 053 053 057 057 123 123 127 127 134 136 062 112 068 118 152 152 163 165 155 157 168 168)
              (214 044 046 053 053 057 057 123 123 127 127 134 136 062 112 068 118 163 163 167 167)
              (215 052 052 063 063 074 074 085 085 096 096 107 107 118 118 058 058 067 067 076 076 094 094 103 103 112 
                   112
              )
              (216 044 046 053 053 057 057 123 123 127 127 134 136 062 112 068 118 043 043 064 074 085 095 106 116 137 
                   137
              )
              (217 044 046 052 053 057 058 062 122 068 128 131 133 137 139 155 155 164 164)
              (218 044 046 052 053 057 058 062 122 068 128 131 133 137 139 155 155 166 166)
              (219 044 046 052 053 057 058 062 122 068 128 131 133 137 139 154 154 165 165 156 156)
              (220 044 046 052 053 057 058 062 122 068 128 131 133 137 139 163 163 167 167)
              (221 044 046 055 085 094 094 096 096 103 113 107 117 122 122 128 128 131 133 137 139 145 155 166 166)
              (222 042 044 132 132 053 133 074 077 104 107 088 098)
              (223 042 042 043 123 134 136 107 127 095 096 087 087 058 078 045 047)
              (224 043 046 048 048 052 072 057 097 083 086 103 106 125 125 134 134)
              (225 043 046 048 048 052 072 057 097 083 086 103 106 125 125 136 136)
              (226 043 046 048 048 052 072 057 097 083 086 103 106 124 124 135 135 126 126)
              (227 043 046 048 048 052 072 057 097 083 086 103 106 122 122 133 134 125 126 137 137)
              (228 043 046 048 048 052 072 057 097 083 086 103 106 133 133 137 137)
              (229 043 046 048 048 052 072 057 097 083 086 103 106 125 125 134 134 145 145 136 136)
              (230 042 044 046 048 059 059 051 071 082 084 102 104 055 095 076 079 089 099 106 108)
              (231 014 015 026 026 035 035 044 046 053 053 057 058 052 092 093 093 104 106 097 098 108 108)
              (232 044 046 053 053 057 058 052 092 093 093 104 106 097 098 088 088 073 078 125 125 134 134)
              (233 044 046 053 053 057 058 052 092 093 093 104 106 097 098 088 088 073 078 125 125 136 136)
              (234 044 046 053 053 057 058 052 092 093 093 104 106 097 098 088 088 073 078 124 124 135 135 126 126)
              (235 044 046 053 053 057 058 052 092 093 093 104 106 097 098 088 088 073 078 133 133 137 137)
              (236 043 047 055 105 103 104 125 125 134 134)
              (237 043 047 055 105 103 104 124 124 135 135)
              (238 043 047 055 105 103 104 124 124 135 135 126 126)
              (239 043 047 055 105 103 104 133 133 136 136)
              (240 044 046 053 053 057 057 052 082 058 088 083 083 087 107 094 096 116 116 113 114 125 125 134 134 136 
                   137
              )
              (241 042 044 046 048 053 103 057 097 102 102 094 094 105 106 122 122 133 134 125 126 137 137)
              (242 044 046 104 106 053 053 057 057 093 093 097 097 052 092 058 098 125 125 134 134)
              (243 044 046 104 106 053 053 057 057 093 093 097 097 052 092 058 098 125 125 136 136)
              (244 044 046 104 106 053 053 057 057 093 093 097 097 052 092 058 098 124 124 135 135 126 126)
              (245 044 046 104 106 053 053 057 057 093 093 097 097 052 092 058 098 122 122 133 135 125 127 138 138)
              (246 044 046 104 106 053 053 057 057 093 093 097 097 052 092 058 098 133 133 137 137)
              (247 055 055 115 115 082 088)
              (248 044 046 104 106 053 053 057 057 093 093 097 097 052 092 058 098 042 042 064 064 075 075 086 086 108 
                   108
              )
              (249 102 102 106 106 053 103 056 056 044 045 047 107 048 048 125 125 134 134)
              (250 102 102 106 106 053 103 056 056 044 045 047 107 048 048 125 125 136 136)
              (251 102 102 106 106 053 103 056 056 044 045 047 107 048 048 124 124 135 135 126 126)
              (252 102 102 106 106 053 103 056 056 044 045 047 107 048 048 133 133 137 137)
              (253 012 013 024 024 035 045 054 064 056 066 073 083 077 087 092 092 098 098 101 103 107 109 125 125 136 
                   136
              )
              (254 012 015 132 132 023 133 054 054 045 046 057 058 068 088 094 094 105 106 097 098)
              (255 012 013 024 024 035 045 054 064 056 066 073 083 077 087 092 092 098 098 101 103 107 109 133 133 137 
                   137
              )
             )
  )
  (eval 
    (list 'defun 
          'Remote>>LM:GrText
          '(str / asc lst vec xco yco)
          (list 'setq 
                'vec
                (list 'quote 
                      (mapcar 
                        (function 
                          (lambda (b) 
                            (cons (car b) 
                                  (mapcar 
                                    (function 
                                      (lambda (a) 
                                        (list (rem a 10) (/ a 10))
                                      )
                                    )
                                    (cdr b)
                                  )
                            )
                          )
                        )
                        vec
                      )
                )
          )
          '(setq xco 0
                 yco 0
           )
          '(repeat (strlen str) 
             (setq asc (ascii str)
                   str (substr str 2)
             )
             (cond 
               ((= 32 asc)
                (setq xco (+ xco 09))
               )
               ((= 09 asc)
                (setq xco (+ xco 36))
               )
               ((= 10 asc)
                (setq xco 0
                      yco (- yco 16)
                )
               )
               ((setq lst (cons 
                            (mapcar 
                              (function 
                                (lambda (a) 
                                  (list (+ (car a) xco) (+ (cadr a) yco))
                                )
                              )
                              (cdr (assoc asc vec))
                            )
                            lst
                          )
                )
                (setq xco (+ xco 9))
               )
             )
           )
          '(apply 'append lst)
    )
  )
  (Remote>>LM:GrText str)
)

;#endregion
;#region Insert Nth
;;-------------------------=={ Insert Nth }==------------------------;;

;; Insert Nth (Recursive)  -  Lee Mac
;; Inserts an item at the nth position in a list.
;; x - [any] Item to be inserted
;; n - [int] Zero-based index at which to insert item
;; l - [lst] List in which item is to be inserted

(defun Remote>>LM:insertnth-r (x n l) 
  (cond 
    ((null l) nil)
    ((< 0 n) (cons (car l) (Remote>>LM:insertnth x (1- n) (cdr l))))
    ((cons x l))
  )
)


;; Insert Nth (Iterative)  -  Lee Mac
;; Inserts an item at the nth position in a list.
;; x - [any] Item to be inserted
;; n - [int] Zero-based index at which to insert item
;; l - [lst] List in which item is to be inserted

(defun Remote>>LM:insertnth (x n l / i) 
  (setq i -1)
  (apply 'append (mapcar '(lambda (a) (if (= n (setq i (1+ i))) (list x a) (list a))) l))
)
;#endregion
;#region Intersection Functions
;;-------------------------=={ Intersection Functions }==------------------------;;

;; Intersections  -  Lee Mac
;; Returns a list of all points of intersection between two objects
;; for the given intersection mode.
;; ob1,ob2 - [vla] VLA-Objects
;;     mod - [int] acextendoption enum of intersectwith method

(defun Remote>>LM:intersections (ob1 ob2 mod / lst rtn) 
  (if 
    (and (vlax-method-applicable-p ob1 'intersectwith) 
         (vlax-method-applicable-p ob2 'intersectwith)
         (setq lst (vlax-invoke ob1 'intersectwith ob2 mod))
    )
    (repeat (/ (length lst) 3) 
      (setq rtn (cons (list (car lst) (cadr lst) (caddr lst)) rtn)
            lst (cdddr lst)
      )
    )
  )
  (reverse rtn)
)


;; Intersections in Set  -  Lee Mac
;; Returns a list of all points of intersection between all objects in a supplied selection set.
;; sel - [sel] Selection Set

(defun Remote>>LM:intersectionsinset (sel / id1 id2 ob1 ob2 rtn) 
  (repeat (setq id1 (sslength sel)) 
    (setq ob1 (vlax-ename->vla-object (ssname sel (setq id1 (1- id1)))))
    (repeat (setq id2 id1) 
      (setq ob2 (vlax-ename->vla-object (ssname sel (setq id2 (1- id2))))
            rtn (cons (Remote>>LM:intersections ob1 ob2 acextendnone) rtn)
      )
    )
  )
  (apply 'append (reverse rtn))
)


;; Intersections in Object List  -  Lee Mac
;; Returns a list of all points of intersection between all objects in a list of VLA-Objects.
;; lst - [lst] List of VLA-Objects

(defun Remote>>LM:intersectionsinobjlist (lst / ob1 rtn) 
  (while (setq ob1 (car lst)) 
    (foreach ob2 (setq lst (cdr lst)) 
      (setq rtn (cons (Remote>>LM:intersections ob1 ob2 acextendnone) rtn))
    )
  )
  (apply 'append (reverse rtn))
)


;; Intersections Between Sets  -  Lee Mac
;; Returns a list of all points of intersection between objects in two selection sets.
;; ss1,ss2 - [sel] Selection sets

(defun Remote>>LM:intersectionsbetweensets (ss1 ss2 / id1 id2 ob1 ob2 rtn) 
  (repeat (setq id1 (sslength ss1)) 
    (setq ob1 (vlax-ename->vla-object (ssname ss1 (setq id1 (1- id1)))))
    (repeat (setq id2 (sslength ss2)) 
      (setq ob2 (vlax-ename->vla-object (ssname ss2 (setq id2 (1- id2))))
            rtn (cons (Remote>>LM:intersections ob1 ob2 acextendnone) rtn)
      )
    )
  )
  (apply 'append (reverse rtn))
)


;; Intersections Between Object Lists  -  Lee Mac
;; Returns a list of all points of intersection between objects in two lists of VLA-Objects.
;; ol1,ol2 - [lst] Lists of VLA-Objects

(defun Remote>>LM:intersectionsbetweenobjlists (ol1 ol2 / rtn) 
  (foreach ob1 ol1 
    (foreach ob2 ol2 
      (setq rtn (cons (Remote>>LM:intersections ob1 ob2 acextendnone) rtn))
    )
  )
  (apply 'append (reverse rtn))
)
;#endregion
;#region List Box
;;-------------------------=={ List Box }==------------------------;;

;; List Box  -  Lee Mac
;; Displays a DCL list box allowing the user to make a selection from the supplied data.
;; msg - [str] Dialog label
;; lst - [lst] List of strings to display
;; bit - [int] 1=allow multiple; 2=return indexes
;; Returns: [lst] List of selected items/indexes, else nil
 
(defun Remote>>LM:listbox (msg lst bit / dch des tmp rtn) 
  (cond 
    ((not 
       (and 
         (setq tmp (vl-filename-mktemp nil nil ".dcl"))
         (setq des (open tmp "w"))
         (write-line 
           (strcat "listbox:dialog{label=\"" 
                   msg
                   "\";spacer;:list_box{key=\"list\";multiple_select="
                   (if (= 1 (logand 1 bit)) "true" "false")
                   ";width=50;height=15;}spacer;ok_cancel;}"
           )
           des
         )
         (not (close des))
         (< 0 (setq dch (load_dialog tmp)))
         (new_dialog "listbox" dch)
       )
     )
     (prompt "\nError Loading List Box Dialog.")
    )
    (t
     (start_list "list")
     (foreach itm lst (add_list itm))
     (end_list)
     (setq rtn (set_tile "list" "0"))
     (action_tile "list" "(setq rtn $value)")
     (setq rtn (if (= 1 (start_dialog)) 
                 (if (= 2 (logand 2 bit)) 
                   (read (strcat "(" rtn ")"))
                   (mapcar '(lambda (x) (nth x lst)) (read (strcat "(" rtn ")")))
                 )
               )
     )
    )
  )
  (if (< 0 dch) 
    (unload_dialog dch)
  )
  (if (and tmp (setq tmp (findfile tmp))) 
    (vl-file-delete tmp)
  )
  rtn
)
;#endregion
;#region List Box Functions
;;-------------------------=={ List Box Functions }==------------------------;;

;; List Box: List Up  -  Lee Mac
;; Shifts the items at the supplied indexes by one position to a lower index
;; idx - [lst] List of zero-based indexes
;; lst - [lst] List of items
;; Returns: [lst] List of ((idx) (lst)) following operation
 
(defun Remote>>LM:listup (idx lst / foo) 
  (defun foo (cnt idx lst idx-out lst-out) 
    (cond 
      ((not (and idx lst))
       (list (reverse idx-out) (append (reverse lst-out) lst))
      )
      ((= 0 (car idx))
       (foo (1+ cnt) (mapcar '1- (cdr idx)) (cdr lst) (cons cnt idx-out) (cons (car lst) lst-out))
      )
      ((= 1 (car idx))
       (foo (1+ cnt) (mapcar '1- (cdr idx)) (cons (car lst) (cddr lst)) (cons cnt idx-out) (cons (cadr lst) lst-out))
      )
      ((foo (1+ cnt) (mapcar '1- idx) (cdr lst) idx-out (cons (car lst) lst-out)))
    )
  )
  (foo 0 idx lst nil nil)
)
 
;; List Box: List Down  -  Lee Mac
;; Shifts the items at the supplied indexes by one position to a higher index
;; idx - [lst] List of zero-based indexes
;; lst - [lst] List of items
;; Returns: [lst] List of ((idx) (lst)) following operation
 
(defun Remote>>LM:listdown (idx lst / bar foo len) 
  (setq len (length lst)
        foo (lambda (x) (- len x 1))
        bar (lambda (a b) (list (reverse (mapcar 'foo a)) (reverse b)))
  )
  (apply 'bar (apply 'Remote>>LM:listup (bar idx lst)))
)
 
;; List Box: List Top  -  Lee Mac
;; Shifts the items at the supplied indexes to the lowest index
;; idx - [lst] List of zero-based indexes
;; lst - [lst] List of items
;; Returns: [lst] List of ((idx) (lst)) following operation
 
(defun Remote>>LM:listtop (idx lst / i) 
  (setq i -1)
  (list 
    (mapcar '(lambda (x) (setq i (1+ i))) idx)
    (append (mapcar '(lambda (x) (nth x lst)) idx) (Remote>>LM:removeitems idx lst))
  )
)
 
;; List Box: List Bottom -  Lee Mac
;; Shifts the items at the supplied indexes to the highest index
;; idx - [lst] List of zero-based indexes
;; lst - [lst] List of items
;; Returns: [lst] List of ((idx) (lst)) following operation
 
(defun Remote>>LM:listbottom (idx lst / i) 
  (setq i (length lst))
  (list 
    (reverse (mapcar '(lambda (x) (setq i (1- i))) idx))
    (append (Remote>>LM:removeitems idx lst) (mapcar '(lambda (x) (nth x lst)) idx))
  )
)
 
;; Remove Items  -  Lee Mac
;; Removes the items at the supplied indexes from a given list
;; idx - [lst] List of zero-based indexes
;; lst - [lst] List from which items are to be removed
;; Returns: [lst] List with items at the supplied indexes removed
 
(defun Remote>>LM:removeitems (idx lst / i) 
  (setq i -1)
  (vl-remove-if '(lambda (x) (member (setq i (1+ i)) idx)) lst)
)

;#endregion
;#region List Box with Filter
;;-------------------------=={ List Box with Filter }==------------------------;;

;; Filtered List Box  -  Lee Mac
;; Displays a list box interface from which the user may select one or more items.
;; Includes an edit box filter to enable the user to filter the displayed list of items.
;; msg - [str] List box dialog title
;; lst - [lst] List of strings to display in the list box
;; mtp - [bol] T=Allow multiple items; nil=Single item selection
;; Returns: [lst] List of selected items, else nil
 
(defun Remote>>LM:filtlistbox (msg lst mtp / _addlist dch dcl des rtn sel tmp) 

  (defun _addlist (key lst) 
    (start_list key)
    (foreach x lst (add_list x))
    (end_list)
    lst
  )

  (if 
    (and 
      (setq dcl (vl-filename-mktemp nil nil ".dcl"))
      (setq des (open dcl "w"))
      (write-line 
        (strcat 
          "filtlistbox : dialog { label = \""
          msg
          "\"; spacer;"
          ": list_box { key = \"lst\"; width = 50; fixed_width = true; height = 15; fixed_height = true; allow_accept = true; "
          "multiple_select = "
          (if mtp "true" "false")
          "; }"
          ": edit_box { key = \"flt\"; width = 50; fixed_width = true; label = \"Filter:\"; }"
          "spacer; ok_cancel; }"
        )
        des
      )
      (not (close des))
      (< 0 (setq dch (load_dialog dcl)))
      (new_dialog "filtlistbox" dch)
    )
    (progn 
      (_addlist "lst" (setq tmp lst))
      (set_tile "lst" (setq rtn "0"))
      (set_tile "flt" "*")
      (action_tile "lst" "(setq rtn $value)")
      (action_tile "flt" 
                   (vl-prin1-to-string 
                     '(progn
                       (setq flt (strcat "*" (strcase $value) "*")
                             sel (mapcar '(lambda (n) (nth n tmp)) (read (strcat "(" rtn ")")))
                       )
                       (_addlist "lst" (setq tmp (vl-remove-if-not '(lambda (x) (wcmatch (strcase x) flt)) lst)))
                       (set_tile "lst" 
                                 (setq rtn (vl-string-trim "()" 
                                                           (vl-princ-to-string 
                                                             (cond 
                                                               ((vl-sort 
                                                                  (vl-remove nil 
                                                                             (mapcar '(lambda (x) (vl-position x tmp)) 
                                                                                     sel
                                                                             )
                                                                  )
                                                                  '<
                                                                )
                                                               )
                                                               ('(0))
                                                             )
                                                           )
                                           )
                                 )
                       )
                      )
                   )
      )
      (setq rtn (if (= 1 (start_dialog)) 
                  (mapcar '(lambda (x) (nth x tmp)) (read (strcat "(" rtn ")")))
                )
      )
    )
  )
  (if (< 0 dch) 
    (setq dch (unload_dialog dch))
  )
  (if (and (= 'str (type dcl)) (findfile dcl)) 
    (vl-file-delete dcl)
  )
  rtn
)
;#endregion
;#region List Difference
;;-------------------------=={ List Difference }==------------------------;;

;;-------------------=={ List Difference }==------------------;;
;;                                                            ;;
;;  Returns items appearing exclusively in one list but not   ;;
;;  another, i.e. the relative complement: l1 \ l2            ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  l1,l2 - lists for which to return the difference          ;;
;;------------------------------------------------------------;;
;;  Returns:  List of items appearing exclusively in list l1  ;;
;;------------------------------------------------------------;;
;;  Recursive

(defun Remote>>LM:ListDifference-r (l1 l2) 
  (if l1 
    (if (member (car l1) l2) 
      (Remote>>LM:ListDifference (cdr l1) l2)
      (cons (car l1) (Remote>>LM:ListDifference (cdr l1) l2))
    )
  )
)


;;-------------------=={ List Difference }==------------------;;
;;                                                            ;;
;;  Returns items appearing exclusively in one list but not   ;;
;;  another, i.e. the relative complement: l1 \ l2            ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  l1,l2 - lists for which to return the difference          ;;
;;------------------------------------------------------------;;
;;  Returns:  List of items appearing exclusively in list l1  ;;
;;------------------------------------------------------------;;
;;  Iterative

(defun Remote>>LM:ListDifference (l1 l2) 
  (vl-remove-if '(lambda (x) (member x l2)) l1)
)

;#endregion
;#region List Intersection
;;-------------------------=={ List Intersection }==------------------------;;

;;-----------------=={ List Intersection }==------------------;;
;;                                                            ;;
;;  Returns a list expressing the intersection of two lists   ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  l1,l2 - Lists for which to return the intersection        ;;
;;------------------------------------------------------------;;
;;  Returns:  A list of all items common to both lists        ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:ListIntersection-r (l1 l2) 
  (if l1 
    (if (member (car l1) l2) 
      (cons (car l1) (Remote>>LM:ListIntersection (cdr l1) l2))
      (Remote>>LM:ListIntersection (cdr l1) l2)
    )
  )
)

;;-----------------=={ List Intersection }==------------------;;
;;                                                            ;;
;;  Returns a list expressing the intersection of two lists   ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  l1,l2 - Lists for which to return the intersection        ;;
;;------------------------------------------------------------;;
;;  Returns:  A list of all items common to both lists        ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:ListIntersection (l1 l2) 
  (vl-remove-if-not '(lambda (x) (member x l2)) l1)
)
;#endregion
;#region List Symmetric Difference
;;-------------------------=={ List Symmetric Difference }==------------------------;;

;;--------------=={ List Symmetric Difference }==-------------;;
;;                                                            ;;
;;  Returns items appearing exclusively in each list and not  ;;
;;  in their intersection.                                    ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  l1,l2 - lists for which to return symmetric difference    ;;
;;------------------------------------------------------------;;
;;  Returns:  List of items in the set (l1\l2)U(l2\l1)        ;;
;;------------------------------------------------------------;;
;;  Recursive

(defun Remote>>LM:ListSymDifference-r (l1 l2 / sub) 
  (defun sub (a b) 
    (if a 
      (if (member (car a) b) 
        (sub (cdr a) b)
        (cons (car a) (sub (cdr a) b))
      )
    )
  )
  (append (sub l1 l2) (sub l2 l1))
)


;;--------------=={ List Symmetric Difference }==-------------;;
;;                                                            ;;
;;  Returns items appearing exclusively in each list and not  ;;
;;  in their intersection.                                    ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  l1,l2 - lists for which to return symmetric difference    ;;
;;------------------------------------------------------------;;
;;  Returns:  List of items in the set (l1\l2)U(l2\l1)        ;;
;;------------------------------------------------------------;;
;;  Iterative

(defun Remote>>LM:ListSymDifference (l1 l2) 
  (append 
    (vl-remove-if '(lambda (x) (member x l2)) l1)
    (vl-remove-if '(lambda (x) (member x l1)) l2)
  )
)


;;--------------=={ Lists Symmetric Difference }==------------;;
;;                                                            ;;
;;  Returns items appearing exclusively in each list and not  ;;
;;  in the intersection of any pair of lists.                 ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  l - list of lists for which to return the sym difference  ;;
;;------------------------------------------------------------;;
;;  Returns: List of (l1\(l2Ul3U..UlN)U(l2\(l1Ul3..UlN)U...   ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:ListsSymDifference-r (l / sub) 
  (defun sub (a b) 
    (if a 
      (if (vl-some '(lambda (x) (member (car a) x)) b) 
        (sub (cdr a) b)
        (cons (car a) (sub (cdr a) b))
      )
    )
  )
  (apply 'append 
         (mapcar 
           '(lambda (a / x) 
              (setq x (sub a (cdr l))
                    l (append (cdr l) (list a))
              )
              x
            )
           l
         )
  )
)


;;--------------=={ Lists Symmetric Difference }==------------;;
;;                                                            ;;
;;  Returns items appearing exclusively in each list and not  ;;
;;  in the intersection of any pair of lists.                 ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  l - list of lists for which to return the sym difference  ;;
;;------------------------------------------------------------;;
;;  Returns: List of (l1\(l2Ul3U..UlN)U(l2\(l1Ul3..UlN)U...   ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:ListsSymDifference (l) 
  (apply 'append 
         (mapcar 
           '(lambda (a / x) 
              (setq x (vl-remove-if 
                        '(lambda (b) (vl-some '(lambda (c) (member b c)) (cdr l)))
                        a
                      )
              )
              (setq l (append (cdr l) (list a)))
              x
            )
           l
         )
  )
)


(defun Remote>>LM:ListsSymDifference-so (l) 
  (Remote>>LM:ListDifference 
    (Remote>>LM:ListsUnion l)
    (Remote>>LM:ListsUnion 
      (mapcar 
        '(lambda (a) 
           (apply 'append 
                  (mapcar '(lambda (b) (Remote>>LM:ListIntersection a b)) (setq l (cdr l)))
           )
         )
        l
      )
    )
  )
)

;#endregion
;#region List to String
;;-------------------------=={ List to String }==------------------------;;

;; List to String (Recursive) -  Lee Mac
;; Concatenates each string in a supplied list, separated by a given delimiter
;; lst - [lst] List of strings to concatenate
;; del - [str] Delimiter string to separate each item

(defun Remote>>LM:lst->str (lst del) 
  (if (cdr lst) 
    (strcat (car lst) del (Remote>>LM:lst->str (cdr lst) del))
    (car lst)
  )
)


;; List to String (Iterative) -  Lee Mac
;; Concatenates each string in a supplied list, separated by a given delimiter
;; lst - [lst] List of strings to concatenate
;; del - [str] Delimiter string to separate each item

(defun Remote>>LM:lst->str~ (lst del / str) 
  (setq str (car lst))
  (foreach itm (cdr lst) (setq str (strcat str del itm)))
  str
)
;#endregion
;#region List Union
;;-------------------------=={ List Union }==------------------------;;

;;---------------------=={ List Union }==---------------------;;
;;                                                            ;;
;;  Returns a list expressing the union of two lists          ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  l1,l2 - Lists for which to return the union               ;;
;;------------------------------------------------------------;;
;;  Returns:  A list of all distinct items in the two lists   ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:ListUnion-r (l1 l2) 
  ((lambda (f) (f (append l1 l2))) 
    (lambda (l) (if l (cons (car l) (f (vl-remove (car l) (cdr l))))))
  )
)


;;---------------------=={ List Union }==---------------------;;
;;                                                            ;;
;;  Returns a list expressing the union of two lists          ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  l1,l2 - Lists for which to return the union               ;;
;;------------------------------------------------------------;;
;;  Returns:  A list of all distinct items in the two lists   ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:ListUnion (l1 l2 / x l) 
  (setq l1 (append l1 l2))
  (while (setq x (car l1)) 
    (setq l  (cons x l)
          l1 (vl-remove x l1)
    )
  )
  (reverse l)
)


;;---------------------=={ Lists Union }==--------------------;;
;;                                                            ;;
;;  Returns a list expressing the union of a set of lists     ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  l - a list of lists for which to return the union         ;;
;;------------------------------------------------------------;;
;;  Returns:  A list of distinct items in the set of lists    ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:ListsUnion-r (l) 
  ((lambda (f) (f (apply 'append l))) 
    (lambda (l) (if l (cons (car l) (f (vl-remove (car l) (cdr l))))))
  )
)


;;---------------------=={ Lists Union }==--------------------;;
;;                                                            ;;
;;  Returns a list expressing the union of a set of lists     ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  l - a list of lists for which to return the union         ;;
;;------------------------------------------------------------;;
;;  Returns:  A list of distinct items in the set of lists    ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:ListsUnion (l / x u) 
  (setq l (apply 'append l))
  (while (setq x (car l)) 
    (setq u (cons x u)
          l (vl-remove x l)
    )
  )
  (reverse u)
)
;#endregion
;#region Load Linetypes
;;-------------------------=={ Load Linetypes }==------------------------;;

;; Load Linetypes  -  Lee Mac
;; Attempts to load a list of linetypes from any .lin files found in the support path.
;; Excludes known metric & imperial definition files based on the value of MEASUREMENT
;; lts - [lst] List of linetypes to load
;; rdf - [bol] If T, linetypes will be redefined from file if already loaded
;; Returns: [bol] T if all linetypes are loaded successfully, else nil
 
(defun Remote>>LM:loadlinetypes (lts rdf / com lst rtn val var) 
  (cond 
    ((not (or rdf (vl-some '(lambda (typ) (not (tblsearch "ltype" typ))) lts))))
    ((if (zerop (getvar 'measurement)) 
       (setq lst (mapcar 'strcase '("acadiso.lin" "iso.lin"))) ;; Known metric .lin files
       (setq lst (mapcar 'strcase '("acad.lin" "default.lin"))) ;; Known imperial .lin files
     )
     (setq lst (vl-remove-if '(lambda (x) (member (strcase x) lst)) 
                             (apply 'append 
                                    (mapcar '(lambda (dir) (vl-directory-files dir "*.lin" 1)) 
                                            (vl-remove "" (Remote>>LM:str->lst (getenv "ACAD") ";"))
                                    )
                             )
               )
     )
     (if rdf 
       (progn 
         (setq var '(cmdecho expert)
               val (mapcar 'getvar var)
               com (cond (command-s) (vl-cmdf))
         )
         (mapcar 'setvar var '(0 5))
       )
     )
     (setq rtn (apply 'and 
                      (mapcar 
                        '(lambda (typ) 
                           (cond 
                             ((not (tblsearch "ltype" typ))
                              (vl-some 
                                '(lambda (lin) 
                                   (vl-catch-all-apply 'vla-load (list (Remote>>LM:aclin) typ lin))
                                   (tblsearch "ltype" typ)
                                 )
                                lst
                              )
                             )
                             (rdf
                              (vl-some 
                                '(lambda (lin) 
                                   (if (Remote>>LM:ltdefined-p typ lin) 
                                     (progn 
                                       (com "_.-linetype" "_L" typ lin "")
                                       (tblsearch "ltype" typ)
                                     )
                                   )
                                 )
                                lst
                              )
                             )
                             (t)
                           )
                         )
                        lts
                      )
               )
     )
     (mapcar 'setvar var val)
     rtn
    )
  )
)
 
;; Linetype Defined-p  -  Lee Mac
;; Returns T if the linetype is defined in the specified .lin file
;; ltp - [str] Linetype name
;; lin - [str] Filename of linetype definition file (.lin)
 
(defun Remote>>LM:ltdefined-p (ltp lin / str rtn) 
  (if 
    (and 
      (setq lin (findfile lin))
      (setq lin (open lin "r"))
    )
    (progn 
      (setq ltp (strcat "`*" (strcase ltp) "`,*"))
      (while 
        (and (setq str (read-line lin)) 
             (not (setq rtn (wcmatch (strcase str) ltp)))
        )
      )
      (close lin)
      rtn
    )
  )
)
;#endregion
;#region Mathematical Functions
;;-------------------------=={ Mathematical Functions }==------------------------;;

;; Matrix Determinant (Upper Triangular Form)  -  ElpanovEvgeniy
;; Args: m - nxn matrix

(defun Remote>>LM:detm (m / d) 
  (cond 
    ((null m) 1)
    ((and (zerop (caar m)) 
          (setq d (car (vl-member-if-not (function (lambda (a) (zerop (car a)))) (cdr m))))
     )
     (Remote>>LM:detm (cons (mapcar '+ (car m) d) (cdr m)))
    )
    ((zerop (caar m)) 0)
    ((* (caar m) 
        (Remote>>LM:detm 
          (mapcar 
            (function 
              (lambda (a / d) 
                (setq d (/ (car a) (float (caar m))))
                (mapcar 
                  (function 
                    (lambda (b c) (- b (* c d)))
                  )
                  (cdr a)
                  (cdar m)
                )
              )
            )
            (cdr m)
          )
        )
     )
    )
  )
)

;; Matrix Determinant (Laplace Formula)  -  Lee Mac
;; Args: m - nxn matrix
 
(defun Remote>>LM:detm (m / i j) 
  (setq i -1
        j 0
  )
  (cond 
    ((null (cdr m)) (caar m))
    ((null (cddr m)) (- (* (caar m) (cadadr m)) (* (cadar m) (caadr m))))
    ((apply '+ 
            (mapcar 
              '(lambda (c) 
                 (setq j (1+ j))
                 (* c 
                    (setq i (- i))
                    (Remote>>LM:detm 
                      (mapcar 
                        '(lambda (x / k) 
                           (setq k 0)
                           (vl-remove-if '(lambda (y) (= j (setq k (1+ k)))) x)
                         )
                        (cdr m)
                      )
                    )
                 )
               )
              (car m)
            )
     )
    )
  )
)

;; Matrix Inverse  -  gile & Lee Mac
;; Uses Gauss-Jordan Elimination to return the inverse of a non-singular nxn matrix.
;; Args: m - nxn matrix

(defun Remote>>LM:invm (m / c f p r) 

  (defun f (p m) 
    (mapcar '(lambda (x) (mapcar '(lambda (a b) (- a (* (car x) b))) (cdr x) p)) m)
  )
  (setq m (mapcar 'append m (imat (length m))))
  (while m 
    (setq c (mapcar '(lambda (x) (abs (car x))) m))
    (repeat (vl-position (apply 'max c) c) 
      (setq m (append (cdr m) (list (car m))))
    )
    (if (equal 0.0 (caar m) 1e-14) 
      (setq m nil
            r nil
      )
      (setq p (mapcar '(lambda (x) (/ (float x) (caar m))) (cdar m))
            m (f p (cdr m))
            r (cons p (f p r))
      )
    )
  )
  (reverse r)
)

;; Identity Matrix  -  Lee Mac
;; Args: n - matrix dimension

(defun Remote>>LM:imat (n / i j l m) 
  (repeat (setq i n) 
    (repeat (setq j n) 
      (setq l (cons (if (= i j) 1.0 0.0) l)
            j (1- j)
      )
    )
    (setq m (cons l m)
          l nil
          i (1- i)
    )
  )
  m
)

;; Matrix Transpose  -  Doug Wilson
;; Args: m - nxn matrix

(defun Remote>>LM:trp (m) 
  (apply 'mapcar (cons 'list m))
)

;; Matrix Trace  -  Lee Mac
;; Args: m - nxn matrix

(defun Remote>>LM:trc (m) 
  (if m (+ (caar m) (Remote>>LM:trc (mapcar 'cdr (cdr m)))) 0)
)

;; Matrix x Matrix  -  Vladimir Nesterovsky
;; Args: m,n - nxn matrices

(defun Remote>>LM:mxm (m n) 
  ((lambda (a) (mapcar '(lambda (r) (Remote>>LM:mxv a r)) m)) (Remote>>LM:trp n))
)

;; Matrix + Matrix  -  Lee Mac
;; Args: m,n - nxn matrices

(defun Remote>>LM:m+m (m n) 
  (mapcar '(lambda (r s) (mapcar '+ r s)) m n)
)

;; Matrix x Scalar  -  Lee Mac
;; Args: m - nxn matrix, n - real scalar

(defun Remote>>LM:mxs (m s) 
  (mapcar '(lambda (r) (mapcar '(lambda (n) (* n s)) r)) m)
)

;; Matrix x Vector  -  Vladimir Nesterovsky
;; Args: m - nxn matrix, v - vector in R^n

(defun Remote>>LM:mxv (m v) 
  (mapcar '(lambda (r) (apply '+ (mapcar '* r v))) m)
)

;; Vector x Scalar  -  Lee Mac
;; Args: v - vector in R^n, s - real scalar

(defun Remote>>LM:vxs (v s) 
  (mapcar '(lambda (n) (* n s)) v)
)

;; Vector Dot Product  -  Lee Mac
;; Args: u,v - vectors in R^n

(defun Remote>>LM:vxv (u v) 
  (apply '+ (mapcar '* u v))
)

;; Vector Cross Product  -  Lee Mac
;; Args: u,v - vectors in R^3

(defun Remote>>LM:v^v (u v) 
  (list 
    (- (* (cadr u) (caddr v)) (* (cadr v) (caddr u)))
    (- (* (car v) (caddr u)) (* (car u) (caddr v)))
    (- (* (car u) (cadr v)) (* (car v) (cadr u)))
  )
)

;; Unit Vector  -  Lee Mac
;; Args: v - vector in R^2 or R^3

(defun Remote>>LM:vx1 (v) 
  ((lambda (n) (if (equal 0.0 n 1e-10) nil (mapcar '/ v (list n n n)))) 
    (distance '(0.0 0.0 0.0) v)
  )
)

;; Vector Norm (R^n)  -  Lee Mac
;; Args: v - vector in R^n

(defun Remote>>LM:|v| (v) 
  (sqrt (apply '+ (mapcar '* v v)))
)

;; Unit Vector (R^n)  -  Lee Mac
;; Args: v - vector in R^n

(defun Remote>>LM:unit (v) 
  ((lambda (n) (if (equal 0.0 n 1e-10) nil (Remote>>LM:vxs v (/ 1.0 n)))) (|v| v))
)

;; Tangent  -  Lee Mac
;; Args: x - real

(defun Remote>>LM:tan (x) 
  (if (not (equal 0.0 (cos x) 1e-10)) 
    (/ (sin x) (cos x))
  )
)

;; ArcSine  -  Lee Mac
;; Args: -1 <= x <= 1

(defun Remote>>LM:asin (x) 
  (if (<= -1.0 x 1.0) 
    (atan x (sqrt (- 1.0 (* x x))))
  )
)

;; ArcCosine  -  Lee Mac
;; Args: -1 <= x <= 1

(defun Remote>>LM:acos (x) 
  (if (<= -1.0 x 1.0) 
    (atan (sqrt (- 1.0 (* x x))) x)
  )
)

;; Hyperbolic Sine  -  Lee Mac
;; Args: x - real

(defun Remote>>LM:sinh (x) 
  (/ (- (exp x) (exp (- x))) 2.0)
)

;; Hyperbolic Cosine  -  Lee Mac
;; Args: x - real

(defun Remote>>LM:cosh (x) 
  (/ (+ (exp x) (exp (- x))) 2.0)
)

;; Hyperbolic Tangent  -  Lee Mac
;; Args: x - real

(defun Remote>>LM:tanh (x) 
  (/ (sinh x) (cosh x))
)

;; Area Hyperbolic Sine  -  Lee Mac
;; Args: x - real

(defun Remote>>LM:asinh (x) 
  (log (+ x (sqrt (1+ (* x x)))))
)

;; Area Hyperbolic Cosine  -  Lee Mac
;; Args: 1 <= x

(defun Remote>>LM:acosh (x) 
  (if (<= 1.0 x) 
    (log (+ x (sqrt (1- (* x x)))))
  )
)

;; Area Hyperbolic Tangent  -  Lee Mac
;; Args: -1 < x < 1

(defun Remote>>LM:atanh (x) 
  (if (< (abs x) 1.0) 
    (/ (log (/ (1+ x) (- 1.0 x))) 2.0)
  )
)


;; Collinear-p  -  Lee Mac
;; Returns T if p1,p2,p3 are collinear

(defun Remote>>LM:Collinear-p (p1 p2 p3) 
  ((lambda (a b c) 
     (or 
       (equal (+ a b) c 1e-8)
       (equal (+ b c) a 1e-8)
       (equal (+ c a) b 1e-8)
     )
   ) 
    (distance p1 p2)
    (distance p2 p3)
    (distance p1 p3)
  )
)

;; List Collinear-p  -  Lee Mac
;; Returns T if all points in a list are collinear

(defun Remote>>LM:ListCollinear-p (lst) 
  (or (null (cddr lst)) 
      (and 
        (equal 1.0 
               (abs 
                 (Remote>>LM:vxv 
                   (Remote>>LM:vx1 (mapcar '- (car lst) (cadr lst)))
                   (Remote>>LM:vx1 (mapcar '- (car lst) (caddr lst)))
                 )
               )
               1e-8
        )
        (Remote>>LM:ListCollinear-p (cdr lst))
      )
  )
)

;; Coplanar-p  -  Lee Mac
;; Returns T if points p1,p2,p3,p4 are coplanar

(defun Remote>>LM:Coplanar-p (p1 p2 p3 p4) 
  ((lambda (n) 
     (equal 
       (last (trans p3 0 n))
       (last (trans p4 0 n))
       1e-8
     )
   ) 
    (Remote>>LM:v^v (mapcar '- p1 p2) (mapcar '- p1 p3))
  )
)

;; List Coplanar-p  -  Lee Mac
;; Returns T if all points in a list are coplanar

(defun Remote>>LM:ListCoplanar-p (lst) 
  (or (null (cdddr lst)) 
      (and 
        ((lambda (n) 
           (equal 
             (last (trans (caddr lst) 0 n))
             (last (trans (cadddr lst) 0 n))
             1e-8
           )
         ) 
          (Remote>>LM:v^v (mapcar '- (car lst) (cadr lst)) (mapcar '- (car lst) (caddr lst)))
        )
        (Remote>>LM:ListCoplanar-p (cdr lst))
      )
  )
)

;; Perpendicular-p  -  Lee Mac
;; Returns T if vectors v1,v2 are perpendicular

(defun Remote>>LM:Perpendicular-p (v1 v2) 
  (equal 0.0 (Remote>>LM:vxv v1 v2) 1e-8)
)


;; List Clockwise-p - Lee Mac
;; Returns T if the point list is clockwise oriented

(defun Remote>>LM:ListClockwise-p (lst) 
  (minusp 
    (apply '+ 
           (mapcar 
             (function 
               (lambda (a b) 
                 (- (* (car b) (cadr a)) (* (car a) (cadr b)))
               )
             )
             lst
             (cons (last lst) lst)
           )
    )
  )
)

;; InsideTriangle-p  -  Lee Mac
;; Returns T if pt lies inside the triangle formed by p1,p2,p3

(defun Remote>>LM:InsideTriangle-p (pt p1 p2 p3) 
  ((lambda (a1 a2 a3) 
     (or 
       (and (<= 0.0 a1) (<= 0.0 a2) (<= 0.0 a3))
       (and (<= a1 0.0) (<= a2 0.0) (<= a3 0.0))
     )
   ) 
    (sin (- (angle p1 pt) (angle p1 p2)))
    (sin (- (angle p2 pt) (angle p2 p3)))
    (sin (- (angle p3 pt) (angle p3 p1)))
  )
)


;; Project Point onto Line  -  Lee Mac
;; Projects pt onto the line defined by p1,p2

(defun Remote>>LM:ProjectPointToLine (pt p1 p2 / nm) 
  (setq nm (mapcar '- p2 p1)
        p1 (trans p1 0 nm)
        pt (trans pt 0 nm)
  )
  (trans (list (car p1) (cadr p1) (caddr pt)) nm 0)
)

;; Project Point onto Plane  -  Lee Mac
;; Projects pt onto the plane defined by its origin and normal

(defun Remote>>LM:ProjectPointToPlane (pt org nm) 
  (setq pt  (trans pt 0 nm)
        org (trans org 0 nm)
  )
  (trans (list (car pt) (cadr pt) (caddr org)) nm 0)
)

;; Reflect Point  -  Lee Mac
;; Returns the point obtained by reflecting 'pt' in the axis defined by points p1 & p2.

(defun Remote>>LM:Reflect (pt p1 p2 / ax) 
  (setq ax (mapcar '- p1 p2)
        p1 (trans p1 0 ax)
        pt (trans pt 0 ax)
  )
  (trans (cons (- (+ (car p1) (car p1)) (car pt)) (cdr pt)) ax 0)
)


;; Line-Plane Intersection  -  Lee Mac
;; Returns the point of intersection of a line defined by
;; points p1,p2 and a plane defined by its origin and normal

(defun Remote>>LM:inters-line-plane (p1 p2 org nm) 
  (setq org (trans org 0 nm)
        p1  (trans p1 0 nm)
        p2  (trans p2 0 nm)
  )
  (trans 
    (inters p1 
            p2
            (list (car p1) (cadr p1) (caddr org))
            (list (car p2) (cadr p2) (caddr org))
            nil
    )
    nm
    0
  )
)

;; Line-Circle Intersection  -  Lee Mac
;; Returns the point(s) of intersection between an infinite line defined by
;; points p,q and circle with centre c and radius r

(defun Remote>>LM:inters-line-circle (p q c r / a d n s) 
  (setq n (mapcar '- q p)
        p (trans p 0 n)
        c (trans c 0 n)
        a (list (car p) (cadr p) (caddr c))
  )
  (cond 
    ((equal r (setq d (distance c a)))
     (list (trans a n 0))
    )
    ((< d r)
     (setq s (sqrt (- (* r r) (* d d))))
     (list 
       (trans (list (car p) (cadr p) (- (caddr c) s)) n 0)
       (trans (list (car p) (cadr p) (+ (caddr c) s)) n 0)
     )
    )
  )
)

;; Line-Circle Intersection (vector version)  -  Lee Mac
;; Returns the point(s) of intersection between an infinite line defined by
;; points p,q and circle with centre c and radius r

(defun Remote>>LM:inters-line-circle (p q c r / v s) 
  (setq v (mapcar '- q p)
        s (mapcar '- p c)
  )
  (mapcar '(lambda (s) (mapcar '+ p (Remote>>LM:vxs v s))) 
          (quad (Remote>>LM:vxv v v) (* 2 (Remote>>LM:vxv v s)) (- (Remote>>LM:vxv s s) (* r r)))
  )
)

;; 2-Circle Intersection  -  Lee Mac
;; Returns the point(s) of intersection between two circles
;; with centres c1,c2 and radii r1,r2

(defun Remote>>LM:inters-circle-circle (c1 r1 c2 r2 / a d m l x y) 
  (if 
    (and (<= (setq d (distance c1 c2)) (+ r1 r2)) 
         (<= (abs (- r1 r2)) d)
    )
    (progn 
      (if (equal r1 (setq x (/ (- (+ (* r1 r1) (* d d)) (* r2 r2)) (+ d d))) 1e-8) 
        (setq l (list (list x 0.0 0.0)))
        (setq y (sqrt (- (* r1 r1) (* x x)))
              l (list (list x y 0.0) (list x (- y) 0.0))
        )
      )
      (setq a (angle c1 c2)
            m (list (list (cos a) (- (sin a)) 0) (list (sin a) (cos a) 0) '(0 0 1))
      )
      (mapcar '(lambda (v) (mapcar '+ c1 (Remote>>LM:mxv m v))) l)
    )
  )
)

;; 2-Circle Intersection (trans version)  -  Lee Mac
;; Returns the point(s) of intersection between two circles
;; with centres c1,c2 and radii r1,r2

(defun Remote>>LM:inters-circle-circle (c1 r1 c2 r2 / n d1 x z) 
  (if 
    (and 
      (< (setq d1 (distance c1 c2)) (+ r1 r2))
      (< (abs (- r1 r2)) d1)
    )
    (progn 
      (setq n  (mapcar '- c2 c1)
            c1 (trans c1 0 n)
            z  (/ (- (+ (* r1 r1) (* d1 d1)) (* r2 r2)) (+ d1 d1))
      )
      (if (equal z r1 1e-8) 
        (list (trans (list (car c1) (cadr c1) (+ (caddr c1) z)) n 0))
        (progn 
          (setq x (sqrt (- (* r1 r1) (* z z))))
          (list 
            (trans (list (- (car c1) x) (cadr c1) (+ (caddr c1) z)) n 0)
            (trans (list (+ (car c1) x) (cadr c1) (+ (caddr c1) z)) n 0)
          )
        )
      )
    )
  )
)

;; 2-Arc Intersection  -  Lee Mac
;; Returns the point(s) of intersection between two arcs
;; with centres c1,c2 radii r1,r2, start angles s1,s2 & end angles e1,e2

(defun Remote>>LM:inters-arc-arc (c1 r1 s1 e1 c2 r2 s2 e2) 
  (cond 
    ((< e1 s1) (Remote>>LM:inters-arc-arc c1 r1 s1 (+ e1 pi pi) c2 r2 s2 e2))
    ((< e2 s2) (Remote>>LM:inters-arc-arc c1 r1 s1 e1 c2 r2 s2 (+ e2 pi pi)))
    ((vl-remove-if-not 
       '(lambda (pt) (and (<= s1 (angle c1 pt) e1) (<= s2 (angle c2 pt) e2)))
       (Remote>>LM:inters-circle-circle c1 r1 c2 r2)
     )
    )
  )
)


;; Midpoint  -  Lee Mac
;; Returns the midpoint of two points

(defun Remote>>LM:mid (a b) 
  (mapcar (function (lambda (a b) (/ (+ a b) 2.0))) a b)
)

;; Polygon Centroid  -  Lee Mac
;; Returns the WCS Centroid of an LWPolyline Polygon Entity

(defun Remote>>LM:PolyCentroid (e / l) 
  (foreach x (setq e (entget e)) 
    (if (= 10 (car x)) (setq l (cons (cdr x) l)))
  )
  ((lambda (a) 
     (if (not (equal 0.0 a 1e-8)) 
       (trans 
         (mapcar '/ 
                 (apply 'mapcar 
                        (cons '+ 
                              (mapcar 
                                (function 
                                  (lambda (a b) 
                                    ((lambda (m) 
                                       (mapcar 
                                         (function 
                                           (lambda (c d) (* (+ c d) m))
                                         )
                                         a
                                         b
                                       )
                                     ) 
                                      (- (* (car a) (cadr b)) (* (car b) (cadr a)))
                                    )
                                  )
                                )
                                l
                                (cons (last l) l)
                              )
                        )
                 )
                 (list a a)
         )
         (cdr (assoc 210 e))
         0
       )
     )
   ) 
    (* 3.0 
       (apply '+ 
              (mapcar 
                (function 
                  (lambda (a b) 
                    (- (* (car a) (cadr b)) (* (car b) (cadr a)))
                  )
                )
                l
                (cons (last l) l)
              )
       )
    )
  )
)


;; 3-Point Arc  -  Lee Mac
;; Returns the center, start/end angle and radius of the arc defined by three supplied points.

(defun Remote>>LM:3PArc (p1 p2 p3 / cn m1 m2) 
  (setq m1 (Remote>>LM:mid p1 p2)
        m2 (Remote>>LM:mid p2 p3)
  )
  (if 
    (setq cn (inters 
               m1
               (polar m1 (+ (angle p1 p2) (/ pi 2.)) 1.0)
               m2
               (polar m2 (+ (angle p2 p3) (/ pi 2.)) 1.0)
               nil
             )
    )
    (append (list cn) 
            (if (Remote>>LM:Clockwise-p p1 p2 p3) 
              (list (angle cn p3) (angle cn p1))
              (list (angle cn p1) (angle cn p3))
            )
            (list (distance cn p1))
    )
  )
)

;; 2-Circle Tangents  -  Lee Mac
;; Returns the two groups of points for which a line from a point in
;; each group is tangent to both circles with centres c1,c2 and radii r1,r2

(defun Remote>>LM:2CircleTangents (c1 r1 c2 r2 / d1 d2 a1 a2) 
  (if (< (abs (setq d1 (- r1 r2))) (setq d2 (distance c1 c2))) 
    (progn 
      (setq a1 (atan (sqrt (- (* d2 d2) (* d1 d1))) d1)
            a2 (angle c1 c2)
      )
      (list 
        (list (polar c1 (+ a2 a1) r1) (polar c1 (- a2 a1) r1))
        (list (polar c2 (+ a2 a1) r2) (polar c2 (- a2 a1) r2))
      )
    )
  )
)

;; Point-Circle Tangents  -  Lee Mac
;; Returns the two points for which a line from 'pt' to each point returned
;; is tangent to the circle with centre c1 and radius r1

(defun Remote>>LM:PointCircleTangents (pt c1 r1 / a1 a2 d1) 
  (if 
    (< r1 
       (setq a1 (angle c1 pt)
             d1 (distance pt c1)
       )
    )
    (progn 
      (setq a2 (atan (sqrt (- (* d1 d1) (* r1 r1))) r1))
      (list 
        (polar c1 (+ a1 a2) r1)
        (polar c1 (- a1 a2) r1)
      )
    )
  )
)


;; Quadratic Solution  -  Lee Mac
;; Args: a,b,c - coefficients of ax^2 + bx + c = 0
 
(defun Remote>>LM:quad (a b c / d r) 
  (cond 
    ((equal 0.0 (setq d (- (* b b) (* 4.0 a c))) 1e-8)
     (list (/ b (* -2.0 a)))
    )
    ((< 0 d)
     (setq r (sqrt d))
     (list (/ (- r b) (* 2.0 a)) (/ (- (- b) r) (* 2.0 a)))
    )
  )
)

;; Least Common Multiple  -  Lee Mac
;; Args: a,b - positive non-zero integers

(defun Remote>>LM:lcm (a b) (* b (/ a (gcd a b))))

;; Least Common Multiple of List  -  Lee Mac
;; Args: l - list of positive non-zero integers

(defun Remote>>LM:lcml (l) 
  (if (cddr l) 
    (lcm (car l) (Remote>>LM:lcml (cdr l)))
    (apply 'lcm l)
  )
)

;; Prime Factors  -  Lee Mac
;; Args: n - positive non-zero integer

(defun Remote>>LM:pf (n / m p r) 
  (setq p 2)
  (while (< 1 n) 
    (while (zerop (rem n p)) 
      (setq r (cons p r)
            n (/ n p)
      )
    )
    (if (< 1 (setq m (sqrt n)) (setq p (if (= p 2) 3 (+ 2 p)))) 
      (setq r (cons n r)
            n 0
      )
      (while (and (<= p m) (< 0 (rem n p))) 
        (setq p (+ 2 p))
      )
    )
  )
  (reverse r)
)

;; Prime-p  -  Lee Mac
;; Args: n - positive non-zero integer

(defun Remote>>LM:prime-p (n / m p) 
  (or (= 2 n) 
      (and 
        (< 2 n)
        (= 1 (rem n 2))
        (progn 
          (setq m (1+ (sqrt n))
                p 3
          )
          (while (and (< p m) (< 0 (rem n p))) 
            (setq p (+ 2 p))
          )
          (< m p)
        )
      )
  )
)


;; Factorial  -  Lee Mac
;; Args: n - positive integer

(defun Remote>>LM:n! (n / r) 
  (setq r n)
  (repeat (fix (- n 2)) (setq r (* r (setq n (1- n)))))
  (if (< r 2) 1 r)
)

;; Factorial (recursive version)  -  Lee Mac
;; Args: n - positive integer

(defun Remote>>LM:n!-rec (n) 
  (if (< n 2) 1 (* n (Remote>>LM:n!-rec (1- n))))
)

;; Factorial Division  -  Lee Mac
;; Args: n,k - positive integers

(defun Remote>>LM:n!/k! (n k / m r) 
  (cond 
    ((= n k) 1)
    ((setq r (max n k)
           m r
     )
     (repeat (fix (1- (abs (- n k)))) (setq r (* r (setq m (1- m)))))
     (if (< k n) r (/ 1.0 r))
    )
  )
)

;; Factorial Multiplication  -  Lee Mac
;; Args: n,k - positive integers

(defun Remote>>LM:n!k! (n k / m) 
  (setq m (n! (min n k)))
  (* (Remote>>LM:n!/k! (max n k) (min n k)) m m)
)


;; Complex Addition  -  Lee Mac
;; Args: c1,c2 - complex numbers of the form a+bi = (a b)

(defun Remote>>LM:c+c (c1 c2) 
  (mapcar '+ c1 c2)
)

;; Complex Subtraction  -  Lee Mac
;; Args: c1,c2 - complex numbers of the form a+bi = (a b)

(defun Remote>>LM:c-c (c1 c2) 
  (mapcar '- c1 c2)
)

;; Complex Multiplication  -  Lee Mac
;; Args: c1,c2 - complex numbers of the form a+bi = (a b)

(defun Remote>>LM:cxc (c1 c2) 
  (list 
    (- (* (car c1) (car c2)) (* (cadr c1) (cadr c2)))
    (+ (* (car c1) (cadr c2)) (* (cadr c1) (car c2)))
  )
)

;; Complex Conjugate  -  Lee Mac
;; Args: c1 - complex number of the form a+bi = (a b)

(defun Remote>>LM:c_ (c1) 
  (list (car c1) (- (cadr c1)))
)

;; Complex Division  -  Lee Mac
;; Args: c1,c2 - complex numbers of the form a+bi = (a b)

(defun Remote>>LM:c/c (c1 c2 / d) 
  ((lambda (d) (mapcar '(lambda (x) (/ x d)) (Remote>>LM:cxc c1 (Remote>>LM:c_ c2)))) 
    (car (Remote>>LM:cxc c2 (Remote>>LM:c_ c2)))
  )
)

;; Complex Norm  -  Lee Mac
;; Args: c1 - complex number of the form a+bi = (a b)
;; defun name change from  |c|  to  Remote>>LM:/c/

(defun Remote>>LM:/c/ (c1) 
  (sqrt (apply '+ (mapcar '* c1 c1)))
)

;#endregion
;#region Matrix Transformation Functions
;; http://www.lee-mac.com/matrixtransformationfunctions.html


;;------------------=={ Scale by Matrix }==-------------------;;
;;                                                            ;;
;;  Scales a VLA-Object or Point List using a                 ;;
;;  Transformation Matrix                                     ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2010 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  target - VLA-Object or Point List to transform            ;;
;;  p1     - Base Point for Scaling Transformation            ;;
;;  scale  - Scale Factor by which to scale object            ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:ScaleByMatrix (Remote>>LM:target p1 scale / m) 

  (Remote>>LM:ApplyMatrixTransformation 
    Remote>>LM:target
    (setq m (list 
              (list scale 0. 0.)
              (list 0. scale 0.)
              (list 0. 0. scale)
            )
    )
    (mapcar '- p1 (Remote>>LM:mxv m p1))
  )
)


;;----------------=={ Translate by Matrix }==-----------------;;
;;                                                            ;;
;;  Translates a VLA-Object or Point List using a             ;;
;;  Transformation Matrix                                     ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2010 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  target - VLA-Object or Point List to transform            ;;
;;  p1, p2 - Points representing vector by which to translate ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:TranslateByMatrix (Remote>>LM:target p1 p2) 

  (Remote>>LM:ApplyMatrixTransformation 
    Remote>>LM:target
    (list 
      (list 1. 0. 0.)
      (list 0. 1. 0.)
      (list 0. 0. 1.)
    )
    (mapcar '- p2 p1)
  )
)


;;------------------=={ Rotate by Matrix }==------------------;;
;;                                                            ;;
;;  Rotates a VLA-Object or Point List using a                ;;
;;  Transformation Matrix                                     ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2010 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  target - VLA-Object or Point List to transform            ;;
;;  p1     - Base Point for Rotation Transformation           ;;
;;  ang    - Angle through which to rotate object             ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:RotateByMatrix (Remote>>LM:target p1 ang) 

  (Remote>>LM:ApplyMatrixTransformation 
    Remote>>LM:target
    (setq m (list 
              (list (cos ang) (- (sin ang)) 0.)
              (list (sin ang) (cos ang) 0.)
              (list 0. 0. 1.)
            )
    )
    (mapcar '- p1 (Remote>>LM:mxv m p1))
  )
)


;;-----------------=={ Reflect by Matrix }==------------------;;
;;                                                            ;;
;;  Reflects a VLA-Object or Point List using a               ;;
;;  Transformation Matrix                                     ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2010 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  target - VLA-Object or Point List to transform            ;;
;;  p1, p2 - Points representing vector in which to reflect   ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:ReflectByMatrix (Remote>>LM:target p1 p2) 
  ((lambda (a / m) 
     (Remote>>LM:ApplyMatrixTransformation 
       Remote>>LM:target
       (setq m (list 
                 (list (cos a) (sin a) 0.)
                 (list (sin a) (- (cos a)) 0.)
                 (list 0. 0. 1.)
               )
       )
       (mapcar '- p1 (Remote>>LM:mxv m p1))
     )
   ) 
    (* 2. (angle p1 p2))
  )
)


;;-----------=={ Apply Matrix Transformation }==--------------;;
;;                                                            ;;
;;  Transforms a VLA-Object or Point List using a             ;;
;;  Transformation Matrix                                     ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2010 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  target - VLA-Object or Point List to Transform            ;;
;;  matrix - 3x3 Matrix by which to Transform object          ;;
;;  vector - 3D translation vector                            ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:ApplyMatrixTransformation (Remote>>LM:target matrix vector) 
  (vl-load-com)
  (cond 
    ((eq 'VLA-OBJECT (type Remote>>LM:target))

     (vla-TransformBy Remote>>LM:target 
                      (vlax-tMatrix 
                        (append (mapcar '(lambda (x v) (append x (list v))) matrix vector) 
                                '((0. 0. 0. 1.))
                        )
                      )
     )
    )
    ((listp Remote>>LM:target)

     (mapcar 
       (function 
         (lambda (point) (mapcar '+ (Remote>>LM:mxv matrix point) vector))
       )
       Remote>>LM:target
     )
    )
  )
)


;;----------------=={ 3D Rotate by Matrix }==-----------------;;
;;                                                            ;;
;;  Rotates a VLA-Object or Point List about a 3D axis using  ;;
;;  a Transformation matrix.                                  ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  target - VLA-Object or Point List to Rotate               ;;
;;  p1,p2  - Two 3D points defining the axis of rotation      ;;
;;  ang    - Rotation Angle                                   ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:Rotate3D (Remote>>LM:target p1 p2 ang / ux uy uz) 

  (mapcar 'set '(ux uy uz) (setq u (Remote>>LM:unit (mapcar '- p2 p1))))

  (Remote>>LM:ApplyMatrixTransformation 
    Remote>>LM:target
    (setq m (m+m 
              (list 
                (list (cos ang) 0. 0.)
                (list 0. (cos ang) 0.)
                (list 0. 0. (cos ang))
              )
              (m+m 
                (mxs 
                  (list 
                    (list 0. (- uz) uy)
                    (list uz 0. (- ux))
                    (list (- uy) ux 0.)
                  )
                  (sin ang)
                )
                (mxs (mapcar '(lambda (e) (Remote>>LM:vxs u e)) u) (- 1. (cos ang)))
              )
            )
    )
    (mapcar '- p1 (Remote>>LM:mxv m p1))
  )
)


;;----------------=={ 3D Reflect by Matrix }==----------------;;
;;                                                            ;;
;;  Reflects a VLA-Object or Point List in a plane using a    ;;
;;  Transformation matrix.                                    ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  target   - VLA-Object or Point List to Reflect            ;;
;;  p1,p2,p3 - Three 3D points defining the reflection plane  ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:Reflect3D (Remote>>LM:target p1 p2 p3 / m u ux uy uz) 

  (mapcar 'set '(ux uy uz) (setq u (Remote>>LM:unit (Remote>>LM:v^v (mapcar '- p2 p1) (mapcar '- p3 p1)))))

  (Remote>>LM:ApplyMatrixTransformation 
    Remote>>LM:target
    (setq m (list 
              (list (- 1. (* 2. ux ux)) (* -2. uy ux) (* -2. ux uz))
              (list (* -2. ux uy) (- 1. (* 2. uy uy)) (* -2. uy uz))
              (list (* -2. ux uz) (* -2. uy uz) (- 1. (* 2. uz uz)))
            )
    )
    (mapcar '- p1 (Remote>>LM:mxv m p1))
  )
)


;;-----------=={ Apply Matrix Transformation }==--------------;;
;;                                                            ;;
;;  Transforms a VLA-Object or Point List using a             ;;
;;  Transformation Matrix                                     ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2010 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  target - VLA-Object or Point List to Transform            ;;
;;  matrix - 3x3 Matrix by which to Transform object          ;;
;;  vector - 3D translation vector                            ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:ApplyMatrixTransformation (Remote>>LM:target matrix vector) 
  (vl-load-com)
  (cond 
    ((eq 'VLA-OBJECT (type target))

     (vla-TransformBy Remote>>LM:target 
                      (vlax-tMatrix 
                        (append (mapcar '(lambda (x v) (append x (list v))) matrix vector) 
                                '((0. 0. 0. 1.))
                        )
                      )
     )
    )
    ((listp Remote>>LM:target)

     (mapcar 
       (function 
         (lambda (point) (mapcar '+ (Remote>>LM:mxv matrix point) vector))
       )
       Remote>>LM:target
     )
    )
  )
)


;#endregion
;#region MD5 Cryptographic Hash Function
;;  http://www.lee-mac.com/md5.html


;; MD5 Cryptographic Hash Function  -  V1.1 2016-03-27  -  Lee Mac
;; AutoLISP implementation of the MD5 algorithm by Ronald Rivest
;; lst - [lst] List of bytes for which to generate hash
;; Returns 128-bit (16-byte) hash string.
 
(defun Remote>>LM:MD5 (lst / a b c d f g h i k l r w x y) 

  ;; k[n] = floor(abs(sin(n+1)))*2^32 ; n:1-64
  (setq k (mapcar '(lambda (x) (md5:int->bits x 32)) 
                  '(3614090360 3905402710 0606105819 3250441966 4118548399 1200080426 2821735955 4249261313 1770035416 
                    2336552879 4294925233 2304563134 1804603682 4254626195 2792965006 1236535329 4129170786 3225465664 
                    0643717713 3921069994 3593408605 0038016083 3634488961 3889429448 0568446438 3275163606 4107603335 
                    1163531501 2850285829 4243563512 1735328473 2368359562 4294588738 2272392833 1839030562 4259657740 
                    2763975236 1272893353 4139469664 3200236656 0681279174 3936430074 3572445317 0076029189 3654602809 
                    3873151461 0530742520 3299628645 4096336452 1126891415 2878612391 4237533241 1700485571 2399980690 
                    4293915773 2240044497 1873313359 4264355552 2734768916 1309151649 4149444226 3174756917 0718787259 
                    3951481745
                   )
          )
  )

  ;; bit-shift values
  (setq r '(07 12 17 22 07 12 17 22 07 12 17 22 07 12 17 22 05 09 14 20 05 09 14 20 05 09 14 20 05 09 14 20 04 11 16 23 
            04 11 16 23 04 11 16 23 04 11 16 23 06 10 15 21 06 10 15 21 06 10 15 21 06 10 15 21
           )
  )

  ;; Initial hash values: forward/backward count in little-endian hex
  (setq h (mapcar '(lambda (x) (md5:int->bits x 32)) 
                  '(1732584193 ; 0x67452301 = 01234567
                    4023233417 ; 0xefcdab89 = 89abcdef
                    2562383102 ; 0x98badcfe = fedcda98
                    0271733878 ; 0x10325476 = 76543210
                   )
          )
  )

  ;; Pre-processing:
  ;; Append 0x80 to list of byte values
  ;; Append 0x00 until list has length of 448 bits (mod 512)
  ;; Append length of string in bytes (little-endian) mod(2^64)
  (setq l (cons 128 (reverse lst)))
  (repeat (rem (+ 64 (- 56 (rem (length l) 64))) 64) (setq l (cons 0 l)))
  (setq l (append (reverse l) (md5:bits->bytes (md5:int->bits (* 8 (length lst)) 64))))

  ;; Process list in 512-bit (64-byte) chunks
  (repeat (/ (length l) 64) 

    ;; Construct list of 16 32-bit (4-byte) words
    (repeat 16 
      (setq w (cons (md5:bytes->bits (mapcar '+ l '(0 0 0 0))) w)
            l (cddddr l)
      )
    )
    (setq w (reverse w))

    ;; Initialise variables to hash values
    ;; Lists of bit values are used as AutoLISP does not support 32-bit unsigned integers
    (mapcar 'set '(a b c d) h)

    ;; Main MD5 algorithm:
    (setq i 0)
    (repeat 64 
      (cond 
        ((< i 16)
         (setq f (mapcar 'logior (mapcar 'logand b c) (mapcar 'logand (mapcar '(lambda (a) (+ 2 (~ a))) b) d))
               g i
         )
        )
        ((< i 32)
         (setq f (mapcar 'logior (mapcar 'logand d b) (mapcar 'logand (mapcar '(lambda (a) (+ 2 (~ a))) d) c))
               g (rem (1+ (* 5 i)) 16)
         )
        )
        ((< i 48)
         (setq f (mapcar '(lambda (a b c) (boole 6 a b c)) b c d)
               g (rem (+ 5 (* 3 i)) 16)
         )
        )
        ((setq f (mapcar '(lambda (a b) (boole 6 a b)) c (mapcar 'logior b (mapcar '(lambda (a) (+ 2 (~ a))) d)))
               g (rem (* 7 i) 16)
         )
        )
      )
      (mapcar 'set 
              '(d c a b i)
              (list c 
                    b
                    d
                    (md5:uint32_+ 
                      b
                      (md5:leftrotate 
                        (md5:uint32_+ 
                          (md5:uint32_+ 
                            (md5:uint32_+ a f)
                            (nth i k)
                          )
                          (nth g w)
                        )
                        (nth i r)
                      )
                    )
                    (1+ i)
              )
      )
    )

    ;; Update hash values for this chunk
    (setq h (mapcar 'md5:uint32_+ h (list a b c d))
          w nil
    )
  )

  ;; Convert the 4 32-bit integer values to 128-bit hash string of 32 hex digits
  (apply 'strcat 
         (mapcar 'md5:byte->hex 
                 (apply 'append (mapcar 'md5:bits->bytes h))
         )
  )
)
(defun md5:int->bits (n b / l x) 
  (repeat b (setq l (cons 0 l)))
  (foreach x (vl-string->list (rtos n 2 0)) 
    (setq x (- x 48)
          l (mapcar 
              '(lambda (a) 
                 (setq a (+ (* a 10) x)
                       x (/ a 2)
                 )
                 (rem a 2)
               )
              l
            )
    )
  )
  (reverse l) ;; output is big-endian
)
(defun md5:bits->int (l)  ;; input is big-endian
  ((lambda (f) (f (reverse l))) 
    (lambda (l) (if l (+ (* 2.0 (f (cdr l))) (car l)) 0))
  )
)
(defun md5:bits->bytes (l / b r)  ;; input is big-endian
  (repeat (/ (length l) 8) 
    (repeat 8 
      (setq b (cons (car l) b)
            l (cdr l)
      )
    )
    (setq r (cons (fix (+ 1e-8 (md5:bits->int (reverse b)))) r)
          b nil
    )
  )
  r ;; output is little-endian
)
(defun md5:bytes->bits (l)  ;; input is little-endian
  (apply 'append (mapcar '(lambda (b) (md5:int->bits b 8)) (reverse l))) ;; output is big-endian
)
(defun md5:int->char (n) 
  (chr (+ n (if (< n 10) 48 87)))
)
(defun md5:byte->hex (x) 
  (strcat (md5:int->char (/ x 16)) (md5:int->char (rem x 16)))
)
(defun md5:leftrotate (l x) 
  (repeat x (setq l (append (cdr l) (list (car l)))))
)
(defun md5:uint32_+ (bl1 bl2 / r)  ;; input is big-endian
  (setq r 0)
  (reverse 
    (mapcar 
      '(lambda (a b c / x) 
         (setq x (boole 6 (boole 6 a b) r)
               r (boole 7 (boole 1 a b) (boole 1 a r) (boole 1 b r))
         )
         x
       )
      (append (reverse bl1) (md5:uint32_0))
      (append (reverse bl2) (md5:uint32_0))
      (md5:uint32_0)
    )
  ) ;; output is big-endian
)
(defun md5:uint32_0 (/ l) 
  (repeat 32 (setq l (cons 0 l)))
  (eval (list 'defun 'md5:uint32_0 nil (list 'quote l)))
  (md5:uint32_0)
)
(princ)

;#endregion
;#region Minimum Bounding Box
;;  http://www.lee-mac.com/minboundingbox.html

;; Minimum Bounding Box  -  Lee Mac
;; Returns the WCS coordinates describing the minimum bounding rectangle
;; surrounding all objects in a supplied selection set.
;; sel - [sel] selection set to process
;; tol - [rea] precision of calculation, 0 < tol < 1

(defun Remote>>LM:minboundingbox (sel tol / ang box bx1 bx2 cen idx lst obj rtn) 
  (if (and sel (< 0.0 tol 1.0)) 
    (progn 
      (repeat (setq idx (sslength sel)) 
        (setq obj (vlax-ename->vla-object (ssname sel (setq idx (1- idx)))))
        (if 
          (and (vlax-method-applicable-p obj 'getboundingbox) 
               (not (vl-catch-all-error-p (vl-catch-all-apply 'vla-getboundingbox (list obj 'a 'b))))
          )
          (setq lst (cons (vla-copy obj) lst))
        )
      )
      (if lst 
        (progn 
          (setq box (Remote>>LM:objlstboundingbox lst)
                tol (* tol pi)
                cen (apply 'mapcar (cons '(lambda (a b) (/ (+ a b) 2.0)) box))
                bx1 (* (- (caadr box) (caar box)) (- (cadadr box) (cadar box)))
                rtn (list 0.0 box)
                ang 0.0
          )
          (while (< (setq ang (+ ang tol)) pi) 
            (foreach obj lst (vlax-invoke obj 'rotate cen tol))
            (setq box (Remote>>LM:objlstboundingbox lst)
                  bx2 (* (- (caadr box) (caar box)) (- (cadadr box) (cadar box)))
            )
            (if (< bx2 bx1) 
              (setq bx1 bx2
                    rtn (list ang box)
              )
            )
          )
          (foreach obj lst (vla-delete obj))
          (Remote>>LM:rotatepoints 
            (mapcar '(lambda (a) (mapcar '(lambda (b) (apply b (cdr rtn))) a)) 
                    '((caar cadar)
                      (caadr cadar)
                      (caadr cadadr)
                      (caar cadadr)
                     )
            )
            cen
            (- (car rtn))
          )
        )
      )
    )
  )
)


;#endregion
;#region Minimum Enclosing Circle
;;  http://www.lee-mac.com/mecfunction.html


;; Minimum Enclosing Circle  -  Lee Mac
;; Implements the algorithm by Pr.Chrystal (1885) using the Convex Hull
;; to determine the Minimum Enclosing Circle of a point set.
 
(defun Remote>>LM:MinEncCircle (lst / _sub) 

  (defun _sub (p1 p2 l1 / a1 a2 l2 p3 p4) 
    (setq l2 (Remote>>LM:RemoveWithFuzz (list p1 p2) l1 1e-8)
          p3 (car l2)
          a1 (Remote>>LM:GetInsideAngle p1 p3 p2)
    )
    (foreach p4 (cdr l2) 
      (if (< (setq a2 (Remote>>LM:GetInsideAngle p1 p4 p2)) a1) 
        (setq p3 p4
              a1 a2
        )
      )
    )
    (cond 
      ((<= (/ pi 2.0) a1)
       (list (Remote>>LM:mid p1 p2) (/ (distance p1 p2) 2.0))
      )
      ((vl-some 
         (function 
           (lambda (a b c) 
             (if (< (/ pi 2.0) (Remote>>LM:GetInsideAngle a b c)) (_sub a c l1))
           )
         )
         (list p1 p1 p2)
         (list p2 p3 p1)
         (list p3 p2 p3)
       )
      )
      ((Remote>>LM:3PCircle p1 p2 p3))
    )
  )

  ((lambda (lst) 
     (cond 
       ((< (length lst) 2)
        nil
       )
       ((< (length lst) 3)
        (list (apply 'Remote>>LM:mid lst) (/ (apply 'distance lst) 2.0))
       )
       ((_sub (car lst) (cadr lst) lst))
     )
   ) 
    (Remote>>LM:ConvexHull lst)
  )
)


;#endregion
;#region ObjectDBX Wrapper
;;  http://www.lee-mac.com/odbxbase.html


;;-----------------------=={ ObjectDBX Wrapper }==----------------------;;
;;                                                                      ;;
;;  Evaluates a supplied function on all drawings in a given list or    ;;
;;  selected directory.                                                 ;;
;;----------------------------------------------------------------------;;
;;  Author:  Lee Mac, Copyright © 2013  -  www.lee-mac.com              ;;
;;----------------------------------------------------------------------;;
;;  Arguments:                                                          ;;
;;                                                                      ;;
;;  fun [SYM]                                                           ;;
;;  ---------------------------------                                   ;;
;;  A function requiring a single argument (the VLA Document object),   ;;
;;  and following the 'rules' of ObjectDBX:                             ;;
;;                                                                      ;;
;;  - No SelectionSets               (ssget, ssname, ssdel, etc)        ;;
;;  - No Command Calls               (command "_.line" ... etc)         ;;
;;  - No ent* methods                (entget, entmod, entupd, etc)      ;;
;;  - No Access to System Variables  (setvar, getvar, setvariable, etc) ;;
;;                                                                      ;;
;;  lst [LIST] [Optional]                                               ;;
;;  ---------------------------------                                   ;;
;;  List of DWG Filenames; if nil, BrowseForFolder Dialog is displayed. ;;
;;                                                                      ;;
;;  sav [SYM]                                                           ;;
;;  ---------------------------------                                   ;;
;;  Boolean flag determining whether drawings should be saved following ;;
;;  function evaluation (T=saved, nil=not saved).                       ;;
;;----------------------------------------------------------------------;;
;;  Returns:                                                            ;;
;;                                                                      ;;
;;  List of:                                                            ;;
;;  (                                                                   ;;
;;      (<Drawing Filename> . <Function Result>)                        ;;
;;      (<Drawing Filename> . <Function Result>)                        ;;
;;      ...                                                             ;;
;;      (<Drawing Filename> . <Function Result>)                        ;;
;;  )                                                                   ;;
;;                                                                      ;;
;;  Where:                                                              ;;
;;  <Drawing Filename>                                                  ;;
;;  is the filename of drawing that has been processed.                 ;;
;;                                                                      ;;
;;  <Function Result>                                                   ;;
;;  is the result of evaluating the supplied function on the Document   ;;
;;  Object representing the associated drawing filename.                ;;
;;                                                                      ;;
;;  If an error occurs when evaluating the supplied function the        ;;
;;  Function Result will be nil and the error message will be printed   ;;
;;  to the command-line.                                                ;;
;;----------------------------------------------------------------------;;
 
(defun Remote>>LM:ODBX (fun lst sav / *error* app dbx dir doc dwl err rtn vrs) 

  (defun *error* (msg) 
    (if (and (= 'vla-object (type dbx)) (not (vlax-object-released-p dbx))) 
      (vlax-release-object dbx)
    )
    (if (not (wcmatch (strcase msg t) "*break,*cancel*,*exit*")) 
      (princ (strcat "\nError: " msg))
    )
    (princ)
  )

  (cond 
    ((not 
       (or lst 
           (and (setq dir (Remote>>LM:browseforfolder "Select Folder of Drawings to Process" nil 512)) 
                (setq lst (mapcar '(lambda (x) (strcat dir "\\" x)) (vl-directory-files dir "*.dwg" 1)))
           )
       )
     )
     nil
    )
    ((progn 
       (setq dbx (vl-catch-all-apply 'vla-getinterfaceobject 
                                     (list (setq app (vlax-get-acad-object)) 
                                           (if (< (setq vrs (atoi (getvar 'acadver))) 16) 
                                             "objectdbx.axdbdocument"
                                             (strcat "objectdbx.axdbdocument." (itoa vrs))
                                           )
                                     )
                 )
       )
       (or (null dbx) (vl-catch-all-error-p dbx))
     )
     (prompt "\nUnable to interface with ObjectDBX.")
    )
    (t
     (vlax-for doc (vla-get-documents app) 
       (setq dwl (cons (cons (strcase (vla-get-fullname doc)) doc) dwl))
     )
     (foreach dwg lst 
       (if 
         (or (setq doc (cdr (assoc (strcase dwg) dwl))) 
             (and (not (vl-catch-all-error-p (vl-catch-all-apply 'vla-open (list dbx dwg)))) 
                  (setq doc dbx)
             )
         )
         (progn 
           (setq rtn (cons 
                       (cons dwg 
                             (if (vl-catch-all-error-p (setq err (vl-catch-all-apply fun (list doc)))) 
                               (prompt (strcat "\n" dwg "\t" (vl-catch-all-error-message err)))
                               err
                             )
                       )
                       rtn
                     )
           )
           (if sav (vla-saveas doc dwg))
         )
         (princ (strcat "\nError opening file: " (vl-filename-base dwg) ".dwg"))
       )
     )
     (if (= 'vla-object (type dbx)) 
       (vlax-release-object dbx)
     )
     (reverse rtn)
    )
  )
)


;#endregion
;#region Open
;;  http://www.lee-mac.com/open.html


;; Open  -  Lee Mac
;; A wrapper for the 'Open' method of the Shell Object
;; target - [int/str] File, folder or ShellSpecialFolderConstants enum

(defun Remote>>LM:open (target / rtn shl) 
  (if 
    (and (or (= 'int (type target)) (setq target (findfile target))) 
         (setq shl (vla-getinterfaceobject (vlax-get-acad-object) "shell.application"))
    )
    (progn 
      (setq rtn (vl-catch-all-apply 'vlax-invoke (list shl 'open target)))
      (vlax-release-object shl)
      (if (vl-catch-all-error-p rtn) 
        (prompt (vl-catch-all-error-message rtn))
        t
      )
    )
  )
)


;#endregion
;#region Ortho Point 
;;  http://www.lee-mac.com/orthopoint.html


;;---------------------=={ Ortho Point }==--------------------;;
;;                                                            ;;
;;  Returns a point transformed relative to a basepoint to    ;;
;;  account for activation of Orthomode in the current UCS.   ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  base  - basepoint for transformation (UCS)                ;;
;;  point - point to be transformed (UCS)                     ;;
;;------------------------------------------------------------;;
;;  Returns:  Point (UCS) transformed to account for Ortho    ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:OrthoPoint (base point / dx dy vp vx vy) 
  (if (zerop (getvar 'ORTHOMODE)) 
    point
    (progn 
      (setq vx (trans (getvar 'UCSXDIR) 0 1 t)
            vy (Remote>>LM:v^v '(0.0 0.0 1.0) vx)
            vp (mapcar '- point base)
            dx (Remote>>LM:vxv vx vp)
            dy (Remote>>LM:vxv vy vp)
      )
      (mapcar '+ 
              base
              (if (< (abs dx) (abs dy)) 
                (Remote>>LM:vxs vy dy)
                (Remote>>LM:vxs vx dx)
              )
      )
    )
  )
)


;;-------------=={ Ortho Point - Trans version}==-------------;;
;;                                                            ;;
;;  Returns a point transformed relative to a basepoint to    ;;
;;  account for activation of Orthomode in the current UCS.   ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  base  - basepoint for transformation (UCS)                ;;
;;  point - point to be transformed (UCS)                     ;;
;;------------------------------------------------------------;;
;;  Returns:  Point (UCS) transformed to account for Ortho    ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:OrthoPoint-trans (base point) 
  (if (zerop (getvar 'ORTHOMODE)) 
    point
    (apply 'polar 
           (cons base 
                 ((lambda (n / a x z) 
                    (setq x (- (car (trans point 0 n)) (car (trans base 0 n)))
                          z (- (caddr (trans point 0 n)) (caddr (trans base 0 n)))
                          a (angle '(0. 0. 0.) n)
                    )
                    (if (< (abs z) (abs x)) 
                      (list (+ a (/ pi 2.)) x)
                      (list a z)
                    )
                  ) 
                   (trans (getvar 'UCSXDIR) 0 1)
                 )
           )
    )
  )
)


;#endregion
;#region Pad Between Strings

;;----------------=={ Pad Between recursive }==---------------;;
;;                                                            ;;
;;  Returns a string of a minimum specified length which is   ;;
;;  the concatenation of two supplied strings padded to a     ;;
;;  desired length using a supplied character.                ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  s1,s2 - strings to be concatenated                        ;;
;;  ch    - character for padding                             ;;
;;  ln    - minimum length of returned string                 ;;
;;------------------------------------------------------------;;
;;  Returns:  Concatenation of s1,s2 padded to a min length   ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:PadBetween-r (s1 s2 ch ln) 
  (if (< (+ (strlen s1) (strlen s2)) ln) 
    (Remote>>LM:PadBetween-r (strcat s1 ch) s2 ch ln)
    (strcat s1 s2)
  )
)


;;---------------------=={ Pad Between }==--------------------;;
;;                                                            ;;
;;  Returns a string of a minimum specified length which is   ;;
;;  the concatenation of two supplied strings padded to a     ;;
;;  desired length using a supplied character.                ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  s1,s2 - strings to be concatenated                        ;;
;;  ch    - character for padding                             ;;
;;  ln    - minimum length of returned string                 ;;
;;------------------------------------------------------------;;
;;  Returns:  Concatenation of s1,s2 padded to a min length   ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:PadBetween (s1 s2 ch ln) 
  ((lambda (a b c) 
     (repeat (- ln (length b) (length c)) (setq c (cons a c)))
     (vl-list->string (append b c))
   ) 
    (ascii ch)
    (vl-string->list s1)
    (vl-string->list s2)
  )
)


;#endregion
;#region Parse Numbers


;; Parse Numbers  -  Lee Mac
;; Parses a list of numerical values from a supplied string.

(defun Remote>>LM:parsenumbers (str) 
  ((lambda (l) 
     (read 
       (strcat "(" 
               (vl-list->string 
                 (mapcar 
                   '(lambda (a b c) 
                      (if 
                        (or (< 47 b 58) 
                            (and (= 45 b) (< 47 c 58) (not (< 47 a 58)))
                            (and (= 46 b) (< 47 a 58) (< 47 c 58))
                        )
                        b
                        32
                      )
                    )
                   (cons nil l)
                   l
                   (append (cdr l) '(()))
                 )
               )
               ")"
       )
     )
   ) 
    (vl-string->list str)
  )
)


;#endregion
;#region Permutations


;;---------------------=={ Permutations }==-------------------;;
;;                                                            ;;
;;  Returns a list of all permutations of elements in a list  ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  l - list to process                                       ;;
;;------------------------------------------------------------;;
;;  Returns: List of all permutations of elements in the list ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:Permutations (l) 
  (if (cdr l) 
    ((lambda (f) 
       (f 
         (apply 'append 
                (mapcar 
                  (function 
                    (lambda (a) 
                      (mapcar (function (lambda (b) (cons a b))) 
                              (Remote>>LM:Permutations 
                                ((lambda (f) (f a l)) 
                                  (lambda (a l) 
                                    (if l 
                                      (if (equal a (car l)) 
                                        (cdr l)
                                        (cons (car l) (f a (cdr l)))
                                      )
                                    )
                                  )
                                )
                              )
                      )
                    )
                  )
                  l
                )
         )
       )
     ) 
      (lambda (l) (if l (cons (car l) (f (vl-remove (car l) (cdr l))))))
    )
    (list l)
  )
)


;#endregion
;#region Polygon Centroid

;; Polygon Centroid  -  Lee Mac
;; Returns the WCS Centroid of an LWPolyline Polygon Entity

(defun Remote>>LM:PolyCentroid (e / l) 
  (foreach x (setq e (entget e)) 
    (if (= 10 (car x)) (setq l (cons (cdr x) l)))
  )
  ((lambda (a) 
     (if (not (equal 0.0 a 1e-8)) 
       (trans 
         (mapcar '/ 
                 (apply 'mapcar 
                        (cons '+ 
                              (mapcar 
                                (function 
                                  (lambda (a b) 
                                    ((lambda (m) 
                                       (mapcar 
                                         (function 
                                           (lambda (c d) (* (+ c d) m))
                                         )
                                         a
                                         b
                                       )
                                     ) 
                                      (- (* (car a) (cadr b)) (* (car b) (cadr a)))
                                    )
                                  )
                                )
                                l
                                (cons (last l) l)
                              )
                        )
                 )
                 (list a a)
         )
         (cdr (assoc 210 e))
         0
       )
     )
   ) 
    (* 3.0 
       (apply '+ 
              (mapcar 
                (function 
                  (lambda (a b) 
                    (- (* (car a) (cadr b)) (* (car b) (cadr a)))
                  )
                )
                l
                (cons (last l) l)
              )
       )
    )
  )
)


;#endregion
;#region Random Number Functions


;; Rand  -  Lee Mac
;; PRNG implementing a linear congruential generator with
;; parameters derived from the book 'Numerical Recipes'

(defun Remote>>LM:rand (/ a c m) 
  (setq m   4294967296.0
        a   1664525.0
        c   1013904223.0
        $xn (rem (+ c (* a (cond ($xn) ((getvar 'date))))) m)
  )
  (/ $xn m)
)


;; Random in Range  -  Lee Mac
;; Returns a pseudo-random integral number in a given range (inclusive)

(defun Remote>>LM:randrange (a b) 
  (+ (min a b) (fix (* (Remote>>LM:rand) (1+ (abs (- a b))))))
)


;#endregion
;#region Read CSV
;;-------------------------=={ Read CSV }==------------------------;;

;; Read CSV  -  Lee Mac
;; Parses a CSV file into a matrix list of cell values.
;; csv - [str] filename of CSV file to read
 
(defun Remote>>LM:readcsv (csv / des lst sep str) 
  (if (setq des (open csv "r")) 
    (progn 
      (setq sep (cond ((vl-registry-read "HKEY_CURRENT_USER\\Control Panel\\International" "sList")) (",")))
      (while (setq str (read-line des)) 
        (setq lst (cons (Remote>>LM:csv->lst str sep 0) lst))
      )
      (close des)
    )
  )
  (reverse lst)
)
 
;; CSV -> List  -  Lee Mac
;; Parses a line from a CSV file into a list of cell values.
;; str - [str] string read from CSV file
;; sep - [str] CSV separator token
;; pos - [int] initial position index (always zero)
 
(defun Remote>>LM:csv->lst (str sep pos / s) 
  (cond 
    ((not (setq pos (vl-string-search sep str pos)))
     (if (wcmatch str "\"*\"") 
       (list (Remote>>LM:csv-replacequotes (substr str 2 (- (strlen str) 2))))
       (list str)
     )
    )
    ((or (wcmatch (setq s (substr str 1 pos)) "\"*[~\"]") 
         (and (wcmatch s "~*[~\"]*") (= 1 (logand 1 pos)))
     )
     (Remote>>LM:csv->lst str sep (+ pos 2))
    )
    ((wcmatch s "\"*\"")
     (cons 
       (Remote>>LM:csv-replacequotes (substr str 2 (- pos 2)))
       (Remote>>LM:csv->lst (substr str (+ pos 2)) sep 0)
     )
    )
    ((cons s (Remote>>LM:csv->lst (substr str (+ pos 2)) sep 0)))
  )
)
 
(defun Remote>>LM:csv-replacequotes (str / pos) 
  (setq pos 0)
  (while (setq pos (vl-string-search "\"\"" str pos)) 
    (setq str (vl-string-subst "\"" "\"\"" str pos)
          pos (1+ pos)
    )
  )
  str
)
;#endregion
;#region 3D Rotate by Matrix
;;----------------=={ 3D Rotate by Matrix }==-----------------;;
;;                                                            ;;
;;  Rotates a VLA-Object or Point List about a 3D axis using  ;;
;;  a Transformation matrix.                                  ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  target - VLA-Object or Point List to Rotate               ;;
;;  p1,p2  - Two 3D points defining the axis of rotation      ;;
;;  ang    - Rotation Angle                                   ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:Rotate3D (Remote>>LM:target p1 p2 ang / ux uy uz) 

  (mapcar 'set '(ux uy uz) (setq u (Remote>>LM:unit (mapcar '- p2 p1))))

  (Remote>>LM:ApplyMatrixTransformation 
    Remote>>LM:target
    (setq m (Remote>>LM:m+m 
              (list 
                (list (cos ang) 0. 0.)
                (list 0. (cos ang) 0.)
                (list 0. 0. (cos ang))
              )
              (Remote>>LM:m+m 
                (Remote>>LM:mxs 
                  (list 
                    (list 0. (- uz) uy)
                    (list uz 0. (- ux))
                    (list (- uy) ux 0.)
                  )
                  (sin ang)
                )
                (Remote>>LM:mxs (mapcar '(lambda (e) (Remote>>LM:vxs u e)) u) (- 1. (cos ang)))
              )
            )
    )
    (mapcar '- p1 (Remote>>LM:mxv m p1))
  )
)

;;----------------=={ 3D Reflect by Matrix }==----------------;;
;;                                                            ;;
;;  Reflects a VLA-Object or Point List in a plane using a    ;;
;;  Transformation matrix.                                    ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  target   - VLA-Object or Point List to Reflect            ;;
;;  p1,p2,p3 - Three 3D points defining the reflection plane  ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:Reflect3D (Remote>>LM:target p1 p2 p3 / m u ux uy uz) 

  (mapcar 'set '(ux uy uz) (setq u (Remote>>LM:unit (Remote>>LM:v^v (mapcar '- p2 p1) (mapcar '- p3 p1)))))

  (Remote>>LM:ApplyMatrixTransformation 
    Remote>>LM:target
    (setq m (list 
              (list (- 1. (* 2. ux ux)) (* -2. uy ux) (* -2. ux uz))
              (list (* -2. ux uy) (- 1. (* 2. uy uy)) (* -2. uy uz))
              (list (* -2. ux uz) (* -2. uy uz) (- 1. (* 2. uz uz)))
            )
    )
    (mapcar '- p1 (Remote>>LM:mxv m p1))
  )
)


;;-----------=={ Apply Matrix Transformation }==--------------;;
;;                                                            ;;
;;  Transforms a VLA-Object or Point List using a             ;;
;;  Transformation Matrix                                     ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2010 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  target - VLA-Object or Point List to Transform            ;;
;;  matrix - 3x3 Matrix by which to Transform object          ;;
;;  vector - 3D translation vector                            ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:ApplyMatrixTransformation (Remote>>LM:target matrix vector) 
  (vl-load-com)
  (cond 
    ((eq 'VLA-OBJECT (type target))

     (vla-TransformBy Remote>>LM:target 
                      (vlax-tMatrix 
                        (append (mapcar '(lambda (x v) (append x (list v))) matrix vector) 
                                '((0. 0. 0. 1.))
                        )
                      )
     )
    )
    ((listp Remote>>LM:target)

     (mapcar 
       (function 
         (lambda (point) (mapcar '+ (Remote>>LM:mxv matrix point) vector))
       )
       Remote>>LM:target
     )
    )
  )
)

;#endregion
;#region Release Object
;;-------------------------=={ Release Object }==------------------------;;

;;------------------=={ Release Object }==--------------------;;
;;                                                            ;;
;;  Releases a VLA Object from memory via plentiful error     ;;
;;  trapping                                                  ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2010 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  obj - VLA Object to be released from memory               ;;
;;------------------------------------------------------------;;
;;  Returns:  T if Object Released, else nil                  ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:ReleaseObject (obj) 
  (and obj 
       (eq 'VLA-OBJECT (type obj))
       (not (vlax-object-released-p obj))
       (not 
         (vl-catch-all-error-p 
           (vl-catch-all-apply 'vlax-release-object (list obj))
         )
       )
  )
)

;#endregion
;#region Remove Items

;;--------------------=={ Remove Items }==--------------------;;
;;                                                            ;;
;;  Removes the items at specified indexes from a list        ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  items - list of zero-based indexes to remove              ;;
;;  lst   - list from which items are to be removed           ;;
;;------------------------------------------------------------;;
;;  Returns:  List with items removed                         ;;
;;------------------------------------------------------------;;
;;  Recursive

(defun Remote>>LM:RemoveItems-r (items lst) 
  (if (and lst items) 
    (if (zerop (car items)) 
      (Remote>>LM:RemoveItems (mapcar '1- (cdr items)) (cdr lst))
      (cons (car lst) (Remote>>LM:RemoveItems (mapcar '1- items) (cdr lst)))
    )
    lst
  )
)


;;--------------------=={ Remove Items }==--------------------;;
;;                                                            ;;
;;  Removes the items at specified indexes from a list        ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  items - list of zero-based indexes to remove              ;;
;;  lst   - list from which items are to be removed           ;;
;;------------------------------------------------------------;;
;;  Returns:  List with items removed                         ;;
;;------------------------------------------------------------;;
;;  Iterative

(defun Remote>>LM:RemoveItems (items lst / i) 
  (setq i -1)
  (vl-remove-if '(lambda (x) (member (setq i (1+ i)) items)) lst)
)
;#endregion
;#region Remove Nth


;;----------------------=={ Remove Nth }==--------------------;;
;;                                                            ;;
;;  Removes the item at the nth index in a supplied list      ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  n - index of item to remove (zero based)                  ;;
;;  l - list from which item is to be removed                 ;;
;;------------------------------------------------------------;;
;;  Returns:  List with item at index n removed               ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:RemoveNth (n l) 
  (if (and l (< 0 n)) 
    (cons (car l) (Remote>>LM:RemoveNth (1- n) (cdr l)))
    (cdr l)
  )
)


;;-------------------------=={ Remove Once }==------------------------;;

;;----------------------=={ Remove Nth }==--------------------;;
;;                                                            ;;
;;  Removes the item at the nth index in a supplied list      ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  n - index of item to remove (zero based)                  ;;
;;  l - list from which item is to be removed                 ;;
;;------------------------------------------------------------;;
;;  Returns:  List with item at index n removed               ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:RemoveNth (n l / i) 
  (setq i -1)
  (vl-remove-if '(lambda (x) (= (setq i (1+ i)) n)) l)
)

;#endregion
;#region Rounding Functions

;; Round  -  Lee Mac
;; Rounds 'n' to the nearest integer

(defun Remote>>LM:round (n) 
  (fix (+ n (if (minusp n) -0.5 0.5)))
)


;; Round Multiple  -  Lee Mac
;; Rounds 'n' to the nearest multiple of 'm'

(defun Remote>>LM:roundm (n m) 
  (* m (fix ((if (minusp n) - +) (/ n (float m)) 0.5)))
)


;; Round To  -  Lee Mac
;; Rounds 'n' to 'p' decimal places

(defun Remote>>LM:roundto (n p) 
  (Remote>>LM:roundm n (expt 10.0 (- p)))
)


;; Round Up  -  Lee Mac
;; Rounds 'n' up to the nearest 'm'

(defun Remote>>LM:roundup (n m) 
  ((lambda (r) (cond ((equal 0.0 r 1e-8) n) ((< n 0) (- n r)) ((+ n (- m r))))) (rem n m))
)


;; Round Down  -  Lee Mac
;; Rounds 'n' down to the nearest 'm'

(defun Remote>>LM:rounddown (n m) 
  ((lambda (r) (cond ((equal 0.0 r 1e-8) n) ((< n 0) (- n r m)) ((- n r)))) (rem n m))
)

;#endregion
;#region Select If

;;---------------------=={ Select if }==----------------------;;
;;                                                            ;;
;;  Provides continuous selection prompts until either a      ;;
;;  predicate function is validated or a keyword is supplied. ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  msg  - prompt string                                      ;;
;;  pred - optional predicate function [selection list arg]   ;;
;;  func - selection function to invoke                       ;;
;;  keyw - optional initget argument list                     ;;
;;------------------------------------------------------------;;
;;  Returns:  Entity selection list, keyword, or nil          ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:SelectIf (msg pred func keyw / sel) 
  (setq pred (eval pred))
  (while 
    (progn (setvar 'ERRNO 0) 
           (if keyw (apply 'initget keyw))
           (setq sel (func msg))
           (cond 
             ((= 7 (getvar 'ERRNO))
              (princ "\nMissed, Try again.")
             )
             ((eq 'STR (type sel))
              nil
             )
             ((vl-consp sel)
              (if (and pred (not (pred sel))) 
                (princ "\nInvalid Object Selected.")
              )
             )
           )
    )
  )
  sel
)

;#endregion
;#region Selection Set Bounding Box

;; Selection Set Bounding Box  -  Lee Mac
;; Returns a list of the lower-left and upper-right WCS coordinates of a
;; rectangular frame bounding all objects in a supplied selection set.
;; sel - [sel] Selection set for which to return bounding box

(defun Remote>>LM:ssboundingbox (sel / idx llp ls1 ls2 obj urp) 
  (repeat (setq idx (sslength sel)) 
    (setq obj (vlax-ename->vla-object (ssname sel (setq idx (1- idx)))))
    (if 
      (and (vlax-method-applicable-p obj 'getboundingbox) 
           (not (vl-catch-all-error-p (vl-catch-all-apply 'vla-getboundingbox (list obj 'llp 'urp))))
      )
      (setq ls1 (cons (vlax-safearray->list llp) ls1)
            ls2 (cons (vlax-safearray->list urp) ls2)
      )
    )
  )
  (if (and ls1 ls2) 
    (mapcar '(lambda (a b) (apply 'mapcar (cons a b))) '(min max) (list ls1 ls2))
  )
)


;; Selection Set Bounding Box  -  Lee Mac
;; Returns a list of the lower-left and upper-right WCS coordinates of a
;; rectangular frame bounding all objects in a supplied selection set.
;; sel - [sel] Selection set for which to return bounding box
;;  Alternative to the above function

(defun Remote>>LM:ssboundingbox~ (sel / idx llp ls1 ls2 obj urp) 
  (repeat (setq idx (sslength sel)) 
    (setq obj (vlax-ename->vla-object (ssname sel (setq idx (1- idx)))))
    (if 
      (and (vlax-method-applicable-p obj 'getboundingbox) 
           (not (vl-catch-all-error-p (vl-catch-all-apply 'vla-getboundingbox (list obj 'llp 'urp))))
      )
      (setq ls1 (mapcar 'min (vlax-safearray->list llp) (cond (ls1) ((vlax-safearray->list llp))))
            ls2 (mapcar 'max (vlax-safearray->list urp) (cond (ls2) ((vlax-safearray->list urp))))
      )
    )
  )
  (if (and ls1 ls2) (list ls1 ls2))
)

;#endregion
;#region Selection Set to List
;;-------------------------=={ Selection Set to List }==------------------------;;

;;--------------=={ SelectionSet -> Entities }==--------------;;
;;                                                            ;;
;;  Converts a SelectionSet to a list of Entities             ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  ss - Valid SelectionSet (Pickset)                         ;;
;;------------------------------------------------------------;;
;;  Returns:  List of Entity names, else nil                  ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:ss->ent (ss / i l) 
  (if ss 
    (repeat (setq i (sslength ss)) 
      (setq l (cons (ssname ss (setq i (1- i))) l))
    )
  )
)


;;------------=={ SelectionSet -> VLA Objects }==-------------;;
;;                                                            ;;
;;  Converts a SelectionSet to a list of VLA Objects          ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  ss - Valid SelectionSet (Pickset)                         ;;
;;------------------------------------------------------------;;
;;  Returns:  List of VLA Objects, else nil                   ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:ss->vla (ss / i l) 
  (if ss 
    (repeat (setq i (sslength ss)) 
      (setq l (cons (vlax-ename->vla-object (ssname ss (setq i (1- i)))) l))
    )
  )
)

;#endregion
;#region String Subst

;;--------------------=={ String Subst }==--------------------;;
;;                                                            ;;
;;  Substitutes a string for all occurrences of another       ;;
;;  string within a string.                                   ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  new - string to be substituted for 'old'                  ;;
;;  old - string to be replaced                               ;;
;;  str - the string to be searched                           ;;
;;------------------------------------------------------------;;
;;  Returns:  String with 'old' replaced with 'new'           ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:StringSubst (new old str / inc len) 
  (setq len (strlen new)
        inc 0
  )
  (while (setq inc (vl-string-search old str inc)) 
    (setq str (vl-string-subst new old str inc)
          inc (+ inc len)
    )
  )
  str
)


;#endregion
;#region String to List 
;;-------------------------=={ String to List }==------------------------;;

;; String to List  -  Lee Mac
;; Separates a string using a given delimiter
;; str - [str] String to process
;; del - [str] Delimiter by which to separate the string
;; Returns: [lst] List of strings
;;  Recursive
 
(defun Remote>>LM:str->lst-r (str del / pos) 
  (if (setq pos (vl-string-search del str)) 
    (cons (substr str 1 pos) (Remote>>LM:str->lst-r (substr str (+ pos 1 (strlen del))) del))
    (list str)
  )
)


;; String to List  -  Lee Mac
;; Separates a string using a given delimiter
;; str - [str] String to process
;; del - [str] Delimiter by which to separate the string
;; Returns: [lst] List of strings
;;  Iterative

(defun Remote>>LM:str->lst (str del / len lst pos) 
  (setq len (1+ (strlen del)))
  (while (setq pos (vl-string-search del str)) 
    (setq lst (cons (substr str 1 pos) lst)
          str (substr str (+ pos len))
    )
  )
  (reverse (cons str lst))
)

;#endregion
;#region String Wrap
;;---------------------=={ String Wrap }==--------------------;;
;;                                                            ;;
;;  Breaks a string at spaces (if possible) into a list of    ;;
;;  substrings of a specified length or less.                 ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  str - String to wrap to a specific length                 ;;
;;  len - Maximum length of each substring                    ;;
;;------------------------------------------------------------;;
;;  Returns:  List of substrings of specified length or less  ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:StringWrap (str len / pos) 
  (if (< len (strlen str)) 
    (cons 
      (substr str 
              1
              (cond 
                ((setq pos (vl-string-position 32 (substr str 1 len) nil t)))
                ((setq pos (1- len)) len)
              )
      )
      (Remote>>LM:StringWrap (substr str (+ 2 pos)) len)
    )
    (list str)
  )
)

;#endregion
;#region Sublist
;;-------------------------=={ Sublist }==------------------------;;

;; Sublst  -  Lee Mac
;; The list analog of the substr function
;; lst - [lst] List from which sublist is to be returned
;; idx - [int] Zero-based index at which to start the sublist
;; len - [int] Length of the sublist or nil to return all items following idx
;;  Recursive

(defun Remote>>LM:sublst-r (lst idx len) 
  (cond 
    ((null lst) nil)
    ((< 0 idx) (Remote>>LM:sublst-r (cdr lst) (1- idx) len))
    ((null len) lst)
    ((< 0 len) (cons (car lst) (Remote>>LM:sublst-r (cdr lst) idx (1- len))))
  )
)


;; Sublst  -  Lee Mac
;; The list analog of the substr function
;; lst - [lst] List from which sublist is to be returned
;; idx - [int] Zero-based index at which to start the sublist
;; len - [int] Length of the sublist or nil to return all items following idx
;;  Iterative

(defun Remote>>LM:sublst (lst idx len / rtn) 
  (setq len (if len (min len (- (length lst) idx)) (- (length lst) idx))
        idx (+ idx len)
  )
  (repeat len (setq rtn (cons (nth (setq idx (1- idx)) lst) rtn)))
)

;#endregion
;#region Subst Once
;;---------------------=={ Subst Once }==---------------------;;
;;                                                            ;;
;;  Substitutes the first occurrence of item 'b' for item 'a' ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  a - item to be substituted                                ;;
;;  b - item to be replaced                                   ;;
;;  l - list in which to make the substitution                ;;
;;------------------------------------------------------------;;
;;  Returns:  Resultant list following the substitution       ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:SubstOnce-r (a b l) 
  (if l 
    (if (equal b (car l)) 
      (cons a (cdr l))
      (cons (car l) (Remote>>LM:SubstOnce-r a b (cdr l)))
    )
  )
)


;;---------------------=={ Subst Once }==---------------------;;
;;                                                            ;;
;;  Substitutes the first occurrence of item 'b' for item 'a' ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  a - item to be substituted                                ;;
;;  b - item to be replaced                                   ;;
;;  l - list in which to make the substitution                ;;
;;------------------------------------------------------------;;
;;  Returns:  Resultant list following the substitution       ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:SubstOnce (a b l) 
  (mapcar 
    '(lambda (x) 
       (if (equal b x) 
         (setq x a
               a nil
               b nil
         )
       )
       x
     )
    l
  )
)

;#endregion
;#region Subst Nth
;;---------------------=={ Subst Nth }==----------------------;;
;;                                                            ;;
;;  Substitutes an item at the nth position in a list.        ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  a - item to substitute                                    ;;
;;  n - position in list to make the substitution             ;;
;;  l - list in which to make the substitution                ;;
;;------------------------------------------------------------;;
;;  Returns:  Resultant list following the substitution       ;;
;;------------------------------------------------------------;;
;;  Recursive

(defun Remote>>LM:SubstNth-r (a n l) 
  (if l 
    (if (zerop n) 
      (cons a (cdr l))
      (cons (car l) (Remote>>LM:SubstNth-r a (1- n) (cdr l)))
    )
  )
)


;;---------------------=={ Subst Nth }==----------------------;;
;;                                                            ;;
;;  Substitutes an item at the nth position in a list.        ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  a - item to substitute                                    ;;
;;  n - position in list to make the substitution             ;;
;;  l - list in which to make the substitution                ;;
;;------------------------------------------------------------;;
;;  Returns:  Resultant list following the substitution       ;;
;;------------------------------------------------------------;;
;;  Iterative

(defun Remote>>LM:SubstNth (a n l / i) 
  (setq i -1)
  (mapcar '(lambda (x) (if (= (setq i (1+ i)) n) a x)) l)
)

;#endregion
;#region Text Case Functions

;; Sentence Case - Lee Mac
;; Returns the supplied string converted to Sentence Case

(defun Remote>>LM:SentenceCase (s / f) 
  (vl-list->string 
    (mapcar 
      (function 
        (lambda (a b c) 
          (if (or f (= 46 a)) (progn (setq f (= 32 b)) b) c)
        )
      )
      (cons 46 (vl-string->list s))
      (vl-string->list (strcase s))
      (vl-string->list (strcase s t))
    )
  )
)


;; Title Case - Lee Mac
;; Returns the supplied string converted to Title Case

(defun Remote>>LM:TitleCase (s) 
  (vl-list->string 
    (mapcar 
      (function 
        (lambda (a b c) (if (= 32 a) b c))
      )
      (cons 32 (vl-string->list s))
      (vl-string->list (strcase s))
      (vl-string->list (strcase s t))
    )
  )
)


;; Toggle Case - Lee Mac
;; Returns the supplied string with the text case of each character switched

(defun Remote>>LM:ToggleCase (s) 
  (vl-list->string 
    (mapcar 
      (function 
        (lambda (a b c) (if (< 96 a 123) b c))
      )
      (vl-string->list s)
      (vl-string->list (strcase s))
      (vl-string->list (strcase s t))
    )
  )
)

;#endregion
;#region UnFormat String
;;-------------------=={ UnFormat String }==------------------;;
;;                                                            ;;
;;  Returns a string with all MText formatting codes removed. ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  str - String to Process                                   ;;
;;  mtx - MText Flag (T if string is for use in MText)        ;;
;;------------------------------------------------------------;;
;;  Returns:  String with formatting codes removed            ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:UnFormat (str mtx / _replace rx) 

  (defun _replace (new old str) 
    (vlax-put-property rx 'pattern old)
    (vlax-invoke rx 'replace str new)
  )
  (if (setq rx (vlax-get-or-create-object "VBScript.RegExp")) 
    (progn 
      (setq str (vl-catch-all-apply 
                  (function 
                    (lambda () 
                      (vlax-put-property rx 'global actrue)
                      (vlax-put-property rx 'multiline actrue)
                      (vlax-put-property rx 'ignorecase acfalse)
                      (foreach pair 
                        '(("\032" . "\\\\\\\\")
                          (" " . "\\\\P|\\n|\\t")
                          ("$1" . "\\\\(\\\\[ACcFfHLlOopQTW])|\\\\[ACcFfHLlOopQTW][^\\\\;]*;|\\\\[ACcFfHLlOopQTW]")
                          ("$1$2/$3" . "([^\\\\])\\\\S([^;]*)[/#\\^]([^;]*);")
                          ("$1$2" . "\\\\(\\\\S)|[\\\\](})|}")
                          ("$1" . "[\\\\]({)|{")
                         )
                        (setq str (_replace (car pair) (cdr pair) str))
                      )
                      (if mtx 
                        (_replace "\\\\" "\032" (_replace "\\$1$2$3" "(\\\\[ACcFfHLlOoPpQSTW])|({)|(})" str))
                        (_replace "\\" "\032" str)
                      )
                    )
                  )
                )
      )
      (vlax-release-object rx)
      (if (null (vl-catch-all-error-p str)) 
        str
      )
    )
  )
)

;#endregion
;#region Unique & Duplicate List Functions

;; Unique  -  Lee Mac
;; Returns a list with duplicate elements removed.
;;  Recursive

(defun Remote>>LM:Unique-r (l) 
  (if l (cons (car l) (Remote>>LM:Unique-r (vl-remove (car l) (cdr l)))))
)


;; Unique  -  Lee Mac
;; Returns a list with duplicate elements removed.
;;  Iterative

(defun Remote>>LM:Unique (l / x r) 
  (while l 
    (setq x (car l)
          l (vl-remove x (cdr l))
          r (cons x r)
    )
  )
  (reverse r)
)


;; Unique-p  -  Lee Mac
;; Returns T if the supplied list contains distinct items.
;;  Recursive

(defun Remote>>LM:Unique-p-r (l) 
  (or (null l) 
      (and (not (member (car l) (cdr l))) 
           (Remote>>LM:Unique-p (cdr l))
      )
  )
)


;; Unique-p  -  Lee Mac
;; Returns T if the supplied list contains distinct items.
;;  Iterative

(defun Remote>>LM:Unique-p (l) 
  (vl-every (function (lambda (x) (not (member x (setq l (cdr l)))))) l)
)


;; Unique with Fuzz  -  Lee Mac
;; Returns a list with all elements considered duplicate to
;; a given tolerance removed.
;;  Recursive

(defun Remote>>LM:UniqueFuzz-r (l f) 
  (if l 
    (cons (car l) 
          (Remote>>LM:UniqueFuzz-r 
            (vl-remove-if 
              (function (lambda (x) (equal x (car l) f)))
              (cdr l)
            )
            f
          )
    )
  )
)


;; Unique-p with Fuzz  -  Lee Mac
;; Returns T if a list contains items considered distinct to
;; a given tolerance
;;  Recursive

(defun Remote>>LM:UniqueFuzz-p-r (l f) 
  (or (null l) 
      (and (not (vl-some (function (lambda (x) (equal x (car l) f))) (cdr l))) 
           (Remote>>LM:UniqueFuzz-p-r (cdr l) f)
      )
  )
)


;; Unique-p with Fuzz  -  Lee Mac
;; Returns T if a list contains items considered distinct to
;; a given tolerance
;;  Iterative

(defun Remote>>LM:UniqueFuzz-p (l f) 
  (vl-every 
    (function 
      (lambda (x) 
        (not 
          (vl-some 
            (function 
              (lambda (y) (equal x y f))
            )
            (setq l (cdr l))
          )
        )
      )
    )
    l
  )
)


;; Unique with Fuzz  -  Lee Mac
;; Returns a list with all elements considered duplicate to
;; a given tolerance removed.
;;  Iterative

(defun Remote>>LM:UniqueFuzz (l f / x r) 
  (while l 
    (setq x (car l)
          l (vl-remove-if (function (lambda (y) (equal x y f))) (cdr l))
          r (cons x r)
    )
  )
  (reverse r)
)


;; List Duplicates  -  Lee Mac
;; Returns a list of items appearing more than once in a supplied list
;;  Recursive

(defun Remote>>LM:ListDupes-r (l) 
  (if l 
    (if (member (car l) (cdr l)) 
      (cons (car l) (Remote>>LM:ListDupes-r (vl-remove (car l) (cdr l))))
      (Remote>>LM:ListDupes-r (vl-remove (car l) (cdr l)))
    )
  )
)


;; List Duplicates  -  Lee Mac
;; Returns a list of items appearing more than once in a supplied list
;;  Iterative

(defun Remote>>LM:ListDupes (l / x r) 
  (while l 
    (if (member (setq x (car l)) (cdr l)) 
      (setq r (cons x r))
    )
    (setq l (vl-remove x (cdr l)))
  )
  (reverse r)
)


;; Count Items  -  Lee Mac
;; Returns a list of dotted pairs detailing the number of
;; occurrences of each item in a supplied list.
;;  Recursive

(defun Remote>>LM:CountItems-r (l / c x) 
  (if (setq x (car l)) 
    (progn 
      (setq c (length l)
            l (vl-remove x (cdr l))
      )
      (cons (cons x (- c (length l))) (Remote>>LM:CountItems-r l))
    )
  )
)


;; Count Items  -  Lee Mac
;; Returns a list of dotted pairs detailing the number of
;; occurrences of each item in a supplied list.
;;  Iterative

(defun Remote>>LM:CountItems (l / c l r x) 
  (while l 
    (setq x (car l)
          c (length l)
          l (vl-remove x (cdr l))
          r (cons (cons x (- c (length l))) r)
    )
  )
  (reverse r)
)

;#endregion
;#region Write CSV

;; Write CSV  -  Lee Mac
;; Writes a matrix list of cell values to a CSV file.
;; lst - [lst] list of lists, sublist is row of cell values
;; csv - [str] filename of CSV file to write
;; Returns T if successful, else nil
 
(defun Remote>>LM:writecsv (lst csv / des sep) 
  (if (setq des (open csv "w")) 
    (progn 
      (setq sep (cond ((vl-registry-read "HKEY_CURRENT_USER\\Control Panel\\International" "sList")) (",")))
      (foreach row lst (write-line (Remote>>LM:lst->csv row sep) des))
      (close des)
      t
    )
  )
)
 
;; List -> CSV  -  Lee Mac
;; Concatenates a row of cell values to be written to a CSV file.
;; lst - [lst] list containing row of CSV cell values
;; sep - [str] CSV separator token
 
(defun Remote>>LM:lst->csv (lst sep) 
  (if (cdr lst) 
    (strcat (Remote>>LM:csv-addquotes (car lst) sep) sep (Remote>>LM:lst->csv (cdr lst) sep))
    (Remote>>LM:csv-addquotes (car lst) sep)
  )
)
 
(defun Remote>>LM:csv-addquotes (str sep / pos) 
  (cond 
    ((wcmatch str (strcat "*[`" sep "\"]*"))
     (setq pos 0)
     (while (setq pos (vl-string-position 34 str pos)) 
       (setq str (vl-string-subst "\"\"" "\"" str pos)
             pos (+ pos 2)
       )
     )
     (strcat "\"" str "\"")
    )
    (str)
  )
)

;#endregion
;#region XRef Path Conversion

;;-------------=={ Relative Path to Full Path }==-------------;;
;;                                                            ;;
;;  Converts a Relative XRef path to a Full Path.             ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  dir  - Directory of the Drawing in which the Xref resides ;;
;;  path - Relative Xref Path                                 ;;
;;------------------------------------------------------------;;
;;  Returns:  Full XRef Path                                  ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:XRef:Relative->Full (dir path) 
  (setq dir (vl-string-right-trim "\\" dir))
  (cond 
    ((eq ".." (substr path 1 2))
     (Remote>>LM:XRef:Relative->Full 
       (substr dir 1 (vl-string-position 92 dir nil t))
       (substr path 4)
     )
    )
    ((eq "." (substr path 1 1))
     (strcat dir (substr path 2))
    )
    ((strcat dir "\\" path))
  )
)


;;-------------=={ Full Path to Relative Path }==-------------;;
;;                                                            ;;
;;  Converts a Full XRef path to a Relative Path.             ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  dir  - Directory of the Drawing in which the Xref resides ;;
;;  path - Full Xref Path                                     ;;
;;------------------------------------------------------------;;
;;  Returns:  Relative XRef Path                              ;;
;;------------------------------------------------------------;;

(defun Remote>>LM:XRef:Full->Relative (dir path / p q) 
  (setq dir (vl-string-right-trim "\\" dir))
  (cond 
    ((and 
       (setq p (vl-string-position 58 dir))
       (setq q (vl-string-position 58 path))
       (not (eq (strcase (substr dir 1 p)) (strcase (substr path 1 q))))
     )
     path
    )
    ((and 
       (setq p (vl-string-position 92 dir))
       (setq q (vl-string-position 92 path))
       (eq (strcase (substr dir 1 p)) (strcase (substr path 1 q)))
     )
     (Remote>>LM:Xref:Full->Relative (substr dir (+ 2 p)) (substr path (+ 2 q)))
    )
    ((and 
       (setq q (vl-string-position 92 path))
       (eq (strcase dir) (strcase (substr path 1 q)))
     )
     (strcat ".\\" (substr path (+ 2 q)))
    )
    ((eq "" dir)
     path
    )
    ((setq p (vl-string-position 92 dir))
     (Remote>>LM:Xref:Full->Relative (substr dir (+ 2 p)) (strcat "..\\" path))
    )
    ((Remote>>LM:Xref:Full->Relative "" (strcat "..\\" path)))
  )
)


;#endregion
;#region ungroup


;; Application Object  -  Lee Mac
;; Returns the VLA Application Object

(defun Remote>>LM:acapp nil 
  (eval (list 'defun 'Remote>>LM:acapp 'nil (vlax-get-acad-object)))
  (Remote>>LM:acapp)
)


;; Get Owner -  Lee Mac
;; A wrapper for the objectidtoobject method & ownerid property to enable
;; compatibility with 32-bit & 64-bit systems
 
(defun Remote>>LM:getowner (obj) 
  (eval 
    (list 'defun 
          'Remote>>LM:getowner
          '(obj)
          (if (vlax-method-applicable-p obj 'ownerid32) 
            (list 'vla-objectidtoobject32 (Remote>>LM:acdoc) '(vla-get-ownerid32 obj))
            (list 'vla-objectidtoobject (Remote>>LM:acdoc) '(vla-get-ownerid obj))
          )
    )
  )
  (Remote>>LM:getowner obj)
)


;; Catch Apply  -  Lee Mac
;; Applies a function to a list of parameters and catches any exceptions.
 
(defun Remote>>LM:catchapply (fnc prm / rtn) 
  (if (not (vl-catch-all-error-p (setq rtn (vl-catch-all-apply fnc prm)))) 
    rtn
  )
)


;; Sortents Table  -  Lee Mac
;; Retrieves the Sortents Table object.
;; obj - [vla] Block Container Object
 
(defun Remote>>LM:sortentstable (obj / dic) 
  (cond 
    ((Remote>>LM:catchapply 
       'vla-item
       (list (setq dic (vla-getextensiondictionary obj)) "acad_sortents")
     )
    )
    ((Remote>>LM:catchapply 'vla-addobject (list dic "acad_sortents" "AcDbSortentsTable")))
  )
)


;; Safearray Variant  -  Lee Mac
;; Returns a populated safearray variant of a specified data type
;; typ - [int] Variant type enum (e.g. vlax-vbdouble)
;; lst - [lst] List of static type data
 
(defun Remote>>LM:safearrayvariant (typ lst) 
  (vlax-make-variant 
    (vlax-safearray-fill 
      (vlax-make-safearray typ (cons 0 (1- (length lst))))
      lst
    )
  )
)
 

;; Active Document  -  Lee Mac
;; Returns the VLA Active Document Object
 
(defun Remote>>LM:acdoc nil 
  (eval (list 'defun 'Remote>>LM:acdoc 'nil (vla-get-activedocument (vlax-get-acad-object))))
  (Remote>>LM:acdoc)
)


;; ObjectID  -  Lee Mac
;; Returns a string containing the ObjectID of a supplied VLA-Object
;; Compatible with 32-bit & 64-bit systems
 
(defun Remote>>LM:ObjectID (obj) 
  (eval 
    (list 'defun 
          'Remote>>LM:ObjectID
          '(obj)
          (if 
            (and 
              (vl-string-search "64" (getenv "PROCESSOR_ARCHITECTURE"))
              (vlax-method-applicable-p (vla-get-utility (Remote>>LM:acdoc)) 'getobjectidstring)
            )
            (list 'vla-getobjectidstring (vla-get-utility (Remote>>LM:acdoc)) 'obj ':vlax-false)
            '(itoa (vla-get-objectid obj))
          )
    )
  )
  (Remote>>LM:ObjectID obj)
)


;; Linetypes Collection  -  Lee Mac
;; Returns the VLA Linetypes Collection for the Active Document
 
(defun Remote>>LM:aclin nil 
  (eval (list 'defun 'Remote>>LM:aclin 'nil (vla-get-linetypes (vla-get-activedocument (vlax-get-acad-object)))))
  (Remote>>LM:aclin)
)

;; Object List Bounding Box  -  Lee Mac
;; Returns the lower-left and upper-right points of a rectangle bounding a list of objects

(defun Remote>>LM:objlstboundingbox (lst / llp ls1 ls2 urp) 
  (foreach obj lst 
    (vla-getboundingbox obj 'llp 'urp)
    (setq ls1 (cons (vlax-safearray->list llp) ls1)
          ls2 (cons (vlax-safearray->list urp) ls2)
    )
  )
  (mapcar '(lambda (a b) (apply 'mapcar (cons a b))) '(min max) (list ls1 ls2))
)

;; Rotate Points  -  Lee Mac
;; Rotates a list of points about a supplied point by a given angle

(defun Remote>>LM:rotatepoints (lst bpt ang / mat vec) 
  (setq mat (list 
              (list (cos ang) (sin (- ang)) 0.0)
              (list (sin ang) (cos ang) 0.0)
              '(0.0 0.0 1.0)
            )
  )
  (setq vec (mapcar '- bpt (Remote>>gc:mxv mat bpt)))
  (mapcar '(lambda (x) (mapcar '+ (Remote>>gc:mxv mat x) vec)) lst)
)

;; Remove With Fuzz  -  Lee Mac
;; Removes items from a list which are equal to a supplied tolerance
 
(defun Remote>>LM:RemoveWithFuzz (l1 l2 fz) 
  (vl-remove-if 
    (function 
      (lambda (a) 
        (vl-some 
          (function (lambda (b) (equal a b fz)))
          l1
        )
      )
    )
    l2
  )
)
 
;; Get Inside Angle  -  Lee Mac
;; Returns the smaller angle subtended by three points with vertex at p2
 
(defun Remote>>LM:GetInsideAngle (p1 p2 p3) 
  ((lambda (a) (min a (- (+ pi pi) a))) 
    (rem (+ pi pi (- (angle p2 p1) (angle p2 p3))) (+ pi pi))
  )
)
;#endregion
;#endregion
