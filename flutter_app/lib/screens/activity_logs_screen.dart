import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../providers/security_provider.dart';
import '../widgets/event_tile.dart';

class ActivityLogsScreen extends StatefulWidget {
  const ActivityLogsScreen({super.key});

  @override
  State<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends State<ActivityLogsScreen> {
  String _selectedFilter = 'ALL'; // ALL, INTRUDER_ALERT, ACCESS_GRANTED, MOTION

  @override
  Widget build(BuildContext context) {
    final sec = Provider.of<SecurityProvider>(context);

    final filteredLogs = sec.logs.where((log) {
      if (_selectedFilter == 'ALL') return true;
      return log.eventType == _selectedFilter;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          "SECURITY ACTIVITY LOG",
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => sec.refreshLogs(),
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: Column(
          children: [
            // Stats Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppColors.surface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem("Events Today", sec.stats['events_today']?.toString() ?? "0", AppColors.textPrimary),
                  _buildStatItem("Intruders", sec.stats['intruders_detected']?.toString() ?? "0", AppColors.alertRed),
                  _buildStatItem("Face Unlocks", sec.stats['authorized_unlocks']?.toString() ?? "0", AppColors.safeGreen),
                ],
              ),
            ),

            // Filter Chips
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip("ALL", "All Activity"),
                    _buildFilterChip("INTRUDER_ALERT", "Intruder Alerts", color: AppColors.alertRed),
                    _buildFilterChip("ACCESS_GRANTED", "Face Verified", color: AppColors.safeGreen),
                    _buildFilterChip("MOTION", "PIR Motion", color: AppColors.motionAmber),
                  ],
                ),
              ),
            ),

            // Logs List
            Expanded(
              child: filteredLogs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_outlined, size: 48, color: AppColors.textMuted.withOpacity(0.5)),
                          const SizedBox(height: 12),
                          const Text(
                            "No events matching this filter.",
                            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filteredLogs.length,
                      itemBuilder: (context, index) {
                        return EventTile(
                          event: filteredLogs[index],
                          baseUrl: sec.baseUrl,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label, {Color? color}) {
    final isSelected = _selectedFilter == key;
    final chipColor = color ?? AppColors.primary;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedFilter = key),
        backgroundColor: AppColors.surface,
        selectedColor: chipColor.withOpacity(0.2),
        checkmarkColor: chipColor,
        labelStyle: TextStyle(
          color: isSelected ? chipColor : AppColors.textSecondary,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? chipColor : AppColors.border,
          ),
        ),
      ),
    );
  }
}
