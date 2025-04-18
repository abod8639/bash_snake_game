#!/bin/bash

#* ------------------------------------------------------
#* ---------------  POWERED BY DEXTER   -----------------
#* ------------------------------------------------------

# Snake Game in Bash with five different modes and colorful display
# This is a feature-rich implementation of the classic Snake game with multiple
# gameplay modes, dynamic difficulty, and colorful visual elements.

#* ==============================================
#*       Game Configuration and Constants
#* ==============================================

#* Game dimensions - defines the playable area
readonly GAME_WIDTH=60           # Width of game area
readonly GAME_HEIGHT=20          # Height of game area
readonly INITIAL_DELAY=0.1       # Starting game speed (lower = faster)
readonly INITIAL_SNAKE_LENGTH=3  # Starting length of snake
readonly INITIAL_SNAKE_X=25      # Starting X position
readonly INITIAL_SNAKE_Y=10      # Starting Y position

#* ANSI Color codes for visual elements
# These colors are used to create a vibrant and visually appealing game interface
readonly RED="\033[31m"
readonly GREEN="\033[32m"
readonly YELLOW="\033[33m"
readonly BLUE="\033[34m"
readonly MAGENTA="\033[35m"
readonly CYAN="\033[36m"
readonly WHITE="\033[37m"
readonly RESET="\033[0m"

#* Game State Variables
# Arrays to store snake body positions
declare -a snake_x_pos        # X coordinates of snake segments
declare -a snake_y_pos        # Y coordinates of snake segments
declare -i snake_length=$INITIAL_SNAKE_LENGTH
declare -i score=0            # Player's current score
declare -i game_over=0        # Game state flag
declare direction="RIGHT"     # Current snake direction
declare -i mode=1             # Current game mode (1-5)
declare delay=$INITIAL_DELAY  # Current game speed

#* Terminal Configuration
# Save original terminal settings for restoration later
old_stty=$(stty -g)
cols=$(tput cols)          # Get terminal width
lines=$(tput lines)        # Get terminal height

#* Food Position
food_x=0                   # Current food X position
food_y=0                   # Current food Y position

#* Clean up terminal on exit
# Function: cleanup
# Purpose: Restores terminal settings and cleans up the display when the game exits
# Called: On game exit or when interrupted (SIGINT/SIGTERM)
# Effects: 
# - Restores original terminal settings
# - Re-enables echo
# - Shows cursor
# - Clears screen
cleanup() {
    stty "$old_stty"
    stty echo
    echo -ne "\e[?25h"
    clear
    exit 0
}

trap cleanup EXIT SIGINT SIGTERM

#* Initialize snake positions
# Function: init_snake
# Purpose: Initializes the snake's starting position and length
# Effects:
# - Creates arrays for snake coordinates
# - Sets initial snake position (horizontal line of segments)
# - Snake starts facing right
init_snake() {
    snake_x_pos=()
    snake_y_pos=()
    for ((i=0; i<snake_length; i++)); do
        snake_x_pos[$i]=$((INITIAL_SNAKE_X - i))
        snake_y_pos[$i]=$INITIAL_SNAKE_Y
    done
}

#* Generate new food position
# Function: generate_food
# Purpose: Creates new food at a random position
# Algorithm:
# 1. Generates random coordinates within game bounds
# 2. Ensures food doesn't appear on snake body
# 3. Retries if position is invalid
generate_food() {
    local valid=0
    while (( valid == 0 )); do
        food_x=$((RANDOM % (GAME_WIDTH-2) + 1))
        food_y=$((RANDOM % (GAME_HEIGHT-2) + 1))
        valid=1
        
        for ((i=0; i<snake_length; i++)); do
            if (( snake_x_pos[i] == food_x && snake_y_pos[i] == food_y )); then
                valid=0
                break
            fi
        done
    done
}

#* Get color based on current mode
# Function: get_border_color
# Purpose: Returns the appropriate color for game border based on current mode
# Returns: ANSI color code string
# Mode colors:
# 1 - Green (Normal)
# 2 - Blue (Fast)
# 3 - Magenta (Slow)
# 4 - Cyan (Wraparound)
# 5 - Yellow (Rainbow)
get_border_color() {
    case $mode in
        1) echo -n "$GREEN"   ;;
        2) echo -n "$BLUE"    ;;
        3) echo -n "$MAGENTA" ;;
        4) echo -n "$CYAN"    ;;
        5) echo -n "$YELLOW"  ;;
    esac
}

