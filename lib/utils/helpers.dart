import 'package:flutter/material.dart';

int? asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

Color actionColor(String action) {
  switch (action) {
    case 'A':
      return Colors.green;
    case 'M':
      return Colors.blue;
    case 'D':
      return Colors.red;
    case 'R':
      return Colors.orange;
    default:
      return Colors.blueGrey;
  }
}

String shortCommitDate(String date) {
  if (date.length >= 10) {
    return date.substring(0, 10);
  }
  return date;
}

String displayDiffText(String text) {
  if (text.startsWith('+') || text.startsWith('-') || text.startsWith(' ')) {
    return text.length > 1 ? text.substring(1) : '';
  }
  return text;
}

DateTime? parseDateTime(Object? value) {
  final text = value?.toString() ?? '';
  if (text.isEmpty) {
    return null;
  }
  return DateTime.tryParse(text);
}

