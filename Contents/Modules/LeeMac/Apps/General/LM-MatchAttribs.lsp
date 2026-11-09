;;  Match Attribs
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

;;-------------------=={ Match Attribs }==--------------------;;
;;                                                            ;;
;;  Prompts for selection of source attribute, then proceeds  ;;
;;  to match the listed properties for subsequently picked    ;;
;;  attributes.                                               ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2010 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;

;; Match Attributes
;; Matches the properties of a source attribute to the picked attributes.

(defun c:LM-MatchAttributes ( / properties source )
  (vl-load-com)
  ;; © Lee Mac 2010

;; List of Properties to Match, may be edited to suit
;;------------------------------------------------------------;;
  
  (setq properties
   '(
     Backward
     Height
     Layer
     Linetype
     LinetypeScale
     Lineweight
     ObliqueAngle
     Rotation
     ScaleFactor
     StyleName
     Thickness
     UpsideDown
    )
  )

;;------------------------------------------------------------;;

  (if (setq source
        (LM:Selectif
          (lambda ( x )
            (eq "ATTRIB" (cdr (assoc 0 (entget x))))
          )
          nentsel "\nSelect Source Attribute: "
        )
      )
    (
      (lambda ( properties values / dest )
        (while
          (setq dest
            (LM:Selectif
              (lambda ( x )
                (eq "ATTRIB" (cdr (assoc 0 (entget x))))
              )
              nentsel "\nSelect Destination Attributes: "
            )
          )
          (setq dest (vlax-ename->vla-object dest))

          (mapcar
            (function
              (lambda ( property value )
                (vlax-put-property dest property value)
              )
            )
            properties values
          )
        )
      )
      properties
      (progn (setq source (vlax-ename->vla-object source))
        (mapcar
          (function
            (lambda ( property ) (vlax-get-property source property))
          )
          properties
        )
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