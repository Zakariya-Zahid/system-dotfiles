#!/bin/bash
cpu=$(top -bn2 | grep "Cpu(s)" | tail -n1 | awk '{print int($2+$4)}')
echo " $cpu%"
