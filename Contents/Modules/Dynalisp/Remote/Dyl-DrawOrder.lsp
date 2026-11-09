;; Dyl-DrawOrder - Dynalisp draw order: objects stacked by layer level (annotation on top, hatches at the bottom)
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

;;  Loaded at startup with the other Remote files, before the Apps.
;;
;;  The draw order levels are presets: one CSV file each in Modules\Dynalisp\Res\DrawOrder
;;  (Default.csv...), named by the file. Saved presets go to the user copy of that folder
;;  (User\Modules\Dynalisp\Res\DrawOrder, see Dyl:UserDirW in dynalisp.mnl). The active preset is the one
;;  saved in the drawing (chosen in Dyl-DrawOrder), else the preferred preset of the
;;  user (DynalispDrawOrderPreset user setting chosen in the Draw Order window, Default when it is
;;  not set); *do:defaults* are used when there is no preset file. One rule per row:
;;    Name;Level;Layers;Objects;Description;Order
;;    Annotation;8;*-Anno,*-Anno-[~R]*;;Annotation layers;10
;;    Hatch objects;-4;;HATCH;Hatches on any layer;20
;;  A rule matches an object when its Layers (layer name wildcard) and Objects (DXF object
;;  type wildcard) both match it, an empty cell matching anything. An object takes the
;;  Level of the rule with the lowest Order (1 to 999) of the rules matching it (the first
;;  row of them on a tie), 0 when no rule matches it. A preset file without the Order
;;  column (written before it) gets one from its levels, the highest first, so that the
;;  highest level of the rules matching an object still wins (see Remote>>Dyl:DrawOrderFill).
;;  The positive levels are stacked above the objects at 0 (the highest on top), the
;;  negative levels below them (the lowest at the bottom).
;;
;;  While auto draw order is on (a user setting, off by default), the objects created by
;;  a command are put in their level when the command ends (only they are moved, see
;;  Remote>>Dyl:DrawOrderPlace), and the commands that change the layer of objects
;;  (LAYMCH, MATCHPROP...) restack the current space. Each restack adds entries to the draw
;;  order tables, which slow down panning and zooming once they grow: DO-REBUILD (and the
;;  output prep step DRAWORDERCLEAN) deletes them and stacks the levels again from scratch.
;;  The block definitions are restacked like the spaces: by DO-APPLY, and when objects are
;;  added to them (BLOCK, BEDIT, REFEDIT...). Not the xrefs, nor the anonymous blocks
;;  AutoCAD makes again itself (dimensions, tables...), but the dynamic block ones (*U).
;;
;;  Use in an App:
;;    (Remote>>Dyl:DrawOrderApply nil nil)     -> restacks model space and every layout
;;    (Remote>>Dyl:DrawOrderApply "Model" nil) -> restacks one space, given by its layout name
;;    (Remote>>Dyl:DrawOrderRebuild nil nil)   -> deletes the draw order tables, then restacks
;;    (Remote>>Dyl:DrawOrderPreset)            -> name of the active preset ("Default")
;;    (Remote>>Dyl:DrawOrderPresetDefault)     -> preferred preset of the user

(vl-load-com)

