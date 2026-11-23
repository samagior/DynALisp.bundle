; DynALisp.iss - DynALisp setup (Inno Setup 6)
; Copyright (C) 2023  Samuel Martineau
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <https://www.gnu.org/licenses/>.
;
; Build it with Installer\Build.ps1 (never ISCC on its own): the script stages the
; files of the bundle (the ones git knows, without the dev files) and passes:
;   /DAppVersion=1.0                       the AppVersion of PackageContents.xml
;   /DStageDir=...\bundle                  the files to install
;   /DBuildDir=...                         holds Modules.iss, the InstallDelete line of each module shipped
;   /DShippedModules=Dynalisp;gileCAD;...  the modules shipped
;   /DOutDir=...                           where the setup goes (Releases)
;
; Install: for the current user only (no admin rights), into the AutoCAD plugins
; folder, as DynALisp.bundle. Never over a git clone (updated with git pull). An
; update removes the shipped folders before copying the new ones (a file deleted
; from DynALisp is not loaded any more) and keeps the User folder (the user's edits)
; and the modules not shipped (MyTools...). It waits for AutoCAD to close: silent
; (/VERYSILENT, started by Dyl-Info or the automatic updates), in the background;
; otherwise it asks.
;
; Saved settings: a "DynALisp Settings <date>" folder (DynALisp-Settings.txt, User\,
; Modules\<module>\), the same as Export settings of Dyl-UserFiles (see Dyl:SetsExport
; in dynalisp.mnl: change both together).
;   - The Import page of the setup (or /IMPORT="...\DynALisp-Settings.txt") copies its
;     folders and leaves its settings file as Import-Settings.txt, applied by the next
;     startup of AutoCAD.
;   - The uninstall asks first whether to save them, and where. Then it removes
;     everything: the whole folder (User and MyTools too), the temp folder of the
;     updates, the Dynalisp* user settings of every AutoCAD, the DynALisp profile
;     (its base profile made current again) and the paths into the folder left in the
;     AutoCAD profiles (support, trusted paths, custom dictionary...).

#ifndef AppVersion
  #error Build the setup with Installer\Build.ps1
#endif
#ifndef ShippedModules
  #define ShippedModules "Dynalisp;gileCAD;LeeMac"
#endif

[Setup]
; The ProductCode of PackageContents.xml: never change it, Windows tells the
; versions of DynALisp apart by it.
AppId={{C481FFC8-87C5-4BB3-8529-5CA7B41EB8E6}
AppName=DynALisp
AppVersion={#AppVersion}
AppVerName=DynALisp {#AppVersion}
AppPublisher=Samuel Martineau
AppPublisherURL=https://github.com/samagior/DynALisp.release
AppSupportURL=https://github.com/samagior/DynALisp.release/issues
AppUpdatesURL=https://github.com/samagior/DynALisp.release/releases
AppCopyright=Copyright (C) 2023 Samuel Martineau, GNU General Public License v3
DefaultDirName={userappdata}\Autodesk\ApplicationPlugins\DynALisp.bundle
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
LicenseFile={#StageDir}\LICENSE
OutputDir={#OutDir}
OutputBaseFilename=DynALisp-Setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallFilesDir={app}\Uninstall
UninstallDisplayName=DynALisp {#AppVersion}
; AutoCAD is waited for by the code below: the Restart Manager would close it (and
; the drawings open) in a silent update.
CloseApplications=no
RestartApplications=no
; One setup at a time (Dyl-Info started in two drawings):
SetupMutex=DynALispSetup
SetupLogging=yes

[InstallDelete]
; The shipped folders, removed before the new ones are copied (files deleted from
; DynALisp). The user's files are not in them: User is next to Contents.
Type: filesandordirs; Name: "{app}\Contents\Resources"
#include BuildDir + "\Modules.iss"

[Files]
Source: "{#StageDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[UninstallDelete]
; Everything: the folder with what DynALisp made in it (User, MyTools, Import-Settings.txt...),
; and the setups downloaded by the updates (Dyl:InfoInstall):
Type: filesandordirs; Name: "{app}"
Type: filesandordirs; Name: "{%TEMP}\DynALisp"

[Messages]
FinishedLabel=DynALisp is installed. Start AutoCAD to use it: type Dyl-Info for help.

[Code]
const
  AcadKey = 'Software\Autodesk\AutoCAD';
  SettingsFile = 'DynALisp-Settings.txt';
  // Settings of this computer only (stamps, profile names, paths), never saved or
  // imported (*dyl:setslocal* in dynalisp.mnl):
  LocalSettings = ',DYNALISPLASTVERSION,DYNALISPUPDATECHECKED,DYNALISPPREFAPPLIED,DYNALISPPREFBASE,DYNALISPPREFCUSTOMBASE,DYNALISPSYSVARSTAMP,DYNALISPWINDOWPLACES,';
  ProfileName = 'DynALisp';

var
  ImportPage: TInputFileWizardPage;
  SavedTo: String;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// T when an AutoCAD (acad.exe: AutoCAD and its verticals) is running:
function AcadRunning(): Boolean;
var
  Locator, Service, Procs: Variant;
begin
  Result := False;
  try
    Locator := CreateOleObject('WbemScripting.SWbemLocator');
    Service := Locator.ConnectServer('.', 'root\CIMV2');
    Procs := Service.ExecQuery('SELECT ProcessId FROM Win32_Process WHERE Name = ''acad.exe''');
    Result := Procs.Count > 0;
  except
    Result := False;
  end;
end;

// T when Name is a module shipped with DynALisp:
function IsShippedModule(Name: String): Boolean;
begin
  Result := Pos(';' + Uppercase(Name) + ';', Uppercase(';{#ShippedModules};')) > 0;
end;

// T when Name is a sub-folder entry (not . or ..) of a find:
function IsSubDir(F: TFindRec): Boolean;
begin
  Result := ((F.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0) and (F.Name <> '.') and (F.Name <> '..');
end;

// Copy the folder Src into Dst, the files already there replaced:
procedure DirCopy(Src, Dst: String);
var
  F: TFindRec;
begin
  ForceDirectories(Dst);
  if FindFirst(Src + '\*', F) then
  try
    repeat
      if IsSubDir(F) then
        DirCopy(Src + '\' + F.Name, Dst + '\' + F.Name)
      else if (F.Attributes and FILE_ATTRIBUTE_DIRECTORY) = 0 then
        FileCopy(Src + '\' + F.Name, Dst + '\' + F.Name, False);
    until not FindNext(F);
  finally
    FindClose(F);
  end;
end;

// Copy the modules of the folder Src (a Modules folder) that are not shipped into Dst:
procedure CopyOwnModules(Src, Dst: String);
var
  F: TFindRec;
begin
  if FindFirst(Src + '\*', F) then
  try
    repeat
      if IsSubDir(F) and not IsShippedModule(F.Name) then
        DirCopy(Src + '\' + F.Name, Dst + '\' + F.Name);
    until not FindNext(F);
  finally
    FindClose(F);
  end;
end;

// T when the folder Src (a Modules folder) has a module not shipped:
function HasOwnModules(Src: String): Boolean;
var
  F: TFindRec;
begin
  Result := False;
  if FindFirst(Src + '\*', F) then
  try
    repeat
      if IsSubDir(F) and not IsShippedModule(F.Name) then
        Result := True;
    until Result or not FindNext(F);
  finally
    FindClose(F);
  end;
end;

// The keys of the AutoCAD products of this user (Software\Autodesk\AutoCAD\R24.3\ACAD-7101:409),
// the oldest release first:
function AcadProducts(): TArrayOfString;
var
  Releases, Products: TArrayOfString;
  I, J, N: Integer;
  Tmp: String;
begin
  SetArrayLength(Result, 0);
  if not RegGetSubkeyNames(HKCU, AcadKey, Releases) then
    Exit;
  for I := 0 to GetArrayLength(Releases) - 2 do
    for J := I + 1 to GetArrayLength(Releases) - 1 do
      if CompareText(Releases[J], Releases[I]) < 0 then
      begin
        Tmp := Releases[I];
        Releases[I] := Releases[J];
        Releases[J] := Tmp;
      end;
  for I := 0 to GetArrayLength(Releases) - 1 do
    if RegGetSubkeyNames(HKCU, AcadKey + '\' + Releases[I], Products) then
      for J := 0 to GetArrayLength(Products) - 1 do
        if RegKeyExists(HKCU, AcadKey + '\' + Releases[I] + '\' + Products[J] + '\FixedProfile\General') then
        begin
          N := GetArrayLength(Result);
          SetArrayLength(Result, N + 1);
          Result[N] := AcadKey + '\' + Releases[I] + '\' + Products[J];
        end;
end;

// T when Name is a Dynalisp* user setting:
function IsDynalispSetting(Name: String): Boolean;
begin
  Result := (Length(Name) > 8) and (CompareText(Copy(Name, 1, 8), 'Dynalisp') = 0);
end;

// T when Name is a Dynalisp* user setting kept with the saved settings:
function IsSavedSetting(Name: String): Boolean;
begin
  Result := IsDynalispSetting(Name) and (Pos(',' + Uppercase(Name) + ',', LocalSettings) = 0);
end;

// Set the Name=Value line of Lines, added when missing:
procedure SetLine(var Lines: TArrayOfString; Name, Value: String);
var
  I, N: Integer;
begin
  N := GetArrayLength(Lines);
  for I := 0 to N - 1 do
    if CompareText(Copy(Lines[I], 1, Length(Name) + 1), Name + '=') = 0 then
    begin
      Lines[I] := Name + '=' + Value;
      Exit;
    end;
  SetArrayLength(Lines, N + 1);
  Lines[N] := Name + '=' + Value;
end;

// The lines of DynALisp-Settings.txt: a comment, then the Dynalisp* user settings
// (FixedProfile\General of each AutoCAD, the newest release winning):
function SettingsLines(): TArrayOfString;
var
  Products, Names: TArrayOfString;
  I, J: Integer;
  Key, Value: String;
begin
  SetArrayLength(Result, 1);
  Result[0] := '; DynALisp settings, saved by the uninstall of version {#AppVersion} (Dyl-UserFiles > Import settings, or the setup, imports them)';
  Products := AcadProducts();
  for I := 0 to GetArrayLength(Products) - 1 do
  begin
    Key := Products[I] + '\FixedProfile\General';
    if RegGetValueNames(HKCU, Key, Names) then
      for J := 0 to GetArrayLength(Names) - 1 do
        if IsSavedSetting(Names[J]) and RegQueryStringValue(HKCU, Key, Names[J], Value) then
          SetLine(Result, Names[J], Value);
  end;
end;

// ---------------------------------------------------------------------------
// Install: import saved settings
// ---------------------------------------------------------------------------
procedure InitializeWizard();
begin
  ImportPage := CreateInputFilePage(wpLicense, 'Import Saved Settings',
    'Do you have DynALisp settings saved from another installation?',
    'To import them (your edited files, the options of Dyl-Settings and your own modules), pick the ' +
    SettingsFile + ' file of the "DynALisp Settings" folder saved by the uninstall or by Dyl-UserFiles > ' +
    'Export settings. Leave it empty to start with the default settings.');
  ImportPage.Add('Settings file (optional):', 'DynALisp settings|' + SettingsFile + '|Text files|*.txt', '.txt');
  ImportPage.Values[0] := ExpandConstant('{param:IMPORT|}');
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if (CurPageID = ImportPage.ID) and (Trim(ImportPage.Values[0]) <> '') and not FileExists(Trim(ImportPage.Values[0])) then
  begin
    MsgBox('File not found:' + #13#10 + ImportPage.Values[0], mbError, MB_OK);
    Result := False;
  end;
end;

// Before anything is changed: never over a git clone, and AutoCAD closed (its
// files, the ribbon, are in use while it runs):
function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  if DirExists(ExpandConstant('{app}\.git')) then
  begin
    Result := 'This DynALisp folder is a git clone:' + #13#10 + ExpandConstant('{app}') + #13#10#13#10 +
              'Update it with git pull instead.';
    Exit;
  end;
  while AcadRunning() do
  begin
    if WizardSilent() then
      Sleep(3000)
    else if MsgBox('Close AutoCAD (every AutoCAD window) to install DynALisp, then click OK.',
                   mbInformation, MB_OKCANCEL) = IDCANCEL then
    begin
      Result := 'Close AutoCAD, then run the setup again.';
      Exit;
    end;
  end;
end;

// The saved settings of the file picked: its User folder and modules copied, its
// settings left for the next startup of AutoCAD (Dyl:SetsPending):
procedure CurStepChanged(CurStep: TSetupStep);
var
  FileName, Src, App: String;
begin
  FileName := Trim(ImportPage.Values[0]);
  if (CurStep <> ssPostInstall) or (FileName = '') or not FileExists(FileName) then
    Exit;
  Src := ExtractFileDir(FileName);
  App := ExpandConstant('{app}');
  if DirExists(Src + '\User') then
    DirCopy(Src + '\User', App + '\User');
  if DirExists(Src + '\Modules') then
    CopyOwnModules(Src + '\Modules', App + '\Contents\Modules');
  FileCopy(FileName, App + '\Import-Settings.txt', False);
end;

// ---------------------------------------------------------------------------
// Uninstall: save the settings, then remove everything
// ---------------------------------------------------------------------------

// A folder picked by the user, '' when cancelled:
function BrowseFolder(Title: String): String;
var
  Shell, Folder: Variant;
begin
  Result := '';
  try
    Shell := CreateOleObject('Shell.Application');
    // BIF_RETURNONLYFSDIRS + BIF_EDITBOX + BIF_NEWDIALOGSTYLE, from the desktop:
    Folder := Shell.BrowseForFolder(0, Title, $51, 0);
    Result := Folder.Self.Path;
  except
    Result := '';
  end;
end;

// T when there is something to save: options, edited files or own modules:
function HasSettings(): Boolean;
begin
  Result := (GetArrayLength(SettingsLines()) > 1) or DirExists(ExpandConstant('{app}\User')) or
            HasOwnModules(ExpandConstant('{app}\Contents\Modules'));
end;

// Save the settings in a new "DynALisp Settings <date>" folder of Dir (SavedTo):
function SaveSettings(Dir: String): Boolean;
var
  App, Dst: String;
begin
  App := ExpandConstant('{app}');
  Dst := AddBackslash(Dir) + 'DynALisp Settings ' + GetDateTimeString('yyyy/mm/dd', '-', ':');
  if DirExists(Dst) then
    Dst := Dst + ' ' + GetDateTimeString('hhnnss', #0, #0);
  Result := ForceDirectories(Dst) and SaveStringsToFile(Dst + '\' + SettingsFile, SettingsLines(), False);
  if not Result then
    Exit;
  if DirExists(App + '\User') then
    DirCopy(App + '\User', Dst + '\User');
  CopyOwnModules(App + '\Contents\Modules', Dst + '\Modules');
  SavedTo := Dst;
end;

function InitializeUninstall(): Boolean;
var
  Dir: String;
  Answer: Integer;
begin
  Result := True;
  while Result and AcadRunning() do
    Result := MsgBox('Close AutoCAD (every AutoCAD window) to uninstall DynALisp, then click OK.',
                     mbInformation, MB_OKCANCEL) = IDOK;
  if not Result or UninstallSilent() or not HasSettings() then
    Exit;
  Answer := MsgBox('Save your DynALisp settings before uninstalling?' + #13#10#13#10 +
                   'Your edited files (User folder), the options of Dyl-Settings and your own modules (MyTools) ' +
                   'are saved in a folder you choose. The setup of a new installation, or Dyl-UserFiles > ' +
                   'Import settings, imports them.' + #13#10#13#10 +
                   'Yes: save them first.  No: remove everything.', mbConfirmation, MB_YESNOCANCEL);
  if Answer = IDCANCEL then
    Result := False
  else if Answer = IDYES then
  begin
    Dir := BrowseFolder('Save the DynALisp settings in:');
    if Dir = '' then
    begin
      MsgBox('No folder chosen: DynALisp is not uninstalled.', mbInformation, MB_OK);
      Result := False;
    end
    else if SaveSettings(Dir) then
      MsgBox('Your settings are saved in:' + #13#10 + SavedTo + #13#10#13#10 +
             'To import them, pick its ' + SettingsFile + ' in the setup, or in Dyl-UserFiles > Import settings.',
             mbInformation, MB_OK)
    else
      Result := MsgBox('Unable to save the settings in:' + #13#10 + Dir + #13#10#13#10 + 'Uninstall anyway?',
                       mbError, MB_YESNO) = IDYES;
  end;
end;

// T when the path list entry Part is in the folder App (uppercase):
function InApp(Part, App: String): Boolean;
begin
  Result := Pos(App + '\', Uppercase(Trim(Part)) + '\') = 1;
end;

// Value (a ;-separated list of paths, or one path) without the paths in the folder App:
function WithoutApp(Value, App: String): String;
var
  Rest, Part: String;
  P: Integer;
begin
  Result := '';
  Rest := Value;
  while Rest <> '' do
  begin
    P := Pos(';', Rest);
    if P = 0 then
    begin
      Part := Rest;
      Rest := '';
    end
    else
    begin
      Part := Copy(Rest, 1, P - 1);
      Rest := Copy(Rest, P + 1, Length(Rest));
    end;
    if (Trim(Part) <> '') and not InApp(Part, App) then
    begin
      if Result <> '' then
        Result := Result + ';';
      Result := Result + Part;
    end;
  end;
  if (Result <> '') and (Copy(Value, Length(Value), 1) = ';') then
    Result := Result + ';';
end;

// The string values of Key that hold a path in the folder App, without it (the
// custom dictionary, DCTCUST, back to the one used before DynALisp's):
procedure CleanPaths(Key, App, CustomBase: String);
var
  Names: TArrayOfString;
  I: Integer;
  Value, NewValue: String;
begin
  if not RegGetValueNames(HKCU, Key, Names) then
    Exit;
  for I := 0 to GetArrayLength(Names) - 1 do
    if RegQueryStringValue(HKCU, Key, Names[I], Value) and (Pos(App + '\', Uppercase(Value)) > 0) then
    begin
      NewValue := WithoutApp(Value, App);
      if (NewValue = '') and (CompareText(Names[I], 'DCTCUST') = 0) then
        NewValue := CustomBase;
      if Pos('%', NewValue) > 0 then
        RegWriteExpandStringValue(HKCU, Key, Names[I], NewValue)
      else
        RegWriteStringValue(HKCU, Key, Names[I], NewValue);
    end;
end;

// A profile of the product Key other than the DynALisp one, '' if none:
function OtherProfile(Key: String): String;
var
  Profiles: TArrayOfString;
  I: Integer;
begin
  Result := '';
  if RegGetSubkeyNames(HKCU, Key + '\Profiles', Profiles) then
    for I := 0 to GetArrayLength(Profiles) - 1 do
      if (Result = '') and (CompareText(Profiles[I], ProfileName) <> 0) then
        Result := Profiles[I];
end;

// What DynALisp left in the AutoCAD product Key: its user settings, its profile and
// the paths into the folder App (uppercase) in every profile:
procedure CleanProduct(Key, App: String);
var
  Names, Profiles, Subs: TArrayOfString;
  I, J: Integer;
  Gen, Cur, Base, CustomBase: String;
begin
  Gen := Key + '\FixedProfile\General';
  Base := '';
  CustomBase := '';
  RegQueryStringValue(HKCU, Gen, 'DynalispPrefBase', Base);
  RegQueryStringValue(HKCU, Gen, 'DynalispPrefCustomBase', CustomBase);
  if RegGetValueNames(HKCU, Gen, Names) then
    for I := 0 to GetArrayLength(Names) - 1 do
      if IsDynalispSetting(Names[I]) then
        RegDeleteValue(HKCU, Gen, Names[I]);
  // The DynALisp profile (File Preferences of Dyl-Settings): the profile it was made
  // from made current again, then deleted (kept when it is the only one):
  if RegKeyExists(HKCU, Key + '\Profiles\' + ProfileName) then
  begin
    Cur := '';
    RegQueryStringValue(HKCU, Key + '\Profiles', '', Cur);
    if CompareText(Cur, ProfileName) = 0 then
    begin
      if (Base = '') or (CompareText(Base, ProfileName) = 0) or not RegKeyExists(HKCU, Key + '\Profiles\' + Base) then
        Base := OtherProfile(Key);
      if Base <> '' then
      begin
        RegWriteStringValue(HKCU, Key + '\Profiles', '', Base);
        Cur := Base;
      end;
    end;
    if CompareText(Cur, ProfileName) <> 0 then
      RegDeleteKeyIncludingSubkeys(HKCU, Key + '\Profiles\' + ProfileName);
  end;
  // The paths into the folder (support, trusted paths, dictionary...) in each profile:
  CleanPaths(Gen, App, CustomBase);
  if RegGetSubkeyNames(HKCU, Key + '\Profiles', Profiles) then
    for I := 0 to GetArrayLength(Profiles) - 1 do
    begin
      CleanPaths(Key + '\Profiles\' + Profiles[I], App, CustomBase);
      if RegGetSubkeyNames(HKCU, Key + '\Profiles\' + Profiles[I], Subs) then
        for J := 0 to GetArrayLength(Subs) - 1 do
          CleanPaths(Key + '\Profiles\' + Profiles[I] + '\' + Subs[J], App, CustomBase);
    end;
end;

// The Assistant (Dyl-Assistant): its working folder (%LOCALAPPDATA%\DynALisp\Assistant) and
// the conversations Claude Code kept for it, in its own folder of projects, named after that
// working folder (C--Users-<user>-AppData-Local-DynALisp-Assistant). Claude Code itself, its
// sign-in and its other projects are the user's: they stay.
procedure CleanAssistant;
var
  Projects: String;
  F: TFindRec;
begin
  DelTree(ExpandConstant('{localappdata}\DynALisp\Assistant'), True, True, True);
  RemoveDir(ExpandConstant('{localappdata}\DynALisp'));
  Projects := GetEnv('USERPROFILE') + '\.claude\projects';
  if FindFirst(Projects + '\*-DynALisp-Assistant', F) then
  begin
    try
      repeat
        if (F.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0 then
          DelTree(Projects + '\' + F.Name, True, True, True);
      until not FindNext(F);
    finally
      FindClose(F);
    end;
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Products: TArrayOfString;
  I: Integer;
  App: String;
begin
  if CurUninstallStep <> usPostUninstall then
    Exit;
  App := Uppercase(RemoveBackslash(ExpandConstant('{app}')));
  Products := AcadProducts();
  for I := 0 to GetArrayLength(Products) - 1 do
    CleanProduct(Products[I], App);
  CleanAssistant;
end;
