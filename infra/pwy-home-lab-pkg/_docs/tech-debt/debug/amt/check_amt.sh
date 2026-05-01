#!/bin/bash

# Define the array properly
AMT_IPS=(10.0.11.10 10.0.11.11 10.0.11.12)

# Set the OpenSSL config path
export OPENSSL_CONF="$HOME/openssl.conf"

# Generate the config file
cat <<EOF > "$OPENSSL_CONF"
openssl_conf = openssl_init

[openssl_init]
ssl_conf = ssl_sect

[ssl_sect]
system_default = system_default_sect

[system_default_sect]
Options = UnsafeLegacyRenegotiation
EOF

# Correct way to iterate over a Bash array
for ip in "${AMT_IPS[@]}"; do
    URL="https://$ip:16993"

    # -q: quiet mode (cleans up the RESP variable)
    # --timeout: prevents the script from hanging on a dead IP
    RESP=$(wget -qO - --no-check-certificate --timeout=5 "$URL" 2>&1 | grep 'title')
    echo "RESPONSE FROM $URL: [$RESP]"
done
