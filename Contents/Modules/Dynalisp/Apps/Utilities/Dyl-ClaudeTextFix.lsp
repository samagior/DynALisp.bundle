;;; ==========================================================================
;;; ClaudeTextFix.lsp
;;;
;;; Proofreads text objects with the Anthropic API (Claude) and replaces the
;;; original text with the corrected version after user confirmation.
;;;
;;; Supported objects : TEXT, MTEXT, MULTILEADER.
;;;   - Block attributes are NOT processed (they cannot be picked with ssget).
;;;   - AutoCAD formatting codes (\P, \f...;, %%c, ...) are preserved.
;;;
;;; Command :
;;;   CLAUDETEXT  - uses the current pickfirst selection (right-click menu)
;;;                 or asks for a selection if nothing is selected.
;;;
;;; Requirements :
;;;   - An Anthropic API key, stored in the ANTHROPIC_API_KEY environment
;;;     variable (restart AutoCAD after creating it) or typed on demand.
;;;   - Windows (uses the WinHttp.WinHttpRequest.5.1 COM object).
;;;
;;; Notes :
;;;   - The text of the selected objects is sent to the Anthropic API.
;;;   - The whole operation is recorded as a single UNDO transaction.
;;; ==========================================================================

(vl-load-com)

;;; --------------------------------------------------------------------------
;;; Configuration
;;;   Global settings, grouped in one place so they are easy to adjust.
;;;   The *ctf:* prefix avoids collisions with other routines.
;;; --------------------------------------------------------------------------
(setq *ctf:api-url*     "https://api.anthropic.com/v1/messages"
      *ctf:api-version* "2023-06-01"
      *ctf:model*       "claude-haiku-5-5" ; fast and cheap, enough for proofreading
      *ctf:max-tokens*  4096
      *ctf:timeout-ms*  30000
)

