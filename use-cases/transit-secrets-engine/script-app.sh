#!/bin/bash

cat << 'EOF' > /opt/flask/vaulthook.sh
#!/bin/bash
command=$1
shift 1
text=$@
if [[ "$command" = "encrypt" ]]; then
    VAULT_ADDR="http://localhost:8100" vault write -field ciphertext transit/$command/app-key plaintext=$(base64 <<< "$text")
elif [[ "$command" = "decrypt" ]]; then
    VAULT_ADDR="http://localhost:8100" vault write -field plaintext transit/$command/app-key ciphertext="$text" | base64 -d
else
    echo "unknown command: $command"
fi
EOF
chmod +x /opt/flask/vaulthook.sh
