# Release screenshot checklist

The screensaver captures in this directory are real 1920×1080 captures from
the running GTK/OpenGL renderer and contain no user data.

Before the first public release, capture these additional views manually on a
clean workspace:

- desktop with Waybar and a non-minimal Hive wallpaper;
- terminal using the Hive palette and a sanitized prompt;
- Omarchy launcher/menu;
- lock screen;
- optional facility schematic/security-terminal screensaver.

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
