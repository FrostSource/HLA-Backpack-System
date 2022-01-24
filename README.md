
# HLA-Backpack-System v2.0
Arbitrary prop storage in Alyx's backpack. Completely open source.

The current example is still a work in progress with more to come.

**\maps\backpack_system_offset_helper.vmap** is a work-in-progress map to aid the process of finding custom grab offset/angle values for any prop.

> This branch is an early work in progress of the total overhaul. Many descriptions might be missing or out-of-date.

### Features:
* Any physical prop placeable in backpack just like ammo or resin.
* Programmatically choose where the player can take items out using Hammer's I/O system.
* Custom backpack sounds per-item supported.
* Grab offset/angle per-item supported (see [Important Issues](#important-issues))
* Save/Load support.
* Modify size/shape of the backpack trigger in hammer.
* Campaign support **New in v2.0**
* Level transition support. **New in v2.0**

## Important Issues
Due to my poor maths ability and the Quaternion class being broken in VScript, custom grab angles are not mirrored to the left hand. If anyone knows a solution to this please start an issue.

## Installation
Files from **maps\prefabs\\** go into your addons `content` folder:\
**Half-Life Alyx\content\hlvr_addons\\\<your addon>\maps\prefabs\\**

Files from **scripts\\** go into your addons `game` folder:\
**Half-Life Alyx\game\hlvr_addons\\\<your addon>\scripts\\**

## Usage

Instructions for v2.0 coming soon...
