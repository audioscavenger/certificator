@echo OFF
pushd %~dp0

:: //TODO: separate CSR from KEY

:: TOTEST:  3-step complete CA + inter + *.domain + client https://blog.behrang.org/articles/creating-a-ca-with-openssl.html
:: CURRENT: 2-step Ca + *.domain https://adfinis.com/en/blog/openssl-x509-certificates/

::  1.1.0   separated server csr from key; can regenerate csr
::  1.1.1   renamed root folder to just ORG
::  1.1.2   using RSA keysize from cfg only
::  1.2.0   added CRL list generation

:init
set version=1.2.0
set author=lderewonko

call :detect_admin_mode
call :set_colors

set ORG=%USERDOMAIN%
set PAUSE=echo:
set RESET=n
set FORCE_CA=n
set FORCE_CRT=y
set DEMO=YOURDOMAIN


:prechecks
for %%x in (powershell.exe) do (set "powershell=%%~$PATH:x")
IF NOT DEFINED powershell call :error %~0: powershell NOT FOUND

call :check_exist_exit openssl.ORG.cfg
call :check_exist_exit openssl.ORG.cmd



:defaults
IF DEFINED DEMO (
  set ORG=%DEMO%
) ELSE (
  set /P ORG=Organisation? [%ORG%] 
)
IF /I "%ORG%"=="ORG" call :error Using ORG as Organisation name is forbidden.

set /P  FORCE_CA=Regenerate CA cert?     [%FORCE_CA%] 
set /P FORCE_CRT=Regenerate Server cert? [%FORCE_CRT%] 

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
call :create_CRL

call :convert_chain_PFX
call :import_chain_CRT

call :revoke_CRT

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
IF /I "%RESET%"=="y" (
  del /f /q %ORG%\*.crt 2>NUL
  del /f /q %ORG%\*.csr 2>NUL
)
goto :EOF


:create_folders
echo %c%%~0%END%

md %ORG%\ 2>NUL
REM md %ORG%\certs 2>NUL
REM md %ORG%\crl 2>NUL
REM md %ORG%\newcerts 2>NUL
REM md %ORG%\private 2>NUL
REM md %ORG%\req 2>NUL

:: https://serverfault.com/questions/857131/odd-error-while-using-openssl
:: https://www.linuxquestions.org/questions/linux-security-4/why-can%27t-i-generate-a-new-certificate-with-openssl-312716/
echo|set /p=>%ORG%\index.txt
echo|set /p="unique_subject = no">%ORG%\index.txt.attr

:: https://serverfault.com/questions/823679/openssl-error-while-loading-crlnumber
echo|set /p="1000">%ORG%\crlnumber

goto :EOF

:create_cfg in out
echo %c%%~0%END%

call openssl.%ORG%.cmd

:: too slow:
copy /y %1 %2
REM for /f "eol=: tokens=1,2 delims==" %%V in (openssl.ORG.cmd) DO (
  REM powershell -executionPolicy bypass -Command "(Get-Content -Path '%~2') -replace '{%%V}', '%%W' | Set-Content -Path '%~2'"
REM )

powershell -executionPolicy bypass -Command ^(Get-Content %1^) ^| Foreach-Object { ^
    $_ -replace '{CADOMAIN}', '%CADOMAIN%' `^
       -replace '{ORG}', '%ORG%' `^
       -replace '{default_days}', '%default_days%' `^
       -replace '{default_md}', '%default_md%' `^
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
       -replace '{explicitText}', '%explicitText%' `^
       -replace '{organization}', '%organization%' `^
       -replace '{crlDistributionPoints}', '%crlDistributionPoints%'^
    } ^| Set-Content %2

:: special case for altnames:
for /f "tokens=1,2 delims==" %%V in ('set DNS.') DO echo %%V=%%W>>%2
for /f "tokens=1,2 delims==" %%V in ('set IP.') DO echo %%V=%%W>>%2

:: OPENSSL_CONF must have full path, and extension cfg on Windows. don't ask me why.
REM set OPENSSL_CONF=%~dp0openssl.github.cfg
REM set OPENSSL_CONF=%~dp0openssl.cfg
REM set OPENSSL_CONF=%~dp0openssl.MIT.cfg
REM set OPENSSL_CONF=%~dp0openssl.pki-tutorial.cfg
set OPENSSL_CONF=%~dp0openssl.%ORG%.cfg
REM set OPENSSL_CONF=%~dp0openssl.%ORG%.cfg

