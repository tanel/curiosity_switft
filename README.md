# Curiosity vs Humanity

Curiosity vs Humanity ("Curiosity", in short) is an interactive art installation coded as a game.

## Architecture

The project consists of 2 projects (repositories):

1) Arduino project to read infrared sensor data.
2) XCode project, to interpret the sensor data and interact with player.

This repository contains the code for the second, XCode project.

## Outcome

Each game will end either in OUTCOME_SAVE (player does not kill the artist) or OUTCOME_KILL (player kills the artist).

## State

At any point of time, the game is in one of the following states:

* STATE_LOADING - the game is still loading
* STATE_WAITING - the game is waiting for the player to enter the game
* STATE_STARTED - the player has entered the game
* STATE_SAVED - the player has chosen to not kill the artist (outcome is SAVE)
* STATE_KILLED - the player has chosen to kill the artist (outcome is KILL)
* STATE_STATS_SAVED - the game has ended and total number of SAVE outcomes is displayed
* STATE_STATS_KILLED - the game has ended and total number of KILL outcomes is displayed

## Player Distance

The game uses an infrared sensor to detect the players presence and distance from the sensor.

Therefore all interaction between the player and the game is based on player **distance** from the sensor.

The distance is divided into zones:

| max sensor read | the save zone        | neutral zone  | the kill zone        | min sensor read | sensor |
|-----------------|----------------------|---------------|----------------------|-----------------|--------|
| 400cm           | 40cm (400cm - 360cm) | 360cm - 60cm  | 40cm (60cm - 20cm)   | 20cm            | 0cm    |

Max distance, save zone, kill zone and min distance are configurable parameters.

Neutral zone is not configurable, since it is all the space between the save and kill zone.

## Game Logic

When the player enters the neutral zone, they have the ability to finish the game with OUTCOME_SAVE, by walking
back into the save zone, or finish the game with OUTCOME_KILL, by walking further into the kill zone.

Should the player abrubtly exit the game, or not reach neutral zone at all after the game has started, the game
will automatically finish with OUTCOME_SAVE.

### OUTCOME_SAVE

The save zone is not enabled by default - otherwise, when the player would walk from the max sensor read zone
into the save zone, the game would instantly end. 

Exiting the save zone and entering the neutral zone will activate the save zone. The activation of the save zone
is tracked with TIMESTAMP_SAVE_ZONE_ACTIVATED_AT - if the value is not set.

Walking back from neutral zone into the save zone will finish the game with OUTCOME_SAVE, if the save zone
was activated (if TIMESTAMP_SAVE_ZONE_ACTIVATED_AT has a value).

    player -> save zone -> neutral zone -> again save zone -> OUTCOME_SAVE

### Automatic OUTCOME_SAVE

Player activity (sensor reading change) is tracked with TIMESTAMP_LAST_USER_INPUT_AT. In case the game started,
but there is no further activity from the player for CONFIGURATION_AUTO_SAVE_SECONDS then the game is 
automatically finished with OUTCOME_SAVE.

    player -> save zone -> no further activity for CONFIGURATION_AUTO_SAVE_SECONDS seconds -> OUTCOME_SAVE

### OUTCOME_KILL

Reaching the kill zone will finish the game with OUTCOME_KILL.

    player -> save zone -> neutral zone -> kill zone -> OUTCOME_KILL
