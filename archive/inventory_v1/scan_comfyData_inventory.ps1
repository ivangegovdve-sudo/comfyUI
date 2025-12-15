param(
  [string]$DataRoot = "C:\Ivan\_StableDiffusion\comfyData",
  [string]$OutDir   = ".\inventory"
)

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function Scan-Folder {
  param($Path, $Extensions)
  if (!(Test-Path $Path)) { return @() }
  Get-ChildItem -Path $Path -Recurse -File |
    Where-Object { $Extensions -contains $_.Extension.ToLower() } |
    ForEach-Object {
      [ordered]@{
        name = $_.Name
        relative_path = $_.FullName.Replace($DataRoot, "").TrimStart("\")
        size_mb = [math]::Round($_.Length / 1MB, 2)
        modified = $_.LastWriteTime.ToString("s")
      }
    }
}

$inventory = [ordered]@{
  generated_at = (Get-Date).ToString("s")
  data_root = $DataRoot
  checkpoints = Scan-Folder "$DataRoot\checkpoints" @(".safetensors", ".ckpt")
  loras       = Scan-Folder "$DataRoot\loras"       @(".safetensors", ".pt")
  embeddings  = Scan-Folder "$DataRoot\embeddings"  @(".pt", ".bin")
  vae         = Scan-Folder "$DataRoot\vae"         @(".safetensors", ".ckpt")
  controlnet  = Scan-Folder "$DataRoot\controlnet"  @(".safetensors", ".pth")
  upscalers   = Scan-Folder "$DataRoot\upscale_models" @(".pth", ".onnx")
}

$inventory | ConvertTo-Json -Depth 5 |
  Set-Content -Encoding UTF8 (Join-Path $OutDir "comfyData_inventory.json")

"OK: inventory written to inventory\comfyData_inventory.json"
