Option Explicit

Sub AppliquerSaisieMotDePasseToutesFeuilles()
Const PWD As String = "Finance2026"
Dim ws As Worksheet
Dim i As Long

    Application.ScreenUpdating = False
    Application.DisplayAlerts = False

    For Each ws In ThisWorkbook.Worksheets
        On Error Resume Next
        ws.Unprotect Password:=PWD
        On Error GoTo 0

        ' Tout verrouiller
        ws.Cells.Locked = True

        ' Supprimer anciennes plages autorisées
        On Error Resume Next
        Do While ws.Protection.AllowEditRanges.Count > 0
            ws.Protection.AllowEditRanges(1).Delete
        Loop
        On Error GoTo 0

        ' Ajouter une plage modifiable avec saisie de mot de passe
        ws.Protection.AllowEditRanges.Add _
            Title:="EditWithPassword", _
            Range:=ws.UsedRange, _
            Password:=PWD

        ' Reprotéger la feuille
        ws.Protect Password:=PWD, DrawingObjects:=False, Contents:=True, Scenarios:=True, _
                   AllowFiltering:=True, AllowSorting:=True
    Next ws

    ' Protéger structure du classeur
    On Error Resume Next
    ThisWorkbook.Unprotect Password:=PWD
    On Error GoTo 0
    ThisWorkbook.Protect Password:=PWD, Structure:=True

    Application.DisplayAlerts = True
    Application.ScreenUpdating = True

    MsgBox "Configuration appliquée sur toutes les feuilles.", vbInformation

End Sub
Étapes rapides:

Alt+F11
Insertion > Module
Colle le code
F5 pour lancer la macro
Après ça, quand quelqu’un tape dans une zone protégée (dans la plage configurée), Excel demandera Finance2026.
