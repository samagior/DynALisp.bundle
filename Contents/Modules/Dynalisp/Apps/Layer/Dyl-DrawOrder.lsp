;; Dyl-DrawOrder - Stack the objects of the drawing by layer level: annotation on top, hatches at the bottom
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
;;
;;  Based on Layer Draw Order (LDOrder) by Lee Mac, Copyright (C) 2011 - www.lee-mac.com
;;
;;-------------------------=={ End of Licence }==------------------------;;

;;  The levels (rules of the presets, Modules\Dynalisp\Res\DrawOrder\<preset>.csv) are in
;;  Modules\Dynalisp\Remote\Dyl-DrawOrder.lsp and the auto draw order reactors in
;;  Modules\Dynalisp\Reactor\Dyl-DrawOrder.lsp, both loaded at startup (the reactors only
;;  while the DynALisp reactors are on, see Dyl-Settings) so that auto draw order works in
;;  every drawing without running a command first.

;;  Edit boxes of the dialog and index of their value in a rule row (the Layers cell, index
;;  2, is edited one wildcard per line in the lay list, the Objects cell, index 3, is
;;  picked in the obj popup from *ldo:catalog*):
(setq *ldo:tiles*   '(("lvl" . 0) ("ord" . 1) ("dsc" . 4) ("pri" . 5))
      *ldo:header*  '("Name" "Level" "Layers" "Objects" "Description" "Order")
      ;;  Rule types, from the cells used to match objects (see ldo:type):
      *ldo:types*   '("Layers" "Objects" "Layers + objects" "All objects")
      ;;  Sorts of the rule list (see ldo:before), the move buttons work in the first two:
      *ldo:sorts*   '("Level" "Order" "Type" "Name")
      ;;  Objects of the obj popup, by product (the Product popup), followed by the product
      ;;  "In this drawing" (the object types the drawing has, see ldo:dwgitems):
      ;;  ((product (label . DXF object types wildcard) ...) ...)
      ;;  Only the objects whose stacking shows in a 2D view are listed: annotation, linework,
      ;;  fills and masks, images, blocks (construction lines, cameras, lights, section planes
      ;;  or single surface types are left out). AutoCAD: the groups, then each object type
      ;;  after a separator (an item without wildcard, that cannot be picked).
      ;;  The other products name their objects with a prefix (AEC_ Architecture, AECB_ MEP,
      ;;  AECC_ Civil 3D, ACPP Plant 3D P&ID, ACM Mechanical) that their groups match with
      ;;  wildcards, their object names changing between releases. The Architecture groups
      ;;  follow the cut plane of the plan views: the objects it cuts, those below it, those
      ;;  above it. Draw order moves a whole object: the components of an object (cut lines,
      ;;  hatch, lines above the cut plane) are drawn by its display representation. Without
      ;;  the product or its object enabler, these objects are proxies (ACAD_PROXY_ENTITY).
      *ldo:catalog* '(("AutoCAD"
                       ("Annotation"
                        . "TEXT,MTEXT,ARCALIGNEDTEXT,*DIMENSION,*LEADER,TOLERANCE,ACAD_TABLE,ATTDEF"
                       )
                       ("Text" . "TEXT,MTEXT,ARCALIGNEDTEXT")
                       ("Dimensions" . "*DIMENSION")
                       ("All leaders" . "*LEADER")
                       ("Fills and masks" . "HATCH,MPOLYGON,SOLID,TRACE,WIPEOUT")
                       ("Hatches and gradients" . "HATCH,MPOLYGON")
                       ("Images and underlays" . "IMAGE,*UNDERLAY,POINTCLOUD*")
                       ("Lineworks" . "LINE,ARC,CIRCLE,ELLIPSE,SPLINE,LWPOLYLINE,POLYLINE,MLINE")
                       ("3D objects" . "3DSOLID,*SURFACE,MESH,3DFACE,BODY")
                       ("------  Object types  ------")
                       ("Arcs" . "ARC")
                       ("Arc-aligned text" . "ARCALIGNEDTEXT")
                       ("Attribute definitions" . "ATTDEF")
                       ("Blocks and xrefs" . "INSERT")
                       ("Circles" . "CIRCLE")
                       ("DGN underlays" . "DGNUNDERLAY")
                       ("DWF underlays" . "DWFUNDERLAY")
                       ("Ellipses" . "ELLIPSE")
                       ("Tolerances" . "TOLERANCE")
                       ("Hatches" . "HATCH")
                       ("Leaders" . "LEADER")
                       ("Lines" . "LINE")
                       ("Mtext" . "MTEXT")
                       ("Multileaders" . "MULTILEADER")
                       ("Multilines" . "MLINE")
                       ("Multi-polygons" . "MPOLYGON")
                       ("OLE objects" . "OLE2FRAME,OLEFRAME")
                       ("PDF underlays" . "PDFUNDERLAY")
                       ("Point clouds" . "POINTCLOUD,POINTCLOUDEX")
                       ("Polylines" . "LWPOLYLINE")
                       ("Heavy and 3D polylines" . "POLYLINE")
                       ("Proxy objects" . "ACAD_PROXY_ENTITY")
                       ("Raster images" . "IMAGE")
                       ("Regions" . "REGION")
                       ("Remote text" . "RTEXT")
                       ("2D solid fills" . "SOLID")
                       ("Splines" . "SPLINE")
                       ("Tables" . "ACAD_TABLE")
                       ("Single-line text" . "TEXT")
                       ("Traces" . "TRACE")
                       ("Wipeouts" . "WIPEOUT")
                      )
                      ("AutoCAD Architecture"
                       ("All Architecture objects" . "AEC_*")
                       ("Cut objects" . "AEC_*WALL*,AEC_*MEMBER*")
                       ("Openings" . "AEC_*DOOR*,AEC_*WINDOW*,AEC_*OPENING*")
                       ("Below cut plane objects" . "AEC_*STAIR*,AEC_*RAILING*,AEC_SLAB*")
                       ("Above cut plane objects" . "AEC_*ROOF*,AEC_*CEILING*")
                       ("Spaces and zones" . "AEC_*SPACE*,AEC_*ZONE*")
                       ("Mass elements" . "AEC_*MASS*")
                       ("Annotation objects" . "AEC_*MVBLOCK*,AEC_*SCHEDULE*,AEC_*DIM*,AEC_*GRID*")
                       ("Sections and elevations" . "AEC_*SECTION*,AEC_*ELEV*")
                      )
                      ("AutoCAD MEP"
                       ("All MEP objects" . "AECB_*")
                       ("Ducts" . "AECB_*DUCT*")
                       ("Pipes and plumbing" . "AECB_*PIPE*,AECB_*PLUMBING*")
                       ("Trays and conduits" . "AECB_*CABLETRAY*,AECB_*CONDUIT*")
                       ("Equipment" . "AECB_*MVPART*")
                       ("Electrical objects" . "AECB_*DEVICE*,AECB_*PANEL*,AECB_*WIRE*")
                       ("Schematics" . "AECB_*SCHEMATIC*")
                      )
                      ("Civil 3D"
                       ("All Civil 3D objects" . "AECC_*")
                       ("Surfaces" . "AECC_*SURFACE*")
                       ("Points" . "AECC_*POINT*")
                       ("Alignments" . "AECC_*ALIGNMENT*")
                       ("Profiles" . "AECC_*PROFILE*")
                       ("Sections" . "AECC_*SAMPLE*,AECC_*SECTION*")
                       ("Corridors" . "AECC_*CORRIDOR*")
                       ("Parcels" . "AECC_*PARCEL*")
                       ("Grading objects" . "AECC_*FEATURE*,AECC_*GRADING*,AECC_*SURVEY*,AECC_*FIGURE*")
                       ("Pipe networks" . "AECC_*PIPE*,AECC_*STRUCTURE*,AECC_*PRESSURE*")
                       ("Labels and tables" . "AECC_*LABEL*,AECC_*TABLE*")
                      )
                      ("Plant 3D P&ID" ("All P&ID objects" . "ACPP*"))
                      ("AutoCAD Mechanical"
                       ("All Mechanical objects" . "ACM*")
                       ("Annotation objects"
                        . "ACM*DIM*,ACM*BALLOON*,ACM*PARTLIST*,ACM*SYMBOL*"
                       )
                      )
                     )
)

;;-------------------------=={ Rules }==------------------------;;

;;  Default rules as rows of a preset file:
(defun ldo:defaults ()
  (mapcar '(lambda (r) (list (car r) (itoa (cadr r)) (nth 2 r) (nth 3 r) (nth 4 r) (itoa (nth 5 r)))) *do:defaults*)
)

;;  Rows of a preset file as they are written: ((name level layers objects description
;;  order) ...), every cell a string. A file without the Order column gets one (see
;;  Remote>>Dyl:DrawOrderFill):
(defun ldo:read (fle / lst)
  (foreach r (Remote>>Dyl:CsvRead fle 6)
    (if (/= "" (car r)) (setq lst (cons r lst)))
  )
  (Remote>>Dyl:DrawOrderFill (reverse lst))
)

;;  Order of a new rule: 10 after the highest order of the rules (999 at most):
(defun ldo:nextorder ()
  (itoa (min 999 (+ 10 (apply 'max (cons 0 (mapcar '(lambda (r) (atoi (nth 5 r))) ldo:lst))))))
)

