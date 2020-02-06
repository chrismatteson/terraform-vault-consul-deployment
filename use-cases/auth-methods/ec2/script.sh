#!/bin/bash

aws iam create-policy --policy-name vault-ec2-auth-validate --policy-document file://policy.json
aws iam create-user --user-name vault-ec2-auth-validate
aws iam attach-user-policy --policy-arn $(aws iam list-policies --query 'Policies[?PolicyName==`vault-ec2-auth-validate`].Arn' --output text) --user-name vault-ec2-auth-validate
aws iam create-access-key --user-name vault-ec2-auth-validate
