import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class DateSelectionSheet extends StatefulWidget {
  const DateSelectionSheet({Key? key}) : super(key: key);

  @override
  State<DateSelectionSheet> createState() => _DateSelectionSheetState();
}

class _DateSelectionSheetState extends State<DateSelectionSheet> {
  // This Set stores all selected dates (Set = no duplicates, like HashSet in C#)
  final Set<DateTime> _selectedDates = {};

  // The month currently displayed in the calendar
  DateTime _focusedDay = DateTime.now();

  // Helper to normalize dates (remove time component)
  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Text(
            'Select Training Days',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),

          // The calendar widget
          TableCalendar(
            // Display settings
            firstDay: DateTime(2000),
            lastDay: DateTime(2200),
            headerStyle: HeaderStyle(
              formatButtonVisible: false, // Hide format button
            ),
            focusedDay: _focusedDay,

            // Calendar format (month view)
            calendarFormat: CalendarFormat.month,

            // Selected days (the dates user tapped)
            selectedDayPredicate: (day) {
              // Check if this day is in our selected set
              return _selectedDates.contains(_dateOnly(day));
            },

            // When user taps a date
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                final normalized = _dateOnly(selectedDay);

                // Toggle: if already selected, remove it; otherwise add it
                if (_selectedDates.contains(normalized)) {
                  _selectedDates.remove(normalized);
                } else {
                  _selectedDates.add(normalized);
                }

                _focusedDay = focusedDay;
              });
            },

            // When user changes month (swipes or taps arrows)
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },

            // Styling
            calendarStyle: CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
                shape: BoxShape.circle,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Show how many dates selected
          Text(
            '${_selectedDates.length} days selected',
            style: Theme.of(context).textTheme.bodyMedium,
          ),

          const SizedBox(height: 16),

          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed:
                    _selectedDates.isEmpty
                        ? null // Disable if no dates selected
                        : () {
                          // Sort dates and return them
                          final sorted =
                              _selectedDates.toList()
                                ..sort((a, b) => a.compareTo(b));
                          Navigator.of(context).pop(sorted);
                        },
                child: const Text('Use selected dates'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
