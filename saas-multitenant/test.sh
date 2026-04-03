export USER_POOL_ID="ap-southeast-1_QYlgvDGpb"
export CLIENT_ID="7n90fqlqafclrr01sq4ltns7qk"
export API_URL="https://j8v5p58kxd.execute-api.ap-southeast-1.amazonaws.com/dev"
export REGION="ap-southeast-1"

export TENANT_ID="tenant-acme"
export USERNAME="alice@acme.com"

export TEMP_PASSWORD="Nadeeth@1982"
export FINAL_PASSWORD="Nadeeth@1984"


# aws cognito-idp admin-create-user \
#   --user-pool-id $USER_POOL_ID \
#   --username $USERNAME \
#   --temporary-password $TEMP_PASSWORD \
#   --user-attributes \
#     Name=email,Value=$USERNAME \
#     Name=email_verified,Value=true \
#     Name=custom:tenantId,Value=$TENANT_ID \
#   --region $REGION

# Step 3a — initiate auth to get the challenge
# SESSION=$(aws cognito-idp initiate-auth \
#   --auth-flow USER_PASSWORD_AUTH \
#   --client-id $CLIENT_ID \
#   --auth-parameters USERNAME=$USERNAME,PASSWORD=$TEMP_PASSWORD \
#   --region $REGION \
#   --query 'Session' --output text)

# # Step 3b — respond to NEW_PASSWORD_REQUIRED challenge
# aws cognito-idp respond-to-auth-challenge \
#   --client-id $CLIENT_ID \
#   --challenge-name NEW_PASSWORD_REQUIRED \
#   --session $SESSION \
#   --challenge-responses USERNAME=$USERNAME,NEW_PASSWORD=$FINAL_PASSWORD \
#   --region $REGION

ID_TOKEN=$(aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id $CLIENT_ID \
  --auth-parameters USERNAME=$USERNAME,PASSWORD=$FINAL_PASSWORD \
  --region $REGION \
  --query 'AuthenticationResult.IdToken' --output text)

echo $ID_TOKEN

curl -s -X GET "$API_URL/data" \
  -H "Authorization: $ID_TOKEN" \
  | jq .