goto :EOF

:create_KEY
echo %c%%~0%END%
IF EXIST %ORG%\ca.%ORG%.key.crt exit /b 0

REM openssl genrsa -aes256 -passout pass:%CAPASS% -out %ORG%\ca.%ORG%.key.crt
REM openssl req -new -newkey rsa -keyout %ORG%\ca.%ORG%.key.crt -out %ORG%\ca.%ORG%.csr -passout pass:%CAPASS%

REM openssl req -new -nodes -newkey rsa -keyout %ORG%\ca.%ORG%.key.crt -out %ORG%\ca.%ORG%.csr
openssl req -batch -new -nodes -keyout %ORG%\ca.%ORG%.key.crt -out %ORG%\ca.%ORG%.csr

:: view csr:
echo %b%  openssl req -noout -text -in %ORG%\ca.%ORG%.csr %END%
REM openssl req -noout -text -in %ORG%\ca.%ORG%.csr

:: view key:
echo %b%  openssl rsa -noout -text -in %ORG%\ca.%ORG%.key.crt -passin pass:%CAPASS% %END%
REM openssl rsa -noout -text -in %ORG%\ca.%ORG%.key.crt -passin pass:%CAPASS%

goto :EOF


::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: -extensions val     CERT extension section (override value in config file)
:: -reqexts val        REQ  extension section (override value in config file)
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::


:create_CA
echo %c%%~0%END%
IF EXIST %ORG%\ca.%ORG%.crt IF /I NOT "%FORCE_CA%"=="y" exit /b 0

:: https://www.phildev.net/ssl/creating_ca.html
REM openssl ca -batch -create_serial -days 3650 -out %ORG%\ca.%ORG%.crt -keyfile %ORG%\ca.%ORG%.key.crt -passin pass:%CAPASS% -selfsign -extensions v3_ca -infiles %ORG%\ca.%ORG%.csr
REM openssl ca -batch -create_serial -rand_serial -subj "/CN=%ORG% CA/OU=OPS/O=%ORG%" -out %ORG%\ca.%ORG%.crt -passin pass:%CAPASS% -keyfile %ORG%\ca.%ORG%.key.crt -selfsign -extensions v3_ca -infiles %ORG%\ca.%ORG%.csr

:: https://adfinis.com/en/blog/openssl-x509-certificates/
openssl x509 -req -sha512 -days 3650 -extfile openssl.%ORG%.cfg -extensions nq_ca -in %ORG%\ca.%ORG%.csr -signkey %ORG%\ca.%ORG%.key.crt -out %ORG%\ca.%ORG%.crt
REM openssl x509 -req -sha512 -days 3650 -extensions nq_ca -in %ORG%\ca.%ORG%.csr -signkey %ORG%\ca.%ORG%.key.crt -out %ORG%\ca.%ORG%.crt
IF %ERRORLEVEL% NEQ 0 pause

:: verify it:
echo %b%  openssl x509 -text -noout -in %ORG%\ca.%ORG%.crt %END%
REM openssl x509 -text -noout -in %ORG%\ca.%ORG%.crt
goto :EOF

:convert_CA_PFX
echo %c%%~0%END%

REM openssl pkcs12 -export -name "%ORG% CA" -inkey %ORG%\ca.%ORG%.key.crt -passin pass:%CAPASS% -in %ORG%\%CADOMAIN%.pem -out %ORG%\ca.%ORG%.pfx -passout pass:%PFXPASS%
REM openssl pkcs12 -export -name "%ORG% CA" -inkey %ORG%\ca.%ORG%.key.crt -passin pass:%CAPASS% -in %ORG%\ca.%ORG%.crt -out %ORG%\ca.%ORG%.pfx -passout pass:%PFXPASS%

:: https://www.phildev.net/ssl/creating_ca.html
openssl pkcs12 -export -name "%ORG% CA" -inkey %ORG%\ca.%ORG%.key.crt -passin pass:%CAPASS% -in %ORG%\ca.%ORG%.crt -passout pass:%PFXPASS% -out %ORG%\ca.%ORG%.pfx
IF %ERRORLEVEL% NEQ 0 pause

