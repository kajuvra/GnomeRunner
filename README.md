# GnomeRunner Addon

GnomeRunner is a World of Warcraft addon designed to facilitate and manage race events within raid groups. This addon keeps track of race statistics, including deaths, elapsed time, and the number of participants.

## Commands

### /race 
Starts a new race event. Only the raid leader can initiate a race. You must first have /payout and /Racename set before you can use /race. 

### /payout PayoutAmount 
Sets the prize pot for the race. This command must be used before starting a race.

### /racename Race Name 
Sets the name for the race event. This command must be used before starting a race.

### /endrace
Ends the current race event and displays final statistics.

## Additional Information

- Races can only be initiated by the raid leader.
- The prize pot and race name must be set before starting a race.
- The addon will automatically inform raid members when it is loaded.
- The addon provides feedback on deaths, elapsed time, and other race-related events.

## Installation

1. Download the GnomeRunner addon folder.
2. Place the folder in the World of Warcraft\_classic_\Interface\AddOns directory.
3. Launch World of Warcraft and enable the GnomeRunner addon from the in-game Addons menu.

## Contributors

- Kajuvra
- KingPin 

## Special Thanks To
Zhorax (CET)
Ddenali
Makan
Vorx
Seymorqueege 
Alone
And to all the Members of Kingdom and the Atiesh Community Discord https://discord.gg/atiesh

## NOT WORKING 

Sending Sound at start of race to other users (GnomeMaleCharge03.ogg).
Reporting of Correct amount of Raiders who are not Raid Leader / Assistant "Racers" during end of race. 
Reporting of player deaths to raid leader and raid warning. 
Addon loaded announcment and announcment to raid that the addon has been loaded. 
Addon reporting back to raid lead and sending a raid warning that a flare spell has been used by someone in raid. 

## Todo List 
Timer:
Updates the race timer every 30 seconds and sends a chat message every 30 minutes.
Status Command: 
A command to list the current status of the race and report it to raid chat. 
Addon Communication: 
The ability for the raid leaders addon to trigger the play gnome starting sound ((GnomeMaleCharge03.ogg). 
Report to raid leader and assistance that a user has used a flare spell and have the raid leader print that Racer has used a flare.  
Report to raid leader and assistance that a user has died and print that to raid chat. 


## License

This addon is open-source and available under the GNU General Public License v3.0. See the LICENSE file for more details.