;;  Rules used when there is no preset file: (name level layers objects description order)
(setq *do:defaults* '(("Redlines" 9 "*-ANNO-REDL*,*-ANNO-REVC*,*-ANNO-REVS*,*-ANNO-RDME*,*-ANNO-NPLT*,*-NPLT,*-NPLT-*" ""
                       "Redlines, revisions and non-plotting information: above everything" 10
                      )
                      ("References" -9 "*-ANNO-REFR*" "" "External references and attached files: below everything" 80)
                      ("Annotation" 8 "*-ANNO,*-ANNO-[~R]*,*-TAGS,*-TAGS-*" ""
                       "Annotation layers: text, dimensions, tags, symbols, titles" 20
                      )
                      ("Annotation objects" 7 "" "TEXT,MTEXT,ARCALIGNEDTEXT,*DIMENSION,*LEADER,TOLERANCE,ACAD_TABLE,ATTDEF"
                       "Text, dimensions, leaders and tables on any other layer" 30
                      )
                      ("Images" -8 "" "IMAGE,*UNDERLAY,POINTCLOUD*" "Images and underlays (PDF, DWF, DGN) on any other layer"
                       70
                      )
                      ("Background" -7 "*-SCRN,*-SCRN-*,*-BGRD,*-BGRD-*,*-EXST,*-EXST-?" ""
                       "Screened coordination lines and background solid fills" 60
                      )
                      ("Hatch layers" -4 "*-PATT,*-PATT-*" "" "Texture and hatch pattern layers" 40)
                      ("Hatch objects" -4 "" "HATCH,MPOLYGON" "Hatches and gradients on any other layer" 50)
                     )
      ;;  Commands whose new objects are left where they are (replaced by the
      ;;  DynalispDrawOrderSkip environment variable):
      *do:skip*     "U,UNDO,REDO,MREDO,OOPS"
      ;;  Commands that change the layer of objects: the current space is restacked when
      ;;  they end (replaced by the DynalispDrawOrderRefresh environment variable):
      *do:refresh*  (strcat "LAYMCH,-LAYMCH,MATCHPROP,PAINTER,CHPROP,-CHPROP,CHANGE,-CHANGE,LAYMRG,-LAYMRG,"
                            "LAYDEL,-LAYDEL,LAYCUR,-LAYCUR,LAYTRANS,-LAYTRANS"
                    )
)

;;-------------------------=={ Rules }==------------------------;;

;;  Default folder of the presets:
(defun Remote>>Dyl:DrawOrderDefaultDir ()
  (strcat (if *dyl:dylres *dyl:dylres (strcat *dyl:dyl "\\Res")) "\\DrawOrder")
)

;;  Folder of the presets, one CSV file each: the user copy once the presets were saved,
;;  else the default folder (see Dyl:UserDir in dynalisp.mnl):
(defun Remote>>Dyl:DrawOrderDir ()
  (Dyl:UserDir (Remote>>Dyl:DrawOrderDefaultDir))
)

;;  Folder where the presets are saved: the user copy, made from the default presets the
;;  first time. Remote>>Dyl:DrawOrderDir and the preset files point to it from then on:
(defun Remote>>Dyl:DrawOrderDirW ()
  (Dyl:UserDirW (Remote>>Dyl:DrawOrderDefaultDir))
)

;;  CSV file of the preset name:
(defun Remote>>Dyl:DrawOrderPresetFile (name)
  (strcat (Remote>>Dyl:DrawOrderDir) "\\" name ".csv")
)

