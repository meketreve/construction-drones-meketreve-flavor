# Construction Drones - Meketreve flavor

--------------------------------------

This mods adds Construction drones and some supporting things.
They are ground based robots available from the early game, and will help contruct things quick.

Please note that the 2.0 support is still highly experimental.

<https://mods.factorio.com/mod/Updated_Construction_Drones>

## Development

Good reads:

* <https://gist.github.com/tburrows13/687f7dc86da1840624575ba437e86cfa>
* <https://github.com/justarandomgeek/vscode-factoriomod-debug/blob/current/doc/workspace.md>

In `.vscode/cheats` there are some useful cheats for testing the mod.

## Release

To make a release, ALWAYS TEST FIRST, then make a git tag and push it. Go to the github page for it and download the
tag as a zip. Upload it to mod portal.

## Drone controller and garage

The drones and their controller are unlocked by the **electronics** technology, the one that teaches the
electronic circuits they are made of.

The drones take their orders from a **drone controller**. It is a gun, so it goes in a weapon slot, which the
character has from the start, and each controller you carry commands a few drones at the same time, more if it is
of a higher quality. Without one in a weapon slot, the drones sit still.

The **drone garage** is a 3 by 3 building with a turning antenna, unlocked by a technology behind radar. It does
three things:

* it commands five more drones while its area covers you, so building several is how you get a bigger swarm
* drones on their way back unload their cargo into a garage in range instead of into your pockets
* chests **wired to it** with red or green wire become places the drones may take items from
* it shows that area on the ground while you hold a garage on the cursor, or select one already built
* it looks for work in its own area and sends its own drones, so put drones inside it and the base keeps being
  built while you are somewhere else. Those drones come back to the garage, unload there and stow themselves

That last one is the point of the wire: a chest announces its contents on the circuit network, the garage listens,
and only then do the drones know the items are there. A chest nobody wired is invisible to them, and so is a wired
chest that sits outside the area of every garage. Requester and buffer chests are read like any other chest, so
wire those only if you want the drones helping themselves to what the logistic network brought.

## Credits

This mod has been passed along a chain of forks:

* [Klonan](https://github.com/Klonan/Construction_Drones) wrote the original mod
* roy192 forked it
* [Tubbles](https://github.com/Tubbles/Construction_Drones) repackaged it as Updated Construction Drones and made
  it work on Factorio 2.0
* [daz96050](https://github.com/daz96050/Construction_Drones) rewrote it into modules, added quality support, job
  chaining and the remote view fixes, and updated it for Factorio 2.1

This flavor builds on daz96050's fork.

The MIT license in [LICENSE](LICENSE) covers the changes made here. See [NOTICE](NOTICE) for what it does not cover.
