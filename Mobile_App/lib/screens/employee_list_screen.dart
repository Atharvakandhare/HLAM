import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/app_provider.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'add_employee_screen.dart';
import '../widgets/app_avatar.dart';


class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  String _searchQuery = '';
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppProvider>(context, listen: false).fetchEmployees();
    });
  }

  Future<void> _loadCurrentUser() async {
    final user = await AuthService().getUser();
    if (mounted) setState(() => _currentUser = user);
  }

  void _showBulkUploadDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (BuildContext sheetContext) {
        bool isLoading = false;
        String? errorMessage;
        Map<String, dynamic>? resultReport;
        PlatformFile? selectedFile;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Future<void> downloadTemplate() async {
              setSheetState(() {
                isLoading = true;
                errorMessage = null;
              });
              try {
                final bytes = await ApiService().downloadEmployeeTemplate();
                final tempDir = await getTemporaryDirectory();
                final tempFile = File('${tempDir.path}/employees_template.xlsx');
                await tempFile.writeAsBytes(bytes);
                await SharePlus.instance.share(
                  ShareParams(
                    files: [XFile(tempFile.path)],
                    text: 'HLAM – Bulk Employee Upload Template',
                  ),
                );
                setSheetState(() => isLoading = false);
              } catch (e) {
                setSheetState(() {
                  isLoading = false;
                  errorMessage = 'Download failed. Please check your connection.';
                });
              }
            }

            Future<void> pickFile() async {
              try {
                final result = await FilePicker.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['xlsx', 'xls', 'csv'],
                  withData: true,
                );
                if (result != null && result.files.isNotEmpty) {
                  setSheetState(() {
                    selectedFile = result.files.first;
                    errorMessage = null;
                    resultReport = null;
                  });
                }
              } catch (e) {
                setSheetState(() => errorMessage = 'Could not open file picker: $e');
              }
            }

            Future<void> uploadFile() async {
              if (selectedFile == null) {
                setSheetState(() => errorMessage = 'Please select a file first.');
                return;
              }
              final bytes = selectedFile!.bytes ??
                  (selectedFile!.path != null
                      ? await File(selectedFile!.path!).readAsBytes()
                      : null);
              if (bytes == null) {
                setSheetState(() => errorMessage = 'Could not read the file. Try again.');
                return;
              }
              setSheetState(() {
                isLoading = true;
                errorMessage = null;
                resultReport = null;
              });
              try {
                final report = await ApiService().bulkUploadEmployees(bytes, selectedFile!.name);
                setSheetState(() {
                  isLoading = false;
                  resultReport = report;
                  selectedFile = null;
                });
                if ((report['insertedCount'] ?? 0) > 0 && ctx.mounted) {
                  Provider.of<AppProvider>(ctx, listen: false).fetchEmployees();
                }
              } catch (e) {
                setSheetState(() {
                  isLoading = false;
                  errorMessage = e.toString();
                });
              }
            }

            final int inserted = resultReport?['insertedCount'] ?? 0;
            final int failed = resultReport?['failedCount'] ?? 0;
            final List errors = (resultReport?['errors'] as List?) ?? [];
            final bool hasResult = resultReport != null;

            return DraggableScrollableSheet(
              initialChildSize: 0.88,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (_, scrollController) {
                return SafeArea(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: Column(
                    children: [
                      // ── Drag Handle ──────────────────────────────────
                      const SizedBox(height: 12),
                      Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),

                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              // ── Gradient Header Banner ────────────────
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF4F46E5)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Icon(
                                        Icons.table_chart_rounded,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Bulk Employee Upload',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 18,
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Register multiple employees at once using an Excel sheet.',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.8),
                                              fontSize: 12,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: isLoading ? null : () => Navigator.pop(sheetContext),
                                      icon: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              if (!hasResult) ...[ // ── Upload Flow ─────────

                                // ── Step 1: Download Template ─────────────
                                _buildStepCard(
                                  step: '1',
                                  title: 'Download Template',
                                  subtitle: 'Get the official Excel template with all required columns.',
                                  icon: Icons.download_rounded,
                                  iconColor: const Color(0xFF0EA5E9),
                                  bgColor: const Color(0xFFEFF6FF),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF2563EB),
                                        side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(vertical: 13),
                                      ),
                                      onPressed: isLoading ? null : downloadTemplate,
                                      icon: const Icon(Icons.download_rounded, size: 18),
                                      label: const Text(
                                        'Download employees_template.xlsx',
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // ── Step 2: Fill & Select File ────────────
                                _buildStepCard(
                                  step: '2',
                                  title: 'Select Filled Spreadsheet',
                                  subtitle: 'Fill the template and pick the file from your device.',
                                  icon: Icons.folder_open_rounded,
                                  iconColor: const Color(0xFF8B5CF6),
                                  bgColor: const Color(0xFFF5F3FF),
                                  child: Column(
                                    children: [
                                      // File picker tap area
                                      GestureDetector(
                                        onTap: isLoading ? null : pickFile,
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                                          decoration: BoxDecoration(
                                            color: selectedFile != null
                                                ? const Color(0xFFEFF6FF)
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(
                                              color: selectedFile != null
                                                  ? const Color(0xFF2563EB)
                                                  : const Color(0xFFE2E8F0),
                                              width: selectedFile != null ? 2 : 1.5,
                                              style: selectedFile != null
                                                  ? BorderStyle.solid
                                                  : BorderStyle.solid,
                                            ),
                                          ),
                                          child: selectedFile == null
                                              ? Column(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.all(12),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(
                                                        Icons.upload_file_rounded,
                                                        color: Color(0xFF8B5CF6),
                                                        size: 28,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 10),
                                                    const Text(
                                                      'Tap to browse files',
                                                      style: TextStyle(
                                                        color: Color(0xFF1E293B),
                                                        fontWeight: FontWeight.w700,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    const Text(
                                                      '.xlsx  •  .xls  •  .csv',
                                                      style: TextStyle(
                                                        color: Color(0xFF94A3B8),
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              : Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.all(10),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(10),
                                                      ),
                                                      child: const Icon(
                                                        Icons.table_chart_rounded,
                                                        color: Color(0xFF2563EB),
                                                        size: 22,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            selectedFile!.name,
                                                            style: const TextStyle(
                                                              color: Color(0xFF0F172A),
                                                              fontWeight: FontWeight.w700,
                                                              fontSize: 13,
                                                            ),
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                          const SizedBox(height: 2),
                                                          Text(
                                                            '${(selectedFile!.size / 1024).toStringAsFixed(1)} KB',
                                                            style: const TextStyle(
                                                              color: Color(0xFF64748B),
                                                              fontSize: 11,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    GestureDetector(
                                                      onTap: () => setSheetState(() {
                                                        selectedFile = null;
                                                        errorMessage = null;
                                                      }),
                                                      child: const Icon(Icons.cancel_rounded, color: Color(0xFF94A3B8), size: 22),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // ── Step 3: Upload ────────────────────────
                                _buildStepCard(
                                  step: '3',
                                  title: 'Register Employees',
                                  subtitle: 'Upload the spreadsheet to register all employees in your company.',
                                  icon: Icons.cloud_upload_rounded,
                                  iconColor: const Color(0xFF10B981),
                                  bgColor: const Color(0xFFECFDF5),
                                  child: Column(
                                    children: [
                                      // Info pill
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFFFDE68A)),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.lock_outline_rounded, color: Color(0xFFD97706), size: 16),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'All employees will be assigned to your company automatically.',
                                                style: TextStyle(color: Color(0xFFD97706), fontSize: 11, fontWeight: FontWeight.w500),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 50,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: selectedFile != null
                                                ? const Color(0xFF2563EB)
                                                : const Color(0xFFCBD5E1),
                                            foregroundColor: Colors.white,
                                            elevation: selectedFile != null ? 2 : 0,
                                            shadowColor: const Color(0xFF2563EB).withValues(alpha: 0.3),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                          ),
                                          onPressed: (selectedFile != null && !isLoading) ? uploadFile : null,
                                          icon: const Icon(Icons.rocket_launch_rounded, size: 20),
                                          label: const Text(
                                            'Upload & Register',
                                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.2),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[ // ── Result View ───────────────────

                                // Success / Failure summary card
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: inserted > 0
                                          ? [const Color(0xFF065F46), const Color(0xFF10B981)]
                                          : [const Color(0xFF7F1D1D), const Color(0xFFEF4444)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (inserted > 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444))
                                            .withValues(alpha: 0.3),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        inserted > 0 ? Icons.check_circle_rounded : Icons.error_rounded,
                                        color: Colors.white,
                                        size: 48,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        inserted > 0 ? 'Upload Complete!' : 'Upload Failed',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 20,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildStatPill(
                                              value: '$inserted',
                                              label: 'Registered',
                                              icon: Icons.person_add_rounded,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _buildStatPill(
                                              value: '$failed',
                                              label: 'Failed',
                                              icon: Icons.person_remove_rounded,
                                              color: Colors.white.withValues(alpha: 0.85),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Error detail list
                                if (errors.isNotEmpty) ...[
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFFECACA)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFEE2E2),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 16),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                '${errors.length} Row${errors.length > 1 ? 's' : ''} Had Issues',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFFDC2626),
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Divider(height: 1, color: Color(0xFFFECACA)),
                                        ListView.separated(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          padding: const EdgeInsets.all(12),
                                          itemCount: errors.length,
                                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                                          itemBuilder: (ctx, i) => Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFF5F5),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Padding(
                                                  padding: EdgeInsets.only(top: 2),
                                                  child: Icon(Icons.circle, size: 6, color: Color(0xFFEF4444)),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    errors[i].toString(),
                                                    style: const TextStyle(
                                                      color: Color(0xFF7F1D1D),
                                                      fontSize: 12,
                                                      height: 1.4,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Action buttons after result
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF2563EB),
                                          side: const BorderSide(color: Color(0xFF2563EB)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          padding: const EdgeInsets.symmetric(vertical: 13),
                                        ),
                                        onPressed: () => setSheetState(() {
                                          resultReport = null;
                                          selectedFile = null;
                                          errorMessage = null;
                                        }),
                                        icon: const Icon(Icons.upload_rounded, size: 18),
                                        label: const Text('Upload Another', style: TextStyle(fontWeight: FontWeight.w700)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF2563EB),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          padding: const EdgeInsets.symmetric(vertical: 13),
                                        ),
                                        onPressed: () => Navigator.pop(sheetContext),
                                        icon: const Icon(Icons.done_rounded, size: 18),
                                        label: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              // Loading overlay content
                              if (isLoading) ...[
                                const SizedBox(height: 24),
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      const SizedBox(
                                        width: 48,
                                        height: 48,
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                                          strokeWidth: 3,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Processing...',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        selectedFile != null
                                            ? 'Validating and registering employees from ${selectedFile!.name}'
                                            : 'Please wait a moment...',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 12,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Error banner
                              if (errorMessage != null && !isLoading) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFFECACA)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          errorMessage!,
                                          style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStepCard({
    required String step,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'STEP $step',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2563EB),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 22)),
              Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final allEmployees = provider.employees;
    final employees = _searchQuery.isEmpty
        ? allEmployees
        : allEmployees
            .where((e) =>
                e.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (e.employeeId ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (e.department ?? '').toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Employees',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_currentUser != null &&
              (_currentUser!.role == 'system_admin' || _currentUser!.role == 'company_admin'))
            IconButton(
              icon: const Icon(Icons.upload_file_rounded, color: Color(0xFF2563EB)),
              tooltip: 'Bulk Upload Employees',
              onPressed: () => _showBulkUploadDialog(context),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search employees...',
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF2563EB)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ),
            // Count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    '${employees.length} ${employees.length == 1 ? 'member' : 'members'}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // List
            Expanded(
              child: employees.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('No employees found',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: employees.length,
                      itemBuilder: (context, index) => _buildEmployeeCard(employees[index], provider),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/add_employee'),
        backgroundColor: const Color(0xFF2563EB),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Add Employee', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmployeeCard(User emp, AppProvider provider) {
    // Detect if this card is a cross-company admin (system_admin viewing other companies' company_admin)
    final bool isCrossCompany = _currentUser != null &&
        emp.companyId != null &&
        _currentUser!.companyId != null &&
        emp.companyId != _currentUser!.companyId;

    Widget avatar = AppAvatar(
      radius: 26,
      backgroundColor: isCrossCompany
          ? const Color(0xFF7C3AED).withValues(alpha: 0.1)
          : const Color(0xFF2563EB).withValues(alpha: 0.1),
      imageUrl: emp.profilePicture != null && emp.profilePicture!.isNotEmpty
          ? '${ApiService.baseUrl.replaceAll('/api', '')}${emp.profilePicture}'
          : null,
      fallback: Text(
        emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: isCrossCompany ? const Color(0xFF7C3AED) : const Color(0xFF2563EB),
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  emp.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.badge_outlined, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      emp.employeeId ?? 'N/A',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.business_outlined, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        emp.department ?? 'N/A',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                // Company name shown for cross-company admins (system_admin sees other companies' company_admins)
                if (isCrossCompany && emp.companyName != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.domain_rounded, size: 13, color: Color(0xFF7C3AED)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          emp.companyName!,
                          style: const TextStyle(color: Color(0xFF7C3AED), fontSize: 11, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: emp.isActive
                            ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        emp.isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: emp.isActive ? const Color(0xFF4CAF50) : Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isCrossCompany
                            ? const Color(0xFF7C3AED).withValues(alpha: 0.08)
                            : const Color(0xFF2563EB).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        emp.role.toUpperCase().replaceAll('_', ' '),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isCrossCompany ? const Color(0xFF7C3AED) : const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                    if (isCrossCompany) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.2)),
                        ),
                        child: const Text(
                          'OTHER CO.',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB), size: 22),
            // system_admin cannot edit company_admin from other companies via mobile (backend enforces)
            onPressed: isCrossCompany ? null : () async {
              final appProvider = Provider.of<AppProvider>(context, listen: false);
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddEmployeeScreen(employee: emp),
                ),
              );
              appProvider.fetchEmployees();
            },
          ),
          const SizedBox(width: 12),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              Icons.delete_outline,
              color: isCrossCompany ? Colors.grey.shade300 : Colors.redAccent,
              size: 22,
            ),
            onPressed: isCrossCompany ? null : () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Delete Employee'),
                  content: Text('Are you sure you want to delete ${emp.name}?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await provider.deleteEmployee(emp.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
