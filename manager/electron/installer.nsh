; Peon Manager - Zusatz fuer den Installer (electron-builder, nsis.include)
; Beim Selbst-Update laeuft der Installer sichtbar (updater.js): Sein kleines Fenster zeigt den Fortschritt,
; danach startet der Manager von selbst neu. Diese Zeilen sagen dort, was gerade passiert.

!macro customHeader
  BrandingText "Peon Manager"
!macroend

!macro customInstall
  DetailPrint "Peon Manager ist eingespielt und startet gleich."
!macroend
