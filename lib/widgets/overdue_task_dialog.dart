import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:betullarise/model/task.dart';
import 'package:betullarise/widgets/info_tooltip.dart';

class OverdueTaskDialog extends StatelessWidget {
  final Task task;
  final int overdueDays;
  final double effectivePoints;
  final VoidCallback onExtendDeadline;
  final VoidCallback onAcceptPenalty;
  final VoidCallback onSetActualDate;
  final VoidCallback onFullPoints;

  const OverdueTaskDialog({
    super.key,
    required this.task,
    required this.overdueDays,
    required this.effectivePoints,
    required this.onExtendDeadline,
    required this.onAcceptPenalty,
    required this.onSetActualDate,
    required this.onFullPoints,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        constraints: BoxConstraints(
          maxWidth: 500.w,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: EdgeInsets.all(24.w),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitle(),
              SizedBox(height: 20.h),
              _buildContent(),
              SizedBox(height: 24.h),
              _buildQuestionText(),
              SizedBox(height: 16.h),
              _buildActionButtons(context),
              SizedBox(height: 20.h),
              _buildCancelButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Row(
      children: [
        const Icon(Icons.schedule, color: Colors.orange),
        SizedBox(width: 8.w),
        Text(
          'Overdue Task',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        InfoTooltip(
          message: 'This dialog helps you handle overdue tasks fairly:\n\n'
                  '• Extend Deadline: Change the due date\n'
                  '• Accept Penalty: Get reduced points for being late\n'
                  '• Set Actual Date: Choose when you really completed it\n'
                  '• Full Points: You completed on time but forgot to mark it',
          title: 'Overdue Task Options',
          icon: Icons.info,
          iconSize: 20.sp,
        ),
      ],
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'This task is $overdueDays day${overdueDays > 1 ? 's' : ''} overdue.',
          style: TextStyle(fontSize: 16.sp),
        ),
        SizedBox(height: 16.h),
        Text('Original points: +${task.score.toStringAsFixed(2)}'),
        Text('Penalty applied: -${(task.penalty * overdueDays).toStringAsFixed(2)}'),
        Text(
          'You would receive: ${effectivePoints.toStringAsFixed(2)} points',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: effectivePoints >= 0 ? Colors.orange : Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionText() {
    return const Text(
      'What would you like to do?',
      style: TextStyle(fontWeight: FontWeight.w600),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.edit_calendar,
                label: 'Extend\nDeadline',
                color: Colors.blue,
                onPressed: onExtendDeadline,
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _buildActionButton(
                icon: Icons.schedule,
                label: 'Accept\nPenalty',
                color: Colors.orange,
                onPressed: onAcceptPenalty,
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.date_range,
                label: 'Set Actual\nDate',
                color: Colors.purple,
                onPressed: onSetActualDate,
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _buildActionButton(
                icon: Icons.check_circle,
                label: 'Full\nPoints',
                color: Colors.green,
                onPressed: onFullPoints,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color),
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
      ),
      icon: Icon(icon, color: color, size: 18.sp),
      label: Text(
        label,
        style: TextStyle(color: color, fontSize: 12.sp),
        textAlign: TextAlign.center,
      ),
      onPressed: onPressed,
    );
  }

  Widget _buildCancelButton(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text(
          'Cancel',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}