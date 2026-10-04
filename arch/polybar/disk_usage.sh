#!/bin/bash
# Show available disk space for /
avail=$(df -h / | awk 'NR==2 {print $4}')   # $4 = available
echo " $avail"
