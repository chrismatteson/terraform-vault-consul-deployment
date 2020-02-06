#!/bin/bash

cat << EOF > /tmp/vault-ec2-auth-validate-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "iam:GetInstanceProfile",
        "iam:GetUser",
        "iam:GetRole"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["sts:AssumeRole"],
      "Resource": ["arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/vault-ec2-auth-validate"]
    }
  ]
}
EOF

aws iam create-policy --policy-name vault-ec2-auth-validate --policy-document file:///tmp/vault-ec2-auth-validate-policy.json
aws iam create-user --user-name vault-ec2-auth-validate
aws iam attach-user-policy --policy-arn $(aws iam list-policies --query 'Policies[?PolicyName==`vault-ec2-auth-validate`].Arn' --output text) --user-name vault-ec2-auth-validate
aws iam create-access-key --user-name vault-ec2-auth-validate
