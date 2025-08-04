import 'package:flutter/material.dart';
import 'package:rfq_insights/screens/master_list_detail_screen.dart';

class MasterListManagerScreen extends StatelessWidget {
  const MasterListManagerScreen({super.key});

  // A list of the master lists we want to manage
  static const List<String> masterLists = [
    'Locations',
    'IMD Names',
    'Occupancies',
    'LOBs',
    'Statuses',
    'CSM/RM Names',
    // Add other lists here as needed
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Master Lists')),
      body: ListView.builder(
        itemCount: masterLists.length,
        itemBuilder: (context, index) {
          final listName = masterLists[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.list_alt),
              title: Text(listName),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                // Navigate to the detail screen for the selected list
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        MasterListDetailScreen(listType: listName),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
