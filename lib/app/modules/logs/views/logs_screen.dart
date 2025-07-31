import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart'; // For formatting dates
import 'package:sizzle/app/helpers/nav_bar.dart';
import '../../../controllers/log_controller.dart';
import '../../../models/log_entry_model.dart';
import '../../../helpers/nav_bar.dart';

class LogsScreen extends GetView<LogsController> {
  const LogsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SizzleNavBar(),
      body: Column(
        children: [
          _buildSortControls(),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (controller.logs.isEmpty) {
                return const Center(child: Text("No activity logs found. Select a workspace to view logs"));
              }
              return ListView.builder(
                itemCount: controller.logs.length,
                itemBuilder: (context, index) {
                  final log = controller.logs[index];
                  return _buildLogEntryCard(log);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSortControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      color: Colors.grey[200],
      child: Obx(() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSortChip(SortType.timestamp, "Most Recent"),
          _buildSortChip(SortType.operation, "By Operation"),
          _buildSortChip(SortType.user, "By User"),
        ],
      )),
    );
  }

  Widget _buildSortChip(SortType type, String label) {
    final bool isSelected = controller.currentSortType.value == type;
    return ActionChip(
      label: Text(label),
      backgroundColor: isSelected ? Get.theme.primaryColor : Colors.white,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
      onPressed: () => controller.sortLogs(type),
      side: BorderSide(color: Colors.grey[400]!),
    );
  }

  Widget _buildLogEntryCard(LogEntry log) {
    // Using a Card for a nice "mini table" row effect
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Column 1: Timestamp
            SizedBox(
              width: 90,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('MMM d').format(log.timestamp),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(DateFormat('hh:mm a').format(log.timestamp)),
                ],
              ),
            ),
            // Divider
            const VerticalDivider(),
            // Column 2 & 3: Description and User
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.description,
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        log.userName,
                        style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}