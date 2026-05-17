@echo off
:: ═══════════════════════════════════════════════════════════════
:: Windows Remote Access Setup for pi Agent
:: Run as Administrator: Right-click ^> Run as Administrator
:: ═══════════════════════════════════════════════════════════════

:: Check if admin
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo.
    echo ERROR: Run this as Administrator!
    echo Right-click this file ^> "Run as Administrator"
    echo.
    pause
    exit /b 1
)

echo.
echo ============================================
echo   Windows Remote Access Setup for pi
echo ============================================
echo.

:: ── 1. Set network to Private (required for firewall rules) ──
echo [1/5] Setting network to Private...
powershell -Command "Set-NetConnectionProfile -NetworkCategory Private"
echo   Done.
echo.

:: ── 2. Create pi-admin user ──
echo [2/5] Creating pi-admin user...
powershell -Command "$u = Get-LocalUser -Name 'pi-admin' -ErrorAction SilentlyContinue; if ($u) { Write-Host '  User already exists.' } else { $p = ConvertTo-SecureString 'pi-admin-2024' -AsPlainText -Force; New-LocalUser -Name 'pi-admin' -Password $p -Description 'Remote admin for pi' -AccountNeverExpires -UserMayNotChangePassword; Add-LocalGroupMember -Group 'Administrators' -Member 'pi-admin'; Write-Host '  Created pi-admin with password pi-admin-2024' }"
echo.

:: ── 3. Install and start OpenSSH Server ──
echo [3/5] Installing OpenSSH Server...
powershell -Command "$cap = Get-WindowsCapability -Online -Name 'OpenSSH.Server*'; if ($cap.State -ne 'Installed') { Add-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0'; Write-Host '  Installed.' } else { Write-Host '  Already installed.' }"
echo   Starting SSH service...
sc config sshd start= auto
net start sshd >nul 2>&1
echo   SSH running on port 22.
echo.

:: ── 4. Open firewall for SSH ──
echo [4/5] Opening firewall for SSH...
powershell -Command "$r = Get-NetFirewallRule -DisplayName 'OpenSSH Server (sshd)' -ErrorAction SilentlyContinue; if ($r) { Enable-NetFirewallRule -DisplayName 'OpenSSH Server (sshd)'; Write-Host '  Enabled existing rule.' } else { New-NetFirewallRule -DisplayName 'OpenSSH Server (sshd)' -Direction Inbound -Protocol TCP -LocalPort 22 -Action Allow -Profile Any; Write-Host '  Created firewall rule for port 22.' }"
echo.

:: ── 5. Enable WinRM ──
echo [5/5] Enabling WinRM...
powershell -Command "winrm quickconfig -quiet 2>$null; Set-Item WSMan:\localhost\Client\TrustedHosts '*' -Force -ErrorAction SilentlyContinue; Set-Item WSMan:\localhost\Service\Auth\Basic true -Force -ErrorAction SilentlyContinue; Restart-Service WinRM -Force -ErrorAction SilentlyContinue; Write-Host '  WinRM enabled.'"
echo.

:: ── Done ──
echo ============================================
echo   SETUP COMPLETE!
echo ============================================
echo.
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /C:"IPv4"') do (
    for /f "tokens=*" %%b in ("%%a") do echo   IP: %%b
)
echo.
echo   SSH:   ssh pi-admin@^<IP^>  (password: pi-admin-2024)
echo   WinRM: port 5985
echo.
echo   pi can now connect via paramiko:
echo     ssh.connect('IP', username='pi-admin', password='pi-admin-2024')
echo.

:: Save info to desktop
powershell -Command "$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike '*Loopback*' -and $_.IPAddress -notlike '127.*' } | Select-Object -First 1).IPAddress; \"pi Remote Access`n==============`nIP: $ip`nUser: pi-admin`nPass: pi-admin-2024`nSSH port: 22`nWinRM port: 5985\" | Set-Content \"$env:USERPROFILE\Desktop\pi-remote-access.txt\" -Force"
echo   Info saved to Desktop\pi-remote-access.txt
echo.
pause
