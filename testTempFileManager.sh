#!/bin/bash

echo "Building PhotoMigrator module..."
swift build -v

echo "Testing SecureTempFileManager..."
swift run -v PhotoMigrator 