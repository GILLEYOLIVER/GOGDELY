// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;

/// Opens a print sheet with only the QR. The browser's Print dialog can save
/// it as PDF; no Auth token or private store data is included in the sheet.
bool openPrintableTableQr({
  required String storeName,
  required int tableNumber,
  required String url,
  required List<dynamic> matrix,
}) {
  if (matrix.isEmpty) return false;
  final escape = const HtmlEscape(HtmlEscapeMode.element);
  final cells = StringBuffer();
  for (var y = 0; y < matrix.length; y++) {
    final row = matrix[y] as List<dynamic>;
    for (var x = 0; x < row.length; x++) {
      if (row[x] == true) {
        cells.write('<rect x="$x" y="$y" width="1" height="1"/>');
      }
    }
  }
  final side = matrix.length;
  final safeName = escape.convert(storeName);
  final safeUrl = escape.convert(url);
  final page = '''<!doctype html><html lang="pt-BR"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>GOGDELY · $safeName · Mesa $tableNumber</title>
<style>@page{size:A4;margin:18mm}body{font:16px Arial,sans-serif;color:#151b2b;text-align:center}
main{max-width:130mm;margin:20mm auto;border:1px solid #dce4f2;border-radius:16px;padding:15mm}
h1{font-size:25px;margin:0 0 8mm}h2{font-size:20px;margin:0 0 8mm;color:#2563eb}
svg{width:65mm;height:65mm;shape-rendering:crispEdges}p{overflow-wrap:anywhere;font-size:12px}
button{margin:20px;padding:12px 20px}@media print{button{display:none}main{margin:0 auto}}</style>
</head><body><button onclick="window.print()">Imprimir ou salvar PDF</button><main>
<h1>$safeName</h1><h2>Mesa $tableNumber</h2>
<svg viewBox="0 0 $side $side" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="QR do cardápio da mesa $tableNumber">
<rect width="$side" height="$side" fill="white"/><g fill="#151b2b">$cells</g></svg>
<p>Abra a câmera do celular para ver o cardápio.</p><p>$safeUrl</p>
</main></body></html>''';
  final blob = html.Blob([page], 'text/html;charset=utf-8');
  final objectUrl = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(objectUrl, '_blank');
  Future.delayed(const Duration(minutes: 1), () => html.Url.revokeObjectUrl(objectUrl));
  return true;
}