;;  Every preset: ((name . rows) ...), a Default preset with the default rules when there
;;  is no preset file yet:
(defun ldo:presets (/ lst)
  (foreach n (Remote>>Dyl:DrawOrderPresets)
    (setq lst (cons (cons n (ldo:read (Remote>>Dyl:DrawOrderPresetFile n))) lst))
  )
  (cond
    ((reverse lst))
    ((list (cons "Default" (ldo:defaults))))
  )
)

;;  Write the presets: the files of the presets old (names when the dialog opened) that
;;  were deleted or renamed are deleted, every preset of sets ((name . rows) ...) is
;;  written. Returns the names of the files that could not be written (open in Excel):
(defun ldo:save (sets old / err)
  ;;  The presets are saved in the user copy of the folder (made the first time):
  (Remote>>Dyl:DrawOrderDirW)
  (foreach n old
    (if (not (member n (mapcar 'car sets))) (vl-file-delete (Remote>>Dyl:DrawOrderPresetFile n)))
  )
  (foreach s sets
    (if (not (Remote>>LM:writecsv (cons *ldo:header* (cdr s)) (Remote>>Dyl:DrawOrderPresetFile (car s))))
      (setq err (cons (car s) err))
    )
  )
  (setq *do:stamp* nil)
  (reverse err)
)

;;  Type of a row, index in *ldo:types*: 0 matches layers, 1 object types, 2 both,
;;  3 every object (Layers and Objects empty):
(defun ldo:type (r)
  (cond
    ((and (/= "" (nth 2 r)) (/= "" (nth 3 r))) 2)
    ((/= "" (nth 2 r)) 0)
    ((/= "" (nth 3 r)) 1)
    (3)
  )
)

;;  Objects of the drawing each rule gives its level to: ((count ...) . others), others
;;  being the objects no rule matches (they stay at 0):
(defun ldo:counts (rules / cnt ss i ed r n all)
  (setq cnt (mapcar '(lambda (r) 0) rules))
  (if (and rules (setq ss (ssget "_X" (Remote>>Dyl:DrawOrderFilter "*" rules))))
    (repeat (setq i (sslength ss))
      (setq ed (entget (ssname ss (setq i (1- i)))))
      (if (setq r (Remote>>Dyl:DrawOrderRule (strcase (cdr (assoc 8 ed))) (cdr (assoc 0 ed)) rules))
        (setq n   (vl-position r rules)
              cnt (Remote>>Dyl:ListSubst cnt n (1+ (nth n cnt)))
        )
      )
    )
  )
  (setq all (if (setq ss (ssget "_X" '((-4 . "<NOT") (0 . "VIEWPORT") (-4 . "NOT>")))) (sslength ss) 0))
  (cons cnt (max 0 (- all (apply '+ cnt))))
)

;;  Restack model space and every layout with rules (nil: the rules of the active preset) as
;;  one undo step. The drawing is regenerated so the new order shows (when the dialog is
;;  open and it cannot be done, ldo:regen is set). Returns the message to show:
(defun ldo:apply (rules / doc n)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (vla-StartUndoMark doc)
  (setq n (Remote>>Dyl:DrawOrderApply nil rules))
  (vla-EndUndoMark doc)
  (if (vl-catch-all-error-p (vl-catch-all-apply 'vla-Regen (list doc acAllViewports)))
    (setq ldo:regen t)
  )
  (strcat "Draw order applied: "
          (itoa n)
          " object(s) restacked in model space, "
          (itoa (length (layoutlist)))
          " layout(s) and "
          (itoa (length (Remote>>Dyl:DrawOrderBlocks)))
          " block definition(s)."
  )
)

;;-------------------------=={ Dialog }==------------------------;;

;;  Write the dialog definition to a temporary DCL file and return its path:
(defun ldo:dcl (/ path file)
  (setq path (vl-filename-mktemp "ldo" nil ".dcl")
        file (open path "w")
  )
  (foreach line
    '("dyl_ldo : dialog { label = \"DynALisp - Draw Order\";"
      "  : text { label = \"Objects are stacked by level: the highest level on top, the lowest at the bottom, the objects no rule matches at 0.\"; }"
      "  : text { label = \"When several rules match an object, the rule with the lowest order gives it its level.\"; }"
      "  : boxed_column { label = \"Presets\";"
      "    : row { fixed_width = true;"
      "      : popup_list { key = \"pst\"; label = \"Edit:\"; edit_width = 40; }"
      "      : button { key = \"pnw\"; label = \"New...\"; }"
      "      : button { key = \"prn\"; label = \"Rename...\"; }"
      "      : button { key = \"pdl\"; label = \"Delete\"; }"
      "    }"
      "    : row { fixed_width = true;"
      "      : popup_list { key = \"pdf\"; label = \"Preferred (every drawing):\"; edit_width = 30; }"
      "      : popup_list { key = \"pdw\"; label = \"This drawing:\"; edit_width = 40; }"
      "    }"
      "  }"
      "  : row {"
      "    : column {"
      "      : row { fixed_width = true;"
      "        : popup_list { key = \"srt\"; label = \"Sort by:\"; edit_width = 16; }"
      "      }"
      "      : list_box { key = \"hdr\"; width = 118; height = 2; fixed_height = true; tabs = \"6 12 29 49 65\"; is_enabled = false; }"
      "      : list_box { key = \"lst\"; width = 118; height = 16; tabs = \"6 12 29 49 65\"; multiple_select = true; }"
      "      : row { fixed_width = true;"
      "        : button { key = \"new\"; label = \"New\"; }"
      "        : button { key = \"cpy\"; label = \"Copy\"; }"
      "        : button { key = \"del\"; label = \"Delete\"; }"
      "        : button { key = \"mup\"; label = \"Move up\"; }"
      "        : button { key = \"mdn\"; label = \"Move down\"; }"
     "        : button { key = \"def\"; label = \"Restore defaults\"; }"
      "      }"
      "    }"
      "    : column {"
      "      : boxed_column { key = \"rbx\"; label = \"Rule (999 selected)\";"
      "        : edit_box { key = \"lvl\"; label = \"Name:\"; edit_width = 36; edit_limit = 64; }"
      "        : edit_box { key = \"dsc\"; label = \"Description:\"; edit_width = 36; edit_limit = 255; }"
      "        : edit_box { key = \"ord\"; label = \"Level (-99 to 99):\"; edit_width = 5; edit_limit = 3; }"
      "        : edit_box { key = \"pri\"; label = \"Order (1 to 999, lowest wins):\"; edit_width = 5; edit_limit = 3; }"
      "        : popup_list { key = \"typ\"; label = \"Type:\"; edit_width = 36; }"
      "        : list_box { key = \"lay\"; label = \"Layers:\"; width = 56; height = 5; }"
      "        : row {"
      "          : edit_box { key = \"lyi\"; edit_width = 24; edit_limit = 255; }"
      "          : button { key = \"lya\"; label = \"Add\"; }"
      "          : button { key = \"lyr\"; label = \"Replace\"; }"
      "          : button { key = \"lyd\"; label = \"Remove\"; }"
      "        }"
      "        : popup_list { key = \"prd\"; label = \"Product:\"; edit_width = 36; }"
      "        : popup_list { key = \"obj\"; label = \"Objects:\"; edit_width = 36; }"
      "        : text { key = \"obn\"; width = 56; }"
      "      }"
      "      : boxed_column { label = \"Content\";"
      "        : text { key = \"cnh\"; width = 56; }"
      "        : edit_box { key = \"cfl\"; label = \"Search:\"; edit_width = 44; edit_limit = 128; }"
      "        : list_box { key = \"cnd\"; width = 56; height = 2; fixed_height = true; tabs = \"44\"; is_enabled = false; }"
      "        : list_box { key = \"cnt\"; width = 56; height = 8; tabs = \"44\"; multiple_select = true; }"
      "        : row { fixed_width = true;"
      "          : button { key = \"czm\"; label = \"Select and zoom\"; }"
      "        }"
      "      }"
      "    }"
      "  }"
      "  : toggle { key = \"aut\"; label = \"Auto draw order (objects created by a command are put in their level when it ends, in every drawing)\"; }"
      "  : row {"
      "    : button { key = \"app\"; label = \"Apply to drawing\"; fixed_width = true; }"
      "    : text { key = \"msg\"; width = 100; }"
      "  }"
      "  : row { fixed_width = true; alignment = right;"
      "    : button { key = \"accept\"; label = \"OK\"; is_default = true; width = 12; fixed_width = true; }"
      "    : button { key = \"cancel\"; label = \"Cancel\"; is_cancel = true; width = 12; fixed_width = true; }"
      "    : button { key = \"docs\"; label = \"Open Docs\"; width = 12; fixed_width = true; }"
      "  }"
      "  errtile;"
      "}"
      "dyl_ldo_ask : dialog { label = \"DynALisp - Draw Order\";"
      "  : text { key = \"msg\"; width = 72; }"
      "  : text { label = \"The changes made to the draw order rules are not saved yet.\"; }"
      "  : row { fixed_width = true; alignment = centered;"
      "    : button { key = \"sav\"; label = \"Save and close\"; is_default = true; }"
      "    : button { key = \"dis\"; label = \"Close without saving\"; }"
      "    : button { key = \"cancel\"; label = \"Cancel\"; is_cancel = true; }"
      "  }"
      "}"
      "dyl_ldo_name : dialog { key = \"ttl\";"
      "  : edit_box { key = \"nam\"; label = \"Preset name:\"; edit_width = 40; edit_limit = 64; allow_accept = true; }"
      "  ok_cancel;"
      "  errtile;"
      "}"
     )
    (write-line line file)
  )
  (close file)
  path
)

;;  The functions below run inside c:Dyl-DrawOrder and use its local variables:
;;  ldo:sets (every preset being edited: ((name . rows) ...)), ldo:pst (index of the
;;  selected preset), ldo:old (names of the presets when the dialog opened),
;;  ldo:lst (rows of the selected preset, in the file order), ldo:idx (index of the row shown),
;;  ldo:sel (indexes of the rules selected, ldo:idx included: several can be selected, see
;;  ldo:sel-of),
;;  ldo:cnt (result of ldo:counts for the rows ldo:cntof), ldo:objs (items of the obj popup),
;;  ldo:layi (selected line of the Layers list), ldo:sort (sort of the rule list, index in
;;  *ldo:sorts*), ldo:viewl (index in ldo:lst of the rule on each line of the list),
;;  ldo:oth (T when the line of the other objects is selected instead of a rule),
;;  ldo:cntkey / ldo:cntres / ldo:cntents (state, result and objects of the last
;;  ldo:dlgcontent), ldo:sets0 (the presets when the dialog opened, to find unsaved
;;  changes), ldo:pref / ldo:dwg (the preferred preset and the preset of the drawing, nil:
;;  it uses the preferred one, as chosen in the dialog; ldo:pref0 / ldo:dwg0 when it
;;  opened), ldo:active (the active preset: ldo:dwg, else ldo:pref),
;;  ldo:zoom (objects to select once the dialog is closed, see ldo:dlgzoom),
;;  ldo:cntfilter (search text of the Content section), ldo:cntview (its lines shown),
;;  ldo:prd (product shown in the Product popup, index in ldo:products), ldo:dwgtypes
;;  (object types of the drawing, see ldo:dwgitems),
;;  ldo:regen (T when the drawing could not be regenerated while the dialog was open).

;;  Row of the selected rule, nil when the line of the other objects is selected:
(defun ldo:rule ()
  (if (not ldo:oth) (nth ldo:idx ldo:lst))
)

;;  Several rules can be selected in the list (Ctrl / Shift click) and edited at once (see
;;  CONVENTIONS.md, Windows): the fields show the rule ldo:idx; Description, Level, Order and
;;  Type changed are given to every rule selected (see ldo:put); the name, the Layers and
;;  Objects lists (edited line by line), Copy and Move up / down are for one rule only;
;;  Delete removes them all. The line of the other objects is selected alone.

;;  Indexes of the rules selected, the one shown (ldo:idx) included (nil: the line of the
;;  other objects is selected):
(defun ldo:sel-of ()
  (cond
    (ldo:oth nil)
    ((member ldo:idx ldo:sel) ldo:sel)
    ((list ldo:idx))
  )
)

;;  Give the value val to the cell i of every rule selected (ldo:one T, see ldo:dlgcommit:
;;  to the rule shown only):
(defun ldo:put (i val)
  (foreach j (if ldo:one (list ldo:idx) (ldo:sel-of))
    (setq ldo:lst (Remote>>Dyl:ListSubst ldo:lst j (Remote>>Dyl:ListSubst (nth j ldo:lst) i val)))
  )
)

;;  Select the lines of the rules selected, or of the other objects, in the rule list:
(defun ldo:dlgsel (/ l)
  (setq l (vl-remove nil (mapcar '(lambda (i) (vl-position i ldo:viewl)) (ldo:sel-of))))
  (cond
    (ldo:oth (set_tile "lst" (itoa (vl-position -1 ldo:viewl))))
    (l (set_tile "lst" (Remote>>LM:lst->str (mapcar 'itoa (vl-sort l '<)) " ")))
    ((set_tile "lst" ""))
  )
)

;;-------------------------=={ Content }==------------------------;;

;;  Object types and layers of the objects of the selection set ss for which test returns T
;;  (nil: every object): (count (type layer count) ...), one line per object type and layer,
;;  sorted by type then layer. The objects counted are kept in ldo:cntents:
;;  (((type . layer) . ename) ...), to select them from the Content section:
(defun ldo:tally (ss test / i e ed key p prs)
  (setq ldo:cntents nil)
  (if ss
    (repeat (setq i (sslength ss))
      (setq ed (entget (setq e (ssname ss (setq i (1- i))))))
      (if (or (not test) (apply test (list ed)))
        (setq key         (cons (cdr (assoc 0 ed)) (cdr (assoc 8 ed)))
              prs         (if (setq p (assoc key prs)) (subst (cons key (1+ (cdr p))) p prs) (cons (cons key 1) prs))
              ldo:cntents (cons (cons key e) ldo:cntents)
        )
      )
    )
  )
  (cons (apply '+ (mapcar 'cdr prs))
        (mapcar '(lambda (p) (list (caar p) (cdar p) (cdr p)))
                (vl-sort prs
                         '(lambda (a b)
                            (if (= (caar a) (caar b))
                              (< (strcase (cdar a)) (strcase (cdar b)))
                              (< (caar a) (caar b))
                            )
                          )
                )
        )
  )
)

;;  Text of a line of the Content section ("MTEXT / A-Anno-Text"), l being (type layer count):
(defun ldo:cntname (l)
  (strcat (car l) " / " (cadr l))
)

;;  T when the line l of the Content section matches the search text (any part of the line,
;;  * and ? wildcards allowed; an empty search matches every line):
(defun ldo:cntmatch (l / res)
  (or (= "" ldo:cntfilter)
      (and (not (vl-catch-all-error-p
                  (setq res (vl-catch-all-apply 'wcmatch
                                                (list (strcase (ldo:cntname l)) (strcat "*" (strcase ldo:cntfilter) "*"))
                            )
                  )
                )
           )
           res
      )
  )
)

;;  Fill the Content section with the layers and object types of the drawing that the
;;  selected rule gives its level to, or of the other objects (no rule matches them).
;;  Counted again only when the rules or the selected line changed:
(defun ldo:dlgcontent (/ key rules rule f)
  (setq key (list ldo:lst ldo:oth ldo:idx))
  (if (not (equal key ldo:cntkey))
    (setq rules       (Remote>>Dyl:DrawOrderParse ldo:lst)
          ldo:cntkey  key
          ldo:cntents nil
          ldo:cntres  (cond
                       (ldo:oth
                        ;;  The objects that none of the rules matches, viewports left out:
                        (setq f (Remote>>Dyl:DrawOrderFilter "*" rules))
                        (cons "Other objects (level 0, no rule matches them)"
                              (ldo:tally (ssget "_X"
                                                (if rules
                                                  (append '((-4 . "<NOT") (0 . "VIEWPORT") (-4 . "NOT>") (-4 . "<NOT"))
                                                          (member '(-4 . "<OR") f)
                                                          '((-4 . "NOT>"))
                                                  )
                                                  '((-4 . "<NOT") (0 . "VIEWPORT") (-4 . "NOT>"))
                                                )
                                         )
                                         nil
                              )
                        )
                       )
                       ((setq rule (nth ldo:idx rules))
                        ;;  The objects the rule matches that take their level from it (no
                        ;;  rule with a lower order matches them):
                        (cons (strcat (car rule) " (level " (itoa (cadr rule)) ")")
                              (ldo:tally (ssget "_X" (Remote>>Dyl:DrawOrderFilter "*" (list rule)))
                                         '(lambda (ed)
                                            (= ldo:idx
                                               (vl-position (Remote>>Dyl:DrawOrderRule (strcase (cdr (assoc 8 ed))) (cdr (assoc 0 ed)) rules)
                                                            rules
                                               )
                                            )
                                          )
                              )
                        )
                       )
                     )
    )
  )
  ;;  ldo:cntview: the lines shown, those matching the search text:
  (setq ldo:cntview (vl-remove-if-not 'ldo:cntmatch (cddr ldo:cntres)))
  (set_tile "cnh"
            (if ldo:cntres
              (strcat (car ldo:cntres)
                      ": "
                      (itoa (cadr ldo:cntres))
                      " object(s)"
                      (if (/= "" ldo:cntfilter)
                        (strcat ", " (itoa (length ldo:cntview)) " of " (itoa (length (cddr ldo:cntres))) " lines shown")
                        ""
                      )
              )
              ""
            )
  )
  (start_list "cnt")
  (foreach l ldo:cntview
    (add_list (strcat (ldo:cntname l) "\t" (itoa (caddr l))))
  )
  (end_list)
)

;;  Select and zoom: the dialog closes to select the objects of the lines selected in the
;;  Content section and zoom on them (ldo:zoom: the objects, see ldo:zoomto). Unsaved
;;  changes are asked about first: saved (dialog status 4), discarded (5) or the dialog
;;  kept open:
(defun ldo:dlgzoom (/ sel keys ans)
  (setq sel  (mapcar '(lambda (i) (nth i ldo:cntview)) (read (strcat "(" (get_tile "cnt") ")")))
        keys (mapcar '(lambda (l) (cons (car l) (cadr l))) sel)
  )
  (cond
    ((not sel) (set_tile "error" "Select one or more lines of the Content list first."))
    ((ldo:dlgcommit)
     (ldo:dlgstore)
     (setq ans (if (and (equal ldo:sets ldo:sets0) (not (ldo:usechanged)))
                 5
                 (ldo:dlgask (strcat "The window closes to select "
                                     (itoa (apply '+ (mapcar 'caddr sel)))
                                     " object(s) and zoom on them."
                             )
                 )
               )
     )
     (if (member ans '(4 5))
       (progn
         (setq ldo:zoom (mapcar 'cdr (vl-remove-if-not '(lambda (p) (member (car p) keys)) ldo:cntents)))
         (done_dialog ans)
       )
     )
    )
  )
)

;;  Ask what to do with the unsaved changes before the dialog closes (msg: why it closes).
;;  Returns 4 to save them, 5 to discard them, nil to keep the dialog open:
(defun ldo:dlgask (msg / sta)
  (if (new_dialog "dyl_ldo_ask" dcl:id)
    (progn
      (set_tile "msg" msg)
      (action_tile "sav" "(done_dialog 4)")
      (action_tile "dis" "(done_dialog 5)")
      (setq sta (start_dialog))
      (if (member sta '(4 5)) sta)
    )
  )
)

;;  Select the objects of the list of enames lst and zoom on them, in the current space
;;  when it has some of them, else in the layout that has the most (made current):
(defun ldo:zoomto (lst / doc prs tabs tab best ss)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  ;;  prs: ((layout . ename) ...) of the objects not erased since, tabs: ((layout . count) ...):
  (foreach e lst
    (if (entget e)
      (setq tab  (cdr (assoc 410 (entget e)))
            prs  (cons (cons tab e) prs)
            tabs (if (assoc tab tabs)
                   (subst (cons tab (1+ (cdr (assoc tab tabs)))) (assoc tab tabs) tabs)
                   (cons (cons tab 1) tabs)
                 )
      )
    )
  )
  (if tabs
    (progn
      (setq best (car tabs))
      (foreach p tabs (if (> (cdr p) (cdr best)) (setq best p)))
      (setq tab (if (assoc (getvar "CTAB") tabs) (getvar "CTAB") (car best))
            ss  (ssadd)
      )
      (if (/= tab (getvar "CTAB")) (setvar "CTAB" tab))
      (if (and (/= "Model" tab) (= :vlax-true (vla-get-MSpace doc))) (vla-put-MSpace doc :vlax-false))
      (foreach p prs (if (= tab (car p)) (ssadd (cdr p) ss)))
      (command "_.ZOOM" "_Object" ss "")
      (sssetfirst nil ss)
      (princ (strcat "\n"
                     (itoa (sslength ss))
                     " object(s) selected in "
                     tab
                     "."
                     (if (< (sslength ss) (length prs))
                       (strcat " " (itoa (- (length prs) (sslength ss))) " more in other layouts.")
                       ""
                     )
             )
      )
    )
    (princ "\nNo object to select (erased since?).")
  )
)

;;  T when the rule a comes before the rule b in the list sorted by ldo:sort (index in
;;  *ldo:sorts*), a and b being (index . row). Level: highest first; Order: lowest first
;;  (the rule that wins first); Type: in the order of *ldo:types*, then by level; Name:
;;  alphabetical. Ties keep the file order:
(defun ldo:before (a b / ra rb la lb pa pb)
  (setq ra (cdr a)
        rb (cdr b)
        la (atoi (cadr ra))
        lb (atoi (cadr rb))
        pa (atoi (nth 5 ra))
        pb (atoi (nth 5 rb))
  )
  (cond
    ((and (= 1 ldo:sort) (/= pa pb)) (< pa pb))
    ((and (= 2 ldo:sort) (/= (ldo:type ra) (ldo:type rb))) (< (ldo:type ra) (ldo:type rb)))
    ((and (= 3 ldo:sort) (/= (strcase (car ra)) (strcase (car rb)))) (< (strcase (car ra)) (strcase (car rb))))
    ((and (member ldo:sort '(0 2)) (/= la lb)) (> la lb))
    ((< (car a) (car b)))
  )
)

;;  Indexes of the rules in the order they are listed, -1 standing for the line of the
;;  other objects (level 0, no rule matches them): between the positive levels and the
;;  others when sorted by level, at the end otherwise:
(defun ldo:view (/ n prs lst)
  (setq n   -1
        prs (mapcar '(lambda (r) (cons (setq n (1+ n)) r)) ldo:lst)
        lst (mapcar 'car (vl-sort prs 'ldo:before))
  )
  (if (= 0 ldo:sort)
    (append (vl-remove-if-not '(lambda (i) (< 0 (atoi (cadr (nth i ldo:lst))))) lst)
            '(-1)
            (vl-remove-if '(lambda (i) (< 0 (atoi (cadr (nth i ldo:lst))))) lst)
    )
    (append lst '(-1))
  )
)

;;  Fill the rule list, sorted by ldo:sort (ldo:viewl: index of the rule on each line),
;;  with the objects of the drawing each rule gives its level to (counted again only when
;;  the rules changed). The line of the other objects is always shown, in capitals between
;;  markers so it stands out (a list box cannot color a line):
(defun ldo:dlglist (/ r)
  (if (not (equal ldo:lst ldo:cntof))
    (setq ldo:cnt   (ldo:counts (Remote>>Dyl:DrawOrderParse ldo:lst))
          ldo:cntof ldo:lst
    )
  )
  (setq ldo:viewl (ldo:view))
  (start_list "lst")
  (foreach i ldo:viewl
    (if (= -1 i)
      (add_list (strcat "-\t0\t----------------\t=== OTHER OBJECTS ===\t"
                        (itoa (cdr ldo:cnt))
                        " object(s)\t=== NO RULE MATCHES THEM ==="
                )
      )
      (progn
        (setq r (nth i ldo:lst))
        (add_list (strcat (nth 5 r)
                          "\t"
                          (cadr r)
                          "\t"
                          (nth (ldo:type r) *ldo:types*)
                          "\t"
                          (car r)
                          "\t"
                          (itoa (nth i (car ldo:cnt)))
                          " object(s)\t"
                          (nth 4 r)
                  )
        )
      )
    )
  )
  (end_list)
  (ldo:dlgsel)
  (ldo:dlgmoves)
  (ldo:dlgcontent)
)

;;-------------------------=={ Move up / down }==------------------------;;

;;  Line next to the line p of the rule list (dir -1: above, 1: below): the index of its rule
;;  in ldo:lst, -1 for the line of the other objects (a neighbour sorted by level only, at
;;  level 0). nil when there is none:
(defun ldo:neighbor (p dir / nb)
  (if
    (and (<= 0 (+ p dir))
         (setq nb (nth (+ p dir) ldo:viewl))
         (or (/= -1 nb) (= 0 ldo:sort))
    )
    nb
  )
)

;;  Enable the move buttons when the selected rule can move that way, in the Level and Order
;;  sorts only:
(defun ldo:dlgmoves (/ p)
  (setq p (if (and (ldo:rule) (not (cdr (ldo:sel-of))) (member ldo:sort '(0 1))) (vl-position ldo:idx ldo:viewl)))
  (mode_tile "mup" (if (and p (ldo:neighbor p -1)) 0 1))
  (mode_tile "mdn" (if (and p (ldo:neighbor p 1)) 0 1))
)

;;  Store the whole number val in the cell i of the rule j:
(defun ldo:setcell (j i val)
  (setq ldo:lst (Remote>>Dyl:ListSubst ldo:lst j (Remote>>Dyl:ListSubst (nth j ldo:lst) i (itoa val))))
)

;;  Move the selected rule past its neighbour nb (see ldo:neighbor) by the cell i (1: Level,
;;  5: Order), step being the change that moves it that way (+1 / -1), kept from lo to hi:
;;    - the two rules trade their values;
;;    - when they are equal, the selected rule's value changes by step (the neighbour's by
;;      -step when the selected one is at the limit);
;;    - past the line of the other objects (level 0): the level goes to 1 moving up, 0
;;      moving down.
(defun ldo:trade (i nb step lo hi / a b)
  (setq a (atoi (nth i (nth ldo:idx ldo:lst))))
  (cond
    ((= -1 nb) (ldo:setcell ldo:idx i (if (< 0 step) 1 0)))
    ((/= a (setq b (atoi (nth i (nth nb ldo:lst)))))
     (ldo:setcell ldo:idx i b)
     (ldo:setcell nb i a)
    )
    ((<= lo (+ a step) hi) (ldo:setcell ldo:idx i (+ a step)))
    ((<= lo (- b step) hi) (ldo:setcell nb i (- b step)))
  )
)

;;  Move up (dir -1) or down (dir 1) the selected rule in the list: sorted by Level, it trades
;;  its level with the rule shown next to it (up: a higher level); sorted by Order, its order
;;  (up: a lower order, the rule wins first). The rule being edited must be valid first:
(defun ldo:dlgmove (dir / p nb)
  (if
    (and (ldo:rule)
         (ldo:dlgcommit)
         (setq p (vl-position ldo:idx ldo:viewl))
         (setq nb (ldo:neighbor p dir))
    )
    (progn
      (if (= 0 ldo:sort)
        (ldo:trade 1 nb (- dir) -99 99)
        (ldo:trade 5 nb dir 1 999)
      )
      (ldo:dlgshow)
    )
  )
)

;;  Show the values of the selected rule and the state of the buttons. The Rule section is
;;  disabled while the line of the other objects is selected:
(defun ldo:dlgshow (/ r)
  (setq r (ldo:rule))
  (foreach x *ldo:tiles* (set_tile (car x) (if r (nth (cdr x) r) "")))
  (foreach k '("lvl" "ord" "pri" "typ" "dsc" "cpy" "del") (mode_tile k (if r 0 1)))
  ;;  Several rules selected: their number in the heading, the name and Copy greyed out:
  (set_tile "rbx" (if (cdr (ldo:sel-of)) (strcat "Rule (" (itoa (length (ldo:sel-of))) " selected)") "Rule"))
  (if (cdr (ldo:sel-of)) (foreach k '("lvl" "cpy") (mode_tile k 1)))
  (set_tile "error" "")
  (set_tile "lyi" "")
  (setq ldo:layi 0)
  (if r (setq ldo:prd (ldo:prdof (nth 3 r))))
  (ldo:dlgmodes)
  (ldo:dlglist)
)

;;-------------------------=={ Objects list }==------------------------;;

;;  Names of the Product popup: the products of *ldo:catalog*, then "In this drawing":
(defun ldo:products ()
  (append (mapcar 'car *ldo:catalog*) '("In this drawing"))
)

;;  Object types of the drawing, one item each (TYPE . TYPE), sorted. The drawing is read
;;  once per dialog (ldo:dwgtypes: (T type ...)). Viewports and the objects whose stacking
;;  does not show in a 2D view (cameras, lights, section planes, construction lines,
;;  points...) are left out:
(defun ldo:dwgitems (/ ss i typ lst)
  (if (not ldo:dwgtypes)
    (progn
      (if (setq ss (ssget "_X" '((-4 . "<NOT") (0 . "VIEWPORT") (-4 . "NOT>"))))
        (repeat (setq i (sslength ss))
          (if
            (not (or (member (setq typ (cdr (assoc 0 (entget (ssname ss (setq i (1- i))))))) lst)
                     (wcmatch typ "CAMERA,LIGHT,SECTION,GEOPOSITIONMARKER,HELIX,XLINE,RAY,POINT")
                 )
            )
            (setq lst (cons typ lst))
          )
        )
      )
      (setq ldo:dwgtypes (cons t (acad_strlsort lst)))
    )
  )
  (mapcar '(lambda (s) (cons s s)) (cdr ldo:dwgtypes))
)

;;  Items of the product p (index in ldo:products): ((label . wildcard) ...):
(defun ldo:prditems (p)
  (if (< p (length *ldo:catalog*)) (cdr (nth p *ldo:catalog*)) (ldo:dwgitems))
)

;;  Product of an Objects cell: the first one that has it, "In this drawing" when it is an
;;  object type of the drawing only, else the product shown (it is then a custom value):
(defun ldo:prdof (val / v n)
  (setq v (strcase val)
        n -1
  )
  (cond
    ((= "" v) (cond (ldo:prd) (0)))
    ((vl-some '(lambda (c) (setq n (1+ n)) (if (member v (mapcar 'cdr (cdr c))) n)) *ldo:catalog*))
    ((member v (mapcar 'cdr (ldo:dwgitems))) (length *ldo:catalog*))
    ((cond (ldo:prd) (0)))
  )
)

;;  Items of the obj popup for an Objects cell, in the product p: the items of the product,
;;  after the cell itself as "Custom: ..." when it is none of them (a rule written by hand
;;  in a preset file, or of another product), so that the popup always shows the cell:
(defun ldo:objitems (p val / lst)
  (setq lst (ldo:prditems p))
  (if (or (= "" val) (member (strcase val) (mapcar 'cdr lst)))
    lst
    (cons (cons (strcat "Custom: " val) (strcase val)) lst)
  )
)

;;  Show the type of the selected rule, only the Layers and Objects fields it uses enabled.
;;  The Product and Objects popups list the objects only when they are used (ldo:objs:
;;  the items of the obj popup, ldo:prd: the product shown):
(defun ldo:dlgmodes (/ r i)
  (setq r        (ldo:rule)
        i        (if r (ldo:type r) 3)
        ldo:objs (if (member i '(1 2)) (ldo:objitems ldo:prd (nth 3 r)))
  )
  (start_list "obj")
  (foreach o ldo:objs (add_list (car o)))
  (end_list)
  (if ldo:objs
    (progn
      (set_tile "prd" (itoa ldo:prd))
      (set_tile "obj" (itoa (cond ((vl-position (strcase (nth 3 r)) (mapcar 'cdr ldo:objs))) (0))))
    )
  )
  (if r (set_tile "typ" (itoa i)))
  (ldo:dlgobjname)
  (ldo:dlglays)
  ;;  The Layers and Objects lists for one rule only:
  (foreach k '("lay" "lyi" "lya" "lyr" "lyd") (mode_tile k (if (and (member i '(0 2)) (not (cdr (ldo:sel-of)))) 0 1)))
  (mode_tile "prd" (if (and ldo:objs (not (cdr (ldo:sel-of)))) 0 1))
  (mode_tile "obj" (if (and ldo:objs (not (cdr (ldo:sel-of)))) 0 1))
)

;;  Show the objects of another product (index in ldo:products) in the obj popup, the
;;  Objects cell kept until an item of the popup is picked:
(defun ldo:dlgprd (p)
  (setq ldo:prd p)
  (ldo:dlgmodes)
)

;;-------------------------=={ Layers list }==------------------------;;

;;  The Layers cell is a comma separated list of wildcards ("*-Anno,*-Anno-*"): the dialog
;;  shows one per line and the commas are only added when it is stored. ldo:layi is the
;;  index of the selected line.

;;  Wildcards of a string, cut at the commas, trimmed, empty ones left out:
(defun ldo:split (str)
  (vl-remove "" (mapcar '(lambda (s) (vl-string-trim " \t" s)) (Remote>>LM:str->lst str ",")))
)

;;  Wildcards of the selected rule (nil when it does not match layers):
(defun ldo:lays ()
  (if (ldo:rule) (ldo:split (nth 2 (ldo:rule))))
)

;;  Fill the Layers list with the wildcards of the selected rule:
(defun ldo:dlglays (/ lst)
  (setq lst     (ldo:lays)
        ldo:layi (max 0 (min ldo:layi (1- (length lst))))
  )
  (start_list "lay")
  (foreach s lst (add_list s))
  (end_list)
  (if lst (set_tile "lay" (itoa ldo:layi)))
)

;;  Store the wildcards lst in the selected rule, selecting the line i:
(defun ldo:dlgsetlays (lst i)
  (setq ldo:lst  (Remote>>Dyl:ListSubst ldo:lst
                                        ldo:idx
                                        (Remote>>Dyl:ListSubst (nth ldo:idx ldo:lst) 2 (cond ((Remote>>LM:lst->str lst ",")) ("")))
                 )
        ldo:layi i
  )
  (set_tile "lyi" "")
  (set_tile "error" "")
  (ldo:dlglays)
  (ldo:dlglist)
)

;;  Show an error about the Layers list and select the input box, returns nil:
(defun ldo:dlglayerr (msg)
  (set_tile "error" msg)
  (mode_tile "lyi" 2)
  nil
)

;;  Wildcards typed in the input box that are not in the list yet (commas typed split them):
(defun ldo:dlglaynew (lst)
  (vl-remove-if '(lambda (s) (member (strcase s) (mapcar 'strcase lst))) (ldo:split (get_tile "lyi")))
)

;;  Add the wildcards typed in the input box at the end of the list:
(defun ldo:dlglayadd (/ lst new)
  (setq lst (ldo:lays))
  (cond
    ((= "" (vl-string-trim " \t," (get_tile "lyi"))) (ldo:dlglayerr "Type a layer name or wildcard to add (*-Anno-*)."))
    ((not (setq new (ldo:dlglaynew lst))) (ldo:dlglayerr "This layer wildcard is already in the list."))
    ((ldo:dlgsetlays (append lst new) (length lst)))
  )
)

;;  Replace the selected line with the wildcards typed in the input box:
(defun ldo:dlglayreplace (/ lst new n)
  (setq lst (ldo:lays)
        n   -1
  )
  (cond
    ((= "" (vl-string-trim " \t," (get_tile "lyi")))
     (ldo:dlglayerr "Type the layer name or wildcard that replaces the selected line.")
    )
    ((not (setq new (ldo:dlglaynew (Remote>>Dyl:ListRemove lst ldo:layi))))
     (ldo:dlglayerr "This layer wildcard is already in the list.")
    )
    ((ldo:dlgsetlays (apply 'append (mapcar '(lambda (s) (if (= ldo:layi (setq n (1+ n))) new (list s))) lst))
                     ldo:layi
     )
    )
  )
)

;;  Remove the selected line (the last one cannot be removed: change the Type instead):
(defun ldo:dlglayremove (/ lst)
  (setq lst (ldo:lays))
  (if (cdr lst)
    (ldo:dlgsetlays (Remote>>Dyl:ListRemove lst ldo:layi) ldo:layi)
    (ldo:dlglayerr "A rule matching layers needs at least one layer: change its Type to match objects only.")
  )
)

;;  Select a line: its wildcard goes to the input box to be replaced:
(defun ldo:dlglaypick (val)
  (setq ldo:layi (atoi val))
  (set_tile "lyi" (cond ((nth ldo:layi (ldo:lays))) ("")))
)

;;  Change the type of the rules selected (index in *ldo:types*): the field a rule does not
;;  use is cleared, the one it needs gets a value to replace when it is empty (placeholder
;;  layers, first item of the Objects list):
(defun ldo:dlgtype (i / r lay obj q)
  (if (ldo:dlgcommit)
    (progn
      (setq r (nth ldo:idx ldo:lst))
      (foreach j (ldo:sel-of)
        (setq q   (nth j ldo:lst)
              lay (cond ((not (member i '(0 2))) "") ((/= "" (nth 2 q)) (nth 2 q)) ("*-Name,*-Name-*"))
              obj (cond ((not (member i '(1 2))) "") ((/= "" (nth 3 q)) (nth 3 q)) ((cdr (cadr (car *ldo:catalog*)))))
        )
        (setq ldo:lst (Remote>>Dyl:ListSubst ldo:lst j (list (car q) (cadr q) lay obj (nth 4 q) (nth 5 q))))
      )
      (setq lay     (nth 2 (nth ldo:idx ldo:lst))
            obj     (nth 3 (nth ldo:idx ldo:lst))
            ldo:prd (ldo:prdof obj)
      )
      (ldo:dlgmodes)
      (ldo:dlglist)
      (cond
        ((and (/= "" lay) (= "" (nth 2 r))) (mode_tile "lyi" 2))
        ((and (/= "" obj) (= "" (nth 3 r))) (mode_tile "obj" 2))
      )
    )
    (ldo:dlgmodes)
  )
)

;;  Show under the obj popup the AutoCAD names (DXF object types) of the Objects cell of the
;;  selected rule, empty when the rule does not match objects:
(defun ldo:dlgobjname (/ lst)
  (setq lst (if ldo:objs (ldo:split (nth 3 (ldo:rule)))))
  (set_tile "obn"
            (cond
              ((cdr lst) (strcat "AutoCAD names: " (Remote>>LM:lst->str lst ", ")))
              (lst (strcat "AutoCAD name: " (car lst)))
              ("")
            )
  )
)

;;  Objects picked in the obj popup (index in ldo:objs). The separator cannot be picked:
;;  the popup goes back to the objects of the rule:
(defun ldo:dlgobj (i / r)
  (setq r (nth ldo:idx ldo:lst))
  (if (cdr (nth i ldo:objs))
    (progn
      (setq ldo:lst (Remote>>Dyl:ListSubst ldo:lst ldo:idx (Remote>>Dyl:ListSubst r 3 (cdr (nth i ldo:objs)))))
      (ldo:dlgobjname)
      (ldo:dlglist)
    )
    (set_tile "obj" (itoa (cond ((vl-position (strcase (nth 3 r)) (mapcar 'cdr ldo:objs))) (0))))
  )
)

;;  Validate the value of a tile and store it in the selected rule, returns T when valid:
(defun ldo:dlgfield (key val / msg)
  (setq val (vl-string-trim " \t" val))
  (if (member key '("ord" "pri")) (setq val (vl-string-left-trim "+" val)))
  (setq msg (cond
              ((and (= "lvl" key) (= "" val)) "The name cannot be empty.")
              ((and (= "ord" key) (not (wcmatch val "#,##,-#,-##")))
               "The level must be a whole number from -99 to 99 (positive: above the other objects, negative: below)."
              )
              ((and (= "pri" key) (not (Remote>>Dyl:DrawOrderOrder-p val)))
               "The order must be a whole number from 1 to 999 (when several rules match an object, the lowest order wins)."
              )
            )
  )
  (if msg
    (progn
      (set_tile "error" msg)
      (mode_tile key 2)
      nil
    )
    (progn
      (if (member key '("ord" "pri")) (setq val (itoa (atoi val))))
      ;;  To every rule selected (the rule shown only for the name, and while committing):
      (if (= "lvl" key)
        (setq ldo:lst (Remote>>Dyl:ListSubst ldo:lst ldo:idx (Remote>>Dyl:ListSubst (nth ldo:idx ldo:lst) 0 val)))
        (ldo:put (cdr (assoc key *ldo:tiles*)) val)
      )
      (set_tile key val)
      (set_tile "error" "")
      t
    )
  )
)

;;  Store every tile in the rule shown, returns T when they are all valid. Only in the rule
;;  shown (ldo:one): a value changed was given to every rule selected by the action of its tile:
(defun ldo:dlgcommit (/ ok ldo:one)
  (setq ldo:one t
        ok      t
  )
  (if (ldo:rule)
    (foreach x *ldo:tiles*
      (if ok (setq ok (ldo:dlgfield (car x) (get_tile (car x)))))
    )
  )
  ok
)

;;  Select other lines ("3" or "0 3 5"; the rule being edited must be valid first). The rule
;;  shown stays when it is still selected, else the first one selected. The line of the
;;  other objects, picked alone, shows its content, the Rule section disabled (picked with
;;  rules, it is left out):
(defun ldo:dlgpick (val / l r)
  (setq l (vl-remove nil (mapcar '(lambda (n) (nth n ldo:viewl)) (read (strcat "(" (cond (val) ("")) ")"))))
        r (vl-remove -1 l)
  )
  (if (and l (ldo:dlgcommit))
    (progn
      (if r
        (setq ldo:oth nil
              ldo:sel r
              ldo:idx (if (member ldo:idx r) ldo:idx (car r))
        )
        (setq ldo:oth t)
      )
      (ldo:dlgshow)
    )
    (ldo:dlgsel)
  )
)

;;  Sort the rule list by *ldo:sorts* item i, the selected rule kept selected:
(defun ldo:dlgsort (i)
  (setq ldo:sort i)
  (ldo:dlgshow)
)

;;  Add a rule after the selected one and select its level name:
(defun ldo:dlgadd (row)
  (if (ldo:dlgcommit)
    (progn
      (setq ldo:idx (if ldo:lst (1+ ldo:idx) 0)
            ldo:lst (Remote>>Dyl:ListInsert ldo:lst ldo:idx row)
            ldo:sel (list ldo:idx)
            ldo:oth nil
      )
      (ldo:dlgshow)
      (mode_tile "lvl" 2)
      (mode_tile "lvl" 3)
    )
  )
)

;;  Delete the rules selected (Cancel brings them back):
(defun ldo:dlgdelete (/ sel i)
  (setq sel     (ldo:sel-of)
        i       -1
        ldo:lst (vl-remove-if '(lambda (r) (member (setq i (1+ i)) sel)) ldo:lst)
        ldo:idx (max 0 (min (apply 'min sel) (1- (length ldo:lst))))
        ldo:sel (list ldo:idx)
  )
  (ldo:dlgshow)
)

;;  Replace the rules with the default ones (Cancel brings them back):
(defun ldo:dlgrestore ()
  (setq ldo:lst (ldo:defaults)
        ldo:idx 0
        ldo:sel '(0)
        ldo:oth nil
  )
  (ldo:dlgshow)
)

;;  Restack the drawing with the rules being edited (OK saves them):
(defun ldo:dlgapply ()
  (if (ldo:dlgcommit)
    (set_tile "msg" (strcat (ldo:apply (Remote>>Dyl:DrawOrderParse ldo:lst)) " OK saves the rules."))
  )
)

;;-------------------------=={ Presets }==------------------------;;

;;  Keep the rules being edited in their preset:
(defun ldo:dlgstore ()
  (setq ldo:sets (Remote>>Dyl:ListSubst ldo:sets ldo:pst (cons (car (nth ldo:pst ldo:sets)) ldo:lst)))
)

;;  Index in ldo:sets of the preset named nam (nil: none):
(defun ldo:nameidx (nam)
  (if nam (vl-position (strcase nam) (mapcar '(lambda (s) (strcase (car s))) ldo:sets)))
)

;;  T when the preferred preset or the preset of the drawing was changed in the dialog:
(defun ldo:usechanged ()
  (not (and (= (strcase (cond (ldo:pref) (""))) (strcase (cond (ldo:pref0) (""))))
            (= (strcase (cond (ldo:dwg) (""))) (strcase (cond (ldo:dwg0) (""))))
       )
  )
)

;;  Fill the Preferred and This drawing popups (the first line of This drawing: use the
;;  preferred preset), and set the active preset from them:
(defun ldo:dlguse (/ names)
  (setq names      (mapcar 'car ldo:sets)
        ldo:active (cond (ldo:dwg) (ldo:pref))
  )
  (start_list "pdf")
  (mapcar 'add_list names)
  (end_list)
  (set_tile "pdf" (itoa (cond ((ldo:nameidx ldo:pref)) (0))))
  (start_list "pdw")
  (add_list (strcat "Preferred preset (" (cond (ldo:pref) ("none")) ")"))
  (mapcar 'add_list names)
  (end_list)
  (set_tile "pdw" (itoa (if (ldo:nameidx ldo:dwg) (1+ (ldo:nameidx ldo:dwg)) 0)))
)

;;  Preferred preset (i: index in ldo:sets) or preset of the drawing (i: index in the This
;;  drawing popup, 0 for the preferred one) picked:
(defun ldo:dlgpref (i)
  (setq ldo:pref (car (nth i ldo:sets)))
  (ldo:dlgpresets)
)
(defun ldo:dlgdwg (i)
  (setq ldo:dwg (if (< 0 i) (car (nth (1- i) ldo:sets))))
  (ldo:dlgpresets)
)

;;  Fill the preset popups, the active preset marked in the Edit one (the last preset
;;  cannot be deleted):
(defun ldo:dlgpresets ()
  (ldo:dlguse)
  (start_list "pst")
  (foreach s ldo:sets
    (add_list (strcat (car s) (if (= (strcase (car s)) (strcase (cond (ldo:active) ("")))) "   (active)" "")))
  )
  (end_list)
  (set_tile "pst" (itoa ldo:pst))
  (mode_tile "pdl" (if (cdr ldo:sets) 0 1))
)

;;  Show the preset i:
(defun ldo:dlgload (i)
  (setq ldo:pst i
        ldo:lst (cdr (nth i ldo:sets))
        ldo:idx 0
        ldo:sel '(0)
        ldo:oth nil
  )
  (ldo:dlgpresets)
  (ldo:dlgshow)
)

;;  Select another preset, the rules of the current one being kept until OK (the rule
;;  being edited must be valid first):
(defun ldo:dlgpreset (i)
  (if (ldo:dlgcommit)
    (progn
      (ldo:dlgstore)
      (ldo:dlgload i)
    )
    (set_tile "pst" (itoa ldo:pst))
  )
)

;;  nam, followed by " 2", " 3"... when a preset already has it:
(defun ldo:unique (nam / i new)
  (setq i   1
        new nam
  )
  (while (vl-some '(lambda (s) (= (strcase new) (strcase (car s)))) ldo:sets)
    (setq new (strcat nam " " (itoa (setq i (1+ i)))))
  )
  new
)

;;  Check a name typed in the name dialog, returns it trimmed, nil when it is not valid (the
;;  error is shown). skip: index of the preset being renamed (its own name is allowed):
(defun ldo:namecheck (nam skip / n msg)
  (setq nam (vl-string-trim " \t." nam)
        n   -1
        msg (cond
              ((= "" nam) "The preset name cannot be empty.")
              ((vl-some '(lambda (c) (vl-string-search c nam)) '("\\" "/" ":" "*" "?" "\"" "<" ">" "|"))
               "A preset name cannot contain \\ / : * ? \" < > |"
              )
              ((vl-some '(lambda (s) (and (/= skip (setq n (1+ n))) (= (strcase nam) (strcase (car s))))) ldo:sets)
               "Another preset already has this name."
              )
            )
  )
  (if msg
    (progn
      (set_tile "error" msg)
      (mode_tile "nam" 2)
      nil
    )
    nam
  )
)

;;  Ask a preset name in a sub-dialog (ttl: its title, nam: the name proposed, skip: see
;;  ldo:namecheck). Returns nil on Cancel:
(defun ldo:dlgname (ttl nam skip / res)
  (if (new_dialog "dyl_ldo_name" dcl:id)
    (progn
      (set_tile "ttl" ttl)
      (set_tile "nam" nam)
      (mode_tile "nam" 2)
      (action_tile "accept" "(if (setq res (ldo:namecheck (get_tile \"nam\") skip)) (done_dialog 1))")
      (if (= 1 (start_dialog)) res)
    )
  )
)

;;  New preset: a copy of the rules of the selected one, under a name asked:
(defun ldo:dlgpnew (/ nam)
  (if
    (and (ldo:dlgcommit)
         (setq nam (ldo:dlgname "New preset (copy of the selected one)"
                                (ldo:unique (strcat (car (nth ldo:pst ldo:sets)) " copy"))
                                nil
                   )
         )
    )
    (progn
      (ldo:dlgstore)
      (setq ldo:sets (append ldo:sets (list (cons nam ldo:lst))))
      (ldo:dlgload (1- (length ldo:sets)))
    )
  )
)

;;  Rename the selected preset:
(defun ldo:dlgprename (/ old nam)
  (setq old (car (nth ldo:pst ldo:sets)))
  (if (and (ldo:dlgcommit) (setq nam (ldo:dlgname "Rename preset" old ldo:pst)))
    (progn
      (if (= (strcase old) (strcase (cond (ldo:pref) ("")))) (setq ldo:pref nam))
      (if (= (strcase old) (strcase (cond (ldo:dwg) ("")))) (setq ldo:dwg nam))
      (setq ldo:sets (Remote>>Dyl:ListSubst ldo:sets ldo:pst (cons nam ldo:lst))
            ldo:ren  (cons (cons old nam) ldo:ren)
      )
      (ldo:dlgpresets)
    )
  )
)

;;  Delete the selected preset (Cancel brings it back, the last one cannot be deleted). The
;;  drawing using it uses the preferred preset, a preferred preset deleted becomes the
;;  first one left:
(defun ldo:dlgpdelete (/ nam)
  (if (cdr ldo:sets)
    (progn
      (setq nam      (strcase (car (nth ldo:pst ldo:sets)))
            ldo:sets (Remote>>Dyl:ListRemove ldo:sets ldo:pst)
      )
      (if (= nam (strcase (cond (ldo:dwg) ("")))) (setq ldo:dwg nil))
      (if (= nam (strcase (cond (ldo:pref) ("")))) (setq ldo:pref (car (car ldo:sets))))
      (ldo:dlgload (max 0 (1- ldo:pst)))
    )
  )
)

;;-------------------------=={ Commands }==------------------------;;

;; Draw Order
;; Edits the draw order levels of the Dynalisp layers (annotation on top, hatches at the bottom), chooses the preferred and drawing presets and restacks the drawing.

(defun c:Dyl-DrawOrder (/ dcl:pth dcl:id sta err ldo:sets ldo:pst ldo:old ldo:active ldo:lst ldo:idx ldo:sel ldo:cnt
                        ldo:cntof ldo:objs ldo:layi ldo:sort ldo:viewl ldo:oth ldo:cntkey ldo:cntres ldo:cntents
                        ldo:sets0 ldo:zoom ldo:cntview ldo:cntfilter ldo:prd ldo:dwgtypes ldo:regen ldo:ren
                        ldo:pref ldo:dwg ldo:pref0 ldo:dwg0
                       )
  (setq dcl:pth    (ldo:dcl)
        dcl:id     (load_dialog dcl:pth)
        ldo:sets   (ldo:presets)
        ldo:sets0  ldo:sets
        ldo:old    (Remote>>Dyl:DrawOrderPresets)
        ldo:pref   (Remote>>Dyl:DrawOrderPresetDefault)
        ldo:dwg    (Remote>>Dyl:DrawOrderPresetDwg)
        ldo:pref0  ldo:pref
        ldo:dwg0   ldo:dwg
        ldo:active (cond (ldo:dwg) (ldo:pref))
        ldo:pst    (cond
                     ((vl-position (strcase (cond (ldo:active) (""))) (mapcar '(lambda (s) (strcase (car s))) ldo:sets)))
                     (0)
                   )
        ldo:lst    (cdr (nth ldo:pst ldo:sets))
        ldo:idx    0
        ldo:sort   0
        ldo:cntfilter ""
        ldo:prd    0
  )
  (if (and (<= 0 dcl:id) (new_dialog "dyl_ldo" dcl:id))
    (progn
      (start_list "hdr")
      (add_list "Order\tLevel\tType\tName\tObjects in drawing\tDescription")
      (end_list)
      (start_list "cnd")
      (add_list "Object / Layer\tObjects")
      (end_list)
      (start_list "typ")
      (mapcar 'add_list *ldo:types*)
      (end_list)
      (start_list "srt")
      (mapcar 'add_list *ldo:sorts*)
      (end_list)
      (start_list "prd")
      (mapcar 'add_list (ldo:products))
      (end_list)
      (set_tile "srt" "0")
      (set_tile "aut" (if (Remote>>Dyl:DrawOrderAuto-p) "1" "0"))
      (ldo:dlgpresets)
      (ldo:dlgshow)
      (action_tile "pst" "(ldo:dlgpreset (atoi $value))")
      (action_tile "pnw" "(ldo:dlgpnew)")
      (action_tile "prn" "(ldo:dlgprename)")
      (action_tile "pdl" "(ldo:dlgpdelete)")
      (action_tile "pdf" "(ldo:dlgpref (atoi $value))")
      (action_tile "pdw" "(ldo:dlgdwg (atoi $value))")
      (foreach x *ldo:tiles*
        (action_tile (car x) "(if (ldo:dlgfield $key $value) (progn (ldo:dlgmodes) (ldo:dlglist)))")
      )
      (action_tile "typ" "(ldo:dlgtype (atoi $value))")
      (action_tile "prd" "(ldo:dlgprd (atoi $value))")
      (action_tile "obj" "(ldo:dlgobj (atoi $value))")
      (action_tile "lay" "(ldo:dlglaypick $value)")
      (action_tile "lya" "(ldo:dlglayadd)")
      (action_tile "lyr" "(ldo:dlglayreplace)")
      (action_tile "lyd" "(ldo:dlglayremove)")
      (action_tile "lst" "(ldo:dlgpick $value)")
      (action_tile "cfl" "(setq ldo:cntfilter (vl-string-trim \" \" $value)) (ldo:dlgcontent)")
      (action_tile "czm" "(ldo:dlgzoom)")
      (action_tile "srt" "(if (ldo:dlgcommit) (ldo:dlgsort (atoi $value)) (set_tile \"srt\" (itoa ldo:sort)))")
      (action_tile "new" "(ldo:dlgadd (list \"New rule\" \"1\" \"*-Name,*-Name-*\" \"\" \"\" (ldo:nextorder)))")
      (action_tile "mup" "(ldo:dlgmove -1)")
      (action_tile "mdn" "(ldo:dlgmove 1)")
      (action_tile "cpy" "(ldo:dlgadd (cons (strcat (car (nth ldo:idx ldo:lst)) \" copy\") (cdr (nth ldo:idx ldo:lst))))")
      (action_tile "del" "(ldo:dlgdelete)")
     (action_tile "def" "(ldo:dlgrestore)")
      (action_tile "aut" "(Remote>>Dyl:DrawOrderAutoSet (= \"1\" $value))")
      (action_tile "app" "(ldo:dlgapply)")
      (action_tile "accept" "(if (ldo:dlgcommit) (progn (ldo:dlgstore) (done_dialog 1)))")
      (Dyl:DocsTile "Layer\\Dyl-DrawOrder.htm")
      (setq sta (start_dialog))
    )
    (princ "\n--> Unable to load the Draw Order dialog.")
  )
  (if (<= 0 dcl:id) (unload_dialog dcl:id))
  (vl-file-delete dcl:pth)
  (if ldo:regen (vla-Regen (vla-get-ActiveDocument (vlax-get-acad-object)) acAllViewports))
  ;;  OK (1), or Save and close from a double-click in the Content section (4), saves every
  ;;  preset, then the preferred preset (user setting, every drawing) and the preset of
  ;;  the drawing (nil: it uses the preferred one) when they were changed:
  (if (member sta '(1 4))
    (progn
      (setq err (ldo:save ldo:sets ldo:old))
      (foreach r (reverse ldo:ren) (Remote>>Dyl:DrawOrderPresetRenamed (car r) (cdr r)))
      (if (/= (strcase (cond (ldo:pref) (""))) (strcase (cond (ldo:pref0) (""))))
        (Remote>>Dyl:DrawOrderPresetDefaultSet ldo:pref)
      )
      (if (/= (strcase (cond (ldo:dwg) (""))) (strcase (cond (ldo:dwg0) (""))))
        (Remote>>Dyl:DrawOrderPresetSet ldo:dwg)
      )
      (if err
        (alert (strcat "Error: these draw order presets could not be saved (is the file open in Excel?):\n"
                       (Remote>>LM:lst->str err "\n")
                       "\n\nFolder: "
                       (Remote>>Dyl:DrawOrderDir)
               )
        )
        (princ (strcat "\nDraw order presets saved. Active preset: "
                       (cond ((Remote>>Dyl:DrawOrderPreset)) ("none"))
                       (if (Remote>>Dyl:DrawOrderPresetDwg)
                         " (saved in this drawing)"
                         " (your preferred preset)"
                       )
                       ". DO-APPLY restacks the drawing with it."
               )
        )
      )
    )
  )
  ;;  Double-click in the Content section: select the objects of the line and zoom on them:
  (if (and ldo:zoom (member sta '(4 5))) (ldo:zoomto ldo:zoom))
  (princ)
)

;; Draw Order Apply
;; Restacks model space, every layout and every block definition by level with the active preset: annotation on top, hatches and backgrounds at the bottom.

(defun c:Pst-DrawOrderApply (/ ldo:regen)
  (princ (strcat "\n" (ldo:apply nil) " Preset: " (cond ((Remote>>Dyl:DrawOrderPreset)) ("default rules")) "."))
  (princ)
)

;; Draw Order Auto Toggle
;; Turns auto draw order on or off: the objects created by a command are put in their level when it ends.

(defun c:Pst-DrawOrderAutoToggle ()
  (Remote>>Dyl:DrawOrderAutoSet (not (Remote>>Dyl:DrawOrderAuto-p)))
  (princ)
)

;;  Draw order table of model space (ACAD_SORTENTS), nil when it has none:
(defun ldo:sortents (/ s)
  (if
    (not
      (vl-catch-all-error-p
        (setq s (vl-catch-all-apply 'vla-Item
                                    (list (vla-GetExtensionDictionary
                                            (vla-get-ModelSpace (vla-get-ActiveDocument (vlax-get-acad-object)))
                                          )
                                          "ACAD_SORTENTS"
                                    )
                )
        )
      )
    )
    s
  )
)

;; Draw Order Count
;; Counts the entries of the model space draw order table against the objects of model space.

(defun c:Pst-DrawOrderCount (/ s n)
  (if (setq s (ldo:sortents))
    (progn
      (setq n 0)
      (foreach p (entget (vlax-vla-object->ename s)) (if (= 331 (car p)) (setq n (1+ n))))
      (princ (strcat "\nDraw order entries: "
                     (itoa n)
                     " / objects in model space: "
                     (itoa (vla-get-Count (vla-get-ModelSpace (vla-get-ActiveDocument (vlax-get-acad-object)))))
             )
      )
    )
    (princ "\nNo draw order table in model space.")
  )
  (princ)
)

;; Draw Order Reset
;; Deletes the model space draw order table: the objects go back to their creation order (U undoes it).

(defun c:Pst-DrawOrderReset (/ doc s)
  (if (setq s (ldo:sortents))
    (progn
      (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
      (vla-StartUndoMark doc)
      (vla-Delete s)
      (vla-EndUndoMark doc)
      (vla-Regen doc acAllViewports)
      (princ "\nModel space draw order table deleted: the objects are in their creation order.")
    )
    (princ "\nNo draw order table in model space.")
  )
  (princ)
)

;; Draw Order Rebuild
;; Deletes the draw order tables of model space, the layouts and the block definitions, then restacks them by level from scratch to keep panning fast.

(defun c:Pst-DrawOrderRebuild (/ doc n)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (vla-StartUndoMark doc)
  (setq n (vl-catch-all-apply 'Remote>>Dyl:DrawOrderRebuild '(nil nil)))
  (setq *do:busy* nil)
  (vla-EndUndoMark doc)
  (if (vl-catch-all-error-p n)
    (princ (strcat "\n--> Draw order not rebuilt: " (vl-catch-all-error-message n)))
    (progn
      (vl-catch-all-apply 'vla-Regen (list doc acAllViewports))
      (princ (strcat "\nDraw order rebuilt: " (itoa n) " object(s) restacked from their creation order (U undoes it)."))
    )
  )
  (princ)
)

(princ)
