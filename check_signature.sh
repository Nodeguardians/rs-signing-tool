#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "${SCRIPT_DIR}/.env"

validator_hex_address=${VALIDATOR_HEX_ADDRESS:-"2C8E45AB480021B3B903B92721D55BA7702A6601"}
slack_webhook="${SLACK_WEBHOOK:-}"
chain_id="${CHAIN_ID:-"pion-1"}"
number_of_blocks_to_check=${NUMBER_OF_BLOCKS_TO_CHECK:-10}
percentage_of_missing_signatures=${PERCENTAGE_OF_MISSING_SIGNATURES:-20}
binary_name=${BINARY_NAME:-"neutrond"}
healthcheck_uuid=${HEALTHCHECK_UUID:-""}


# logging functions
log_generator() {
	local type="$1"; shift
	# accept argument string or stdin
	local text="$*"; if [ "$#" -eq 0 ]; then text="$(cat)"; fi
	local dt; dt="$(date '+%Y-%m-%d %H:%M:%S')"
	printf "[%s] [%s]: %s\n" "$dt" "$type" "$text"
}

log_info() {
	log_generator INFO "$@"
}

#log_warn() {
#	log_generator WARN "$@" >&2
#}

log_error() {
	log_generator ERROR "$@" >&2
}

send_slack_message() {
  script_path="${SCRIPT_DIR}/$(basename "${BASH_SOURCE[0]}")"
  message=":warning: [Neutron / ${chain_id}] Error with the last signed blocks\n\nValidator address \`${validator_hex_address}\` not found.\n\nPlease check the validator ! Script path : \`${script_path}\`"
  curl -s -S -X POST -H 'Content-type: application/json' --data "{\"blocks\": [{\"type\": \"section\",\"text\": {\"type\": \"mrkdwn\",\"text\": \"${message}\"}}]}" "${slack_webhook}"
}

curl -fsS --retry 3 https://hc-ping.com/"${healthcheck_uuid}"/start

current_block_details=$(${binary_name} q block)
current_block_height=$(echo "${current_block_details}" | jq '.block.last_commit.height | tonumber')
log_info "Current block height: ${current_block_height}"

missing_signatures=0
log_info "Checking last ${number_of_blocks_to_check} blocks"

for i in $(seq 0 $((number_of_blocks_to_check - 1))); do
  block_to_check=$((current_block_height - i))
  block_data=$(${binary_name} q block ${block_to_check})
  signature_count=$(echo "${block_data}" | jq ".block.last_commit.signatures[] | select(.validator_address == \"${validator_hex_address}\")" | wc -l)

  if ((signature_count == 0)); then
    missing_signatures=$((missing_signatures + 1))
    log_error "Block ${block_to_check} has no signature from ${validator_hex_address}"
    continue # skip to next block
  fi
  log_info "Block ${block_to_check} has signature from ${validator_hex_address}"
done

if ((missing_signatures > (number_of_blocks_to_check * percentage_of_missing_signatures / 100))); then
  log_info "Sending slack message"
  send_slack_message
fi

log_info "Checking done"
curl -fsS --retry 3 https://hc-ping.com/"${healthcheck_uuid}"/$? -d "Checking ${chain_id} done"
