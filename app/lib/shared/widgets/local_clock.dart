import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final class LocalClock extends StatefulWidget {
  const LocalClock({super.key});

  @override
  State<LocalClock> createState() => _LocalClockState();
}

final class _LocalClockState extends State<LocalClock> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    final delay = Duration(seconds: 60 - _now.second);
    _timer = Timer(delay, _beginMinuteUpdates);
  }

  void _beginMinuteUpdates() {
    if (!mounted) return;
    setState(() => _now = DateTime.now());
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Semantics(
      label: DateFormat.jm(locale).format(_now),
      child: Text(
        DateFormat.jm(locale).format(_now),
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}
