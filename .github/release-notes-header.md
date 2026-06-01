## Installing on macOS

Tally is **not yet code-signed with an Apple Developer ID**, so macOS Gatekeeper
will refuse to open it on first launch with:

> *"Tally.app" Not Opened — Apple could not verify "Tally.app" is free of malware…*

This dialog only has a **Done** button. On macOS 15.4+ (Sequoia/Tahoe) the old
right-click → Open bypass no longer works either.

### Recommended: clear the quarantine attribute

After dragging `Tally.app` into `/Applications`, run:

```sh
xattr -dr com.apple.quarantine /Applications/Tally.app
```

Then double-click `Tally.app` from `/Applications`. It will open without
warnings on every subsequent launch.

### Alternative: System Settings → Privacy & Security

1. Try to open `Tally.app` once — let macOS show the warning dialog and click **Done**.
2. Open **System Settings → Privacy & Security**.
3. Scroll down to the security messages. You'll see: *"Tally.app" was blocked to protect your Mac.*
4. Click **Open Anyway** next to it.
5. Confirm with **Open** in the follow-up dialog.

---
