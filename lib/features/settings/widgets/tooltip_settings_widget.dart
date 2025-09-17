import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../provider/tooltip_provider.dart';

class TooltipSettingsWidget extends StatelessWidget {
  const TooltipSettingsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TooltipProvider>(
      builder: (context, tooltipProvider, child) {
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Interface',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12.h),
                SwitchListTile(
                  title: const Text('Info Tooltips'),
                  value: tooltipProvider.showTooltips,
                  onChanged: (value) {
                    tooltipProvider.setShowTooltips(value);
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}