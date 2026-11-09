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

(Defun Dyl-LayMake (*typ *dir *lst *cop) 
  ;; *typ = "Csv" for layer list or "Lyr" for single layer
  ;; *dir = directory subfolder name from:

  ;; Error handling function:
  (defun *error* (*erm) 
    (if *cme (setvar 'cmdecho *cme))
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
        *lyr  nil
        *dsc  nil
  )


  ;; Get CSV data:
  (if (= *typ "Lyr") (setq *lyl *lst))
  (if (= *typ "Csv") 
    (foreach *fle *lst 
      (setq *data (append *data (cdr (Local>>LM:readcsv (Dyl:UserFile (strcat *dyl:layerlist "\\" *dir "\\" *fle))))))
    )
  )


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
      (cond 
        ((= *sel "N") (setq *nbr "0001"))
        ((= *sel "S1") (setq *nbr "0001"))
        ((= *sel "S2") (setq *nbr "0002"))
        ((= *sel "S3") (setq *nbr "0003"))
        ((= *sel "S4") (setq *nbr "0004"))
        ((= *sel "S5") (setq *nbr "0005"))
        ((= *sel "S6") (setq *nbr "0006"))
        ((= *sel "S7") (setq *nbr "0007"))
        ((= *sel "S8") (setq *nbr "0008"))
        ((= *sel "S9") (setq *nbr "0009"))
        (T (setq *nbr "----"))
      )
    )
  )


  ;; Check data for variable designatior layers (double question mark in data) and ask user for the desired stack:
  (if (wcmatch *data "*$$*") 
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
      (cond 
        ((= *sel "G") (setq *ddr "G"))
        ((= *sel "A") (setq *ddr "A"))
        ((= *sel "I") (setq *ddr "I"))
        ((= *sel "S") (setq *ddr "S"))
        ((= *sel "L") (setq *ddr "L"))
        (T (setq *ddr "G"))
      )
    )
  )


  ;; Build data into a list of list made of a usable layer name and description:
  (foreach *row *data 
    (setq *dsc (nth 5 *row)
          *str (Local>>LM:lst->str 
                 (list (nth 0 *row) 
                       (nth 1 *row)
                       (nth 2 *row)
                       (nth 3 *row)
                       (nth 4 *row)
                 )
                 "-"
               )
          *lyr (vl-string-right-trim "-" 
                                     (if (wcmatch *str "*0000*") 
                                       (setq *str (vl-string-subst *ddr "$$" (vl-string-subst *nbr "0000" *str)))
                                     )
               )
          *lyl (cons (cons *lyr *dsc) *lyl)
    )
  )

  ;; Build a new list of list with phased layer name:
  (foreach x *lyl 
    (foreach z *pha 
      (setq *lyr (car x))
      (setq *lyr (strcat *lyr z))
      (setq *nwl (cons (cons *lyr (cdr x)) *nwl))
    )
  )



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
          *plt "P"
    )
    (if (wcmatch *lyr "*Nplt*,*Rdme*") (setq *plt "N"))


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
      (if (not (tblsearch "LAYER" *lyr)) 
        (progn 
          (if (= "Yes" *truecolor) 
            (command "-layer" "m" *lyr "lw" *lw "" "l" *lt "" "c" "t" *col "" "p" *plt "" "d" *dsc *lyr "")
            (command "-layer" "m" *lyr "lw" *lw "" "l" *lt "" "c" *col "" "p" *plt "" "d" *dsc *lyr "")
          )
          (prompt (strcat "\n..." *lyr " - created"))
        )
        (progn 
          (if (= "Yes" *truecolor) 
            (command "-layer" "m" *lyr "lw" *lw "" "l" *lt "" "c" "t" *col "" "p" *plt "" "d" *dsc *lyr "y" "")
            (command "-layer" "m" *lyr "lw" *lw "" "l" *lt "" "c" *col "" "p" *plt "" "d" *dsc *lyr "y" "")
          )
          (prompt (strcat "\n..." *lyr " - updated"))
        )
      )
    )
  )
  (princ)


  (setvar 'cmdecho *cme)
  (princ)
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
      (setq sep (cond ((vl-registry-read "HKEY_CURRENT_USER\\Control Panel\\International" "sList")) (",")))
      (while (setq str (read-line des)) 
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
;;  aliases (LL-A-FLOOR...) or picked in the Dyl-LayMake dialog.

;; Make Layers
;; Lists the layer sets with their aliases and creates the layers of the one picked.

(defun c:Dyl-LayMake ()
  (Dyl:ChildPicker "Dyl-LayerMake.lsp" "Make Layers" "Double-click a layer set (or OK) to create its layers." '*lm:last*)
)

  ;#region layer list

;; Make Basic Drawing Layers
;; Creates the basic drawing layers from the Dynalisp CSV layer list.

(defun c:Pst-MakeBasicDrawingLayers () 
  (setq *typ "Csv"
        *dir "Dyl//Drawing"
        *lst '("Basic.csv")
  )
  (Dyl-LayMake *typ *dir *lst *cop)
)

;; Make Architectural Elevation Layers
;; Creates the architectural elevation, equipment and annotation layers from the CSV layer lists.

(defun c:Pst-MakeArchitecturalElevationLayers () 
  (setq *typ "Csv"
        *dir "Architecture"
        *lst '("A-Elev.csv" "A-Eqpm.csv" "A-Anno.csv")
  )
  (Dyl-LayMake *typ *dir *lst *cop)
)

;; Make Architectural Section Layers
;; Creates the architectural section, equipment and annotation layers from the CSV layer lists.

(defun c:Pst-MakeArchitecturalSectionLayers () 
  (setq *typ "Csv"
        *dir "Architecture"
        *lst '("A-Elev.csv" "A-Eqpm.csv" "A-Anno.csv")
  )
  (Dyl-LayMake *typ *dir *lst *cop)
)

;; Make Architectural Detail Layers
;; Creates the architectural detail, equipment and annotation layers from the CSV layer lists.

(defun c:Pst-MakeArchitecturalDetailLayers () 
  (setq *typ "Csv"
        *dir "Architecture"
        *lst '("A-Drawing.csv" "A-Eqpm.csv" "A-Anno.csv")
  )
  (Dyl-LayMake *typ *dir *lst *cop)
)

;; Make Architectural Floor Plan Layers
;; Creates the architectural floor plan, equipment and annotation layers from the CSV layer lists.

(defun c:Pst-MakeArchitecturalFloorPlanLayers () 
  (setq *typ "Csv"
        *dir "Architecture"
        *lst '("A-Flor.csv" "A-Eqpm.csv" "A-Anno.csv")
  )
  (Dyl-LayMake *typ *dir *lst *cop)
)

;; Make Architectural Roof Plan Layers
;; Creates the architectural roof plan, equipment and annotation layers from the CSV layer lists.

(defun c:Pst-MakeArchitecturalRoofPlanLayers () 
  (setq *typ "Csv"
        *dir "Architecture"
        *lst '("A-Roof.csv" "A-Eqpm.csv" "A-Anno.csv")
  )
  (Dyl-LayMake *typ *dir *lst *cop)
)

;; Make Architectural Ceiling Plan Layers
;; Creates the architectural ceiling plan, floor, equipment and annotation layers from the CSV layer lists.

(defun c:Pst-MakeArchitecturalCeilingPlanLayers () 
  (setq *typ "Csv"
        *dir "Architecture"
        *lst '("A-Ceil.csv" "A-Flor.csv" "A-Eqpm.csv" "A-Anno.csv")
  )
  (Dyl-LayMake *typ *dir *lst *cop)
)

;; Make Architectural Furniture Plan Layers
;; Creates the architectural furniture plan, floor and annotation layers from the CSV layer lists.

(defun c:Pst-MakeArchitecturalFurniturePlanLayers () 
  (setq *typ "Csv"
        *dir "Architecture"
        *lst '("A-Furn.csv" "A-Flor.csv" "A-Anno.csv")
  )
  (Dyl-LayMake *typ *dir *lst *cop)
)

;; Make NCS Level 1 Layers
;; Creates the NCS level 1 layers of every discipline from the CSV layer lists.

(defun c:Pst-MakeNCSLevel1Layers () 
  (setq *typ "Csv"
        *dir "NCS"
        *lst '("1-Architectural.csv" "1-Civil.csv" "1-Interior.csv" "1-Landscape.csv" "1-Structural.csv" "1-Civil.csv" 
               "1-Plumbing.csv" "1-Electrical.csv" "1-Mechanical.csv"
              )
  )
  (Dyl-LayMake *typ *dir *lst *cop)
)

;; Make NCS Level 2 Layers
;; Creates the NCS level 2 layers of every discipline from the CSV layer lists.

(defun c:Pst-MakeNCSLevel2Layers () 
  (setq *typ "Csv"
        *dir "NCS"
        *lst '("2-Architectural.csv" "2-Interior.csv" "2-Landscape.csv" "2-Structural.csv" "2-Civil.csv" 
               "2-Plumbing.csv" "2-Electrical.csv" "2-Mechanical.csv"
              )
  )
  (Dyl-LayMake *typ *dir *lst *cop)
)

;; Make NCS Level 3 Layers
;; Creates the NCS level 3 layers of every discipline from the CSV layer lists.

(defun c:Pst-MakeNCSLevel3Layers () 
  (setq *typ "Csv"
        *dir "NCS"
        *lst '("3-Architectural.csv" "2-Interior.csv" "3-Landscape.csv" "3-Structural.csv" "3-Civil.csv" 
               "2-Plumbing.csv" "3-Electrical.csv" "3-Mechanical.csv"
              )
  )
  (Dyl-LayMake *typ *dir *lst *cop)
)
  ;#endregion