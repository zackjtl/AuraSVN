List<List<String>> parseCsv(String source) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < source.length; i += 1) {
    final char = source[i];
    if (char == '"') {
      final nextIsQuote = i + 1 < source.length && source[i + 1] == '"';
      if (inQuotes && nextIsQuote) {
        cell.write('"');
        i += 1;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }
    if (char == ',' && !inQuotes) {
      row.add(cell.toString());
      cell.clear();
      continue;
    }
    if ((char == '\n' || char == '\r') && !inQuotes) {
      if (char == '\r' && i + 1 < source.length && source[i + 1] == '\n') {
        i += 1;
      }
      row.add(cell.toString());
      cell.clear();
      rows.add(row);
      row = <String>[];
      continue;
    }
    cell.write(char);
  }

  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(row);
  }
  return rows;
}
