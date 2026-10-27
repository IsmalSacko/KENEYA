; Installateur Windows de Ngoni Santé (Inno Setup 6), pour un .exe à
; télécharger hors du Microsoft Store.
;   1. flutter build windows --release
;   2. Ouvrir ce fichier dans Inno Setup, puis « Compile » :
;      l'installateur sort dans build\installeur\.
; Sans certificat de signature, Windows affiche un avertissement au premier
; lancement : pour l'éviter, passer par le Microsoft Store (voir CONSTRUIRE.md).

#define Nom "Ngoni Santé"
#define Version "4.0.2"
#define Editeur "IsmaelDev"
#define Exe "ngoni_sante.exe"

[Setup]
AppId={{6F1D9C2A-5B7E-4E8A-9C1F-0A7B3D2E4F51}
AppName={#Nom}
AppVersion={#Version}
AppPublisher={#Editeur}
AppPublisherURL=https://keneya.ismaeldev.fr
DefaultDirName={autopf}\Ngoni Sante
DefaultGroupName={#Nom}
OutputDir=..\..\build\installeur
OutputBaseFilename=NgoniSante-{#Version}-installation
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#Exe}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "bureau"; Description: "Créer un raccourci sur le Bureau"; GroupDescription: "Raccourcis :"

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#Nom}"; Filename: "{app}\{#Exe}"
Name: "{group}\Désinstaller {#Nom}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#Nom}"; Filename: "{app}\{#Exe}"; Tasks: bureau

[Run]
Filename: "{app}\{#Exe}"; Description: "Lancer {#Nom}"; Flags: nowait postinstall skipifsilent
