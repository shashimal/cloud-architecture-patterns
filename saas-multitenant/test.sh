#!/usr/bin/env bash
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
USER_POOL_ID="ap-southeast-1_Z9v4ozsja"
CLIENT_ID="737olj3h785moljbm0t7in5je1"
API_URL="https://hm8jgpqzq9.execute-api.ap-southeast-1.amazonaws.com/dev"
REGION="ap-southeast-1"
TABLE_NAME="tanant-data"

# ─── Tenant / User definitions ───────────────────────────────────────────────
# Format: "tenantId|username|password"
USERS=(
  "tenant-acme|alice@acme.com|Nadeeth@1982"
  "tenant-globex|bob@globex.com|Nadeeth@1982"
  "tenant-initech|carol@initech.com|Nadeeth@1982"
)

# ─── Helpers ─────────────────────────────────────────────────────────────────
log()  { echo -e "\n\033[1;34m[INFO]\033[0m  $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m    $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
fail() { echo -e "\033[1;31m[FAIL]\033[0m  $*" >&2; }

separator() { echo -e "\n\033[1;37m$(printf '─%.0s' {1..60})\033[0m"; }

# ─── Step 1: Create Cognito Users ────────────────────────────────────────────
separator
log "STEP 1 — Creating Cognito users"

for entry in "${USERS[@]}"; do
  IFS='|' read -r TENANT_ID USERNAME PASSWORD <<< "$entry"

  log "Creating user: $USERNAME (tenant: $TENANT_ID)"

  if aws cognito-idp admin-get-user \
      --user-pool-id "$USER_POOL_ID" \
      --username "$USERNAME" \
      --region "$REGION" &>/dev/null; then
    warn "User $USERNAME already exists — skipping creation"
  else
    aws cognito-idp admin-create-user \
      --user-pool-id "$USER_POOL_ID" \
      --username "$USERNAME" \
      --temporary-password "TempPass@123456!" \
      --user-attributes \
        Name=email,Value="$USERNAME" \
        Name=email_verified,Value=true \
        Name="custom:tenantId",Value="$TENANT_ID" \
      --message-action SUPPRESS \
      --region "$REGION" > /dev/null
    ok "Created $USERNAME"
  fi
done

# ─── Step 2: Set permanent passwords (skips NEW_PASSWORD_REQUIRED) ───────────
separator
log "STEP 2 — Setting permanent passwords"

for entry in "${USERS[@]}"; do
  IFS='|' read -r TENANT_ID USERNAME PASSWORD <<< "$entry"

  log "Setting permanent password for: $USERNAME"
  aws cognito-idp admin-set-user-password \
    --user-pool-id "$USER_POOL_ID" \
    --username "$USERNAME" \
    --password "$PASSWORD" \
    --permanent \
    --region "$REGION"
  ok "Password set for $USERNAME"
done

# ─── Step 3: Confirm users are CONFIRMED ─────────────────────────────────────
separator
log "STEP 3 — Verifying user status"

for entry in "${USERS[@]}"; do
  IFS='|' read -r TENANT_ID USERNAME PASSWORD <<< "$entry"

  STATUS=$(aws cognito-idp admin-get-user \
    --user-pool-id "$USER_POOL_ID" \
    --username "$USERNAME" \
    --region "$REGION" \
    --query 'UserStatus' --output text)

  if [[ "$STATUS" == "CONFIRMED" ]]; then
    ok "$USERNAME → status: $STATUS"
  else
    fail "$USERNAME → unexpected status: $STATUS"
  fi
done

# ─── Step 4: Seed DynamoDB records ───────────────────────────────────────────
separator
log "STEP 4 — Seeding DynamoDB table: $TABLE_NAME"

tenant_extra() {
  case "$1" in
    tenant-acme)    echo '"name":{"S":"Acme Corp"},"plan":{"S":"enterprise"},"region":{"S":"us-east-1"}' ;;
    tenant-globex)  echo '"name":{"S":"Globex Inc"},"plan":{"S":"standard"},"region":{"S":"eu-west-1"}' ;;
    tenant-initech) echo '"name":{"S":"Initech Ltd"},"plan":{"S":"starter"},"region":{"S":"ap-southeast-1"}' ;;
  esac
}

for entry in "${USERS[@]}"; do
  IFS='|' read -r TENANT_ID USERNAME PASSWORD <<< "$entry"
  EXTRA=$(tenant_extra "$TENANT_ID")

  log "Writing DynamoDB record for tenant: $TENANT_ID"
  aws dynamodb put-item \
    --table-name "$TABLE_NAME" \
    --item "{\"tenantId\":{\"S\":\"$TENANT_ID\"},$EXTRA}" \
    --region "$REGION"
  ok "Record written for $TENANT_ID"
done

# ─── Step 5: Authenticate and run API tests ───────────────────────────────────
separator
log "STEP 5 — Running API tests"

PASS=0
FAIL=0

for entry in "${USERS[@]}"; do
  IFS='|' read -r TENANT_ID USERNAME PASSWORD <<< "$entry"
  separator
  log "Testing tenant: $TENANT_ID  |  user: $USERNAME"

  # Authenticate — get ID token
  ID_TOKEN=$(aws cognito-idp initiate-auth \
    --auth-flow USER_PASSWORD_AUTH \
    --client-id "$CLIENT_ID" \
    --auth-parameters USERNAME="$USERNAME",PASSWORD="$PASSWORD" \
    --region "$REGION" \
    --query 'AuthenticationResult.IdToken' --output text)

  if [[ -z "$ID_TOKEN" || "$ID_TOKEN" == "None" ]]; then
    fail "Could not obtain ID token for $USERNAME"
    (( FAIL++ )) || true
    continue
  fi
  ok "Authenticated — token obtained"

  # Test 1: GET /data — own tenant data (expect 200)
  log "  [GET /data] Fetching own tenant data..."
  HTTP_STATUS=$(curl -s -o /tmp/api_response.json -w "%{http_code}" -X GET "$API_URL/data" \
    -H "Authorization: $ID_TOKEN")
  BODY=$(cat /tmp/api_response.json)

  if [[ "$HTTP_STATUS" == "200" ]]; then
    ok "  GET /data → $HTTP_STATUS"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
    (( PASS++ )) || true
  else
    fail "  GET /data → $HTTP_STATUS (expected 200)"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
    (( FAIL++ )) || true
  fi
done

# ─── Summary ─────────────────────────────────────────────────────────────────
separator
echo ""
echo -e "  \033[1;32mPASSED: $PASS\033[0m   \033[1;31mFAILED: $FAIL\033[0m"
echo ""
if [[ $FAIL -eq 0 ]]; then
  ok "All tests passed!"
else
  fail "$FAIL test(s) failed."
  exit 1
fi
