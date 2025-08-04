import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:rfq_insights/models/rfq.dart';
import 'package:rfq_insights/screens/analytics_dashboard_screen.dart';
import 'package:rfq_insights/screens/auth_screen.dart';
import 'package:rfq_insights/screens/filter_bottom_sheet.dart';
import 'package:rfq_insights/screens/master_list_manager_screen.dart';
import 'package:rfq_insights/screens/rfq_form_screen.dart';
import 'package:web/web.dart' as web;

class RfqListScreen extends StatefulWidget {
  const RfqListScreen({super.key});

  @override
  State<RfqListScreen> createState() => _RfqListScreenState();
}

class _RfqListScreenState extends State<RfqListScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // IMPORTANT: Replace 'your_admin_email@example.com' with an email from one of your test users.
  bool get _isAdmin => _auth.currentUser?.email == 'nick@nick.me';

  // Filter variables
  String? _selectedStatusFilter;
  String? _selectedLOBFilter;
  String? _selectedCSMFilter;
  String? _selectedLocationFilter;

  // List of unique values for dropdowns
  Set<String> _uniqueStatuses = {};
  Set<String> _uniqueLOBs = {};
  Set<String> _uniqueCSMs = {};
  Set<String> _uniqueLocations = {};

  // Helper function to fetch a list of strings from a collection with a 'name' field
  // Inside _RfqListScreenState class
  Future<Set<String>> _fetchMasterList(String collectionName) async {
    final snapshot = await _firestore.collection(collectionName).get();
    return snapshot.docs.map((doc) => doc.data()['name'] as String).toSet();
  }

  Future<void> _fetchUniqueFilterValues() async {
    try {
      final statuses = await _fetchMasterList('statuses');
      final lobs = await _fetchMasterList('lobs');
      final csmNames = await _fetchMasterList('csm_rm_names');
      final locations = await _fetchMasterList(
        'locations',
      ); // <-- This variable is now used

      setState(() {
        _uniqueStatuses = statuses;
        _uniqueLOBs = lobs;
        _uniqueCSMs = csmNames;
        _uniqueLocations =
            locations; // <-- Assign the value here to remove the warning
      });
    } catch (e) {
      // ...
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchUniqueFilterValues();
  }

  // --- REFACTOR: Dynamic Query Builder with `isEqualTo` ---
  // Inside _RfqListScreenState class
  Stream<QuerySnapshot> _buildQuery() {
    Query query = _firestore.collection('rfqs');

    if (_selectedStatusFilter != null) {
      query = query.where('status', isEqualTo: _selectedStatusFilter);
    }
    if (_selectedLOBFilter != null) {
      query = query.where('lob', isEqualTo: _selectedLOBFilter);
    }
    if (_selectedCSMFilter != null) {
      query = query.where('csmRmName', isEqualTo: _selectedCSMFilter);
    }
    if (_selectedLocationFilter != null) {
      // <-- NEW query clause
      query = query.where('location', isEqualTo: _selectedLocationFilter);
    }

    return query.snapshots();
  }

  // --- NEW: Function to show the filter bottom sheet ---
  // Inside _RfqListScreenState class
  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return FilterBottomSheet(
          uniqueStatuses: _uniqueStatuses,
          uniqueLOBs: _uniqueLOBs,
          uniqueCSMs: _uniqueCSMs,
          uniqueLocations: _uniqueLocations,
          onApplyFilters: (status, lob, csm, location) {
            setState(() {
              _selectedStatusFilter = status;
              _selectedLOBFilter = lob;
              _selectedCSMFilter = csm;
              _selectedLocationFilter =
                  location; // <-- Update the new filter variable
            });
          },
        );
      },
    );
  }

  // Function to delete an RFQ (unchanged)
  Future<void> _deleteRfq(String rfqId) async {
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this RFQ entry?'),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(false);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop(true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      try {
        await _firestore.collection('rfqs').doc(rfqId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('RFQ deleted successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete RFQ: $e')));
      }
    }
  }

  // Down load RFQ List to CSV
  Future<void> _downloadRfqList() async {
    try {
      final querySnapshot = await _firestore.collection('rfqs').get();
      final rfqDocs = querySnapshot.docs;

      if (rfqDocs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No RFQ entries to download.')),
        );
        return;
      }

      List<List<dynamic>> csvData = [
        [
          'Location',
          'RFQ Send Date',
          'Quote Received Date',
          'IMD Name',
          'IMD Code',
          'Proposer Name',
          'Occupancy',
          'LOB',
          'Status',
          'Premium',
          'Remarks',
          'COA',
          'Preferred/Referred',
          'Quote Mode',
          'Interaction ID',
          'CSM/RM Name',
          'Inward Tracker',
          'Policy No',
          'Co-share %',
          'Total Net Premium',
          'Total Premium with GST',
        ],
      ];

      for (var doc in rfqDocs) {
        final rfq = Rfq.fromFirestore(
          doc as DocumentSnapshot<Map<String, dynamic>>,
        );
        csvData.add([
          rfq.location,
          DateFormat('dd-MMM-yyyy').format(rfq.rfqSendDate),
          rfq.quoteReceivedDate != null
              ? DateFormat('dd-MMM-yyyy').format(rfq.quoteReceivedDate!)
              : 'N/A',
          rfq.imdName,
          rfq.imdCode,
          rfq.proposerName,
          rfq.occupancy,
          rfq.lob,
          rfq.status,
          rfq.premium,
          rfq.remarks ?? '',
          rfq.coa,
          rfq.preferredReferred,
          rfq.quoteMode,
          rfq.interactionId,
          rfq.csmRmName,
          rfq.inwardTracker ?? '',
          rfq.policyNo ?? '',
          rfq.coSharePercentage,
          rfq.totalNetPremium,
          rfq.totalPremiumWithGst,
        ]);
      }

      String csv = const ListToCsvConverter().convert(csvData);

      // Use the new web API to trigger the download
      final blob = web.Blob(
        [Utf8Encoder().convert(csv).toJS].toJS,
        web.BlobPropertyBag(type: 'text/csv'),
      );
      final url = web.URL.createObjectURL(blob);
      final anchor = web.HTMLAnchorElement()
        ..href = url
        ..download =
            'rfq_list_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
      web.document.body!.append(anchor);
      anchor.click();
      web.document.body!.removeChild(anchor);
      web.URL.revokeObjectURL(url);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('RFQ list downloaded successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download RFQ list: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RFQ Tracker Dashboard'),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Download RFQ List',
              onPressed: _downloadRfqList,
            ),
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Manage Master Lists',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const MasterListManagerScreen(),
                  ),
                );
              },
            ),
          // --- NEW: Analytics Dashboard Button ---
          // if (_isAdmin)
          IconButton(
            icon: const Icon(Icons.analytics),
            tooltip: 'Analytics Dashboard',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AnalyticsDashboardScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list), // New filter icon
            tooltip: 'Filter',
            onPressed: _showFilterOptions,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await _auth.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const AuthScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          // Display active filters at the top of the screen
          _buildActiveFiltersRow(),

          // The list of RFQs will now fill the rest of the screen
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 600) {
                  // Desktop/Tablet View (using DataTable)
                  return StreamBuilder<QuerySnapshot>(
                    stream: _buildQuery(),
                    builder: (context, snapshot) {
                      // ... (DataTable widget code remains the same)
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Text('No RFQ entries found. Add a new one!'),
                        );
                      }
                      final rfqDocs = snapshot.data!.docs;
                      final List<Rfq> rfqs = rfqDocs
                          .map(
                            (doc) => Rfq.fromFirestore(
                              doc as DocumentSnapshot<Map<String, dynamic>>,
                            ),
                          )
                          .toList();

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 20,
                          dataRowMinHeight: 40,
                          dataRowMaxHeight: 60,
                          columns: const [
                            DataColumn(label: Text('Location')),
                            DataColumn(label: Text('RFQ Send Date')),
                            DataColumn(label: Text('Quote Received Date')),
                            DataColumn(label: Text('IMD Name')),
                            DataColumn(label: Text('IMD Code')),
                            DataColumn(label: Text('Proposer Name')),
                            DataColumn(label: Text('Occupancy')),
                            DataColumn(label: Text('LOB')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Premium')),
                            DataColumn(label: Text('Remarks')),
                            DataColumn(label: Text('COA')),
                            DataColumn(label: Text('Preferred/Referred')),
                            DataColumn(label: Text('Quote Mode')),
                            DataColumn(label: Text('Interaction ID')),
                            DataColumn(label: Text('CSM/RM Name')),
                            DataColumn(label: Text('Inward Tracker')),
                            DataColumn(label: Text('Policy No')),
                            DataColumn(label: Text('Co-share %')),
                            DataColumn(label: Text('Total Net Premium')),
                            DataColumn(label: Text('Total Premium with GST')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: rfqs.map((rfq) {
                            return DataRow(
                              cells: [
                                DataCell(Text(rfq.location)),
                                DataCell(
                                  Text(
                                    DateFormat(
                                      'dd-MMM-yyyy',
                                    ).format(rfq.rfqSendDate),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    rfq.quoteReceivedDate != null
                                        ? DateFormat(
                                            'dd-MMM-yyyy',
                                          ).format(rfq.quoteReceivedDate!)
                                        : 'N/A',
                                  ),
                                ),
                                DataCell(Text(rfq.imdName)),
                                DataCell(Text(rfq.imdCode)),
                                DataCell(Text(rfq.proposerName)),
                                DataCell(Text(rfq.occupancy)),
                                DataCell(Text(rfq.lob)),
                                DataCell(Text(rfq.status)),
                                DataCell(Text(rfq.premium.toStringAsFixed(2))),
                                DataCell(Text(rfq.remarks ?? 'N/A')),
                                DataCell(Text(rfq.coa)),
                                DataCell(Text(rfq.preferredReferred)),
                                DataCell(Text(rfq.quoteMode)),
                                DataCell(Text(rfq.interactionId)),
                                DataCell(Text(rfq.csmRmName)),
                                DataCell(Text(rfq.inwardTracker ?? 'N/A')),
                                DataCell(Text(rfq.policyNo ?? 'N/A')),
                                DataCell(
                                  Text(
                                    '${rfq.coSharePercentage.toStringAsFixed(2)}%',
                                  ),
                                ),
                                DataCell(
                                  Text(rfq.totalNetPremium.toStringAsFixed(2)),
                                ),
                                DataCell(
                                  Text(
                                    rfq.totalPremiumWithGst.toStringAsFixed(2),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 20),
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  RfqFormScreen(rfq: rfq),
                                            ),
                                          );
                                        },
                                        tooltip: 'Edit RFQ',
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          size: 20,
                                          color: Colors.red,
                                        ),
                                        onPressed: () => _deleteRfq(rfq.id!),
                                        tooltip: 'Delete RFQ (Admin Only)',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      );
                    },
                  );
                } else {
                  // Mobile View (using ListView of Cards)
                  return StreamBuilder<QuerySnapshot>(
                    stream: _buildQuery(),
                    builder: (context, snapshot) {
                      // ... (ListView widget code remains the same)
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Text('No RFQ entries found. Add a new one!'),
                        );
                      }
                      final rfqDocs = snapshot.data!.docs;
                      final List<Rfq> rfqs = rfqDocs
                          .map(
                            (doc) => Rfq.fromFirestore(
                              doc as DocumentSnapshot<Map<String, dynamic>>,
                            ),
                          )
                          .toList();

                      return ListView.builder(
                        itemCount: rfqs.length,
                        itemBuilder: (context, index) {
                          final rfq = rfqs[index];
                          return _buildRfqCard(rfq);
                        },
                      );
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const RfqFormScreen()),
          );
        },
        tooltip: 'Add New RFQ',
        child: const Icon(Icons.add),
      ),
    );
  }

  // --- NEW: Widget to display active filters ---
  Widget _buildActiveFiltersRow() {
    final activeFilters = <Widget>[];

    if (_selectedStatusFilter != null) {
      activeFilters.add(
        Chip(
          label: Text('Status: $_selectedStatusFilter'),
          onDeleted: () => setState(() => _selectedStatusFilter = null),
        ),
      );
    }
    if (_selectedLOBFilter != null) {
      activeFilters.add(
        Chip(
          label: Text('LOB: $_selectedLOBFilter'),
          onDeleted: () => setState(() => _selectedLOBFilter = null),
        ),
      );
    }
    if (_selectedCSMFilter != null) {
      activeFilters.add(
        Chip(
          label: Text('CSM: $_selectedCSMFilter'),
          onDeleted: () => setState(() => _selectedCSMFilter = null),
        ),
      );
    }

    if (activeFilters.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const Text(
                'Active Filters:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              ...activeFilters.map(
                (chip) => Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: chip,
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _selectedStatusFilter = null;
                  _selectedLOBFilter = null;
                  _selectedCSMFilter = null;
                }),
                child: const Text('Clear All'),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink(); // Return an empty widget if no filters are active
  }

  // Helper method for the mobile view's RFQ card (unchanged)
  Widget _buildRfqCard(Rfq rfq) {
    // ... (This method remains the same as in the previous response)
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blueAccent,
          child: Text(
            rfq.status.substring(0, 1),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          rfq.proposerName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Status: ${rfq.status} | LOB: ${rfq.lob}'),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16.0),
        children: [
          const Divider(),
          _buildDetailRow('Location', rfq.location),
          _buildDetailRow(
            'RFQ Send Date',
            DateFormat('dd-MMM-yyyy').format(rfq.rfqSendDate),
          ),
          _buildDetailRow(
            'Quote Received Date',
            rfq.quoteReceivedDate != null
                ? DateFormat('dd-MMM-yyyy').format(rfq.quoteReceivedDate!)
                : 'N/A',
          ),
          _buildDetailRow('IMD Name', rfq.imdName),
          _buildDetailRow('IMD Code', rfq.imdCode),
          _buildDetailRow('Occupancy', rfq.occupancy),
          _buildDetailRow('Premium', '₹${rfq.premium.toStringAsFixed(2)}'),
          _buildDetailRow(
            'Total Net Premium',
            '₹${rfq.totalNetPremium.toStringAsFixed(2)}',
          ),
          // _buildDetailRow(
          //   'Total Premium with GST',
          //   '₹${rfq.totalPremiumWithGst.toStringAsFixed(2)}',
          // ),
          _buildDetailRow('CSM/RM Name', rfq.csmRmName),

          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, size: 24),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => RfqFormScreen(rfq: rfq),
                    ),
                  );
                },
                tooltip: 'Edit RFQ',
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 24, color: Colors.red),
                onPressed: () => _deleteRfq(rfq.id!),
                tooltip: 'Delete RFQ (Admin Only)',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper widget for a consistent detail row (unchanged)
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(flex: 3, child: Text(value)),
        ],
      ),
    );
  }
}