;;  Names of the presets (their file names), sorted:
(defun Remote>>Dyl:DrawOrderPresets ()
  (acad_strlsort (mapcar 'vl-filename-base (vl-directory-files (Remote>>Dyl:DrawOrderDir) "*.csv" 1)))
)

;;  Name p when it is a preset with a file, else nil:
(defun Remote>>Dyl:DrawOrderPresetValid (p)
  (if (and (= 'STR (type p)) (/= "" p) (findfile (Remote>>Dyl:DrawOrderPresetFile p))) p)
)

;;  Preset saved in the drawing (nil: none, or its file is missing on this computer):
(defun Remote>>Dyl:DrawOrderPresetDwg ()
  (Remote>>Dyl:DrawOrderPresetValid (vlax-ldata-get "dyl-layer" "draworder"))
)

;;  Preferred preset of the user, for the drawings that have none (DynalispDrawOrderPreset
;;  user setting, chosen in the Draw Order window): Default when it is not set or its file is
;;  missing, else the first preset (nil: there is none):
(defun Remote>>Dyl:DrawOrderPresetDefault ()
  (cond
    ((Remote>>Dyl:DrawOrderPresetValid (getenv "DynalispDrawOrderPreset")))
    ((Remote>>Dyl:DrawOrderPresetValid "Default"))
    ((car (Remote>>Dyl:DrawOrderPresets)))
  )
)

;;  Active preset: the one saved in the drawing, else the preferred one of the user (nil:
;;  there is none, *do:defaults* are used):
(defun Remote>>Dyl:DrawOrderPreset ()
  (cond ((Remote>>Dyl:DrawOrderPresetDwg)) ((Remote>>Dyl:DrawOrderPresetDefault)))
)

;;  Save name as the preset of the drawing (nil: none, the drawing uses the preferred one):
(defun Remote>>Dyl:DrawOrderPresetSet (name)
  (if name
    (vlax-ldata-put "dyl-layer" "draworder" name)
    (vlax-ldata-delete "dyl-layer" "draworder")
  )
  (setq *do:stamp* nil)
)

;;  Make name the preferred preset of the user (every drawing without its own preset):
(defun Remote>>Dyl:DrawOrderPresetDefaultSet (name)
  (setenv "DynalispDrawOrderPreset" (cond (name) ("")))
  (setq *do:stamp* nil)
)

;;  Preset old renamed new: the drawing and the preferred preset using it follow (the
;;  other drawings saved with it use the preferred preset until another one is chosen):
(defun Remote>>Dyl:DrawOrderPresetRenamed (old new / p)
  (if (and (= 'STR (type (setq p (vlax-ldata-get "dyl-layer" "draworder")))) (= (strcase p) (strcase old)))
    (Remote>>Dyl:DrawOrderPresetSet new)
  )
  (if (and (setq p (getenv "DynalispDrawOrderPreset")) (= (strcase p) (strcase old)))
    (Remote>>Dyl:DrawOrderPresetDefaultSet new)
  )
)

;;  Rules of the active preset: ((name level layers objects description) ...), the layers
;;  and objects wildcards in upper case ("" matches anything). *do:defaults* when there is
;;  no preset file (or at startup, while Dyl-Sub.lsp that reads the CSV files is not loaded
;;  yet). The file is read again only when it changed or another preset is made active:
(defun Remote>>Dyl:DrawOrderRules (/ pst fle stm)
  (setq pst (Remote>>Dyl:DrawOrderPreset)
        fle (if pst (Remote>>Dyl:DrawOrderPresetFile pst))
        stm (if fle (vl-file-systime fle))
  )
  (cond
    ((and stm *do:rules* (equal (list (strcase fle) stm) *do:stamp*)) *do:rules*)
    ((and stm Remote>>Dyl:CsvRead)
     (setq *do:stamp* (list (strcase fle) stm)
           *do:rules* (Remote>>Dyl:DrawOrderParse (Remote>>Dyl:CsvRead fle 6))
     )
    )
    (*do:defaults*)
  )
)

;;  T when the string str is a valid Order: a whole number from 1 to 999:
(defun Remote>>Dyl:DrawOrderOrder-p (str)
  (and (= 'STR (type str)) (wcmatch str "#,##,###") (<= 1 (atoi str) 999))
)

;;  Rows of a preset file (every cell a string) with an Order in their sixth cell: the rows
;;  without a valid one (a preset file written before the Order column) are numbered after
;;  the others, 10 apart, the highest level first, which keeps the precedence they had
;;  (the highest level of the rules matching an object won). The rows keep their order:
(defun Remote>>Dyl:DrawOrderFill (rows / top i prs)
  (setq top 0
        i   -1
  )
  (foreach r rows
    (setq i (1+ i))
    (if (Remote>>Dyl:DrawOrderOrder-p (nth 5 r))
      (setq top (max top (atoi (nth 5 r))))
      (setq prs (cons (cons i (atoi (cadr r))) prs))
    )
  )
  ;;  prs: ((index . order) ...) of the rows to number, by level then index:
  (setq prs (vl-sort prs '(lambda (a b) (if (= (cdr a) (cdr b)) (< (car a) (car b)) (> (cdr a) (cdr b)))))
        i   0
        prs (mapcar '(lambda (p) (cons (car p) (min 999 (+ top (* 10 (setq i (1+ i))))))) prs)
        i   -1
  )
  (mapcar '(lambda (r / p)
             (setq i (1+ i))
             (if (setq p (assoc i prs))
               (append (list (car r) (cadr r) (nth 2 r) (nth 3 r) (nth 4 r)) (list (itoa (cdr p))))
               r
             )
           )
          rows
  )
)

;;  Rules of rows as they are written in a preset file (every cell a string), the rows
;;  without a name left out. The rules keep the order of the rows:
(defun Remote>>Dyl:DrawOrderParse (rows / lst)
  (foreach r (Remote>>Dyl:DrawOrderFill rows)
    (if (/= "" (car r))
      (setq lst (cons (list (car r)
                            (atoi (cadr r))
                            (strcase (nth 2 r))
                            (strcase (nth 3 r))
                            (nth 4 r)
                            (atoi (nth 5 r))
                      )
                      lst
                )
      )
    )
  )
  (reverse lst)
)

;;  Rule giving its level to a layer name and a DXF object type, both in upper case: of the
;;  rules matching them, the one with the lowest order (the first of them on a tie). nil
;;  when no rule matches:
(defun Remote>>Dyl:DrawOrderRule (lay typ rules / res)
  (foreach r rules
    (if
      (and (or (not res) (< (nth 5 r) (nth 5 res)))
           (or (= "" (nth 2 r)) (wcmatch lay (nth 2 r)))
           (or (= "" (nth 3 r)) (wcmatch typ (nth 3 r)))
      )
      (setq res r)
    )
  )
  res
)

;;  Level of the entity data ed (0 when no rule matches it):
(defun Remote>>Dyl:DrawOrderOf (ed rules)
  (cond
    ((cadr (Remote>>Dyl:DrawOrderRule (strcase (cdr (assoc 8 ed))) (cdr (assoc 0 ed)) rules)))
    (0)
  )
)

;;  T when order o is between lo and hi (nil: no limit on that side):
(defun Remote>>Dyl:DrawOrderIn-p (o lo hi)
  (and (or (not lo) (<= lo o)) (or (not hi) (<= o hi)))
)

;;  ssget filter of the objects of the space tab (layout name) matching one of the rules,
;;  viewports excluded:
(defun Remote>>Dyl:DrawOrderFilter (tab rules / lst)
  (foreach r rules
    (setq lst (append lst
                      (list '(-4 . "<AND")
                            (cons 8 (if (= "" (nth 2 r)) "*" (nth 2 r)))
                            (cons 0 (if (= "" (nth 3 r)) "*" (nth 3 r)))
                            '(-4 . "AND>")
                      )
              )
    )
  )
  (append (list (cons 410 tab) '(-4 . "<NOT") '(0 . "VIEWPORT") '(-4 . "NOT>") '(-4 . "<OR"))
          lst
          '((-4 . "OR>"))
  )
)

;;  Objects of the space tab whose order is between lo and hi, grouped by order:
;;  ((order ename ...) ...)
(defun Remote>>Dyl:DrawOrderLevels (tab lo hi rules / sel ss i e o lst grp)
  (setq sel (vl-remove-if-not '(lambda (r) (Remote>>Dyl:DrawOrderIn-p (cadr r) lo hi)) rules))
  (if (and sel (setq ss (ssget "_X" (Remote>>Dyl:DrawOrderFilter tab sel))))
    (repeat (setq i (sslength ss))
      (setq e (ssname ss (setq i (1- i)))
            o (Remote>>Dyl:DrawOrderOf (entget e) rules)
      )
      (if (Remote>>Dyl:DrawOrderIn-p o lo hi) (setq lst (cons (cons o e) lst)))
    )
  )
  (Remote>>Dyl:DrawOrderGroup lst)
)

;;  Objects of the block definition blk (vla) whose order is between lo and hi, grouped by
;;  order like Remote>>Dyl:DrawOrderLevels:
(defun Remote>>Dyl:DrawOrderBlockLevels (blk lo hi rules / ed o lst)
  (vlax-for obj blk
    (if
      (and (setq ed (entget (vlax-vla-object->ename obj)))
           (Remote>>Dyl:DrawOrderIn-p (setq o (Remote>>Dyl:DrawOrderOf ed rules)) lo hi)
      )
      (setq lst (cons (cons o (cdr (assoc -1 ed))) lst))
    )
  )
  (Remote>>Dyl:DrawOrderGroup (reverse lst))
)

;;  ((order . ename) ...) grouped by order: ((order ename ...) ...)
(defun Remote>>Dyl:DrawOrderGroup (lst / grp)
  (foreach p lst
    (if (not (assoc (car p) grp))
      (setq grp (cons (cons (car p) (mapcar 'cdr (vl-remove-if-not '(lambda (q) (= (car p) (car q))) lst))) grp))
    )
  )
  grp
)

;;  T when the block definition blk (vla) is restacked: not a layout, an xref or a block of
;;  an xref, nor an anonymous block but the ones of the dynamic blocks (*U): the anonymous
;;  blocks of dimensions, tables... are made again by AutoCAD:
(defun Remote>>Dyl:DrawOrderBlock-p (blk / nam)
  (setq nam (strcase (vla-get-Name blk)))
  (and (= :vlax-false (vla-get-IsLayout blk))
       (= :vlax-false (vla-get-IsXRef blk))
       (not (wcmatch nam "*|*"))
       (or (not (wcmatch nam "`**")) (wcmatch nam "`*U*"))
  )
)

;;  Block records (enames) of the block definitions restacked:
(defun Remote>>Dyl:DrawOrderBlocks (/ lst)
  (vlax-for blk (vla-get-Blocks (vla-get-ActiveDocument (vlax-get-acad-object)))
    (if (Remote>>Dyl:DrawOrderBlock-p blk) (setq lst (cons (vlax-vla-object->ename blk) lst)))
  )
  (reverse lst)
)

;;-------------------------=={ Draw order }==------------------------;;

;;  Draw order table of a block (model space, a layout), created when missing:
(defun Remote>>Dyl:DrawOrderTable (blk / dic res)
  (setq dic (vla-GetExtensionDictionary blk))
  (if (vl-catch-all-error-p (setq res (vl-catch-all-apply 'vla-Item (list dic "ACAD_SORTENTS"))))
    (vla-AddObject dic "ACAD_SORTENTS" "AcDbSortentsTable")
    res
  )
)

;;  Block (vla) of the space tab: a layout name, or the block record (ename) of a block
;;  definition. nil when it is not found:
(defun Remote>>Dyl:DrawOrderSpace (tab / blk)
  (if
    (not
      (vl-catch-all-error-p
        (setq blk (vl-catch-all-apply
                    '(lambda ()
                       (if (= 'ENAME (type tab))
                         (vlax-ename->vla-object tab)
                         (vla-get-Block (vla-Item (vla-get-Layouts (vla-get-ActiveDocument (vlax-get-acad-object))) tab))
                       )
                     )
                  )
        )
      )
    )
    blk
  )
)

;;  Restack the space tab: a layout name, or the block record (ename) of a block
;;  definition. The levels above top are moved to the top, the lowest first, and the
;;  levels at bot and below are moved to the bottom, the highest first (top or bot nil:
;;  that side is not restacked). Each level keeps the draw order of its own objects.
;;  Returns the number of objects moved:
(defun Remote>>Dyl:DrawOrderStack (tab top bot rules / blk srt grp n)
  (setq n 0)
  (if (setq blk (Remote>>Dyl:DrawOrderSpace tab))
    (foreach side (list (if top (list (1+ top) nil 'MoveToTop '<)) (if bot (list nil bot 'MoveToBottom '>)))
      (if
        (and side
             (setq grp (if (= 'ENAME (type tab))
                         (Remote>>Dyl:DrawOrderBlockLevels blk (car side) (cadr side) rules)
                         (Remote>>Dyl:DrawOrderLevels tab (car side) (cadr side) rules)
                       )
             )
             (or srt (setq srt (Remote>>Dyl:DrawOrderTable blk)))
        )
        (foreach g (vl-sort grp (function (lambda (a b) (apply (cadddr side) (list (car a) (car b))))))
          (if
            (not
              (vl-catch-all-error-p
                (vl-catch-all-apply 'vlax-invoke (list srt (caddr side) (mapcar 'vlax-ename->vla-object (cdr g))))
              )
            )
            (setq n (+ n (length (cdr g))))
          )
        )
      )
    )
  )
  n
)

;;  Restack the space tab (layout name), or model space, every layout and every block
;;  definition (see Remote>>Dyl:DrawOrderBlock-p) when tab is nil, with the rules of the
;;  active preset (or with rules, when not nil). Returns the number of objects moved:
(defun Remote>>Dyl:DrawOrderApply (tab rules / n)
  (setq rules     (cond (rules) ((Remote>>Dyl:DrawOrderRules)))
        n         0
        *do:busy* t
  )
  (foreach l (if tab (list tab) (append (cons "Model" (layoutlist)) (Remote>>Dyl:DrawOrderBlocks)))
    (setq n (+ n (Remote>>Dyl:DrawOrderStack l 0 -1 rules)))
  )
  (setq *do:busy* nil)
  n
)

;;  Rebuild the draw order of the space tab (layout name), or of model space, every layout
;;  and every block definition when tab is nil: their draw order tables are deleted (the
;;  objects go back to their creation order), then the levels are stacked again from it.
;;  This drops the entries piled up by the restacks made after each command, that slow
;;  down panning and zooming; a DRAWORDER set by hand within a level is lost. Returns the
;;  number of objects moved:
(defun Remote>>Dyl:DrawOrderRebuild (tab rules / blk srt)
  (foreach l (if tab (list tab) (append (cons "Model" (layoutlist)) (Remote>>Dyl:DrawOrderBlocks)))
    (if
      (and (setq blk (Remote>>Dyl:DrawOrderSpace l))
           (= :vlax-true (vla-get-HasExtensionDictionary blk))
           (not
             (vl-catch-all-error-p
               (setq srt (vl-catch-all-apply 'vla-Item (list (vla-GetExtensionDictionary blk) "ACAD_SORTENTS")))
             )
           )
      )
      (vla-Delete srt)
    )
  )
  (Remote>>Dyl:DrawOrderApply tab rules)
)

;;  Objects of the space tab (layout name, or block record ename) whose order is above o,
;;  for Remote>>Dyl:DrawOrderLowest: a list of enames for a block definition, a selection
;;  set for a space when o >= 0 (the objects matching a rule above o: their order is
;;  checked, a rule with a lower Order can give them another level), T for a space when
;;  o < 0 (the objects at 0 match no rule: the order of each object is read). nil: none:
(defun Remote>>Dyl:DrawOrderAbove (tab o rules / sel)
  (cond
    ((= 'ENAME (type tab))
     (apply 'append (mapcar 'cdr (Remote>>Dyl:DrawOrderBlockLevels (vlax-ename->vla-object tab) (1+ o) nil rules)))
    )
    ((< o 0))
    ((setq sel (vl-remove-if-not '(lambda (r) (< o (cadr r))) rules))
     (ssget "_X" (Remote>>Dyl:DrawOrderFilter tab sel))
    )
  )
)

;;  Object (vla) drawn the lowest in the draw order table srt of the objects cand (see
;;  Remote>>Dyl:DrawOrderAbove: T tests the order of each object, from the bottom up, for
;;  one above o; viewports left out). nil: there is none:
(defun Remote>>Dyl:DrawOrderLowest (srt cand o rules / var e ed)
  (vla-GetFullDrawOrder srt 'var :vlax-false)
  (vl-some '(lambda (obj)
              (setq e (vlax-vla-object->ename obj))
              (if
                (cond
                  ((eq t cand)
                   (and (setq ed (entget e))
                        (/= "VIEWPORT" (cdr (assoc 0 ed)))
                        (< o (Remote>>Dyl:DrawOrderOf ed rules))
                   )
                  )
                  ((= 'PICKSET (type cand)) (and (ssmemb e cand) (< o (Remote>>Dyl:DrawOrderOf (entget e) rules))))
                  ((member e cand))
                )
                obj
              )
            )
           (vlax-safearray->list (vlax-variant-value var))
  )
)

;;  Put the new objects lst (enames) of the space tab in their level without moving the
;;  objects already stacked: the new objects of each level, the highest level first, go
;;  right below the lowest object of the levels above it (they stay where they are when
;;  there is none: new objects are drawn on top). Returns the number of objects moved, nil
;;  when the space is not found. An error (the draw order cannot be read) is caught by
;;  Remote>>Dyl:DrawOrderPlaceSafe:
(defun Remote>>Dyl:DrawOrderPlace (tab lst rules / blk srt cand low n)
  (if (setq blk (Remote>>Dyl:DrawOrderSpace tab))
    (progn
      (setq n 0)
      (foreach g (vl-sort (Remote>>Dyl:DrawOrderGroup
                            (mapcar '(lambda (e) (cons (Remote>>Dyl:DrawOrderOf (entget e) rules) e)) lst)
                          )
                          '(lambda (a b) (> (car a) (car b)))
                 )
        (if
          (and (setq cand (Remote>>Dyl:DrawOrderAbove tab (car g) rules))
               (or srt (setq srt (Remote>>Dyl:DrawOrderTable blk)))
               (setq low (Remote>>Dyl:DrawOrderLowest srt cand (car g) rules))
          )
          (progn
            (vlax-invoke srt 'MoveBelow (mapcar 'vlax-ename->vla-object (cdr g)) low)
            (setq n (+ n (length (cdr g))))
          )
        )
      )
    )
  )
  n
)

;;  Remote>>Dyl:DrawOrderPlace, nil on an error:
(defun Remote>>Dyl:DrawOrderPlaceSafe (tab lst rules / res)
  (if (not (vl-catch-all-error-p (setq res (vl-catch-all-apply 'Remote>>Dyl:DrawOrderPlace (list tab lst rules)))))
    res
  )
)

;;  (top bot) of the new objects lst (enames) for Remote>>Dyl:DrawOrderStack: top, the
;;  lowest order >= 0 of them, bot, the highest order below 0 (nil: none on that side):
(defun Remote>>Dyl:DrawOrderBounds (lst rules / o top bot)
  (foreach e lst
    (if (<= 0 (setq o (Remote>>Dyl:DrawOrderOf (entget e) rules)))
      (setq top (if top (min o top) o))
      (setq bot (if bot (max o bot) o))
    )
  )
  (list top bot)
)

;;-------------------------=={ Auto draw order }==------------------------;;

;;  The auto draw order reactors are in Modules\Dynalisp\Reactor\Dyl-DrawOrder.lsp, loaded
;;  only while the DynALisp reactors are on (Dyl-Settings).

;;  T when auto draw order is on (user setting, off by default). It runs only while the
;;  DynALisp reactors are on too (Dyl:ReactorsOn-p):
(defun Remote>>Dyl:DrawOrderAuto-p ()
  (= "1" (getenv "DynalispDrawOrderAuto"))
)

;;  Turn auto draw order on or off (every drawing, from the next one made current):
(defun Remote>>Dyl:DrawOrderAutoSet (on)
  (setenv "DynalispDrawOrderAuto" (if on "1" "0"))
  (if Reactor>>Dyl:DrawOrderReactors (vl-catch-all-apply 'Reactor>>Dyl:DrawOrderReactors (list on)))
  (princ (strcat "\nAuto draw order "
                 (if on "on" "off")
                 (if (and on (not (Dyl:ReactorsOn-p))) ", but the DynALisp reactors are off (see Dyl-Settings)" "")
                 "."
         )
  )
)

(princ)
