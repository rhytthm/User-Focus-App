# User Focus App 
This app has been made using SwiftUI. It has folowing features -
1. A User can enter into one of the four predefi ned Focus Modes ( Work, Play, Rest, Sleep).
2. Once they're in a particular mode, that focus mode starts with a timer.
3. The timer shows the current time in 00:00 form, when the timer crosses an hour mark then you show the current time in 00:00:00 format.
4. Every 2 minutes the user gets a Point and a badge.
5. Handled **Edge cases** where the User closes the app. 
   * Ideally, the user should be redirected to the same focus mode which was active. 
   * The Session Points shouldn't be lost. 
6. From the Home View, add a button to navigate to the Profile View. 
   Prefill the User name, and a User image and store it into the DB. 

## Demo Videos
| Dark/Light mode  | Timer About to Complete & Edge case |
| ------------- | ------------- |
|<video src="https://github.com/user-attachments/assets/932ecff5-3293-44e0-81a0-f5867d901be8">|<video src="https://github.com/user-attachments/assets/aae47cb8-7a8a-41d9-8c66-63eb53b522af">|
