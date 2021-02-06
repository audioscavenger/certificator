::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: This batch collects all the variables used to setup your DOMAIN certificates ::
::               Simply replace the values where you see fit.                   ::
::                    Some values can also be left blank.                       ::
::                 https://cabforum.org/extended-validation/                    ::
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:: this is your Root CA ORGanisation short name
set ORG_Root=YOURORG
:: this is your Intermediate ORGanisation short name and could be = to %USERDOMAIN%
set ORG_Intermediate=YOURDOMAIN
:: this is your Server short name, used for filenames and could be = to %USERDNSDOMAIN%
set CADOMAIN=INTERNAL.YOURDOMAIN.LOCAL

:: website of the CA emiter:
set authorityInfoAccessOCSP=ocsp.godaddy.com/

:: pkix-cert of the emiter:
set authorityInfoAccessCaIssuers=certificates.godaddy.com/repository/gdig2.crt

:: 3650 = 10 years
set default_days=3650
set default_days_Root=7300
set default_days_Intermediate=3650
set default_days_Subscriber=3650

:: Expert constantly predict the end of 1024bit encryption but, as of 2021 it still has not been breaked; using 2048 your security is improved 2^1024 times
:: From a security perspective, sha512 it would be pretty pointless: In practical terms, SHA-256 is just as secure as SHA-384 or SHA-512. We can't produce collisions in any of them with current or foreseeable technology, so the security you get is identical. 
set default_md=sha256
set default_md_Root=sha512
set default_md_Intermediate=sha256
set default_md_Subscriber=sha256
:: https://sectigo.com/resource-library/rsa-vs-dsa-vs-ecc-encryption
::    RSA     ECC
::    1024    160
::    2048    224
::    3072    256
::    7680    384
::    15360   521
set default_bits=2048
set default_bits_Root=4096
set default_bits_Intermediate=2048
set default_bits_Subscriber=2048
set default_ecc=384
set default_ecc_Root=521
set default_ecc_Intermediate=384
set default_ecc_Subscriber=384

:: Password for Private keys and certificates, can be blank but should be 20 chars really
set PASSWORD_Root=root_key_pass
set PASSWORD_Intermediate=intermediate_key_pass
set PASSWORD_Subscriber=subscriber_key_pass
:: Password for exported PFX files, can be blank or very simple; not sure it's needed
set PASSWORD_PFX=pfx_pass

:: req_distinguished_name section, https://en.wikipedia.org/wiki/Certificate_signing_request
:: Only countryName MUST be 2 chars, the rest can be 64 chars max
set countryName=US
set stateOrProvinceName=Arizona
set localityName=Phoenix
set organizationName=yourCompany Inc.
:: Subject Organization Name Field: subject:organizationName (OID 2.5.4.10 )
set organizationalUnitName=YOURDOMAIN
:: Subject Common Name Field: subject:commonName (OID:  2.5.4.3)
:: Required/Optional:   Deprecated (Discouraged, but not prohibited)
set commonName=yourCompany Inc.
set emailAddress=admin@yourcompany.com
:: optional:
set postalCode=12345
set streetAddress=1234 Main St
:: secondary company name:
set unstructuredName=yourCompany Inc.
:: Subject Business Category Field: subject:businessCategory (OID:  2.5.4.15)
set businessCategory=Private Organization
:: Subject Jurisdiction of Incorporation or Registration Field: jurisdictionCountryName, jurisdictionStateOrProvinceName, jurisdictionLocalityName
set jurisdictionCountryName=US
:: EV certificates: Those 3 required attributes in the DN (businessCategory, serialNumber and jurisdictionCountryName) MUST be present
:: Subject Registration Number Field:   Subject:serialNumber (OID:  2.5.4.5) 
:: For Private Organizations, this field MUST contain the Registration (or similar) Number assigned to the Subject  by  the  Incorporating  or  Registration  Agency  in  its  Jurisdiction  of  Incorporation  or  Registration
:: managing serials from here is painful. Don't do that.
REM set serialNumber=1234567890

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


