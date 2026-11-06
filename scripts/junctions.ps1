# Peon: Umschalten der Peon-Addons im AddOns-Ordner zwischen Manager und Entwicklung.
# Aufruf über junctions.cmd:
#   junctions.cmd                      zeigt den Zustand
#   junctions.cmd manager [Module]     macht aus Junctions echte Ordner (Kopie aus dem Repo). Der Peon Manager
#                                      aktualisiert sie dann wie bei allen anderen.
#   junctions.cmd entwicklung [Module] macht aus echten Ordnern Junctions auf addons\ im Repo. Der echte Ordner
#                                      wandert ins Archiv, auch wenn er vom Repo abweicht.
#   junctions.cmd anlegen              legt fehlende Junctions an. Echte Ordner werden nur ersetzt, wenn alle
#                                      Dateien gleich sind (Prüfsumme). Junctions auf Module, die es im Repo
#                                      nicht mehr gibt, werden entfernt (nur der Verweis, der Inhalt bleibt).
# Ohne Module gilt es für alle. Beim Ändern muss WoW geschlossen sein. Gelöscht wird nichts außer dem Verweis.
# Der AddOns-Ordner kommt aus scripts\local.json ({ "addons": "X:\\...\\_forever_\\Interface\\AddOns" }, nicht im Repo),
# sonst aus -AddOns, sonst der übliche Ort von Battle.net.
[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Position = 0)][string]$Aktion = "status",
    [string]$AddOns = "",
    [string]$Archiv = "",
    [string]$Repo = "",
    [switch]$OhneWowPruefung,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Namen
)
$ErrorActionPreference = "Stop"
if ($Aktion -notin @("status", "manager", "entwicklung", "anlegen")) { Write-Host "Unbekannte Aktion: $Aktion (status, manager, entwicklung, anlegen)"; exit 1 }
if (-not $Repo) { $Repo = Split-Path -Parent $PSScriptRoot }
if (-not $AddOns) {
    $lokal = Join-Path $PSScriptRoot "local.json"
    if (Test-Path $lokal) { $AddOns = (Get-Content $lokal -Raw -Encoding UTF8 | ConvertFrom-Json).addons }
    if (-not $AddOns) { $AddOns = "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns" }
}
$Quelle = Join-Path $Repo "addons"
if (-not $Archiv) { $Archiv = Join-Path (Split-Path -Parent $Repo) ("Peon_Archiv\AddOns_vor_Junctions_" + (Get-Date -Format "yyyy-MM-dd")) }
$ZuManager = $Aktion -eq "manager"
$ZuEntwicklung = $Aktion -eq "entwicklung"
$Anlegen = $Aktion -eq "anlegen" -or $ZuEntwicklung
# Dateien, die nicht zum Code gehören und beim Vergleich nicht zählen (schreibt der Peon Manager)
$Ignorieren = @("Peon_Bridge\Data.lua", "Peon_Client\Data.lua")

if (-not (Test-Path $AddOns)) { Write-Host "AddOns-Ordner nicht gefunden: $AddOns"; exit 1 }

if (($Anlegen -or $ZuManager) -and -not $OhneWowPruefung) {
    $wow = Get-Process | Where-Object { $_.ProcessName -match '^Wow' }
    if ($wow) { Write-Host "WoW läuft ($($wow[0].ProcessName)). Bitte zuerst schließen."; exit 1 }
}

