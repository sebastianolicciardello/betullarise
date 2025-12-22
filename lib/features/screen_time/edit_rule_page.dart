import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../model/screen_time_rule.dart';
import '../../provider/screen_time_provider.dart';
import '../../services/ui/snackbar_service.dart';
import 'widgets/app_selector_widget.dart';

class EditRulePage extends StatefulWidget {
  final ScreenTimeRule rule;

  const EditRulePage({super.key, required this.rule});

  @override
  State<EditRulePage> createState() => _EditRulePageState();
}

class _EditRulePageState extends State<EditRulePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _timeLimitController = TextEditingController();
  final _penaltyController = TextEditingController();

  List<String> _selectedPackages = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Pre-populate form with existing rule data
    _nameController.text = widget.rule.name;
    _timeLimitController.text = widget.rule.dailyTimeLimitMinutes.toString();
    _penaltyController.text =
        widget.rule.penaltyPerMinuteExtra.abs().toString();
    _selectedPackages = List.from(widget.rule.appPackages);
  }

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
      final updatedRule = ScreenTimeRule(
        id: widget.rule.id,
        name: _nameController.text.trim(),
        appPackages: _selectedPackages,
        dailyTimeLimitMinutes: int.parse(_timeLimitController.text),
        penaltyPerMinuteExtra: -double.parse(_penaltyController.text),
        isActive: widget.rule.isActive,
        createdTime: widget.rule.createdTime,
        updatedTime: DateTime.now().millisecondsSinceEpoch,
      );

      final screenTimeProvider = Provider.of<ScreenTimeProvider>(
        context,
        listen: false,
      );

      final success = await screenTimeProvider.updateRule(updatedRule);

      if (success && mounted) {
        SnackbarService.showSuccessSnackbar(
          context,
          'Rule updated successfully!',
        );
        Navigator.of(context).pop();
      } else if (mounted) {
        SnackbarService.showErrorSnackbar(context, 'Failed to update rule');
      }
    } catch (e) {
      if (mounted) {
        SnackbarService.showErrorSnackbar(context, 'Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Rule'),
        backgroundColor:
            Theme.of(context).brightness == Brightness.light
                ? Colors.white
                : Colors.black,
        foregroundColor:
            Theme.of(context).brightness == Brightness.light
                ? Colors.black
                : Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rule Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Rule Name',
                  hintText: 'e.g., CHAT, SOCIAL, GAMES',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Rule name is required';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16.h),

              // Time Limit
              TextFormField(
                controller: _timeLimitController,
                decoration: InputDecoration(
                  labelText: 'Daily Time Limit (minutes)',
                  hintText: 'e.g., 60',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Time limit is required';
                  }
                  final minutes = int.tryParse(value);
                  if (minutes == null || minutes <= 0) {
                    return 'Enter a valid positive number';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16.h),

              // Penalty
              TextFormField(
                controller: _penaltyController,
                decoration: InputDecoration(
                  labelText: 'Penalty per Extra Minute',
                  hintText: 'e.g., 0.5',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Penalty is required';
                  }
                  final penalty = double.tryParse(value);
                  if (penalty == null || penalty < 0) {
                    return 'Enter a valid non-negative number';
                  }
                  return null;
                },
              ),
              SizedBox(height: 24.h),

              // App Selection
              Text(
                'Select Apps',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8.h),
              Container(
                height: 600.h,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: AppSelectorWidget(
                  selectedPackages: _selectedPackages,
                  onSelectionChanged: (packages) {
                    setState(() {
                      _selectedPackages = packages;
                    });
                  },
                ),
              ),

              SizedBox(height: 32.h),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).brightness == Brightness.light
                            ? Colors.black
                            : Colors.white,
                    foregroundColor:
                        Theme.of(context).brightness == Brightness.light
                            ? Colors.white
                            : Colors.black,
                    padding: EdgeInsets.symmetric(vertical: 16.h),
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
                          : const Text('Update Rule'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
