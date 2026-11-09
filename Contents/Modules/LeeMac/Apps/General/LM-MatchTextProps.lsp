;;  Match Text Properties
;;  Copyright (C) 2026  Samuel Martineau
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

;;---------------=={ Match Text Properties }==----------------;;
;;                                                            ;;
;;  Prompts for a selection of Text, MText, Attribute, or     ;;
;;  Attribute Definition object to use as property source,    ;;
;;  then proceed to match those properties listed for similar ;;
;;  objects selected thereafter.                              ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2010 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;

;; Match Text Properties
;; Matches the properties of a source text, Mtext or attribute to the selected objects.

(defun c:LM-MatchTextProperties ( / *error* _StartUndo _EndUndo _GetTextInsertion _PutTextInsertion Props doc entity object ss )
  (vl-load-com)
  ;; © Lee Mac 2010

  (setq Props
   '(
     Alignment
     AttachmentPoint
     BackgroundFill
     Backward
     DrawingDirection
     Height
     Layer
     LineSpacingDistance
     LineSpacingFactor
     LineSpacingStyle
     Linetype
     LinetypeScale
     Lineweight
     ObliqueAngle
     Rotation
     ScaleFactor
     StyleName
    ; TextString
     Thickness
     UpsideDown
     Width
    )
  )

  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))

  (defun *error* ( msg )
    (if doc (_EndUndo doc)) (if mutt (setvar 'NOMUTT mutt))
    (or (wcmatch (strcase msg) "*BREAK,*CANCEL*,*EXIT*")
        (princ (strcat "\n** Error: " msg " **")))
    (princ)
  )

  (defun _StartUndo ( doc ) (_EndUndo doc)
    (vla-StartUndoMark doc)
  )

  (defun _EndUndo ( doc )
    (if (= 8 (logand 8 (getvar 'UNDOCTL)))
      (vla-EndUndoMark doc)
    )
  )

  (defun _GetTextInsertion ( object )
    (vlax-get-property object
      (if
        (or
          (eq "AcDbMText" (vla-get-ObjectName object))
          (vl-position (vla-get-Alignment object)
            (list acAlignmentLeft acAlignmentFit acAlignmentAligned)
          )
        )
        'InsertionPoint
        'TextAlignmentPoint
      )
    )
  )

  (defun _PutTextInsertion ( object point )
    (vlax-put-property object
      (if
        (or
          (eq "AcDbMText" (vla-get-ObjectName object))
          (vl-position (vla-get-Alignment object)
            (list acAlignmentLeft acAlignmentFit acAlignmentAligned)
          )
        )
        'InsertionPoint
        'TextAlignmentPoint
      )
      point
    )
  )

  (if
    (and
      (setq entity
        (LM:Selectif
          (lambda ( x )
            (wcmatch (cdr (assoc 0 (entget x))) "TEXT,MTEXT,ATTRIB,ATTDEF")
          )
          nentsel "\nSelect Source Object: "
        )
      )
      (progn
        (setq mutt (getvar 'NOMUTT))
        (setvar 'NOMUTT 1)
        
        (princ (strcat "\nSelect Destination " (cdr (assoc 0 (entget entity))) " objects: "))
        (setq object (vlax-ename->vla-object entity)
          ss
           (ssget "_:L"
             (list
               (assoc 0 (entget entity))
             )
           )
        )
        (setvar 'NOMUTT mutt) ss
      )
    )
    (
      (lambda ( i values / entity obj )

        (_StartUndo doc)
        
        (while (setq entity (ssname ss (setq i (1+ i))))
          (setq obj (vlax-ename->vla-object entity))

          (mapcar
            (function
              (lambda ( prop value )
                (if
                  (vl-catch-all-error-p
                    (vl-catch-all-apply
                      (function
                        (lambda nil
                          (if (and (vlax-property-available-p obj prop t) value)
                            (if (vl-position prop '(Alignment AttachmentPoint))
                              (
                                (lambda ( insertion )
                                  (vlax-put-property obj prop value)
                                  (_PutTextInsertion obj insertion)
                                )
                                (_GetTextInsertion obj)
                              )
                              (vlax-put-property obj prop value)
                            )
                          )
                        )
                      )
                    )
                  )
                  (princ (strcat "\n** Error Applying Property: " Prop " **"))
                )
              )
            )
            Props Values
          )
        )

        (_EndUndo doc)
      )
      -1
      (mapcar
        (function
          (lambda ( prop )
            (if (vlax-property-available-p object prop)
              (vlax-get-property object prop)
            )
          )
        )
        Props
      )
    )
  )
  (princ)
)

;;---------------------=={ Select if }==----------------------;;
;;                                                            ;;
;;  Continuous selection prompts until the predicate function ;;
;;  foo is validated                                          ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2010 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  foo - optional predicate function taking ename argument   ;;
;;  fun - selection function to invoke                        ;;
;;  str - prompt string                                       ;;
;;------------------------------------------------------------;;
;;  Returns:  selected entity ename if successful, else nil   ;;
;;------------------------------------------------------------;;

(defun LM:Selectif ( foo fun str / e )
  ;; © Lee Mac 2010
  (while
    (progn (setq e (car (fun str)))      
      (cond
        ( (eq 'ENAME (type e))

          (if (and foo (not (foo e)))
            (princ "\n** Invalid Object Selected **")
          )
        )
      )
    )
  )
  e
)