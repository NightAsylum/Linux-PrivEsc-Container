#!/bin/sh
{
    echo "===== $(date) ====="
    netstat -tulpn
    echo
} >> /tmp/netlog.log