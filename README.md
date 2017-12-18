# Invoke-SocksProxy
Creates a Socks proxy using powershell.

Supports both Socks4 and Socks5 connections.

# Examples

Create a Socks 4/5 proxy on port 1234:
```
Import-Module .\Invoke-SocksProxy.psm1
Invoke-SocksProxy -bindPort 1234
```
Create a simple tcp port forward:
```
Import-Module .\Invoke-SocksProxy.psm1
Invoke-PortFwd -bindPort 33389 -destHost 127.0.0.1 -destPort 3389
```
# Limitations
- This is only a subset of the Socks 4 and 5 protocols: It does not support authentication, It does not support UDP or bind requests.
- New features will be implemented in the future. PR are welcome.


