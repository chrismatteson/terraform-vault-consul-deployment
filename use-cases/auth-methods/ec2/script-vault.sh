#!/bin/bash

vault auth enable aws
vault write auth/aws/config/client secret_key=$AWS_ACCESS_KEY_ID  access_key=$AWS_SECRET_ACCESS_KEY
vault write auth/aws/role/app-role auth_type=ec2 bound_ec2_instance_id=$APP_INSTANCE_ID policies=getmysqlcreds