echo certutil -f -p %CADOMAIN% %%~dp0ca.%ORG%.pfx>%ORG%\ca.%ORG%.pfx.cmd
goto :EOF

:import_CA
echo %c%%~0%END%

:: https://medium.com/better-programming/trusted-self-signed-certificate-and-local-domains-for-testing-7c6e6e3f9548
:: no friendly name with PEM
echo certutil -f -addstore "Root" %ORG%\ca.%ORG%.crt
certutil -f -addstore "Root" %ORG%\ca.%ORG%.crt
IF %ERRORLEVEL% NEQ 0 pause

goto :EOF

:create_server_KEY
echo %c%%~0%END%
IF EXIST %ORG%\star.%CADOMAIN%.key.crt exit /b 0

:: https://adfinis.com/en/blog/openssl-x509-certificates/
openssl genrsa -passout pass:%CAPASS% -out %ORG%\star.%CADOMAIN%.key.crt
IF %ERRORLEVEL% NEQ 0 pause

:: view it:
echo %b%  openssl rsa -noout -text -in %ORG%\star.%CADOMAIN%.key.crt %END%

goto :EOF

:create_server_CSR
echo %c%%~0%END%
IF EXIST %ORG%\star.%CADOMAIN%.crt IF /I NOT "%FORCE_CRT%"=="y" exit /b 0

:: https://adfinis.com/en/blog/openssl-x509-certificates/
:: you don't have to specify rsa keysize here, it's in the cfg already
echo openssl req -batch -new -nodes -newkey rsa -subj "/CN=*.%CADOMAIN%" -keyout %ORG%\star.%CADOMAIN%.key.crt -out %ORG%\star.%CADOMAIN%.csr
openssl req -batch -new -nodes -newkey rsa -subj "/CN=*.%CADOMAIN%" -keyout %ORG%\star.%CADOMAIN%.key.crt -out %ORG%\star.%CADOMAIN%.csr

:: https://blog.behrang.org/articles/creating-a-ca-with-openssl.html
REM openssl req -new -sha512 -nodes -newkey rsa -subj "/CN=*.%CADOMAIN%" -key %ORG%\star.%CADOMAIN%.key.crt -passin pass:%CAPASS% -out %ORG%\star.%CADOMAIN%.csr
IF %ERRORLEVEL% NEQ 0 pause

:: view it:
echo %b%  openssl req -verify -in %ORG%\star.%CADOMAIN%.csr -text -noout %END%
REM openssl req -verify -in %ORG%\star.%CADOMAIN%.csr -text -noout
goto :EOF

:sign_server_CSR
echo %c%%~0%END%
IF EXIST %ORG%\star.%CADOMAIN%.crt IF /I NOT "%FORCE_CRT%"=="y" exit /b 0

:: https://adfinis.com/en/blog/openssl-x509-certificates/
openssl x509 -req -sha512 -days 3650 -CA %ORG%\ca.%ORG%.crt -CAkey %ORG%\ca.%ORG%.key.crt -CAcreateserial -CAserial %ORG%\star.%CADOMAIN%.srl -extfile openssl.%ORG%.cfg -extensions nq_server -in %ORG%\star.%CADOMAIN%.csr -out %ORG%\star.%CADOMAIN%.crt

:: https://blog.behrang.org/articles/creating-a-ca-with-openssl.html
REM -create_serial -rand_serial -md sha512
REM openssl ca -create_serial -updatedb -days 3650 -passin pass:%CAPASS% -extfile openssl.%ORG%.cfg -extensions nq_server -keyfile %ORG%\ca.%ORG%.key.crt -in %ORG%\star.%CADOMAIN%.csr -out %ORG%\star.%CADOMAIN%.crt
IF %ERRORLEVEL% NEQ 0 pause

certutil %ORG%\star.%CADOMAIN%.crt | findstr /c:"Cert Hash(sha1)" | for /f "tokens=3" %%t in ('more') do echo %c%THUMBPRINT =%END% %%t

:: view it:
REM openssl x509 -text -noout -in %ORG%\star.%CADOMAIN%.crt

