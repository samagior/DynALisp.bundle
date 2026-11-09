;; QuickSelectSimilar - Customizable Select Similar
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
;;; QuickSelectSimilar.lsp
;;;
;;; Customizable "Select Similar" for AutoCAD / AutoCAD Architecture.
;;;
;;; Selects every visible object of the current space that matches criteria
;;; chosen on the fly in a dialog box:
;;;   - one or many object types (DXF names, shown with live counts);
;;;   - optional property filters, combined with a logical AND:
;;;       Layer, Color, Linetype, Lineweight,
;;;       Text style (TEXT / MTEXT / ATTDEF), Dim style (dimensions),
;;;       Block name (block references, dynamic blocks supported);
;;;   - scope: whole current space or current view only;
;;;   - options: exclude locked layers, add to the current selection.
;;;
;;; Filter syntax:
;;;   Each field accepts comma-separated values and the * ? wildcards.
;;;   Within one field, values are combined with OR.
;;;   Type-specific filters (text style, dim style, block name) only restrict
;;;   their own object types; other selected types are not affected by them.
;;;
;;; Commands:
;;;   QSS              - run the command
;;;   QSELECTSIMILAR   - alias of QSS
;;;
;;; Workflow:
;;;   1. Pre-select reference object(s), or pick them at the prompt
;;;      (press Enter to skip and open the dialog with the last settings).
;;;   2. The dialog is pre-filled with the reference types and properties.
;;;      Check the filters to apply, edit values as needed.
;;;   3. "Choisir reference <" lets you pick new reference objects without
;;;      losing the dialog settings.
;;;   4. OK: the result is gripped (PICKFIRST) and stored as "Previous".
;;;
;;; Notes:
;;;   - "Visible" means: layer on and thawed, object not invisible (DXF 60).
;;;     Layers frozen only in a paper space viewport (VP freeze) are not
;;;     detected.
;;;   - The color filter compares ACI values (true colors use their ACI).
;;;   - Dialog settings are remembered for the current drawing session.
;;;   - The dialog definition (DCL) is generated at run time, so this single
;;;     .lsp file is all that is needed.
;;; ==========================================================================

(vl-load-com)


;;; ==========================================================================
;;; SECTION 1 - CONFIGURATION AND SESSION STATE
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; *qss:properties*
;;;   Data-driven table of the property filters. Adding a filter here adds a
;;;   row to the dialog automatically (a reader must also be added in
;;;   qss:prop-string).
;;;
;;;   Entry format: (key label applicable-types)
;;;     key              -> suffix of the dialog tiles ("t_<key>", "v_<key>")
;;;     label            -> text displayed in the dialog
;;;     applicable-types -> wcmatch pattern of the DXF types the filter
;;;                         applies to, or nil if it applies to every type.
;;; --------------------------------------------------------------------------
(setq *qss:properties* '(("layer" "Calque" nil)
                         ("color" "Couleur (ACI)" nil)
                         ("ltype" "Type de ligne" nil)
                         ("lweight" "Epaisseur (mm)" nil)
                         ("tstyle" "Style de texte" "TEXT,MTEXT,ATTDEF")
                         ("dstyle" "Style de cote" "*DIMENSION")
                         ("block" "Nom de bloc" "INSERT")
                        )
)

