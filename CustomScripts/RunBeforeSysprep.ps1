# See description of "custom_resources_path" and "custom_scripts_path" in Config.psm1 for details

$resourcesPath = "$ENV:SystemDrive\UnattendResources"
$customResourcesPath = "$resourcesPath\CustomResources"

function Enable-AdministratorAccount {
    $setupCompletePath = "$ENV:windir\Setup\Scripts\SetupComplete.cmd"
    $activate = "net user Administrator /active:yes"
    Add-Content -Encoding Ascii -Value $activate -Path $setupCompletePath
    Write-Log "Administrator" "Account was enabled succesfully"
}

function Install-Msi {
    Param(
        [parameter(Mandatory=$true)]
        [string]$description,
        [parameter(Mandatory=$true)]
        [string]$file
    )

    $Host.UI.RawUI.WindowTitle = "Installing $description from $file..."
    $p = Start-Process -Wait -PassThru -FilePath msiexec -ArgumentList "/i $file /qn"
    if ($p.ExitCode -ne 0) {
        throw "Installation of $description from $file failed."
    }
}

function Is-WindowsClient {
    $path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
    if ((Get-ItemProperty -Path $path -Name "InstallationType").InstallationType -eq "Client") {
        return $true
    }
    return $false
}

Install-Msi -description "QEMU Guest Agent" -file "$customResourcesPath\qemu-ga-x64.msi"

if (Is-WindowsClient) {
    Enable-AdministratorAccount

    Remove-LocalUser -Name "Admin" -ErrorAction SilentlyContinue
}
