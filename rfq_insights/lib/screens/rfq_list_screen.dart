import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:rfq_insights/models/rfq.dart';
import 'package:rfq_insights/screens/analytics_dashboard_screen.dart';
import 'package:rfq_insights/screens/auth_screen.dart';
import 'package:rfq_insights/screens/filter_bottom_sheet.dart';
import 'package:rfq_insights/screens/master_list_manager_screen.dart';
import 'package:rfq_insights/screens/rfq_form_screen.dart';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:csv/csv.dart';
import 'dart:convert';

class RfqListScreen extends StatefulWidget {
  const RfqListScreen({super.key});

  @override
  State<RfqListScreen> createState() => _RfqListScreenState();
}

class _RfqListScreenState extends State<RfqListScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool get _isAdmin => _auth.currentUser?.email == 'nick@nick.me';

  // Filter variables
  String? _selectedStatusFilter;
  String? _selectedLOBFilter;
  String? _selectedCSMFilter;
  String? _selectedLocationFilter;
  String? _selectedUrgencyFilter; // <-- NEW
  String? _selectedAgingFilter; // <-- NEW

  // List of unique values for dropdowns
  Set<String> _uniqueStatuses = {};
  Set<String> _uniqueLOBs = {};
  Set<String> _uniqueCSMs = {};
  Set<String> _uniqueLocations = {};

  // Static lists for new filters
  final List<String> _urgencyFilters = ['Expired', 'Expiring Soon'];
  final List<String> _agingFilters = [
    'New (0-7 days)',
    'Aging (8-14 days)',
    'Stale (15+ days)',
  ];

  Future<Set<String>> _fetchMasterList(String collectionName) async {
    final snapshot = await _firestore.collection(collectionName).get();
    return snapshot.docs.map((doc) => doc.data()['name'] as String).toSet();
  }

  Future<void> _fetchUniqueFilterValues() async {
    try {
      final statuses = await _fetchMasterList('statuses');
      final lobs = await _fetchMasterList('lobs');
      final csmNames = await _fetchMasterList('csm_rm_names');
      final locations = await _fetchMasterList('locations');

      setState(() {
        _uniqueStatuses = statuses;
        _uniqueLOBs = lobs;
        _uniqueCSMs = csmNames;
        _uniqueLocations = locations;
      });
    } catch (e) {
      print('Error fetching master lists for filters: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchUniqueFilterValues();
  }

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
      query = query.where('location', isEqualTo: _selectedLocationFilter);
    }

    // --- NEW: Query for urgency and aging ---
    if (_selectedUrgencyFilter != null) {
      query = query.where('urgencyFlag', isEqualTo: _selectedUrgencyFilter);
    }

    if (_selectedAgingFilter != null) {
      final now = DateTime.now();
      if (_selectedAgingFilter == 'New (0-7 days)') {
        final sevenDaysAgo = now.subtract(const Duration(days: 7));
        query = query.where(
          'rfqSendDate',
          isGreaterThanOrEqualTo: sevenDaysAgo,
        );
      } else if (_selectedAgingFilter == 'Aging (8-14 days)') {
        final eightDaysAgo = now.subtract(const Duration(days: 8));
        final fifteenDaysAgo = now.subtract(const Duration(days: 15));
        query = query
            .where('rfqSendDate', isLessThan: eightDaysAgo)
            .where('rfqSendDate', isGreaterThan: fifteenDaysAgo);
      } else if (_selectedAgingFilter == 'Stale (15+ days)') {
        final fifteenDaysAgo = now.subtract(const Duration(days: 15));
        query = query.where('rfqSendDate', isLessThan: fifteenDaysAgo);
      }
    }
    // Note: For multi-field queries, you might need to create composite indexes in Firestore.

    return query.snapshots();
  }

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
          urgencyFilters: _urgencyFilters, // <-- NEW
          agingFilters: _agingFilters, // <-- NEW
          onApplyFilters: (status, lob, csm, location, urgency, aging) {
            // <-- UPDATED SIGNATURE
            setState(() {
              _selectedStatusFilter = status;
              _selectedLOBFilter = lob;
              _selectedCSMFilter = csm;
              _selectedLocationFilter = location;
              _selectedUrgencyFilter = urgency; // <-- NEW
              _selectedAgingFilter = aging; // <-- NEW
            });
          },
        );
      },
    );
  }

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
          'Policy Expiry Date',
          'Urgency Flag',
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
          rfq.policyExpiryDate != null
              ? DateFormat('dd-MMM-yyyy').format(rfq.policyExpiryDate!)
              : 'N/A', // <-- NEW
          rfq.urgencyFlag ?? 'N/A', // <-- NEW
        ]);
      }

      String csv = const ListToCsvConverter().convert(csvData);

      final bytes = Utf8Encoder().convert(csv);
      final blob = web.Blob(
        [bytes.toJS].toJS,
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
          if (_isAdmin)
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
            icon: const Icon(Icons.filter_list),
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
          _buildActiveFiltersRow(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 600) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: _buildQuery(),
                    builder: (context, snapshot) {
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
                  return StreamBuilder<QuerySnapshot>(
                    stream: _buildQuery(),
                    builder: (context, snapshot) {
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

  Widget _buildActiveFiltersRow() {
    final activeFilters = <Widget>[];
    if (_selectedStatusFilter != null)
      activeFilters.add(
        Chip(
          label: Text('Status: $_selectedStatusFilter'),
          onDeleted: () => setState(() => _selectedStatusFilter = null),
        ),
      );
    if (_selectedLOBFilter != null)
      activeFilters.add(
        Chip(
          label: Text('LOB: $_selectedLOBFilter'),
          onDeleted: () => setState(() => _selectedLOBFilter = null),
        ),
      );
    if (_selectedCSMFilter != null)
      activeFilters.add(
        Chip(
          label: Text('CSM: $_selectedCSMFilter'),
          onDeleted: () => setState(() => _selectedCSMFilter = null),
        ),
      );
    if (_selectedLocationFilter != null)
      activeFilters.add(
        Chip(
          label: Text('Location: $_selectedLocationFilter'),
          onDeleted: () => setState(() => _selectedLocationFilter = null),
        ),
      );

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
              ...activeFilters
                  .map(
                    (chip) => Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: chip,
                    ),
                  )
                  .toList(),
              TextButton(
                onPressed: () => setState(() {
                  _selectedStatusFilter = null;
                  _selectedLOBFilter = null;
                  _selectedCSMFilter = null;
                  _selectedLocationFilter = null;
                }),
                child: const Text('Clear All'),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildRfqCard(Rfq rfq) {
    // Determine the color and icon for the urgency flag
    Color? urgencyColor;
    IconData? urgencyIcon;

    if (rfq.urgencyFlag == 'Expired') {
      urgencyColor = Colors.red;
      urgencyIcon = Icons.error;
    } else if (rfq.urgencyFlag == 'Expiring Soon') {
      urgencyColor = Colors.amber;
      urgencyIcon = Icons.warning;
    } else {
      urgencyColor = null;
      urgencyIcon = null;
    }

    // --- NEW: Aging Badge Logic ---
    final now = DateTime.now();
    final agingDays = now.difference(rfq.rfqSendDate).inDays;
    Color agingColor;
    String agingLabel;

    if (agingDays <= 7) {
      agingColor = Colors.green;
      agingLabel = '$agingDays Days';
    } else if (agingDays <= 14) {
      agingColor = Colors.amber;
      agingLabel = '$agingDays Days';
    } else {
      agingColor = Colors.red;
      agingLabel = '$agingDays Days';
    }

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
        title: Row(
          children: [
            // Display the proposer name
            Text(
              rfq.proposerName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            // Conditionally display the urgency icon
            if (urgencyIcon != null)
              Icon(urgencyIcon, color: urgencyColor, size: 20),
            const SizedBox(width: 8),
            // --- NEW: Display the aging badge ---
            Chip(
              label: Text(
                agingLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: agingColor,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            ),
          ],
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
          _buildDetailRow(
            'Total Premium with GST',
            '₹${rfq.totalPremiumWithGst.toStringAsFixed(2)}',
          ),
          _buildDetailRow(
            'Policy Expiry Date',
            rfq.policyExpiryDate != null
                ? DateFormat('dd-MMM-yyyy').format(rfq.policyExpiryDate!)
                : 'N/A',
          ),
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
