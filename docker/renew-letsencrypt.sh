#!/usr/bin/env bash

# Stop if a command fails or an unset variable is used.
set -euo pipefail

# Set this to the certificate name shown by: sudo certbot certificates
CERT_NAME="easternbeach.duckdns.org"
PFX_DIRECTORY="/media/remote/EMBY_ext4/config"
PFX_FILENAME="emby-cert-duck.pfx"
PFX_OWNER="remote:remote"

# Set the PFX password here so automated runs do not need user input.
PFX_PASSWORD='YourStrongPassword'

# Certbot and its deploy hook need access to the certificate's private key.
if [[ "$EUID" -ne 0 ]]; then
    echo "Run this script as root." >&2
    exit 1
fi

# Check dependencies before attempting renewal.
command -v certbot >/dev/null
command -v openssl >/dev/null
id "${PFX_OWNER%%:*}" >/dev/null
getent group "${PFX_OWNER#*:}" >/dev/null

# Pass export settings to the deploy hook without putting the password in arguments.
export PFX_DIRECTORY PFX_FILENAME PFX_OWNER PFX_PASSWORD
mkdir -p -- "$PFX_DIRECTORY"

# Certbot renews only this certificate when it is due for renewal.
# The deploy hook runs only after an actual, successful renewal.
# Test renewal and export the current valid certificate with:
# sudo bash renew-letsencrypt.sh --dry-run --run-deploy-hooks
# Extra arguments are passed to Certbot; no arguments means normal renewal.
certbot renew --cert-name "$CERT_NAME" "$@" --deploy-hook '
    set -eu
    umask 077

    # Build the PFX beside its destination so replacement is atomic.
    # Keep the existing PFX if export or ownership changes fail.
    temporary_pfx=$(mktemp "$PFX_DIRECTORY/.renew-letsencrypt.XXXXXX")
    trap '\''rm -f -- "$temporary_pfx"'\'' EXIT

    # Include the private key, certificate, and intermediate certificate chain.
    openssl pkcs12 -export \
        -inkey "$RENEWED_LINEAGE/privkey.pem" \
        -in "$RENEWED_LINEAGE/cert.pem" \
        -certfile "$RENEWED_LINEAGE/chain.pem" \
        -out "$temporary_pfx" \
        -passout env:PFX_PASSWORD

    # Only the owner can read the password-protected PFX.
    chmod 600 "$temporary_pfx"
    chown "$PFX_OWNER" "$temporary_pfx"
    mv -f -- "$temporary_pfx" "$PFX_DIRECTORY/$PFX_FILENAME"
'
