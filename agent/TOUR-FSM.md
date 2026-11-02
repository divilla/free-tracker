# Tour Finite State Machine

## Screens

- Tour
- History - shows all tours ordered by StartTime descending
- Calendar - screen shows monthly calendar - today is in red sqare - active days 1..n tours in the day are blue squared - click on date transitions to HistoryScreen filtered by clicked date
- Config
- Exit

### Common

All screens have bottom navigation with Tour|History|Calendar|Config|Exit items.

### Tour

Tour consist of:
1. Square Map on top - displays current position as blinking red dot - displays red line through all previous red positions - displays indoor as blinking blue dot
2. Action Menu Buttons - Start|Pause|Resume|Stop|Continue - buttons are enabled/disabled depending on TourMainState - Continue button is only enabled if last tour `is_active`
3. StartDate - Shown in format `YYYY-MM-DD` - example: `2026-03-01`
4. StartTime - Shown in format `HH:MM:SS` (optional `AM`/`PM`) - example: `16:03:01` or `04:03:01 PM` depending on the config value
5. TotalDistance - `km` or `mi` with 3 decimals - example: `0.000 km` or `0.011 mi` or `12.001 km` - TotalDistance is dynamic in RecordingState
6. ElapsedTime -  Shown in format `HH:MM:SS` - example: `03:01:02` - time is dynamic (changing every second) in RecordingState - time is stopped in all other states - shows `00:00:00` in IdleState
7. CurrentSpeed | AverageSpeed - `km/h` or `mph` speed with 1 decimal - example `4.3 | 3.3 km/h` or `3.3 | 2.0 mph` - current_speed=(sum last 3 distances)/3s | average_speed=total_distance/elapsed_time - shows `0.0 | 0.0 km/h` if not in RecordingState and `0.0 | 0.0 km/h` for first 3 seconds after start (surpress noise)

**Wireframe**:
-----------------------------
| Square Map                |<br>
|                           |<br>
|                           |<br>
|                           |<br>
|                           |<br>
|                           |<br>
|                           |<br>
|                           |<br>
-----------------------------
| Start    | StartDate      |<br>
| Pause    | StartTime      |<br>
| Resume   | TotalDistance  |<br>
| Stop     | ElapsedTime    |<br>
| Continue | AverageSpeed   |<br>
| New Tour | CurrentSpeed   |<br>
-----------------------------
|      Navigation  Bar      |<br>
-----------------------------

### History

Each item contains:
1. Line - StartTime
2. Line - TotalDistance | ElapsedTime
3. Line - OpenButton

**Wireframe**:
-----------------------
| 2026-10-01 15:21    |<br>
| 21.101 km  00:17:18 |<br>
|        Open         |<br>
-----------------------
| 2026-09-11 15:21    |<br>
| 21.101 km  00:17:18 |<br>
|        Open         |<br>
-----------------------
| 2026-09-01 15:21    |<br>
| 21.101 km  00:17:18 |<br>
|        Open         |<br>
-----------------------
|        ...          |<br>
-----------------------
|   Navigation Bar    |<br>
-----------------------

### Exit

- click on Exit pops `Are you sure? Yes/No` confirmation dialog in center and 
- app exits on Yes - OnExitEvent is triggered that 
- executes _manual_resume_/_stop_ flow if in PausedState
- executes _stop_ if in RecordingState

## App Start

On app start new empty tour in IdleState is show. If there is saved tour where date part of StartDateTime == current date (today) then open that tour instead.

## Tour Base States

DB names:
- recording
- paused
- finished

Transitions:
- IdleState      -> _start_            -> RecodingState
- RecordingState -> _manual_pause_     -> PausedState
- RecordingState -> _automatic_pause_  -> PausedState
- RecordingState -> _stop_             -> FinishedState
- PausedState    -> _manual_resume_    -> RecordingState
- PausedState    -> _automatic_resume_ -> RecordingState
- FinishedState  -> _continue_         -> RecordingState
- FinishedState  -> _delete_           -> DeletedState

*IdleState means it is not yet saved to DB. DeletedState means its deleted from DB.*

*_automatic_resume_ can resume only PausedState reached via _automatic_pause_. _manual_resume_ can resume both _manual_pause_ and _automatic_pause_.*

States:
- Idle   -> New Unstarted Tour
- Active -> Recording/Paused/Finished
- Saved  -> It can be accessed in history

## Tour Active States

States
