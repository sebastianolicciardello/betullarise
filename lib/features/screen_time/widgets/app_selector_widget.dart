import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_device_apps/flutter_device_apps.dart' hide AppInfo;
import '../../../model/app_info.dart';
import '../../../services/android_usage_stats_service.dart';

class AppSelectorWidget extends StatefulWidget {
  final List<String> selectedPackages;
  final Function(List<String>) onSelectionChanged;

  const AppSelectorWidget({
    super.key,
    required this.selectedPackages,
    required this.onSelectionChanged,
  });

  @override
  State<AppSelectorWidget> createState() => _AppSelectorWidgetState();
}

class _AppSelectorWidgetState extends State<AppSelectorWidget> {
  List<AppInfo> _installedApps = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool _showSystemApps = false;
  final AndroidUsageStatsService _usageStatsService =
      AndroidUsageStatsService();

  @override
  void initState() {
    super.initState();
    _loadInstalledApps();
  }

  Future<void> _loadInstalledApps() async {
    try {
      setState(() => _isLoading = true);

      // First try to get all installed apps
      final allApps = await _getAllInstalledApps();
      if (allApps.isNotEmpty) {
        setState(() {
          _installedApps = allApps;
          _isLoading = false;
        });
        return;
      }

      // Fallback to apps from usage monitoring if we can't get all apps
      final usageApps = await _getAppsFromUsageStats();
      if (usageApps.isNotEmpty) {
        setState(() {
          _installedApps = usageApps;
          _isLoading = false;
        });
        return;
      }

      // Last fallback to common apps
      final commonApps = _getCommonApps();
      setState(() {
        _installedApps = commonApps;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading installed apps: $e');

      // Fallback to common apps in case of error
      final commonApps = _getCommonApps();
      setState(() {
        _installedApps = commonApps;
        _isLoading = false;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading apps: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<List<AppInfo>> _getAllInstalledApps() async {
    try {
      // Get all installed apps using flutter_device_apps
      final apps = await FlutterDeviceApps.listApps(
        includeSystem: true,
        onlyLaunchable: false,
        includeIcons: true, // We load icons to show real app icons
      );

      debugPrint(
        'Loaded ${apps.length} installed apps from flutter_device_apps',
      );

      // Convert AppInfo to local AppInfo
      final appInfos =
          apps.map((app) {
            return AppInfo(
              packageName: app.packageName!,
              appName: app.appName!,
              isSystemApp: app.isSystem ?? false,
              icon: app.iconBytes,
            );
          }).toList();

      // Sort by app name
      appInfos.sort((a, b) => a.appName.compareTo(b.appName));

      return appInfos;
    } catch (e) {
      debugPrint('Error getting all installed apps: $e');
      return [];
    }
  }

  Future<List<AppInfo>> _getAppsFromUsageStats() async {
    try {
      // Get usage data for today to see which apps have been monitored
      final today = DateTime.now();
      final usageData = await _usageStatsService.getAppsUsageForDay(today, []);

      // Convert package names to AppInfo with descriptive names
      final apps =
          usageData.keys.map((packageName) {
            return AppInfo(
              packageName: packageName,
              appName: _getAppNameFromPackage(packageName),
              isSystemApp: _isSystemPackage(packageName),
            );
          }).toList();

      debugPrint('Loaded ${apps.length} apps from usage stats');
      return apps;
    } catch (e) {
      debugPrint('Error getting apps from usage stats: $e');
      return [];
    }
  }

  String _getAppNameFromPackage(String package) {
    // Map of most common package names
    final packageMap = {
      'com.whatsapp': 'WhatsApp',
      'org.telegram.messenger': 'Telegram',
      'com.instagram.android': 'Instagram',
      'com.facebook.katana': 'Facebook',
      'com.google.android.youtube': 'YouTube',
      'com.spotify.music': 'Spotify',
      'com.twitter.android': 'Twitter',
      'com.tinder': 'Tinder',
      'com.netflix.mediaclient': 'Netflix',
      'com.google.android.gm': 'Gmail',
      'com.google.android.chrome': 'Chrome',
      'com.android.chrome': 'Chrome',
      'com.google.android.apps.photos': 'Google Photos',
      'com.google.android.apps.maps': 'Google Maps',
      'com.google.android.calendar': 'Google Calendar',
      'com.google.android.contacts': 'Google Contacts',
      'com.android.contacts': 'Contacts',
      'com.android.phone': 'Phone',
      'com.android.mms': 'Messages',
      'com.android.settings': 'Settings',
      'com.android.camera': 'Camera',
      'com.google.android.apps.messaging': 'Messages Google',
      'com.android.systemui': 'System UI',
      'com.android.launcher': 'Launcher',
      'com.google.android.googlequicksearchbox': 'Google',
      'com.google.android.apps.nexuslauncher': 'Pixel Launcher',
    };

    return packageMap[package] ?? _formatPackageName(package);
  }

  String _formatPackageName(String package) {
    // For unknown packages, format the name in a readable way
    final parts = package.split('.');
    if (parts.length >= 2) {
      final lastPart = parts.last;
      // Capitalize the first letter
      return lastPart.substring(0, 1).toUpperCase() + lastPart.substring(1);
    }
    return package;
  }

  bool _isSystemPackage(String package) {
    // Consider packages starting with com.android as system apps
    return package.startsWith('com.android') ||
        package.startsWith('android') ||
        package.contains('systemui') ||
        package.contains('launcher');
  }

  List<AppInfo> _getCommonApps() {
    return [
      AppInfo(
        packageName: 'com.whatsapp',
        appName: 'WhatsApp',
        isSystemApp: false,
      ),
      AppInfo(
        packageName: 'org.telegram.messenger',
        appName: 'Telegram',
        isSystemApp: false,
      ),
      AppInfo(
        packageName: 'com.instagram.android',
        appName: 'Instagram',
        isSystemApp: false,
      ),
      AppInfo(
        packageName: 'com.facebook.katana',
        appName: 'Facebook',
        isSystemApp: false,
      ),
      AppInfo(
        packageName: 'com.google.android.youtube',
        appName: 'YouTube',
        isSystemApp: false,
      ),
    ];
  }

  List<AppInfo> get _filteredApps {
    var apps = _installedApps;

    // Filter out system apps if not showing them
    if (!_showSystemApps) {
      apps = apps.where((app) => !app.isSystemApp).toList();
    }

    if (_searchQuery.isEmpty) {
      return apps;
    }
    return apps.where((app) {
      final query = _searchQuery.toLowerCase();
      return app.appName.toLowerCase().contains(query) ||
          app.packageName.toLowerCase().contains(query);
    }).toList();
  }

  void _toggleAppSelection(String packageName) {
    final newSelection = List<String>.from(widget.selectedPackages);
    if (newSelection.contains(packageName)) {
      newSelection.remove(packageName);
    } else {
      newSelection.add(packageName);
    }
    widget.onSelectionChanged(newSelection);
  }

  Widget _buildAppTile(AppInfo app) {
    final isSelected = widget.selectedPackages.contains(app.packageName);

    return ListTile(
      leading:
          app.icon != null
              ? Image.memory(
                app.icon!,
                width: 40.sp,
                height: 40.sp,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.apps,
                    size: 40.sp,
                    color: Theme.of(context).colorScheme.primary,
                  );
                },
              )
              : Icon(
                Icons.apps,
                size: 40.sp,
                color: Theme.of(context).colorScheme.primary,
              ),
      title: Text(
        app.appName,
        style: TextStyle(fontSize: 16.sp),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        app.packageName,
        style: TextStyle(
          fontSize: 12.sp,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Checkbox(
        value: isSelected,
        onChanged: (value) => _toggleAppSelection(app.packageName),
        activeColor: Theme.of(context).colorScheme.primary,
        checkColor: Theme.of(context).colorScheme.onPrimary,
        fillColor: WidgetStateProperty.resolveWith<Color>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.selected)) {
            return Theme.of(context).colorScheme.primary;
          }
          return Theme.of(context).colorScheme.surface;
        }),
      ),
      onTap: () => _toggleAppSelection(app.packageName),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with selection count
          Padding(
            padding: EdgeInsets.only(left: 16.w, bottom: 12.h),
            child: Row(
              children: [
                Text(
                  'Select Apps',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    '${widget.selectedPackages.length} selected',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Selected apps preview
          if (widget.selectedPackages.isNotEmpty) ...[
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Apps',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.15,
                    ),
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 6.w,
                        runSpacing: 6.h,
                        children:
                            widget.selectedPackages.map((package) {
                              final app =
                                  _installedApps
                                      .where((a) => a.packageName == package)
                                      .firstOrNull;
                              return Chip(
                                label: Text(
                                  app?.appName ?? package,
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                onDeleted: () => _toggleAppSelection(package),
                                deleteIcon: Icon(
                                  Icons.close,
                                  size: 16.sp,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                backgroundColor:
                                    Theme.of(context).colorScheme.surface,
                                side: BorderSide.none,
                              );
                            }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),
          ],

          // Search bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search apps...',
                prefixIcon: Icon(Icons.search, size: 20.sp),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 12.h,
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          SizedBox(height: 12.h),

          // Toggle for showing system apps
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                Text(
                  'Show system apps',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: _showSystemApps,
                  onChanged: (value) => setState(() => _showSystemApps = value),
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                  activeTrackColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.3),
                  inactiveThumbColor: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                  inactiveTrackColor: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.1),
                ),
              ],
            ),
          ),

          SizedBox(height: 12.h),

          // Apps list
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredApps.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.apps,
                            size: 64.sp,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            _searchQuery.isEmpty
                                ? 'No apps found'
                                : 'No apps match the search',
                            style: TextStyle(
                              fontSize: 16.sp,
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: _filteredApps.length,
                      itemBuilder: (context, index) {
                        final app = _filteredApps[index];
                        return _buildAppTile(app);
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
