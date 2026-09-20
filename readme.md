# Construction Drones - Meketreve flavor

--------------------------------------

This mods adds Construction drones and some supporting things.
They are ground based robots available from the early game, and will help contruct things quick.

Please note that the support for Factorio 2.x is still highly experimental.
Version 2.1.x of this mod requires Factorio 2.1, version 2.0.x is for Factorio 2.0.

The drones take their items out of your inventory. After researching "Construction drone chest pickup" they also
take them out of chests near the job, except requester and buffer chests, which hold items meant for something else.
The range is a map setting, set it to 0 to keep the drones out of your chests.

<https://mods.factorio.com/mod/Updated_Construction_Drones>

## Development

Good reads:

* <https://gist.github.com/tburrows13/687f7dc86da1840624575ba437e86cfa>
* <https://github.com/justarandomgeek/vscode-factoriomod-debug/blob/current/doc/workspace.md>

In `.vscode/cheats` there are some useful cheats for testing the mod.

## Release

To make a release, ALWAYS TEST FIRST, then make a git tag and push it. Go to the github page for it and download the
tag as a zip. Upload it to mod portal.

## Credits

This is a fork of a fork of a fork:

* [Klonan](https://github.com/Klonan/Construction_Drones) wrote the original mod
* roy192 forked it
* [Tubbles](https://github.com/Tubbles/Construction_Drones) repackaged that fork as Updated Construction Drones
  and made it work on Factorio 2.0

This flavor picks it up from there:

* Updated for Factorio 2.1 (steering moved onto the unit prototype, `LuaEntity::neighbours` split per type,
  rendering targets carry their own offset)
* Drones can take items out of chests near the job, after researching "Construction drone chest pickup"
* Products no longer disappear when a drone upgrades an entity with a full inventory
* Tighter steering, so the drones follow their path more closely

The MIT license in [LICENSE](LICENSE) covers the changes listed above. See [NOTICE](NOTICE) for what it does not
cover.
