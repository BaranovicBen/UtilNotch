---
allowed-tools: Bash
description: Build UtilityNotch and surface only errors — no noise
---

Run the debug build and report the result clearly.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme UtilityNotch -configuration Debug \
  -destination 'platform=macOS' build 2>&1 \
  | grep -E "error:|warning:|BUILD SUCCEEDED|BUILD FAILED" \
  | grep -v "^$"
```

If `BUILD SUCCEEDED`: report success in one line.

If `BUILD FAILED`:
- List each `error:` with file path and line number
- Group errors by file
- For each error, state what it is and the likely fix — do not just echo the compiler message
- Ask if the user wants you to fix them
