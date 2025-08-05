import 'package:flutter/material.dart';

class FilterBottomSheet extends StatefulWidget {
  final Set<String> uniqueStatuses;
  final Set<String> uniqueLOBs;
  final Set<String> uniqueCSMs;
  final Set<String> uniqueLocations;
  final List<String> urgencyFilters; // <-- NEW
  final List<String> agingFilters; // <-- NEW
  final Function(String?, String?, String?, String?, String?, String?)
  onApplyFilters; // <-- UPDATED

  const FilterBottomSheet({
    super.key,
    required this.uniqueStatuses,
    required this.uniqueLOBs,
    required this.uniqueCSMs,
    required this.uniqueLocations,
    required this.urgencyFilters,
    required this.agingFilters,
    required this.onApplyFilters,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  String? _selectedStatus;
  String? _selectedLOB;
  String? _selectedCSM;
  String? _selectedLocation;
  String? _selectedUrgency; // <-- NEW
  String? _selectedAging; // <-- NEW

  @override
  void initState() {
    super.initState();
  }

  void _clearFilters() {
    setState(() {
      _selectedStatus = null;
      _selectedLOB = null;
      _selectedCSM = null;
      _selectedLocation = null;
      _selectedUrgency = null;
      _selectedAging = null;
    });
    // This will apply the cleared filters to the parent widget
    widget.onApplyFilters(null, null, null, null, null, null);
    Navigator.of(context).pop();
  }

  Widget _buildFilterDropdown({
    required String label,
    required List<String> options,
    required String? selectedValue,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: selectedValue,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem<String>(value: null, child: Text('All')),
          ...options.map((String value) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }),
        ],
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filter RFQs',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Clear All'),
                ),
              ],
            ),
            const Divider(),
            _buildFilterDropdown(
              label: 'Status',
              options: widget.uniqueStatuses.toList(),
              selectedValue: _selectedStatus,
              onChanged: (value) => setState(() => _selectedStatus = value),
            ),
            _buildFilterDropdown(
              label: 'LOB',
              options: widget.uniqueLOBs.toList(),
              selectedValue: _selectedLOB,
              onChanged: (value) => setState(() => _selectedLOB = value),
            ),
            _buildFilterDropdown(
              label: 'CSM/RM',
              options: widget.uniqueCSMs.toList(),
              selectedValue: _selectedCSM,
              onChanged: (value) => setState(() => _selectedCSM = value),
            ),
            _buildFilterDropdown(
              label: 'Location',
              options: widget.uniqueLocations.toList(),
              selectedValue: _selectedLocation,
              onChanged: (value) => setState(() => _selectedLocation = value),
            ),
            // --- NEW DROPDOWNS ---
            _buildFilterDropdown(
              label: 'Urgency',
              options: widget.urgencyFilters,
              selectedValue: _selectedUrgency,
              onChanged: (value) => setState(() => _selectedUrgency = value),
            ),
            _buildFilterDropdown(
              label: 'Aging',
              options: widget.agingFilters,
              selectedValue: _selectedAging,
              onChanged: (value) => setState(() => _selectedAging = value),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                widget.onApplyFilters(
                  _selectedStatus,
                  _selectedLOB,
                  _selectedCSM,
                  _selectedLocation,
                  _selectedUrgency,
                  _selectedAging,
                );
                Navigator.of(context).pop();
              },
              child: const Text('Apply Filters'),
            ),
          ],
        ),
      ),
    );
  }
}
