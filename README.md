# BeamMP
<!-- ALL-CONTRIBUTORS-BADGE:START - Do not remove or modify this section -->
[![All Contributors](https://img.shields.io/badge/all_contributors-1-orange.svg?style=flat-square)](#contributors-)
<!-- ALL-CONTRIBUTORS-BADGE:END -->
A Lua mod bringing online multiplayer to [BeamNG.drive](https://beamng.com)!

# Important Links

- [Discord](https://discord.gg/BeamMP)
- [Website](https://beammp.com)
- [Wiki](https://wiki.beammp.com)
- [Forum](https://forum.beammp.com)

# Contents
 - [Installation](#installation)
 - [Servers](#servers)
 - [How does it work?](#how-does-it-work)
 - [Roadmap](#roadmap)
 - [Troubleshooting](#troubleshooting)


# Installation

[Click here for a step-by-step guide](https://wiki.beammp.com/en/home/installation-guide) on how to install the mod on Windows.

The BeamMP mod has been made as simple as it gets. Just head over to [our website (BeamMP.com)](https://beammp.com) and click download. This will download a zip file which contains the installer exe. Just run that exe and follow the instructions. Once this completes all you need to do is double click the shortcut on your desktop. 

Now you can play by clicking "Play" and then "Multiplayer", logging in with either a guest account or a [BeamMP Forum](https://forum.beammp.com) account.
Then just select a server to play on! That's it! :)

If you need help at any point, see the [troubleshooting](#troubleshooting) section or join the official [Discord](https://discord.gg/BeamMP) and ask our dedicated support team!

# Servers

[Click here for a step-by-step guide](https://wiki.beammp.com/en/home/server-installation) on how to set up and run a server for you & your friends.

The server is usable free of charge, and the source code is available on [GitHub](https://github.com/BeamMP/BeamMP-Server).

Please check out [wiki.beammp.com](https://Wiki.beammp.com) for a guide on how to setup your own server.

# How does it work?
*This section is a technical explanation of the inner workings of the project and is not relevant for most players.*

The Launcher is a separate program which start the game and connects to the Lua mod right away. The launcher then connects to a remote server of your choice, and these two communicate. The launcher then forwards some packets to the game, like car positions, rotations, chat messages, etc.

For more information on how the launcher and server operate, you can read the source code (C++) in their respective repositories: 
- [Launcher](https://github.com/BeamMP/BeamMP-Launcher)
- [Server](https://github.com/BeamMP/BeamMP-Server)

# Roadmap
You can see and keep track of development, planned features, etc. on our [Trello](https://trello.com/b/Kw75j3zZ/beamngdrive-multiplayer)!

Additionally, you can join the [Discord](https://discord.gg/BeamMP), where regular updates are posted!

# Troubleshooting

- [Common Issues](https://forum.beammp.com/)
- [Error Codes](https://wiki.beammp.com/en/error-codes)
- [Server Auth Key](https://www.beammp.com/keymaster)

If none of these fix your issue, we have a dedicated support team on our [Discord](https://discord.gg/BeamMP), and a wonderful up-to-date troubleshooting channel (#before-you-ask)!

## Contributors ✨

Thanks goes to these wonderful people ([emoji key](https://allcontributors.org/docs/en/emoji-key)):

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tr>
    <td align="center"><a href="http://kortlepel.com"><img src="https://avatars.githubusercontent.com/u/29932116?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Lion</b></sub></a><br /><a href="https://github.com/BeamMP/BeamMP/commits?author=lionkor" title="Code">💻</a> <a href="#content-lionkor" title="Content">🖋</a> <a href="https://github.com/BeamMP/BeamMP/commits?author=lionkor" title="Documentation">📖</a> <a href="#mentoring-lionkor" title="Mentoring">🧑‍🏫</a> <a href="#maintenance-lionkor" title="Maintenance">🚧</a> <a href="#platform-lionkor" title="Packaging/porting to new platform">📦</a> <a href="https://github.com/BeamMP/BeamMP/pulls?q=is%3Apr+reviewed-by%3Alionkor" title="Reviewed Pull Requests">👀</a></td>
  </tr>
</table>

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->

This project follows the [all-contributors](https://github.com/all-contributors/all-contributors) specification. Contributions of any kind welcome!