#* Draw game border
# Function: draw_border
# Purpose: Renders the game border and status information
# Effects:
# - Draws box border using Unicode characters
# - Updates score and mode display
# - Applies mode-specific border color
draw_border() {
    local border_color=$(get_border_color)
    
    echo -ne "\e[1;1H$border_color╔"
    for ((i=1; i<=GAME_WIDTH; i++)); do
        echo -ne "═"
    done
    echo -ne "╗\n"
    
    for ((i=1; i<=GAME_HEIGHT; i++)); do
        echo -ne "\e[$((i+1));1H${border_color}║"
        echo -ne "\e[$((i+1));$((GAME_WIDTH+2))H${border_color}║"
    done
    
    echo -ne "\e[$((GAME_HEIGHT+2));1H${border_color}╚"
    for ((i=1; i<=GAME_WIDTH; i++)); do
        echo -ne "═"
    done
    echo -ne "╝$RESET"
    
    echo -ne "\e[$((GAME_HEIGHT+3));1H${WHITE}Score: $score | Mode: $mode | Q to quit | WASD to move | M to change mode$RESET"
}

#* Get snake colors based on mode
# Function: get_snake_colors
# Purpose: Determines snake body and head colors based on game mode
# Returns: Two color codes (body head)
# Special handling for rainbow mode (mode 5)
get_snake_colors() {
    case $mode in
        1) echo "$GREEN $WHITE"  ;;
        2) echo "$BLUE $YELLOW"  ;;
        3) echo "$MAGENTA $CYAN" ;;
        4) echo "$CYAN $RED"     ;;
        5) echo "" "$WHITE"      ;; # Rainbow mode handled separately
    esac
}

#* Draw the snake
# Function: draw_snake
# Purpose: Renders the snake on screen
# Algorithm:
# 1. Clears previous snake position
# 2. Draws head with direction indicator (▲▼◄►)
# 3. Draws body segments with mode-specific colors
# Special features:
# - Rainbow mode cycles colors for body segments
# - Different head shapes based on direction
draw_snake() {
    local colors=($(get_snake_colors))
    local snake_color=${colors[0]}
    local head_color=${colors[1]}

    #*Clear previous snake positions
    for ((i=0; i<snake_length; i++)); do
        if (( snake_x_pos[i] > 0 && snake_x_pos[i] < GAME_WIDTH+1 && 
              snake_y_pos[i] > 0 && snake_y_pos[i] < GAME_HEIGHT+1 )); then
            echo -ne "\e[$((snake_y_pos[i]+1));$((snake_x_pos[i]+1))H "
        fi
    done

    # Draw snake head
    if (( snake_x_pos[0] > 0 && snake_x_pos[0] < GAME_WIDTH+1 && 
          snake_y_pos[0] > 0 && snake_y_pos[0] < GAME_HEIGHT+1 )); then
        echo -ne "\e[$((snake_y_pos[0]+1));$((snake_x_pos[0]+1))H$head_color"
        
        case $direction in
            "UP")    echo -ne "▲" ;;
            "DOWN")  echo -ne "▼" ;;
            "LEFT")  echo -ne "◄" ;;
            "RIGHT") echo -ne "►" ;;
        esac
    fi

    # Draw snake body
    for ((i=1; i<snake_length; i++)); do
        if (( snake_x_pos[i] > 0 && snake_x_pos[i] < GAME_WIDTH+1 && 
              snake_y_pos[i] > 0 && snake_y_pos[i] < GAME_HEIGHT+1 )); then
            if (( mode == 5 )); then
                # Rainbow mode - different color for each segment
                case $((i % 6)) in
                    0) snake_color=$RED     ;;
                    1) snake_color=$YELLOW  ;;
                    2) snake_color=$GREEN   ;;
                    3) snake_color=$CYAN    ;;
                    4) snake_color=$BLUE    ;;
                    5) snake_color=$MAGENTA ;;
                esac
            fi
            
            echo -ne "\e[$((snake_y_pos[i]+1));$((snake_x_pos[i]+1))H${snake_color}O$RESET"
        fi
    done
}

