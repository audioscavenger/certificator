@echo OFF
pushd %~dp0

:: //TODO: separate CSR from KEY

:: TOTEST:  3-step complete CA + inter + *.domain + client https://blog.behrang.org/articles/creating-a-ca-with-openssl.html
:: CURRENT: 2-step Ca + *.domain https://adfinis.com/en/blog/openssl-x509-certificates/

::  1.1.0   separated server csr from key; can regenerate csr

:init
set version=1.1.0
set author=lderewonko

call :detect_admin_mode
call :set_colors

set ORG=%USERDOMAIN%
set CADOMAIN=%USERDNSDOMAIN%
set CAPASS=%USERDNSDOMAIN%
set PFXPASS=%USERDNSDOMAIN%
set PAUSE=echo:
set RESET=
set REMOTE=

:: OPENSSL_CONF must have full path, and extension cfg on Windows. don't ask me why.
REM set OPENSSL_CONF=%~dp0openssl.github.cfg
REM set OPENSSL_CONF=%~dp0openssl.cfg
REM set OPENSSL_CONF=%~dp0openssl.MIT.cfg
REM set OPENSSL_CONF=%~dp0openssl.pki-tutorial.cfg
set OPENSSL_CONF=%~dp0openssl.%ORG%.cfg
REM set OPENSSL_CONF=%~dp0openssl.%ORG%.cfg


:prechecks
for %%x in (powershell.exe) do (set "powershell=%%~$PATH:x")
IF NOT DEFINED powershell call :error %~0: powershell NOT FOUND

call :check_exist_exit openssl.ORG.cfg
call :check_exist_exit openssl.ORG.cmd



:defaults
IF DEFINED REMOTE (
  set ORG=NQSALES
  set CADOMAIN=INTERNAL.NQSALES.COM
  set CAPASS=INTERNAL.NQSALES.COM
  set PFXPASS=INTERNAL.NQSALES.COM
) ELSE (
  set /P ORG=Organisation? [%ORG%] 
  set /P CADOMAIN=Domain? [%CADOMAIN%] 
  set /P CAPASS=Key pass? [%CAPASS%] 
  set /P PFXPASS=PFX pass? [%PFXPASS%] 
)

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:main


call :ask_for_values
call :create_cfg openssl.ORG.cfg openssl.%ORG%.cfg
call :reset
call :create_folders

REM set OPENSSL_CONF=%~dp0openssl.%ORG%.cfg
call :create_KEY
call :create_CA
call :convert_CA_PFX

REM set OPENSSL_CONF=%~dp0openssl.%CADOMAIN%.cfg
call :create_server_KEY
call :create_server_CSR
call :sign_server_CSR
call :convert_CRT_PFX
call :convert_CACRT_PFX
call :import_chain_CRT

goto :end
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:ask_for_values
echo %c%%~0%END%

IF EXIST openssl.%ORG%.cmd exit /b 0

echo:
echo   %HIGH%Please copy %c%openssl.ORG.cmd%w% into %g%openssl.%ORG%.cmd%w% and set the values inside.
echo                            Then restart this batch%END%
echo                                   Thank you
echo:
pause
exit 0
goto :EOF


:reset
echo %c%%~0%END%
IF DEFINED RESET rd /s /q %CADOMAIN% 2>NUL
goto :EOF


:create_folders
echo %c%%~0%END%

md %CADOMAIN% 2>NUL
REM md %CADOMAIN%\certs 2>NUL
REM md %CADOMAIN%\crl 2>NUL
REM md %CADOMAIN%\newcerts 2>NUL
REM md %CADOMAIN%\private 2>NUL
REM md %CADOMAIN%\req 2>NUL

:: https://serverfault.com/questions/857131/odd-error-while-using-openssl
:: https://www.linuxquestions.org/questions/linux-security-4/why-can%27t-i-generate-a-new-certificate-with-openssl-312716/
echo|set /p=>%CADOMAIN%\index.txt
echo|set /p="unique_subject = no">%CADOMAIN%\index.txt.attr

:: https://serverfault.com/questions/823679/openssl-error-while-loading-crlnumber
echo|set /p="1000">%CADOMAIN%\crlnumber

goto :EOF

:create_cfg in out
echo %c%%~0%END%

call openssl.%ORG%.cmd

:: too slow:
copy /y openssl.ORG.cfg openssl.%ORG%.cfg
REM for /f "eol=: tokens=1,2 delims==" %%V in (openssl.ORG.cmd) DO (
  REM powershell -executionPolicy bypass -Command "(Get-Content -Path '%~2') -replace '{%%V}', '%%W' | Set-Content -Path '%~2'"
REM )

