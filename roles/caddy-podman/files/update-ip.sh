#!/usr/bin/env bash

# Update IPv4 addresses for all domains within a Cloudflare zone to the current
# host's IP address using the Cloudflare API.
#
# Useful for when assigning a static IP to your host is not possible.
#
# Expects a .env file in the same directory as this file. This file should have
# these variables:
# - CLOUDFLARE_ZONE_ID: The zone ID for the DNS records you want to keep updated
# - CLOUDFLARE_API_TOKEN: Your Cloudflare API token, for authentication purposes
#
# Requires these tools:
# - curl
# - jq


SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
LOG_FILE="${SCRIPT_DIR}/ip-change.log"
ENV_FILE="${SCRIPT_DIR}/.env"

TIMEFORMAT=%R

log_info() {
    msg="$1"
    printf "[$(date +"%Y-%m-%d %H:%M:%S")] INFO: $msg\n" | tee -a "$LOG_FILE"
}

log_error() {
    msg="$1"
    printf "[$(date +"%Y-%m-%d %H:%M:%S")] ERROR: $msg\n" | tee -a "$LOG_FILE"
}

source "$ENV_FILE"

if [[ -z "$CLOUDFLARE_ZONE_ID" ]]; then
    log_error "CLOUDFLARE_ZONE_ID is not set in ${ENV_FILE}!"
    exit 1
fi

if [[ -z "$CLOUDFLARE_API_TOKEN" ]]; then
    log_error "CLOUDFLARE_API_TOKEN is not set in ${ENV_FILE}!"
    exit 1
fi

current_ipv4=$(curl --silent ifconfig.me)

if [[ $? -ne 0 ]]; then
    log_error "Could not get current IP address! Aborting."
    exit 1
fi

log_info "Current IP address is $current_ipv4"

num_updated=0
num_errors=0

# Read all DNS records in this zone
curl --silent \
     --request GET \
     --url https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records \
     --header 'Content-Type: application/json' \
     --header "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | \
jq -r '.result.[] | .id + "," + .name + "," + .type + "," + .content' | \
while IFS="," read -r dns_record_id dns_record_name dns_record_type dns_record_content; do
    # Skip non-A records
    if [[ "$dns_record_type" != "A" ]]; then
        continue
    fi

    if [[ "$dns_record_content" = "$current_ipv4" ]]; then
        log_info "IP address has not changed for $dns_record_name."
        continue
    fi

    # Update A record if IP does not match the current IP address
    log_info "IP address changed for ${dns_record_name}. Updating via Cloudflare API"

    output=$(
        curl --silent \
             --request PUT \
             --url "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records/$dns_record_id" \
             --header 'Content-Type: application/json' \
             --header "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | \
             --data \
        "{
            \"name\": \"$dns_record_name\",
            \"proxied\": true,
            \"settings\": {},
            \"tags\": [],
            \"content\": \"$current_ipv4\",
            \"type\": \"A\"
        }"
    )

    if [[ $(jq .success <<< "$output") != true ]]; then
        log_error "Could not update DNS record! success=false in Cloudflare response. See:"
        log_error "$output"
        ((num_errors++))
    else
        log_info "IP address updated from $dns_record_content -> $current_ipv4"
        ((num_updated++))
    fi
done

if (( num_errors != 0 )); then
    log_error "Encountered ${num_errors} error(s) (see output above)"
fi

if (( num_updated != 0 )); then
    log_info "Updated ${num_updated} DNS records"
fi

if (( num_errors == 0 && num_updated == 0 ));
    log_info "Nothing to do!"
fi
