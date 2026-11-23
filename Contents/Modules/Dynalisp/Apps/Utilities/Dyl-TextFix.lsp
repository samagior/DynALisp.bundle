;; TextFix - Proofreads the selected texts with Claude, through Claude Code
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
;;-------------------------=={ End of Licence }==------------------------;;

;;; ==========================================================================
;;; Dyl-TextFix.lsp
;;;
;;; Proofreads text objects with Claude and replaces the original text with
;;; the corrected version after user confirmation.
;;;
;;; Supported objects : TEXT, MTEXT, MULTILEADER.
;;;   - Block attributes are NOT processed (they cannot be picked with ssget).
;;;   - AutoCAD formatting codes (\P, \f...;, %%c, ...) are preserved.
;;;
;;; Command :
;;;   Dyl-TextFix (TEXTFIX) - uses the current pickfirst selection (right-click
;;;                 menu) or asks for a selection if nothing is selected.
;;;
;;; Requirements :
;;;   - DynALisp.Assistant.dll (AutoCAD 2016 or later): (Dyl:ClaudeRun ...).
;;;   - Claude Code installed and signed in with the user's own Claude
;;;     account (Dyl-Assistant installs it and signs it in): no API key.
;;;
;;; Notes :
;;;   - The texts of the objects selected are sent to Anthropic through
;;;     Claude Code, all of them in one request (a few for a large
;;;     selection, *ctf:batch-max* texts or *ctf:batch-chars* characters
;;;     each), the answer following a JSON schema: one corrected text per
;;;     text sent, in the same order.
;;;   - The whole operation is recorded as a single UNDO transaction.
;;; ==========================================================================

(vl-load-com)

;;; --------------------------------------------------------------------------
;;; Configuration
;;;   The *ctf:* prefix avoids collisions with other routines.
;;; --------------------------------------------------------------------------
(setq *ctf:model*       "haiku" ; fast, enough for proofreading
      *ctf:timeout*     180     ; seconds, for one request
      *ctf:batch-max*   40      ; texts per request at most
      *ctf:batch-chars* 6000    ; characters per request at most
)

;; Instructions sent with every request.
(setq *ctf:system-prompt*
       (strcat "You proofread texts taken from AutoCAD construction drawings "
               "(notes, specifications, labels). "
               "The input is a JSON object whose \"texts\" array holds the texts. "
               "Correct the spelling, grammar, accents and punctuation of each text, "
               "in the language of that text. Never translate. "
               "Keep technical terms, abbreviations, units, numbers, dimensions, codes "
               "and standard references (for example CNB, CSA) unchanged. "
               "Keep every AutoCAD formatting code exactly as written "
               "(for example \\P, \\~, \\fArial|b0;, braces, %%c, %%d, %%p, \\U+00E9) "
               "and keep the line structure. "
               "Answer with the \"texts\" array: exactly one corrected text for each "
               "text received, in the same order, each the corrected text only "
               "(no quotes, no explanation). A text already correct is returned unchanged."
       )
)

;; The answer: one string per text sent.
(setq *ctf:schema*
       (strcat "{\"type\":\"object\","
               "\"properties\":{\"texts\":{\"type\":\"array\",\"items\":{\"type\":\"string\"}}},"
               "\"required\":[\"texts\"],\"additionalProperties\":false}"
       )
)

;;; ==========================================================================
;;; SECTION 1 - STRING AND JSON HELPERS
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; ctf:replace-all
;;;   Replaces every occurrence of OLD by NEW in STR and returns the result.
;;;   The search resumes after each replacement, so NEW may safely contain OLD.
;;; --------------------------------------------------------------------------
(defun ctf:replace-all (str old new / pos)
  (setq pos 0)
  (while (setq pos (vl-string-search old str pos))
    (setq str (strcat (substr str 1 pos)
                      new
                      (substr str (+ pos (strlen old) 1))
              )
          pos (+ pos (strlen new))
    )
  )
  str
)