#* Get food character and color based on mode
# Function: get_food_attributes
# Purpose: Determines food appearance based on game mode
# Returns: Two values - character and color for food
# Mode-specific food:
# 1 - Red heart (♥)
# 2 - Yellow diamond (♦)
# 3 - White star (★)
# 4 - Green circle (●)
# 5 - Rainbow flower (✿)
get_food_attributes() {
    case $mode in
        1) echo "♥" "$RED" ;;
        2) echo "♦" "$YELLOW" ;;
        3) echo "★" "$WHITE" ;;
        4) echo "●" "$GREEN" ;;
        5) 
            # Rainbow mode - random color
            case $((RANDOM % 6)) in
                0) echo "✿" "$RED" ;;
                1) echo "✿" "$YELLOW" ;;
                2) echo "✿" "$GREEN" ;;
                3) echo "✿" "$CYAN" ;;
                4) echo "✿" "$BLUE" ;;
                5) echo "✿" "$MAGENTA" ;;
            esac
            ;;
    esac
}

#* Draw the food
# Function: draw_food
# Purpose: Renders food item on screen
# Uses: get_food_attributes for appearance
# Effects: Draws food with mode-specific character and color
draw_food() {
    local food_attrs=($(get_food_attributes))
    local food_char=${food_attrs[0]}
    local food_color=${food_attrs[1]}
    
    echo -ne "\e[$((food_y+1));$((food_x+1))H$food_color$food_char$RESET"
}

#* Update snake position and check collisions
# Function: update_snake
# Purpose: Core game logic for snake movement and collision detection
# Algorithm:
# 1. Updates snake position based on direction
# 2. Handles food collection and growth
# 3. Checks for collisions (walls and self)
# 4. Implements special mode behaviors (wraparound)
# Effects:
# - Updates snake position arrays
# - Modifies score and length
# - Can trigger game over
update_snake() {
    local prev_x=("${snake_x_pos[@]}")
    local prev_y=("${snake_y_pos[@]}")
    
    # Move head
    case $direction in
        "UP")    snake_y_pos[0]=$((snake_y_pos[0] - 1)) ;;
        "DOWN")  snake_y_pos[0]=$((snake_y_pos[0] + 1)) ;;
        "LEFT")  snake_x_pos[0]=$((snake_x_pos[0] - 1)) ;;
        "RIGHT") snake_x_pos[0]=$((snake_x_pos[0] + 1)) ;;
    esac
    
    # Move body
    for ((i=1; i<snake_length; i++)); do
        snake_x_pos[$i]=${prev_x[$i-1]}
        snake_y_pos[$i]=${prev_y[$i-1]}
    done
    
    # Check food collision
    if (( snake_x_pos[0] == food_x && snake_y_pos[0] == food_y )); then
        score=$((score + 10))
        snake_length=$((snake_length + 1))
        snake_x_pos[$snake_length-1]=${prev_x[$snake_length-2]}
        snake_y_pos[$snake_length-1]=${prev_y[$snake_length-2]}
        generate_food
        
        # Increase speed (except in mode 3)
        if (( mode != 3 )); then
            delay=$(awk "BEGIN {print $delay * 0.95}")
            if (( $(awk "BEGIN {print ($delay < 0.03) ? 1 : 0}") )); then
                delay=0.03
            fi
        fi
    fi
    
    # Check wall collision (mode 4 has wraparound)
    if (( mode != 4 )); then
        if (( snake_x_pos[0] <= 0 || snake_x_pos[0] > GAME_WIDTH || 
              snake_y_pos[0] <= 0 || snake_y_pos[0] > GAME_HEIGHT )); then
            game_over=1
        fi
    else
        # Wraparound for mode 4
        if (( snake_x_pos[0] <= 0 )); then
            snake_x_pos[0]=$GAME_WIDTH
        elif (( snake_x_pos[0] > GAME_WIDTH )); then
            snake_x_pos[0]=1
        fi
        
        if (( snake_y_pos[0] <= 0 )); then
            snake_y_pos[0]=$GAME_HEIGHT
        elif (( snake_y_pos[0] > GAME_HEIGHT )); then
            snake_y_pos[0]=1
        fi
    fi
    
    # Check self collision
    for ((i=1; i<snake_length; i++)); do
        if (( snake_x_pos[0] == snake_x_pos[i] && snake_y_pos[0] == snake_y_pos[i] )); then
            game_over=1
            break
        fi
    done
}

