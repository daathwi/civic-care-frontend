import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_theme.dart';
import '../models/complaint.dart';
import '../providers/complaint_provider.dart';
import '../providers/departments_provider.dart';
import '../widgets/voice_recording_widget.dart';

const _kTotalSteps = 3;

class AddComplaintFlow extends ConsumerStatefulWidget {
  const AddComplaintFlow({super.key});

  @override
  ConsumerState<AddComplaintFlow> createState() => _AddComplaintFlowState();
}

class _AddComplaintFlowState extends ConsumerState<AddComplaintFlow> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  int _currentStep = 0; // 0 = Evidence, 1 = Dept/Category, 2 = Description

  File? _image;
  File? _audioFile;
  double? _lat;
  double? _lng;
  String _address = '';
  bool _isCapturing = false;

  String? _selectedDepartmentId;
  String? _selectedCategoryId;
  ComplaintPriority _selectedPriority = ComplaintPriority.medium;
  bool _isSensitive = false;
  bool _isSubmitting = false;

  Future<void> _captureImageAndLocation() async {
    setState(() => _isCapturing = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permission denied';
        }
      }
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
      );
      if (pickedFile == null) {
        setState(() => _isCapturing = false);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      setState(() {
        _image = File(pickedFile.path);
        _lat = position.latitude;
        _lng = position.longitude;
        _address =
            '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        _isCapturing = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() => _isCapturing = false);
    }
  }

  void _goNext() {
    if (_currentStep == 0) {
      if (_image == null || _lat == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please capture a photo first to lock your location.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      setState(() => _currentStep = 1);
      return;
    }
    if (_currentStep == 1) {
      setState(() => _currentStep = 2);
      return;
    }
    _showSubmissionPreview();
  }

  void _showSubmissionPreview() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Ready to Submit?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please review your report details before proceeding.',
              style: GoogleFonts.inter(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            _previewItem(Icons.title, 'Title', _titleController.text),
            const SizedBox(height: 12),
            _previewItem(
              Icons.location_on,
              'Address',
              _address.isNotEmpty ? _address : 'GPS Location Locked',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Review',
              style: GoogleFonts.inter(color: AppTheme.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submit();
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Confirm & Submit'),
          ),
        ],
      ),
    );
  }

  Widget _previewItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              Text(
                value.isEmpty ? 'Not specified' : value,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _goBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.maybePop(context);
    }
  }

  Future<void> _submit() async {
    if (_image == null || _lat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please go back and capture a photo first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);
    String? wardId;
    String? detectedWardId;
    String? detectedWardName;
    try {
      if (_lat != null && _lng != null) {
        try {
          final ward = await ref
              .read(wardsRepositoryProvider)
              .lookupByCoordinates(_lat!, _lng!);
          if (ward != null) {
            detectedWardId = ward.id;
            detectedWardName = ward.name;
            debugPrint(
              'Ward resolved: $detectedWardName (ID: $detectedWardId)',
            );
            wardId = detectedWardId; // Assign to wardId for submission
          } else {
            debugPrint(
              'Ward not found for coordinates: $_lat, $_lng - Backend fallback will resolve it.',
            );
          }
        } catch (e) {
          debugPrint('Ward resolution error: $e');
        }
      }
    } catch (_) {
      // Proceed without ward_id
    }

    final departments = ref.read(departmentsProvider).valueOrNull ?? [];
    String deptName = "General";
    if (_selectedDepartmentId != null) {
      final dept = departments.firstWhere(
        (d) => d['id'] == _selectedDepartmentId,
        orElse: () => <String, dynamic>{},
      );
      if (dept.isNotEmpty) deptName = dept['name']?.toString() ?? deptName;
    }

    final categoriesAsync = ref.read(
      categoriesForDepartmentProvider(_selectedDepartmentId),
    );
    final categories = categoriesAsync.valueOrNull ?? [];
    String catName = "Grievance";
    if (_selectedCategoryId != null) {
      final cat = categories.firstWhere(
        (c) => c['id'] == _selectedCategoryId,
        orElse: () => <String, dynamic>{},
      );
      if (cat.isNotEmpty) catName = cat['name']?.toString() ?? catName;
    }

    String title = _titleController.text.trim();
    String? description = _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim();

    if (_audioFile != null && title.isEmpty) {
      title = "$deptName - $catName";
      description ??= "Voice recording attached.";
    }

    final notifier = ref.read(complaintProvider.notifier);
    final err = await notifier.addComplaint(
      title: title,
      description: description,
      lat: _lat!,
      lng: _lng!,
      address: _address.isEmpty ? null : _address,
      priority: _selectedPriority,
      departmentId: _selectedDepartmentId,
      categoryId: _selectedCategoryId,
      wardId: wardId,
      photoFile: _image,
      audioFile: _audioFile,
      isSensitive: _isSensitive,
    );

    if (!mounted) return;
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (err != null) {
      if (err.toLowerCase().contains('spam')) {
        _showSpamAlert(err);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red),
        );
      }
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Grievance reported successfully!'),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  void _showSpamAlert(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with warning icon
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF5F5),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: AppTheme.error,
                      size: 48,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  children: [
                    Text(
                      'Submission Flagged',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'I Understand',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.sizeOf(context).width >= 800;
    return Scaffold(
      backgroundColor: AppTheme.surfaceScaffold,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            backgroundColor: AppTheme.surfaceScaffold,
            elevation: 0,
            scrolledUnderElevation: 0,
            pinned: true,
            expandedHeight: 120,
            collapsedHeight: 60,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: _goBack,
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(60, 0, 20, 12),
              title: Text(
                'Submit your complaint,\nWe will get back to you',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: AppTheme.textPrimary,
                  height: 1.1,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _StepIndicator(
              currentStep: _currentStep,
              totalSteps: _kTotalSteps,
            ),
          ),
        ],
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isWeb ? 520 : double.infinity,
              ),
              child: Form(key: _formKey, child: _buildStepContent(isWeb)),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildStepContent(bool isWeb) {
    switch (_currentStep) {
      case 0:
        return _Step1Evidence(
          isWeb: isWeb,
          image: _image,
          lat: _lat,
          lng: _lng,
          isCapturing: _isCapturing,
          onCapture: _captureImageAndLocation,
        );
      case 1:
        return _Step2DepartmentCategory(
          selectedDepartmentId: _selectedDepartmentId,
          selectedCategoryId: _selectedCategoryId,
          selectedPriority: _selectedPriority,
          onDepartmentChanged: (id) => setState(() {
            _selectedDepartmentId = id;
            _selectedCategoryId = null;
          }),
          onCategoryChanged: (id) => setState(() => _selectedCategoryId = id),
          onPriorityChanged: (p) => setState(() => _selectedPriority = p),
        );
      case 2:
        return _Step3Description(
          titleController: _titleController,
          descriptionController: _descriptionController,
          audioFile: _audioFile,
          onAudioChanged: (file) => setState(() => _audioFile = file),
          isSensitive: _isSensitive,
          onSensitiveChanged: (v) => setState(() => _isSensitive = v),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBottomBar() {
    final isFirst = _currentStep == 0;
    final isLast = _currentStep == _kTotalSteps - 1;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceScaffold.withValues(alpha: 0.8),
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          if (!isFirst)
            Expanded(
              flex: 1,
              child: TextButton(
                onPressed: _goBack,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Back',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          if (!isFirst) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _goNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isLast ? 'Submit Report' : 'Continue',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _StepIndicator({required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'STEP ${currentStep + 1} OF $totalSteps',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                '${((currentStep + 1) / totalSteps * 100).toInt()}% COMPLETE',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(totalSteps, (i) {
              final isCompleted = i < currentStep;
              final isCurrent = i == currentStep;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i == totalSteps - 1 ? 0 : 6),
                  height: 6,
                  decoration: BoxDecoration(
                    color: isCompleted || isCurrent
                        ? AppTheme.primary
                        : AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _Step1Evidence extends StatelessWidget {
  final bool isWeb;
  final File? image;
  final double? lat;
  final double? lng;
  final bool isCapturing;
  final VoidCallback onCapture;

  const _Step1Evidence({
    required this.isWeb,
    required this.image,
    required this.lat,
    required this.lng,
    required this.isCapturing,
    required this.onCapture,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInfoSection(),
          const SizedBox(height: 24),
          _buildCaptureSection(),
          if (lat != null) ...[
            const SizedBox(height: 24),
            _buildLocationSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Capture Evidence',
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Take a photo of the issue. Your location will be locked automatically for verification.',
          style: GoogleFonts.inter(
            fontSize: 15,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildCaptureSection() {
    return Container(
      decoration: AppTheme.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          GestureDetector(
            onTap: isCapturing ? null : onCapture,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: isWeb ? 320 : 280,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                image: image != null
                    ? DecorationImage(
                        image: FileImage(image!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: image == null
                  ? Center(
                      child: isCapturing
                          ? const CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.primary,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 40,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Tap to open camera',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'A photo is required for reports',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                    )
                  : Container(
                      padding: const EdgeInsets.all(12),
                      alignment: Alignment.topRight,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: IconButton(
                          icon: const Icon(
                            Icons.refresh_rounded,
                            color: Colors.white,
                          ),
                          onPressed: onCapture,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE1F5FE),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: Color(0xFF0288D1),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Location Locked',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF4CAF50),
            size: 24,
          ),
        ],
      ),
    );
  }
}

class _Step2DepartmentCategory extends ConsumerWidget {
  final String? selectedDepartmentId;
  final String? selectedCategoryId;
  final ComplaintPriority selectedPriority;
  final ValueChanged<String?> onDepartmentChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<ComplaintPriority> onPriorityChanged;

  const _Step2DepartmentCategory({
    required this.selectedDepartmentId,
    required this.selectedCategoryId,
    required this.selectedPriority,
    required this.onDepartmentChanged,
    required this.onCategoryChanged,
    required this.onPriorityChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final departmentsAsync = ref.watch(departmentsProvider);
    final categoriesAsync = ref.watch(
      categoriesForDepartmentProvider(selectedDepartmentId),
    );
    final departments = departmentsAsync.valueOrNull ?? [];
    final categories = categoriesAsync.valueOrNull ?? [];
    final deptLoading = departmentsAsync.isLoading;
    final catLoading =
        ref.watch(allCategoriesProvider).isLoading &&
        selectedDepartmentId != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInfoSection(),
          const SizedBox(height: 24),
          _buildFormSection(departments, categories, deptLoading, catLoading),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Issue Details',
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Categorize your report to ensure it reaches the correct department quickly.',
          style: GoogleFonts.inter(
            fontSize: 15,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFormSection(
    List<dynamic> departments,
    List<dynamic> categories,
    bool deptLoading,
    bool catLoading,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDropdown(
            label: 'Department',
            value: selectedDepartmentId,
            hint: 'Select department',
            icon: Icons.business_rounded,
            items: departments,
            isLoading: deptLoading,
            onChanged: onDepartmentChanged,
          ),
          const SizedBox(height: 20),
          _buildDropdown(
            label: 'Category',
            value: selectedCategoryId,
            hint: selectedDepartmentId == null
                ? 'Select department first'
                : 'Select category',
            icon: Icons.category_rounded,
            items: categories,
            isLoading: catLoading,
            enabled: selectedDepartmentId != null,
            onChanged: onCategoryChanged,
          ),
          const SizedBox(height: 24),
          _buildPrioritySelector(),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required String hint,
    required IconData icon,
    required List<dynamic> items,
    required bool isLoading,
    bool enabled = true,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppTheme.primary, size: 20),
            filled: true,
            fillColor: AppTheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.border),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          hint: Text(
            isLoading ? 'Loading...' : hint,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item['id']?.toString(),
              child: Text(
                item['name']?.toString() ?? '',
                style: GoogleFonts.inter(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: enabled && !isLoading ? onChanged : null,
        ),
      ],
    );
  }

  Widget _buildPrioritySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'URGENCY',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _PriorityButton(
              label: 'Low',
              color: const Color(0xFF4CAF50),
              isSelected: selectedPriority == ComplaintPriority.low,
              onTap: () => onPriorityChanged(ComplaintPriority.low),
            ),
            const SizedBox(width: 8),
            _PriorityButton(
              label: 'Normal',
              color: const Color(0xFFFF9800),
              isSelected: selectedPriority == ComplaintPriority.medium,
              onTap: () => onPriorityChanged(ComplaintPriority.medium),
            ),
            const SizedBox(width: 8),
            _PriorityButton(
              label: 'High',
              color: const Color(0xFFF44336),
              isSelected: selectedPriority == ComplaintPriority.high,
              onTap: () => onPriorityChanged(ComplaintPriority.high),
            ),
          ],
        ),
      ],
    );
  }
}

class _PriorityButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _PriorityButton({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : color.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }
}

class _Step3Description extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final File? audioFile;
  final ValueChanged<File?> onAudioChanged;
  final bool isSensitive;
  final ValueChanged<bool> onSensitiveChanged;

  const _Step3Description({
    required this.titleController,
    required this.descriptionController,
    required this.audioFile,
    required this.onAudioChanged,
    required this.isSensitive,
    required this.onSensitiveChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInfoSection(),
          const SizedBox(height: 24),
          _buildFormSection(),
          const SizedBox(height: 24),
          _buildSensitivityToggle(),
          const SizedBox(height: 24),
          VoiceRecordingWidget(onRecordingComplete: onAudioChanged),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Describe Issue',
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          audioFile != null
              ? 'Your voice recording is attached. You can also add a title/description or leave them for us to fill.'
              : 'Add a title and description. You can also record a voice message for more context.',
          style: GoogleFonts.inter(
            fontSize: 15,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFormSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTextField(
            label: 'TITLE',
            controller: titleController,
            hint: 'E.g., Broken street light',
            icon: Icons.title_rounded,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            label: 'DESCRIPTION',
            controller: descriptionController,
            hint: 'Provide more details...',
            icon: Icons.description_rounded,
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: GoogleFonts.inter(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
            ),
            prefixIcon: Icon(icon, color: AppTheme.primary, size: 20),
            filled: true,
            fillColor: AppTheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.border),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          validator: (v) {
            if (label == 'TITLE' &&
                v != null &&
                v.trim().isEmpty &&
                audioFile == null) {
              return 'Title is required';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSensitivityToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: AppTheme.cardDecoration(),
      child: SwitchListTile.adaptive(
        value: isSensitive,
        onChanged: onSensitiveChanged,
        activeTrackColor: AppTheme.primary,
        contentPadding: EdgeInsets.zero,
        secondary: Icon(
          isSensitive ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          color: isSensitive ? Colors.orange : AppTheme.primary,
        ),
        title: Text(
          'Sensitive Content',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: Text(
          'Mark if the image contains graphic or disturbing content.',
          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ),
    );
  }
}
