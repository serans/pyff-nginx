# PyFF Docker Image and Openshift Configuration

## Overview


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
- 2025-09-22
    - fix wrong path in pipeline
    - paths and pipelines hardcoded into pyffd.sh rather than passed in ENV variables (it was unused anyway)
    - pyffd.sh now runs both pipelines before doing the blue/green switch
    - merge sps and idps jobs into one
- 2025-09-15
    - `static` entities now renamed to `overrides`
    - add green/blue deployment for nginx in `pyffd.sh`
---