powershell -executionPolicy bypass -Command ^(Get-Content %1^) ^| Foreach-Object { ^
    $_ -replace '{CADOMAIN}', '%CADOMAIN%' `^
       -replace '{ORG}', '%ORG%' `^
       -replace '{default_days}', '%default_days%' `^
       -replace '{default_bits}', '%default_bits%' `^
       -replace '{CAPASS}', '%CAPASS%' `^
       -replace '{PFXPASS}', '%PFXPASS%' `^
       -replace '{countryName}', '%countryName%' `^
       -replace '{stateOrProvinceName}', '%stateOrProvinceName%' `^
       -replace '{localityName}', '%localityName%' `^
       -replace '{organizationName}', '%organizationName%' `^
       -replace '{organizationalUnitName}', '%organizationalUnitName%' `^
       -replace '{commonName}', '%commonName%' `^
       -replace '{emailAddress}', '%emailAddress%' `^
       -replace '{postalCode}', '%postalCode%' `^
       -replace '{streetAddress}', '%streetAddress%' `^
       -replace '{unstructuredName}', '%unstructuredName%' `^
       -replace '{CPS.1}', '%CPS.1%' `^
       -replace '{CPS.2}', '%CPS.2%' `^
       -replace '{explicitText}', '%explicitText%'^
    } ^| Set-Content %2

:: special case for altnames:
for /f "tokens=1,2 delims==" %%V in ('set DNS.') DO echo %%V=%%W>>%2

goto :EOF

:create_KEY
echo %c%%~0%END%
IF EXIST %CADOMAIN%\ca.%ORG%.key.crt exit /b 0

REM openssl genrsa -aes256 -passout pass:%CAPASS% -out %CADOMAIN%\ca.%ORG%.key.crt
REM openssl req -new -newkey rsa:4096 -keyout %CADOMAIN%\ca.%ORG%.key.crt -out %CADOMAIN%\ca.%ORG%.csr -passout pass:%CAPASS%

REM openssl req -new -nodes -newkey rsa:4096 -keyout %CADOMAIN%\ca.%ORG%.key.crt -out %CADOMAIN%\ca.%ORG%.csr
openssl req -batch -new -nodes -keyout %CADOMAIN%\ca.%ORG%.key.crt -out %CADOMAIN%\ca.%ORG%.csr

:: view csr:
echo %b%  openssl req -noout -text -in %CADOMAIN%\ca.%ORG%.csr %END%
REM openssl req -noout -text -in %CADOMAIN%\ca.%ORG%.csr

:: view key:
echo %b%  openssl rsa -noout -text -in %CADOMAIN%\ca.%ORG%.key.crt -passin pass:%CADOMAIN% %END%
REM openssl rsa -noout -text -in %CADOMAIN%\ca.%ORG%.key.crt -passin pass:%CADOMAIN%

goto :EOF


::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: -extensions val     CERT extension section (override value in config file)
:: -reqexts val        REQ  extension section (override value in config file)
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::


:create_CA
echo %c%%~0%END%
IF EXIST %CADOMAIN%\ca.%ORG%.crt exit /b 0

:: PEM has no password
REM openssl req -x509 -new -nodes -sha512 -days 3650 -key %CADOMAIN%\ca.%ORG%.key.crt -passin pass:%CAPASS% -config %CADOMAIN%\%CADOMAIN%.cfg -out %CADOMAIN%\%CADOMAIN%.pem
REM openssl req -x509 -new -nodes -sha512 -days 3650 -key %CADOMAIN%\ca.%ORG%.key.crt -passin pass:%CAPASS% -config %CADOMAIN%\%CADOMAIN%.cfg -out %CADOMAIN%\ca.%ORG%.crt

:: https://www.phildev.net/ssl/creating_ca.html
REM openssl ca -batch -create_serial -days 3650 -out %CADOMAIN%\ca.%ORG%.crt -keyfile %CADOMAIN%\ca.%ORG%.key.crt -passin pass:%CAPASS% -selfsign -extensions v3_ca -infiles %CADOMAIN%\ca.%ORG%.csr
REM openssl ca -batch -create_serial -rand_serial -subj "/CN=%ORG% CA/OU=OPS/O=%ORG%" -out %CADOMAIN%\ca.%ORG%.crt -passin pass:%CAPASS% -keyfile %CADOMAIN%\ca.%ORG%.key.crt -selfsign -extensions v3_ca -infiles %CADOMAIN%\ca.%ORG%.csr

