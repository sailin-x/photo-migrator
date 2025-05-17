#!/bin/bash

echo "Running standalone test for SecureTempFileManager..."
cd "$(dirname "$0")"
swift SecureTempFileManagerTest.swift 