# Flet macOS Notarization Script

A comprehensive bash script to automate the macOS notarization process for Flet applications, handling code signing, virtual environment cleaning, DMG creation, and Apple notarization submission.

## What It Does

This script streamlines the entire macOS app notarization workflow:

1. **Configuration Management** - Creates and manages a config file for your credentials
2. **Virtual Environment Handling** - Extracts, signs, and repackages any bundled Python virtual environments
3. **Code Cleaning** - Removes CocoaPods metadata that can cause notarization issues
4. **Code Signing** - Signs all binaries, libraries, and frameworks with your Developer ID certificate
5. **Signature Verification** - Validates proper code signing before submission
6. **DMG Creation** - Builds a professional disk image with an Applications folder symlink
7. **Notarization** - Submits the app to Apple's notarization service and waits for approval
8. **Stapling** - Attaches the notarization ticket to the DMG

## Prerequisites

### Required Software
* **macOS** (notarization only works on macOS)
* **Xcode Command Line Tools** - Install with:
  ```bash
  xcode-select --install

### Apple Developer Requirements
- Active Apple Developer Account (paid membership)
- Developer ID Certificate – Generate from Apple Developer Portal
  - Used for code signing
  - Must be imported in Keychain
- App-Specific Password – Create at appleid.apple.com
  - This is NOT your regular Apple ID password
  - Format: ⁠`xxxx-xxxx-xxxx-xxxx`
 
### Configuration
Before running, you'll need:
- Team ID - Found in Apple Developer Portal
- Certificate Name - Exactly as it appears in Keychain (e.g., "Developer ID Application: Your Name (XXXXX)")
- App Path - Full path to your `.app` bundle

### Usage
1. Make the script executable:
```
 chmod +x flet_notarize_template.sh
```
2. Run the script:
```
 ./flet_notarize_template.sh
```
3. On first run, the script creates a ⁠flet_notarize.config file and opens your default editor
4. Fill in all required fields in the config file and save
5. The script will proceed with notarization and show you status updates

### OutPut
The script creates:
- DMG file - Your notarized application disk image (ready for distribution)
- Notarization ticket - Stapled to the DMG
- Temporary files - Stored in ⁠`/tmp/notarize_work` (automatically cleaned up)

### Notes
- The script will prompt for confirmation before proceeding with notarization
- Notarization typically takes 5-15 minutes
- The ⁠`flet_notarize.config` file is created locally — do not commit it to version control (add to ⁠`.gitignore`)
- Apple notarization requires active internet connection

### Troubleshooting
If notarization fails:
1. Check that your certificate is installed in Keychain
2. Verify your app-specific password is correct
3. Ensure your Team ID matches your certificate
4. Review Apple's notarization documentation for specific error codes
 
## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
