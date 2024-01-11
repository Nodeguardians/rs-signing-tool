#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "${SCRIPT_DIR}/.env"

validator_hex_address="2C8E45AB480021B3B903B92721D55BA7702A6601"
chain_id="pion-1"
first_block_to_check=8325000
last_block_to_check=8370000
WINDOW_SIZE=36000
missed_signatures=0
checked_blocks=0
missed_blocks_window=()

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
#       log_generator WARN "$@" >&2
#}

log_error() {
        log_generator ERROR "$@" >&2
}

missing_signatures=0
log_info "Checking blocks from height ${first_block_to_check} to height ${last_block_to_check}"

calculate_missed_in_window() {
    echo "${missed_blocks_window[@]}" | tr -d ' ' | fold -w1 | grep -c "1"
}

for i in $(seq 0 $((last_block_to_check - first_block_to_check))); do
  block_to_check=$((first_block_to_check + i))
  block_data=$(/home/neutron/go/bin/neutrond q block ${block_to_check})
#  echo "${block_data}"
  signature_count=$(echo "${block_data}" | jq ".block.last_commit.signatures[] | select(.validator_address == \"${validator_hex_address}\")" | wc -l)
  empty_validator_count=$(echo "${block_data}" | jq '.block.last_commit.signatures[] | select(.signature == null) | length' | wc -l)
  
  if ((signature_count == 0)); then
    missed_signatures=$((missed_signatures + 1))
    missed_blocks_window+=1
  else 
    missed_blocks_window+=0
  fi

  missed_in_window=$(calculate_missed_in_window)

  if ((signature_count == 0)); then
    log_error "Block ${block_to_check} Not signed by ${validator_hex_address}. Missed in window: ${missed_in_window}. Global missed: ${empty_validator_count}"
  else 
    log_info "Block ${block_to_check} Signed by ${validator_hex_address}. Missed in window: ${missed_in_window}. Global missed: ${empty_validator_count}"
  fi

  ((checked_blocks++))

  # Maintain a sliding window of the last WINDOW_SIZE blocks
  if [ ${#missed_blocks_window[@]} -gt $WINDOW_SIZE ]; then
    missed_blocks_window=("${missed_blocks_window[@]:1}")
  fi

  # Check if more than 95% of the last WINDOW_SIZE blocks are missed
  if [ $checked_blocks -ge $WINDOW_SIZE ]; then
    missed_percentage=$((missed_in_window * 100 / WINDOW_SIZE))
    if [ $missed_percentage -gt 95 ]; then
      window_start=$((block_to_check - WINDOW_SIZE + 1))
      log_error "More than 95% blocks missed from block ${window_start} to ${block_to_check}. Stopping analysis."
      break
    fi
  fi
done

