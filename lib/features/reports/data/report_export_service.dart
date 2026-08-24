import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'reports_data_source.dart';

class ReportExportService {
  Future<void> excel(ReportResult report, String filename) async {
    final bytes = _excelBytes(report);
    await FilePicker.platform.saveFile(fileName: '$filename.xlsx', bytes: bytes);
  }

  Future<void> pdf(ReportResult report, String filename) async {
    final document = pw.Document();
    final columns = _columns(report.rows);
    document.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      build: (_) => [
        pw.Text(report.type.label, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text('Generado: ${DateTime.now().toLocal()}'),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: columns,
          data: report.rows.map((row) => columns.map((key) => _text(row[key])).toList()).toList(),
        ),
      ],
    ));
    await Printing.layoutPdf(name: '$filename.pdf', onLayout: (_) => document.save());
  }

  Uint8List _excelBytes(ReportResult report) {
    final workbook = Excel.createExcel();
    workbook.delete('Sheet1');
    final sheet = workbook['Reporte'];
    sheet.appendRow([TextCellValue(report.type.label)]);
    sheet.appendRow([TextCellValue('Generado: ${DateTime.now().toLocal()}')]);
    final columns = _columns(report.rows);
    sheet.appendRow(columns.map(TextCellValue.new).toList());
    for (final row in report.rows) {
      sheet.appendRow(columns.map((key) => TextCellValue(_text(row[key]))).toList());
    }
    return Uint8List.fromList(workbook.encode() ?? const []);
  }

  List<String> _columns(List<Map<String, dynamic>> rows) => rows.isEmpty ? const [] : rows.first.keys.toList();
  static String _text(Object? value) => value is Map || value is List ? value.toString() : value?.toString() ?? '';
}
