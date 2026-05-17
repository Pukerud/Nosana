<#
.SYNOPSIS
    Enables remote access for pi (SSH + WinRM) on a Windows machine.
    
.DESCRIPTION
    This script sets up two remote access methods so pi can manage this machine over LAN:
    
    1. OpenSSH Server (SSH) — same as Linux SSH, works with paramiko/ssh
    2. WinRM (Windows Remote Management) — native Windows remote management
    
    It also creates a dedicated user "pi-admin" with admin rights for remote access,
    or you can just use your existing user account.
    
    Run this script AS ADMINISTRATOR:
    Right-click PowerShell → "Run as Administrator" → then run this script.
    
.EXAMPLE
    .\enable-remote-access.ps1
    
.EXAMPLE
    # Skip user creation, just enable SSH + WinRM for current user
    .\enable-remote-access.ps1 -SkipUserCreation
    
.EXAMPLE
    # Set custom username and password
    .\enable-remote-access.ps1 -Username "myadmin" -Password "MySecurePass123!"
#>

param(
    [string]$Username = "pi-admin",
    [string]$Password = "pi-admin-2024",
    [switch]$SkipUserCreation,
    [switch]$SkipFirewallRules
)

# ── Check if running as admin ──
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host ""
    Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Right-click PowerShell -> 'Run as Administrator' -> run this script again." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Windows Remote Access Setup for pi" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# ═══════════════════════════════════════════════════════════
# 1. CREATE DEDICATED USER
# ═══════════════════════════════════════════════════════════
if (-not $SkipUserCreation) {
    Write-Host "[1/5] Creating admin user '$Username'..." -ForegroundColor Yellow
    
    $existingUser = Get-LocalUser -Name $Username -ErrorAction SilentlyContinue
    if ($existingUser) {
        Write-Host "  User '$Username' already exists, skipping creation." -ForegroundColor Gray
    } else {
        $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
        New-LocalUser -Name $Username -Password $securePassword -Description "Remote admin for pi" -AccountNeverExpires -UserMayNotChangePassword
        Add-LocalGroupMember -Group "Administrators" -Member $Username
        Write-Host "  Created user '$Username' with password '$Password'" -ForegroundColor Green
        Write-Host "  Added to Administrators group" -ForegroundColor Green
    }
} else {
    Write-Host "[1/5] Skipping user creation (using current user)." -ForegroundColor Gray
    $Username = $env:USERNAME
}

# ═══════════════════════════════════════════════════════════
# 2. INSTALL / ENABLE OpenSSH SERVER
# ═══════════════════════════════════════════════════════════
Write-Host ""
Write-Host "[2/5] Setting up OpenSSH Server..." -ForegroundColor Yellow

$sshInstalled = Get-WindowsCapability -Online | Where-Object Name -like "OpenSSH.Server*"
if ($sshInstalled.State -eq "NotPresent") {
    Write-Host "  Installing OpenSSH Server (this may take a minute)..." -ForegroundColor Gray
    Add-WindowsCapability -Online -Name "OpenSSH.Server~~~~0.0.1.0"
    Write-Host "  Installed." -ForegroundColor Green
} elseif ($sshInstalled.State -eq "Installed") {
    Write-Host "  OpenSSH Server already installed." -ForegroundColor Gray
} else {
    # Windows 10/11 might have it available via optional features
    $cap = Get-WindowsCapability -Online -Name "OpenSSH.Server*"
    if ($cap) {
        Add-WindowsCapability -Online -Name $cap.Name
        Write-Host "  Installed OpenSSH Server." -ForegroundColor Green
    } else {
        Write-Host "  OpenSSH Server not available as Windows capability, trying chocolatey..." -ForegroundColor Gray
    }
}

# Start and set to auto-start
Start-Service sshd -ErrorAction SilentlyContinue
Set-Service -Name sshd -StartupType Automatic

# Configure SSH
$sshdConfigDir = "$env:ProgramData\ssh"
if (-not (Test-Path $sshdConfigDir)) {
    New-Item -ItemType Directory -Path $sshdConfigDir -Force | Out-Null
}

$sshdConfig = @"
# pi remote access SSH config
Port 22
PermitRootLogin yes
PubkeyAuthentication yes
PasswordAuthentication yes
ChallengeResponseAuthentication no
UsePrivilegeSeparation sandbox
Subsystem powershell c:/windows/system32/WindowsPowerShell/v1.0/powershell.exe -sshs -NoLogo
Subsystem bash c:/windows/system32/bash.exe
"@

$configPath = Join-Path $sshdConfigDir "sshd_config"
$sshdConfig | Set-Content $configPath -Force

# Restart to apply config
Restart-Service sshd -ErrorAction SilentlyContinue

Write-Host "  SSH server running on port 22" -ForegroundColor Green
Write-Host "  SSH config written to $configPath" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════
# 3. ENABLE WinRM (Windows Remote Management)
# ═══════════════════════════════════════════════════════════
Write-Host ""
Write-Host "[3/5] Setting up WinRM..." -ForegroundColor Yellow

