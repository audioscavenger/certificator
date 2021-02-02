::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: This batch collects all the variables used to setup your DOMAIN certificates ::
::               Simply replace the values where you see fit.                   ::
::                    Some values can also be left blank.                       ::
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:: this is your FQDN domain and should be = to %USERDNSDOMAIN%
set CADOMAIN=INTERNAL.YOURDOMAIN.LOCAL

:: this is your ORGanisation short name and could be = to %USERDOMAIN%
set ORG=YOURDOMAIN

:: 3650 = 10 years
set default_days=3650

:: Expert constantly predict the end of 1024bit encryption but, as of 2021 it still has not been breaked
:: It's a guarantee you will be safe for the next 30 years when using 4096
:: also sha512 is available
set default_md=sha512
set default_bits=4096

:: Password for Private keys and certificates, can be blank but should be 20 chars really
set CAPASS=private_key_pass

:: Password for exported PFX files, can be blank or very simple
set PFXPASS=

:: req_distinguished_name section, https://en.wikipedia.org/wiki/Certificate_signing_request
:: Only countryName MUST be 2 chars, the rest can be 64 chars max
set countryName=US
set stateOrProvinceName=Arizona
set localityName=Phoenix
set organizationName=yourCompany Inc.
set organizationalUnitName=YOURDOMAIN
set commonName=yourCompany Inc.
set emailAddress=admin@yourcompany.com
:: optional:
set postalCode=12345
set streetAddress=1234 Main St
:: secondary company name:
set unstructuredName=yourCompany Inc.

:: [alt_names] section, enter a list of domains to cover; there is no limit
:: You can add short machine names, IP addresses, and wildcard domains
:: Simply increment the DNS.{num} of the variable to add more domains
:: Delete the lines you do not need starting from the bottom
set DNS.1=*.INTERNAL.YOURDOMAIN.LOCAL
set DNS.2=server-cc
set DNS.3=server-ep-2
set DNS.4=server-ir5
set DNS.5=server-pa
set IP.1=10.1.13.12
set IP.2=10.1.13.121
set IP.3=10.1.13.95
set IP.4=10.1.13.97

:: CPS Pointer is an URL to a Certificate Practice Statement document 
:: that describes the policy under which the certificate in the subject was issued.
set CPS.1=https://www.yourcompany.com/
set CPS.2=https://www.yourcompany.com/policy

:: User Notice is a small piece of text (RFC recommends to use no more than 200 characters) that describes particular policy.
set explicitText=Explicit Policy Text Here for what this server certificate covers
set organization=yourCompany Inc.

:: revocation url
set crlDistributionPoints=http://yourcompany.com/root.crl
