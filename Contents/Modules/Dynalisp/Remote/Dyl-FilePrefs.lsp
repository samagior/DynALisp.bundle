;; Dyl-FilePrefs - DynALisp profile set from the file preferences
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

;;  Loaded at startup with the other Remote files, before the Apps.
;;
;;  The file preferences are user settings chosen in Dyl-Settings (or with the
;;  Dyl-SetFilePrefs command):
;;    DynalispPrefClass     AEC library classification: CAWS, MasterFormat or OmniClass
;;    DynalispPrefUnits     drawing units: Metric or Imperial
;;    DynalispPrefLanguage  language of the content and of the spell checker: one of the
;;                          languages AutoCAD is installed in (English, French, German...)
;;    DynalispPrefProfile   "1": AutoCAD uses the DynALisp profile
;;    DynalispPrefCustomDict "0": the DynALisp custom dictionary of the language is not
;;                          used (off by default, used only when the language has one)
;;    DynalispPrefCustomBase custom dictionary before a DynALisp one was made current,
;;                          made current again when it is not used
;;
;;  On, the DynALisp profile (Options > Profiles) is made current. It is made once, as a
;;  copy of the profile current then (DynalispPrefBase, made current again when it is
;;  turned off). Its main dictionary (Files tab, DCTMAIN) is the one of the language, the
;;  English one when AutoCAD has none for it (Support\<code>.dct, see *fp:langs*). Its
;;  paths are the ones of Res\FilePrefs.csv matching the preferences:
;;    Setting;Classification;Units;Language;Value
;;  Setting: Files:<property> - an option of the Files tab (TemplateDwgPath, QNewTemplateFile...)
;;           Reg:<key>|<value>[,<value>...] - values of the profile in the registry, the
;;             AEC options of AutoCAD Architecture (Preferences\AecGuiBase80|SILocationRoot...)
;;           Aec:<key>|<value>[,<value>...] - AutoCAD Architecture options shared by every
;;             profile (AEC\<version> key: General\Tools|ToolContentRoot, the tool catalog
;;             content root path), read by AutoCAD Architecture when it starts
;;           Db:Components, Db:Keynotes - the current detail component or keynote database
;;             (Configure Detail Component / Keynote Databases): one not registered in
;;             AutoCAD Architecture yet is added to its list
;;  Classification, Units, Language: the preference key the row is for, * or empty: any.
;;  Value: a path (several: separated by ;). {ACA} is the AutoCAD Architecture content
;;    folder of the language (C:\ProgramData\Autodesk\ACA 2027\enu or fra), {ACA*} the
;;    content folder of each language installed, the one of the language first (a
;;    database missing from its content is found in the other one), {DYL} the Res
;;    folder of the module, {DYLU} its user copy (User\...\Res): the file is copied
;;    there from its default the first time, for a file AutoCAD writes to (the words
;;    added to a custom dictionary). A file name can have * and ? (AecDtlComponents*.mdb):
;;    the first file of the folder that matches.
;;  For each setting, the first row that matches and whose path exists is used: the next
;;  rows are its fallbacks. A setting no row matches is left as the profile has it.
;;
;;  The profile is set by Dyl-Settings (Save) and Dyl-SetFilePrefs. AutoCAD keeps it
;;  current for the next sessions. Every drawing opened only checks it (Remote>>Dyl:PrefApply,
;;  run by dynalisp.mnl) and tells to run Dyl-SetFilePrefs when it is not current, or when
;;  the preferences or the file changed since it was set (DynalispPrefApplied). It sets
;;  the main dictionary of the language though, in whichever profile is current.
;;
;;  Use in an App:
;;    (Remote>>Dyl:PrefGet "Units")  -> "Metric"
;;    (Remote>>Dyl:PrefApply T)      -> sets the DynALisp profile now, returns a status line

(vl-load-com)

