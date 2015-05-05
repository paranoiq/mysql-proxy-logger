set MYSQLPROXY_HOME=%programfiles(x86)%\mysql-proxy
set MYSQLPROXY=%MYSQLPROXY_HOME%\bin\mysql-proxy.exe

"%MYSQLPROXY%" --defaults-file="C:/bin/mysql-proxy/config/config.ini"