# Release screenshot checklist

The screensaver captures in this directory are real 1920×1080 captures from
the running GTK/OpenGL renderer and contain no user data.

The normal desktop and terminal, T-virus diagnostic, Red Queen, and wallpaper
gallery are already represented by real captures or original project artwork.

Before the next public release, capture these two additional views manually:

1. **Launcher/menu:** open the Apps menu with `Super + Alt + Space` over a
   clean Hive desktop. Keep the themed bar and enough wallpaper visible to
   show context. Capture the full screen and save the reviewed 16:9 image as
   `docs/screenshots/launcher-menu.png`.
2. **Lock screen:** capture the real Hive lock screen showing its normal clock,
   identity-verification field, borders, and background, but no failed-login
   text or typed password. Because secure lock surfaces may block normal
   screenshot tools, use a clean test account/session or an external camera if
   necessary. Crop and perspective-correct the result to 16:9, then save it as
   `docs/screenshots/lock-screen.png`.

Once each file exists and has been inspected at full resolution, add it under
`Desktop screenshots` in the root `README.md`. Do not add placeholders or
mock-ups while the real captures are unavailable.

Privacy checklist:

- close browsers, chat clients, password managers, and notification history;
- hide personal tray plugins and account avatars;
- use a generic prompt such as `operator@workstation`;
- remove Wi-Fi SSIDs, Bluetooth device names, weather location, IP addresses,
  filesystem paths, repository names, and notification content;
- inspect every capture at full resolution before publication;
- keep raw captures outside the repository.

Use a 16:9 PNG at least 1000 pixels wide for `preview.png`. The preview should
be a real desktop capture rather than a wallpaper-only image.
