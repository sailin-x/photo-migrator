#!/bin/bash

# Script to reorganize the PhotoMigrator project structure to follow Swift Package Manager conventions
# This will help resolve the duplicate source files issues

# Create the proper directory structure if it doesn't exist
mkdir -p Sources/PhotoMigrator
mkdir -p Sources/PhotoMigrator/Models
mkdir -p Sources/PhotoMigrator/Services
mkdir -p Sources/PhotoMigrator/Utils
mkdir -p Sources/PhotoMigrator/Views
mkdir -p Sources/PhotoMigrator/Resources
mkdir -p Tests/PhotoMigratorTests/ServicesTests
mkdir -p Tests/PhotoMigratorTests/UtilsTests
mkdir -p Tests/PhotoMigratorTests/ModelsTests
mkdir -p Tests/PhotoMigratorTests/TestData

# Move model files
echo "Moving model files..."
cp PhotoMigrator/Models/*.swift Sources/PhotoMigrator/Models/

# Move service files
echo "Moving service files..."
cp PhotoMigrator/Services/*.swift Sources/PhotoMigrator/Services/

# Move utility files
echo "Moving utility files..."
cp PhotoMigrator/Utils/*.swift Sources/PhotoMigrator/Utils/

# Move view files
echo "Moving view files..."
cp PhotoMigrator/Views/*.swift Sources/PhotoMigrator/Views/

# Move app files
echo "Moving app files..."
cp PhotoMigrator/PhotoMigratorApp.swift Sources/PhotoMigrator/
cp PhotoMigrator/ContentView.swift Sources/PhotoMigrator/

# Move resource files (if any)
echo "Moving resource files..."
if [ -d "PhotoMigrator/Resources" ]; then
    cp -R PhotoMigrator/Resources/* Sources/PhotoMigrator/Resources/
fi

# Ensure test files are in the right place
echo "Organizing test files..."
cp Tests/PhotoMigratorTests/ServicesTests/*.swift Tests/PhotoMigratorTests/ServicesTests/
cp Tests/PhotoMigratorTests/UtilsTests/*.swift Tests/PhotoMigratorTests/UtilsTests/
cp Tests/PhotoMigratorTests/*.swift Tests/PhotoMigratorTests/

echo "Project structure reorganization complete!"
echo "You can now build the project with 'swift build'"
echo "Note: You may need to update imports in some files." 