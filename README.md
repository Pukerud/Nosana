# Nosana

Scripts and tools for the Nosana project.

---

## Windows Remote Access Setup

Makes any Windows machine on your LAN accessible to a pi agent via SSH and WinRM. Tested on Windows 10 and 11.

### Quick Start

1. **Download** `enable-remote-access.bat` onto the target Windows machine
2. **Right-click → "Run as Administrator"**
3. Done — pi can now SSH in

### What It Does

| Step | What |
|------|------|
| 1 | Sets network profile to **Private** (required for firewall rules to work) |
| 2 | Creates **pi-admin** user with admin rights (password: `pi-admin-2024`) |
| 3 | Installs and starts **OpenSSH Server** on port 22 (auto-starts on boot) |
| 4 | Opens **firewall rule** for SSH (port 22) |
| 5 | Enables **WinRM** on port 5985 (PowerShell remoting) |
| 6 | Saves connection info to Desktop |

### Connecting from pi

```python
import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('192.168.1.X', username='pi-admin', password='pi-admin-2024', timeout=10)

stdin, stdout, stderr = ssh.exec_command('hostname')
print(stdout.read().decode())
ssh.close()
```

### Finding the Machine

Scan your LAN for Windows machines with SSH open:

```python
import socket

for i in range(1, 255):
    ip = f'192.168.1.{i}'
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(0.5)
        if s.connect_ex((ip, 22)) == 0:
            hostname = socket.gethostbyaddr(ip)[0]
            print(f'{ip}: {hostname}')
        s.close()
    except:
        pass
```

### Troubleshooting

**"SSH installed but can't connect"** — The network profile is likely set to Public. Run this as admin:

```powershell
Set-NetConnectionProfile -NetworkCategory Private
Enable-NetFirewallRule -DisplayName "OpenSSH Server (sshd)"
Restart-Service sshd
```

**"WinRM failed with network type error"** — Same fix: set network to Private first. The bat file handles this automatically.

**"Can't find the machine"** — Check the IP on the machine (`ipconfig` in cmd). It may be on a different subnet.

### Default Credentials

| | |
|---|---|
| Username | `pi-admin` |
| Password | `pi-admin-2024` |
| SSH Port | `22` |
| WinRM Port | `5985` |

### Files

- **`enable-remote-access.bat`** — One-click setup (run as admin). Does everything.
- **`enable-remote-access.ps1`** — PowerShell version with more options (custom username/password, skip user creation, etc.)
