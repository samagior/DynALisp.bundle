;; Dyl-Diagnostics - Reports what DynALisp, AutoCAD and the drawing are doing, to find a problem
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

;;  Each section (dg:sections) checks one part and adds its lines to the report: what it
;;  found, and the problems ("[!]" lines, also listed at the top of the report). A section
;;  run alone writes %TEMP%\DynALisp Diagnostics\<section>.txt and opens it in the text
;;  editor; Dyl-Diagnostics runs them all into a DynALisp Report <date> folder of %TEMP%,
;;  with the DynALisp settings and the User folder, zips it, and offers to open a GitHub
;;  issue on the releases repository (*dyl:relrepo*) to send it. Nothing is printed on the
;;  command line but what to do next.
;;
;;  The reports never hold the user's profile folder, user name or computer name: they are
;;  replaced by %USERPROFILE%, %USERNAME% and %COMPUTERNAME% (dg:anon), since the issue is
;;  public.
;;
;;  The startup keeps what it did for these reports (dyl:startup in dynalisp.mnl):
;;  *dyl:startms*, *dyl:startwarn*, *dyl:startnote*, *dyl:loaderrs*, *dyl:loadtimes*.
;;  A tool that adds a startup step, a reactor, a data file or a setting adds its check here.

(vl-load-com)

;;-------------------------=={ Report }==------------------------;;

;;  dg:out   - lines of the report, last first
;;  dg:probs - problems found ("Section: text"), last first
;;  dg:sect  - the section running

(defun dg:str (x)
  (cond
    ((= 'STR (type x)) x)
    ((null x) "-")
    ((vl-princ-to-string x))
  )
)

(defun dg:add (s) (setq dg:out (cons s dg:out)))
(defun dg:kv (k v) (dg:add (strcat "  " k ": " (dg:str v))))
(defun dg:sub (s) (dg:add (strcat "  -- " s)))
(defun dg:item (s) (dg:add (strcat "     " (dg:str s))))
(defun dg:note (s) (dg:add (strcat "  [i] " s)))

;;  A problem: in its section, and in the list at the top of the report:
(defun dg:bad (s)
  (setq dg:probs (cons (strcat dg:sect ": " s) dg:probs))
  (dg:add (strcat "  [!] " s))
)

;;  Run a check f (a function without arguments): an error is reported and the next
;;  checks run:
(defun dg:try (f / r)
  (if (vl-catch-all-error-p (setq r (vl-catch-all-apply f nil)))
    (dg:bad (strcat "check " (dg:str f) " stopped: " (vl-catch-all-error-message r)))
  )
)

(defun dg:pad (n) (if (< n 10) (strcat "0" (itoa n)) (itoa n)))

(defun dg:now () (menucmd "M=$(edtime,$(getvar,date),YYYY-MO-DD HH:MM:SS)"))

;;  Date of a file ("2026-11-13 14:05"), nil when it is missing:
(defun dg:date (f / tm)
  (if (setq tm (vl-file-systime f))
    (strcat (itoa (nth 0 tm)) "-" (dg:pad (nth 1 tm)) "-" (dg:pad (nth 3 tm)) " " (dg:pad (nth 4 tm)) ":"
            (dg:pad (nth 5 tm))
    )
  )
)

;;  str with every old replaced by new, ignoring case:
(defun dg:repl (str old new / u o p i)
  (if (and str old (/= "" old))
    (progn
      (setq u (strcase str)
            o (strcase old)
            i 0
      )
      (while (setq p (vl-string-search o u i))
        (setq str (strcat (substr str 1 p) new (substr str (+ p 1 (strlen old))))
              u   (strcat (substr u 1 p) (strcase new) (substr u (+ p 1 (strlen old))))
              i   (+ p (strlen new))
        )
      )
    )
  )
  str
)

;;  str without the profile folder (also its short form, C:\Users\SMARTI~1), the user
;;  name and the computer name:
(defun dg:anon (str / tmp p)
  (setq str (dg:repl str (getenv "USERPROFILE") "%USERPROFILE%"))
  (if (and (setq tmp (getenv "TEMP")) (setq p (vl-string-search "\\APPDATA\\" (strcase tmp))))
    (setq str (dg:repl str (substr tmp 1 p) "%USERPROFILE%"))
  )
  (foreach v '("USERNAME" "COMPUTERNAME")
    (if (and (setq tmp (getenv v)) (< 2 (strlen tmp))) (setq str (dg:repl str tmp (strcat "%" v "%"))))
  )
  str
)

;;  Write lines to the file pth (UTF-8 when AutoCAD can), anonymized. Returns pth, nil
;;  when it could not be written:
(defun dg:write (pth lines / f)
  (if (vl-catch-all-error-p (setq f (vl-catch-all-apply 'open (list pth "w" "utf8")))) (setq f (open pth "w")))
  (if f
    (progn
      (foreach l lines (write-line (dg:anon l) f))
      (close f)
      pth
    )
  )
)

;;  Lines of a text file (at most n, nil: all), nil when it cannot be read:
(defun dg:lines (file n / des s lst)
  (if (and file (findfile file) (setq des (open file "r")))
    (progn
      (while (and (setq s (read-line des)) (or (not n) (< (length lst) n))) (setq lst (cons s lst)))
      (close des)
      (reverse lst)
    )
  )
)

;;  Open a file, folder or URL in its default program (a .txt in the text editor):
(defun dg:open (target / sh)
  (if (setq sh (vlax-create-object "Shell.Application"))
    (progn
      (vl-catch-all-apply 'vlax-invoke-method (list sh 'ShellExecute target "" "" "open" 1))
      (vlax-release-object sh)
    )
  )
)

;;  Run a command line hidden and wait for it. Returns its exit code, nil on an error:
(defun dg:run (cmd / sh r)
  (if (setq sh (vlax-create-object "WScript.Shell"))
    (progn
      (setq r (vl-catch-all-apply 'vlax-invoke-method (list sh 'Run cmd 0 :vlax-true)))
      (vlax-release-object sh)
      (if (not (vl-catch-all-error-p r)) r)
    )
  )
)

;;  Every file of dir and its sub-folders matching pat (the .git folder skipped):
(defun dg:files (dir pat / lst)
  (foreach f (vl-directory-files dir pat 1) (setq lst (cons (strcat dir "\\" f) lst)))
  (foreach s (vl-remove-if '(lambda (x) (member x '("." ".." ".git"))) (vl-directory-files dir nil -1))
    (setq lst (append lst (dg:files (strcat dir "\\" s) pat)))
  )
  lst
)

;;  path relative to root when it is under it:
(defun dg:rel (path root)
  (if (and root (= (strcase (strcat root "\\")) (strcase (substr path 1 (1+ (strlen root))))))
    (substr path (+ 2 (strlen root)))
    path
  )
)

(defun dg:split (str del) (vl-remove "" (Remote>>LM:str->lst (cond (str) ("")) del)))

;;  The command name of a Startup Suite or alias name, without C: and in capitals:
(defun dg:cmd (s)
  (setq s (strcase s))
  (if (= "C:" (substr s 1 2)) (substr s 3) s)
)

(defun dg:acad () (vlax-get-acad-object))
(defun dg:doc () (vla-get-ActiveDocument (vlax-get-acad-object)))

;;-------------------------=={ Shared facts }==------------------------;;

;;  Name and version of an application bundle folder (its PackageContents.xml):
(defun dg:pkg (dir / txt)
  (if (setq txt (dg:lines (strcat dir "\\PackageContents.xml") 40))
    (progn
      (setq txt (apply 'strcat (mapcar '(lambda (l) (strcat l " ")) txt)))
      (list (Dyl:InfoAfter txt " Name=") (Dyl:InfoAfter txt "AppVersion="))
    )
  )
)

;;  The folders AutoCAD loads application bundles from:
(defun dg:pluginroots ()
  (vl-remove-if-not
    'vl-file-directory-p
    (mapcar '(lambda (v) (strcat (cond ((getenv v)) ("?")) "\\Autodesk\\ApplicationPlugins"))
            '("APPDATA" "ProgramData" "ProgramFiles")
    )
  )
)

;;  Every application bundle installed: (path ...):
(defun dg:bundles (/ lst)
  (foreach r (dg:pluginroots)
    (foreach b (vl-remove-if '(lambda (x) (member x '("." ".."))) (vl-directory-files r nil -1))
      (setq lst (cons (strcat r "\\" b) lst))
    )
  )
  (reverse lst)
)

;;  The registry key of this AutoCAD (HKEY_CURRENT_USER\...\R26.0\ACAD-A104:409):
(defun dg:prodkey ()
  (if vlax-user-product-key (vlax-user-product-key) (vlax-product-key))
)