:: verify it:
REM certutil -verify -urlfetch %ORG%\star.%CADOMAIN%.crt

goto :EOF


:revoke_CRT
echo %c%%~0%END%

:: https://blog.didierstevens.com/2013/05/08/howto-make-your-own-cert-and-revocation-list-with-openssl/
echo:
echo %c% openssl ca -revoke %ORG%\star.%CADOMAIN%.crt -keyfile %ORG%\ca.%ORG%.key.crt -cert %ORG%\ca.%ORG%.crt %END%
REM openssl ca -revoke %ORG%\star.%CADOMAIN%.crt -keyfile %ORG%\ca.%ORG%.key.crt -cert %ORG%\ca.%ORG%.crt

exit /b 0
call :create_CRL

goto :EOF


:create_CRL
echo %c%%~0%END%

:: https://blog.didierstevens.com/2013/05/08/howto-make-your-own-cert-and-revocation-list-with-openssl/
openssl ca -gencrl -keyfile %ORG%\ca.%ORG%.key.crt -cert %ORG%\ca.%ORG%.crt -out %ORG%\root.crl.pem

openssl crl -inform PEM -in %ORG%\root.crl.pem -outform DER -out %ORG%\root.crl
REM del /f /q %ORG%\root.crl.pem

:: verify it:
REM certutil -verify -urlfetch %ORG%\star.%CADOMAIN%.crt

:: a Windows Server 2003 CA will always check revocation on all certificates in the PKI hierarchy (except the root CA certificate) before issuing an end-entity certificate. However in this situation, a valid Certificate Revocation List (CRL) for one or more of the intermediate certification authority (CA) certificates was not be found since the root CA was offline. This issue may occur if the CRL is not available to the certificate server, or if the CRL has expired.

:: You may disabled the feature that checks revocation on all certificates in the PKI hierarchy with the following command on the CA:

REM certutil –setreg ca\CRLFlags +CRLF_REVCHECK_IGNORE_OFFLINE
goto :EOF


:convert_chain_PFX
echo %c%%~0%END%

:: https://stackoverflow.com/questions/9971464/how-to-convert-crt-cetificate-file-to-pfx
:: CRT + CA: all in one
REM openssl pkcs12 -export -name "*.%CADOMAIN%" -inkey %ORG%\ca.%ORG%.key.crt -passin pass:%CAPASS% -in %ORG%\star.%CADOMAIN%.crt -certfile %ORG%\ca.%ORG%.crt -passout pass:%PFXPASS% -out %ORG%\%CADOMAIN%.pfx

:: certfile and CAfile seem identical
openssl pkcs12 -export -name "*.%CADOMAIN%" -inkey %ORG%\star.%CADOMAIN%.key.crt -passin pass:%CAPASS% -in %ORG%\star.%CADOMAIN%.crt -chain -CAfile %ORG%\ca.%ORG%.crt -passout pass:%PFXPASS% -out %ORG%\%CADOMAIN%.pfx
IF %ERRORLEVEL% NEQ 0 pause

echo certutil -importPFX -f -p "%PFXPASS%" %%~dp0\%CADOMAIN%.pfx>%ORG%\%CADOMAIN%.pfx.cmd
echo certutil -verify -urlfetch %%~dp0\star.%CADOMAIN%.crt>>%ORG%\%CADOMAIN%.pfx.cmd
echo:>>%ORG%\%CADOMAIN%.pfx.cmd
echo revoque IR5 certificates:>>%ORG%\%CADOMAIN%.pfx.cmd
echo netsh http delete sslcert ipport=0.0.0.0:8085>>%ORG%\%CADOMAIN%.pfx.cmd
echo netsh http delete sslcert ipport=0.0.0.0:8086>>%ORG%\%CADOMAIN%.pfx.cmd
echo timeout /t 5>>%ORG%\%CADOMAIN%.pfx.cmd

goto :EOF


:import_chain_CRT
echo %c%%~0%END%

echo certutil -importPFX -f -p "%PFXPASS%" %ORG%\%CADOMAIN%.pfx
certutil -importPFX -f -p "%PFXPASS%" %ORG%\%CADOMAIN%.pfx
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
