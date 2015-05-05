# mysql-proxy-logger
Logging scripts for Mysql Proxy

proxy script logs all Mysql traffic (querries, not results) and displays color highlighted querries in console

## Setup:
- copy scripts to your `<mysql-proxy-home>/lib/mysql-proxy/lua` directory
- fix paths in config file and batch file and logging path in the `logger.lua` file
- change your application mysql server address to `127.0.0.1`, port `3307`
- start the proxy via batch file
