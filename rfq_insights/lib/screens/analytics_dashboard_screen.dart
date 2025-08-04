import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() =>
      _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // State variables to hold our aggregated data
  Map<String, int> _rfqStatusData = {};
  Map<String, double> _premiumByLOBData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  // New method to fetch all the data for the dashboard
  Future<void> _fetchDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final rfqDocs = await _firestore.collection('rfqs').get();
      final rfqCount = rfqDocs.docs.length;

      // 1. Aggregate RFQs by Status for the Pie Chart
      final Map<String, int> statusCounts = {};
      // 2. Aggregate Total Premium by LOB for the Bar Chart
      final Map<String, double> premiumByLOB = {};

      for (var doc in rfqDocs.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? 'Unknown';
        final lob = data['lob'] as String? ?? 'Unknown';
        final totalNetPremium =
            (data['totalNetPremium'] as num?)?.toDouble() ?? 0.0;

        // Count statuses
        statusCounts.update(status, (value) => value + 1, ifAbsent: () => 1);

        // Sum premium by LOB
        premiumByLOB.update(
          lob,
          (value) => value + totalNetPremium,
          ifAbsent: () => totalNetPremium,
        );
      }

      setState(() {
        _rfqStatusData = statusCounts;
        _premiumByLOBData = premiumByLOB;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching dashboard data: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load dashboard data.')));
    }
  }

  // Helper method to create a pie chart section
  List<PieChartSectionData> _getPieChartSections(int total) {
    return _rfqStatusData.entries.map((entry) {
      final isTouched = false; // We can add touch logic later
      final double radius = isTouched ? 60 : 50;
      final color = _getStatusColor(entry.key);
      final value = entry.value.toDouble();
      final percentage = (value / total * 100).toStringAsFixed(1);

      return PieChartSectionData(
        color: color,
        value: value,
        title: '${entry.key}\n$percentage%',
        radius: radius,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  // Helper method to assign colors to statuses
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Won':
        return Colors.green;
      case 'Lost':
        return Colors.red;
      case 'Quoted':
        return Colors.blue;
      case 'Pending':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics Dashboard')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Pie Chart: RFQs by Status
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text(
                            'RFQs by Status',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 200,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 40,
                                sections: _getPieChartSections(
                                  _rfqStatusData.values.fold(
                                    0,
                                    (a, b) => a + b,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8.0,
                            children: _rfqStatusData.entries
                                .map(
                                  (entry) => _buildLegendItem(
                                    entry.key,
                                    _getStatusColor(entry.key),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Bar Chart: Total Premium by LOB
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text(
                            'Total Premium by LOB',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 250,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        return Text(
                                          _premiumByLOBData.keys.elementAt(
                                            value.toInt(),
                                          ),
                                          style: const TextStyle(fontSize: 12),
                                        );
                                      },
                                      reservedSize: 30,
                                    ),
                                  ),
                                  leftTitles: const AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 40,
                                    ),
                                  ),
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                barGroups: _premiumByLOBData.entries.map((
                                  entry,
                                ) {
                                  final index = _premiumByLOBData.keys
                                      .toList()
                                      .indexOf(entry.key);
                                  return BarChartGroupData(
                                    x: index,
                                    barRods: [
                                      BarChartRodData(
                                        toY: entry.value,
                                        color: Colors.blueAccent,
                                        width: 15,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLegendItem(String title, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
