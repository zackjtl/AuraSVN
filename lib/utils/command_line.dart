List<String> splitCommandLine(String command) {
  final parts = <String>[];
  final current = StringBuffer();
  var inSingleQuote = false;
  var inDoubleQuote = false;

  for (var i = 0; i < command.length; i += 1) {
    final char = command[i];
    if (char == "'" && !inDoubleQuote) {
      inSingleQuote = !inSingleQuote;
      continue;
    }
    if (char == '"' && !inSingleQuote) {
      inDoubleQuote = !inDoubleQuote;
      continue;
    }
    if (char.trim().isEmpty && !inSingleQuote && !inDoubleQuote) {
      if (current.isNotEmpty) {
        parts.add(current.toString());
        current.clear();
      }
      continue;
    }
    current.write(char);
  }

  if (current.isNotEmpty) {
    parts.add(current.toString());
  }
  return parts;
}
