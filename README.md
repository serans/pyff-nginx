# PyFF Docker Image and Openshift Configuration

## Overview

- Home cooked pyff docker image published in Gitlab registry, runs in 2 modes; filter or server
- Main container runs pyff as a server (pyff.deploy.yaml)
- 2 additional cron jobs fetch eduGAIN metadata, process it and publish it to a shared volume
- All need write access to /var/run, so added as an emptyDir volume

## Update PyFF version

- Update version in Dockerfile.in
- Update docker tag in gitlab-ci to reflect it
- Update version used in overlay Kustomization file

## Deploy to Openshift

- Ensure that you have OC tools and Kustomize installed
- Log in to https://paas.cern.ch/topology/ns/pyff-dev?view=list
- Copy log in command to the command line and run
- Switch to the target project e.g. `oc project pyff-dev`
- Run `kubectl apply -k .` from inside whichever Overlay folder you wish to deply

## Run a cron job on demand

```
kubectl create job --from cj/pyff-dev-idps-importer idps
kubectl create job --from cj/pyff-dev-sps-importer sps
```

---
Changelog:
- 2025-09-15
    - `static` entities now renamed to `overrides`
    - `pyffd.sh` 
---