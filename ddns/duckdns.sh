#!/bin/bash
# Your comma-separated domains list

source $HOME/scripts/ddns/duckdns.env # at this point, this file only has domain names for various hosts.
curl -k -o ./duck.log "https://www.duckdns.org/update?domains=${DOMAINS}&token=${DUCKDNS_TOKEN}&ip="