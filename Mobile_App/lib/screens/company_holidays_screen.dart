import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../providers/app_provider.dart';
import '../models/holiday.dart';
import '../utils/app_messages.dart';
import '../utils/file_saver.dart';

class CompanyHolidaysScreen extends StatefulWidget {
  const CompanyHolidaysScreen({super.key});

  @override
  State<CompanyHolidaysScreen> createState() => _CompanyHolidaysScreenState();
}

class _CompanyHolidaysScreenState extends State<CompanyHolidaysScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _parsedHolidays = [];
  bool _showParsedPreview = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHolidays();
    });
  }

  Future<void> _loadHolidays() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    await provider.fetchHolidays(year: DateTime.now().year);
  }

  Future<void> _downloadTemplate() async {
    try {
      final csvContent = "Date,Holiday Name\n"
          "2026-01-01,New Year's Day\n"
          "2026-01-26,Republic Day\n"
          "2026-08-15,Independence Day\n"
          "2026-10-02,Mahatma Gandhi Jayanti\n"
          "2026-12-25,Christmas Day\n";
      
      final bytes = utf8.encode(csvContent);
      
      await saveAndShareFile(
        Uint8List.fromList(bytes),
        'holidays_template.csv',
        shareText: 'HL Holidays Upload Template',
      );
      
      if (mounted) {
        AppMessages.showSuccess(context, 'Template downloaded successfully!');
      }
    } catch (e) {
      if (mounted) {
        AppMessages.showError(context, 'Failed to download template: $e');
      }
    }
  }

  Future<void> _uploadSheet() async {
    final picker = ImagePicker();
    // Use file picker approach
    try {
      final file = await picker.pickMedia();
      if (file == null) return;
      if (!mounted) return;

      setState(() => _isLoading = true);
      final provider = Provider.of<AppProvider>(context, listen: false);
      try {
        final parsed = await provider.parseHolidaySheet(file);
        if (mounted) {
          setState(() {
            _parsedHolidays = parsed;
            _showParsedPreview = true;
          });
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        AppMessages.showError(context, 'Failed to pick file: $e');
      }
    }
  }

  Future<void> _confirmBulkCreate() async {
    if (_parsedHolidays.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      await provider.bulkCreateHolidays(_parsedHolidays);
      setState(() {
        _parsedHolidays = [];
        _showParsedPreview = false;
      });
      if (mounted) {
        AppMessages.showSuccess(context, '${_parsedHolidays.length} holidays saved successfully!');
      }
    } catch (e) {
      if (mounted) {
        AppMessages.showError(context, 'Failed to save holidays: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addHolidayManually() async {
    DateTime? selectedDate;
    final nameController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            top: 0, left: 24, right: 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Add Company Holiday', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Holiday Name',
                  hintText: 'e.g. Republic Day, Diwali...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.celebration_rounded, color: Color(0xFF4F46E5)),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(primary: Color(0xFF4F46E5)),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) {
                    setSheetState(() => selectedDate = picked);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, color: Color(0xFF4F46E5), size: 20),
                      const SizedBox(width: 12),
                      Text(
                        selectedDate != null
                            ? DateFormat('dd MMM yyyy').format(selectedDate!)
                            : 'Select Date',
                        style: TextStyle(
                          color: selectedDate != null ? const Color(0xFF0F172A) : Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (selectedDate == null) {
                      AppMessages.showError(ctx, 'Please select a date');
                      return;
                    }
                    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate!);
                    final name = nameController.text.trim().isEmpty ? 'Company Holiday' : nameController.text.trim();
                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);
                    try {
                      final provider = Provider.of<AppProvider>(context, listen: false);
                      await provider.createHoliday(dateStr, name);
                      if (mounted) AppMessages.showSuccess(context, 'Holiday added!');
                    } catch (e) {
                      if (mounted) AppMessages.showError(context, 'Error: $e');
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Add Holiday', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteHoliday(Holiday holiday) async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Holiday', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Remove "${holiday.name}" from company holidays?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await provider.deleteHoliday(holiday.id);
      if (mounted) AppMessages.showSuccess(context, 'Holiday deleted');
    } catch (e) {
      if (mounted) AppMessages.showError(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final holidays = provider.holidays;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            centerTitle: false,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, size: 20, color: Color(0xFF0F172A)),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Company Holidays 🏖️', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                Text('Manage your company holiday calendar', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
              ],
            ),
            actions: [
              IconButton(
                onPressed: _loadHolidays,
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF4F46E5)),
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Upload Sheet Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.cloud_upload_outlined, color: Color(0xFF4F46E5), size: 20),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Import Holidays Sheet',
                                  style: TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Import a CSV or Excel sheet with holiday dates. Valid days will be added automatically to the directory.',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 11.5,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _uploadSheet,
                                    icon: const Icon(Icons.file_open_outlined, size: 14),
                                    label: const Text(
                                      'Choose File',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4F46E5),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 11),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _downloadTemplate,
                                    icon: const Icon(Icons.download_outlined, size: 14),
                                    label: const Text(
                                      'Get Template',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF4F46E5),
                                      side: const BorderSide(color: Color(0xFFC7D2FE), width: 1.5),
                                      padding: const EdgeInsets.symmetric(vertical: 11),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Parsed Preview
                      if (_showParsedPreview && _parsedHolidays.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_parsedHolidays.length} dates found — Review & Confirm',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ..._parsedHolidays.take(8).map((h) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF97316).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        h['date'] ?? '',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFF97316)),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        h['name'] ?? 'Company Holiday',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                              if (_parsedHolidays.length > 8)
                                Text(
                                  '+ ${_parsedHolidays.length - 8} more...',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => setState(() {
                                        _parsedHolidays = [];
                                        _showParsedPreview = false;
                                      }),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.grey,
                                        side: const BorderSide(color: Colors.grey),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _confirmBulkCreate,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF10B981),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: const Text('Save All', style: TextStyle(fontWeight: FontWeight.w800)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Company Holidays',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                          ),
                          TextButton.icon(
                            onPressed: _addHolidayManually,
                            icon: const Icon(Icons.add_rounded, size: 18, color: Color(0xFF4F46E5)),
                            label: const Text('Add Holiday', style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Holidays List
                      if (holidays.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Column(
                            children: [
                              const Text('🏖️', style: TextStyle(fontSize: 40)),
                              const SizedBox(height: 12),
                              const Text('No holidays set yet', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              const SizedBox(height: 4),
                              Text('Upload a holiday sheet or add holidays manually', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                            ],
                          ),
                        )
                      else
                        ...holidays.map((holiday) => _buildHolidayCard(holiday, provider)),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildHolidayCard(Holiday holiday, AppProvider provider) {
    final dateTime = DateTime.tryParse(holiday.date);
    final formatted = dateTime != null ? DateFormat('dd MMM yyyy, EEEE').format(dateTime) : holiday.date;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('🏖️', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      holiday.name,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatted,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              // Exceptions count badge
              if (holiday.exceptions.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${holiday.exceptions.length} exceptions',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                  ),
                ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onSelected: (val) async {
                  if (val == 'delete') {
                    _deleteHoliday(holiday);
                  } else if (val == 'exception') {
                    _showAddExceptionDialog(holiday, provider);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'exception',
                    child: Row(children: [
                      Icon(Icons.group_add_rounded, size: 18, color: Color(0xFF2563EB)),
                      SizedBox(width: 8),
                      Text('Add Exception'),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ]),
                  ),
                ],
              ),
            ],
          ),
          if (holiday.exceptions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: holiday.exceptions.map((ex) {
                final label = ex.teamName != null
                    ? '👥 ${ex.teamName}'
                    : '👤 ${ex.userName ?? 'User'}';
                return GestureDetector(
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Text('Remove Exception?'),
                        content: Text('Remove exception for "$label"?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        await provider.removeHolidayException(holiday.id, ex.id);
                        if (mounted) AppMessages.showSuccess(context, 'Exception removed');
                      } catch (e) {
                        if (mounted) AppMessages.showError(context, 'Error: $e');
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
                        const SizedBox(width: 4),
                        const Icon(Icons.close_rounded, size: 12, color: Color(0xFF10B981)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddExceptionDialog(Holiday holiday, AppProvider provider) {
    int? selectedType = 0; // 0 = team, 1 = employee
    int? selectedTeamId;
    int? selectedUserId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            top: 0, left: 24, right: 24,
          ),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text(
                  'Add Exception for "${holiday.name}"',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                Text('Allow a specific team or employee to work on this holiday.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setSheetState(() { selectedType = 0; selectedUserId = null; }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: selectedType == 0 ? const Color(0xFF4F46E5).withValues(alpha: 0.1) : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: selectedType == 0 ? const Color(0xFF4F46E5) : Colors.grey.shade200, width: selectedType == 0 ? 2 : 1),
                          ),
                          child: const Column(children: [
                            Text('👥', style: TextStyle(fontSize: 24)),
                            SizedBox(height: 4),
                            Text('Team', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setSheetState(() { selectedType = 1; selectedTeamId = null; }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: selectedType == 1 ? const Color(0xFF4F46E5).withValues(alpha: 0.1) : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: selectedType == 1 ? const Color(0xFF4F46E5) : Colors.grey.shade200, width: selectedType == 1 ? 2 : 1),
                          ),
                          child: const Column(children: [
                            Text('👤', style: TextStyle(fontSize: 24)),
                            SizedBox(height: 4),
                            Text('Employee', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                          ]),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (selectedType == 0) ...[
                  const Text('Select Team', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                  const SizedBox(height: 8),
                  ...provider.teams.map((team) {
                    final id = team['id'] as int?;
                    final name = team['name'] as String? ?? 'Team';
                    final isSelected = selectedTeamId == id;
                    return GestureDetector(
                      onTap: () => setSheetState(() => selectedTeamId = id),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF4F46E5).withValues(alpha: 0.08) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isSelected ? const Color(0xFF4F46E5) : Colors.grey.shade200, width: isSelected ? 1.5 : 1),
                        ),
                        child: Row(
                          children: [
                            const Text('👥', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Text(name, style: TextStyle(fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600, color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF374151))),
                            if (isSelected) ...[
                              const Spacer(),
                              const Icon(Icons.check_rounded, size: 16, color: Color(0xFF4F46E5)),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ] else ...[
                  const Text('Select Employee', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                  const SizedBox(height: 8),
                  ...provider.employees.map((emp) {
                    final isSelected = selectedUserId == emp.id;
                    return GestureDetector(
                      onTap: () => setSheetState(() => selectedUserId = emp.id),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF4F46E5).withValues(alpha: 0.08) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isSelected ? const Color(0xFF4F46E5) : Colors.grey.shade200, width: isSelected ? 1.5 : 1),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(radius: 14, backgroundColor: const Color(0xFF4F46E5), child: Text(emp.name[0].toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white))),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(emp.name, style: TextStyle(fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600, color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF374151), fontSize: 13)),
                                  Text(emp.department ?? emp.email, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                ],
                              ),
                            ),
                            if (isSelected) const Icon(Icons.check_rounded, size: 16, color: Color(0xFF4F46E5)),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (selectedType == 0 && selectedTeamId == null) {
                        AppMessages.showError(ctx, 'Please select a team');
                        return;
                      }
                      if (selectedType == 1 && selectedUserId == null) {
                        AppMessages.showError(ctx, 'Please select an employee');
                        return;
                      }
                      Navigator.pop(ctx);
                      setState(() => _isLoading = true);
                      try {
                        await provider.addHolidayException(holiday.id, {
                          if (selectedType == 0) 'teamId': selectedTeamId,
                          if (selectedType == 1) 'userId': selectedUserId,
                        });
                        if (mounted) AppMessages.showSuccess(context, 'Exception added successfully');
                      } catch (e) {
                        if (mounted) AppMessages.showError(context, 'Error: $e');
                      } finally {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Add Exception', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
