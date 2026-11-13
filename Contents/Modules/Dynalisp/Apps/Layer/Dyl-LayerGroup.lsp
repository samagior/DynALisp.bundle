;; LayerGroup - Change selected object(s) from a selected layer group to a new one (layer must already be in file)
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

(defun Dyl:LayGroup (/ *lcl *obj *lyr *nme *ent *len *tst *ctr *lst) 

  ;;  *lcl : Layers collection
  ;;  *lyr : Layer entity
  ;;  *nme : Layer name
  ;;  *ent : Dictionary entity
  ;;  *len : Lenght
  ;;  *tst : Test
  ;;  *ctr : Counter
  ;;  *lst : List
  ;;  *grp : Group

  (vl-load-com) ;; load ActiveX support

  (setvar "cmdecho" 0)

  (setq *lcl (vla-get-layers (vla-get-ActiveDocument (vlax-get-acad-object)))
        *obj (vla-addobject (vla-GetExtensionDictionary *lcl) "ACLYDICTIONARY" "AcDbDictionary")
        *ent (vlax-vla-object->ename *obj)
  )
  ;#region dict

  ;#region Architectural
  (setq *len (vlax-get-property *obj 'Count))
  (setq *tst (cdr (car (dictnext *ent T))))
  (setq *ctr 0)
  (while (< *ctr *len) 
    (if (= (cdr (assoc 300 (entget *tst))) "Architectural") 
      (progn 
        (setq *tst:nme (vlax-get-property (vlax-ename->vla-object *tst) 'Name))
        (vlax-put-property (vlax-ename->vla-object *tst) 'Name "Dyl-A")
        (setq *len *ctr)
      )
      (progn 
        (setq *tst (cdr (car (dictnext *ent))))
        (setq *ctr (1+ *ctr))
      )
    )
  )

  (dictremove *ent "Dyl-A")

  (setq _root (list '(0 . "DICTIONARY") '(100 . "AcDbDictionary") '(280 . 1) '(281 . 1)))
  (setq _root (entmakex _root))

  (setq _dict (list '(0 . "DICTIONARY") '(100 . "AcDbDictionary") '(280 . 1) '(281 . 1)))
  (setq _dict (entmakex _dict))

  (setq *dscp nil
        *grp1 nil
        *grp2 nil
        *grp3 nil
        *grp4 nil
  )

  ;#region Main
  (vlax-for *lyr *lcl 
    (setq *nme (vlax-get-property *lyr 'name))
    (if (or (= *nme "0") (= (strcase *nme) "DEFPOINTS") (wcmatch *nme "A-*")) 
      (progn 
        (setq *lst (cons 
                     '330
                     (cdr 
                       (assoc 
                         -1
                         (entget 
                           (handent (vlax-get-property *lyr 'handle))
                         )
                       )
                     )
                   )
        )
        (setq *dscp (cons *lst *dscp))
      )
    )
  )
  (setq _datalist (append 
                    (list '(0 . "XRECORD") 
                          '(102 . "{ACAD_XDICTIONARY")
                          (cons 360 _root)
                          '(102 . "}")
                          '(100 . "AcDbXrecord")
                          '(280 . 1)
                    )
                    '((1 . "AcLyLayerGroup")
                      (90 . 1)
                      (300 . "Architectural")
                     )
                    *dscp
                  )
  )
  (setq _xname (entmakex _datalist))
  (dictadd *ent "Dyl-A" _xname)
  ;#endregion


  ;#region Detail
  (vlax-for *lyr *lcl 
    (setq *nme (vlax-get-property *lyr 'name))
    (if 
      (and (or (= *nme "0") (= (strcase *nme) "DEFPOINTS") (wcmatch *nme "A-Detl*,A-Anno*")) 
           (not (wcmatch *nme "*|*"))
      )
      (progn 
        (setq *lst (cons 
                     '330
                     (cdr 
                       (assoc 
                         -1
                         (entget 
                           (handent (vlax-get-property *lyr 'handle))
                         )
                       )
                     )
                   )
        )
        (setq *grp1 (cons *lst *grp1))
      )
    )
  )
  (setq _datalist (append 
                    (list '(0 . "XRECORD") 
                          '(100 . "AcDbXrecord")
                          '(280 . 1)
                    )
                    '((1 . "AcLyLayerGroup")
                      (90 . 1)
                      (300 . "Detail")
                     )
                    *grp1
                  )
  )
  (setq _xname (entmakex _datalist))
  (dictadd _dict "Dyl-A-Detail" _xname)
  ;#endregion


  ;#region Elevation
  (vlax-for *lyr *lcl 
    (setq *nme (vlax-get-property *lyr 'name))
    (if 
      (and 
        (or (= *nme "0") (= (strcase *nme) "DEFPOINTS") (wcmatch *nme "A-Elev*,A-Anno*"))
        (not (wcmatch *nme "*|*"))
      )
      (progn 
        (setq *lst (cons 
                     '330
                     (cdr 
                       (assoc 
                         -1
                         (entget 
                           (handent (vlax-get-property *lyr 'handle))
                         )
                       )
                     )
                   )
        )
        (setq *grp2 (cons *lst *grp2))
      )
    )
  )
  (setq _datalist (append 
                    (list '(0 . "XRECORD") 
                          '(100 . "AcDbXrecord")
                          '(280 . 1)
                    )
                    '((1 . "AcLyLayerGroup")
                      (90 . 1)
                      (300 . "Elevation")
                     )
                    *grp2
                  )
  )
  (setq _xname (entmakex _datalist))
  (dictadd _dict "Dyl-A-Elev" _xname)
  ;#endregion


  ;#region Plan
  (vlax-for *lyr *lcl 
    (setq *nme (vlax-get-property *lyr 'name))
    (if 
      (and 
        (or (= *nme "0") (= (strcase *nme) "DEFPOINTS") (wcmatch *nme "A-????*"))
        (not (wcmatch *nme "*|*,?-Elev*,?-Detl*,?-Sect*"))
      )
      (progn 
        (setq *lst (cons 
                     '330
                     (cdr 
                       (assoc 
                         -1
                         (entget 
                           (handent (vlax-get-property *lyr 'handle))
                         )
                       )
                     )
                   )
        )
        (setq *grp3 (cons *lst *grp3))
      )
    )
  )
  (setq _datalist (append 
                    (list '(0 . "XRECORD") 
                          '(100 . "AcDbXrecord")
                          '(280 . 1)
                    )
                    '((1 . "AcLyLayerGroup")
                      (90 . 1)
                      (300 . "Plan")
                     )
                    *grp3
                  )
  )
  (setq _xname (entmakex _datalist))
  (dictadd _dict "Dyl-A-Plan" _xname)
  ;#endregion


  ;#region Section
  (vlax-for *lyr *lcl 
    (setq *nme (vlax-get-property *lyr 'name))
    (if 
      (and 
        (or (= *nme "0") (= (strcase *nme) "DEFPOINTS") (wcmatch *nme "A-Sect*,A-Anno*"))
        (not (wcmatch *nme "*|*"))
      )
      (progn 
        (setq *lst (cons 
                     '330
                     (cdr 
                       (assoc 
                         -1
                         (entget 
                           (handent (vlax-get-property *lyr 'handle))
                         )
                       )
                     )
                   )
        )
        (setq *grp4 (cons *lst *grp4))
      )
    )
  )
  (setq _datalist (append 
                    (list 
                      '(0 . "XRECORD")
                      '(100 . "AcDbXrecord")
                      '(280 . 1)
                    )
                    '((1 . "AcLyLayerGroup")
                      (90 . 1)
                      (300 . "Section")
                     )
                    *grp4
                  )
  )
  (setq _xname (entmakex _datalist))
  (dictadd _dict "Dyl-A-Sect" _xname)
  ;#endregion


  (setq _dict (entget _dict))
  (setq _dict (vl-remove (car _dict) _dict))
  (setq _dict (entmakex _dict))
  (dictadd _root "ACLYDICTIONARY" _dict)
  ;#endregion

  ;#region Civil
  (setq *len (vlax-get-property *obj 'Count))
  (setq *tst (cdr (car (dictnext *ent T))))
  (setq *ctr 0)
  (while (< *ctr *len) 
    (if (= (cdr (assoc 300 (entget *tst))) "Civil") 
      (progn 
        (setq *tst:nme (vlax-get-property (vlax-ename->vla-object *tst) 'Name))
        (vlax-put-property (vlax-ename->vla-object *tst) 'Name "Dyl-C")
        (setq *len *ctr)
      )
      (progn 
        (setq *tst (cdr (car (dictnext *ent))))
        (setq *ctr (1+ *ctr))
      )
    )
  )

  (dictremove *ent "Dyl-C")

  (setq _root (list '(0 . "DICTIONARY") '(100 . "AcDbDictionary") '(280 . 1) '(281 . 1)))
  (setq _root (entmakex _root))

  (setq _dict (list '(0 . "DICTIONARY") '(100 . "AcDbDictionary") '(280 . 1) '(281 . 1)))
  (setq _dict (entmakex _dict))

  (setq *dscp nil)

  (vlax-for *lyr *lcl 
    (setq *nme (vlax-get-property *lyr 'name))
    (if (or (= *nme "0") (= (strcase *nme) "DEFPOINTS") (wcmatch *nme "C-*")) 
      (progn 
        (setq *lst (cons 
                     '330
                     (cdr 
                       (assoc 
                         -1
                         (entget 
                           (handent (vlax-get-property *lyr 'handle))
                         )
                       )
                     )
                   )
        )
        (setq *dscp (cons *lst *dscp))
      )
    )
  )
  (setq _datalist (append 
                    (list '(0 . "XRECORD") 
                          '(102 . "{ACAD_XDICTIONARY")
                          (cons 360 _root)
                          '(102 . "}")
                          '(100 . "AcDbXrecord")
                          '(280 . 1)
                    )
                    '((1 . "AcLyLayerGroup")
                      (90 . 1)
                      (300 . "Civil")
                     )
                    *dscp
                  )
  )
  (setq _xname (entmakex _datalist))
  (dictadd *ent "Dyl-C" _xname)


  (setq _dict (entget _dict))
  (setq _dict (vl-remove (car _dict) _dict))
  (setq _dict (entmakex _dict))
  (dictadd _root "ACLYDICTIONARY" _dict)
  ;#endregion

  ;#region Electrical
  (setq *len (vlax-get-property *obj 'Count))
  (setq *tst (cdr (car (dictnext *ent T))))
  (setq *ctr 0)
  (while (< *ctr *len) 
    (if (= (cdr (assoc 300 (entget *tst))) "Electrical") 
      (progn 
        (setq *tst:nme (vlax-get-property (vlax-ename->vla-object *tst) 'Name))
        (vlax-put-property (vlax-ename->vla-object *tst) 'Name "Dyl-E")
        (setq *len *ctr)
      )
      (progn 
        (setq *tst (cdr (car (dictnext *ent))))
        (setq *ctr (1+ *ctr))
      )
    )
  )

  (dictremove *ent "Dyl-E")

  (setq _root (list '(0 . "DICTIONARY") '(100 . "AcDbDictionary") '(280 . 1) '(281 . 1)))
  (setq _root (entmakex _root))

  (setq _dict (list '(0 . "DICTIONARY") '(100 . "AcDbDictionary") '(280 . 1) '(281 . 1)))
  (setq _dict (entmakex _dict))

  (setq *dscp nil)

  (vlax-for *lyr *lcl 
    (setq *nme (vlax-get-property *lyr 'name))
    (if (or (= *nme "0") (= (strcase *nme) "DEFPOINTS") (wcmatch *nme "E-*")) 
      (progn 
        (setq *lst (cons 
                     '330
                     (cdr 
                       (assoc 
                         -1
                         (entget 
                           (handent (vlax-get-property *lyr 'handle))
                         )
                       )
                     )
                   )
        )
        (setq *dscp (cons *lst *dscp))
      )
    )
  )
  (setq _datalist (append 
                    (list '(0 . "XRECORD") 
                          '(102 . "{ACAD_XDICTIONARY")
                          (cons 360 _root)
                          '(102 . "}")
                          '(100 . "AcDbXrecord")
                          '(280 . 1)
                    )
                    '((1 . "AcLyLayerGroup")
                      (90 . 1)
                      (300 . "Electrical")
                     )
                    *dscp
                  )
  )
  (setq _xname (entmakex _datalist))
  (dictadd *ent "Dyl-E" _xname)


  (setq _dict (entget _dict))
  (setq _dict (vl-remove (car _dict) _dict))
  (setq _dict (entmakex _dict))
  (dictadd _root "ACLYDICTIONARY" _dict)
  ;#endregion

  ;#region General
  (setq *len (vlax-get-property *obj 'Count))
  (setq *tst (cdr (car (dictnext *ent T))))
  (setq *ctr 0)
  (while (< *ctr *len) 
    (if (= (cdr (assoc 300 (entget *tst))) "General") 
      (progn 
        (setq *tst:nme (vlax-get-property (vlax-ename->vla-object *tst) 'Name))
        (vlax-put-property (vlax-ename->vla-object *tst) 'Name "Dyl-G")
        (setq *len *ctr)
      )
      (progn 
        (setq *tst (cdr (car (dictnext *ent))))
        (setq *ctr (1+ *ctr))
      )
    )
  )

  (dictremove *ent "Dyl-G")

  (setq _root (list '(0 . "DICTIONARY") '(100 . "AcDbDictionary") '(280 . 1) '(281 . 1)))
  (setq _root (entmakex _root))

  (setq _dict (list '(0 . "DICTIONARY") '(100 . "AcDbDictionary") '(280 . 1) '(281 . 1)))
  (setq _dict (entmakex _dict))

  (setq *dscp nil)

  (vlax-for *lyr *lcl 
    (setq *nme (vlax-get-property *lyr 'name))
    (if (or (= *nme "0") (= (strcase *nme) "DEFPOINTS") (wcmatch *nme "G-*")) 
      (progn 
        (setq *lst (cons 
                     '330
                     (cdr 
                       (assoc 
                         -1
                         (entget 
                           (handent (vlax-get-property *lyr 'handle))
                         )
                       )
                     )
                   )
        )
        (setq *dscp (cons *lst *dscp))
      )
    )
  )
  (setq _datalist (append 
                    (list '(0 . "XRECORD") 
                          '(102 . "{ACAD_XDICTIONARY")
                          (cons 360 _root)
                          '(102 . "}")
                          '(100 . "AcDbXrecord")
                          '(280 . 1)
                    )
                    '((1 . "AcLyLayerGroup")
                      (90 . 1)
                      (300 . "General")
                     )
                    *dscp
                  )
  )
  (setq _xname (entmakex _datalist))
  (dictadd *ent "Dyl-G" _xname)


  (setq _dict (entget _dict))
  (setq _dict (vl-remove (car _dict) _dict))
  (setq _dict (entmakex _dict))
  (dictadd _root "ACLYDICTIONARY" _dict)
  ;#endregion

  ;#region Interior
  (setq *len (vlax-get-property *obj 'Count))
  (setq *tst (cdr (car (dictnext *ent T))))
  (setq *ctr 0)
  (while (< *ctr *len) 
    (if (= (cdr (assoc 300 (entget *tst))) "Interior") 
      (progn 
        (setq *tst:nme (vlax-get-property (vlax-ename->vla-object *tst) 'Name))
        (vlax-put-property (vlax-ename->vla-object *tst) 'Name "Dyl-I")
        (setq *len *ctr)
      )
      (progn 
        (setq *tst (cdr (car (dictnext *ent))))
        (setq *ctr (1+ *ctr))
      )
    )
  )

  (dictremove *ent "Dyl-I")

  (setq _root (list '(0 . "DICTIONARY") '(100 . "AcDbDictionary") '(280 . 1) '(281 . 1)))
  (setq _root (entmakex _root))

  (setq _dict (list '(0 . "DICTIONARY") '(100 . "AcDbDictionary") '(280 . 1) '(281 . 1)))
  (setq _dict (entmakex _dict))

  (setq *dscp nil)

  (vlax-for *lyr *lcl 
    (setq *nme (vlax-get-property *lyr 'name))
    (if (or (= *nme "0") (= (strcase *nme) "DEFPOINTS") (wcmatch *nme "I-*")) 
      (progn 
        (setq *lst (cons 
                     '330
                     (cdr 
                       (assoc 
                         -1
                         (entget 
                           (handent (vlax-get-property *lyr 'handle))
                         )
                       )
                     )
                   )
        )
        (setq *dscp (cons *lst *dscp))
      )
    )
  )
  (setq _datalist (append 
                    (list '(0 . "XRECORD") 
                          '(102 . "{ACAD_XDICTIONARY")
                          (cons 360 _root)
                          '(102 . "}")
                          '(100 . "AcDbXrecord")
                          '(280 . 1)
                    )
                    '((1 . "AcLyLayerGroup")
                      (90 . 1)
                      (300 . "Interior")
                     )
                    *dscp
                  )
  )
  (setq _xname (entmakex _datalist))
  (dictadd *ent "Dyl-I" _xname)


  (setq _dict (entget _dict))
  (setq _dict (vl-remove (car _dict) _dict))
  (setq _dict (entmakex _dict))
  (dictadd _root "ACLYDICTIONARY" _dict)
  ;#endregion

  ;#region Landscape
  (setq *len (vlax-get-property *obj 'Count))
  (setq *tst (cdr (car (dictnext *ent T))))
  (setq *ctr 0)
  (while (< *ctr *len) 
    (if (= (cdr (assoc 300 (entget *tst))) "Landscape") 
      (progn 
        (setq *tst:nme (vlax-get-property (vlax-ename->vla-object *tst) 'Name))
        (vlax-put-property (vlax-ename->vla-object *tst) 'Name "Dyl-L")
        (setq *len *ctr)
      )
      (progn 
        (setq *tst (cdr (car (dictnext *ent))))
        (setq *ctr (1+ *ctr))
      )
    )
  )

  (dictremove *ent "Dyl-L")

  (setq _root (list '(0 . "DICTIONARY") '(100 . "AcDbDictionary") '(280 . 1) '(281 . 1)))
  (setq _root (entmakex _root))

  (setq _dict (list '(0 . "DICTIONARY") '(100 . "AcDbDictionary") '(280 . 1) '(281 . 1)))
  (setq _dict (entmakex _dict))

  (setq *dscp nil)

  (vlax-for *lyr *lcl 
    (setq *nme (vlax-get-property *lyr 'name))
    (if (or (= *nme "0") (= (strcase *nme) "DEFPOINTS") (wcmatch *nme "L-*")) 
      (progn 
        (setq *lst (cons 
                     '330
                     (cdr 
                       (assoc 
                         -1
                         (entget 
                           (handent (vlax-get-property *lyr 'handle))
                         )
                       )
                     )
                   )
        )
        (setq *dscp (cons *lst *dscp))
      )
    )
  )
  (setq _datalist (append 
                    (list '(0 . "XRECORD") 
                          '(102 . "{ACAD_XDICTIONARY")
                          (cons 360 _root)
                          '(102 . "}")
                          '(100 . "AcDbXrecord")
                          '(280 . 1)
                    )
                    '((1 . "AcLyLayerGroup")
                      (90 . 1)
                      (300 . "Landscape")
                     )
                    *dscp
                  )
  )
  (setq _xname (entmakex _datalist))
  (dictadd *ent "Dyl-L" _xname)


  (setq _dict (entget _dict))
  (setq _dict (vl-remove (car _dict) _dict))
  (setq _dict (entmakex _dict))
  (dictadd _root "ACLYDICTIONARY" _dict)
  ;#endregion

  ;#region Mechanical
  (setq *len (vlax-get-property *obj 'Count))
  (setq *tst (cdr (car (dictnext *ent T))))
  (setq *ctr 0)
  (while (< *ctr *len) 
    (if (= (cdr (assoc 300 (entget *tst))) "Mechanical") 
      (progn 
        (setq *tst:nme (vlax-get-property (vlax-ename->vla-object *tst) 'Name))
        (vlax-put-property (vlax-ename->vla-object *tst) 'Name "Dyl-M")
        (setq *len *ctr)
      )
      (progn 
        (setq *tst (cdr (car (dictnext *ent))))
        (setq *ctr (1+ *ctr))
      )
    )
  )

  (dictremove *ent "Dyl-M")

  (setq _root (list '(0 . "DICTIONARY") '(100 . "AcDbDictionary") '(280 . 1) '(281 . 1)))
  (setq _root (entmakex _root))

  (setq _dict (list '(0 . "DICTIONARY") '(100 . "AcDbDictionary") '(280 . 1) '(281 . 1)))
  (setq _dict (entmakex _dict))

  (setq *dscp nil)

  (vlax-for *lyr *lcl 
    (setq *nme (vlax-get-property *lyr 'name))
    (if (or (= *nme "0") (= (strcase *nme) "DEFPOINTS") (wcmatch *nme "L-*")) 
      (progn 
        (setq *lst (cons 
                     '330
                     (cdr 
                       (assoc 
                         -1
                         (entget 
                           (handent (vlax-get-property *lyr 'handle))
                         )
                       )
                     )
                   )
        )
        (setq *dscp (cons *lst *dscp))
      )
    )
  )
  (setq _datalist (append 
                    (list '(0 . "XRECORD") 
                          '(102 . "{ACAD_XDICTIONARY")
                          (cons 360 _root)
                          '(102 . "}")
                          '(100 . "AcDbXrecord")
                          '(280 . 1)
                    )
                    '((1 . "AcLyLayerGroup")
                      (90 . 1)
                      (300 . "Mechanical")
                     )
                    *dscp
                  )
  )
  (setq _xname (entmakex _datalist))
  (dictadd *ent "Dyl-M" _xname)


  (setq _dict (entget _dict))
  (setq _dict (vl-remove (car _dict) _dict))
  (setq _dict (entmakex _dict))
  (dictadd _root "ACLYDICTIONARY" _dict)
  ;#endregion

  ;#region Plumbing
  (setq *len (vlax-get-property *obj 'Count))
  (setq *tst (cdr (car (dictnext *ent T))))
  (setq *ctr 0)
  (while (< *ctr *len) 
    (if (= (cdr (assoc 300 (entget *tst))) "Plumbing") 
      (progn 
        (setq *tst:nme (vlax-get-property (vlax-ename->vla-object *tst) 'Name))
        (vlax-put-property (vlax-ename->vla-object *tst) 'Name "Dyl-P")
        (setq *len *ctr)
      )
      (progn 
        (setq *tst (cdr (car (dictnext *ent))))
        (setq *ctr (1+ *ctr))
      )
    )
  )

  (dictremove *ent "Dyl-P")

  (setq _root (list '(0 . "DICTIONARY") '(100 . "AcDbDictionary") '(280 . 1) '(281 . 1)))
  (setq _root (entmakex _root))

  (setq _dict (list '(0 . "DICTIONARY") '(100 . "AcDbDictionary") '(280 . 1) '(281 . 1)))
  (setq _dict (entmakex _dict))

  (setq *dscp nil)

  (vlax-for *lyr *lcl 
    (setq *nme (vlax-get-property *lyr 'name))
    (if (or (= *nme "0") (= (strcase *nme) "DEFPOINTS") (wcmatch *nme "P-*")) 
      (progn 
        (setq *lst (cons 
                     '330
                     (cdr 
                       (assoc 
                         -1
                         (entget 
                           (handent (vlax-get-property *lyr 'handle))
                         )
                       )
                     )
                   )
        )
        (setq *dscp (cons *lst *dscp))
      )
    )
  )
  (setq _datalist (append 
                    (list '(0 . "XRECORD") 
                          '(102 . "{ACAD_XDICTIONARY")
                          (cons 360 _root)
                          '(102 . "}")
                          '(100 . "AcDbXrecord")
                          '(280 . 1)
                    )
                    '((1 . "AcLyLayerGroup")
                      (90 . 1)
                      (300 . "Plumbing")
                     )
                    *dscp
                  )
  )
  (setq _xname (entmakex _datalist))
  (dictadd *ent "Dyl-P" _xname)


  (setq _dict (entget _dict))
  (setq _dict (vl-remove (car _dict) _dict))
  (setq _dict (entmakex _dict))
  (dictadd _root "ACLYDICTIONARY" _dict)
  ;#endregion

  ;#region Structural
  (setq *len (vlax-get-property *obj 'Count))
  (setq *tst (cdr (car (dictnext *ent T))))
  (setq *ctr 0)
  (while (< *ctr *len) 
    (if (= (cdr (assoc 300 (entget *tst))) "Structural") 
      (progn 
        (setq *tst:nme (vlax-get-property (vlax-ename->vla-object *tst) 'Name))
        (vlax-put-property (vlax-ename->vla-object *tst) 'Name "Dyl-S")
        (setq *len *ctr)
      )
      (progn 
        (setq *tst (cdr (car (dictnext *ent))))
        (setq *ctr (1+ *ctr))
      )
    )
  )

  (dictremove *ent "Dyl-S")

  (setq _root (list '(0 . "DICTIONARY") '(100 . "AcDbDictionary") '(280 . 1) '(281 . 1)))
  (setq _root (entmakex _root))

  (setq _dict (list '(0 . "DICTIONARY") '(100 . "AcDbDictionary") '(280 . 1) '(281 . 1)))
  (setq _dict (entmakex _dict))

  (setq *dscp nil)

  (vlax-for *lyr *lcl 
    (setq *nme (vlax-get-property *lyr 'name))
    (if (or (= *nme "0") (= (strcase *nme) "DEFPOINTS") (wcmatch *nme "S-*")) 
      (progn 
        (setq *lst (cons 
                     '330
                     (cdr 
                       (assoc 
                         -1
                         (entget 
                           (handent (vlax-get-property *lyr 'handle))
                         )
                       )
                     )
                   )
        )
        (setq *dscp (cons *lst *dscp))
      )
    )
  )
  (setq _datalist (append 
                    (list '(0 . "XRECORD") 
                          '(102 . "{ACAD_XDICTIONARY")
                          (cons 360 _root)
                          '(102 . "}")
                          '(100 . "AcDbXrecord")
                          '(280 . 1)
                    )
                    '((1 . "AcLyLayerGroup")
                      (90 . 1)
                      (300 . "Structural")
                     )
                    *dscp
                  )
  )
  (setq _xname (entmakex _datalist))
  (dictadd *ent "Dyl-S" _xname)


  (setq _dict (entget _dict))
  (setq _dict (vl-remove (car _dict) _dict))
  (setq _dict (entmakex _dict))
  (dictadd _root "ACLYDICTIONARY" _dict)
  ;#endregion

  ;#endregion
)


(defun Dyl-A () 
  (setq *dic  "Architectural"
        *obj  "Dyl-A"
        *obj2 "Dyl-A-Detail"
  )
)

;; Layer Groups
;; Creates the standard Dynalisp layer group filters in the Layer Properties Manager.

(defun c:Dyl-LayerGroup () 
  (Dyl:LayGroup)
)