;; Session cache for the API key (kept across command calls, never saved).
(if (not (boundp '*ctf:api-key*)) (setq *ctf:api-key* nil))

;; Instructions sent to the model with every request.
(setq *ctf:system-prompt* (strcat "You proofread text taken from AutoCAD construction drawings " 
                                  "(notes, specifications, labels). " 
                                  "Correct spelling, grammar, accents and punctuation in the language of " 
                                  "the input. Never translate. " 
                                  "Keep technical terms, abbreviations, units, numbers, dimensions, codes " 
                                  "and standard references (for example CNB, CSA) unchanged. " 
                                  "Keep every AutoCAD formatting code exactly as written " 
                                  "(for example \\P, \\~, \\fArial|b0;, braces, %%c, %%d, %%p, \\U+00E9) " 
                                  "and keep the line structure. " 
                                  "Reply with the corrected text only: no quotes, no explanation, " 
                                  "no markdown. If the text is already correct, return it unchanged."
                          )
)

;;; ==========================================================================
;;; SECTION 1 - STRING HELPERS
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

;;; ==========================================================================
;;; SECTION 2 - JSON HELPERS
;;; ==========================================================================

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
;;;   single character. Codes outside 1-255 cannot be represented in the
;;;   AutoLISP code page and are replaced by "?".
;;; --------------------------------------------------------------------------
(defun ctf:unicode-to-char (hex / code digit c) 
  (setq code 0)
  (foreach c (vl-string->list (strcase hex)) 
    (setq digit (vl-string-position c "0123456789ABCDEF")
          code  (+ (* code 16) (if digit digit 0))
    )
  )
  (if (< 0 code 256) (chr code) "?")
)

;;; --------------------------------------------------------------------------
;;; ctf:json-string-after
;;;   Finds the first  "KEY":"..."  pair in a JSON text and returns the
;;;   unescaped string value, or nil if the key is missing or truncated.
;;;   Enough for the flat fields we need ("text" and "message"); this is
;;;   not a general-purpose JSON parser.
;;; --------------------------------------------------------------------------
(defun ctf:json-string-after (json key / marker start pos len ch esc out done) 
  (setq marker (strcat "\"" key "\":\"")
        start  (vl-string-search marker json)
  )
  (if start 
    (progn 
      (setq pos  (+ start (strlen marker) 1) ; 1-based index of the first value char
            len  (strlen json)
            out  ""
            done nil
      )
      (while (and (not done) (<= pos len)) 
        (setq ch (substr json pos 1))
        (cond 
          ;; Unescaped quote: end of the string value
          ((= ch "\"")
           (setq done T)
          )
          ;; Escape sequence: decode the character that follows the backslash
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
             ;; \" \\ and \/ simply stand for the character itself
             (T (setq out (strcat out esc)))
           )
          )
          ;; Ordinary character
          (T (setq out (strcat out ch)))
        )
        (setq pos (1+ pos))
      )
      (if done out)
    )
  )
)

;;; ==========================================================================
;;; SECTION 3 - API LAYER
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; ctf:get-api-key
;;;   Returns the API key: session cache first, then the ANTHROPIC_API_KEY
;;;   environment variable, then an interactive prompt. Returns nil if the
;;;   user enters nothing. A typed key is kept in memory for the session only.
;;; --------------------------------------------------------------------------
(defun ctf:get-api-key (/ input) 
  (cond 
    (*ctf:api-key* *ctf:api-key*)
    ((setq *ctf:api-key* (getenv "ANTHROPIC_API_KEY")) *ctf:api-key*)
    (T
     (setq input (getstring T "\nCle API Anthropic (valable pour cette session) : "))
     (if (/= input "") (setq *ctf:api-key* input))
    )
  )
)

;;; --------------------------------------------------------------------------
;;; ctf:build-request-body
;;;   Builds the JSON body of the /v1/messages request for the given text.
;;; --------------------------------------------------------------------------
(defun ctf:build-request-body (text) 
  (strcat "{\"model\":\"" 
          *ctf:model*
          "\","
          "\"max_tokens\":"
          (itoa *ctf:max-tokens*)
          ","
          "\"system\":\""
          (ctf:json-escape *ctf:system-prompt*)
          "\","
          "\"messages\":[{\"role\":\"user\",\"content\":\""
          (ctf:json-escape text)
          "\"}]}"
  )
)

;;; --------------------------------------------------------------------------
;;; ctf:http-post
;;;   Performs the synchronous HTTP POST on an existing WinHttp object.
;;;   Returns (status . response-text). COM errors are raised to the caller,
;;;   which wraps this function in vl-catch-all-apply.
;;; --------------------------------------------------------------------------
(defun ctf:http-post (http api-key body) 
  (vlax-invoke-method http 'SetTimeouts 10000 10000 *ctf:timeout-ms* *ctf:timeout-ms*)
  (vlax-invoke-method http 'Open "POST" *ctf:api-url* :vlax-false)
  (vlax-invoke-method http 'SetRequestHeader "Content-Type" "application/json; charset=utf-8")
  (vlax-invoke-method http 'SetRequestHeader "x-api-key" api-key)
  (vlax-invoke-method http 'SetRequestHeader "anthropic-version" *ctf:api-version*)
  (vlax-invoke-method http 'Send body)
  (cons (vlax-get-property http 'Status) 
        (vlax-get-property http 'ResponseText)
  )
)

;;; --------------------------------------------------------------------------
;;; ctf:send-request
;;;   Safe wrapper around ctf:http-post. Always returns (status . text):
;;;   status 0 means a local failure and text then holds the error message.
;;; --------------------------------------------------------------------------
(defun ctf:send-request (api-key body / http result) 
  (setq http (vlax-create-object "WinHttp.WinHttpRequest.5.1"))
  (cond 
    ((not http)
     (cons 0 "impossible de creer l'objet WinHttp")
    )
    (T
     (setq result (vl-catch-all-apply 'ctf:http-post (list http api-key body)))
     (vlax-release-object http)
     (if (vl-catch-all-error-p result) 
       (cons 0 (vl-catch-all-error-message result))
       result
     )
    )
  )
)

;;; --------------------------------------------------------------------------
;;; ctf:correct-text
;;;   Sends TEXT to Claude and returns (T . corrected-text) on success or
;;;   (nil . error-message) on failure.
;;; --------------------------------------------------------------------------
(defun ctf:correct-text (api-key text / response status raw corrected err) 
  (setq response (ctf:send-request api-key (ctf:build-request-body text))
        status   (car response)
        raw      (cdr response)
  )
  (cond 
    ;; Success: extract the generated text
    ((= status 200)
     (setq corrected (ctf:json-string-after raw "text"))
     (if corrected 
       (cons T (vl-string-right-trim (strcat (chr 10) (chr 13)) corrected))
       (cons nil "reponse inattendue de l'API")
     )
    )
    ;; Local failure (no network, timeout, COM error)
    ((= status 0)
     (cons nil raw)
    )
    ;; HTTP error returned by the API
    (T
     (setq err (ctf:json-string-after raw "message"))
     (cons nil (strcat "HTTP " (itoa status) " - " (if err err "erreur inconnue")))
    )
  )
)

;;; ==========================================================================
;;; SECTION 4 - SELECTION AND USER INTERACTION
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
;;; SECTION 5 - PROCESSING
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; ctf:process-selection
;;;   Proofreads every object of the selection set, one API call per object.
;;;   Returns a list of counters : (checked fixed failed).
;;; --------------------------------------------------------------------------
(defun ctf:process-selection (api-key ss / idx obj original result corrected answer apply-all quit n-checked n-fixed 
                              n-failed
                             ) 
  (setq idx       0
        n-checked 0
        n-fixed   0
        n-failed  0
        apply-all nil
        quit      nil
  )

  (while (and (not quit) (< idx (sslength ss))) 
    (setq obj (vlax-ename->vla-object (ssname ss idx))
          idx (1+ idx)
    )

    (if (ctf:text-editable-p obj) 
      (progn 
        (setq n-checked (1+ n-checked)
              original  (vla-get-TextString obj)
              result    (ctf:correct-text api-key original)
        )

        (cond 
          ;; The request failed: report and continue with the next object
          ((not (car result))
           (setq n-failed (1+ n-failed))
           (princ (strcat "\n  Echec : " (cdr result)))
          )

          ;; Nothing to correct
          ((= (cdr result) original)
           nil
          )

          ;; A correction is proposed
          (T
           (setq corrected (cdr result))
           (ctf:print-change original corrected)
           (setq answer (if apply-all "Oui" (ctf:ask-confirmation)))

           (cond 
             ((= answer "Tous")
              (setq apply-all T
                    answer    "Oui"
              )
             )
             ((= answer "Quitter") (setq quit T))
           )

           (if (= answer "Oui") 
             (if (ctf:apply-text obj corrected) 
               (setq n-fixed (1+ n-fixed))
               (setq n-failed (1+ n-failed))
             )
           )
          )
        )
      )
    )
  )

  (list n-checked n-fixed n-failed)
)

;;; ==========================================================================
;;; SECTION 6 - COMMAND
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; C:Dyl-ClaudeTextFix
;;;   Main command: gets the API key and the selection, runs the proofreading
;;;   inside one UNDO transaction and prints a summary.
;;; --------------------------------------------------------------------------

;; Claude Text Fix
;; Proofreads the selected texts, mtexts and multileaders with Claude and replaces them after confirmation.

(defun c:Dyl-ClaudeTextFix (/ *error* doc undo-open api-key ss stats) 

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
    ((not (setq api-key (ctf:get-api-key)))
     (princ "\nCLAUDETEXT : aucune cle API fournie. Commande annulee.")
    )

    ((not (setq ss (ctf:get-selection)))
     (princ "\nCLAUDETEXT : aucun texte selectionne.")
    )

    (T
     (vla-StartUndoMark doc)
     (setq undo-open T)
     (setq stats (ctf:process-selection api-key ss))
     (vla-EndUndoMark doc)
     (setq undo-open nil)

     (princ 
       (strcat "\n\nCLAUDETEXT : " 
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

(princ "\nClaudeTextFix.lsp charge. Tapez Dyl-ClaudeTextFix pour executer.")
(princ)