;;  Preferences: (what label ((key label) ...)), the first choice is the default (the
;;  language of AutoCAD for the language):
(setq *fp:prefs*   '(("Class" "AEC library classification"
                      (("CAWS" "NBS CAWS (Global)") ("MasterFormat" "CSI MasterFormat (US)") ("OmniClass" "OmniClass"))
                     )
                     ("Units" "Drawing units" (("Metric" "Metric (Global)") ("Imperial" "Imperial (US)")))
                     ("Language"
                      "Language"
                      (("English" "English")
                       ("French" "French")
                       ("Chinese-Simplified" "Chinese (Simplified)")
                       ("Chinese-Traditional" "Chinese (Traditional)")
                       ("Czech" "Czech")
                       ("German" "German")
                       ("Hungarian" "Hungarian")
                       ("Italian" "Italian")
                       ("Japanese" "Japanese")
                       ("Korean" "Korean")
                       ("Polish" "Polish")
                       ("Portuguese" "Portuguese (Brazil)")
                       ("Russian" "Russian")
                       ("Spanish" "Spanish")
                      )
                     )
                    )
      *fp:profile* "DynALisp"
      ;;  Changed when the way the profile is set changes: every profile is set again
      ;;  (2: the detail databases are registered under the id of their file, 3: the main
      ;;  dictionary of the language):
      *fp:version* "3"
      ;;  Each language AutoCAD is installed in: (language code lcid). code is the folder
      ;;  of the language in the AutoCAD Architecture content and the name of its main
      ;;  dictionary (Support\<code>.dct, none for chs, cht, hun, jpn, kor and plk); lcid
      ;;  ends the product key of the AutoCAD of the language (...\ACAD-A101:40C):
      *fp:langs*   '(("English" "enu" "409")
                     ("French" "fra" "40C")
                     ("Chinese-Simplified" "chs" "804")
                     ("Chinese-Traditional" "cht" "404")
                     ("Czech" "csy" "405")
                     ("German" "deu" "407")
                     ("Hungarian" "hun" "40E")
                     ("Italian" "ita" "410")
                     ("Japanese" "jpn" "411")
                     ("Korean" "kor" "412")
                     ("Polish" "plk" "415")
                     ("Portuguese" "ptb" "416")
                     ("Russian" "rus" "419")
                     ("Spanish" "esp" "40A")
                    )
)

;;-------------------------=={ Preferences }==------------------------;;

;;  Choices of the preference what: ((key label) ...)
(defun Remote>>Dyl:PrefChoices (what) (caddr (assoc what *fp:prefs*)))

