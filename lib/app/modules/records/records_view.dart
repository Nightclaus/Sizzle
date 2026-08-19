import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/records_controller.dart';
import '../../helpers/nav_bar.dart';

class RecordsView extends GetView<RecordsController> {
  const RecordsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SizzleNavBar(),
      backgroundColor: const Color(0xFFFAF8F5), // Earthy background
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF948473)));
        }

        if (controller.records.isEmpty) {
          return const Center(
            child: Text(
              "No records found in this workspace yet.",
              style: TextStyle(fontSize: 18, color: Colors.black54),
            ),
          );
        }

        return ListView.builder(
          itemCount: controller.records.length,
          padding: const EdgeInsets.all(24),
          itemBuilder: (context, index) {
            final record = controller.records[index];
            return Card(
              color: const Color(0xFFC7B9A9), // Soft brown card
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(
                  record['name'] ?? 'Unnamed Record',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3E2F23)),
                ),
                subtitle: Text(
                  "JSON Data: ${record['data_as_json']}",
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}