:: https://adfinis.com/en/blog/openssl-x509-certificates/
openssl x509 -req -sha512 -days 3650 -extfile openssl.%ORG%.cfg -extensions nq_ca -in %CADOMAIN%\ca.%ORG%.csr -signkey %CADOMAIN%\ca.%ORG%.key.crt -out %CADOMAIN%\ca.%ORG%.crt
REM openssl x509 -req -sha512 -days 3650 -extensions nq_ca -in %CADOMAIN%\ca.%ORG%.csr -signkey %CADOMAIN%\ca.%ORG%.key.crt -out %CADOMAIN%\ca.%ORG%.crt
IF %ERRORLEVEL% NEQ 0 pause

:: verify it:
echo %b%  openssl x509 -text -noout -in %CADOMAIN%\ca.%ORG%.crt %END%
REM openssl x509 -text -noout -in %CADOMAIN%\ca.%ORG%.crt
goto :EOF

:convert_CA_PFX
echo %c%%~0%END%
IF EXIST %CADOMAIN%\ca.%ORG%.pfx exit /b 0

REM openssl pkcs12 -export -name "%ORG% CA" -inkey %CADOMAIN%\ca.%ORG%.key.crt -passin pass:%CAPASS% -in %CADOMAIN%\%CADOMAIN%.pem -out %CADOMAIN%\ca.%ORG%.pfx -passout pass:%PFXPASS%
REM openssl pkcs12 -export -name "%ORG% CA" -inkey %CADOMAIN%\ca.%ORG%.key.crt -passin pass:%CAPASS% -in %CADOMAIN%\ca.%ORG%.crt -out %CADOMAIN%\ca.%ORG%.pfx -passout pass:%PFXPASS%

:: https://www.phildev.net/ssl/creating_ca.html
openssl pkcs12 -export -name "%ORG% CA" -inkey %CADOMAIN%\ca.%ORG%.key.crt -passin pass:%CAPASS% -in %CADOMAIN%\ca.%ORG%.crt -passout pass:%PFXPASS% -out %CADOMAIN%\ca.%ORG%.pfx
IF %ERRORLEVEL% NEQ 0 pause

echo certutil -f -p %CADOMAIN% %%~dp0ca.%ORG%.pfx>%CADOMAIN%\ca.%ORG%.pfx.cmd
goto :EOF

:import_CA
echo %c%%~0%END%

:: https://medium.com/better-programming/trusted-self-signed-certificate-and-local-domains-for-testing-7c6e6e3f9548
:: no friendly name with PEM
REM certutil -f -addstore "Root" %CADOMAIN%\%CADOMAIN%.pem
echo certutil -f -addstore "Root" %CADOMAIN%\ca.%ORG%.crt
certutil -f -addstore "Root" %CADOMAIN%\ca.%ORG%.crt
IF %ERRORLEVEL% NEQ 0 pause

goto :EOF

:create_server_KEY
echo %c%%~0%END%
IF EXIST %CADOMAIN%\star.%CADOMAIN%.key.crt exit /b 0

:: https://adfinis.com/en/blog/openssl-x509-certificates/
openssl genrsa -passout pass:%CAPASS% -out %CADOMAIN%\star.%CADOMAIN%.key.crt
IF %ERRORLEVEL% NEQ 0 pause

:: view it:
echo %b%  openssl rsa -noout -text -in %CADOMAIN%\star.%CADOMAIN%.key.crt %END%

goto :EOF

:create_server_CSR
echo %c%%~0%END%

:: https://adfinis.com/en/blog/openssl-x509-certificates/
openssl req -batch -new -nodes -newkey rsa:4096 -keyout %CADOMAIN%\star.%CADOMAIN%.key.crt -out %CADOMAIN%\star.%CADOMAIN%.csr

:: https://blog.behrang.org/articles/creating-a-ca-with-openssl.html
REM openssl req -new -sha512 -nodes -newkey rsa:4096 -subj "/CN=*.%CADOMAIN%" -key %CADOMAIN%\star.%CADOMAIN%.key.crt -passin pass:%CAPASS% -out %CADOMAIN%\star.%CADOMAIN%.csr
IF %ERRORLEVEL% NEQ 0 pause

:: view it:
echo %b%  openssl req -verify -in %CADOMAIN%\star.%CADOMAIN%.csr -text -noout %END%
REM openssl req -verify -in %CADOMAIN%\star.%CADOMAIN%.csr -text -noout
goto :EOF

