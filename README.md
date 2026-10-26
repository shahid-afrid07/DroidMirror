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