;;; --------------------------------------------------------------------------
;;; Session state (global variables, prefixed *qss:)
;;;   *qss:settings*    -> association list of the dialog values, kept for
;;;                        the whole session (see Section 5).
;;;   *qss:ref-types*   -> object types of the current reference objects.
;;;   *qss:type-names*  -> DXF type names, in the order shown in the list box.
;;; --------------------------------------------------------------------------
(if (not (boundp '*qss:settings*)) (setq *qss:settings* nil))
(setq *qss:ref-types*  nil
      *qss:type-names* nil
)


;;; ==========================================================================
;;; SECTION 2 - STRING AND LIST UTILITIES
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; qss:split
;;;   Splits a string on a delimiter.
;;;   Arguments : str   - string to split
;;;               delim - delimiter string
;;;   Returns   : list of substrings (empty items included)
;;; --------------------------------------------------------------------------
(defun qss:split (str delim / pos result) 
  (while (setq pos (vl-string-search delim str)) 
    (setq result (cons (substr str 1 pos) result)
          str    (substr str (+ pos 1 (strlen delim)))
    )
  )
  (reverse (cons str result))
)

;;; --------------------------------------------------------------------------
;;; qss:join
;;;   Joins a list of strings with a delimiter.
;;;   Arguments : lst   - list of strings
;;;               delim - delimiter string
;;;   Returns   : single string ("" for an empty list)
;;; --------------------------------------------------------------------------
(defun qss:join (lst delim / result) 
  (setq result "")
  (foreach item lst 
    (setq result (if (= result "") item (strcat result delim item)))
  )
  result
)

;;; --------------------------------------------------------------------------
;;; qss:tokens
;;;   Splits a comma-separated field into trimmed, non-empty tokens.
;;;   Arguments : str - raw text typed in a dialog field
;;;   Returns   : list of tokens
;;; --------------------------------------------------------------------------
(defun qss:tokens (str) 
  (vl-remove "" 
             (mapcar '(lambda (tok) (vl-string-trim " \t" tok)) 
                     (qss:split str ",")
             )
  )
)

;;; --------------------------------------------------------------------------
;;; qss:unique
;;;   Removes duplicates from a list, keeping the first occurrence order.
;;;   Arguments : lst - any list
;;;   Returns   : list without duplicates
;;; --------------------------------------------------------------------------
(defun qss:unique (lst / result) 
  (foreach item lst 
    (if (not (member item result)) (setq result (cons item result)))
  )
  (reverse result)
)

;;; --------------------------------------------------------------------------
;;; qss:escape-wc
;;;   Escapes wcmatch special characters with a backquote so that a real
;;;   name (layer, style, block...) is matched literally.
;;;   Arguments : str - name to escape
;;;   Returns   : escaped string
;;; --------------------------------------------------------------------------
(defun qss:escape-wc (str / special result) 
  (setq special (vl-string->list "#@*?~[]`")
        result  ""
  )
  (foreach code (vl-string->list str) 
    (setq result (strcat result 
                         (if (member code special) "`" "")
                         (chr code)
                 )
    )
  )
  result
)


;;; ==========================================================================
;;; SECTION 3 - SELECTION SET UTILITIES
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; qss:ss->list
;;;   Converts a selection set into a list of entity names.
;;;   Arguments : ss - selection set or nil
;;;   Returns   : list of enames (nil if ss is nil)
;;; --------------------------------------------------------------------------
(defun qss:ss->list (ss / index result) 
  (if ss 
    (repeat (setq index (sslength ss)) 
      (setq result (cons (ssname ss (setq index (1- index))) result))
    )
  )
  result
)

;;; --------------------------------------------------------------------------
;;; qss:ss-union
;;;   Adds every object of ss2 to ss1.
;;;   Arguments : ss1, ss2 - selection sets
;;;   Returns   : ss1 (modified)
;;; --------------------------------------------------------------------------
(defun qss:ss-union (ss1 ss2) 
  (foreach ent (qss:ss->list ss2) (ssadd ent ss1))
  ss1
)

;;; --------------------------------------------------------------------------
;;; qss:count-by-type
;;;   Counts entities per DXF type.
;;;   Arguments : ents - list of enames
;;;   Returns   : sorted association list ((type . count) ...)
;;; --------------------------------------------------------------------------
(defun qss:count-by-type (ents / typ pair counts) 
  (foreach ent ents 
    (setq typ (cdr (assoc 0 (entget ent))))
    (if (setq pair (assoc typ counts)) 
      (setq counts (subst (cons typ (1+ (cdr pair))) pair counts))
      (setq counts (cons (cons typ 1) counts))
    )
  )
  (vl-sort counts '(lambda (a b) (< (car a) (car b))))
)


;;; ==========================================================================
;;; SECTION 4 - DRAWING STATE (SPACE, LAYERS, VIEW)
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; qss:current-space
;;;   Returns the layout name (DXF 410) of the space the user works in.
;;;   Working in model space through a paper space viewport returns "Model".
;;; --------------------------------------------------------------------------
(defun qss:current-space () 
  (if (and (= (getvar "TILEMODE") 0) (/= (getvar "CVPORT") 1)) 
    "Model"
    (getvar "CTAB")
  )
)

;;; --------------------------------------------------------------------------
;;; qss:excluded-layers
;;;   Lists the layers whose objects must be ignored: layers that are off or
;;;   frozen and, optionally, locked layers.
;;;   Arguments : exclude-locked - T to also exclude locked layers
;;;   Returns   : list of upper-case layer names
;;; --------------------------------------------------------------------------
(defun qss:excluded-layers (exclude-locked / rec flags result) 
  (while (setq rec (tblnext "LAYER" (null rec))) 
    (setq flags (cdr (assoc 70 rec)))
    (if 
      (or (minusp (cdr (assoc 62 rec)))  ; layer off
          (= 1 (logand 1 flags)) ; layer frozen
          (and exclude-locked (= 4 (logand 4 flags)))
      ) ; layer locked
      (setq result (cons (strcase (cdr (assoc 2 rec))) result))
    )
  )
  result
)

;;; --------------------------------------------------------------------------
;;; qss:visible-p
;;;   Tests whether an object is visible (layer not excluded and object not
;;;   flagged invisible with DXF 60).
;;;   Arguments : ed       - entity data list (entget)
;;;               excluded - list from qss:excluded-layers
;;;   Returns   : T or nil
;;; --------------------------------------------------------------------------
(defun qss:visible-p (ed excluded) 
  (and (not (member (strcase (cdr (assoc 8 ed))) excluded)) 
       (/= 1 (cdr (assoc 60 ed)))
  )
)

;;; --------------------------------------------------------------------------
;;; qss:view-corners
;;;   Computes the lower-left and upper-right corners of the current view,
;;;   expressed in the current UCS (for ssget "_C").
;;;   Returns   : (lower-left upper-right)
;;; --------------------------------------------------------------------------
(defun qss:view-corners (/ center height width screen) 
  (setq center (trans (getvar "VIEWCTR") 1 2) ; UCS -> DCS
        height (getvar "VIEWSIZE")
        screen (getvar "SCREENSIZE")
        width  (* height (/ (car screen) (cadr screen)))
  )
  (list 
    (trans 
      (list (- (car center) (/ width 2.0)) 
            (- (cadr center) (/ height 2.0))
            0.0
      )
      2
      1
    )
    (trans 
      (list (+ (car center) (/ width 2.0)) 
            (+ (cadr center) (/ height 2.0))
            0.0
      )
      2
      1
    )
  )
)

;;; --------------------------------------------------------------------------
;;; qss:visible-entities
;;;   Collects every visible object of a space.
;;;   Arguments : space    - layout name (DXF 410)
;;;               excluded - list from qss:excluded-layers
;;;   Returns   : list of enames
;;; --------------------------------------------------------------------------
(defun qss:visible-entities (space excluded) 
  (vl-remove-if-not 
    '(lambda (ent) (qss:visible-p (entget ent) excluded))
    (qss:ss->list (ssget "_X" (list (cons 410 space))))
  )
)


;;; ==========================================================================
;;; SECTION 5 - SETTINGS (DIALOG VALUES KEPT FOR THE SESSION)
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; qss:default-settings
;;;   Builds the initial settings. Keys match the dialog tile keys:
;;;     "types"           -> list of selected DXF types
;;;     "t_<key>"         -> "1"/"0" filter toggle (Layer is on by default)
;;;     "v_<key>"         -> filter value string
;;;     "scope"           -> "sc_space" or "sc_view"
;;;     "o_locked","o_add"-> "1"/"0" options
;;; --------------------------------------------------------------------------
(defun qss:default-settings () 
  (append 
    (list (cons "types" nil) 
          (cons "scope" "sc_space")
          (cons "o_locked" "0")
          (cons "o_add" "0")
    )
    (apply 'append 
           (mapcar 
             '(lambda (prop) 
                (list (cons (strcat "t_" (car prop)) (if (= (car prop) "layer") "1" "0")) 
                      (cons (strcat "v_" (car prop)) "")
                )
              )
             *qss:properties*
           )
    )
  )
)

;;; --------------------------------------------------------------------------
;;; qss:get / qss:put
;;;   Read and write one value of *qss:settings*.
;;; --------------------------------------------------------------------------
(defun qss:get (key) 
  (cdr (assoc key *qss:settings*))
)

(defun qss:put (key value / old) 
  (setq old (assoc key *qss:settings*))
  (setq *qss:settings* (if old 
                         (subst (cons key value) old *qss:settings*)
                         (cons (cons key value) *qss:settings*)
                       )
  )
  value
)

;;; --------------------------------------------------------------------------
;;; qss:init-session
;;;   Creates the settings on first use and clears the reference of the
;;;   previous run.
;;; --------------------------------------------------------------------------
(defun qss:init-session () 
  (if (null *qss:settings*) (setq *qss:settings* (qss:default-settings)))
  (setq *qss:ref-types* nil)
)


;;; ==========================================================================
;;; SECTION 6 - PROPERTY READERS AND FILTER PATTERNS
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; qss:color->string
;;;   Converts an ACI value (DXF 62) to its display string.
;;;   Arguments : aci - integer or nil (nil = BYLAYER)
;;; --------------------------------------------------------------------------
(defun qss:color->string (aci) 
  (cond 
    ((or (null aci) (= aci 256)) "BYLAYER")
    ((= aci 0) "BYBLOCK")
    (T (itoa aci))
  )
)

;;; --------------------------------------------------------------------------
;;; qss:lweight->string
;;;   Converts a lineweight (DXF 370, hundredths of mm) to its display string.
;;;   Arguments : lw - integer or nil (nil = BYLAYER)
;;; --------------------------------------------------------------------------
(defun qss:lweight->string (lw) 
  (cond 
    ((or (null lw) (= lw -1)) "BYLAYER")
    ((= lw -2) "BYBLOCK")
    ((= lw -3) "DEFAULT")
    (T (rtos (/ lw 100.0) 2 2))
  )
)

;;; --------------------------------------------------------------------------
;;; qss:effective-name
;;;   Returns the effective name of a block reference, so that instances of
;;;   a dynamic block (anonymous *U names) match their parent block name.
;;;   Arguments : ent - ename of the INSERT
;;;               ed  - its entity data list (fallback on DXF 2)
;;; --------------------------------------------------------------------------
(defun qss:effective-name (ent ed / name) 
  (setq name (vl-catch-all-apply 'vla-get-EffectiveName 
                                 (list (vlax-ename->vla-object ent))
             )
  )
  (if (vl-catch-all-error-p name) (cdr (assoc 2 ed)) name)
)

;;; --------------------------------------------------------------------------
;;; qss:prop-applies-p
;;;   Tests whether a property filter applies to an object type.
;;;   Arguments : key - property key from *qss:properties*
;;;               typ - DXF type name
;;; --------------------------------------------------------------------------
(defun qss:prop-applies-p (key typ / pattern) 
  (setq pattern (caddr (assoc key *qss:properties*)))
  (or (null pattern) (wcmatch typ pattern))
)

;;; --------------------------------------------------------------------------
;;; qss:prop-string
;;;   Reads one property of an object as a display string. Missing DXF
;;;   groups are replaced by their AutoCAD default value.
;;;   Arguments : ent - ename
;;;               ed  - entity data list
;;;               key - property key from *qss:properties*
;;;   Returns   : string, or nil if the property does not apply to the type
;;; --------------------------------------------------------------------------
(defun qss:prop-string (ent ed key) 
  (if (qss:prop-applies-p key (cdr (assoc 0 ed))) 
    (cond 
      ((= key "layer") (cdr (assoc 8 ed)))
      ((= key "color") (qss:color->string (cdr (assoc 62 ed))))
      ((= key "ltype") (cond ((cdr (assoc 6 ed))) ("BYLAYER")))
      ((= key "lweight") (qss:lweight->string (cdr (assoc 370 ed))))
      ((= key "tstyle") (cond ((cdr (assoc 7 ed))) ("Standard")))
      ((= key "dstyle") (cond ((cdr (assoc 3 ed))) ("Standard")))
      ((= key "block") (qss:effective-name ent ed))
    )
  )
)

;;; --------------------------------------------------------------------------
;;; qss:normalize-pattern
;;;   Cleans a filter field typed by the user into an upper-case wcmatch
;;;   pattern: trims tokens, formats lineweights like qss:lweight->string,
;;;   and maps colors 256 / 0 to BYLAYER / BYBLOCK.
;;;   Arguments : key - property key
;;;               str - raw field text
;;;   Returns   : pattern string ("" if the field is empty)
;;; --------------------------------------------------------------------------
(defun qss:normalize-pattern (key str) 
  (strcase 
    (qss:join 
      (mapcar 
        '(lambda (tok / num) 
           (cond 
             ((and (= key "lweight") (setq num (distof tok 2))) (rtos num 2 2))
             ((and (= key "color") (= tok "256")) "BYLAYER")
             ((and (= key "color") (= tok "0")) "BYBLOCK")
             (T tok)
           )
         )
        (qss:tokens str)
      )
      ","
    )
  )
)

;;; --------------------------------------------------------------------------
;;; qss:active-filters
;;;   Lists the filters that are checked and have a non-empty value.
;;;   Returns   : association list ((key . pattern) ...)
;;; --------------------------------------------------------------------------
(defun qss:active-filters (/ key pattern result) 
  (foreach prop *qss:properties* 
    (setq key (car prop))
    (if 
      (and (= (qss:get (strcat "t_" key)) "1") 
           (/= "" (setq pattern (qss:normalize-pattern key (qss:get (strcat "v_" key)))))
      )
      (setq result (cons (cons key pattern) result))
    )
  )
  (reverse result)
)

;;; --------------------------------------------------------------------------
;;; qss:filters-match-p
;;;   Tests an object against every active filter (logical AND). A filter
;;;   that does not apply to the object type is ignored.
;;;   Arguments : ent, ed - ename and its entity data list
;;;               filters - list from qss:active-filters
;;; --------------------------------------------------------------------------
(defun qss:filters-match-p (ent ed filters / ok value) 
  (setq ok T)
  (foreach filter filters 
    (if ok 
      (progn 
        (setq value (qss:prop-string ent ed (car filter)))
        (if (and value (not (wcmatch (strcase value) (cdr filter)))) 
          (setq ok nil)
        )
      )
    )
  )
  ok
)


;;; ==========================================================================
;;; SECTION 7 - REFERENCE OBJECTS
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; qss:prompt-reference
;;;   Asks the user for reference object(s).
;;;   Returns   : selection set, or nil if the user pressed Enter
;;; --------------------------------------------------------------------------
(defun qss:prompt-reference () 
  (princ "\nChoisissez le ou les objets de reference <Entree = aucun> : ")
  (ssget)
)

;;; --------------------------------------------------------------------------
;;; qss:set-reference
;;;   Pre-fills the settings from reference objects: their types become the
;;;   selected types, and each property field receives the distinct values
;;;   found among them (comma-separated). Does nothing if ss is nil.
;;;   Arguments : ss - selection set of reference objects, or nil
;;; --------------------------------------------------------------------------
(defun qss:set-reference (ss / ents eds values) 
  (if ss 
    (progn 
      (setq ents (qss:ss->list ss)
            eds  (mapcar 'entget ents)
      )
      ;; Object types
      (setq *qss:ref-types* (qss:unique (mapcar '(lambda (ed) (cdr (assoc 0 ed))) eds)))
      (qss:put "types" *qss:ref-types*)
      ;; Property values (escaped to be matched literally)
      (foreach prop *qss:properties* 
        (setq values (qss:unique 
                       (vl-remove nil 
                                  (mapcar '(lambda (ent ed) (qss:prop-string ent ed (car prop))) ents eds)
                       )
                     )
        )
        (qss:put 
          (strcat "v_" (car prop))
          (qss:join (mapcar 'qss:escape-wc values) ",")
        )
      )
    )
  )
  ss
)


;;; ==========================================================================
;;; SECTION 8 - SELECTION ENGINE
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; qss:build-selection
;;;   Builds the result selection set from the current settings:
;;;     1. ssget pre-filters on type and space (whole space or current view);
;;;     2. each candidate is checked for visibility and property filters.
;;;   Arguments : space    - layout name (DXF 410)
;;;               excluded - list from qss:excluded-layers
;;;   Returns   : selection set (possibly empty)
;;; --------------------------------------------------------------------------
(defun qss:build-selection (space excluded / filter-list corners candidates filters result ed) 
  ;; Step 1 - ssget pre-filter
  (setq filter-list (list (cons 0 (qss:join (mapcar 'qss:escape-wc (qss:get "types")) ",")) 
                          (cons 410 space)
                    )
  )
  (setq candidates (if (= (qss:get "scope") "sc_view") 
                     (progn 
                       (setq corners (qss:view-corners))
                       (ssget "_C" (car corners) (cadr corners) filter-list)
                     )
                     (ssget "_X" filter-list)
                   )
  )

  ;; Step 2 - visibility and property filters
  (setq filters (qss:active-filters)
        result  (ssadd)
  )
  (foreach ent (qss:ss->list candidates) 
    (setq ed (entget ent))
    (if 
      (and (qss:visible-p ed excluded) 
           (qss:filters-match-p ent ed filters)
      )
      (ssadd ent result)
    )
  )
  result
)

;;; --------------------------------------------------------------------------
;;; qss:report
;;;   Prints the number of selected objects, detailed by type.
;;;   Arguments : ss - result selection set
;;; --------------------------------------------------------------------------
(defun qss:report (ss) 
  (princ (strcat "\nQSS : " (itoa (sslength ss)) " objet(s) selectionne(s)"))
  (if (> (sslength ss) 0) 
    (princ 
      (strcat " : " 
              (qss:join 
                (mapcar '(lambda (pair) (strcat (car pair) " (" (itoa (cdr pair)) ")")) 
                        (qss:count-by-type (qss:ss->list ss))
                )
                ", "
              )
      )
    )
  )
  (princ ".")
)


;;; ==========================================================================
;;; SECTION 9 - DIALOG DEFINITION (DCL GENERATED AT RUN TIME)
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; qss:dcl-lines
;;;   Returns the DCL source as a list of lines. The property filter rows
;;;   are generated from *qss:properties*.
;;; --------------------------------------------------------------------------
(defun qss:dcl-lines () 
  (append 
    ;; Header and object type list (left column)
    (list "qss_dialog : dialog {" "  label = \"Selection rapide d'objets similaires\";" "  : row {" 
          "    : boxed_column {" "      label = \"Types d'objets visibles (espace courant)\";" 
          "      : list_box { key = \"types\"; multiple_select = true;" 
          "                   width = 40; height = 18; fixed_width = true; }" "      : row {" 
          "        : button { key = \"all\";  label = \"Tous\"; }" "        : button { key = \"none\"; label = \"Aucun\"; }" 
          "        : button { key = \"ref\";  label = \"Reference\"; }" "      }" "    }" "    : column {" 
          "      : boxed_column {" "        label = \"Filtres de proprietes (ET logique)\";"
    )
    ;; One row per property filter: toggle + edit box
    (mapcar 
      '(lambda (prop) 
         (strcat "        : row { : toggle { key = \"t_" 
                 (car prop)
                 "\"; label = \""
                 (cadr prop)
                 "\"; width = 18; fixed_width = true; }"
                 " : edit_box { key = \"v_"
                 (car prop)
                 "\"; edit_width = 28; edit_limit = 256; } }"
         )
       )
      *qss:properties*
    )
    ;; Help text, scope, options and buttons
    (list "        : text { label = \"Valeurs separees par des virgules, jokers * et ? permis.\"; }" 
          "        : text { label = \"Styles et nom de bloc ne filtrent que leurs propres types.\"; }" "      }" 
          "      : boxed_radio_column {" "        label = \"Portee\"; key = \"scope\";" 
          "        : radio_button { key = \"sc_space\"; label = \"Tout l'espace courant\"; }" 
          "        : radio_button { key = \"sc_view\";  label = \"Vue courante seulement\"; }" "      }" 
          "      : boxed_column {" "        label = \"Options\";" 
          "        : toggle { key = \"o_locked\"; label = \"Exclure les calques verrouilles\"; }" 
          "        : toggle { key = \"o_add\";    label = \"Ajouter a la selection courante\"; }" "      }" "    }" "  }" 
          "  : row {" "    fixed_width = true; alignment = centered;" 
          "    : button { key = \"pick\"; label = \"Choisir reference <\"; width = 22; }" "    ok_button;" 
          "    cancel_button;" "    : button { key = \"docs\"; label = \"Open Docs\"; width = 12; fixed_width = true; }" "  }" "  errtile;" "}"
    )
  )
)

;;; --------------------------------------------------------------------------
;;; qss:write-dcl
;;;   Writes the DCL source to a temporary file.
;;;   Returns   : full path of the file
;;; --------------------------------------------------------------------------
(defun qss:write-dcl (/ path file) 
  (setq path (vl-filename-mktemp "qss" nil ".dcl")
        file (open path "w")
  )
  (foreach line (qss:dcl-lines) (write-line line file))
  (close file)
  path
)


;;; ==========================================================================
;;; SECTION 10 - DIALOG HANDLERS
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; qss:types->indices / qss:indices->types
;;;   Convert between a list of DXF type names and the list box value
;;;   (space-separated indices, e.g. "0 3 5").
;;; --------------------------------------------------------------------------
(defun qss:types->indices (selected names / index result) 
  (setq index  0
        result ""
  )
  (foreach name names 
    (if (member name selected) (setq result (strcat result (itoa index) " ")))
    (setq index (1+ index))
  )
  (vl-string-right-trim " " result)
)

(defun qss:indices->types (value names) 
  (mapcar '(lambda (index) (nth index names)) 
          (read (strcat "(" value ")"))
  )
)

;;; --------------------------------------------------------------------------
;;; qss:merge-types
;;;   Adds to the type counts the types that are selected or referenced but
;;;   absent from the space (count 0), so they remain visible in the list.
;;;   Arguments : counts - association list ((type . count) ...)
;;;               extra  - list of type names
;;; --------------------------------------------------------------------------
(defun qss:merge-types (counts extra) 
  (foreach typ extra 
    (if (not (assoc typ counts)) (setq counts (cons (cons typ 0) counts)))
  )
  (vl-sort counts '(lambda (a b) (< (car a) (car b))))
)

;;; --------------------------------------------------------------------------
;;; qss:dlg-init
;;;   Fills every tile of the dialog from the settings.
;;;   Arguments : type-counts - association list ((type . count) ...)
;;; --------------------------------------------------------------------------
(defun qss:dlg-init (type-counts / key) 
  ;; Object type list
  (setq *qss:type-names* (mapcar 'car type-counts))
  (start_list "types")
  (foreach pair type-counts 
    (add_list (strcat (car pair) "   (" (itoa (cdr pair)) ")"))
  )
  (end_list)
  (set_tile "types" (qss:types->indices (qss:get "types") *qss:type-names*))
  (mode_tile "ref" (if *qss:ref-types* 0 1))

  ;; Property filters (value field disabled when its toggle is off)
  (foreach prop *qss:properties* 
    (setq key (car prop))
    (set_tile (strcat "t_" key) (qss:get (strcat "t_" key)))
    (set_tile (strcat "v_" key) (qss:get (strcat "v_" key)))
    (mode_tile (strcat "v_" key) (if (= (qss:get (strcat "t_" key)) "1") 0 1))
  )

  ;; Scope and options
  (set_tile "scope" (qss:get "scope"))
  (set_tile "o_locked" (qss:get "o_locked"))
  (set_tile "o_add" (qss:get "o_add"))
)

;;; --------------------------------------------------------------------------
;;; qss:dlg-set-actions
;;;   Binds the dialog callbacks.
;;;   Return codes of start_dialog: 0 = cancel, 1 = OK, 2 = pick reference.
;;; --------------------------------------------------------------------------
(defun qss:dlg-set-actions () 
  (action_tile "all" "(set_tile \"types\" (qss:types->indices *qss:type-names* *qss:type-names*))")
  (action_tile "none" "(set_tile \"types\" \"\")")
  (action_tile "ref" "(set_tile \"types\" (qss:types->indices *qss:ref-types* *qss:type-names*))")
  (foreach prop *qss:properties* 
    (action_tile (strcat "t_" (car prop)) "(qss:dlg-toggle-field $key $value)")
  )
  (action_tile "pick" "(qss:dlg-save) (done_dialog 2)")
  (action_tile "accept" "(qss:dlg-accept)")
  (action_tile "cancel" "(done_dialog 0)")
)

;;; --------------------------------------------------------------------------
;;; qss:dlg-toggle-field
;;;   Enables or disables the value field linked to a filter toggle and
;;;   gives it the focus when enabled.
;;;   Arguments : key   - toggle key ("t_<prop>")
;;;               value - "1" or "0"
;;; --------------------------------------------------------------------------
(defun qss:dlg-toggle-field (key value / field) 
  (setq field (strcat "v_" (substr key 3)))
  (mode_tile field (if (= value "1") 0 1))
  (if (= value "1") (mode_tile field 2))
)

;;; --------------------------------------------------------------------------
;;; qss:dlg-save
;;;   Copies every tile value into the settings.
;;; --------------------------------------------------------------------------
(defun qss:dlg-save () 
  (qss:put "types" (qss:indices->types (get_tile "types") *qss:type-names*))
  (foreach prop *qss:properties* 
    (foreach prefix '("t_" "v_") 
      (qss:put (strcat prefix (car prop)) (get_tile (strcat prefix (car prop))))
    )
  )
  (foreach key '("scope" "o_locked" "o_add") 
    (qss:put key (get_tile key))
  )
)

;;; --------------------------------------------------------------------------
;;; qss:dlg-accept
;;;   OK button: saves the values and closes the dialog, unless no object
;;;   type is selected.
;;; --------------------------------------------------------------------------
(defun qss:dlg-accept () 
  (qss:dlg-save)
  (if (null (qss:get "types")) 
    (set_tile "error" "Selectionnez au moins un type d'objet.")
    (done_dialog 1)
  )
)


;;; ==========================================================================
;;; SECTION 11 - MAIN COMMAND
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; C:Dyl-QuickSelectSimilar
;;;   Main command: reference -> dialog loop -> selection -> grips.
;;; --------------------------------------------------------------------------

;; Quick Select Similar
;; Selects the visible objects matching the types and properties chosen in a dialog.

(defun c:Dyl-QuickSelectSimilar (/ *error* old-cmdecho space pre-ss type-counts dcl-path dcl-id status excluded result) 

  ;; ------------------------------------------------------------------------
  ;; Error handler: unloads the dialog, deletes the temporary DCL file and
  ;; restores system variables.
  ;; ------------------------------------------------------------------------
  (defun *error* (msg) 
    (if dcl-id (unload_dialog dcl-id))
    (if (and dcl-path (findfile dcl-path)) (vl-file-delete dcl-path))
    (if old-cmdecho (setvar "CMDECHO" old-cmdecho))
    (if (and msg (not (wcmatch (strcase msg) "*BREAK*,*CANCEL*,*QUIT*,*EXIT*"))) 
      (princ (strcat "\nErreur : " msg))
    )
    (princ)
  )

  ;; ------------------------------------------------------------------------
  ;; Initialization
  ;; ------------------------------------------------------------------------
  (setq old-cmdecho (getvar "CMDECHO"))
  (setvar "CMDECHO" 0)
  (qss:init-session)
  (setq space (qss:current-space))

  ;; ------------------------------------------------------------------------
  ;; Reference objects: pre-selection (PICKFIRST) or prompt
  ;; ------------------------------------------------------------------------
  (setq pre-ss (ssget "_I"))
  (if pre-ss 
    (qss:set-reference pre-ss)
    (qss:set-reference (qss:prompt-reference))
  )

  ;; ------------------------------------------------------------------------
  ;; Visible object types of the current space (computed once)
  ;; ------------------------------------------------------------------------
  (setq type-counts (qss:count-by-type (qss:visible-entities space (qss:excluded-layers nil))))

  ;; ------------------------------------------------------------------------
  ;; Dialog loop: status 2 hides the dialog to pick new reference objects,
  ;; then reopens it with the settings preserved.
  ;; ------------------------------------------------------------------------
  (setq dcl-path (qss:write-dcl)
        dcl-id   (load_dialog dcl-path)
        status   2
  )
  (if (< dcl-id 0) (progn (setq dcl-id nil) (exit)))

  (while (= status 2) 
    (if (not (new_dialog "qss_dialog" dcl-id)) (exit))
    (qss:dlg-init 
      (qss:merge-types 
        type-counts
        (append *qss:ref-types* (qss:get "types"))
      )
    )
    (qss:dlg-set-actions)
    (Dyl:DocsTile "Utilities\\Dyl-QuickSelectSimilar.htm")
    (setq status (start_dialog))
    (if (= status 2) (qss:set-reference (qss:prompt-reference)))
  )

  (unload_dialog dcl-id)
  (vl-file-delete dcl-path)
  (setq dcl-id   nil
        dcl-path nil
  )

  ;; ------------------------------------------------------------------------
  ;; Selection: build, optionally merge with the pre-selection, grip it and
  ;; store it as the "Previous" selection.
  ;; ------------------------------------------------------------------------
  (if (= status 1) 
    (progn 
      (setq excluded (qss:excluded-layers (= (qss:get "o_locked") "1"))
            result   (qss:build-selection space excluded)
      )
      (if (and pre-ss (= (qss:get "o_add") "1")) 
        (setq result (qss:ss-union result pre-ss))
      )
      (qss:report result)
      (if (> (sslength result) 0) 
        (progn 
          (command "_.SELECT" result "")
          (sssetfirst nil result)
        )
        (sssetfirst nil nil)
      )
    )
    (princ "\nQSS : annule.")
  )

  (setvar "CMDECHO" old-cmdecho)
  (princ)
)

(princ "\nQuickSelectSimilar.lsp charge. Tapez Dyl-QuickSelectSimilar pour executer.")
(princ)
