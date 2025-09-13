# Define download URL and destination path
$downloadUrl = "https://downloads.nicecloudsvc.com/8.0/rcp-installer-8.0.4.0.exe"
$destinationFolder = "D:\test proj"
$installerPath = Join-Path $destinationFolder "rcp-installer-8.0.4.0.exe"

# Create folder if it doesn't exist
if (-Not (Test-Path -Path $destinationFolder)) {
    Write-Host "[*] Creating folder: $destinationFolder"
    New-Item -ItemType Directory -Path $destinationFolder -Force | Out-Null
}

# Download the file
Write-Host "[*] Downloading installer to: $installerPath"
Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath

# Verify download
if (Test-Path $installerPath) {
    Write-Host "[*] Download complete!"
    Write-Host "[*] Launching installer..."
    Start-Process -FilePath $installerPath -Wait
} else {
    Write-Host "[!] Download failed!"
    exit 1
}
