# BeamMP
A Lua mod bringing online multiplayer to [BeamNG.drive](https://beamng.com)!

# Important Links

- [Documentation](https://beammp.github.io/BeamMP/)
- [Discord](https://discord.gg/BeamMP)
- [Website](https://beammp.com)
- [Docs](https://docs.beammp.com)
- [Forum](https://forum.beammp.com)
- `#beammp` on `irc.libera.chat` ([webchat link](https://web.libera.chat/#beammp))

# Contents
- [BeamMP](#beammp)
- [Important Links](#important-links)
- [Contents](#contents)
- [Installation](#installation)
- [Servers](#servers)
- [How does it work?](#how-does-it-work)
- [Roadmap](#roadmap)
- [Troubleshooting](#troubleshooting)
- [Support](#support)
- [Translations](#translations)


# Installation

**[Click here for a step-by-step guide](https://docs.beammp.com/game/getting-started/) on how to install the mod on Windows.**

The BeamMP mod has been made as simple as it gets. Just head over to [our website (BeamMP.com)](https://beammp.com) and click download. This will download a zip file which contains the installer exe. Just run that exe and follow the instructions. Once this completes all you need to do is double click the shortcut on your desktop. 

Now you can play by clicking "Play" and then "Multiplayer", logging in with either a guest account or a [BeamMP Forum](https://forum.beammp.com) account.
Then just select a server to play on! That's it! :)

If you need help at any point, see the [troubleshooting](#troubleshooting) section. There are instructions there on how to get support from our dedicated support team.

# Servers

[Click here for a step-by-step guide](https://docs.beammp.com/server/create-a-server/) on how to set up and run a server for you & your friends.

The server is usable free of charge for non-commercial use, and the source code is available on [GitHub](https://github.com/BeamMP/BeamMP-Server).

Please check out [docs.beammp.com](https://docs.beammp.com) for a guide on how to setup your own server. If you run into issues, join the official [Discord](https://discord.gg/BeamMP) or join us via IRC in `#beammp` on `irc.libera.chat` ([webchat link](https://web.libera.chat/#beammp)).

# How does it work?
*This section is a technical explanation of the inner workings of the project and is not relevant for most players.*

The Launcher is a separate program which starts the game and connects to the Lua mod right away. The launcher then connects to a remote server of your choice, and these two communicate. The launcher then forwards some packets to the game, like car positions, rotations, chat messages, etc.

For more information on how the launcher and server operate, you can read the source code (C++) in their respective repositories: 
- [Launcher](https://github.com/BeamMP/BeamMP-Launcher)
- [Server](https://github.com/BeamMP/BeamMP-Server)

# Roadmap
You can see and keep track of development, planned features, etc. [Here](https://github.com/orgs/BeamMP/projects/4) or on the GitHub Issues section of each repository.

Additionally, you can join the [Discord](https://discord.gg/BeamMP), where regular updates are posted!
Also there is our community [Forum](https://forum.beammp.com/), where we post additional details.

# Troubleshooting

- [Frequently Asked Questions/Common Issues](https://forum.beammp.com/c/faq/35)
- [Error Codes](https://docs.beammp.com/server/error-codes/)
- [Server Auth Key](https://www.beammp.com/keymaster)

If none of these fix your issue, we have a dedicated support team on our [Discord](https://discord.gg/BeamMP), and our [Forum](https://forum.beammp.com/c/support/33)

# Support
The BeamMP project is supported by community donations via our [Patreon](https://www.patreon.com/BeamMP) This brings perks such as Patreon-only channels on our Discord, Early access to new updates, and more server keys. 

# Translations
BeamMP makes an effort to be maintained for multiple languages. 
The current progress of this sits at: 
[![gitlocalized ](https://gitlocalize.com/repo/9181/whole_project/badge.svg)](https://gitlocalize.com/repo/9181?utm_source=badge) 
We use [GitLocalize](https://gitlocalize.com/) for managing this. You can contribute if you wish here: https://gitlocalize.com/repo/9181.

The individual language progress is as follows:

| Language              | Badge                                                                                                                           |
|-----------------------|---------------------------------------------------------------------------------------------------------------------------------|
| Catalan               | [![gitlocalized ](https://gitlocalize.com/repo/9181/ca/badge.svg)](https://gitlocalize.com/repo/9181/ca?utm_source=badge)       |
| Chinese               | [![gitlocalized ](https://gitlocalize.com/repo/9181/zh/badge.svg)](https://gitlocalize.com/repo/9181/zh?utm_source=badge)       |
| Czech                 | [![gitlocalized ](https://gitlocalize.com/repo/9181/cs/badge.svg)](https://gitlocalize.com/repo/9181/cs?utm_source=badge)       |
| French                | [![gitlocalized ](https://gitlocalize.com/repo/9181/fr-FR/badge.svg)](https://gitlocalize.com/repo/9181/fr-FR?utm_source=badge) |
| German                | [![gitlocalized ](https://gitlocalize.com/repo/9181/de-DE/badge.svg)](https://gitlocalize.com/repo/9181/de-DE?utm_source=badge) |
| Japanese              | [![gitlocalized ](https://gitlocalize.com/repo/9181/ja-JP/badge.svg)](https://gitlocalize.com/repo/9181/ja-JP?utm_source=badge) |
| Korean (South Korea)  | [![gitlocalized ](https://gitlocalize.com/repo/9181/ko-KR/badge.svg)](https://gitlocalize.com/repo/9181/ko-KR?utm_source=badge) |
| Polish                | [![gitlocalized ](https://gitlocalize.com/repo/9181/pl/badge.svg)](https://gitlocalize.com/repo/9181/pl?utm_source=badge)       |
| Portuguese (Brazil)   | [![gitlocalized ](https://gitlocalize.com/repo/9181/pt_BR/badge.svg)](https://gitlocalize.com/repo/9181/pt_BR?utm_source=badge) |
| Portuguese (Portugal) | [![gitlocalized ](https://gitlocalize.com/repo/9181/pt-PT/badge.svg)](https://gitlocalize.com/repo/9181/pt-PT?utm_source=badge) |
| Russian               | [![gitlocalized ](https://gitlocalize.com/repo/9181/ru/badge.svg)](https://gitlocalize.com/repo/9181/ru?utm_source=badge)       |
| Slovak                | [![gitlocalized ](https://gitlocalize.com/repo/9181/sk/badge.svg)](https://gitlocalize.com/repo/9181/sk?utm_source=badge)       |
| Spanish               | [![gitlocalized ](https://gitlocalize.com/repo/9181/es-ES/badge.svg)](https://gitlocalize.com/repo/9181/es-ES?utm_source=badge) |
| Turkish               | [![gitlocalized ](https://gitlocalize.com/repo/9181/tr/badge.svg)](https://gitlocalize.com/repo/9181/tr?utm_source=badge)       |
