# Copyright 2019 Aleksey Chudov <aleksey.chudov@gmail.com>
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

$ErrorActionPreference = "Stop"

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$basePath = Split-Path -Parent $scriptPath
$buildPath = Join-Path -Path $basePath -ChildPath "build"
$customResourcesPath = Join-Path -Path $buildPath -ChildPath "CustomResources"
$customScriptsPath = Join-Path -Path $scriptPath -ChildPath "CustomScripts"

$cloudbaseInitConfigPath = Join-Path -Path $scriptPath -ChildPath "cloudbase-init\cloudbase-init.conf"
$cloudbaseInitUnattendedConfigPath = Join-Path -Path $scriptPath -ChildPath "cloudbase-init\cloudbase-init-unattend.conf"

# Create directories
New-Item -Force -ItemType Directory -Path $buildPath | Out-Null
New-Item -Force -ItemType Directory -Path $customResourcesPath | Out-Null

# Update Git submodules
git -C $basePath submodule update --init
if ($LASTEXITCODE) {
    throw "Failed to update git modules."
}

# Reload modules
try {
    Join-Path -Path $basePath -ChildPath "Config.psm1" | Remove-Module -ErrorAction SilentlyContinue
    Join-Path -Path $basePath -ChildPath "WinImageBuilder.psm1" | Remove-Module -ErrorAction SilentlyContinue
    Join-Path -Path $basePath -ChildPath "UnattendResources\ini.psm1" | Remove-Module -ErrorAction SilentlyContinue
} finally {
    Join-Path -Path $basePath -ChildPath "Config.psm1" | Import-Module
    Join-Path -Path $basePath -ChildPath "WinImageBuilder.psm1" | Import-Module
    Join-Path -Path $basePath -ChildPath "UnattendResources\ini.psm1" | Import-Module
}

# The wim file path is the installation image on the Windows ISO
$wimFilePath = "D:\Sources\install.wim"

# Every Windows ISO can contain multiple Windows versions like Home, Pro, Standard, Datacenter, etc.
$images = Get-WimFileImagesInfo -WimFilePath $wimFilePath

# E.g. for Windows Server ISO the second image version is the Standard one
# $image = $images[1]

if (!$image) {
    $images | Format-table | Out-string | Write-Host
    [int]$imageIndex = Read-Host "Enter Windows ImageIndex to build"
    $image = $images[$imageIndex - 1]
}

# The Windows image file that will be generated
$windowsImageName = "{0}.qcow2" -f $image.ImageName, $image.ImageArchitecture -replace " ", "-"
$windowsImagePath = Join-Path -Path $buildPath -ChildPath $windowsImageName

# VirtIO ISO contains guest drivers for the KVM hypervisor
$virtIOISOPath = Join-Path -Path $buildPath -ChildPath "virtio.iso"
$virtIOISOLink = "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.173-2/virtio-win-0.1.173.iso"

# Download the VirtIO ISO
Write-Host "Downloading the VirtIO ISO from $virtIOISOLink..."
(New-Object System.Net.WebClient).DownloadFile($virtIOISOLink, $virtIOISOPath)

# QEMU Guest Agent https://wiki.libvirt.org/page/Qemu_guest_agent
$qemuGaMsiPath = Join-Path -Path $customResourcesPath -ChildPath "qemu-ga-x64.msi"
$qemuGaMsiLink = "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-qemu-ga/qemu-ga-win-100.0.0.0-3.el7ev/qemu-ga-x64.msi"

# Download the QEMU Guest Agent
Write-Host "Downloading the QEMU Guest Agent from $qemuGaMsiLink..."
(New-Object System.Net.WebClient).DownloadFile($qemuGaMsiLink, $qemuGaMsiPath)

# Make sure the switch exists and allows Internet access for updates to be installed
$switchName = "Default Switch"

# Create config file
$configFilePath = Join-Path $buildPath -ChildPath "config.ini"
New-WindowsImageConfig -ConfigFilePath $configFilePath

# See Config.psm1 for available options
Set-IniFileValue -Path $configFilePath -Section "Default" -Key "wim_file_path" -Value $wimFilePath
Set-IniFileValue -Path $configFilePath -Section "Default" -Key "image_name" -Value $image.ImageName
Set-IniFileValue -Path $configFilePath -Section "Default" -Key "image_path" -Value $windowsImagePath
Set-IniFileValue -Path $configFilePath -Section "Default" -Key "virtual_disk_format" -Value "QCOW2"
Set-IniFileValue -Path $configFilePath -Section "Default" -Key "image_type" -Value "KVM"
Set-IniFileValue -Path $configFilePath -Section "Default" -Key "force" -Value "True"
Set-IniFileValue -Path $configFilePath -Section "Default" -Key "custom_resources_path" -Value $customResourcesPath
Set-IniFileValue -Path $configFilePath -Section "Default" -Key "custom_scripts_path" -Value $customScriptsPath
Set-IniFileValue -Path $configFilePath -Section "Default" -Key "enable_administrator_account" -Value "False"
Set-IniFileValue -Path $configFilePath -Section "Default" -Key "enable_custom_wallpaper" -Value "False"
Set-IniFileValue -Path $configFilePath -Section "Default" -Key "disable_first_logon_animation" -Value "True"
Set-IniFileValue -Path $configFilePath -Section "Default" -Key "zero_unused_volume_sectors" -Value "True"

Set-IniFileValue -Path $configFilePath -Section "vm" -Key "external_switch" -Value $switchName
Set-IniFileValue -Path $configFilePath -Section "vm" -Key "cpu_count" -Value 1
Set-IniFileValue -Path $configFilePath -Section "vm" -Key "ram_size" -Value (2GB)
Set-IniFileValue -Path $configFilePath -Section "vm" -Key "disk_size" -Value (30GB)

Set-IniFileValue -Path $configFilePath -Section "drivers" -Key "virtio_iso_path" -Value $virtIOISOPath

Set-IniFileValue -Path $configFilePath -Section "updates" -Key "install_updates" -Value "False"
Set-IniFileValue -Path $configFilePath -Section "updates" -Key "purge_updates" -Value "True"

Set-IniFileValue -Path $configFilePath -Section "sysprep" -Key "disable_swap" -Value "True"

Set-IniFileValue -Path $configFilePath -Section "cloudbase_init" -Key "cloudbase_init_config_path" -Value $cloudbaseInitConfigPath
Set-IniFileValue -Path $configFilePath -Section "cloudbase_init" -Key "cloudbase_init_unattended_config_path" -Value $cloudbaseInitUnattendedConfigPath
Set-IniFileValue -Path $configFilePath -Section "cloudbase_init" -Key "cloudbase_init_use_local_system" -Value "True"

# This scripts generates a QCOW2 image file, that can be used with KVM
New-WindowsOnlineImage -ConfigFilePath $configFilePath
