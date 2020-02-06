#!/bin/bash
VAULT_ADDR="http://localhost:8200" vault operator init -recovery-shares=1 -recovery-threshold=1
