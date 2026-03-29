# SpeedSplits

A reward-focused speedrunner's addon that smoothly tracks **Boss Splits**, **Personal Bests**, **Run History**, and includes unique **Individual Timer**, **PB Sound Effects**, and **Route Awareness**

(colour)
__Note__: Feedback and suggestions are welcomed as comments!
(colour)

# Unique Features
### **Individual Frames, Resizing, and Customisation**
Fully adjustable, individual, and toggleable frames for the running Timer and Splits Table.
<video example>
(Resize frame, scroll bar, on-hover, moving separately, diff Customisation, textures Customisation, presets

### **PB Reward Toasts**
Celebrate Personal Bests with custom textures and sound effects!
<video example>

### **Route Awareness**
Automatically adjust your PBs to match the exact order you have killed bosses. Try out different routes and compare them to your fastest at the end! Also prevents against impossible kill times.
<video example>


# Other Features
*   **Speedrun Mode Support**: Choose between __All Bosses mode__ and __Last Boss mode__.
*   **Boss Split Tracking**: Automatically records live boss-by-boss split times during your run.
*   **Personal Best Comparison**: Compares each split against your saved PB pace and overall run pace.
*   **Full Visual Customisation**: Adjust colours, fonts, textures, scaling, and overall presentation to suit your UI.
*   **Adjustable Columns**: Resize each Splits Table column to be wider or smaller, or add a scroll bar when needed.
*   **Boss Ignore Controls**: Ignore specific bosses manually, sending all completed runs with them to a seperate database table.
*   **Reload Awareness**: Prevents against cheats using /reloads to reset the timer. Also stops users setting impossible to beat times.
*   **Highly-reabable Splits**: All Splits centred in their columns, aligned on digits, and appropriately coloured.
*   **Run History Logging**: Stores all runs with filters so you can review and compare attempts over time.
*   **Custom Split Thresholds**:
    *   __On pace__: First threshold for runs close to a PB.
    *   __Behind pace__: Second threshold for runs behind PB.
    *   **Dynamic colours**: split colours will dynamically fit between threshold colours.


# Usage
### Commands

*   Use '**/ss**' to open settings.
*   Use '**/ss history**' to open Run History.

### Example

*   Enter any instance with bosses (loads entries via Objectives or Adventure Journal).
*   Start moving = start timer.
*   Set speedrun mode to either 'All Bosses' (default) or 'Last Bosses'.
*   Kill any boss: Records coloured split time, shows toast effect, and adjusts route.
*   Kill last boss: Timer stops instantly, colour indicates speedrun success, run and route saved to database.
*   Review speedrun via Run History (timer icon or '/ss history')


# Planned Features

*   3D Models for current instance bosses (BETA)
*   Global leader board comparison.
*   Waypoint routing and route sharing.
*   Per-boss notes, reminders, suggestions.
*   Instance difficulty awareness and toggle.
*   Run history inspection and analysis.
*   Reload awareness and forged run protection. (Done) (strikethrough)

---
Feedback is welcome, you can support me by...
---

__Disclaimer__: SpeedSplits timer icon represents the concept of 'speed' generally, not necessarily the UI of the addon. This addon is in early development; your feedback is highly appreciated.

> Game: World of Warcraft
> Topics: speed, speedrun, speedrunner, speedrunning, splits, timer, run
