# certificator

- generate CA + Intermediate + wildcard DNSDOMAIN for servers
- produces server PFX and clients PFX
- generates unattended import PFX batches for server and client

## How To
1. duplicate/rename YOURORG folder. YOURORG is the Root CA name
2. rename and edit all 3 batches within YOURORG folder
3. run CAgenerator.cmd (Optional: run as admin to be able to import the generated PFX)
4. optional: import the generated PFX by runing the generated batches *.chain.pfx.cmd

- ca.DOMAIN.chain.pfx.cmd = Root+Intermediate to deploy on every desktop
- DNSDOMAIN.chain.pfx.cmd = server+Root+Intermediate to deploy on servers ONLY

## Requisites
- powershell
- openssl 1.1.1r (provided in \bin)
