import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../provider/tooltip_provider.dart';

class InfoTooltip extends StatelessWidget {
  final String message;
  final String? title;
  final IconData icon;
  final double? iconSize;
  final Color? iconColor;

  const InfoTooltip({
    super.key,
    required this.message,
    this.title,
    this.icon = Icons.info_outline,
    this.iconSize,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<TooltipProvider>(
      builder: (context, tooltipProvider, child) {
        if (!tooltipProvider.showTooltips) {
          return const SizedBox.shrink();
        }

        return IconButton(
          icon: Icon(
            icon,
            size: iconSize ?? 20.sp,
            color: iconColor ?? Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
          ),
          onPressed: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: title != null ? Text(title!) : null,
                  content: Text(message),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                );
              },
            );
          },
          tooltip: 'Tap for info',
          padding: EdgeInsets.all(4.w),
          constraints: BoxConstraints(
            minWidth: 24.w,
            minHeight: 24.h,
          ),
        );
      },
    );
  }
}