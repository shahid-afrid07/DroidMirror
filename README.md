<p align="center">
  <img width="180" alt="1f409505b2977372e6ab2df6ae71737c9afb31f7c60a629c172f941bcf27da55 (2)" src="https://github.com/user-attachments/assets/918578ba-af21-4561-a408-fad3545173ea" />
</p>

<h1 align="center">DroidMirror</h1>

<p align="center"><strong>Mirror your Android with Mac and Windows.</strong><br>
Wireless Android screen mirroring and control, powered by scrcpy.</p>

DroidMirror is a desktop companion for discovering Android phones on your Wi-Fi or phone hotspot, pairing through Android 
Wireless debugging, and opening a low-latency mirror with [scrcpy](https://github.com/Genymobile/scrcpy).

## Platforms

| Platform | App | Status |
| --- | --- | --- |
| macOS 14+ | Native AppKit application | Available |
| Windows 10/11 x64 | Windows Forms application | Preview |

The Windows target is new and needs its first Windows CI build before it can be called stable. Both apps need Android Platform Tools (`adb`) and scrcpy installed on the computer.

## Quick start

1. Connect your Mac or PC and Android phone to the same Wi-Fi, or connect the computer to the phone's hotspot.
2. Turn on **Developer options → Wireless debugging** on Android.
3. Open DroidMirror. Nearby phones advertising ADB Wireless debugging appear under **Devices** when the network allows mDNS.
4. For first-time pairing, open **Pair device with pairing code** on Android. Select the phone, enter the pairing code in DroidMirror, and choose **Start Mirroring**.
5. On later sessions, select the phone and choose **Start Mirroring**. scrcpy opens its own window for video and controls.

ADB pairing is required once for each phone and computer. Keep Wireless debugging enabled for automatic reconnection. Android and ADB use separate ports for pairing and connection; DroidMirror discovers the normal connection port automatically when mDNS is available. If a network blocks mDNS, use the manual **Device IP:port** shown on Android's main Wireless debugging screen.

## Install prerequisites
📱 DroidMirror v1.0

DroidMirror lets you mirror your Android phone to your Mac or Windows laptop using wireless debugging.

💻 1. Install DroidMirror

🍎 macOS

1. Download the DroidMirror ZIP file.
2. Unzip the downloaded file.
3. Drag and drop the application into your Applications folder.
4. Open DroidMirror.

🪟 Windows

1. Download the DroidMirror ZIP file.
2. Extract the ZIP file.
3. Open the extracted folder.
4. Double-click the application icon to launch DroidMirror.

🛠️ 2. Install Required Packages

Before connecting your phone, install the required packages for your operating system.

🍎 macOS

Open Terminal and run:

brew install scrcpy
brew install --cask android-platform-tools

🪟 Windows

Open PowerShell or Windows Terminal and run:

winget install --exact Genymobile.scrcpy
winget install Google.PlatformTools

Wait for the installations to finish before continuing.

📲 3. Enable Wireless Debugging on Android

1. Open Settings on your Android phone.
2. Go to About phone.
3. Tap Build number seven times to enable Developer options. You may need to enter your phone's PIN.
4. Return to Settings and open Developer options.
5. Enable Wireless debugging and allow the permission if prompted.
6. Make sure your phone and laptop are connected to the same Wi-Fi network.

Note: The exact menu names may vary depending on your Android device.

🔗 4. Pair Your Phone with DroidMirror

1. Open Developer options → Wireless debugging on your phone.
2. Tap Pair device with pairing code.
3. Your phone will display an IP address, a pairing port, and a pairing code.
4. In DroidMirror, enter the IP address in the IP Address field.
5. Enter the pairing port in the Port field, if the app asks for the pairing port.
6. Enter the pairing code if DroidMirror provides a field for it.
7. Follow the app's on-screen instructions to complete pairing.

Important: Android displays a separate pairing port and connection port. Use the pairing port for pairing. If DroidMirror has a separate connection step, use the connection port displayed on the main Wireless debugging screen.

▶️ 5. Start Mirroring

After pairing is complete:

1. Follow the connection instructions displayed by DroidMirror.
2. Allow any debugging authorization prompt that appears on your phone.
3. Start the mirroring session.
4. Your Android screen should appear on your laptop.

❓ Troubleshooting

- Phone not connecting? Ensure both devices are on the same Wi-Fi network.
- Pairing failed? Check that you entered the correct IP address and pairing port.
- Connection stopped? Check that Wireless debugging is still enabled. Android may change the ports or IP address.
- Command not found? Confirm that Homebrew (macOS) or WinGet (Windows) is available and that the required packages installed successfully.
- Still having problems? Restart DroidMirror and try pairing again.

🔒 Security Note

Wireless debugging allows authorized debugging connections to your phone. Only pair with trusted devices, and disable Wireless debugging when you no longer need it.

---

DroidMirror v1.0
Mirror your Android phone on your laptop.
### macOS

Install [Android Platform Tools](https://developer.android.com/tools/releases/platform-tools) and [scrcpy](https://github.com/Genymobile/scrcpy). With Homebrew:

```sh
brew install android-platform-tools scrcpy
```

### Windows

Install Android Platform Tools and scrcpy using their official downloads. Add the folders containing `adb.exe` and `scrcpy.exe` to `PATH`, then restart DroidMirror.

## Build from source

### macOS app

The native macOS app builds with the macOS Command Line Tools. Xcode is not required.

```sh
./build-mac-app.sh
```

### Windows app

Use Windows 10/11 and the .NET 8 SDK:

```powershell
dotnet run --project windows/DroidMirror.Windows.csproj
```

The Windows project publishes a self-contained x64 app through the GitHub Actions workflow. `adb.exe` and `scrcpy.exe` remain external prerequisites.

## Troubleshooting

- **Phone does not appear:** confirm both devices are on the same local network and Wireless debugging is on. Guest networks and some phone hotspots block mDNS; use manual connection.
- **Pairing does not finish:** open Android's pairing-code screen and use the current code. Pairing requires its own IP:port.
- **No mirror window:** select a connected phone, allow the debugging prompt on Android, and try **Start Mirroring** again.
- **Choppy video or audio:** move closer to the Wi-Fi access point and reduce other network traffic. DroidMirror uses a 1600-pixel video limit, 30 fps, 4 Mbps bitrate, and a 100 ms audio buffer by default.

## License

DroidMirror source is MIT licensed. scrcpy is a separate project under Apache-2.0; it is not bundled in this repository.
