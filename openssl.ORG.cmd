::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: This batch collects all the variables used to setup your DOMAIN certificates ::
::               Simply replace the values where you see fit.                   ::
::                    Some values can also be left blank.                       ::
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:: this is your FQDN domain and should be = to %USERDNSDOMAIN%
set CADOMAIN=INTERNAL.DOMAIN.LOCAL

:: this is your ORGanisation short name and could be = to %USERDOMAIN%
set ORG=DOMAIN

:: 3650 = 10 years
set default_days=3650

:: Expert constantly predict the end of 1024bit encryption but, as of 2021 it still has not been breaked
:: I guarantee you to be safe for the next 10 years when using 4096
set default_bits = 4096

:: Password for Private keys and certificates, can be blank but should be 20 chars really
set CAPASS=INTERNAL.DOMAIN.LOCAL

:: Password for exported PFX files, can be blank or very simple
set PFXPASS=INTERNAL.DOMAIN.LOCAL

:: req_distinguished_name section, https://en.wikipedia.org/wiki/Certificate_signing_request
:: Only countryName MUST be 2 chars, the rest can be 64 chars max
set countryName=US
set stateOrProvinceName=Arizona
set localityName=Tempe
set organizationName=Company Inc.
set organizationalUnitName=DOMAIN
set commonName=Company Inc.
set emailAddress=admin@company.com
:: optional:
set postalCode=85284
set streetAddress=7890 S Hardy Drive
:: secondary company name:
set unstructuredName=Company Inc.

:: [alt_names] section, enter a list of domains to cover; there is no limit
:: You can add short machine names, IP addresses, and wildcard domains
:: Simply increment the DNS.{num} of the variable to add more domains
:: Delete the lines you do not need starting from the bottom
set DNS.1=*.INTERNAL.DOMAIN.LOCAL
set DNS.2=server-cc
set DNS.3=10.1.13.12
set DNS.4=server-ep-2
set DNS.5=10.1.13.121
set DNS.6=server-ir5
set DNS.7=10.1.13.95
set DNS.8=server-pa
set DNS.9=10.1.13.97

:: CPS Pointer is an URL to a Certificate Practice Statement document 
:: that describes the policy under which the certificate in the subject was issued.
set CPS.1=https://www.company.com/
set CPS.2=https://www.company.com/policy

:: User Notice is a small piece of text (RFC recommends to use no more than 200 characters) that describes particular policy.
set explicitText=Explicit Policy Text Here
