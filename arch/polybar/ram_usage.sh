#!/bin/bash
# Show RAM used / total in human-readable format
read used total <<< $(free -h | awk '/^Mem:/ {print $3, $2}')
echo "mem: $used/$total"
