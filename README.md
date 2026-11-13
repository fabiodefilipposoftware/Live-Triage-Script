# Live-Triage-Script
A linux and a Windows powershell scripts for a live triage of a remote host:
1. for Windows is required psexec;
2. for Linux is required ssh;

## HOW TO USE THEM:

1. Windows:
```
powershell.exe -ExecutionPolicy Bypass -File ".\windows-live-remote-triage.ps1" -NomePC "PC-REMOTO" -Utente "DOMINIO\Admin"
```

2. Linux:
```
linux-live-remote-triage.sh remote-username@remote.ip
```
