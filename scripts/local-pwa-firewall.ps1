[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$LanIp,
    [Parameter(Mandatory=$true)][int]$ApiPid,
    [int]$Port = 8767,
    [int]$CertificatePort = 8768
)

$ErrorActionPreference = 'Stop'
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Execute este auxiliar como administrador.'
}
$address = Get-NetIPAddress -AddressFamily IPv4 -IPAddress $LanIp -ErrorAction SilentlyContinue | Select-Object -First 1
$proc = Get-CimInstance Win32_Process -Filter "ProcessId=$ApiPid" -ErrorAction SilentlyContinue
if (-not $address -or $LanIp -notmatch '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)' -or
    -not $proc -or $proc.CommandLine -notlike '*gogdely_api.main:app*') {
    throw 'Servidor GOGDELY e IP privado ativos são necessários.'
}
$ruleName = 'GOGDELY-Local-PWA-Temporary'
Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
try {
    $rule = @{
        Name=$ruleName; DisplayName='GOGDELY PWA local temporário'; Direction='Inbound';
        Action='Allow'; Protocol='TCP'; Profile='Any'; LocalAddress=$LanIp;
        LocalPort=@($Port,$CertificatePort); RemoteAddress='LocalSubnet'; InterfaceAlias=$address.InterfaceAlias
    }
    if ($LanIp -eq '192.168.137.1' -and $address.PrefixLength -eq 24) {
        $rule.RemoteAddress = '192.168.137.0/24'
        $rule.Remove('InterfaceAlias')
    }
    New-NetFirewallRule @rule | Out-Null
    while ($true) {
        Start-Sleep -Seconds 3
        $proc = Get-CimInstance Win32_Process -Filter "ProcessId=$ApiPid" -ErrorAction SilentlyContinue
        if (-not $proc -or $proc.CommandLine -notlike '*gogdely_api.main:app*') { break }
    }
} finally {
    Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
}
