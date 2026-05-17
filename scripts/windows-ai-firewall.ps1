# Run elevated once on the Windows AI laptop.
# Allows inbound gRPC TCP 50051 from hotspot LAN and common Docker Desktop subnets.

$ErrorActionPreference = 'Stop'
$port = 50051

function Add-FwRule {
    param([string]$Name, [string]$RemoteIp = 'any')
    if (Get-NetFirewallRule -DisplayName $Name -ErrorAction SilentlyContinue) {
        Write-Host "OK (exists): $Name"
        return
    }
    New-NetFirewallRule -DisplayName $Name -Direction Inbound -Action Allow `
        -Protocol TCP -LocalPort $port -RemoteAddress $RemoteIp `
        -Profile Private, Public | Out-Null
    Write-Host "Added: $Name"
}

Add-FwRule -Name 'ManyFaces AI gRPC 50051'
Add-FwRule -Name 'ManyFaces AI gRPC 50051 (172.20.10 LAN)' -RemoteIp '172.20.10.0/24'
Add-FwRule -Name 'ManyFaces AI gRPC 50051 (Mac Docker 192.168.65)' -RemoteIp '192.168.65.0/24'
Add-FwRule -Name 'ManyFaces AI gRPC 50051 (Docker 172.16-31)' -RemoteIp '172.16.0.0/12'
