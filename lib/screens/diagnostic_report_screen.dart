import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/notification_service.dart';

class DiagnosticReportScreen extends StatefulWidget {
  final String locale;

  const DiagnosticReportScreen({
    super.key,
    required this.locale,
  });

  @override
  State<DiagnosticReportScreen> createState() => _DiagnosticReportScreenState();
}

class _DiagnosticReportScreenState extends State<DiagnosticReportScreen> {
  final NotificationService _notificationService = NotificationService();
  bool _isLoading = true;
  String _report = '';

  bool get isHebrew => widget.locale == 'he';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final report = await _notificationService.generateDiagnosticReport();
      if (!mounted) return;
      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _report = 'Error generating report: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _report));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isHebrew ? 'הדו״ח הועתק ללוח' : 'Report copied to clipboard'),
        backgroundColor: const Color(0xFFE8B923),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isHebrew ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(
              isHebrew ? Icons.arrow_forward : Icons.arrow_back,
              color: const Color(0xFF1A1A1A),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            isHebrew ? 'דו״ח אבחון' : 'Diagnostic Report',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF1A1A1A)),
              onPressed: _load,
              tooltip: isHebrew ? 'רענן' : 'Refresh',
            ),
            IconButton(
              icon: const Icon(Icons.copy, color: Color(0xFF1A1A1A)),
              onPressed: _report.isEmpty ? null : _copy,
              tooltip: isHebrew ? 'העתק' : 'Copy',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFE8B923)),
              )
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _report,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        height: 1.25,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