:sign_server_CSR
echo %c%%~0%END%

:: https://adfinis.com/en/blog/openssl-x509-certificates/
openssl x509 -req -sha512 -days 3650 -CA %CADOMAIN%\ca.%ORG%.crt -CAkey %CADOMAIN%\ca.%ORG%.key.crt -CAcreateserial -CAserial %CADOMAIN%\star.%CADOMAIN%.srl -extfile openssl.%ORG%.cfg -extensions nq_server -in %CADOMAIN%\star.%CADOMAIN%.csr -out %CADOMAIN%\star.%CADOMAIN%.crt

:: https://blog.behrang.org/articles/creating-a-ca-with-openssl.html
REM -create_serial -rand_serial -md sha512
REM openssl ca -create_serial -updatedb -days 3650 -passin pass:%CAPASS% -extfile openssl.%ORG%.cfg -extensions nq_server -keyfile %CADOMAIN%\ca.%ORG%.key.crt -in %CADOMAIN%\star.%CADOMAIN%.csr -out %CADOMAIN%\star.%CADOMAIN%.crt
IF %ERRORLEVEL% NEQ 0 pause

:: view it:
REM openssl x509 -text -noout -in %CADOMAIN%\star.%CADOMAIN%.crt
goto :EOF

:convert_CRT_PFX
echo %c%%~0%END%

:: https://stackoverflow.com/questions/9971464/how-to-convert-crt-cetificate-file-to-pfx
:: just the CRT: need to install CA separately
openssl pkcs12 -export -name "*.%CADOMAIN%" -inkey %CADOMAIN%\star.%CADOMAIN%.key.crt -passin pass:%CAPASS% -in %CADOMAIN%\star.%CADOMAIN%.crt -passout pass:%PFXPASS% -out %CADOMAIN%\star.%CADOMAIN%.pfx
IF %ERRORLEVEL% NEQ 0 pause
goto :EOF

:convert_CACRT_PFX
echo %c%%~0%END%

:: https://stackoverflow.com/questions/9971464/how-to-convert-crt-cetificate-file-to-pfx
:: CRT + CA: all in one
REM openssl pkcs12 -export -name "*.%CADOMAIN%" -inkey %CADOMAIN%\ca.%ORG%.key.crt -passin pass:%CAPASS% -in %CADOMAIN%\star.%CADOMAIN%.crt -certfile %CADOMAIN%\ca.%ORG%.crt -passout pass:%PFXPASS% -out %CADOMAIN%\%CADOMAIN%.pfx

openssl pkcs12 -export -name "*.%CADOMAIN%" -inkey %CADOMAIN%\star.%CADOMAIN%.key.crt -passin pass:%CAPASS% -in %CADOMAIN%\star.%CADOMAIN%.crt -certfile %CADOMAIN%\ca.%ORG%.crt -passout pass:%PFXPASS% -out %CADOMAIN%\%CADOMAIN%.pfx
IF %ERRORLEVEL% NEQ 0 pause

echo certutil -importPFX -f -p %PFXPASS% %%~dp0%CADOMAIN%.pfx>%CADOMAIN%\%CADOMAIN%.pfx.cmd

goto :EOF

:import_crt_CRT
echo %c%%~0%END%

echo certutil -importPFX -f %CADOMAIN%\star.%CADOMAIN%.pfx
certutil -importPFX -f %CADOMAIN%\star.%CADOMAIN%.pfx
IF %ERRORLEVEL% NEQ 0 pause
goto :EOF

:import_chain_CRT
echo %c%%~0%END%

echo certutil -importPFX -f -p %PFXPASS% %CADOMAIN%\%CADOMAIN%.pfx
certutil -importPFX -f -p %PFXPASS% %CADOMAIN%\%CADOMAIN%.pfx
IF %ERRORLEVEL% NEQ 0 pause
goto :EOF


