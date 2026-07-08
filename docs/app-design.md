# EGO Mobile App

## What is EGO?

EGO is the public transit organization of Ankara, Turkey. They operate hundreds of bus lines in the city, Ankara Metro and Ankaray LRT. They also run the payment system for the başkentray suburban train line, though they don't operate that line itself. The EGO branding emphasises white text on #E30A17 red a lot.

## The App

I want to build an app that pulls information from ego api and displays to user. Requests sent to ego servers should be the same as offical app to prevent causing any harm to system. API is documented in ego-api.md file.

### Bottom Tab Bar Screens

1. Home: This screen should have a large text input for entering stop number. All the bus stops have a 5-digit number. So entering this number should send user to that stop's screen.
2. Lines: This screen should have a segmented control on top to switch between bus/rail lines, a search bar and list all the lines. Lines should have the line number and name.
3. Card: This screen should display information about user's EGO Card. Balance and subscription last date (if there is one) should be shown directly and past card usage should be shown in a swiftui sheet when past usage button is pressed. There should be a top up button that opens the website in safari. Users should also be able to add multiple cards but only one can be the main card.
4. More: This screen can be empty, I have some plans for later.

### Other Screens

- Stop: Stop screen should have the stop name as title, and show a list of bus lines. Bus line items should have bus line code and line name. Additionally if there is a bus incoming it should display remaining time, license plate, bus code, and if the bus is solo or articulated. If there is no bus on the line it should display next departure time (this is handled by backend). It should send to Busses tab of Line screen when pressed on one of the items on list (pass the line code). Fetch data when this screen is visible and let user refresh by pulling down the list. Also when this screen is visible set this stop as the selected stop.
- Line: This is a screen with 4 tabs.
  - Line Stops: Lists stops of that bus line, also has information of total line distance and duration.
  - Departures: Lists departures of a line. Has a segmented control at the top for choosing between weekdays/saturday/sunday.
  - Busses: Lists busses on the road. It should have the same component as the list on the Stop screen and should fetch and display the live arriving times for this line and selected stop, fetch data when this screen is visible and let user refresh by pulling down the list.
  - Route: This will have a map but for now leave empty, we'll look at this later.

### Notes:

- Store user cards in UserDefaults.
- Store selected stop in @Observable, it doesn't need persistent storage but multiple screens should be able to access it (for example busses tab of lines screen).
- If user enters Busses tab of Lines screen, use FNC=Otobus endpoint to query data. You can omit the DURAK parameter if no stop has selected and it's also fine if selected stop is irrelevant to that line.
