#!/bin/bash

if [ -f ".env" ]; then
    export $(grep -v '^#' .env | grep -v '^$' | xargs)
    echo "Environment variables loaded from .env file"
else
    echo "Error: .env file not found"
    exit 1
fi