;;  Name of this AutoCAD product (AutoCAD Architecture 2027...):
(defun dg:product ()
  (cond
    ((vl-registry-read (strcat "HKEY_LOCAL_MACHINE\\" (vlax-product-key)) "ProductName"))
    ((vla-get-Name (dg:acad)))
  )
)

;;  The Lisp files of the AutoCAD Startup Suite (APPLOAD) of the active profile:
(defun dg:apploads (/ key n lst f)
  (setq key (strcat "HKEY_CURRENT_USER\\" (dg:prodkey) "\\Profiles\\" (getvar "CPROFILE") "\\Dialogs\\Appload\\Startup"))
  (if (setq n (vl-registry-read key "NumStartup"))
    (progn
      (setq n (if (= 'STR (type n)) (atoi n) n))
      (repeat n
        (if (setq f (vl-registry-read key (strcat (itoa n) "Startup"))) (setq lst (cons f lst)))
        (setq n (1- n))
      )
    )
  )
  lst
)

;;  The DynALisp command names (commands of the Startup Suite and aliases), capitals:
(defun dg:dylnames (/ rows lst)
  (setq rows (vl-catch-all-apply 'Dyl:Suite '(nil)))
  (if (listp rows)
    (foreach r rows
      (if (/= "" (nth 1 r)) (setq lst (cons (dg:cmd (nth 1 r)) lst)))
    )
  )
  (foreach a (Dyl:AliasRead) (setq lst (cons (car a) lst)))
  lst
)

;;  Entries of the draw order table of a block (model space, a layout), nil when none:
(defun dg:sortn (blk / s n)
  (if (not (vl-catch-all-error-p
             (setq s (vl-catch-all-apply 'vla-Item (list (vla-GetExtensionDictionary blk) "ACAD_SORTENTS")))
           )
      )
    (progn
      (setq n 0)
      (foreach p (entget (vlax-vla-object->ename s)) (if (= 331 (car p)) (setq n (1+ n))))
      n
    )
  )
)

;;-------------------------=={ DynALisp }==------------------------;;

;;  The git clone: "branch main, commit 1a2b3c4d5e", nil when it is not one:
(defun dg:git (/ head ref sha)
  (if (and (Dyl:InfoGit-p) (setq head (car (dg:lines (strcat *dyl:repo "\\.git\\HEAD") 1))))
    (if (= "ref: " (substr head 1 5))
      (progn
        (setq ref (substr head 6)
              sha (car (dg:lines (strcat *dyl:repo "\\.git\\" (vl-string-translate "/" "\\" ref)) 1))
        )
        (if (not sha)
          (foreach l (dg:lines (strcat *dyl:repo "\\.git\\packed-refs") nil)
            (if (and (< 41 (strlen l)) (= ref (substr l 42))) (setq sha (substr l 1 40)))
          )
        )
        (strcat "branch " (if (= "refs/heads/" (substr ref 1 11)) (substr ref 12) ref)
                ", commit " (if sha (substr sha 1 10) "?")
        )
      )
      (strcat "detached, commit " (substr head 1 10))
    )
  )
)

(defun dg:s-dynalisp ()
  (dg:try 'dg:dyl-install)
  (dg:try 'dg:dyl-startup)
  (dg:try 'dg:dyl-modules)
  (dg:try 'dg:dyl-assistant)
)

;;  The Assistant (Dyl-Assistant, DynALisp.Assistant.dll, AutoCAD 2016 and later) runs
;;  Claude Code, installed and signed in by the user: checked only when its command is
;;  turned on in the Startup Suite (Dyl:ClaudeInfo runs Claude Code twice, a second or two).
;;  Never the account or a token: whether it is signed in, and how.
(defun dg:dyl-assistant (/ info v)
  (if c:Dyl-Assistant
    (progn
      (dg:sub "Assistant")
      (cond
        ((not Dyl:ClaudeInfo)
         (if (< (atof (getvar "ACADVER")) 20.1)
           (dg:bad "Dyl-Assistant is turned on, but the Assistant needs AutoCAD 2016 or later")
           (dg:bad "Dyl-Assistant is turned on, but DynALisp.Assistant.dll is not loaded (blocked by SECURELOAD, missing, or failed to load: see the command line at startup)")
         )
        )
        ((= "" (cdr (assoc "path" (setq info (Dyl:ClaudeInfo)))))
         (dg:note "Claude Code is not installed: Dyl-Assistant offers to install it")
        )
        (T
         (dg:kv "Claude Code" (cdr (assoc "path" info)))
         (if (= "" (setq v (cdr (assoc "version" info))))
           (dg:bad "Claude Code does not run: install it again (Dyl-Assistant)")
           (dg:kv "Claude Code version" v)
         )
         (cond
           ((not (assoc "loggedIn" info)) (dg:note "Claude Code did not say whether it is signed in"))
           ((= "1" (cdr (assoc "loggedIn" info)))
            (dg:kv "Signed in" (strcat "yes (" (cdr (assoc "authMethod" info)) ")"))
           )
           ((dg:note "Claude Code is not signed in: Sign in in the Assistant palette"))
         )
        )
      )
      ;;  Claude Code bills ANTHROPIC_API_KEY instead of the subscription when it is set:
      (if (= "1" (cdr (assoc "apiKey" info)))
        (dg:note "ANTHROPIC_API_KEY is set: Claude Code uses that API key (billed by the API), not the Claude subscription")
      )
    )
  )
)

(defun dg:dyl-install (/ git ver lst res)
  (setq ver (Dyl:InfoVersion))
  (dg:kv "Version" ver)
  (dg:kv "Latest release"
         (cond
           ((eq 'NONE *dyl:latest*) "not found (offline?)")
           (*dyl:latest*)
           ("not checked in this drawing (Dyl-Info checks it)")
         )
  )
  (dg:kv "Installed" (if (setq git (dg:git)) (strcat "git clone, " git) "with the setup"))
  (dg:kv "Folder" *dyl:repo*)
  ;;  The docs open on the website, from the list of its pages (Resources\DocsPages.txt,
  ;;  Dyl:DocsPages); without it, only the pages of a git clone open:
  (if Dyl:DocsPages
    (if (Dyl:DocsPages)
      (dg:kv "Docs" (strcat *dyl:docsweb* " (" (itoa (length (Dyl:DocsPages))) " pages)"))
      (dg:bad "Resources\\DocsPages.txt is missing: the Open Docs buttons find only the pages of a git clone")
    )
  )
  ;;  The language of DynALisp, its docs (Language in Dyl-Settings, Dyl:Lang):
  (if Dyl:Lang
    (dg:kv "Docs language"
           (strcat (Dyl:Lang) (if (getenv "DynalispLanguage") "" " (not set: the language of AutoCAD)"))
    )
  )
  ;;  The ribbon, in the language of the AutoCAD installed (Dyl:LangDefault, its key), is
  ;;  translated by DynALisp.Ribbon.dll (AutoCAD 2025 and later; English in an older one):
  (if Dyl:LangDefault
    (dg:kv "Ribbon language"
           (if (< (atof (getvar "ACADVER")) 25.0)
             "English (AutoCAD older than 2025)"
             (strcat (Dyl:LangDefault) " (the language of AutoCAD)")
           )
    )
  )
  (if (and Dyl:LangAcad (/= "en" (Dyl:LangAcad)) (not Dyl:RibbonLang))
    (if (< (atof (getvar "ACADVER")) 25.0)
      (dg:note "The ribbon stays in English: DynALisp.Ribbon.dll needs AutoCAD 2025 or later")
      (dg:bad "The ribbon stays in English: DynALisp.Ribbon.dll is not loaded (blocked by SECURELOAD, missing, or failed to load: see the command line at startup)")
    )
  )
  ;;  The windows of DynALisp (Dyl-Settings...) are shown by DynALisp.Windows.dll (AutoCAD
  ;;  2015 and later, the Windows region of dynalisp.mnl):
  (cond
    (Dyl:Window)
    ((< (atof (getvar "ACADVER")) 20.0)
     (dg:bad "The windows of DynALisp cannot open: DynALisp.Windows.dll needs AutoCAD 2015 or later")
    )
    ((dg:bad "The windows of DynALisp cannot open: DynALisp.Windows.dll is not loaded (blocked by SECURELOAD, missing, or failed to load: see the command line at startup)"))
  )
  (if (not (vl-some '(lambda (r) (= (strcase r) (strcase (vl-filename-directory *dyl:repo))))
                    (dg:pluginroots)
           )
      )
    (dg:bad "DynALisp is not in an ApplicationPlugins folder of AutoCAD")
  )
  (if (/= (getenv "DynalispLastVersion") ver)
    (dg:note (strcat "Last version run: " (dg:str (getenv "DynalispLastVersion"))))
  )
  ;;  Another DynALisp would load its own files and commands over these ones:
  (foreach b (dg:bundles)
    (if (and (/= (strcase b) (strcase *dyl:repo)) (findfile (strcat b "\\Contents\\Resources\\DYLB.txt")))
      (dg:bad (strcat "Another DynALisp is installed: " b))
    )
  )
  (if (/= (strcase (vl-filename-directory (cond ((findfile "DYLB.txt")) ("?")))) (strcase *dyl:res))
    (dg:bad (strcat "The support path finds the DYLB.txt of another folder: " (dg:str (findfile "DYLB.txt"))))
  )
  (if (menugroup "DYNALISP")
    (dg:kv "Menu" "DynALisp.cuix loaded")
    (dg:bad "The DynALisp menu (DynALisp.cuix) is not loaded: no ribbon tab")
  )
  (if (findfile (strcat *dyl:repo "\\Import-Settings.txt"))
    (dg:note "Import-Settings.txt waits to be imported by the next startup")
  )
  (setq lst (if (vl-file-directory-p *dyl:user) (dg:files *dyl:user "*")))
  (dg:kv "User folder" (if lst (strcat (itoa (length lst)) " file(s) of your own") "none (every file is the default)"))
)

(defun dg:dyl-startup (/ lst tot)
  (dg:sub "Startup of this drawing")
  (dg:kv "Started" (if *dyl:started* "yes" "no"))
  (if (not *dyl:started*) (dg:bad "The DynALisp startup did not run in this drawing (S::STARTUP replaced?)"))
  (dg:kv "Time" (if *dyl:startms* (strcat (itoa *dyl:startms*) " ms") "not recorded"))
  (dg:kv "Commands / aliases" (strcat (dg:str *dyl:cmdcount*) " / " (dg:str *dyl:aliascount*)))
  (foreach w *dyl:startwarn* (dg:bad (strcat "Startup: " w)))
  (foreach n *dyl:startnote* (dg:note n))
  (foreach e (reverse *dyl:loaderrs*) (dg:bad (strcat "Load error: " e)))
  (if *dyl:loadtimes*
    (progn
      (setq tot (apply '+ (mapcar 'cdr *dyl:loadtimes*))
            lst (vl-sort *dyl:loadtimes* '(lambda (a b) (> (cdr a) (cdr b))))
      )
      (dg:kv "Remote and Reactor files"
             (strcat (itoa (length *dyl:loadtimes*)) " loaded in " (itoa tot) " ms, the slowest:")
      )
      (repeat (min 5 (length lst))
        (dg:item (strcat (itoa (cdar lst)) " ms  " (caar lst)))
        (setq lst (cdr lst))
      )
    )
  )
)

(defun dg:dyl-modules (/ n)
  (dg:sub "Modules (Lisp files)")
  (foreach m (vl-remove-if '(lambda (x) (wcmatch x "*.*")) (vl-directory-files *dyl:module nil -1))
    (dg:item
      (strcat m ":"
              (apply 'strcat
                     (mapcar '(lambda (f / d)
                                (setq d (strcat *dyl:module "\\" m "\\" f))
                                (strcat " " f " " (itoa (if (vl-file-directory-p d) (length (dg:files d "*.lsp")) 0)))
                              )
                             '("Apps" "Remote" "Reactor")
                     )
              )
      )
    )
  )
)

;;-------------------------=={ AutoCAD }==------------------------;;

(defun dg:s-autocad ()
  (dg:try 'dg:acad-product)
  (dg:try 'dg:acad-vars)
  (dg:try 'dg:acad-paths)
  (dg:try 'dg:acad-loaded)
)

(defun dg:acad-product (/ win bld prf names)
  (dg:kv "Product" (dg:product))
  (dg:kv "Version" (strcat (vla-get-Version (dg:acad)) ", ACADVER " (dg:str (getvar "ACADVER"))))
  (dg:kv "Registry key" (dg:prodkey))
  (dg:kv "Language" (strcat (dg:str (getvar "LOCALE")) ", " (dg:str (getvar "PLATFORM"))))
  (if (vl-some '(lambda (a) (wcmatch (strcase a) "AECBASE*")) (arx))
    (dg:note "AutoCAD Architecture or MEP objects are loaded (AEC)")
  )
  (setq win "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion"
        bld (vl-registry-read win "CurrentBuild")
  )
  (dg:kv "Windows"
         (strcat (if (and bld (<= 22000 (atoi bld))) "Windows 11" (dg:str (vl-registry-read win "ProductName")))
                 " " (dg:str (vl-registry-read win "DisplayVersion")) ", build " (dg:str bld)
         )
  )
  (setq prf (vla-get-Profiles (vla-get-Preferences (dg:acad))))
  (dg:kv "Profile" (vla-get-ActiveProfile prf))
  (if (not (vl-catch-all-error-p (vl-catch-all-apply 'vla-GetAllProfileNames (list prf 'names))))
    (dg:kv "Profiles" (Remote>>LM:lst->str (vlax-safearray->list names) ", "))
  )
)

;;  System variables that change how programs load and run:
(defun dg:acad-vars (/ v)
  (dg:sub "System variables")
  (foreach n '("SECURELOAD" "LISPSYS" "ACADLSPASDOC" "DEMANDLOAD" "SDI" "CMDECHO" "NOMUTT" "FILEDIA" "CMDDIA"
               "EXPERT" "SORTENTS" "MODEMACRO" "LOGFILEMODE" "TRUSTEDDOMAINS"
              )
    (dg:item (strcat n " = " (dg:str (getvar n))))
  )
  (if (= 1 (getvar "NOMUTT")) (dg:bad "NOMUTT is 1: AutoCAD hides its prompts (a program left it on)"))
  (if (= 0 (getvar "FILEDIA")) (dg:bad "FILEDIA is 0: the file dialogs are off"))
  (if (= 0 (getvar "CMDDIA")) (dg:note "CMDDIA is 0: some dialogs open at the command line"))
  (if (= 0 (getvar "SECURELOAD")) (dg:note "SECURELOAD is 0: AutoCAD loads programs from any folder"))
  (if (= 0 (getvar "ACADLSPASDOC")) (dg:note "ACADLSPASDOC is 0: acad.lsp is loaded in the first drawing only"))
)

(defun dg:acad-paths (/ lst seen)
  (dg:sub "Support file search path")
  (foreach p (dg:split (getenv "ACAD") ";")
    (cond
      ((member (strcase p) seen) (dg:bad (strcat "Listed twice in the support path: " p)))
      ((not (vl-file-directory-p p)) (dg:bad (strcat "Missing folder in the support path: " p)))
      ((dg:item p))
    )
    (setq seen (cons (strcase p) seen))
  )
  (dg:sub "Trusted locations")
  (foreach p (dg:split (getvar "TRUSTEDPATHS") ";") (dg:item p))
  (dg:sub "Startup Lisp files")
  (foreach f '("acad.lsp" "acaddoc.lsp" "acad.pgp" "acad.mnl")
    (dg:item (strcat f ": " (cond ((findfile f)) ("not found"))))
  )
)

(defun dg:acad-loaded (/ inf)
  (dg:sub "ARX and .NET applications loaded (arx)")
  (foreach a (acad_strlsort (arx)) (dg:item a))
  (dg:sub "Menus loaded")
  (vlax-for g (vla-get-MenuGroups (dg:acad))
    (dg:item (strcat (vla-get-Name g) "  " (vla-get-MenuFileName g)))
  )
  (dg:sub "Application bundles installed")
  (foreach b (dg:bundles)
    (setq inf (dg:pkg b))
    (dg:item (strcat b (if inf (strcat "  (" (dg:str (car inf)) " " (dg:str (cadr inf)) ")") "")))
  )
  (dg:sub "AutoCAD Startup Suite (APPLOAD)")
  (foreach f (cond ((dg:apploads)) ('("none"))) (dg:item f))
)

;;-------------------------=={ Conflicts }==------------------------;;

(defun dg:s-conflicts ()
  (dg:try 'dg:cf-files)
  (dg:try 'dg:cf-pgp)
  (dg:try 'dg:cf-aliases)
  (dg:try 'dg:cf-reactors)
)

;;  The Lisp files AutoCAD loads besides DynALisp: acad.lsp, acaddoc.lsp, the AutoCAD
;;  Startup Suite, the other application bundles, and the support folders outside the
;;  folders of AutoCAD itself (at most 300 files):
(defun dg:cf-sources (/ lst add pf)
  (defun add (f)
    (if (and f
             (findfile f)
             (not (member (strcase f) (mapcar 'strcase lst)))
             (/= (strcase *dyl:repo) (strcase (substr f 1 (strlen *dyl:repo))))
             (< (length lst) 300)
        )
      (setq lst (cons f lst))
    )
  )
  (setq pf (strcase (cond ((getenv "ProgramFiles")) ("?"))))
  (foreach f '("acad.lsp" "acaddoc.lsp") (add (findfile f)))
  (foreach f (dg:apploads) (if (wcmatch (strcase f) "*.LSP,*.MNL") (add f)))
  (foreach b (dg:bundles)
    (if (/= (strcase b) (strcase *dyl:repo))
      (foreach f (append (dg:files b "*.lsp") (dg:files b "*.mnl")) (add f))
    )
  )
  (foreach p (dg:split (getenv "ACAD") ";")
    (if (and (vl-file-directory-p p) (/= pf (strcase (substr p 1 (strlen pf)))))
      (foreach f (append (vl-directory-files p "*.lsp" 1) (vl-directory-files p "*.mnl" 1))
        (add (strcat (vl-string-right-trim "\\" p) "\\" f))
      )
    )
  )
  (reverse lst)
)

;;  Name of the command defined at position p of the line s (after "(DEFUN C:"):
(defun dg:cf-name (s p / e)
  (setq s (substr s (+ p 10))
        e 0
  )
  (while (and (< e (strlen s)) (not (member (substr s (1+ e) 1) '(" " "(" "\t" ")")))) (setq e (1+ e)))
  (substr s 1 e)
)

(defun dg:cf-files (/ names srcs u p n rea)
  (dg:sub "Lisp files of other programs")
  (setq names (dg:dylnames)
        srcs  (dg:cf-sources)
  )
  (dg:kv "Files read" (itoa (length srcs)))
  (foreach f srcs
    (setq rea nil)
    (foreach s (dg:lines f 20000)
      (setq u (strcase s))
      (if (not (wcmatch (vl-string-left-trim " \t" u) ";*"))
        (progn
          (if (vl-string-search "(DEFUN S::STARTUP" u)
            (dg:bad (strcat f " defines S::STARTUP with DEFUN: the DynALisp startup, added to S::STARTUP, may not run"))
          )
          (if (and (setq p (vl-string-search "(DEFUN C:" u)) (member (setq n (dg:cf-name u p)) names))
            (dg:bad (strcat f " defines the command " n ", also a DynALisp command or alias"))
          )
          (if (vl-string-search "UNDEFINE" u) (dg:note (strcat f " undefines AutoCAD commands")))
          (if (vl-string-search "(VLR-" u) (setq rea t))
        )
      )
    )
    (if rea (dg:note (strcat f " makes reactors")))
  )
)

;;  The aliases of acad.pgp named as a DynALisp command or alias defined in this
;;  drawing (a command turned off, an alias not defined, takes nothing):
(defun dg:cf-pgp (/ pgp als rows ons r)
  (setq pgp  (Dyl:PgpAliases)
        als  (Dyl:AliasRead)
        rows (vl-catch-all-apply 'Dyl:Suite '(nil))
  )
  (dg:kv "acad.pgp" (cond ((findfile "acad.pgp")) ("not found")))
  (if (listp rows)
    (foreach r rows
      (if (and (= "1" (car r)) (/= "" (nth 1 r))) (setq ons (cons (list (dg:cmd (nth 1 r)) (nth 3 r)) ons)))
    )
  )
  (foreach p pgp
    (cond
      ((setq r (assoc (car p) ons))
       (dg:bad (strcat "acad.pgp alias " (car p) " (" (cdr p) ") has the name of the DynALisp command "
                       (car p) " (Modules\\" (cadr r) "): rename the command or turn it off in Dyl-Suite"
               )
       )
      )
      ((member (car p) (mapcar 'strcase *dyl:dyndefs*))
       (dg:bad (strcat "acad.pgp alias " (car p) " (" (cdr p) ") has the name of a DynALisp custom preset command"))
      )
      ((and (member (car p) (mapcar 'strcase *dyl:aliasdefs*)) (setq r (assoc (car p) als)))
       (dg:bad (strcat "acad.pgp alias " (car p) " (" (cdr p) ") has the name of the DynALisp alias of "
                       (cdr r) ": give " (cdr r) " another alias in Dyl-Suite"
               )
       )
      )
    )
  )
)

;;  The DynALisp aliases not defined, their name being taken:
(defun dg:cf-aliases (/ n)
  (setq n 0)
  (foreach p (Dyl:AliasRead)
    (if (and (eval (read (strcat "C:" (cdr p)))) (not (member (car p) (mapcar 'strcase *dyl:aliasdefs*))))
      (progn
        (setq n (1+ n))
        (dg:bad (strcat "Alias " (car p) " of " (cdr p) " not defined: " (car p) " is already "
                        (cond ((Dyl:AliasTaken (car p))) ("a command"))
                )
        )
      )
    )
  )
  (if (= 0 n) (dg:kv "Aliases" "every alias of a command turned on is defined"))
)

;;  The reactors of other programs in this drawing:
(defun dg:cf-reactors (/ n)
  (setq n 0)
  (foreach grp (vlr-reactors)
    (foreach r (cdr grp)
      (if (not (wcmatch (dg:str (vlr-data r)) "Dyl-*"))
        (progn
          (setq n (1+ n))
          (dg:note (strcat "Reactor of another program: " (dg:str (car grp)) " " (dg:str (vlr-data r))
                           (if (vlr-pers-p r) " [saved in the drawing]" "")
                           (if (eq (car grp) :VLR-Object-Reactor) (strcat ", " (itoa (length (vlr-owners r))) " object(s)") "")
                           " -> " (dg:str (vlr-reactions r))
                   )
          )
        )
      )
    )
  )
  (dg:kv "Reactors of other programs" (itoa n))
)

;;-------------------------=={ Startup Suite }==------------------------;;

(defun dg:s-suite ()
  (dg:try 'dg:suite-rows)
  (dg:try 'dg:suite-aliases)
)

(defun dg:suite-rows (/ recs on mods m paths undef seen docs)
  (setq recs (Dyl:SuiteRecs))
  (dg:kv "File" (Dyl:UserFile *dyl:suite))
  (if (and (/= *dyl:suite (Dyl:UserFile *dyl:suite))
           (Dyl:SuiteNewer-p (Dyl:SuiteTime *dyl:suite) (Dyl:SuiteTime (Dyl:UserFile *dyl:suite)))
      )
    (dg:note "The default StartupSuite.csv is newer than your copy (an update)")
  )
  (if (not recs) (dg:bad "StartupSuite.csv cannot be read"))
  (setq on (vl-remove-if-not '(lambda (r) (= "1" (car r))) recs))
  (dg:kv "Rows / turned on" (strcat (itoa (length recs)) " / " (itoa (length on))))
  (foreach r recs
    (setq m (nth 3 r))
    (setq mods (if (assoc m mods)
                 (subst (list m (1+ (cadr (assoc m mods))) (+ (caddr (assoc m mods)) (if (= "1" (car r)) 1 0)))
                        (assoc m mods)
                        mods
                 )
                 (cons (list m 1 (if (= "1" (car r)) 1 0)) mods)
               )
    )
    (if (not (member (strcase (nth 5 r)) paths)) (setq paths (cons (strcase (nth 5 r)) paths)))
  )
  (foreach m (reverse mods) (dg:item (strcat (car m) ": " (itoa (caddr m)) " on of " (itoa (cadr m)))))
  (foreach p paths
    (if (not (findfile (strcat *dyl:module "\\" p))) (dg:bad (strcat "File of the Startup Suite missing: Modules\\" p)))
  )
  ;;  Turned on, so defined at startup (the command or its autoload stub):
  (foreach r on
    (if (and (/= "" (nth 1 r)) (not (eval (read (strcat "C:" (dg:cmd (nth 1 r)))))))
      (setq undef (cons (dg:cmd (nth 1 r)) undef))
    )
  )
  (if undef
    (dg:bad (strcat (itoa (length undef)) " command(s) turned on but not defined: "
                    (Remote>>LM:lst->str (reverse undef) ", ")
            )
    )
  )
  (foreach r recs
    (if (/= "" (nth 1 r))
      (if (member (dg:cmd (nth 1 r)) seen)
        (dg:bad (strcat "Command in two files: " (dg:cmd (nth 1 r))))
        (setq seen (cons (dg:cmd (nth 1 r)) seen))
      )
    )
  )
  ;;  The docs page of each main command (Dyl-*, LM-*), on the website or on this
  ;;  computer (Dyl:DocsFind):
  (foreach r recs
    (if (and (wcmatch (dg:cmd (nth 1 r)) "DYL-*,LM-*")
             (wcmatch (strcase (nth 5 r)) "*\\APPS\\*")
             (not (Dyl:DocsFind (strcat *dyl:module "\\"
                                    (vl-filename-directory (dg:repl (nth 5 r) "\\Apps\\" "\\Docs\\"))
                                    "\\" (vl-filename-base (nth 5 r)) ".htm"
                            )
                  )
             )
        )
      (setq docs (cons (vl-filename-base (nth 5 r)) docs))
    )
  )
  (if docs (dg:note (strcat "Main command(s) without a docs page: " (Remote>>LM:lst->str (reverse docs) ", "))))
)

;;  An alias of a command neither in the Startup Suite nor a dynamic child (a
;;  custom preset, Dyl:DynList) is left over from a command removed or renamed:
(defun dg:suite-aliases (/ als cmds)
  (setq als  (Dyl:AliasRead)
        cmds (append (mapcar '(lambda (r) (dg:cmd (nth 1 r))) (Dyl:SuiteRecs))
                     (mapcar '(lambda (d) (strcase (car d))) (Dyl:DynList))
             )
  )
  (dg:kv "Aliases.csv" (Dyl:UserFile *dyl:alias))
  (dg:kv "Aliases / defined" (strcat (itoa (length als)) " / " (itoa (length *dyl:aliasdefs*))))
  (foreach p als
    (if (not (member (cdr p) cmds)) (dg:bad (strcat "Alias " (car p) " of a command not in the Startup Suite: " (cdr p))))
  )
)

;;-------------------------=={ Settings }==------------------------;;

(defun dg:s-settings ()
  (dg:try 'dg:set-values)
  (dg:try 'dg:set-user)
  (dg:try 'dg:set-csv)
  (dg:try 'dg:set-asm)
  (dg:try 'dg:set-mat)
)

;;  Every Dynalisp* user setting, local ones included: (name ...):
(defun dg:setnames ()
  (acad_strlsort
    (vl-remove-if-not
      '(lambda (n) (and (= 'STR (type n)) (wcmatch (strcase n) "DYNALISP?*")))
      (vl-registry-descendents (strcat "HKEY_CURRENT_USER\\" (dg:prodkey) "\\FixedProfile\\General") T)
    )
  )
)

(defun dg:set-values ()
  (dg:sub "DynALisp settings")
  (foreach n (dg:setnames) (dg:item (strcat n " = " (dg:str (getenv n)))))
)

;;  The user copies, and whether an update brought a newer default:
(defun dg:set-user (/ def)
  (dg:sub "Your files (User folder)")
  (if (vl-file-directory-p *dyl:user)
    (foreach f (dg:files *dyl:user "*")
      (setq def (strcat *dyl:contents (substr f (1+ (strlen *dyl:user)))))
      (dg:item (strcat (dg:rel f *dyl:user) "  " (dg:str (dg:date f)) "  " (itoa (cond ((vl-file-size f)) (0))) " bytes"
                       (cond
                         ((wcmatch (strcase f) (strcat "*" (strcase *dyl:userdirmark*))) "")
                         ((not (findfile def)) "  (no default)")
                         ((Dyl:SuiteNewer-p (Dyl:SuiteTime def) (Dyl:SuiteTime f)) "  (the default is newer)")
                         ("")
                       )
               )
      )
    )
    (dg:item "none")
  )
)

;;  Number of fields of a CSV line, the separators inside quotes skipped:
(defun dg:fields (str sep / n q c)
  (setq n 1
        q nil
        sep (ascii sep)
  )
  (foreach c (vl-string->list str)
    (cond
      ((= c 34) (setq q (not q)))
      ((and (= c sep) (not q)) (setq n (1+ n)))
    )
  )
  n
)

;;  Every data file of DynALisp (Resources and the Res folders of the modules, MyTools
;;  left out) as DynALisp reads it (its user copy when there is one): its rows, and the
;;  time to read them all:
(defun dg:set-csv (/ files t0 tot f lines hdr sep nf odd)
  (dg:sub "Data files (CSV)")
  (setq files (dg:files *dyl:res "*.csv"))
  (foreach m (vl-remove-if '(lambda (x) (or (wcmatch x "*.*") (= (strcase x) (strcase (vl-filename-base *dyl:custom)))))
                           (vl-directory-files *dyl:module nil -1)
             )
    (if (vl-file-directory-p (strcat *dyl:module "\\" m "\\Res"))
      (setq files (append files (dg:files (strcat *dyl:module "\\" m "\\Res") "*.csv")))
    )
  )
  (setq tot 0)
  (foreach d files
    (setq f     (Dyl:UserFile d)
          t0    (getvar "MILLISECS")
          lines (vl-remove-if '(lambda (l) (= "" (vl-string-trim " \t" l))) (dg:lines f nil))
          tot   (+ tot (- (getvar "MILLISECS") t0))
          hdr   (car lines)
          odd   0
    )
    (cond
      ((not lines) (dg:bad (strcat "Cannot be read or empty: " (dg:rel f *dyl:repo))))
      (T
       (setq sep (cond ((vl-string-search ";" hdr) ";") ((vl-string-search "\t" hdr) "\t") (","))
             nf  (dg:fields hdr sep)
       )
       (foreach l (cdr lines) (if (/= nf (dg:fields l sep)) (setq odd (1+ odd))))
       (if (< 0 odd)
         (dg:note (strcat (dg:rel f *dyl:repo) ": " (itoa odd) " of " (itoa (1- (length lines)))
                          " row(s) do not have the " (itoa nf) " fields of the header"
                  )
         )
       )
      )
    )
  )
  (dg:kv "Files" (strcat (itoa (length files)) " read in " (itoa tot) " ms"))
)

;;  The assembly presets of Quick Draw (QuickDrawAssemblies.csv): how many, with the default
;;  assemblies (as-*, the typical assemblies of the building code, read from the file as
;;  shipped when a user copy does not have them yet), and the Quick
;;  Draw presets whose assembly (column 38: its id) is not one of them (drawn without
;;  layers). A column with ":" is the layers of a preset of an older file, made an assembly
;;  preset when the Quick Draw window opens:
(defun dg:set-asm (/ ids defs bad v)
  (if (and Remote>>Dyl:PresetCsv (Remote>>Dyl:PresetProp "QuickDrawAssembly" 'header))
    (progn
      (dg:sub "Assembly presets")
      (setq ids  (mapcar '(lambda (a) (strcase (car a))) (Remote>>Dyl:PresetCsv "QuickDrawAssembly"))
            defs (vl-remove-if-not '(lambda (id) (wcmatch id "AS-?*"))
                                   (mapcar '(lambda (a) (strcase (car a)))
                                           (Remote>>Dyl:CsvRead (Remote>>Dyl:PresetDefault "QuickDrawAssembly") 1)
                                   )
                 )
      )
      (foreach id defs (if (not (member id ids)) (setq ids (cons id ids))))
      (dg:kv "Default assemblies" (itoa (length defs)))
      (foreach r (Remote>>Dyl:PresetCsv "QuickDraw")
        (setq v (vl-string-trim " " (cond ((nth 38 r)) (""))))
        (if (and (/= "" v) (not (vl-string-search ":" v)) (not (member (strcase v) ids)))
          (setq bad (cons (nth 2 r) bad))
        )
      )
      (dg:kv "Assemblies" (itoa (length ids)))
      (if bad
        (dg:bad (strcat "Quick Draw presets whose assembly no longer exists: " (Remote>>LM:lst->str (reverse bad) ", ")))
      )
    )
  )
)

;;  The materials and their hatch presets: a materials file of DynALisp 1.1 and older not split
;;  yet (each material its own hatch), a material whose hatch preset no longer exists (drawn
;;  without hatch), the materials in a group that is not one of the groups of the materials
;;  (MaterialGroups.csv: still listed, after the others), a User copy of the HatchPresets.csv
;;  of DynALisp 1.0 (not read):
(defun dg:set-mat (/ b ids bad f grps odd)
  (if Remote>>Dyl:MaterialBoth
    (progn
      (dg:sub "Materials")
      ;;  (never split here: the report changes no file)
      (if (Remote>>Dyl:MaterialOld-p)
        (dg:note "The materials file is of DynALisp 1.1 or older: it is split into materials and hatch presets when it is read")
        (progn
          (setq b   (Remote>>Dyl:MaterialBoth)
                ids (mapcar 'car (car b))
          )
          (dg:kv "Materials" (itoa (length (cadr b))))
          (dg:kv "Hatch presets" (itoa (length ids)))
          (foreach m (cadr b)
            (foreach i '(3 4)
              (if (and (/= "" (nth i m)) (not (member (nth i m) ids)))
                (setq bad (cons (strcat (nth 2 m) " (" (nth i m) ")") bad))
              )
            )
          )
          (if bad
            (dg:bad (strcat "Materials whose hatch preset no longer exists: " (Remote>>LM:lst->str (reverse bad) ", ")))
          )
          (if Remote>>Dyl:GroupsOf
            (progn
              (setq grps (mapcar 'strcase (Remote>>Dyl:GroupsOf "Material")))
              (dg:kv "Groups of the materials" (itoa (length grps)))
              (foreach m (cadr b)
                (if (not (member (strcase (nth 1 m)) grps)) (setq odd (cons (strcat (nth 2 m) " (" (nth 1 m) ")") odd)))
              )
              (if odd
                (dg:note (strcat "Materials in a group that is not one of the groups of the materials: " (Remote>>LM:lst->str (reverse odd) ", ")))
              )
            )
          )
        )
      )
      (setq f (Dyl:UserFile (Remote>>Dyl:PresetDefault "HatchPreset")))
      (if (and (/= (strcase f) (strcase (Remote>>Dyl:PresetDefault "HatchPreset")))
               (/= (Remote>>Dyl:PresetFile "HatchPreset") f)
          )
        (dg:note "The User copy of HatchPresets.csv is the file of DynALisp 1.0: not read (saving the hatch presets replaces it)")
      )
    )
  )
)

;;-------------------------=={ Reactors }==------------------------;;

(defun dg:s-reactors ()
  (dg:try 'dg:rea-state)
  (dg:try 'dg:rea-list)
)

;;  The reactors of type typ named nam in this drawing:
(defun dg:rea-count (typ nam)
  (length (vl-remove-if-not '(lambda (r) (= nam (vlr-data r))) (cdr (assoc typ (vlr-reactors)))))
)

(defun dg:rea-state (/ on n)
  (setq on (= "1" (getenv "DynalispReactors")))
  (foreach v '("DynalispReactors" "DynalispPhaseAuto" "DynalispObjectKeys" "DynalispDrawOrderAuto" "DynalispSettingsSync")
    (dg:kv v (getenv v))
  )
  (dg:kv "Counter fix (Dyl:CmdTop-p)" (if Dyl:CmdTop-p "loaded" "not loaded"))
  ;;  Each reactor turned on has its database reactor in this drawing, once:
  (foreach x '(("DynalispPhaseAuto" "Dyl-LayerPhase" "Auto-phase")
               ("DynalispObjectKeys" "Dyl-ObjectLayerKeys" "Auto layer keys")
               ("DynalispDrawOrderAuto" "Dyl-DrawOrder" "Auto draw order")
              )
    (setq n (dg:rea-count :VLR-AcDb-Reactor (cadr x)))
    (cond
      ((and on (= "1" (getenv (car x))) (= 0 n)) (dg:bad (strcat (caddr x) " is on but has no reactor in this drawing")))
      ((and (not on) (< 0 n)) (dg:bad (strcat (caddr x) " has reactors while the DynALisp reactors are off")))
      ((< 1 n) (dg:bad (strcat (caddr x) " has " (itoa n) " database reactors in this drawing (made twice)")))
    )
  )
  (dg:kv "Depth  phase / keys / order" (list *ph:depth* *olk:depth* *do:depth*))
  (dg:kv "Pending phase / keys / order"
         (mapcar '(lambda (l) (if (listp l) (length l) l)) (list *ph:new* *olk:new* *do:new*))
  )
  (if (and (= "" (getvar "CMDNAMES")) (vl-some '(lambda (d) (and d (< 0 d))) (list *ph:depth* *olk:depth* *do:depth*)))
    (dg:bad "A reactor counts a command running while none is: its count is stuck")
  )
  (if (vl-some '(lambda (l) (< 1000 (length l))) (list *ph:new* *olk:new* *do:new*))
    (dg:bad "A reactor keeps more than 1000 objects to handle: it no longer runs")
  )
  (dg:kv "MODEMACRO" (getvar "MODEMACRO"))
)

(defun dg:rea-list ()
  (dg:sub "Reactors of this drawing")
  (foreach grp (vlr-reactors)
    (dg:item (strcat (dg:str (car grp)) ": " (itoa (length (cdr grp)))))
    (foreach r (cdr grp)
      (dg:item (strcat "  " (dg:str (vlr-data r)) (if (vlr-added-p r) "" " [disabled]")
                       (if (vlr-pers-p r) " [saved in the drawing]" "")
                       (if (eq (car grp) :VLR-Object-Reactor) (strcat " owners: " (itoa (length (vlr-owners r)))) "")
                       " -> " (dg:str (mapcar 'car (vlr-reactions r)))
               )
      )
    )
  )
)

;;-------------------------=={ Drawing }==------------------------;;

(defun dg:s-drawing ()
  (dg:try 'dg:dwg-file)
  (dg:try 'dg:dwg-spaces)
  (dg:try 'dg:dwg-tables)
  (dg:try 'dg:dwg-objects)
  (dg:try 'dg:dwg-revisions)
  (dg:try 'dg:dwg-materials)
  (dg:try 'dg:dwg-regen)
)

;;  The objects that carry a material (their DynALisp data, see Remote>>Dyl:MaterialTags):
;;  how many, of how many materials, those of a material that no longer exists (a problem: a
;;  simulation cannot read them) and how many are closed outlines rather than hatches.
;;  Counts only: the id of a material of one's own can name a client:
(defun dg:dwg-materials (/ ss i e id ids gone n reg own)
  (dg:sub "Material of the objects (Pst-MaterialAssign)")
  (cond
    ((not Remote>>Dyl:MaterialTags) (dg:bad "Remote\\Dyl-Materials.lsp is not loaded"))
    ((not (setq ss (ssget "_X" (list (list -3 (list *mt:app*))))))
     (dg:item "No object carries a material")
    )
    (T
     (setq i 0 n 0 reg 0)
     (repeat (sslength ss)
       (setq e (ssname ss i)
             i (1+ i)
       )
       (if (setq id (Remote>>Dyl:MaterialOf e))
         (progn
           (setq n (1+ n))
           (if (not (member id ids)) (setq ids (cons id ids)))
           (if (/= "HATCH" (cdr (assoc 0 (entget e)))) (setq reg (1+ reg)))
         )
       )
     )
     (foreach x ids
       (if (not (or (assoc x (cadr (Remote>>Dyl:MaterialBoth))) (assoc x (Remote>>Dyl:MaterialRowDefs))))
         (setq gone (cons x gone))
       )
     )
     (setq own (vl-remove-if '(lambda (x) (assoc x (Remote>>Dyl:MaterialRowDefs))) ids))
     (dg:kv "Objects with a material" (strcat (itoa n) " (" (itoa reg) " closed outline(s), the others hatches)"))
     (dg:kv "Materials used" (strcat (itoa (length ids)) " (" (itoa (length own)) " of one's own)"))
     (if gone
       (dg:bad (strcat (itoa (length gone)) " material(s) used in the drawing no longer exist: give their objects another one (Pst-MaterialAssign)"))
     )
    )
  )
)

;;  The revisions of the project of the drawing (Dyl-Revisions): its files, and the title
;;  blocks of the layouts that have revisions. No project name or folder (they can name a
;;  client):
(defun dg:dwg-revisions (/ prj revs maps shts scan xr n)
  (dg:sub "Revisions (Dyl-Revisions)")
  (dg:kv "DynalispRevisionSync" (getenv "DynalispRevisionSync"))
  (cond
    ((not Remote>>Dyl:RevProjectOf) (dg:bad "Remote\\Dyl-Revisions.lsp is not loaded"))
    ((not (setq prj (Remote>>Dyl:RevProjectOf))) (dg:item "Not in a Project Navigator project (no .apj from its folder up)"))
    (T
     (setq revs (Remote>>Dyl:RevRead prj)
           maps (Remote>>Dyl:RevBlocks)
           shts (Remote>>Dyl:RevSheets prj)
     )
     (dg:kv "Project" "found (.apj)")
     (dg:kv "Sheet folder" (if (vl-file-directory-p (nth 4 prj)) "found" "missing"))
     (dg:kv "Revisions" (strcat (itoa (length revs)) " (" (itoa (length (vl-remove-if-not '(lambda (r) (= "1" (nth 6 r))) revs))) " issued)"))
     (dg:kv "Settings" (Remote>>LM:lst->str (mapcar '(lambda (s) (strcat (car s) "=" (cdr s))) (Remote>>Dyl:RevSettings prj)) ", "))
     (dg:kv "Sheets.csv" (strcat (itoa (length shts)) " sheet(s)"))
     (dg:kv "Title blocks set up" (itoa (length maps)))
     ;;  (n nil for each file: a file missing must not close the one before again)
     (foreach f '("Revisions.csv" "Sheets.csv")
       (setq n nil)
       (if (and (findfile (Remote>>Dyl:RevPath prj f)) (not (setq n (open (Remote>>Dyl:RevPath prj f) "r"))))
         (dg:bad (strcat f " of the project cannot be read"))
         (if n (close n))
       )
     )
     (dg:kv "This drawing" (if (Remote>>Dyl:RevSheetThis prj) "a sheet of the project" "not in the sheet folder"))
     (vlax-for lay (vla-get-Layouts (dg:doc))
       (if (= :vlax-false (vla-get-ModelType lay))
         (progn
           (setq scan (Remote>>Dyl:RevScan (vla-get-Block lay) maps)
                 xr   (Remote>>Dyl:RevXrecGet lay)
           )
           (dg:item (strcat (vla-get-Name lay) ": " (itoa (length (car xr))) " revision(s) given, "
                            (itoa (length (car scan))) " in clouds, " (itoa (length (caddr scan))) " title block(s)"
                            (if (and xr (= 1 (cadr xr))) ", attributes to set again (ObjectDBX)" "")
                    )
           )
           (if (and (or (car xr) (car scan)) (not (caddr scan)))
             (dg:bad (strcat "Layout " (vla-get-Name lay) " has revisions but no title block set up (REVTB)"))
           )
         )
       )
     )
    )
  )
)

(defun dg:dwg-file (/ f)
  (setq f (strcat (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (dg:kv "Drawing" (if (= 1 (getvar "DWGTITLED")) f (strcat (getvar "DWGNAME") " (never saved)")))
  (if (and (= 1 (getvar "DWGTITLED")) (vl-file-size f))
    (dg:kv "File" (strcat (itoa (/ (vl-file-size f) 1024)) " KB, saved " (dg:str (dg:date f))))
  )
  (dg:kv "Changed since saved" (if (= 0 (getvar "DBMOD")) "no" "yes"))
  (foreach n '("MEASUREMENT" "INSUNITS" "LUNITS" "LUPREC" "CANNOSCALE" "DIMSCALE" "LTSCALE" "PSLTSCALE" "MSLTSCALE"
               "CTAB" "TILEMODE"
              )
    (dg:item (strcat n " = " (dg:str (getvar n))))
  )
  (dg:kv "Active phase" (if Remote>>Dyl:PhaseGet (Remote>>Dyl:PhaseGet)))
  (dg:kv "Draw order preset" (if Remote>>Dyl:DrawOrderPreset (Remote>>Dyl:DrawOrderPreset)))
)

;;  Objects and draw order entries of model space and each layout:
(defun dg:dwg-spaces (/ blk cnt srt)
  (dg:sub "Spaces: objects / draw order entries")
  (vlax-for lay (vla-get-Layouts (dg:doc))
    (setq blk (vla-get-Block lay)
          cnt (vla-get-Count blk)
          srt (dg:sortn blk)
    )
    (dg:item (strcat (vla-get-Name lay) ": " (itoa cnt) " / " (if srt (itoa srt) "no table")))
    (if (and srt (< cnt srt)) (dg:bad (strcat (vla-get-Name lay) " has more draw order entries than objects (Do-Rebuild cleans them)")))
  )
)

(defun dg:dwg-tables (/ n off frz lck blks xrs ed)
  (setq n 0 off 0 frz 0 lck 0)
  (vlax-for l (vla-get-Layers (dg:doc))
    (setq n (1+ n))
    (if (= :vlax-false (vla-get-LayerOn l)) (setq off (1+ off)))
    (if (= :vlax-true (vla-get-Freeze l)) (setq frz (1+ frz)))
    (if (= :vlax-true (vla-get-Lock l)) (setq lck (1+ lck)))
  )
  (dg:kv "Layers" (strcat (itoa n) " (" (itoa off) " off, " (itoa frz) " frozen, " (itoa lck) " locked)"))
  (setq blks 0)
  (vlax-for b (vla-get-Blocks (dg:doc))
    (cond
      ((= :vlax-true (vla-get-IsLayout b)))
      ((= :vlax-true (vla-get-IsXRef b)) (setq xrs (cons b xrs)))
      ((setq blks (1+ blks)))
    )
  )
  (dg:kv "Block definitions" (itoa blks))
  (dg:kv "Xrefs" (itoa (length xrs)))
  (foreach x (reverse xrs)
    (setq ed (tblsearch "BLOCK" (vla-get-Name x)))
    (dg:item (strcat (vla-get-Name x) "  " (dg:str (cdr (assoc 1 ed)))))
    (if (and ed (/= 32 (logand 32 (cdr (assoc 70 ed)))))
      (dg:bad (strcat "Xref not loaded or not found: " (vla-get-Name x)))
    )
  )
)

;;  The kinds of objects of the drawing (at most 100 000 counted):
(defun dg:dwg-objects (/ ss i typ lst)
  (if (setq ss (ssget "_X"))
    (progn
      (dg:kv "Objects" (itoa (sslength ss)))
      (if (< (sslength ss) 100000)
        (progn
          (setq i 0)
          (repeat (sslength ss)
            (setq typ (cdr (assoc 0 (entget (ssname ss i))))
                  lst (if (assoc typ lst) (subst (cons typ (1+ (cdr (assoc typ lst)))) (assoc typ lst) lst) (cons (cons typ 1) lst))
                  i   (1+ i)
            )
          )
          (setq lst (vl-sort lst '(lambda (a b) (> (cdr a) (cdr b)))))
          (dg:sub "Kinds of objects")
          (foreach p lst (dg:item (strcat (itoa (cdr p)) "  " (car p))))
          (if (assoc "ACAD_PROXY_ENTITY" lst)
            (dg:note "The drawing has proxy objects (made by an application not loaded)")
          )
        )
      )
    )
    (dg:kv "Objects" "0")
  )
)

;;  The time to regenerate every viewport, 3 times (through ActiveX: no command runs):
(defun dg:dwg-regen (/ t0 lst)
  (repeat 3
    (setq t0 (getvar "MILLISECS"))
    (vla-Regen (dg:doc) acAllViewports)
    (setq lst (cons (- (getvar "MILLISECS") t0) lst))
  )
  (dg:kv "Regen" (strcat (itoa (/ (apply '+ lst) 3)) " ms on average " (dg:str (reverse lst))))
)

;;-------------------------=={ Running the sections }==------------------------;;

;;  (name function), in the order of the full report:
(setq dg:sections '(("DynALisp" dg:s-dynalisp)
                    ("AutoCAD" dg:s-autocad)
                    ("Conflicts" dg:s-conflicts)
                    ("Startup Suite" dg:s-suite)
                    ("Settings" dg:s-settings)
                    ("Reactors" dg:s-reactors)
                    ("Drawing" dg:s-drawing)
                   )
)

;;  The lines of a report of the sections secs (names of dg:sections), the problems at
;;  the top:
(defun dg:report (secs / body)
  (setq dg:out   nil
        dg:probs nil
  )
  (foreach s dg:sections
    (if (member (car s) secs)
      (progn
        (setq dg:sect (car s))
        (dg:add "")
        (dg:add (strcat "== " (car s) " =="))
        (dg:try (cadr s))
      )
    )
  )
  (setq body (reverse dg:out))
  (append
    (list (strcat "DynALisp diagnostics - " (dg:now))
          (strcat "DynALisp " (Dyl:InfoVersion) " - " (dg:str (vl-catch-all-apply 'dg:product nil)) " - " (getvar "DWGNAME"))
          ""
          (strcat "Problems found: " (itoa (length dg:probs)))
    )
    (mapcar '(lambda (p) (strcat "  [!] " p)) (reverse dg:probs))
    body
  )
)

;;  Run one section, write it to %TEMP%\DynALisp Diagnostics\<name>.txt and open it:
(defun dg:one (name / dir pth)
  (setq dir (strcat (getenv "TEMP") "\\DynALisp Diagnostics"))
  (vl-mkdir dir)
  (if (setq pth (dg:write (strcat dir "\\" name ".txt") (dg:report (list name))))
    (dg:open pth)
    (princ (strcat "\n--> Unable to write in " dir))
  )
  (princ)
)

;;-------------------------=={ Full report and GitHub issue }==------------------------;;

;;  Percent-encode a string for a URL (UTF-8):
(defun dg:hex (n) (strcat "%" (substr "0123456789ABCDEF" (1+ (lsh n -4)) 1) (substr "0123456789ABCDEF" (1+ (logand n 15)) 1)))
(defun dg:url (str)
  (apply 'strcat
         (mapcar '(lambda (c)
                    (cond
                      ((or (< 47 c 58) (< 64 c 91) (< 96 c 123) (member c '(45 46 95 126))) (chr c))
                      ((< c 128) (dg:hex c))
                      ((< c 2048) (strcat (dg:hex (+ 192 (lsh c -6))) (dg:hex (+ 128 (logand c 63)))))
                      ((strcat (dg:hex (+ 224 (lsh c -12))) (dg:hex (+ 128 (logand (lsh c -6) 63))) (dg:hex (+ 128 (logand c 63)))))
                    )
                  )
                 (vl-string->list str)
         )
  )
)

;;  The new issue page of the releases repository, its title and text filled in: the
;;  summary and the problems found (kept short: the whole report is in the zip):
(defun dg:issue (zip / body n)
  (setq body (strcat "**What happened:**\n\n(what you did, what you saw, what you expected)\n\n"
                     "**Report:** drag the file `" (vl-filename-base zip) ".zip` here.\n\n"
                     "### Summary\n"
                     "- DynALisp " (Dyl:InfoVersion) (if (dg:git) (strcat " (git clone, " (dg:git) ")") "") "\n"
                     "- " (dg:str (vl-catch-all-apply 'dg:product nil)) ", " (vla-get-Version (dg:acad)) "\n"
                     "- Profile " (getvar "CPROFILE") ", reactors " (if (= "1" (getenv "DynalispReactors")) "on" "off") "\n\n"
                     "### Problems found (" (itoa (length dg:probs)) ")\n"
             )
        n    0
  )
  (foreach p (reverse dg:probs)
    (if (< (strlen body) 3500) (setq body (strcat body "- " p "\n") n (1+ n)))
  )
  (if (< n (length dg:probs)) (setq body (strcat body "- ... (" (itoa (- (length dg:probs) n)) " more in the report)\n")))
  (strcat "https://github.com/" *dyl:relrepo* "/issues/new?title="
          (dg:url (strcat "Diagnostics report - DynALisp " (Dyl:InfoVersion) " - " (dg:str (vl-catch-all-apply 'dg:product nil))))
          "&body=" (dg:url (dg:anon body))
  )
)

;;  The settings as Export settings writes them (DynALisp-Settings.txt, Name=Value), every
;;  Dynalisp* setting, local ones included:
(defun dg:settingsfile (dir)
  (dg:write (strcat dir "\\" *dyl:setsfile*)
            (cons "; DynALisp settings, written by Dyl-Diagnostics"
                  (mapcar '(lambda (n) (strcat n "=" (dg:str (getenv n)))) (dg:setnames))
            )
  )
)

;;  Zip the folder dir into dir.zip (PowerShell). Returns the zip, nil when it failed:
(defun dg:zip (dir / zip)
  (setq zip (strcat dir ".zip"))
  (if (findfile zip) (vl-file-delete zip))
  (dg:run (strcat "powershell -NoProfile -ExecutionPolicy Bypass -Command \"Compress-Archive -Path '"
                  (dg:repl dir "'" "''") "\\*' -DestinationPath '" (dg:repl zip "'" "''") "' -Force\""
          )
  )
  (if (findfile zip) zip)
)

;;  Every section into a DynALisp Report <date> folder of %TEMP%, with the settings and the
;;  User folder; the folder zipped, the report opened, then the issue offered:
(defun dg:full (/ dir rep zip)
  (princ "\nDynALisp diagnostics: checking DynALisp, AutoCAD and the drawing...")
  (setq dir (strcat (getenv "TEMP") "\\DynALisp Report " (menucmd "M=$(edtime,$(getvar,date),YYYY-MO-DD HHMMSS)")))
  (vl-mkdir dir)
  (cond
    ((not (setq rep (dg:write (strcat dir "\\Report.txt") (dg:report (mapcar 'car dg:sections)))))
     (princ (strcat "\n--> Unable to write in " dir))
    )
    (T
     (dg:settingsfile dir)
     (if (vl-file-directory-p *dyl:user) (Dyl:SetsCopy *dyl:user (strcat dir "\\User")))
     (setq zip (dg:zip dir))
     (dg:open rep)
     (if
       (Dyl:Ask (list (strcat "Report ready: " (itoa (length dg:probs)) " problem(s) found.")
                      "Send it to the DynALisp developer in a GitHub issue? The issue is public:"
                      "check the report first. The zip of the report then goes in the issue."
                )
                "Open issue"
                "Close"
       )
       (progn
         (dg:open (dg:issue (cond (zip) (dir))))
         (if zip
           (startapp "explorer" (strcat "/select,\"" zip "\""))
           (dg:open dir)
         )
         (princ (strcat "\nDrag " (vl-filename-base (cond (zip) (dir))) (if zip ".zip" "") " into the issue, describe the problem, then Submit."))
       )
       (princ (strcat "\nReport saved in " (cond (zip) (dir)) "."))
     )
    )
  )
  (princ)
)

;;-------------------------=={ Reactor events }==------------------------;;

;;  Count the events of the drawing (the DynALisp reactors run only on these events)
;;  between two runs of Pst-DiagnosticsReactorEvents, to see what a slow zoom or pan sends.
;;  The counting reactors are in Modules\Dynalisp\Reactor\Dyl-Diagnostics.lsp, loaded
;;  only while the DynALisp reactors are on:
(defun dg:events (/ res dir pth lines)
  (cond
    ((or (not Reactor>>Dyl:DiagEventsStart) (not (Dyl:ReactorsOn-p)))
     (if Reactor>>Dyl:DiagEventsStop (Reactor>>Dyl:DiagEventsStop))
     (princ "\nThe DynALisp reactors are off (Dyl-Settings): no DynALisp reactor runs, there is nothing to count.")
    )
    ((Reactor>>Dyl:DiagEventsOn-p)
     (setq res   (Reactor>>Dyl:DiagEventsStop)
           lines (list (strcat "DynALisp reactor events - " (dg:now) " - " (getvar "DWGNAME"))
                       (strcat "Events during the test (" (rtos (/ (car res) 1000.0) 2 1) " s), the most frequent first:")
                       "(the lispWillStart of this command is counted too)"
                 )
     )
     (foreach e (cdr res) (setq lines (append lines (list (strcat "  " (itoa (cdr e)) "  " (car e))))))
     (if (not (cdr res)) (setq lines (append lines (list "  none: no reactor ran while you worked"))))
     (setq dir (strcat (getenv "TEMP") "\DynALisp Diagnostics"))
     (vl-mkdir dir)
     (if (setq pth (dg:write (strcat dir "\Reactor Events.txt") lines))
       (dg:open pth)
       (princ (strcat "\n--> Unable to write in " dir))
     )
    )
    ((Reactor>>Dyl:DiagEventsStart)
     (princ "\nCounting the events: work the slow way (zoom, pan, draw) for about 20 s, then run Pst-DiagnosticsReactorEvents again.")
    )
  )
  (princ)
)

;;-------------------------=={ Commands }==------------------------;;

;; Diagnostics
;; Writes a full report of DynALisp, AutoCAD and the drawing with your settings and files, then offers to send it in a GitHub issue.

(defun c:Dyl-Diagnostics () (dg:full))

;; Diagnostics DynALisp
;; Reports the version and installation of DynALisp, its startup, load errors and modules.

(defun c:Pst-DiagnosticsDynalisp () (dg:one "DynALisp"))

;; Diagnostics AutoCAD
;; Reports the AutoCAD product, Windows, the profile, system variables, paths, applications and bundles loaded.

(defun c:Pst-DiagnosticsAutocad () (dg:one "AutoCAD"))

;; Diagnostics Conflicts
;; Looks for other programs that redefine the DynALisp commands, aliases or startup, and their reactors.

(defun c:Pst-DiagnosticsConflicts () (dg:one "Conflicts"))

;; Diagnostics Startup Suite
;; Checks the Startup Suite and the aliases: missing files, commands not defined, aliases without a command.

(defun c:Pst-DiagnosticsSuite () (dg:one "Startup Suite"))

;; Diagnostics Settings
;; Lists the DynALisp settings and your files, and checks every data file DynALisp reads.

(defun c:Pst-DiagnosticsSettings () (dg:one "Settings"))

;; Diagnostics Reactors
;; Checks the DynALisp reactors of the drawing against their settings and lists every reactor.

(defun c:Pst-DiagnosticsReactors () (dg:one "Reactors"))

;; Diagnostics Reactor Events
;; Counts the events the drawing sends to the reactors between two runs, to find what slows AutoCAD.

(defun c:Pst-DiagnosticsReactorEvents () (dg:events))

;; Diagnostics Drawing
;; Reports the units, spaces, draw order tables, layers, xrefs and objects of the drawing, and its regen time.

(defun c:Pst-DiagnosticsDrawing () (dg:one "Drawing"))

(princ)
