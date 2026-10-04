#!/bin/bash

city="Lahore"

weather=$(curl -s "https://wttr.in/$city?format=1")

echo "$weather"
