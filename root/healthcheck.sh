#!/bin/bash

# check to see if AMBEd is listening on port 10100
lsof -i udp:10100