#* Handle user input
# Function: handle_input
# Purpose: Processes user keyboard input
# Controls:
# - WASD: Direction controls
# - M: Change game mode
# - Q: Quit game
# Features:
# - Prevents 180° turns
# - Updates game speed on mode change
handle_input() {
    if read -t 0.01 -n 1 key; then
        case $key in
            w|W) [[ $direction != "DOWN" ]]  && direction="UP"    ;;
            s|S) [[ $direction != "UP" ]]    && direction="DOWN"  ;;
            a|A) [[ $direction != "RIGHT" ]] && direction="LEFT"  ;;
            d|D) [[ $direction != "LEFT" ]]  && direction="RIGHT" ;;
            m|M) 
                mode=$((mode % 5 + 1))
                case $mode in
                    1) delay=0.1  ;;
                    2) delay=0.07 ;;
                    3) delay=0.15 ;;
                    4) delay=0.1  ;;
                    5) delay=0.1  ;;
                esac
                ;;
            q|Q) game_over=1 ;;
        esac
    fi
}

#* Show game over screen
# Function: show_game_over
# Purpose: Displays game over screen with final score
# Effects:
# - Shows game over message
# - Displays final score
# - Waits for key press to exit
show_game_over() {
    echo -ne "\e[$((GAME_HEIGHT/2));$((GAME_WIDTH/2-5))H${RED}Game Over!$RESET"
    echo -ne "\e[$((GAME_HEIGHT/2+1));$((GAME_WIDTH/2-7))H${WHITE}Final Score: $score$RESET"
    echo -ne "\e[$((GAME_HEIGHT/2+2));$((GAME_WIDTH/2-8))H${GREEN}Press any key to exit$RESET"
    echo -ne "\e[?25h"
    read -n 1
}

#* Show mode selection screen
# Function: show_modes_info
# Purpose: Displays welcome screen and game mode information
# Shows:
# - Available game modes and their features
# - Control instructions
# - Waits for player to start game
show_modes_info() {
    clear
    echo -e "${WHITE}Welcome to Snake Game!${RESET}\n"
    echo -e "${GREEN}Available Modes:${RESET}"
    echo -e "${GREEN}1. Normal Mode:${RESET} Medium speed, green color"
    echo -e "${BLUE}2. Fast Mode:${RESET} High speed, blue color"
    echo -e "${MAGENTA}3. Slow Mode:${RESET} Low speed, pink color"
    echo -e "${CYAN}4. Wraparound Mode:${RESET} Cross through borders, cyan color"
    echo -e "${YELLOW}5. Rainbow Mode:${RESET} Multi-colored snake and food\n"
    echo -e "${WHITE}Controls:${RESET}"
    echo -e "W: Move up"
    echo -e "S: Move down"
    echo -e "A: Move left"
    echo -e "D: Move right"
    echo -e "M: Change mode"
    echo -e "Q: Quit game\n"
    echo -e "${RED}Press any key to start...${RESET}"
    read -n 1
}

#* Main game loop
# Function: run_game
# Purpose: Main game loop
# Algorithm:
# 1. Initializes game state
# 2. Repeatedly:
#    - Draws game elements
#    - Handles input
#    - Updates game state
#    - Controls game timing
# Effects:
# - Manages entire gameplay session
run_game() {
    echo -ne "\e[?25l"
    clear
    
    init_snake
    generate_food
    stty -icanon -echo
    
    while (( game_over == 0 )); do
        draw_border
        draw_food
        draw_snake
        sleep $delay
        handle_input
        update_snake
    done
    
    show_game_over
    stty "$old_stty"
    stty echo
    clear
}

#* Main function
# Function: main
# Purpose: Entry point and setup
# Steps:
# 1. Verifies terminal size
# 2. Shows welcome screen
# 3. Starts game loop
# Effects:
# - Exits if terminal is too small
# - Launches complete game session
main() {
    if (( cols < GAME_WIDTH+5 || lines < GAME_HEIGHT+5 )); then
        echo "Terminal too small! Please resize your window."
        echo "Minimum required size: ${GAME_WIDTH}x${GAME_HEIGHT}"
        exit 1
    fi
    
    show_modes_info
    run_game
}

# Start the game
main