;;; --------------------------------------------------------------------------
;;; ctf:json-escape
;;;   Escapes a string so it can be embedded inside a JSON string literal.
;;;   The backslash must be escaped first to avoid double-escaping.
;;; --------------------------------------------------------------------------
(defun ctf:json-escape (str)
  (setq str (ctf:replace-all str "\\" "\\\\"))
  (setq str (ctf:replace-all str "\"" "\\\""))
  (setq str (ctf:replace-all str (strcat (chr 13) (chr 10)) "\\n"))
  (setq str (ctf:replace-all str (chr 10) "\\n"))
  (setq str (ctf:replace-all str (chr 13) "\\n"))
  (setq str (ctf:replace-all str (chr 9) "\\t"))
  str
)

;;; --------------------------------------------------------------------------
;;; ctf:unicode-to-char
;;;   Converts a 4-digit hexadecimal string (from a JSON \uXXXX escape) to a
;;;   character. AutoCAD 2021 and later (Unicode AutoLISP) take any code;
;;;   an older one only those of its code page (1-255), the others "?".
;;; --------------------------------------------------------------------------
(defun ctf:unicode-to-char (hex / code digit)
  (setq code 0)
  (foreach c (vl-string->list (strcase hex))
    (setq digit (vl-string-position c "0123456789ABCDEF")
          code  (+ (* code 16) (if digit digit 0))
    )
  )
  (cond
    ((< 0 code 256) (chr code))
    ((and (< 255 code 65536) (>= (atof (getvar "ACADVER")) 24.0)) (chr code))
    ("?")
  )
)

;;; --------------------------------------------------------------------------
;;; ctf:json-string-at
;;;   Reads the JSON string literal whose opening quote is at POS (1-based) of
;;;   JSON. Returns (value . position after its closing quote), nil when it
;;;   is not closed.
;;; --------------------------------------------------------------------------
(defun ctf:json-string-at (json pos / len ch esc out done)
  (setq pos (1+ pos)
        len (strlen json)
        out ""
  )
  (while (and (not done) (<= pos len))
    (setq ch (substr json pos 1))
    (cond
      ((= ch "\"") (setq done T))
      ((= ch "\\")
       (setq pos (1+ pos)
             esc (substr json pos 1)
       )
       (cond
         ((= esc "n") (setq out (strcat out (chr 10))))
         ((= esc "t") (setq out (strcat out (chr 9))))
         ((= esc "r") nil)
         ((= esc "u")
          (setq out (strcat out (ctf:unicode-to-char (substr json (1+ pos) 4)))
                pos (+ pos 4)
          )
         )
         ;; \" \\ and \/ stand for the character itself
         (T (setq out (strcat out esc)))
       )
      )
      (T (setq out (strcat out ch)))
    )
    (setq pos (1+ pos))
  )
  (if done (cons out pos))
)

;;; --------------------------------------------------------------------------
;;; ctf:json-strings
;;;   The strings of the array of KEY in JSON ("key":["a","b"]), in order;
;;;   nil when the key or its array is missing or not closed. Enough for the
;;;   answer of the schema above; not a general-purpose JSON parser.
;;; --------------------------------------------------------------------------
(defun ctf:json-strings (json key / pos len ch str out done)
  (if (and (setq pos (vl-string-search (strcat "\"" key "\"") json))
           (setq pos (vl-string-search "[" json pos))
      )
    (progn
      (setq pos (+ pos 2)
            len (strlen json)
      )
      (while (and (not done) (<= pos len))
        (setq ch (substr json pos 1))
        (cond
          ((= ch "]") (setq done T))
          ((= ch "\"")
           (if (setq str (ctf:json-string-at json pos))
             (setq out (cons (car str) out)
                   pos (cdr str)
             )
             (setq pos (1+ len))
           )
          )
          ;; commas and spaces between the items
          (T (setq pos (1+ pos)))
        )
      )
      (if done (reverse out))
    )
  )
)

;;; ==========================================================================
;;; SECTION 2 - CLAUDE
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; ctf:batches
;;;   Splits the texts into the lists sent in one request each: at most
;;;   *ctf:batch-max* texts and *ctf:batch-chars* characters (a longer text
;;;   alone).
;;; --------------------------------------------------------------------------
(defun ctf:batches (texts / cur n out)
  (setq n 0)
  (foreach s texts
    (if (and cur
             (or (>= (length cur) *ctf:batch-max*)
                 (> (+ n (strlen s)) *ctf:batch-chars*)
             )
        )
      (setq out (cons (reverse cur) out)
            cur nil
            n   0
      )
    )
    (setq cur (cons s cur)
          n   (+ n (strlen s))
    )
  )
  (if cur (setq out (cons (reverse cur) out)))
  (reverse out)
)

