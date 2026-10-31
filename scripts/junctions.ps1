# Peon: Junctions im AddOns-Ordner auf die Addons im Repo (addons\).
# Aufruf über junctions.cmd:
#   junctions.cmd            zeigt den Zustand
#   junctions.cmd anlegen    legt fehlende Junctions an. Echte Ordner werden nur ersetzt, wenn alle
#                            Dateien gleich sind (Prüfsumme), und vorher ins Archiv verschoben.
#                            Junctions auf Module, die es im Repo nicht mehr gibt, werden entfernt
#                            (nur der Verweis, der Inhalt bleibt).
# WoW muss beim Anlegen geschlossen sein.
# Der AddOns-Ordner kommt aus scripts\local.json ({ "addons": "X:\\...\\_forever_\\Interface\\AddOns" }, nicht im Repo),
# sonst aus -AddOns, sonst der übliche Ort von Battle.net.
param(
    [string]$Aktion = "status",
    [string]$AddOns = "",
    [string]$Archiv = ""
)
$ErrorActionPreference = "Stop"
$Repo = Split-Path -Parent $PSScriptRoot
if (-not $AddOns) {
    $lokal = Join-Path $PSScriptRoot "local.json"
    if (Test-Path $lokal) { $AddOns = (Get-Content $lokal -Raw -Encoding UTF8 | ConvertFrom-Json).addons }
    if (-not $AddOns) { $AddOns = "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns" }
}
$Quelle = Join-Path $Repo "addons"
if (-not $Archiv) { $Archiv = Join-Path (Split-Path -Parent $Repo) ("Peon_Archiv\AddOns_vor_Junctions_" + (Get-Date -Format "yyyy-MM-dd")) }
$Anlegen = $Aktion -eq "anlegen"
# Dateien, die nicht zum Code gehören und beim Vergleich nicht zählen (schreibt der Peon Manager)
$Ignorieren = @("Peon_Bridge\Data.lua", "Peon_Client\Data.lua")

if (-not (Test-Path $AddOns)) { Write-Host "AddOns-Ordner nicht gefunden: $AddOns"; exit 1 }

if ($Anlegen) {
    $wow = Get-Process | Where-Object { $_.ProcessName -match '^Wow' }
    if ($wow) { Write-Host "WoW läuft ($($wow[0].ProcessName)). Bitte zuerst schließen."; exit 1 }
}

function Pruefsummen($ordner, $name) {
    $h = @{}
    Get-ChildItem $ordner -Recurse -File -Force | ForEach-Object {
        $rel = $name + $_.FullName.Substring($ordner.Length)
        if ($Ignorieren -notcontains $rel) { $h[$rel] = (Get-FileHash $_.FullName -Algorithm SHA256).Hash }
    }
    return $h
}

function Gleich($a, $b) {
    if ($a.Count -ne $b.Count) { return $false }
    foreach ($k in $a.Keys) { if ($b[$k] -ne $a[$k]) { return $false } }
    return $true
}

$fehler = 0
$module = Get-ChildItem $Quelle -Directory | Sort-Object Name
foreach ($m in $module) {
    $ziel = Join-Path $AddOns $m.Name
    $item = Get-Item $ziel -Force -ErrorAction SilentlyContinue
    if (-not $item) {
        if ($Anlegen) {
            New-Item -ItemType Junction -Path $ziel -Target $m.FullName | Out-Null
            Write-Host ("{0,-18} Junction angelegt" -f $m.Name)
        } else { Write-Host ("{0,-18} fehlt" -f $m.Name) }
        continue
    }
    if ($item.LinkType -eq "Junction") {
        $t = @($item.Target)[0]
        if ($t.TrimEnd('\') -eq $m.FullName.TrimEnd('\')) { Write-Host ("{0,-18} Junction OK" -f $m.Name) }
        else { Write-Host ("{0,-18} Junction zeigt woanders hin: {1}" -f $m.Name, $t); $fehler++ }
        continue
    }
    # echter Ordner: vergleichen
    $gleich = Gleich (Pruefsummen $m.FullName $m.Name) (Pruefsummen $item.FullName $m.Name)
    if (-not $gleich) {
        Write-Host ("{0,-18} Ordner, NICHT gleich wie im Repo. Bleibt unverändert, bitte von Hand prüfen." -f $m.Name)
        $fehler++
        continue
    }
    if (-not $Anlegen) { Write-Host ("{0,-18} Ordner, gleich wie im Repo (kann ersetzt werden)" -f $m.Name); continue }
    New-Item -ItemType Directory -Force $Archiv | Out-Null
    $sicher = Join-Path $Archiv $m.Name
    if (Test-Path $sicher) { Write-Host ("{0,-18} Archiv schon belegt: {1}" -f $m.Name, $sicher); $fehler++; continue }
    Move-Item $item.FullName $sicher
    New-Item -ItemType Junction -Path $ziel -Target $m.FullName | Out-Null
    Write-Host ("{0,-18} Ordner nach {1} verschoben, Junction angelegt" -f $m.Name, $Archiv)
}

# Peon-Ordner im AddOns-Ordner, die es im Repo nicht gibt
$namen = $module | ForEach-Object { $_.Name }
Get-ChildItem $AddOns -Directory -Force | Where-Object { ($_.Name -eq "Peon" -or $_.Name -like "Peon_*") -and ($namen -notcontains $_.Name) } | ForEach-Object {
    if ($_.LinkType -eq "Junction") {
        $t = @($_.Target)[0]
        if ($t.StartsWith($Quelle) -and -not (Test-Path $t)) {
            if ($Anlegen) { cmd /c rmdir "$($_.FullName)"; Write-Host ("{0,-18} alte Junction entfernt (Modul nicht mehr im Repo)" -f $_.Name) }
            else { Write-Host ("{0,-18} alte Junction, Modul nicht mehr im Repo (wird beim Anlegen entfernt)" -f $_.Name) }
        } else { Write-Host ("{0,-18} Junction auf {1}, nicht im Repo" -f $_.Name, $t) }
    } else { Write-Host ("{0,-18} normaler Ordner, nicht im Repo (bleibt)" -f $_.Name) }
}
if ($fehler) { exit 1 }
