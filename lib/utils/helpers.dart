import 'package:flutter/material.dart';

/// Width at which the layout switches from the phone layout to the
/// sidebar / two-column layout (same breakpoint as the Figma design).
const double kWideBreakpoint = 900;

bool isWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kWideBreakpoint;

bool isCompact(BuildContext context) => MediaQuery.sizeOf(context).width < 480;

void showInfo(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

const List<String> _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const List<String> _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String weekdayName(DateTime d) => _weekdays[d.weekday - 1];

String dateLabel(DateTime d) => '${weekdayName(d)}, ${d.day} ${_months[d.month - 1]}';

String greeting(DateTime d) {
  if (d.hour < 12) return 'Good morning';
  if (d.hour < 17) return 'Good afternoon';
  return 'Good evening';
}