:: Intermediate policies: OIDs of public policies that apply to your Intermediate CA ---------
:: To respect the CA Browser EV Guidelines, you must be registered in IANA under https://www.alvestrand.no/objectid/1.3.6.1.4.1.html
:: Example: Internet Private: 1.3.6.1.4.1.44947.1.1.1 = OID attached to certificates issued by Let's Encrypt.
:: Example: some are reserved such as 2.16.840.1.101 = gov; 2.16.840.1.113938 = EQUIFAX INC.; etc
:: Object Identifiers (OID) are controlled by IANA and you need to register a Private Enterprise Number (PEN), or OID arc under 1.3.6.1.4.1 namespace.
:: Here is the FREE PEN registration page: http://pen.iana.org/pen/PenApplication.page
:: Your private namespace OID should be present in the Root CA and Intermediate CA

:: 1.Statement Identifier:  1.3.6.1.4.1.311.42.1 = Microsoft; use yours or 1.3.6.1.4.1 for internal domains
:: 2.Certificate Type:      Domain Validation:          2.23.140.1.2.1 = domain-validated https://oidref.com/2.23.140.1.2.1
:: 3.Certificate Type:      Organization Validation:    2.23.140.1.2.2 = subject-identity-validated  https://oidref.com/2.23.140.1.2.2
set policiesOIDsIntermediate=1.3.6.1.4.1, 2.23.140.1.2.1, 2.23.140.1.2.2

:: End points policies: OIDs of public policies that apply to your end point / servr CA -----
:: 1.Statement Identifier:  1.3.6.1.4.1.311.42.1 = Microsoft; use yours or 1.3.6.1.4.1 for internal domains
:: 2.Certificate Type:      Organization Validation:    2.23.140.1.2.2 = subject-identity-validated  https://oidref.com/2.23.140.1.2.2
set policiesOIDsSubscriber=1.3.6.1.4.1, 2.23.140.1.2.2

:: https://stackoverflow.com/questions/51641962/how-do-i-create-my-own-extended-validation-certificate-to-display-a-green-bar/51644728
:: https://www.sysadmins.lv/blog-en/certificate-policies-extension-all-you-should-know-part-1.aspx
:: 3.Practices Statement:   id-qt-cps: OID for CPS qualifier    1.3.6.1.5.5.7.2.1   https://www.alvestrand.no/objectid/1.3.6.1.5.5.7.2.1.html
::    1.3.6.1.5.5.7.2 - id-qt policy qualifier types RFC2459
::    1.3.6.1.5.5.7 - PKIX
::    1.3.6.1.5.5 - Mechanisms
::    1.3.6.1.5 - IANA Security-related objects
::    1.3.6.1 - OID assignments from 1.3.6.1 - Internet
::    1.3.6 - US Department of Defense
::    1.3 - ISO Identified Organization
::    1 - ISO assigned OIDs 
set policyIdentifier=1.3.6.1.5.5.7.2.1
:: CPS Point to the Internet Security Research Group (ISRG) Certification Practice Statementer of the CA emiter
:: that describes the policy under which the certificate in the subject was issued. 
:: examples: http://cps.letsencrypt.org   http://certificates.godaddy.com/repository/
set CPS.1=http://yourcompany.com/cps/

:: User Notice is a small piece of text (RFC recommends to use no more than 200 characters) that describes particular policy.
set explicitText=This certificate protects the private data transmitted throught the local domain YOURDOMAIN, own by yourCompany Inc.
set organization=yourCompany Inc.

:: X509v3 CRL Distribution Points:
:: revocation url: you should serve %ORG_Intermediate%.crl (DER) and %ORG_Intermediate%.crl.crt (PEM) over http at this address:
set crlDistributionPoints.1=http://pki.yourcompany.com/%ORG_Intermediate%.crl

:: //TODO: CT Precertificate SCTs: https://certificate.transparency.dev/howctworks/
:: //TODO: CT Precertificate SCTs: https://letsencrypt.org/2018/04/04/sct-encoding.html
