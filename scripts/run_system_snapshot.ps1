param(
  [string]$RepoRoot = "C:\Ivan\_StableDiffusion\comfyUI_repo",
  [string]$DataRoot = "C:\Ivan\_StableDiffusion\comfyData"
)

$ts = Get-Date -Format "yyyy-MM-dd_HHmmss"
$SnapshotRoot = Join-Path $RepoRoot "inventory\snapshots\snapshot_$ts"

New-Item -ItemType Directory -Force -Path $SnapshotRoot | Out-Null

$summaryFile = Join-Path $SnapshotRoot "snapshot_summary.txt"

@"
snapshot_time = $ts
repo_root = $RepoRoot
data_root = $DataRoot
snapshot_root = $SnapshotRoot
"@ | Set-Content -Encoding UTF8 $summaryFile

# --- Models summary ---
$modelsSummarySrc = Join-Path $RepoRoot "inventory\comfyData_summary_v2.txt"
if (Test-Path $modelsSummarySrc) {
  Copy-Item $modelsSummarySrc (Join-Path $SnapshotRoot "models_summary.txt") -Force
  Add-Content $summaryFile "models_summary = models_summary.txt"
}

# --- Workflows summary ---
$wfDir = Join-Path $RepoRoot "workflows"
$wfOut = Join-Path $SnapshotRoot "workflows_summary.txt"
if (Test-Path $wfDir) {
  Get-ChildItem $wfDir -File -Filter *.json |
    Sort-Object LastWriteTime -Descending |
    Select-Object Name, Length, LastWriteTime |
    Format-Table -AutoSize |
    Out-String |
    Set-Content -Encoding UTF8 $wfOut
  Add-Content $summaryFile "workflows_summary = workflows_summary.txt"
}

# --- Custom nodes (direct) ---
$nodesDir = Join-Path $DataRoot "custom_nodes"
$nodesOut = Join-Path $SnapshotRoot "custom_nodes_summary.txt"
if (Test-Path $nodesDir) {
  Get-ChildItem $nodesDir -Directory |
    Sort-Object Name |
    Select-Object Name, LastWriteTime |
    Format-Table -AutoSize |
    Out-String |
    Set-Content -Encoding UTF8 $nodesOut
  Add-Content $summaryFile "custom_nodes_summary = custom_nodes_summary.txt"
}

# --- ComfyUI-Manager nodes ---
$mgrCache = Join-Path $DataRoot "user\__manager\cache"
$mgrOut   = Join-Path $SnapshotRoot "manager_nodes_summary.txt"

if (Test-Path $mgrCache) {
  Get-ChildItem $mgrCache -File -Filter "*nodes*.json" |
    Sort-Object LastWriteTime -Descending |
    Select-Object Name, LastWriteTime |
    Format-Table -AutoSize |
    Out-String |
    Set-Content -Encoding UTF8 $mgrOut

  Add-Content $summaryFile "manager_nodes_summary = manager_nodes_summary.txt"
}

"OK: FULL snapshot written to $SnapshotRoot"
