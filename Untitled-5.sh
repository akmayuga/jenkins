# Define the URL and local file name
$downloadUrl = "https://downloads.nicecloudsvc.com/8.0/rcp-installer-8.0.4.0.exe"
$installerPath = "$env:TEMP\rcp-installer-8.0.4.0.exe"

Write-Host "[*] Downloading installer from $downloadUrl..."

# Download the file
Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath

# Check if the file was downloaded
if (Test-Path $installerPath) {
    Write-Host "[*] Download complete: $installerPath"
    
    # Run the installer
    Write-Host "[*] Running installer..."
    Start-Process -FilePath $installerPath -Wait
} else {
    Write-Host "[!] Download failed."
    exit 1
}
