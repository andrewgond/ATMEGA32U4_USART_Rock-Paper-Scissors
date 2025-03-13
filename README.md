# ECE375 Lab 7 - Remotely Communicated Rock Paper Scissors

## Overview
This project is part of the **ECE375: Computer Organization and Assembly Language Programming** course at Oregon State University. It involves writing an assembly program for two ATmega32U4 microcontroller boards to play a game of Rock, Paper, Scissors through serial communication.

## Objectives
- Implement a **Universal Synchronous/Asynchronous Receiver/Transmitter (USART)** module for communication.
- Utilize **Timer/Counter1** in normal mode to generate a **1.5-second delay**.
- Configure an **LCD display** to show game status and user selections.
- Implement **button-based input** for gesture selection and game start.
- Use **LEDs as a countdown timer** before the selection is locked in.

## Functionality
1. **Game Start**
   - Upon boot, the LCD displays:
     ```
     Welcome!
     Please press PD7
     ```
   - The user presses PD7 to indicate readiness.
   - The board transmits a **ready signal** to the opponent and waits.

2. **Countdown and Gesture Selection**
   - When both players are ready, a **6-second countdown** starts via **PB4-PB7 LEDs**.
   - The user can press **PD4** to cycle through the available gestures:
     - **Rock → Paper → Scissors → Rock...**
   - The selected gesture appears on the LCD.

3. **Game Resolution**
   - After the countdown, both boards exchange gestures via USART.
   - The opponent’s choice is displayed along with the user’s choice.
   - The outcome (**Win, Lose, or Draw**) is displayed on the LCD.
   - After a delay, the game resets to the welcome screen.

## Hardware Setup
- **AVR ATmega32U4 microcontroller**
- **USART1 (TX/RX) for communication**
- **LCD display for user interface**
- **Buttons (PD7 for start, PD4 for selection)**
- **4 LEDs (PB4-PB7) as countdown timer**

### USART Configuration
- Baud Rate: **2400 bps with double speed mode**
- Data Frame: **8-bit data, 2 stop bits, no parity**

### Timer Configuration
- **Timer/Counter1 in NORMAL mode**
- **Polling or interrupt-based implementation (no busy loop delays allowed)**

## Extra Credit Challenge
An extended version of the game allows each player to select **both right and left-hand gestures** and make a strategic final choice before the result is determined.

## License
This project is for educational purposes at Oregon State University.

---
Feel free to modify and expand this README to include code examples, installation steps, or additional notes!
