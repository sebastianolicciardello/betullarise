import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../model/screen_time_rule.dart';
import '../../provider/screen_time_provider.dart';
import '../../services/ui/snackbar_service.dart';
import 'widgets/app_selector_widget.dart';

class CreateRulePage extends StatefulWidget {
  const CreateRulePage({super.key});

  @override
  State<CreateRulePage> createState() => _CreateRulePageState();
}

class _CreateRulePageState extends State<CreateRulePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _timeLimitController = TextEditingController();
  final _penaltyController = TextEditingController();

  List<String> _selectedPackages = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _timeLimitController.dispose();
    _penaltyController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPackages.isEmpty) {
      SnackbarService.showErrorSnackbar(
        context,
        'Select at least one app for the rule',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final rule = ScreenTimeRule(
        name: _nameController.text.trim(),
        appPackages: _selectedPackages,
        dailyTimeLimitMinutes: int.parse(_timeLimitController.text),
        penaltyPerMinuteExtra: -double.parse(_penaltyController.text),
        isActive: true,
        createdTime: DateTime.now().millisecondsSinceEpoch,
        updatedTime: DateTime.now().millisecondsSinceEpoch,
      );

      final screenTimeProvider = Provider.of<ScreenTimeProvider>(
        context,
        listen: false,
      );

      final success = await screenTimeProvider.addRule(rule);

      if (success && context.mounted) {
        SnackbarService.showSuccessSnackbar(
          context,
          'Rule "${rule.name}" created successfully!',
        );

        if (context.mounted) {
          Navigator.of(context).pop();
        }
      } else if (context.mounted) {
        SnackbarService.showErrorSnackbar(context, 'Error creating the rule');
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarService.showErrorSnackbar(context, 'Error: $e');
      }
    } finally {
      if (context.mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Create Rule',
          style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rule name
              Text(
                'Rule Name',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 8.h),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'e.g. CHAT, SOCIAL, GAMES...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a name for the rule';
                  }
                  if (value.trim().length < 2) {
                    return 'The name must be at least 2 characters';
                  }
                  // TODO: Check if the name is already in use
                  return null;
                },
                textCapitalization: TextCapitalization.characters,
              ),

              SizedBox(height: 24.h),

              // Daily time limit
              Text(
                'Daily Time Limit (minutes)',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 8.h),
              TextFormField(
                controller: _timeLimitController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'e.g. 60, 120, 180...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter a time limit';
                  }
                  final minutes = int.tryParse(value);
                  if (minutes == null || minutes <= 0) {
                    return 'Enter a valid number greater than 0';
                  }
                  if (minutes > 1440) {
                    return 'The limit cannot exceed 24 hours (1440 minutes)';
                  }
                  return null;
                },
              ),

              SizedBox(height: 24.h),

              // Penalty per extra minute
              Text(
                'Penalty per Extra Minute (points)',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 8.h),
              TextFormField(
                controller: _penaltyController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'e.g. 0.5, 1.0, 2.0...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter a penalty per minute';
                  }
                  final penalty = double.tryParse(value);
                  if (penalty == null || penalty < 0) {
                    return 'Enter a valid number greater than or equal to 0';
                  }
                  return null;
                },
              ),

              SizedBox(height: 24.h),

              // App selector
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    borderRadius: BorderRadius.zero,
                  ),
                  child: AppSelectorWidget(
                    selectedPackages: _selectedPackages,
                    onSelectionChanged: (packages) {
                      setState(() => _selectedPackages = packages);
                    },
                  ),
                ),
              ),

              SizedBox(height: 32.h),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isSubmitting
                            ? Colors.grey
                            : Theme.of(context).brightness == Brightness.light
                            ? Colors.black
                            : Colors.white,
                    foregroundColor:
                        _isSubmitting
                            ? Colors.grey.shade600
                            : Theme.of(context).brightness == Brightness.light
                            ? Colors.white
                            : Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child:
                      _isSubmitting
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : Text(
                            'Create Rule',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                ),
              ),

              SizedBox(height: 16.h),
            ],
          ),
        ),
      ),
    );
  }
}
