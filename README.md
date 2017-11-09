# Invoke-SocksProxy
Creates a Socks proxy using powershell.

# Examples

Create a Socks5 proxy on port 1234:
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
It only supports Socks5 at the moment although socks4 will be easy to implement. (Windows system proxy is Socks4).
This is only a subset of the full Socks5 protocol: It does not support authentication, It does not support UDP or bind requests.

New features will be implemented in the future. PR are welcome.