;;  Key of the preference what ("Class", "Units" or "Language"), its default when not set:
(defun Remote>>Dyl:PrefGet (what / key)
  (setq key (getenv (strcat "DynalispPref" what)))
  (cond
    ((assoc key (Remote>>Dyl:PrefChoices what)) key)
    ((and (= "Language" what)
          (setq key (car (vl-some '(lambda (l) (if (wcmatch (strcase (vlax-product-key)) (strcat "*:" (caddr l))) l)) *fp:langs*)))
     )
     key
    )
    ((car (car (Remote>>Dyl:PrefChoices what))))
  )
)

(defun Remote>>Dyl:PrefSet (what key)
  (setenv (strcat "DynalispPref" what) key)
)

;;  T when AutoCAD uses the DynALisp profile (off by default):
(defun Remote>>Dyl:PrefOn-p ()
  (= "1" (getenv "DynalispPrefProfile"))
)

;;  The labels of the preferences: "NBS CAWS (Global), Metric (Global), English"
(defun Remote>>Dyl:PrefLabel ()
  (Remote>>LM:lst->str (mapcar '(lambda (p) (cadr (assoc (Remote>>Dyl:PrefGet (car p)) (caddr p)))) *fp:prefs*) ", ")
)

;;  Paths of the preferences (its user copy when there is one):
(defun Remote>>Dyl:PrefFile ()
  (Dyl:UserFile (strcat *dyl:dyl "\\Res\\FilePrefs.csv"))
)

;;  What the profile was set from: the preferences, the version and the time of the file:
(defun Remote>>Dyl:PrefStamp ()
  (strcat (Remote>>LM:lst->str (mapcar '(lambda (p) (Remote>>Dyl:PrefGet (car p))) *fp:prefs*) "|")
          "|"
          *fp:version*
          "|"
          (vl-princ-to-string (vl-file-systime (Remote>>Dyl:PrefFile)))
  )
)

;;-------------------------=={ Paths }==------------------------;;

;;  AutoCAD Architecture content folder of the language lang ({ACA}): the folder of the
;;  language next to the one of the AEC content of the profile name (...\ACA 2027\enu\AEC
;;  Content -> ...\ACA 2027\fra), nil when there is none (AutoCAD without Architecture):
(defun Remote>>Dyl:PrefContent (name lang / dir)
  (if
    (and (setq dir (vl-registry-read (strcat (Remote>>Dyl:PrefKey name) "\\Preferences\\AecDcArch80") "DCAecContentRoot"))
         (/= "" dir)
         (setq dir (vl-filename-directory (vl-filename-directory (vl-string-right-trim "\\" dir))))
         (vl-file-directory-p (setq dir (strcat dir "\\" (cadr (assoc lang *fp:langs*)))))
    )
    dir
  )
)

;;  Content folders of every language installed ({ACA*}), the one of lang first:
(defun Remote>>Dyl:PrefContents (name lang)
  (vl-remove nil
             (mapcar '(lambda (l) (Remote>>Dyl:PrefContent name l))
                     (cons lang (vl-remove lang (mapcar 'car *fp:langs*)))
             )
  )
)

(defun Remote>>Dyl:PrefSubst (val tok new)
  (while (vl-string-search tok val) (setq val (vl-string-subst new tok val)))
  val
)

;;  User copy of the file path under Contents ({DYLU}), copied from path the first time
;;  (the path itself when it is not under Contents or cannot be copied):
(defun Remote>>Dyl:PrefUserCopy (path / usr)
  (setq usr (Dyl:UserFileW path))
  (if (and (not (findfile usr)) (findfile path)) (vl-file-copy path usr))
  (if (findfile usr) usr path)
)

;;  Paths to try for the value val of FilePrefs.csv, aca the {ACA} folder, acas the
;;  {ACA*} folders: one path per content folder for {ACA*}, none when it uses {ACA} and
;;  aca is nil:
(defun Remote>>Dyl:PrefExpand (val aca acas / lst)
  (setq lst (cond
              ((vl-string-search "{ACA*}" val) (mapcar '(lambda (a) (Remote>>Dyl:PrefSubst val "{ACA*}" a)) acas))
              ((vl-string-search "{ACA}" val) (if aca (list (Remote>>Dyl:PrefSubst val "{ACA}" aca))))
              ((list val))
            )
  )
  (mapcar '(lambda (v)
             (if (vl-string-search "{DYLU}" v)
               (Remote>>Dyl:PrefUserCopy (Remote>>Dyl:PrefSubst v "{DYLU}" (strcat *dyl:dyl "\\Res")))
               (Remote>>Dyl:PrefSubst v "{DYL}" (strcat *dyl:dyl "\\Res"))
             )
           )
          lst
  )
)

;;  The path val when it exists, nil when not. A file name with * or ? is the first file
;;  of its folder that matches it (AecDtlComponents*.mdb):
(defun Remote>>Dyl:PrefResolve (val / pos pat dir fnd)
  (setq pos (vl-string-position 92 val nil T))
  (cond
    ((and pos
          (not (vl-string-search ";" val))
          (setq pat (substr val (+ 2 pos)))
          (or (vl-string-search "*" pat) (vl-string-search "?" pat))
     )
     (setq dir (substr val 1 pos))
     (if (and (vl-file-directory-p dir) (setq fnd (vl-directory-files dir pat 1)))
       (strcat dir "\\" (car (vl-sort fnd '<)))
     )
    )
    ((Remote>>Dyl:PrefExists-p val) val)
  )
)

;;  T when every path of val (separated by ;) is a folder or a file:
(defun Remote>>Dyl:PrefExists-p (val / lst)
  (and (setq lst (vl-remove "" (mapcar '(lambda (p) (vl-string-trim " " p)) (Remote>>LM:str->lst val ";"))))
       (vl-every '(lambda (p) (setq p (vl-string-right-trim "\\" p)) (or (vl-file-directory-p p) (findfile p))) lst)
  )
)

;;  T when the cell of a row (* or empty: any) matches the preference key:
(defun Remote>>Dyl:PrefMatch-p (cell key)
  (or (= "" cell) (wcmatch (strcase key) (strcase cell)))
)

;;  Paths of the preferences, aca the {ACA} folder, acas the {ACA*} folders, only the
;;  setting only when not nil (in upper case: "FILES:CUSTOMDICTIONARY"):
;;  (((SETTING setting value) ...) missing), the first row of each setting that matches
;;  and whose path exists (SETTING in upper case), and the settings that matched with no
;;  path found:
(defun Remote>>Dyl:PrefTargets (aca acas only / keys nam res wanted val)
  (setq keys (mapcar '(lambda (p) (Remote>>Dyl:PrefGet (car p))) *fp:prefs*))
  (foreach r (Remote>>Dyl:CsvRead (Remote>>Dyl:PrefFile) 5)
    (setq nam (strcase (car r)))
    (if
      (and (/= "" nam)
           (or (not only) (= only nam))
           (not (assoc nam res))
           (vl-every 'Remote>>Dyl:PrefMatch-p (list (nth 1 r) (nth 2 r) (nth 3 r)) keys)
      )
      (progn
        (if (not (member nam wanted)) (setq wanted (cons nam wanted)))
        (if (setq val (vl-some 'Remote>>Dyl:PrefResolve (Remote>>Dyl:PrefExpand (nth 4 r) aca acas)))
          (setq res (cons (list nam (car r) val) res))
        )
      )
    )
  )
  (list (reverse res) (vl-remove-if '(lambda (s) (assoc s res)) (reverse wanted)))
)

;;-------------------------=={ Main dictionary }==------------------------;;

;;  Main dictionary of the language lang (DCTMAIN): its code when AutoCAD has the
;;  dictionary (<code>.dct in the support path or the Support folder of AutoCAD), else
;;  "enu" (American English):
(defun Remote>>Dyl:PrefDictionary (lang / code)
  (if
    (and (setq code (cadr (assoc lang *fp:langs*)))
         (or (findfile (strcat code ".dct"))
             (findfile (strcat (vla-get-Path (vlax-get-acad-object)) "\\Support\\" code ".dct"))
         )
    )
    code
    "enu"
  )
)

;;  T when the DynALisp custom dictionaries are used (Dyl-Settings, off by default):
(defun Remote>>Dyl:PrefCustomOn-p ()
  (= "1" (getenv "DynalispPrefCustomDict"))
)

(defun Remote>>Dyl:PrefCustomSet (on)
  (setenv "DynalispPrefCustomDict" (if on "1" "0"))
)

;;  T when the custom dictionary path is a DynALisp one (Res\Dictionaries, or its user copy):
(defun Remote>>Dyl:PrefCustomOwn-p (path / dir)
  (setq dir (strcat *dyl:dyl "\\Res\\Dictionaries"))
  (and (/= "" path)
       (member (strcase (vl-filename-directory path))
               (mapcar 'strcase (vl-remove nil (list dir (Dyl:UserPath dir))))
       )
  )
)

;;  DynALisp custom dictionary of the preferences: the Files:CustomDictionary row of
;;  FilePrefs.csv that matches and whose file exists, nil when they are not used or the
;;  language has none:
(defun Remote>>Dyl:PrefCustom ()
  (if (and Remote>>Dyl:CsvRead (Remote>>Dyl:PrefCustomOn-p))
    (caddr (car (car (Remote>>Dyl:PrefTargets nil nil "FILES:CUSTOMDICTIONARY"))))
  )
)

;;  Make the dictionaries of the preferences current (kept by the current profile): the
;;  main dictionary of the language (DCTMAIN), and the DynALisp custom dictionary of the
;;  language when there is one (DCTCUST, see Remote>>Dyl:PrefCustom). Without one, a
;;  DynALisp custom dictionary current is replaced by the one it replaced
;;  (DynalispPrefCustomBase), else by the sample.cus of AutoCAD; another one is left as it
;;  is. Returns the code of the main dictionary. Unlike the profile, they are set in every
;;  drawing opened: a shortcut starting AutoCAD with another profile
;;  (/p "AutoCAD Architecture (Global)") would leave the dictionaries of that profile:
(defun Remote>>Dyl:PrefDictionarySet (/ dct cus cur old)
  (setq dct (Remote>>Dyl:PrefDictionary (Remote>>Dyl:PrefGet "Language"))
        cur (getvar "DCTCUST")
  )
  (if (/= (strcase (getvar "DCTMAIN")) (strcase dct))
    (vl-catch-all-apply 'setvar (list "DCTMAIN" dct))
  )
  (cond
    ((setq cus (Remote>>Dyl:PrefCustom))
     (if (not (Remote>>Dyl:PrefCustomOwn-p cur)) (setenv "DynalispPrefCustomBase" cur))
     (if (/= (strcase cur) (strcase cus)) (vl-catch-all-apply 'setvar (list "DCTCUST" cus)))
    )
    ((and (Remote>>Dyl:PrefCustomOwn-p cur)
          (setq old (cond
                      ((and (setq old (getenv "DynalispPrefCustomBase")) (findfile old)))
                      ((findfile "sample.cus"))
                    )
          )
     )
     (vl-catch-all-apply 'setvar (list "DCTCUST" old))
    )
  )
  dct
)

;;-------------------------=={ Detail databases }==------------------------;;

;;  Registry key of the AutoCAD Architecture options shared by every profile of this
;;  AutoCAD (HKCU\<product>\AEC\<version>, the latest version), nil when there is none
;;  (AutoCAD without Architecture):
(defun Remote>>Dyl:PrefAecRoot (/ aec)
  (setq aec (strcat "HKEY_CURRENT_USER\\" (vlax-product-key) "\\AEC"))
  (vl-some '(lambda (v) (if (vl-registry-descendents (strcat aec "\\" v)) (strcat aec "\\" v)))
           (reverse (vl-sort (vl-registry-descendents aec) '<))
  )
)

;;  Write val to the registry values of spec ("<key>|<value>[,<value>...]", key under
;;  base). T when written, nil when there is no base or no "|":
(defun Remote>>Dyl:PrefWrite (base spec val / p)
  (if (and base (setq p (vl-string-position (ascii "|") spec)))
    (progn
      (foreach nam (Remote>>LM:str->lst (substr spec (+ 2 p)) ",")
        (vl-registry-write (strcat base "\\" (vl-string-trim "\\ " (substr spec 1 p))) (vl-string-trim " " nam) val)
      )
      T
    )
  )
)

;;  Registry list of the detail databases of kind ("Components" or "Keynotes") of
;;  AutoCAD Architecture (AEC\<version>\AecRcpBase80\Databases\<kind>), nil when there
;;  is none:
(defun Remote>>Dyl:PrefDbList (kind / aec)
  (if (setq aec (Remote>>Dyl:PrefAecRoot))
    (strcat aec "\\AecRcpBase80\\Databases\\" kind)
  )
)

;;  T when the database entry key (registry) is the database path:
(defun Remote>>Dyl:PrefDbAt-p (key path / loc)
  (and (setq loc (vl-registry-read key "DatabaseLocation")) (= (strcase loc) (strcase path)))
)

;;  Id under which the list lst registers the database path, nil when it does not:
(defun Remote>>Dyl:PrefDbFind (lst path)
  (vl-some '(lambda (k) (if (Remote>>Dyl:PrefDbAt-p (strcat lst "\\" k) path) k)) (vl-registry-descendents lst))
)

;;  Id of the database path in the list of another AutoCAD (another language or release)
;;  than the list own, nil when none registers it:
(defun Remote>>Dyl:PrefDbKnown (kind path own / root lst res)
  (setq root "HKEY_CURRENT_USER\\Software\\Autodesk\\AutoCAD")
  (foreach rel (vl-registry-descendents root)
    (foreach prd (vl-registry-descendents (strcat root "\\" rel))
      (foreach ver (vl-registry-descendents (strcat root "\\" rel "\\" prd "\\AEC"))
        (setq lst (strcat root "\\" rel "\\" prd "\\AEC\\" ver "\\AecRcpBase80\\Databases\\" kind))
        (if (and (not res) (not (Remote>>Dyl:PrefIs-p lst own)))
          (setq res (Remote>>Dyl:PrefDbFind lst path))
        )
      )
    )
  )
  res
)

;;  The string s in single quotes for PowerShell (' doubled):
(defun Remote>>Dyl:PrefPsQuote (s / i)
  (setq i 0)
  (while (setq i (vl-string-search "'" s i))
    (setq s (vl-string-subst "''" "'" s i)
          i (+ i 2)
    )
  )
  (strcat "'" s "'")
)

;;  Id written inside the database file path of kind: AutoCAD Architecture knows a
;;  database by it, a database registered under another id is not used. It is the
;;  {GUID} next to the word Component (or Keynote), read by PowerShell (the file is
;;  binary). Kept for the session in *fp:guids*. nil when it cannot be read:
(defun Remote>>Dyl:PrefDbFileGuid (kind path / w tmp wsh des res)
  (cond
    ((cdr (assoc (strcase path) *fp:guids*)))
    ((setq w   (if (= "KEYNOTES" (strcase kind)) "Keynote" "Component")
           tmp (vl-filename-mktemp "dylguid.txt")
           wsh (vlax-create-object "WScript.Shell")
     )
     (vl-catch-all-apply
       'vlax-invoke-method
       (list wsh
             'Run
             (strcat "powershell.exe -NoProfile -NonInteractive -Command \""
                     "$t=[IO.File]::ReadAllText(" (Remote>>Dyl:PrefPsQuote path) ",[Text.Encoding]::GetEncoding(28591));"
                     "$g='\\{[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}\\}';"
                     "$m=[regex]::Match($t,'(?<=" w "[\\s\\S]{0,12})'+$g+'|'+$g+'(?=[\\s\\S]{0,60}" w ")');"
                     "[IO.File]::WriteAllText(" (Remote>>Dyl:PrefPsQuote tmp) ",$m.Value)\""
             )
             0
             :vlax-true
       )
     )
     (vlax-release-object wsh)
     (if (setq des (open tmp "r"))
       (progn
         (setq res (read-line des))
         (close des)
       )
     )
     (vl-file-delete tmp)
     (if (and res (wcmatch res "{????????-????-????-????-????????????}"))
       (progn
         (setq *fp:guids* (cons (cons (strcase path) res) *fp:guids*))
         res
       )
     )
    )
  )
)

;;  Id of the detail database path of kind, the one of the file (else the one another
;;  AutoCAD registers it under), added to the list of AutoCAD Architecture when it is
;;  not there. An entry of the same file under another id is removed (made up by a
;;  previous version: AutoCAD Architecture ignores it). nil when there is no list
;;  (AutoCAD without Architecture) or no id:
(defun Remote>>Dyl:PrefDbGuid (kind path / lst g)
  (if
    (and (setq lst (Remote>>Dyl:PrefDbList kind))
         (setq g (cond
                   ((Remote>>Dyl:PrefDbFileGuid kind path))
                   ((Remote>>Dyl:PrefDbKnown kind path lst))
                   ((Remote>>Dyl:PrefDbFind lst path))
                 )
         )
    )
    (progn
      (foreach k (vl-registry-descendents lst)
        (if (and (not (Remote>>Dyl:PrefIs-p k g)) (Remote>>Dyl:PrefDbAt-p (strcat lst "\\" k) path))
          (vl-registry-delete (strcat lst "\\" k))
        )
      )
      (cond
        ((vl-some '(lambda (k) (if (Remote>>Dyl:PrefIs-p k g) k)) (vl-registry-descendents lst)))
        (T
         (vl-registry-write (strcat lst "\\" g) "DatabaseLocation" path)
         g
        )
      )
    )
  )
)

;;-------------------------=={ Profile }==------------------------;;

(defun Remote>>Dyl:PrefProfiles ()
  (vla-get-Profiles (vla-get-Preferences (vlax-get-acad-object)))
)

;;  Registry key of the profile name:
(defun Remote>>Dyl:PrefKey (name)
  (strcat "HKEY_CURRENT_USER\\" (vlax-product-key) "\\Profiles\\" name)
)

;;  Names of the profiles of prf:
(defun Remote>>Dyl:PrefNames (prf / var)
  (vla-GetAllProfileNames prf 'var)
  (if (= 'VARIANT (type var)) (setq var (vlax-variant-value var)))
  (if (= 'SAFEARRAY (type var)) (vlax-safearray->list var))
)

(defun Remote>>Dyl:PrefIs-p (a b)
  (= (strcase a) (strcase b))
)

;;  Profile made current while the DynALisp profile is written, or when it is turned off:
;;  the one it was made from, else another one, else a copy of it:
(defun Remote>>Dyl:PrefBase (prf / names base)
  (setq names (vl-remove-if '(lambda (n) (Remote>>Dyl:PrefIs-p n *fp:profile*)) (Remote>>Dyl:PrefNames prf))
        base  (getenv "DynalispPrefBase")
  )
  (cond
    ((and base (vl-some '(lambda (n) (Remote>>Dyl:PrefIs-p n base)) names)) base)
    ((car names))
    (T
     (vla-CopyProfile prf *fp:profile* (strcat *fp:profile* " (Base)"))
     (strcat *fp:profile* " (Base)")
    )
  )
)

;;  Turn the DynALisp profile on or off (saved for every drawing). Off, the profile it was
;;  made from is made current again; on, it is set by Remote>>Dyl:PrefApply:
(defun Remote>>Dyl:PrefProfileSet (on / prf)
  (setenv "DynalispPrefProfile" (if on "1" "0"))
  (setq prf (Remote>>Dyl:PrefProfiles))
  (if (and (not on) (Remote>>Dyl:PrefIs-p (vla-get-ActiveProfile prf) *fp:profile*))
    (vla-put-ActiveProfile prf (Remote>>Dyl:PrefBase prf))
  )
)

;;  Make the DynALisp profile current with the paths of the preferences, when it is on
;;  (force T, from a command). Without force (a drawing opened) it is only checked: a
;;  profile made current while a drawing opens reloads the menus of every drawing, runs
;;  their startup again and can stop AutoCAD with an unknown exception. The registry
;;  values are written while it is not current: AutoCAD keeps the current profile in
;;  memory and reads a profile again when it is made current. Returns a status line, nil
;;  when it is off:
(defun Remote>>Dyl:PrefApply (force / prf act aca tgt key g n dct)
  (setq prf (Remote>>Dyl:PrefProfiles)
        act (vla-get-ActiveProfile prf)
  )
  ;;  Checked only, the profile still gets the main dictionary of the language:
  (if (and (not force) (Remote>>Dyl:PrefOn-p)) (Remote>>Dyl:PrefDictionarySet))
  (cond
    ((not (Remote>>Dyl:PrefOn-p)) nil)
    ((and (not force) (not (Remote>>Dyl:PrefIs-p act *fp:profile*)))
     (strcat "--> the current profile is " act ", run Dyl-SetFilePrefs to make the " *fp:profile* " profile current")
    )
    ((and (not force) (/= (getenv "DynalispPrefApplied") (Remote>>Dyl:PrefStamp)))
     (strcat *fp:profile*
             " profile, --> the preferences or FilePrefs.csv changed, run Dyl-SetFilePrefs to set it again"
     )
    )
    ((not force) (strcat *fp:profile* " profile, " (Remote>>Dyl:PrefLabel)))
    (T
     (if (not (Remote>>Dyl:PrefIs-p act *fp:profile*))
       (progn
         (if (not (vl-some '(lambda (n) (Remote>>Dyl:PrefIs-p n *fp:profile*)) (Remote>>Dyl:PrefNames prf)))
           (vla-CopyProfile prf act *fp:profile*)
         )
         (setenv "DynalispPrefBase" act)
       )
       (vla-put-ActiveProfile prf (Remote>>Dyl:PrefBase prf))
     )
     (setq aca (Remote>>Dyl:PrefContent *fp:profile* (Remote>>Dyl:PrefGet "Language"))
           tgt (Remote>>Dyl:PrefTargets aca (Remote>>Dyl:PrefContents *fp:profile* (Remote>>Dyl:PrefGet "Language")) nil)
           key (Remote>>Dyl:PrefKey *fp:profile*)
           n   0
     )
     (foreach x (car tgt)
       (cond
         ((and (wcmatch (car x) "REG:*") (Remote>>Dyl:PrefWrite key (substr (cadr x) 5) (caddr x)))
          (setq n (1+ n))
         )
         ((and (wcmatch (car x) "AEC:*") (Remote>>Dyl:PrefWrite (Remote>>Dyl:PrefAecRoot) (substr (cadr x) 5) (caddr x)))
          (setq n (1+ n))
         )
         ((and (wcmatch (car x) "DB:*") (setq g (Remote>>Dyl:PrefDbGuid (substr (cadr x) 4) (caddr x))))
          (vl-registry-write (strcat key "\\Defaults\\AecRcpBase80\\Databases\\" (substr (cadr x) 4)) "Current" g)
          (setq n (1+ n))
         )
       )
     )
     (vla-put-ActiveProfile prf *fp:profile*)
     ;;  The options of the Files tab, set in the current profile (the custom dictionary
     ;;  by Remote>>Dyl:PrefDictionarySet, which can turn it off):
     (foreach x (car tgt)
       (if
         (and (wcmatch (car x) "FILES:*")
              (/= "FILES:CUSTOMDICTIONARY" (car x))
              (not
                (vl-catch-all-error-p
                  (vl-catch-all-apply 'vlax-put-property
                                      (list (vla-get-Files (vla-get-Preferences (vlax-get-acad-object)))
                                            (substr (cadr x) 7)
                                            (caddr x)
                                      )
                  )
                )
              )
         )
         (setq n (1+ n))
       )
     )
     ;;  The main dictionary of the language, also a Files tab option:
     (setq dct (Remote>>Dyl:PrefDictionarySet))
     (setenv "DynalispPrefApplied" (Remote>>Dyl:PrefStamp))
     (strcat *fp:profile*
             " profile set, "
             (Remote>>Dyl:PrefLabel)
             " ("
             (itoa n)
             " path(s), main dictionary "
             (getvar "DCTMAIN")
             (if (and (= "enu" dct) (/= "English" (Remote>>Dyl:PrefGet "Language")))
               " (none for the language)"
               ""
             )
             (if (Remote>>Dyl:PrefCustomOwn-p (getvar "DCTCUST"))
               (strcat ", custom dictionary " (vl-filename-base (getvar "DCTCUST")))
               ""
             )
             (if aca "" ", no AutoCAD Architecture content for the language")
             (if (cadr tgt) (strcat ", not found: " (Remote>>LM:lst->str (cadr tgt) ", ")) "")
             ")"
     )
    )
  )
)

(princ)
