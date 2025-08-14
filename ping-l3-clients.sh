#!/usr/bin/env bash

# Colors
GREEN="\e[32m"
RED="\e[31m"
NC="\e[0m"  # No Color

test_ping() {
    local src="$1"
    local dst="$2"
    local ip="$3"

    echo "Pinging from $src to $dst..."
    if docker exec "$src" ping -c 4 -W 2 "$ip"; then
        echo -e "${GREEN}$src to $dst: successful${NC}"
    else
        echo -e "${RED}$src to $dst: failed${NC}"
    fi
    echo
}

test_ping client1 client2 10.2.2.20
test_ping client2 client3 10.3.3.30
test_ping client3 client1 10.1.1.10

