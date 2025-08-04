import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MasterListDetailScreen extends StatefulWidget {
  final String listType;

  const MasterListDetailScreen({super.key, required this.listType});

  @override
  State<MasterListDetailScreen> createState() => _MasterListDetailScreenState();
}

class _MasterListDetailScreenState extends State<MasterListDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _getCollectionName() {
    switch (widget.listType) {
      case 'IMD Names':
        return 'imd_names';
      case 'CSM/RM Names':
        return 'csm_rm_names';
      case 'LOBs':
        return 'lobs';
      case 'Statuses':
        return 'statuses';
      case 'Locations':
        return 'locations';
      case 'Occupancies':
        return 'occupancies';
      default:
        return widget.listType.toLowerCase();
    }
  }

  // New helper method to get the correct field name
  String _getFieldNameForCollection(String collectionName) {
    switch (collectionName) {
      case 'locations':
        return 'name';
      case 'imd_names':
        return 'name';
      case 'occupancies':
        return 'name';
      case 'lobs':
        return 'name';
      case 'statuses':
        return 'name';
      case 'csm_rm_names':
        return 'name';
      default:
        return 'name';
    }
  }

  Future<void> _showMasterListFormDialog({
    DocumentSnapshot? doc,
    String? initialValue,
    String? initialCode,
  }) async {
    final isEditing = doc != null;
    final nameController = TextEditingController(text: initialValue);
    final codeController = TextEditingController(text: initialCode);
    final collectionName = _getCollectionName();
    final isImd = collectionName == 'imd_names';
    final fieldName = _getFieldNameForCollection(collectionName);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isEditing ? 'Edit ${widget.listType}' : 'Add New ${widget.listType}',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: fieldName,
              ), // <-- CORRECTED: Using the fieldName variable
            ),
            if (isImd)
              TextField(
                controller: codeController,
                decoration: const InputDecoration(labelText: 'Code'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('$fieldName cannot be empty')),
                );
                return;
              }

              final data = {fieldName: nameController.text.trim()};
              if (isImd) {
                data['code'] = codeController.text.trim();
              }

              try {
                if (isEditing) {
                  await _firestore
                      .collection(collectionName)
                      .doc(doc!.id)
                      .update(data);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('${widget.listType} updated successfully!'),
                    ),
                  );
                } else {
                  await _firestore.collection(collectionName).add(data);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('${widget.listType} added successfully!'),
                    ),
                  );
                }
                Navigator.of(ctx).pop();
              } catch (e) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Failed to save item: $e')),
                );
              }
            },
            child: Text(isEditing ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(String docId) async {
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text(
          'Are you sure you want to delete this ${widget.listType} item?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      try {
        await _firestore.collection(_getCollectionName()).doc(docId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.listType} deleted successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete item: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final collectionName = _getCollectionName();
    final fieldName = _getFieldNameForCollection(collectionName);
    final isImd = collectionName == 'imd_names';

    return Scaffold(
      appBar: AppBar(title: Text('Manage ${widget.listType}')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection(collectionName)
            .orderBy(fieldName) // <-- CORRECTED: Using the fieldName variable
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No items found. Add a new one!'));
          }

          final docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final name =
                  data[fieldName] ??
                  'N/A'; // <-- CORRECTED: Using the fieldName variable
              final code = isImd ? (data['code'] ?? '') : '';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  title: Text(name),
                  subtitle: code.isNotEmpty ? Text('Code: $code') : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showMasterListFormDialog(
                          doc: doc,
                          initialValue: name,
                          initialCode: code,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteItem(doc.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMasterListFormDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
