
# Curiosity vs Humanity

Curiosity vs Humanity ("Curiosity", in short) is an interactive art installation coded as a game.

## Game Outcome

Each game will end either in SAVE (player does not kill the artist) or KILL (player kills the artist).

## Game state

At any point of time, the game is in one of the following states:

* loading - the game is still loading
* waiting - the game is waiting for the player to enter the game
* started - the player has entered the game
* saved - the player has chosen to not kill the artist (outcome is SAVE)
* killed - the player has chosen to kill the artist (outcome is KILL)
* statsSaved - the game has ended and total number of SAVE outcomes is displayed
* statsKilled - the game has ended and total number of KILL outcomes is displayed

## Player Interaction with the Game

The game uses an infrared sensor to detect the players presence and distance from the sensor.

The distance is divided into zones:

| ZONE    | max distance sensor is able to read | the save zone        | neutral zone  | the kill zone        | min distance the sensor is able to read | sensor location |
|---------|-------------------------------------|----------------------|---------------|----------------------|-----------------------------------------|-----------------|
| EXAMPLE | 400cm                               | 40cm (400cm - 360cm) | 360cm - 60cm  | 40cm (60cm - 20cm)   | 20cm                                    | 0cm             |

Max distance, save zone, kill zone and min distance are configurable parameters.
                                    
Neutral zone is not configurable, since it is all the space between the save and kill zone.