:set_colors
IF DEFINED END goto :EOF
set END=[0m
set HIGH=[1m
set Underline=[4m
set REVERSE=[7m

set k=[30m
set r=[31m
set g=[32m
set y=[33m
set b=[34m
set m=[35m
set c=[36m
set w=[37m

goto :EOF
:: BUG: some space are needed after :set_colors


:detect_admin_mode [num]
IF DEFINED DEBUG echo DEBUG: %m%%~n0 %~0 %HIGH%%*%END% 1>&2
:: https://stackoverflow.com/questions/1894967/how-to-request-administrator-access-inside-a-batch-file

set req=%1
set bits=32
set bitx=x86
IF DEFINED PROCESSOR_ARCHITEW6432 echo WARNING: running 32bit cmd on 64bit system 1>&2
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
  set arch=-x64
  set bits=64
  set bitx=x64
)
REM %SystemRoot%\system32\whoami /groups | findstr "12288" >NUL && set "ADMIN=0" || set "ADMIN=1"
net session  >NUL 2>&1 && set "ADMIN=0" || set "ADMIN=1"
IF %ADMIN% EQU 0 (
  echo Batch started with %HIGH%%y%ADMIN%END% rights 1>&2
) ELSE (
  echo Batch started with %y%USER%END% rights 1>&2
)

IF DEFINED req (
  IF NOT "%ADMIN%" EQU "%req%" (
    IF "%ADMIN%" GTR "%req%" (
      echo %y%Batch started with USER privileges, when ADMIN was needed.%END% 1>&2
      IF DEFINED AUTOMATED exit
      REM :UACPrompt
      REM net localgroup administrators | findstr "%USERNAME%" >NUL || call :error %~0: User %USERNAME% is NOT localadmin
      gpresult /R | findstr BUILTIN\Administrators >NUL || call :error %~0: User %USERNAME% is NOT localadmin
      echo Set UAC = CreateObject^("Shell.Application"^) >"%TMP%\getadmin.vbs"
      REM :: WARNING: cannot use escaped parameters with this one:
      IF DEFINED params (
      echo UAC.ShellExecute "cmd.exe", "/c %~s0 %params:"=""%", "", "runas", 1 >>"%TMP%\getadmin.vbs"
      ) ELSE echo UAC.ShellExecute "cmd.exe", "/c %~s0", "", "runas", 1 >>"%TMP%\getadmin.vbs"
      CScript //B "%TMP%\getadmin.vbs"
      del /q "%TMP%\getadmin.vbs"
    ) ELSE (
      echo %r%Batch started with ADMIN privileges, when USER was needed. EXIT%END% 1>&2
      IF NOT DEFINED AUTOMATED pause 1>&2
    )
    exit 1
  )
)

set osType=workstation
md %TMP% 2>NUL
%SystemRoot%\System32\wbem\wmic.exe os get Caption /value | findstr Server >%TMP%\wmic.tmp.txt && set "osType=server" || ver >%TMP%\ver.tmp.txt

:: https://www.lifewire.com/windows-version-numbers-2625171
:: Microsoft Windows [Version 10.0.17763.615]
IF "%osType%"=="workstation" (
  findstr /C:"Version 10.0" %TMP%\ver.tmp.txt >NUL && set "WindowsVersion=10"    && exit /b 0
  findstr /C:"Version 6.3"  %TMP%\ver.tmp.txt >NUL && set "WindowsVersion=8.1"   && exit /b 0
  findstr /C:"Version 6.2"  %TMP%\ver.tmp.txt >NUL && set "WindowsVersion=8"     && exit /b 0
  findstr /C:"Version 6.1"  %TMP%\ver.tmp.txt >NUL && set "WindowsVersion=7"     && exit /b 0
  findstr /C:"Version 6.0"  %TMP%\ver.tmp.txt >NUL && set "WindowsVersion=Vista" && exit /b 0
  findstr /C:"Version 5.1"  %TMP%\ver.tmp.txt >NUL && set "WindowsVersion=XP"    && exit /b 0
) ELSE (
  for /f "tokens=4" %%a in (%TMP%\wmic.tmp.txt) do    set "WindowsVersion=%%a"   && exit /b 0
)
goto :EOF

:check_exist_exit
IF DEFINED DEBUG echo DEBUG: %m%%~n0 %~0 %HIGH%%*%END% 1>&2
IF NOT EXIST %1 (
  echo %HIGH%%r% IF EXIST KO%END%: %1 not found... EXIT 1>&2
  pause
  exit 1
)
echo %HIGH%%g% IF EXIST OK%END%: %1 1>&2
goto :EOF

:error "msg"
echo:%r% 1>&2
echo ============================================================== 1>&2
echo %HIGH%%r%  ERROR:%END%%r% %* 1>&2
IF /I [%2]==[powershell] echo %y%Consider install Management Framework at http://aka.ms/wmf5download %r% 1>&2
echo ============================================================== 1>&2
echo:%END% 1>&2
IF NOT DEFINED AUTOMATED pause 1>&2
exit 1
goto :EOF

:end
pause
