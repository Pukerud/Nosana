# Nosana

Scripts and tools for the Nosana project.

---

## Windows Remote Access Setup

Run this **as Administrator** in PowerShell on the target Windows machine:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Pukerud/Nosana/main/enable-remote-access.ps1" -OutFile "enable-remote-access.ps1"; .\enable-remote-access.ps1
```

This enables SSH (port 22) + WinRM (port 5985), creates a `pi-admin` user, and opens firewall rules.

### Options

```powershell
# Use your existing Windows login instead of creating a new user
.\enable-remote-access.ps1 -SkipUserCreation

# Custom username and password
.\enable-remote-access.ps1 -Username "myuser" -Password "MyPass123!"
```