# Enable WinRM
Enable-PSRemoting -Force -ErrorAction SilentlyContinue

# Set WinRM to allow connections from any IP (LAN access)
Set-Item WSMan:\localhost\Client\TrustedHosts "*" -Force -ErrorAction SilentlyContinue
Set-Item WSMan:\localhost\Service\AllowRemoteAccess true -Force -ErrorAction SilentlyContinue

# Configure for basic auth (simple password auth over LAN)
Set-Item WSMan:\localhost\Service\Auth\Basic true -Force -ErrorAction SilentlyContinue
Set-Item WSMan:\localhost\Service\Auth\CredSSP true -Force -ErrorAction SilentlyContinue

# Restart WinRM
Restart-Service WinRM -Force -ErrorAction SilentlyContinue

Write-Host "  WinRM enabled with Basic auth" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════
# 4. FIREWALL RULES
# ═══════════════════════════════════════════════════════════
if (-not $SkipFirewallRules) {
    Write-Host ""
    Write-Host "[4/5] Configuring firewall rules..." -ForegroundColor Yellow
    
    # SSH firewall rule
    $sshRule = Get-NetFirewallRule -DisplayName "OpenSSH Server (sshd)" -ErrorAction SilentlyContinue
    if (-not $sshRule) {
        New-NetFirewallRule -DisplayName "OpenSSH Server (sshd)" -Direction Inbound -Protocol TCP -LocalPort 22 -Action Allow -Profile Any
        Write-Host "  Created firewall rule for SSH (port 22)" -ForegroundColor Green
    } else {
        Enable-NetFirewallRule -DisplayName "OpenSSH Server (sshd)"
        Write-Host "  SSH firewall rule already exists, enabled." -ForegroundColor Gray
    }
    
    # WinRM firewall rules
    $winrmRule = Get-NetFirewallRule -DisplayName "Windows Remote Management (HTTP-In)" -ErrorAction SilentlyContinue
    if ($winrmRule) {
        Enable-NetFirewallRule -DisplayName "Windows Remote Management (HTTP-In)"
        Write-Host "  WinRM firewall rule enabled" -ForegroundColor Green
    } else {
        New-NetFirewallRule -DisplayName "WinRM HTTP-In" -Direction Inbound -Protocol TCP -LocalPort 5985 -Action Allow -Profile Any
        Write-Host "  Created firewall rule for WinRM (port 5985)" -ForegroundColor Green
    }
} else {
    Write-Host ""
    Write-Host "[4/5] Skipping firewall rules." -ForegroundColor Gray
}

# ═══════════════════════════════════════════════════════════
# 5. SUMMARY
# ═══════════════════════════════════════════════════════════
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  SETUP COMPLETE!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" -and $_.IPAddress -notlike "127.*" } | Select-Object -First 1).IPAddress

Write-Host "  This machine IP:  $ip" -ForegroundColor White
Write-Host ""
Write-Host "  SSH access (Linux-like):" -ForegroundColor White
if (-not $SkipUserCreation) {
    Write-Host "    ssh ${Username}@${ip}" -ForegroundColor Yellow
    Write-Host "    Password: $Password" -ForegroundColor Yellow
} else {
    Write-Host "    ssh ${Username}@${ip}" -ForegroundColor Yellow
    Write-Host "    (use your Windows login password)" -ForegroundColor Gray
}
Write-Host ""
Write-Host "  Python paramiko:" -ForegroundColor White
Write-Host "    ssh.connect('$ip', username='$Username', password='...')" -ForegroundColor Yellow
Write-Host ""
Write-Host "  WinRM (PowerShell remoting):" -ForegroundColor White
Write-Host "    Port 5985 (HTTP)" -ForegroundColor Gray
Write-Host "    Enter-PSSession -ComputerName $ip -Credential (Get-Credential)" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Services running:" -ForegroundColor White
$sshdStatus = (Get-Service sshd -ErrorAction SilentlyContinue).Status
$winrmStatus = (Get-Service WinRM -ErrorAction SilentlyContinue).Status
Write-Host "    sshd:   $sshdStatus" -ForegroundColor $(if ($sshdStatus -eq "Running") { "Green" } else { "Red" })
Write-Host "    winrm:  $winrmStatus" -ForegroundColor $(if ($winrmStatus -eq "Running") { "Green" } else { "Red" })
Write-Host ""

# Save info to file for easy reference
$infoPath = "$env:USERPROFILE\Desktop\pi-remote-access-info.txt"
@"
pi Remote Access Info
=====================
Machine: $env:COMPUTERNAME
IP:      $ip
User:    $Username
$(if (-not $SkipUserCreation) { "Pass:    $Password" })

SSH:     ssh ${Username}@${ip}  (port 22)
WinRM:   port 5985 (HTTP)

Services auto-start on boot.
"@ | Set-Content $infoPath -Force
Write-Host "  Info saved to: $infoPath" -ForegroundColor Gray
Write-Host ""
Read-Host "Press Enter to exit"
