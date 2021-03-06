
# HLA-Backpack-System
Arbitrary prop_physics storage in Alyx's backpack. Completely open source and public domain.

The current example is still a work in progress with more to come.

**\maps\backpack_system_offset_helper.vmap** is a work-in-progress map to aid the process of finding custom grab offset/angle values for any prop.

### Features:
* Any prop_physics placeable in backpack just like ammo or resin.
* Programmatically choose where the player can take items out using Hammer's I/O system.
* Custom backpack sounds per-item supported.
* Grab offset/angle per-item supported (see [Important Issues](#important-issues))
* Save/Load support.
* Modify size/shape of the backpack trigger in hammer.

## Important Issues
Due to my poor maths ability and the Quaternion class being broken in VScript, custom grab angles are not mirrored to the left hand. If anyone knows a solution to this please start an issue.

## Installation
Files from **maps\prefabs\\** go into your addons content folder:\
**Half-Life Alyx\content\hlvr_addons\\\<your addon>\maps\prefabs\\**

Files from **scripts\\** go into your addons game folder:\
**Half-Life Alyx\game\hlvr_addons\\\<your addon>\scripts\\**

## Usage
### Setting up the system
The backpack system requires several entities in Hammer to work and these are bundled up into the prefab **prefabs\\backpack_system.vmap**. Simply drag the prefab from the asset browser into your map and put it somewhere out-of-bounds where the player will never be near. You will also want to create an empty room around the prefab large enough to contain any items the player will store in their backpack, this is where they will go.
*The surrounding room isn't strictly necessary after the last rewrite but is still recommended.*

### Setting up entities
Any **prop_physics** you wish the player to store in their backpack needs to have the script **backpack_item.lua** attached to its **Entity Scripts** key in the **Misc** section. It also must have a targetname. Nothing else needs to be done to the entity to allow storage.

*(**prop_physics** is the only entity type currently supported)*

### Taking items out
When you want the player to be able to retrieve a specific item(entity) from their backpack you will send the input **CallScriptFunction** to that entity using I/O with a parameter override of **EnableBackpackRetrieval**.

When you want to disallow the player from retrieving a specific item from their backpack you will send the input **CallScriptFunction** to that entity using I/O with a parameter override of **DisableBackpackRetrieval**.

This can be used to define an area in your map where the player can take the item out using a **trigger_multiple** and the ouputs **OnStartTouch** and **OnEndTouch** (see the example map for this usage.)

### All I/O hooks
##### Input to @backpack_system:
* **Input > CallScriptFunction > DisableAllBackpackStorage**
*Disabled backpack storage of any item, globally.*
* **Input > CallScriptFunction > EnableAllBackpackStorage**
*Enables backpack storage of items. Specific items which are disabled will stay disabled.*
* **Input > CallScriptFunction > DisableAllBackpackRetrieval**
*Disables retrieval of any item, globally.*
* **Input > CallScriptFunction > EnableAllBackpackRetrieval**
*Enables retrieval of items. Specific items disabled will stay disabled.*
* **Input > RunScriptCode > SetVirtualBackpackTarget(targetname)**
*Sets the name of the entity which will the location backpack items are teleported to when stored, e.g.
SetVirtualBackpackTarget('@virtual_backpack_target')
USE SINGLE QUOTES ONLY. USING DOUBLE QUOTES IN YOUR OUTPUT/OVERRIDE MAY CORRUPT YOUR FILE.*
* **Output > User1**
*Fires when the player puts ANY item in their backpack.*
* **Output > User2**
*Fires when the player retrieves ANY item from their backpack.*

##### Input to any backpack item:
* **Input > CallScriptFunction > PutInBackpack**
*Puts the item into the backpack immediately without sound or feedback. Can be useful for items the player starts with.*
* **Input > CallScriptFunction > EnableBackpackRetrieval**
*Tells the backpack system that this item may be retrieved from the backpack by the player. Also pushes this item to the top of the stack for retrieval, meaning it will come out first if multiple items are waiting. This will prevent the player from taking ammo from the backpack if there are items waiting, but won't prevent putting ammo in.*
* **Input > CallScriptFunction > DisableBackpackRetrieval**
*Tells the system to disallow this item from being retrieved.*
* **Input > CallScriptFunction > EnableBackpackStorage**
*Allows the item to be stored by putting it over the shoulder.*
* **Input > CallScriptFunction > DisableBackpackStorage**
*Disallows the item from being stored by putting it over the shoulder. Can be useful for items which have already served their purpose.*
* **Input > RunScriptCode > SetStoreSound(sound)**
*Sets the sound that should play for this item only when putting in backpack, e.g.
SetStoreSound('Inventory.DepositItem')
USE SINGLE QUOTES ONLY. USING DOUBLE QUOTES IN YOUR OUTPUT/OVERRIDE MAY CORRUPT YOUR FILE.*
* **Input > RunScriptCode > SetRetrieveSound(sound)**
*Sets the sound that should play for this item only when taking out of backpack, e.g.
SetRetrieveSound('Inventory.BackpackGrabItemResin')
USE SINGLE QUOTES ONLY. USING DOUBLE QUOTES IN YOUR OUTPUT/OVERRIDE MAY CORRUPT YOUR FILE.*
* **Output > User1**
*Fires when the player puts this item in their backpack.*
* **Output > User2**
*Fires when the player retrieves this item from their backpack.*
### Custom Keys
* **StoreSound (string)**
*The path to the sound the item will play when put in backpack.*
* **RetrieveSound (string)**
*The path to the sound the item will play when taken from backpack.*
* **GrabOffset (string)**
*A vector3 of offset values (x,y,z) defining the offset from the hand that the object will be when retrieved. Each number separated by a space.*
* **GrabAngle (string)**
*A vector3 of euler angles (pitch,yaw,roll) defining the rotation relative to the hand that the object will be when retrieved. Each number separated by a space.*
