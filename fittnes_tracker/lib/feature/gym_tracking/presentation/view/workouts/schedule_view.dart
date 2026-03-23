import 'package:flutter/material.dart';

class ScheduleView extends StatefulWidget {
  final List<DateTime> initialSelected;
  const ScheduleView({Key? key, this.initialSelected = const []})
    : super(key: key);

  @override
  _WorkoutDatePickerState createState() => _WorkoutDatePickerState();
}

class _WorkoutDatePickerState extends State<ScheduleView> {
  late List<DateTime> _selectedDates;
  DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  int daysKey(DateTime d) =>
      dateOnly(d).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  DateTime fromDaysKey(int key) => DateTime(key * Duration.millisecondsPerDay);
  DateTime displayMonth = DateTime.now();
  List<DateTime> visibleDays(DateTime month) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    // adjust if you want Sun-first: use different offset
    final startOffset = firstOfMonth.weekday - 1; // Monday=1..Sunday=7
    final gridStart = firstOfMonth.subtract(Duration(days: startOffset));
    return List.generate(42, (i) => gridStart.add(Duration(days: i)));
  }

  @override
  void initState() {
    super.initState();
    _selectedDates = widget.initialSelected;
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      if (_selectedDates.contains(date)) {
        _selectedDates.remove(date);
      } else {
        _selectedDates.add(date);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Select Workout Dates')),
      body: CalendarDatePicker(
        initialDate: DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        onDateChanged: _onDateSelected,
        selectableDayPredicate: (date) => true,
      ),
    );
  }
}
