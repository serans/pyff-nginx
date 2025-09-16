#!/bin/bash

# Mandatory env variables
# ----------------------- 

# FILTER_PIPELINE: the filter pipeline to run. Mandatory!
if [ -z "${FILTER_PIPELINE}" ]; then
  echo "Error: FILTER_PIPELINE environment variable must be set"
  exit 1
fi

# Default env variables
# ---------------------

[ -z "${DATADIR}" ] && DATADIR="/tmp/pyff"
[ -z "${LOGLEVEL}" ] && LOGLEVEL="INFO"

# Nginx related variables
# -----------------------

# UPDATE_NGINX_DATA: (optional) if "TRUE" the script will make the entities available to nginx

# Directory with entities to override downloaded ones
[ -z "${ENTITIES_OVERRIDE}" ] && ENTITIES_OVERRIDE="/tmp/overrides"

# Directory where pyff pipeline is configured to download entities
[ -z "${DOWNLOADED_ENTITIES}" ] && DOWNLOADED_ENTITIES="${DATADIR}/downloads"

# Nginx root link. Note that it should be a soft link to a directory
# and it should not point directly to the DOWNLOADED_ENTITIES directory
[ -z "${NGINX_ROOT_LINK}" ] && NGINX_ROOT_LINK="${DATADIR}/nginx-root"

# Blue-green deployment directories
[ -z "${DEPLOY_BLUE}" ] && DEPLOY_BLUE="${DATADIR}/deploy/blue"
[ -z "${DEPLOY_GREEN}" ] && DEPLOY_GREEN="${DATADIR}/deploy/green"

if [ "$UPDATE_NGINX_DATA" = "TRUE" ] && [ "$(realpath "${NGINX_ROOT_LINK}")" = "$(realpath "${DOWNLOADED_ENTITIES}")" ]; then
   echo "ERROR: downloading entities directly in the nginx root link is not supported" >&2
   exit 1
fi

# Signature generation
# --------------------
. ${VENV}/bin/activate
mkdir -p ${DATADIR} && cd ${DATADIR}
mkdir -p /var/run
openssl genrsa 4096 > default.key
openssl req -x509 -sha1 -new -subj "/CN=Default Metadata Signer" -key default.key -out default.crt

# Run the filter pipeline standalone
# ----------------------------------
${VENV}/bin/pyff --loglevel=${LOGLEVEL} ${FILTER_PIPELINE}

# Nginx data update
# Data is updated in an atomic way using a blue-green deployment strategy
# -----------------
if [ "${UPDATE_NGINX_DATA}" = "TRUE" ]; then

   # Override downloaded entities with the ones provided in ENTITIES_OVERRIDE
   for f in "${ENTITIES_OVERRIDE}"/*.xml; do
      cp -f "$f" "$DOWNLOADED_ENTITIES/"

      # Create a sha1 version of the file name
      if entity_id=$(xmlstarlet sel -t -v "//@entityID" "$f"); then
         entity_sha1=$(echo -n "$entity_id" | sha1sum | awk '{print $1}')
         cp -f "$f" "$DOWNLOADED_ENTITIES/\{sha1\}$entity_sha1.xml"
      else
         echo "Error: failed to generate sha1 link for entity $f" >&2
      fi
   done

   # Create deployment dirs if they don't exist already
   [ -d "$DEPLOY_BLUE" ] || mkdir -p "$DEPLOY_BLUE"
   [ -d "$DEPLOY_GREEN" ] || mkdir -p "$DEPLOY_GREEN"

   # Make sure nginx root exists and is a soft link
   if ! [ -L "$NGINX_ROOT_LINK" ]; then
      if [ -d "$NGINX_ROOT_LINK" ]; then
         rm -rf "$NGINX_ROOT_LINK"
      fi
      ln -sfn "$DEPLOY_BLUE" "$NGINX_ROOT_LINK"
   fi

   # Check out if we should use green or blue dir
   CURRENT_COLOR=$(realpath "$NGINX_ROOT_LINK")
   if [ "$CURRENT_COLOR" = "$(realpath "$DEPLOY_BLUE")" ]; then
      NEW_COLOR="$DEPLOY_GREEN"
   elif [ "$CURRENT_COLOR" = "$(realpath "$DEPLOY_GREEN")" ]; then
      NEW_COLOR="$DEPLOY_BLUE"
   else
      echo "ERROR: the current production directory '${NGINX_ROOT_LINK}'" >&2
      echo "       is pointing to an unknown location '${NEW_COLOR}'" >&2
      exit 2
   fi

   # make sure the new directory is empty, this is safe since we have
   # already made sure that NGINX is currently using the other one
   rm -rf "$NEW_COLOR"
   mv "$DOWNLOADED_ENTITIES" "$NEW_COLOR"

   # update nginx root link
   ln -sfn "$NEW_COLOR" "$NGINX_ROOT_LINK"
fi