function Pruefsummen($ordner, $name) {
    $h = @{}
    # Windows liefert die Dateien mit langem Pfad, auch wenn der Ordner gekürzt angegeben ist (ABC~1). Über den Elternordner gibt es denselben Pfad.
    $leaf = Split-Path -Leaf $ordner
    $ordner = (Get-ChildItem (Split-Path -Parent $ordner) -Directory -Force | Where-Object { $_.Name -eq $leaf }).FullName
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

function TocVersion($ordner, $name) {
    $toc = Join-Path $ordner "$name.toc"
    if (-not (Test-Path $toc)) { return "unbekannt" }
    $z = Select-String -Path $toc -Pattern '^##\s*Version:\s*(\S+)' | Select-Object -First 1
    if ($z) { return $z.Matches[0].Groups[1].Value }
    return "unbekannt"
}

# Junction entfernen: rmdir ohne /s nimmt nur den Verweis, der Inhalt im Repo bleibt
function VerweisEntfernen($pfad) {
    cmd /c rmdir "$pfad"
    if ($LASTEXITCODE -ne 0 -or (Test-Path $pfad)) { throw "Verweis ließ sich nicht entfernen: $pfad" }
}

# Junction durch eine geprüfte Kopie aus dem Repo ersetzen
function ZuOrdner($m, $ziel) {
    $neu = Join-Path $AddOns (".peon_neu_" + $m.Name)
    if (Test-Path $neu) { Remove-Item $neu -Recurse -Force }
    Copy-Item $m.FullName $neu -Recurse -Force
    if (-not (Gleich (Pruefsummen $m.FullName $m.Name) (Pruefsummen $neu $m.Name))) {
        Remove-Item $neu -Recurse -Force
        throw "Kopie von $($m.Name) ist nicht gleich dem Repo, die Junction bleibt."
    }
    VerweisEntfernen $ziel
    try { Move-Item $neu $ziel }
    catch {
        New-Item -ItemType Junction -Path $ziel -Target $m.FullName | Out-Null
        throw "$($m.Name) ließ sich nicht an seinen Platz schieben, die Junction ist wieder da: $_"
    }
}

# Echten Ordner ins Archiv verschieben (freier Name, auch bei mehrmaligem Umschalten am selben Tag)
function InsArchiv($item, $name) {
    New-Item -ItemType Directory -Force $Archiv | Out-Null
    $sicher = Join-Path $Archiv $name
    for ($i = 2; Test-Path $sicher; $i++) { $sicher = Join-Path $Archiv "$name-$i" }
    Move-Item $item.FullName $sicher
}

# Was der Manager in den echten Ordner geschrieben hat (Data.lua), gilt in der Entwicklung weiter
function ManagerDateienUebernehmen($item, $m) {
    foreach ($rel in $Ignorieren) {
        if (-not $rel.StartsWith($m.Name + "\")) { continue }
        $von = Join-Path $AddOns $rel
        if (Test-Path $von) { Copy-Item $von (Join-Path $Repo "addons\$rel") -Force }
    }
}

$fehler = 0
$module = Get-ChildItem $Quelle -Directory | Sort-Object Name
$alleNamen = $module | ForEach-Object { $_.Name }
if ($Namen) {
    $falsch = $Namen | Where-Object { $alleNamen -notcontains $_ }
    if ($falsch) { Write-Host "Nicht im Repo: $($falsch -join ', ')"; exit 1 }
    $module = $module | Where-Object { $Namen -contains $_.Name }
}
foreach ($m in $module) {
    $ziel = Join-Path $AddOns $m.Name
    $item = Get-Item $ziel -Force -ErrorAction SilentlyContinue
    if (-not $item) {
        if ($Anlegen) {
            New-Item -ItemType Junction -Path $ziel -Target $m.FullName | Out-Null
            Write-Host ("{0,-18} Junction angelegt" -f $m.Name)
        } elseif ($ZuManager) { Write-Host ("{0,-18} fehlt, der Manager kann es installieren" -f $m.Name) }
        else { Write-Host ("{0,-18} fehlt" -f $m.Name) }
        continue
    }
    if ($item.LinkType -eq "Junction") {
        $t = @($item.Target)[0]
        if ($t.TrimEnd('\') -ne $m.FullName.TrimEnd('\')) {
            Write-Host ("{0,-18} Junction zeigt woanders hin: {1}" -f $m.Name, $t); $fehler++
            continue
        }
        if ($ZuManager) {
            try {
                ZuOrdner $m $ziel
                Write-Host ("{0,-18} jetzt echter Ordner, Version {1}" -f $m.Name, (TocVersion $ziel $m.Name))
            } catch { Write-Host ("{0,-18} {1}" -f $m.Name, $_); $fehler++ }
        } else { Write-Host ("{0,-18} Junction OK (Entwicklung)" -f $m.Name) }
        continue
    }
    # echter Ordner: vergleichen
    $gleich = Gleich (Pruefsummen $m.FullName $m.Name) (Pruefsummen $item.FullName $m.Name)
    if ($ZuManager -or $Aktion -eq "status") {
        if ($gleich) { Write-Host ("{0,-18} echter Ordner, gleich wie im Repo" -f $m.Name) }
        else { Write-Host ("{0,-18} echter Ordner, Version {1} (Repo {2})" -f $m.Name, (TocVersion $item.FullName $m.Name), (TocVersion $m.FullName $m.Name)) }
        continue
    }
    if (-not $gleich -and -not $ZuEntwicklung) {
        Write-Host ("{0,-18} Ordner, NICHT gleich wie im Repo. Bleibt unverändert, bitte von Hand prüfen." -f $m.Name)
        $fehler++
        continue
    }
    ManagerDateienUebernehmen $item $m
    InsArchiv $item $m.Name
    New-Item -ItemType Junction -Path $ziel -Target $m.FullName | Out-Null
    Write-Host ("{0,-18} Ordner nach {1} verschoben, Junction angelegt" -f $m.Name, $Archiv)
}

# Peon-Ordner im AddOns-Ordner, die es im Repo nicht gibt
Get-ChildItem $AddOns -Directory -Force | Where-Object { ($_.Name -eq "Peon" -or $_.Name -like "Peon_*") -and ($alleNamen -notcontains $_.Name) } | ForEach-Object {
    if ($_.LinkType -eq "Junction") {
        $t = @($_.Target)[0]
        if ($t.StartsWith($Quelle) -and -not (Test-Path $t)) {
            if ($Aktion -eq "anlegen") { cmd /c rmdir "$($_.FullName)"; Write-Host ("{0,-18} alte Junction entfernt (Modul nicht mehr im Repo)" -f $_.Name) }
            else { Write-Host ("{0,-18} alte Junction, Modul nicht mehr im Repo (wird beim Anlegen entfernt)" -f $_.Name) }
        } else { Write-Host ("{0,-18} Junction auf {1}, nicht im Repo" -f $_.Name, $t) }
    } else { Write-Host ("{0,-18} normaler Ordner, nicht im Repo (bleibt)" -f $_.Name) }
}
if ($fehler) { exit 1 }
