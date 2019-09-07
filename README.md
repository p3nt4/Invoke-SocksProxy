# Invoke-SocksProxy
Creates a local or "reverse" Socks proxy using powershell.

Supports both Socks4 and Socks5 connections.

# Examples

Create a Socks 4/5 proxy on port 1234:
```
Import-Module .\Invoke-SocksProxy.psm1
Invoke-SocksProxy -bindPort 1234
```

Create a "reverse" Socks 4/5 proxy on port 1234 of a remote host:
```
Import-Module .\Invoke-SocksProxy.psm1
Invoke-ReverseSocksProxy -remotePort 1234 -remoteHost 192.168.49.130
```

The "reverse" Socks 4/5 proxy can go through the system proxy:
```
Import-Module .\Invoke-SocksProxy.psm1
Invoke-ReverseSocksProxy -remotePort 1234 -remoteHost 192.168.49.130 -useSystemProxy
```
Credit: https://github.com/Arno0x/PowerShellScripts/blob/master/proxyTunnel.ps1


Increase the number of threads from 200 to 400
```
Import-Module .\Invoke-SocksProxy.psm1
Invoke-SocksProxy -threads 400
```

# Limitations
- This is only a subset of the Socks 4 and 5 protocols: It does not support authentication, It does not support UDP or bind requests.
- When the Socks Proxy runs out of available threads, new connections cannot be established until a thread is freed.
- New features will be implemented in the future. PR are welcome.


