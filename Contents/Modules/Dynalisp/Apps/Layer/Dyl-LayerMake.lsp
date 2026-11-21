;; LayerMake - Make layers from CSV files
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
;;
;;-------------------------=={ End of Licence }==------------------------;;

(Defun Dyl-LayerMake (*typ *dir *lst *cop / *error* *cme *doc *lys *lin *pha *data *lyl *nwl *lyr *dsc *sel *nbr
                     *ddr *maj *mjd *trd *row *fld *str *col *truecolor *id *exp *lw *lt *plt *obj *new *upd *res)
  ;; *typ = "Csv" for layer lists or "Lyr" for a list of (name . description)
  ;; *dir = the folder of the files, under *dyl:layerlist (nil: *lst holds paths relative to it)
  ;; *lst = the CSV files (Designator,Major,Minor1,Minor2,Minor3,Description)
  ;; The placeholders of the files:
  ;;   $$ or ?? (designator)  the discipline asked (General, Architectural...)
  ;;   A? (designator)        the discipline alone: the ? is dropped (NCS)
  ;;   Maj$ or Majr (major)   the major group asked, MajrDesc$ / GroupTyp its description
  ;;   0000                   the stack asked (0001...), dropped for None
  ;;   ----                   an empty field, dropped; a ~ pads a short field, dropped

  ;; Error handling function:
  (defun *error* (*erm)
    (if *cme (setvar 'cmdecho *cme))
    (if *doc (vla-EndUndoMark *doc))
    (if (not (member *erm '("Function cancelled" "quit / exit abort")))
      (princ (strcat "\nError: " *erm))
    )
    (princ)
  )
  (setq *cme (getvar 'cmdecho))
  (setvar 'cmdecho 0)


  ;; Default variable values/reset:
  (setq *pha  '("")
        *cop  "MinorColor"
        *data '()
        *lyl  '()
        *nwl  '()
        *nbr  "----"
        *ddr  "G"
  )


  ;; Get CSV data:
  (if (= *typ "Lyr") (setq *lyl (reverse *lst)))
  (if (= *typ "Csv")
    (foreach *fle *lst
      (setq *fle (strcat *dyl:layerlist "\\" (if *dir (strcat *dir "\\") "") *fle))
      (if (findfile (Dyl:UserFile *fle))
        (setq *data (append *data (cdr (Local>>LM:readcsv (Dyl:UserFile *fle)))))
        (prompt (strcat "\nLayer list not found: " *fle))
      )
    )
  )
  ;; Only the rows with a name:
  (setq *data (vl-remove-if-not '(lambda (r) (and (>= (length r) 2) (/= "" (car r)))) *data))


  ;; Check data for stackable layers (0000 in data) and ask user for the desired stack:
  (setq *trd (Local>>getMatching "*0000*" *data))
  (if (= *trd "Yes")
    (progn
      (initget
        "None 1-First 2-Second 3-Third 4-Fourth 5-Fifth 6-Sixth 7-Seventh 8-Eighth 9-Ninth _N S1 S2 S3 S4 S5 S6 S7 S8 S9"
      )
      (setq *sel (getkword
                   (strcat
                     "\nSelect layer stacked: [None/1-First/2-Second/3-Third/4-Fourth/5-Fifth/6-Sixth/7-Seventh/8-Eighth/9-Ninth] <N>: "
                   )
                 )
      )
      (setq *nbr (if (and *sel (wcmatch *sel "S#")) (strcat "000" (substr *sel 2)) "----"))
    )
  )


  ;; Check data for variable designator layers ($$ or ?? in data) and ask user for the discipline:
  (if (= "Yes" (Local>>getMatching "$$,`?`?" (mapcar 'list (mapcar 'car *data))))
    (progn
      (initget
        "General Architectural Interior Structural Landscape _G A I S L"
      )
      (setq *sel (getkword
                   (strcat
                     "\nSelect layer discipline: [General/Architectural/Interior/Structural/Landscape] <G>: "
                   )
                 )
      )
      (setq *ddr (if *sel *sel "G"))
    )
  )


  ;; Check data for a variable major group (Maj$ or Majr) and ask user for it:
  (if (= "Yes" (Local>>getMatching "Maj$,Majr" (mapcar 'list (mapcar 'cadr *data))))
    (progn
      (while
        (progn
          (setq *maj (getstring "\nMajor group of the layers, 4 characters <Detl>: "))
          (if (= "" *maj) (setq *maj "Detl"))
          (if (or (/= 4 (strlen *maj)) (not (snvalid *maj)) (wcmatch *maj "*-*"))
            (prompt "\nA major group is 4 characters, letters or digits (Detl, Wall, Flor...).")
          )
        )
      )
      (setq *maj (strcat (strcase (substr *maj 1 1)) (strcase (substr *maj 2) T))
            *mjd (Local>>MajorDesc *maj)
      )
    )
  )


  ;; Build data into a list of (name . description), without the names twice:
  (foreach *row *data
    (setq *str '())
    (foreach *fld (Local>>FirstN 5 *row)
      (cond
        ((wcmatch *fld "$$,`?`?") (setq *fld *ddr))
        ((wcmatch *fld "Maj$,Majr") (setq *fld *maj))
        ((= *fld "0000") (setq *fld *nbr))
      )
      (setq *fld (vl-string-trim " " (vl-string-translate "?~" "  " *fld)))
      (if (not (member *fld '("" "----"))) (setq *str (cons *fld *str)))
    )
    (setq *lyr (Local>>LM:lst->str (reverse *str) "-")
          *dsc (cond ((nth 5 *row)) (""))
    )
    (if *mjd
      (foreach *pat '("MajrDesc$" "GroupTyp")
        (while (vl-string-search *pat *dsc) (setq *dsc (vl-string-subst *mjd *pat *dsc)))
      )
    )
    (if (and (/= "" *lyr) (not (assoc *lyr *lyl))) (setq *lyl (cons (cons *lyr *dsc) *lyl)))
  )
  (setq *lyl (reverse *lyl))

  ;; Build a new list of list with phased layer name:
  (foreach x *lyl
    (foreach z *pha
      (setq *lyr (car x))
      (setq *lyr (strcat *lyr z))
      (setq *nwl (cons (cons *lyr (cdr x)) *nwl))
    )
  )
  (setq *nwl (reverse *nwl)
        *doc (vla-get-ActiveDocument (vlax-get-acad-object))
        *lys (vla-get-Layers *doc)
        *lin (if (= 1 (getvar 'measurement)) "acadiso.lin" "acad.lin")
        *new 0
        *upd 0
  )
  (vla-StartUndoMark *doc)



  ;;; ;; List of List Fltering/Formating:
  ;;; (foreach x *lyl
  ;;;   (setq *len (strlen (car x)))
  ;;;   (if (> 7 *len)
  ;;;     (progn
  ;;;       (setq *lyr (substr (car x) 1 6))
  ;;;       (if (not (assoc *lyr *nwl))
  ;;;         (progn
  ;;;           (setq *dsc (cdr x))
  ;;;           (if (wcmatch *dsc "*:*")
  ;;;             (setq *dsc (substr *dsc 1 (vl-string-search ":" *dsc)))
  ;;;           )
  ;;;           (setq *nwl (cons (cons *lyr *dsc) *nwl))
  ;;;         )
  ;;;       )
  ;;;     )
  ;;;   )
  ;;; )

  ;;; ;; Add Identification layer for every component type in the list of list:
  ;;; (foreach x *nwl
  ;;;   (setq *lyr (car x)
  ;;;         *dsc (cdr x)
  ;;;   )
  ;;;   (if
  ;;;     (or
  ;;;       (wcmatch *lyr "*Wall*")
  ;;;       (wcmatch *lyr "*Glaz*")
  ;;;       (wcmatch *lyr "*Curt*")
  ;;;       (wcmatch *lyr "*Flor*")
  ;;;       (wcmatch *lyr "*Ceil*")
  ;;;       (wcmatch *lyr "*Door*")
  ;;;       (wcmatch *lyr "*Cols*")
  ;;;       (wcmatch *lyr "*Beam*")
  ;;;       (wcmatch *lyr "*Eqpm*")
  ;;;       (wcmatch *lyr "*Roof*")
  ;;;       (wcmatch *lyr "*Hvac*")
  ;;;       (wcmatch *lyr "*Lite*")
  ;;;       (wcmatch *lyr "*Furn*")
  ;;;       (wcmatch *lyr "*Fenc*")
  ;;;       (wcmatch *lyr "*Cswk*")
  ;;;       (wcmatch *lyr "*Fnsh*")
  ;;;       (wcmatch *lyr "*Prtn*")
  ;;;       (wcmatch *lyr "*Irrg*")
  ;;;       (wcmatch *lyr "*Plnt*")
  ;;;       (wcmatch *lyr "*Pvmt*")
  ;;;       (wcmatch *lyr "*Brcg*")
  ;;;       (wcmatch *lyr "*Deck*")
  ;;;       (wcmatch *lyr "*Fndn*")
  ;;;       (wcmatch *lyr "*Jois*")
  ;;;       (wcmatch *lyr "*Lntl*")
  ;;;       (wcmatch *lyr "*Strs*")
  ;;;       (wcmatch *lyr "*Slab*")
  ;;;       (wcmatch *lyr "*Trus*")
  ;;;       (wcmatch *lyr "*Area*")
  ;;;     )
  ;;;     (setq *lyl (cons (cons (strcat *lyr "-Iden") (strcat *dsc ": Identifications")) *lyl))
  ;;;   )
  ;;; )

  ;;; (foreach x *lyl
  ;;;   (setq *lyr (substr (car x) 1 1)
  ;;;         *dsc (cdr x)
  ;;;         *tml '()
  ;;;   )
  ;;;   (if (not (member *lyr *tml))
  ;;;     (progn
  ;;;       (setq *tml (cons *lyr *tml))
  ;;;       (setq *lyl (cons (cons *lyr "Annotations") *lyl))
  ;;;     )
  ;;;   )
  ;;; )






  (foreach z *nwl 

    ;; default reset value
    (setq *lyr       (car z)
          *dsc       (cdr z)
          *col       "151"
          *truecolor "No"
    )

    ;; Thickness assigmenet befor group override (color will be changed unless MinorColor is selected):
    (if (not (wcmatch *lyr "?-Elev*")) 
      (progn 
        (if (wcmatch *lyr "*Gcvr*,*Deck*") (setq *col "189"))
      )
    )
    (if (wcmatch *lyr "*Patt*") (setq *col "189"))


    ;;  Group override:
    (setq *id (substr *col 1 2))
    (if (= "DesignatorColor" *cop) 
      (progn 
        (if (wcmatch *lyr "A*") (setq *col (vl-string-subst "02" *id *col)))
        (if (wcmatch *lyr "S*") (setq *col (vl-string-subst "10" *id *col)))
        (if (wcmatch *lyr "M*") (setq *col (vl-string-subst "18" *id *col)))
        (if (wcmatch *lyr "E*") (setq *col (vl-string-subst "18" *id *col)))
        (if (wcmatch *lyr "I*") (setq *col (vl-string-subst "04" *id *col)))
        (if (wcmatch *lyr "C*") (setq *col (vl-string-subst "18" *id *col)))
        (if (wcmatch *lyr "L*") (setq *col (vl-string-subst "08" *id *col)))
        (if (wcmatch *lyr "P*") (setq *col (vl-string-subst "18" *id *col)))
      )
    )
    (if (= "MajorColor" *cop) 
      (progn 
        (if (wcmatch *lyr "?-*") 
          (setq *exp (substr *lyr 3 4))
          (setq *exp (substr *lyr 4 4))
        )
        ;;  Site and landscape components:
        (if (wcmatch *exp "Plnt,Site") (setq *col (vl-string-subst "08" *id *col)))
        ;;  Hot Water, safety and healt systems:
        (if (wcmatch *exp "Mdgs,Alrm,Hwtr,Stem,Smok,Fume,Fire") (setq *col (vl-string-subst "02" *id *col)))
        ;;  Telecom, media and sound components:
        (if (wcmatch *exp "Catv,Auxl,Data,Bell,Clok,Cctv,Comm,Soun,Nurs,Intc") 
          (setq *col (vl-string-subst "24" *id *col))
        )
        ;;  Opening and transportation components:
        (if (wcmatch *exp "Strs,Curt,Door") (setq *col (vl-string-subst "14" *id *col)))
        ;;  Design and graphical components:
        (if (wcmatch *exp "Crpt,Mill,Tile,Fnsh,Furn,Cswk") (setq *col (vl-string-subst "18" *id *col)))
        ;;  Space defining and structural components:
        (if 
          (wcmatch *exp 
                   "
                      Bldg,
                      Clng,
                      Prtn,
                      Fenc,
                      Wall,
                      Flor,
                      Brcg,
                      Trus,
                      Lntl,
                      Fndn,
                      Jois,
                      Deck,
                      Cols,
                      Beam,
                      Slab
                     "
          )
          (setq *col (vl-string-subst "10" *id *col))
        )
        ;;  Graphical, Design and suggested components:
        (if (wcmatch *exp "Afld,Brdg,Tral,Pvmt,Road,Prkg,Rail") (setq *col (vl-string-subst "18" *id *col)))
        ;;  Electrical alimentation and appliances:
        (if (wcmatch *exp "Cabl,Ener,Exhs,Ngas,Powr,Pvmd,Ltng,Lite,Elht,Rcov,Glyc,Fuel,") 
          (setq *col (vl-string-subst "04" *id *col))
        )
        ;;  Cold Water and sanitary components:
        (if (wcmatch *exp "Chan,Dfld,Swlk,Wetl,Wway,Rivr,Watr,Sswr,Strm,Irrg,Cndw,Cwtr,Domw,") 
          (setq *col (vl-string-subst "16" *id *col))
        )
        ;;  Air and ventilation components:
        (if (wcmatch *exp "Rair,Hvac,Mkup,Rair") (setq *col (vl-string-subst "06" *id *col)))
      )
    )
    (if (= "StackColor" *cop) 
      (progn 
        (if (wcmatch *lyr "*0001*") (setq *col (vl-string-subst "02" *id *col)))
        (if (wcmatch *lyr "*0002*") (setq *col (vl-string-subst "06" *id *col)))
        (if (wcmatch *lyr "*0003*") (setq *col (vl-string-subst "10" *id *col)))
        (if (wcmatch *lyr "*0004*") (setq *col (vl-string-subst "14" *id *col)))
        (if (wcmatch *lyr "*0005*") (setq *col (vl-string-subst "18" *id *col)))
        (if (wcmatch *lyr "*0006*") (setq *col (vl-string-subst "24" *id *col)))
        (if (wcmatch *lyr "*0007*") (setq *col (vl-string-subst "04" *id *col)))
        (if (wcmatch *lyr "*0008*") (setq *col (vl-string-subst "08" *id *col)))
        (if (wcmatch *lyr "*0009*") (setq *col (vl-string-subst "12" *id *col)))
        (if (wcmatch *lyr "*0010*") (setq *col (vl-string-subst "14" *id *col)))
      )
    )
    (if (= "PhaseColor" *cop) 
      (progn 
        (if (wcmatch *lyr "*-E") (setq *col (vl-string-subst "20" *id *col)))
        (if (wcmatch *lyr "*-D") (setq *col (vl-string-subst "02" *id *col)))
        (if (wcmatch *lyr "*-N") (setq *col (vl-string-subst "16" *id *col)))
      )
    )

    ;;  Always the same color:
    (if (wcmatch *lyr "?-Elev*") 
      (progn 
        (if (wcmatch *lyr "*Main*") (setq *col "042"))
        (if (wcmatch *lyr "*Sect*") (setq *col "223"))
        (if (wcmatch *lyr "*Otln*") (setq *col "004"))
        (if (wcmatch *lyr "*Blin*") (setq *col "005"))
        (if (wcmatch *lyr "*Jnt@*") (setq *col "184"))
        (if (wcmatch *lyr "*Opng*") (setq *col "121"))


        (if (wcmatch *lyr "*Bgrd*") 
          (progn 
            (if (wcmatch *lyr "*0001*") (setq *col "061"))
            (if (wcmatch *lyr "*0002*") (setq *col "101"))
            (if (wcmatch *lyr "*0003*") (setq *col "141"))
            (if (wcmatch *lyr "*0004*") (setq *col "181"))
            (if (wcmatch *lyr "*0005*") (setq *lyr "Delete"))
          )
        )
        (if (wcmatch *lyr "*Mcut*") 
          (cond 
            ((wcmatch *lyr "*0001*") (setq *col "020"))
            ((wcmatch *lyr "*0002*") (setq *col "060"))
            ((wcmatch *lyr "*0003*") (setq *col "100"))
            ((wcmatch *lyr "*0004*") (setq *col "140"))
            ((wcmatch *lyr "*0005*") (setq *col "180"))
            (T (setq *col "020"))
          )
        )
      )
    )
    (if (wcmatch *lyr "?-Eqpm*") (setq *col "001"))
    (if (wcmatch *lyr "*Plnt*") (setq *col "081"))
    (if (wcmatch *lyr "*Titl*") (setq *col "023"))
    (if (wcmatch *lyr "*Nplt*,*Rdme*") (setq *col "140"))
    (if (wcmatch *lyr "*Iden*") (setq *col (itoa (1+ (atoi *col)))))
    (if (wcmatch *lyr "*Tags*") (setq *col "182"))
    (if (wcmatch *lyr "*Note*,*Mark*") (setq *col "122"))
    (if (wcmatch *lyr "*Revc*,*Revs*") (setq *col "062"))
    (if (wcmatch *lyr "*Dims*,*Symb*,*Brng*,*Grid**") (setq *col "221"))
    (if (wcmatch *lyr "*Labl*") (setq *col "163"))
    (if (wcmatch *lyr "*Text*,*Data*") (setq *col "041"))
    (if (wcmatch *lyr "*Scrn*,*Grph*") (setq *col "008"))
    (if (wcmatch *lyr "*Exst*") (setq *col "009"))
    (if (wcmatch *lyr "*Redl*") 
      (setq *col       "255,0,0"
            *truecolor "Yes"
      )
    )






    ;;  Default value reset:
    (setq *lw  "0.18"
          *lt  "Continuous"
          *plt "_P"
    )
    (if (wcmatch *lyr "*Nplt*,*Rdme*") (setq *plt "_N"))


    ;; Default line weight attribution based on layer color:
    (cond 
      ((wcmatch *col "##0") (setq *lw "0.13"))
      ((wcmatch *col "##1") (setq *lw "0.18"))
      ((wcmatch *col "##2") (setq *lw "0.25"))
      ((wcmatch *col "##3") (setq *lw "0.35"))
      ((wcmatch *col "##4") (setq *lw "0.50"))
      ((wcmatch *col "##5") (setq *lw "0.70"))
      ((wcmatch *col "##6") (setq *lw "1.00"))
      ((wcmatch *col "##7") (setq *lw "1.40"))
      ((wcmatch *col "##8") (setq *lw "2.00"))
      ((wcmatch *col "##9") (setq *lw "0.13"))
      (T (setq *lw "0.18"))
    )
    (if (wcmatch *col "008,8,009,9,250,251,253,254,255") (setq *lw "0.13"))


    ;;  Default line type attribution based on layer name:
    (if (wcmatch *lyr "*Cntr*") (setq *lt "Center"))
    (if (wcmatch *lyr "*Cnt2*") (setq *lt "Center2"))
    (if (wcmatch *lyr "*Hdln*") (setq *lt "Hidden"))
    (if (wcmatch *lyr "*Hid2*") (setq *lt "Hidden2"))
    (if (wcmatch *lyr "*Phnt*") (setq *lt "Phantom"))
    (if (wcmatch *lyr "*Phn2*") (setq *lt "Phantom2"))
    (if (wcmatch *lyr "*Grid*") (setq *lt "Center2"))
    (if (wcmatch *lyr "*Labl*,*Tags*") (setq *lt "Phantom"))
    (if (wcmatch *lyr "?-Elev*") 
      (progn 
        (if (wcmatch *lyr "*Jnts*") (setq *lt "ACAD_ISO10W100"))
        (if (wcmatch *lyr "*Jntc*") (setq *lt "ACAD_ISO12W100"))
        (if (wcmatch *lyr "*Jnte*") (setq *lt "ACAD_ISO14W100"))
        (if (wcmatch *lyr "*Opng*") (setq *lt "Phantom2"))
        (if (wcmatch *lyr "*Crak*") (setq *lt "JIS_02_1.2"))
      )
    )



    (if (wcmatch *lyr "*Redl*") 
      (setq *col       "255,0,0"
            *truecolor "Yes"
      )
    )



    (if (= *lyr "Delete")
      (prompt (strcat "\n..." *lyr " - deleted from list"))
      (progn
        (setq *obj (tblsearch "LAYER" *lyr)
              *res (Local>>LayerPut *lys *lyr *col (= "Yes" *truecolor) *lw (Local>>Linetype *doc *lt *lin) (/= "_N" *plt) *dsc)
        )
        (cond
          ((vl-catch-all-error-p *res)
           (prompt (strcat "\n..." *lyr " - not made: " (vl-catch-all-error-message *res)))
          )
          (*obj (setq *upd (1+ *upd)) (prompt (strcat "\n..." *lyr " - updated")))
          (T (setq *new (1+ *new)) (prompt (strcat "\n..." *lyr " - created")))
        )
      )
    )
  )
  (vla-EndUndoMark *doc)
  (prompt (strcat "\n" (itoa *new) " layer(s) created, " (itoa *upd) " updated."))
  (setvar 'cmdecho *cme)
  (princ)
)

;; The first n items of a list (nil past its end).
(defun Local>>FirstN (n lst / res)
  (repeat n (setq res (cons (car lst) res) lst (cdr lst)))
  (vl-remove nil (reverse res))
)

;; The description of a major group in the AEC standard (Major.csv), else the group itself.
(defun Local>>MajorDesc (maj / row res)
  (foreach row (Local>>LM:readcsv (Dyl:UserFile (strcat *dyl:dylres "\\AEC\\Standard\\Major.csv")))
    (if (and (not res) (= (strcase maj) (strcase (vl-string-left-trim "\357\273\277" (car row)))) (nth 5 row) (/= "" (nth 5 row)))
      (setq res (nth 5 row))
    )
  )
  (cond (res) (maj))
)

;; The linetype to give a layer: lt, loaded from the .lin file of the drawing units when
;; the drawing does not have it yet, else Continuous.
(defun Local>>Linetype (doc lt lin)
  (cond
    ((tblsearch "LTYPE" lt) lt)
    ((and (not (vl-catch-all-error-p (vl-catch-all-apply 'vla-Load (list (vla-get-Linetypes doc) lt lin))))
          (tblsearch "LTYPE" lt))
     lt
    )
    (T "Continuous")
  )
)

;; Makes or updates the layer name with its properties, without making it current.
;; col is an ACI ("151") or, rgb true, "R,G,B"; lw is in millimetres ("0.18").
;; Returns the layer, or the error caught.
(defun Local>>LayerPut (lys name col rgb lw lt plt dsc / lay clr rgbl)
  (vl-catch-all-apply
    '(lambda ()
       (setq lay (if (tblsearch "LAYER" name) (vla-Item lys name) (vla-Add lys name)))
       (if rgb
         (progn
           (setq rgbl (read (strcat "(" (vl-string-translate "," " " col) ")"))
                 clr  (vla-get-TrueColor lay)
           )
           (vla-SetRGB clr (car rgbl) (cadr rgbl) (caddr rgbl))
           (vla-put-TrueColor lay clr)
         )
         (vla-put-Color lay (atoi col))
       )
       (vla-put-Lineweight lay (fix (+ 0.5 (* 100 (atof lw)))))
       (vla-put-Linetype lay lt)
       (vla-put-Plottable lay (if plt :vlax-true :vlax-false))
       (vla-put-Description lay dsc)
       lay
     )
  )
)
(defun Local>>getMatching (*pat *lol) 
  (setq *trd "No")
  (mapcar 
    (function 
      (lambda (x) 
        (mapcar 
          '(lambda (s) (if (wcmatch s *pat) (setq *trd "Yes")))
          x
        )
      )
    )
    *lol
  )
)


  ;; Read CSV  -  Lee Mac
  ;; Parses a CSV file into a matrix list of cell values.
  ;; csv - [str] filename of CSV file to read
(defun Local>>LM:readcsv (csv / des lst sep str) 
  (if (setq des (open csv "r")) 
    (progn 
      (while (setq str (read-line des)) 
        (if (not sep)
          (setq sep (cond ((vl-string-search ";" str) ";") ((vl-string-search "\t" str) "\t") (","))))
        (setq lst (cons (Local>>LM:csv->lst str sep 0) lst))
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
(defun Local>>LM:csv->lst (str sep pos / s) 
  (cond 
    ((not (setq pos (vl-string-search sep str pos)))
     (if (wcmatch str "\"*\"") 
       (list (Local>>LM:csv-replacequotes (substr str 2 (- (strlen str) 2))))
       (list str)
     )
    )
    ((or (wcmatch (setq s (substr str 1 pos)) "\"*[~\"]") 
         (and (wcmatch s "~*[~\"]*") (= 1 (logand 1 pos)))
     )
     (Local>>LM:csv->lst str sep (+ pos 2))
    )
    ((wcmatch s "\"*\"")
     (cons 
       (Local>>LM:csv-replacequotes (substr str 2 (- pos 2)))
       (Local>>LM:csv->lst (substr str (+ pos 2)) sep 0)
     )
    )
    ((cons s (Local>>LM:csv->lst (substr str (+ pos 2)) sep 0)))
  )
)

  ;; List to String  -  Lee Mac
  ;; Concatenates each string in a supplied list, separated by a given delimiter
  ;; lst - [lst] List of strings to concatenate
  ;; del - [str] Delimiter string to separate each item
(defun Local>>LM:lst->str (lst del) 
  (if (cdr lst) 
    (strcat (car lst) del (Local>>LM:lst->str (cdr lst) del))
    (car lst)
  )
)


  ;; ACI -> RGB  -  Lee Mac
  ;; Args: c - [int] ACI (AutoCAD Colour Index) Colour (1<=c<=255)
(defun Local>>LM:ACI->RGB (c / o r) 
  (if (setq o (vla-getinterfaceobject (Local>>LM:acapp) (strcat "autocad.accmcolor." (substr (getvar 'acadver) 1 2)))) 
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

  ;; Application Object  -  Lee Mac
  ;; Returns the VLA Application Object
(defun Local>>LM:acapp nil 
  (eval (list 'defun 'Local>>LM:acapp 'nil (vlax-get-acad-object)))
  (Local>>LM:acapp)
)



;;  The layer sets are the child commands Pst-Make*Layers below, run by their
;;  aliases (LL-A-FLOOR...) or picked in the Dyl-LayerMake dialog.

;; Make Layers
;; Lists the layer sets with their aliases and creates the layers of the one picked.

(defun c:Dyl-LayerMake ()
  (Dyl:ChildPicker "Dyl-LayerMake.lsp" "Make Layers" "Double-click a layer set (or OK) to create its layers." '*lm:last*)
)

  ;#region layer list

;; Make Basic Drawing Layers
;; Creates the basic drawing layers from the Dynalisp CSV layer list.

(defun c:Pst-MakeBasicDrawingLayers () 
  (setq *typ "Csv"
        *dir nil
        *lst '("Dyl\\Drawing\\Basic.csv")
  )
  (Dyl-LayerMake *typ *dir *lst *cop)
)

;; Make Architectural Elevation Layers
;; Creates the architectural elevation, equipment and annotation layers from the CSV layer lists.

(defun c:Pst-MakeArchitecturalElevationLayers () 
  (setq *typ "Csv"
        *dir nil
        *lst '("Architecture\\A-Elevation.csv" "Architecture\\A-Anno.csv")
  )
  (Dyl-LayerMake *typ *dir *lst *cop)
)

;; Make Architectural Section Layers
;; Creates the architectural section, equipment and annotation layers from the CSV layer lists.

(defun c:Pst-MakeArchitecturalSectionLayers () 
  (setq *typ "Csv"
        *dir nil
        *lst '("Architecture\\A-Elevation.csv" "Architecture\\A-Anno.csv")
  )
  (Dyl-LayerMake *typ *dir *lst *cop)
)

;; Make Architectural Detail Layers
;; Creates the architectural detail, equipment and annotation layers from the CSV layer lists.

(defun c:Pst-MakeArchitecturalDetailLayers () 
  (setq *typ "Csv"
        *dir nil
        *lst '("Architecture\\A-Detail.csv" "Architecture\\A-Anno.csv")
  )
  (Dyl-LayerMake *typ *dir *lst *cop)
)

;; Make Architectural Floor Plan Layers
;; Creates the architectural floor plan, equipment and annotation layers from the CSV layer lists.

(defun c:Pst-MakeArchitecturalFloorPlanLayers () 
  (setq *typ "Csv"
        *dir nil
        *lst '("Dyl\\Model\\Floor.csv" "Architecture\\A-Anno.csv")
  )
  (Dyl-LayerMake *typ *dir *lst *cop)
)

;; Make Architectural Roof Plan Layers
;; Creates the architectural roof plan, equipment and annotation layers from the CSV layer lists.

(defun c:Pst-MakeArchitecturalRoofPlanLayers () 
  (setq *typ "Csv"
        *dir nil
        *lst '("Architecture\\A-Roof.csv" "Architecture\\A-Anno.csv")
  )
  (Dyl-LayerMake *typ *dir *lst *cop)
)

;; Make Architectural Ceiling Plan Layers
;; Creates the architectural ceiling plan, floor, equipment and annotation layers from the CSV layer lists.

(defun c:Pst-MakeArchitecturalCeilingPlanLayers () 
  (setq *typ "Csv"
        *dir nil
        *lst '("Architecture\\A-Ceiling.csv" "Architecture\\A-Anno.csv")
  )
  (Dyl-LayerMake *typ *dir *lst *cop)
)

;; Make Architectural Furniture Plan Layers
;; Creates the architectural furniture plan, floor and annotation layers from the CSV layer lists.

(defun c:Pst-MakeArchitecturalFurniturePlanLayers () 
  (setq *typ "Csv"
        *dir nil
        *lst '("Dyl\\Model\\Furniture.csv" "Dyl\\Model\\Floor.csv" "Architecture\\A-Anno.csv")
  )
  (Dyl-LayerMake *typ *dir *lst *cop)
)

;; Make NCS Level 1 Layers
;; Creates the NCS level 1 layers of every discipline from the CSV layer lists.

(defun c:Pst-MakeNCSLevel1Layers () 
  (setq *typ "Csv"
        *dir nil
        *lst '("NCSv5\\1\\Architectural.csv" "NCSv5\\1\\Civil.csv" "NCSv5\\1\\Interior.csv" "NCSv5\\1\\Landscape.csv" "NCSv5\\1\\Structural.csv" "NCSv5\\1\\Plumbing.csv" "NCSv5\\1\\Electrical.csv" "NCSv5\\1\\Mechanical.csv")
  )
  (Dyl-LayerMake *typ *dir *lst *cop)
)

;; Make NCS Level 2 Layers
;; Creates the NCS level 2 layers of every discipline from the CSV layer lists.

(defun c:Pst-MakeNCSLevel2Layers () 
  (setq *typ "Csv"
        *dir nil
        *lst '("NCSv5\\2\\Architectural.csv" "NCSv5\\2\\Civil.csv" "NCSv5\\2\\Interior.csv" "NCSv5\\2\\Landscape.csv" "NCSv5\\2\\Structural.csv" "NCSv5\\2\\Plumbing.csv" "NCSv5\\2\\Electrical.csv" "NCSv5\\2\\Mechanical.csv")
  )
  (Dyl-LayerMake *typ *dir *lst *cop)
)

;; Make NCS Level 3 Layers
;; Creates the NCS level 3 layers of every discipline from the CSV layer lists.

(defun c:Pst-MakeNCSLevel3Layers () 
  (setq *typ "Csv"
        *dir nil
        *lst '("NCSv5\\3\\Architectural.csv" "NCSv5\\3\\Civil.csv" "NCSv5\\2\\Interior.csv" "NCSv5\\3\\Landscape.csv" "NCSv5\\3\\Structural.csv" "NCSv5\\2\\Plumbing.csv" "NCSv5\\3\\Electrical.csv" "NCSv5\\3\\Mechanical.csv")
  )
  (Dyl-LayerMake *typ *dir *lst *cop)
)
  ;#endregion