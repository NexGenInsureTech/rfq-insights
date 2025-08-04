import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';

class FilterBottomSheet extends StatefulWidget {
  final Set<String> uniqueStatuses;
  final Set<String> uniqueLOBs;
  final Set<String> uniqueCSMs;
  final Set<String> uniqueLocations; // <-- NEW parameter
  final Function(String?, String?, String?, String?)
  onApplyFilters; // <-- Updated signature

  const FilterBottomSheet({
    super.key,
    required this.uniqueStatuses,
    required this.uniqueLOBs,
    required this.uniqueCSMs,
    required this.uniqueLocations, // <-- Required here
    required this.onApplyFilters,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  String? _selectedStatus;
  String? _selectedLOB;
  String? _selectedCSM;
  String? _selectedLocation; // <-- NEW variable

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Apply Filters',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // Status Dropdown
          DropdownSearch<String>(
            popupProps: const PopupProps.menu(showSearchBox: true),
            items: (String filter, dynamic props) {
              final list = widget.uniqueStatuses.toList();
              if (filter.isEmpty) return list;
              return list
                  .where(
                    (item) => item.toLowerCase().contains(filter.toLowerCase()),
                  )
                  .toList();
            },
            decoratorProps: const DropDownDecoratorProps(
              decoration: InputDecoration(
                labelText: "Status",
                border: OutlineInputBorder(),
              ),
            ),
            onChanged: (value) => _selectedStatus = value,
            selectedItem: _selectedStatus,
          ),
          const SizedBox(height: 12),
          // LOB Dropdown
          DropdownSearch<String>(
            popupProps: const PopupProps.menu(showSearchBox: true),
            items: (String filter, dynamic props) {
              final list = widget.uniqueLOBs.toList();
              if (filter.isEmpty) return list;
              return list
                  .where(
                    (item) => item.toLowerCase().contains(filter.toLowerCase()),
                  )
                  .toList();
            },
            decoratorProps: const DropDownDecoratorProps(
              decoration: InputDecoration(
                labelText: "LOB",
                border: OutlineInputBorder(),
              ),
            ),
            onChanged: (value) => _selectedLOB = value,
            selectedItem: _selectedLOB,
          ),
          const SizedBox(height: 12),
          // CSM/RM Name Dropdown
          DropdownSearch<String>(
            popupProps: const PopupProps.menu(showSearchBox: true),
            items: (String filter, dynamic props) {
              final list = widget.uniqueCSMs.toList();
              if (filter.isEmpty) return list;
              return list
                  .where(
                    (item) => item.toLowerCase().contains(filter.toLowerCase()),
                  )
                  .toList();
            },
            decoratorProps: const DropDownDecoratorProps(
              decoration: InputDecoration(
                labelText: "CSM/RM Name",
                border: OutlineInputBorder(),
              ),
            ),
            onChanged: (value) => _selectedCSM = value,
            selectedItem: _selectedCSM,
          ),
          const SizedBox(height: 12),
          // Location Dropdown <-- NEW
          DropdownSearch<String>(
            popupProps: const PopupProps.menu(showSearchBox: true),
            items: (String filter, dynamic props) {
              final list = widget.uniqueLocations.toList();
              if (filter.isEmpty) return list;
              return list
                  .where(
                    (item) => item.toLowerCase().contains(filter.toLowerCase()),
                  )
                  .toList();
            },
            decoratorProps: const DropDownDecoratorProps(
              decoration: InputDecoration(
                labelText: "Location",
                border: OutlineInputBorder(),
              ),
            ),
            onChanged: (value) => _selectedLocation = value,
            selectedItem: _selectedLocation,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () {
                  // Pass null for all filter variables to clear them
                  widget.onApplyFilters(null, null, null, null);
                  Navigator.of(context).pop();
                },
                child: const Text('Clear Filters'),
              ),
              ElevatedButton(
                onPressed: () {
                  // Apply all selected filter variables
                  widget.onApplyFilters(
                    _selectedStatus,
                    _selectedLOB,
                    _selectedCSM,
                    _selectedLocation,
                  );
                  Navigator.of(context).pop();
                },
                child: const Text('Apply'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
