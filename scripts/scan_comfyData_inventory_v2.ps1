param(
  [string]$DataRoot = "C:\Ivan\_StableDiffusion\comfyData",
  [string]$OutDir   = ".\inventory"
)

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# --- Helpers ---
function RelPath([string]$full, [string]$base) {
  return $full.Replace($base, "").TrimStart("\")
}

function Get-Files([string]$path, [string[]]$exts) {
  if (!(Test-Path $path)) { return @() }
  $items = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $exts -contains $_.Extension.ToLower() } |
    ForEach-Object {
      [ordered]@{
        name = $_.Name
        relative_path = (RelPath $_.FullName $DataRoot)
        size_mb = [math]::Round($_.Length / 1MB, 2)
        modified = $_.LastWriteTime.ToString("s")
      }
    }
  return @($items)
}

# --- Known categories (ComfyUI typical + common variants) ---
$categories = @(
  @{ key="checkpoints"; folders=@("models\checkpoints","models\Stable-diffusion","checkpoints","models\Stable-diffusion"); exts=@(".safetensors",".ckpt") },
  @{ key="loras";       folders=@("models\loras","models\Lora","loras","models\Lora");                         exts=@(".safetensors",".pt") },
  @{ key="embeddings";  folders=@("models\embeddings","embeddings");                                           exts=@(".pt",".bin") },
  @{ key="vae";         folders=@("models\vae","models\VAE","vae");                                            exts=@(".safetensors",".ckpt") },
  @{ key="controlnet";  folders=@("models\controlnet","controlnet","models\ControlNet");                       exts=@(".safetensors",".pth") },
  @{ key="upscalers";   folders=@("models\upscale_models","models\upscalers","upscale_models","models\ESRGAN","models\RealESRGAN","models\SwinIR"); exts=@(".pth",".onnx",".safetensors") }
)

# --- Discover structure (top-level + models/*) ---
$dirs = @()
if (Test-Path $DataRoot) {
  $dirs += Get-ChildItem -Path $DataRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object { RelPath $_.FullName $DataRoot }
}
if (Test-Path (Join-Path $DataRoot "models")) {
  $dirs += Get-ChildItem -Path (Join-Path $DataRoot "models") -Directory -ErrorAction SilentlyContinue | ForEach-Object { "models\" + $_.Name }
}
$dirs = $dirs | Sort-Object -Unique

# --- Build inventory ---
$inv = [ordered]@{
  generated_at = (Get-Date).ToString("s")
  data_root    = $DataRoot
  discovered_dirs = $dirs
  categories = [ordered]@{}
  summary = [ordered]@{}
}

foreach ($cat in $categories) {
  $all = @()
  $usedPaths = @()

  foreach ($f in $cat.folders) {
    $p = Join-Path $DataRoot $f
    if (Test-Path $p) {
      $usedPaths += $f
      $all += Get-Files $p $cat.exts
    }
  }

  # de-dup by relative_path
  $all = $all | Sort-Object relative_path -Unique

  $totalMb = 0
  foreach ($x in $all) { $totalMb += [double]$x.size_mb }

  $inv.categories[$cat.key] = [ordered]@{
    scanned_paths = @($usedPaths)
    extensions    = @($cat.exts)
    files         = @($all)
  }

  $inv.summary[$cat.key] = [ordered]@{
    count = @($all).Count
    size_mb = [math]::Round($totalMb, 2)
    scanned_paths = @($usedPaths)
  }
}

# --- Also compute extension histogram across comfyData (fast-ish, useful for surprises) ---
$extHist = [ordered]@{}
if (Test-Path $DataRoot) {
  Get-ChildItem -Path $DataRoot -Recurse -File -ErrorAction SilentlyContinue |
    ForEach-Object {
      $e = $_.Extension.ToLower()
      if (!$e) { return }
      if (!$extHist.Contains($e)) { $extHist[$e] = 0 }
      $extHist[$e] += 1
    }
}
$inv.summary["extension_histogram"] = $extHist

# --- Write outputs ---
$inv | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 (Join-Path $OutDir "comfyData_inventory_v2.json")

# human-readable summary
$lines = @()
$lines += "generated_at: $($inv.generated_at)"
$lines += "data_root: $($inv.data_root)"
$lines += ""
$lines += "discovered_dirs:"
$inv.discovered_dirs | ForEach-Object { $lines += "  - $_" }
$lines += ""
$lines += "category_summary:"
foreach ($k in $inv.summary.Keys) {
  if ($k -eq "extension_histogram") { continue }
  $s = $inv.summary[$k]
  $lines += ("  - {0}: count={1}, size_mb={2}, paths=[{3}]" -f $k, $s.count, $s.size_mb, (($s.scanned_paths -join ", ")))
}
$lines += ""
$lines += "extension_histogram (top 25):"
$inv.summary.extension_histogram.GetEnumerator() |
  Sort-Object Value -Descending |
  Select-Object -First 25 |
  ForEach-Object { $lines += ("  {0} : {1}" -f $_.Key, $_.Value) }

$lines | Set-Content -Encoding UTF8 (Join-Path $OutDir "comfyData_summary_v2.txt")

"OK: wrote inventory\comfyData_inventory_v2.json and inventory\comfyData_summary_v2.txt"