;;; --------------------------------------------------------------------------
;;; ctf:correct-texts
;;;   Sends TEXTS (strings) to Claude in one request (Dyl:ClaudeRun of
;;;   DynALisp.Assistant.dll, which runs Claude Code signed in with the
;;;   user's account). Returns (T corrected ...), one per text in the same
;;;   order, or (nil error-message).
;;; --------------------------------------------------------------------------
(defun ctf:correct-texts (texts / input res out)
  (setq input (strcat "{\"texts\":["
                      (apply 'strcat
                             (cdr (apply 'append
                                         (mapcar '(lambda (s) (list "," (strcat "\"" (ctf:json-escape s) "\"")))
                                                 texts
                                         )
                                  )
                             )
                      )
                      "]}"
              )
        res   (vl-catch-all-apply 'Dyl:ClaudeRun (list input *ctf:system-prompt* *ctf:model* *ctf:schema* *ctf:timeout*))
  )
  (cond
    ((vl-catch-all-error-p res) (list nil (vl-catch-all-error-message res)))
    ((not (car res))
     (setq res (if (= 'STR (type (cadr res))) (cadr res) "Claude Code n'a rien renvoye"))
     ;; Claude Code not signed in: Dyl-Assistant signs it in
     (if (wcmatch (strcase res) "*LOGIN*,*LOG IN*,*LOGGED*,*AUTHENTICAT*,*API KEY*")
       (setq res (strcat res " (run Dyl-Assistant to sign in to Claude Code)"))
     )
     (list nil res)
    )
    ((not (setq out (ctf:json-strings (cadr res) "texts")))
     (list nil "reponse inattendue de Claude")
    )
    ((/= (length out) (length texts))
     (list nil (strcat "Claude a renvoye " (itoa (length out)) " texte(s) pour " (itoa (length texts))))
    )
    ((cons T
           (mapcar '(lambda (s) (vl-string-right-trim (strcat (chr 10) (chr 13)) s)) out)
     )
    )
  )
)

;;; ==========================================================================
;;; SECTION 3 - SELECTION AND USER INTERACTION
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; ctf:get-selection
;;;   Returns a selection set of supported text objects, or nil.
;;;   The current pickfirst selection is used when available (right-click
;;;   menu case); otherwise the user is asked to select objects.
;;; --------------------------------------------------------------------------
(defun ctf:get-selection (/ filter ss)
  (setq filter '((0 . "TEXT,MTEXT,MULTILEADER")))
  (setq ss (ssget "_I" filter))
  (if (not ss)
    (progn
      (prompt "\nSelectionnez le texte a corriger : ")
      (setq ss (ssget filter))
    )
  )
  ss
)

;;; --------------------------------------------------------------------------
;;; ctf:text-editable-p
;;;   Returns non-nil if the VLA object has a writable TextString property.
;;; --------------------------------------------------------------------------
(defun ctf:text-editable-p (obj)
  (vlax-property-available-p obj 'TextString T)
)

;;; --------------------------------------------------------------------------
;;; ctf:print-change
;;;   Shows the original and the corrected text on the command line.
;;; --------------------------------------------------------------------------
(defun ctf:print-change (original corrected)
  (princ (strcat "\n\n  Avant : " original))
  (princ (strcat "\n  Apres : " corrected))
)

;;; --------------------------------------------------------------------------
;;; ctf:ask-confirmation
;;;   Asks whether to apply the correction.
;;;   Returns one of "Oui", "Non", "Tous" or "Quitter" (default: "Oui").
;;; --------------------------------------------------------------------------
(defun ctf:ask-confirmation (/ answer)
  (initget "Oui Non Tous Quitter")
  (setq answer (getkword "\nAppliquer la correction ? [Oui/Non/Tous/Quitter] <Oui> : "))
  (if answer answer "Oui")
)

;;; --------------------------------------------------------------------------
;;; ctf:apply-text
;;;   Writes the corrected text to the object (ActiveX, so locked layers are
;;;   handled too). Returns T on success, nil on failure.
;;; --------------------------------------------------------------------------
(defun ctf:apply-text (obj text)
  (not
    (vl-catch-all-error-p
      (vl-catch-all-apply 'vla-put-TextString (list obj text))
    )
  )
)

;;; ==========================================================================
;;; SECTION 4 - PROCESSING
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; ctf:process-selection
;;;   Proofreads every object of the selection set: their texts sent
;;;   together (ctf:batches), then each correction shown and confirmed.
;;;   Returns a list of counters : (checked fixed failed).
;;; --------------------------------------------------------------------------
(defun ctf:process-selection (ss / idx obj items batch res answer apply-all quit n-checked n-fixed n-failed)
  (setq idx       0
        n-checked 0
        n-fixed   0
        n-failed  0
  )
  ;; The objects and their texts:
  (while (< idx (sslength ss))
    (setq obj (vlax-ename->vla-object (ssname ss idx))
          idx (1+ idx)
    )
    (if (ctf:text-editable-p obj)
      (setq items (cons (cons obj (vla-get-TextString obj)) items))
    )
  )
  (setq items     (reverse items)
        n-checked (length items)
  )
  ;; One request per batch, then its corrections:
  (foreach texts (ctf:batches (mapcar 'cdr items))
    (if (not quit)
      (progn
        (setq batch nil)
        (repeat (length texts)
          (setq batch (cons (car items) batch)
                items (cdr items)
          )
        )
        (setq batch (reverse batch))
        (princ (strcat "\nCorrection de " (itoa (length texts)) " texte(s) par Claude..."))
        (setq res (ctf:correct-texts texts))
        (if (not (car res))
          (progn
            (setq n-failed (+ n-failed (length texts)))
            (princ (strcat "\n  Echec : " (cadr res)))
          )
          (mapcar
            '(lambda (item corrected)
               (if (and (not quit) (/= corrected (cdr item)))
                 (progn
                   (ctf:print-change (cdr item) corrected)
                   (setq answer (if apply-all "Oui" (ctf:ask-confirmation)))
                   (cond
                     ((= answer "Tous") (setq apply-all T answer "Oui"))
                     ((= answer "Quitter") (setq quit T))
                   )
                   (if (= answer "Oui")
                     (if (ctf:apply-text (car item) corrected)
                       (setq n-fixed (1+ n-fixed))
                       (setq n-failed (1+ n-failed))
                     )
                   )
                 )
               )
             )
            batch
            (cdr res)
          )
        )
      )
    )
  )
  (list n-checked n-fixed n-failed)
)

;;; ==========================================================================
;;; SECTION 5 - COMMAND
;;; ==========================================================================

;; Text Fix
;; Proofreads the selected texts, mtexts and multileaders with Claude and replaces them after confirmation.

(defun c:Dyl-TextFix (/ *error* doc undo-open ss stats)

  ;; Local error handler: closes the UNDO group and hides Esc/cancel noise.
  (defun *error* (msg)
    (if undo-open (vla-EndUndoMark doc))
    (if (and msg (not (wcmatch (strcase msg) "*BREAK*,*CANCEL*,*QUIT*")))
      (princ (strcat "\nErreur : " msg))
    )
    (princ)
  )

  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))

  (cond
    ((not Dyl:ClaudeRun)
     (princ "\n--> Text Fix needs DynALisp.Assistant.dll (AutoCAD 2016 or later, not blocked by SECURELOAD).")
    )

    ((not (setq ss (ctf:get-selection)))
     (princ "\nTEXTFIX : aucun texte selectionne.")
    )

    (T
     (vla-StartUndoMark doc)
     (setq undo-open T)
     (setq stats (ctf:process-selection ss))
     (vla-EndUndoMark doc)
     (setq undo-open nil)

     (princ
       (strcat "\n\nTEXTFIX : "
               (itoa (nth 0 stats))
               " texte(s) analyse(s), "
               (itoa (nth 1 stats))
               " corrige(s), "
               (itoa (nth 2 stats))
               " en echec."
       )
     )
    )
  )
  (princ)
)

(princ)
