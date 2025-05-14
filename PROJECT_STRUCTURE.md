# PhotoMigrator Project Structure Issues

## Current Issues

The PhotoMigrator project currently has a problematic structure that is causing build issues:

1. **Duplicate Source Files**: The same Swift files exist in multiple locations:
   - Files in `PhotoMigrator/` directory
   - Duplicate files in `PhotoMigrator/Sources/PhotoMigrator/` directory

2. **Non-Standard Swift Package Structure**: The project doesn't follow standard Swift Package Manager conventions, which expect:
   - Source files in `Sources/<target>/`
   - Test files in `Tests/<target>Tests/`

3. **Build Errors**: When running `swift build`, the compiler finds multiple definitions of the same types, resulting in errors like:
   - `error: multiple producers of module PhotoMigrator with name MediaItem`
   - `error: duplicate target name 'PhotoMigrator'`

## Proposed Fix

We've implemented the following fixes:

1. **Fixed Test Manifest Files**:
   - Updated `XCTestManifests.swift` to include all test classes
   - Ensured `LinuxMain.swift` correctly imports the test modules

2. **Created a Clean Package.swift**:
   - Simplified target configuration
   - Removed path overrides and excluded directories
   - Set up proper resources handling

3. **Project Reorganization Script**:
   - Created `scripts/reorganize_project.sh` to help reorganize the project
   - The script moves source files to the standard Swift Package Manager structure
   - This helps eliminate duplicate sources

## Next Steps

To properly fix the build issues:

1. **Run the Reorganization Script**:
   ```
   ./scripts/reorganize_project.sh
   ```

2. **Update Imports if Needed**:
   - After reorganization, some imports may need to be updated
   - Ensure all files import the correct modules

3. **Remove Duplicate Files**:
   - After confirming the reorganized project builds and works properly, 
     you can remove the duplicate files in the `PhotoMigrator/` directory

4. **Test Suite Completion**:
   - Complete the remaining subtasks for the test suite (Task 13)
   - Implement remaining unit, integration, and UI tests

## Standard Swift Package Structure

For reference, here's the recommended directory structure:

```
PhotoMigrator/
├── Package.swift
├── README.md
├── Sources/
│   └── PhotoMigrator/
│       ├── Models/
│       ├── Services/
│       ├── Utils/
│       ├── Views/
│       └── Resources/
└── Tests/
    └── PhotoMigratorTests/
        ├── ModelsTests/
        ├── ServicesTests/ 
        ├── UtilsTests/
        └── TestData/
```

This structure follows Swift Package Manager conventions and will prevent duplicate file issues. 