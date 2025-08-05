import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:rfq_insights/models/rfq.dart';

// Create a simple model for IMD to hold both name and code
class Imd {
  final String name;
  final String code;

  Imd({required this.name, required this.code});

  @override
  String toString() => name; // This is what the DropdownSearch will display

  // Custom equality operator for the model
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Imd &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          code == other.code;

  @override
  int get hashCode => name.hashCode ^ code.hashCode;
}

class RfqFormScreen extends StatefulWidget {
  final Rfq? rfq;

  const RfqFormScreen({super.key, this.rfq});

  @override
  State<RfqFormScreen> createState() => _RfqFormScreenState();
}

class _RfqFormScreenState extends State<RfqFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Controllers for text fields
  final TextEditingController _proposerNameController = TextEditingController();
  final TextEditingController _rfqSendDateController = TextEditingController();
  final TextEditingController _quoteReceivedDateController =
      TextEditingController();
  final TextEditingController _imdCodeController = TextEditingController();
  // final TextEditingController _premiumController = TextEditingController();
  final TextEditingController _grossPremiumController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _coaController = TextEditingController();
  final TextEditingController _interactionIdController =
      TextEditingController();
  final TextEditingController _inwardTrackerController =
      TextEditingController();
  final TextEditingController _policyNoController = TextEditingController();
  final TextEditingController _policyExpiryDateController =
      TextEditingController();
  final TextEditingController _coSharePercentageController =
      TextEditingController();
  final TextEditingController _totalNetPremiumController =
      TextEditingController();
  // final TextEditingController _totalPremiumWithGstController =
  //     TextEditingController();

  // Master lists for dropdowns
  List<String> _locations = [];
  List<Imd> _imdList = [];
  List<String> _occupancies = [];
  List<String> _lobs = [];
  List<String> _statuses = [];
  List<String> _csmRmNames = [];

  // Selected values for dropdowns
  String? _selectedLocation;
  Imd? _selectedImd;
  String? _selectedOccupancy;
  String? _selectedLOB;
  String? _selectedStatus;
  String? _selectedPreferredReferred;
  String? _selectedQuoteMode;
  String? _selectedCsmRmName;
  DateTime? _rfqSendDate;
  DateTime? _quoteReceivedDate;
  DateTime? _policyExpiryDate;
  String? _urgencyFlag;

  final List<String> _preferredReferredOptions = [
    'Preferred',
    'Referred',
    'Other',
  ];
  final List<String> _quoteModeOptions = ['Email', 'Portal', 'Direct', 'Other'];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchMasterLists();
    // _totalNetPremiumController.addListener(_computeTotalPremiumWithGst);
    _grossPremiumController.addListener(_computePremiums);
  }

  @override
  void dispose() {
    _proposerNameController.dispose();
    _rfqSendDateController.dispose();
    _quoteReceivedDateController.dispose();
    _imdCodeController.dispose();
    // _premiumController.dispose();
    _grossPremiumController.removeListener(_computePremiums);
    _grossPremiumController.dispose();
    _remarksController.dispose();
    _coaController.dispose();
    _interactionIdController.dispose();
    _inwardTrackerController.dispose();
    _policyNoController.dispose();
    _policyExpiryDateController.dispose();
    _coSharePercentageController.dispose();
    // _totalNetPremiumController.removeListener(_computeTotalPremiumWithGst);
    _totalNetPremiumController.dispose();
    // _totalPremiumWithGstController.dispose();
    super.dispose();
  }

  // Helper function to fetch a list from a collection
  Future<List<String>> _fetchMasterList(String collectionName) async {
    final snapshot = await _firestore.collection(collectionName).get();
    // Use .data()? to safely access the map and '??' to provide a fallback value
    return snapshot.docs
        .map((doc) => doc.data()?['name']?.toString() ?? 'N/A')
        .toList();
  }

  // --- REFACTORED METHOD ---
  Future<void> _fetchMasterLists() async {
    try {
      // Await all data fetching calls first
      final imdSnapshot = await _firestore.collection('imd_names').get();
      final imdList = imdSnapshot.docs
          .map(
            (doc) => Imd(
              name:
                  doc.data()?['name']?.toString() ??
                  'N/A', // Null-aware access and fallback
              code:
                  doc.data()?['code']?.toString() ??
                  'N/A', // Null-aware access and fallback
            ),
          )
          .toList();

      final locations = await _fetchMasterList('locations');
      final occupancies = await _fetchMasterList('occupancies');
      final lobs = await _fetchMasterList('lobs');
      final statuses = await _fetchMasterList('statuses');
      final csmRmNames = await _fetchMasterList('csm_rm_names');

      // Now, update all state variables in a single synchronous setState call
      setState(() {
        _locations = locations;
        _occupancies = occupancies;
        _lobs = lobs;
        _statuses = statuses;
        _csmRmNames = csmRmNames;
        _imdList = imdList;
      });

      if (widget.rfq != null) {
        _initializeFormForEdit();
      }
    } catch (e) {
      // This print statement is for debugging. Check your console for any output.
      print('Error fetching master lists: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load form options: $e')),
      );
    }
  }

  void _initializeFormForEdit() {
    final rfq = widget.rfq!;
    _selectedLocation = rfq.location;
    _selectedImd = _imdList.firstWhere(
      (imd) => imd.name == rfq.imdName && imd.code == rfq.imdCode,
      orElse: () => Imd(name: rfq.imdName, code: rfq.imdCode),
    );
    _imdCodeController.text = rfq.imdCode;
    _proposerNameController.text = rfq.proposerName;
    _selectedOccupancy = rfq.occupancy;
    _selectedLOB = rfq.lob;
    _selectedStatus = rfq.status;

    _rfqSendDate = rfq.rfqSendDate;
    _rfqSendDateController.text = DateFormat(
      'dd-MMM-yyyy',
    ).format(_rfqSendDate!);
    _quoteReceivedDate = rfq.quoteReceivedDate;
    if (_quoteReceivedDate != null) {
      _quoteReceivedDateController.text = DateFormat(
        'dd-MMM-yyyy',
      ).format(_quoteReceivedDate!);
    }

    // _premiumController.text = rfq.premium.toString();
    _grossPremiumController.text = rfq.premium.toString();
    _computePremiums();
    _remarksController.text = rfq.remarks ?? '';
    _coaController.text = rfq.coa;
    _selectedPreferredReferred = rfq.preferredReferred;
    _selectedQuoteMode = rfq.quoteMode;
    _interactionIdController.text = rfq.interactionId;
    _selectedCsmRmName = rfq.csmRmName;
    _inwardTrackerController.text = rfq.inwardTracker ?? '';
    _policyNoController.text = rfq.policyNo ?? '';
    _policyExpiryDate = rfq.policyExpiryDate;
    if (_policyExpiryDate != null) {
      _policyExpiryDateController.text = DateFormat(
        'dd-MMM-yyyy',
      ).format(_policyExpiryDate!);
      _checkPolicyStatus(_policyExpiryDate!); // Check status on load
    }
    _coSharePercentageController.text = rfq.coSharePercentage.toString();
    _totalNetPremiumController.text = rfq.totalNetPremium.toString();
    // _totalPremiumWithGstController.text = rfq.totalPremiumWithGst
    //     .toStringAsFixed(2);
  }

  // void _computeTotalPremiumWithGst() {
  //   final netPremiumText = _totalNetPremiumController.text;
  //   if (netPremiumText.isNotEmpty) {
  //     try {
  //       final netPremium = double.parse(netPremiumText);
  //       final gstPremium = Rfq.computeTotalPremiumWithGst(netPremium);
  //       _totalPremiumWithGstController.text = gstPremium.toStringAsFixed(2);
  //     } catch (e) {
  //       _totalPremiumWithGstController.text = 'Invalid No.';
  //     }
  //   } else {
  //     _totalPremiumWithGstController.text = '';
  //   }
  // }

  // Helper method to compute premiums from gross premium
  void _computePremiums() {
    final grossPremiumText = _grossPremiumController.text;
    if (grossPremiumText.isNotEmpty) {
      try {
        final grossPremium = double.parse(grossPremiumText);
        final totalNetPremium = grossPremium / (1 + Rfq.GST_RATE);

        _totalNetPremiumController.text = totalNetPremium.toStringAsFixed(2);
      } catch (e) {
        _totalNetPremiumController.text = 'Invalid No.';
      }
    } else {
      _totalNetPremiumController.text = '';
    }
  }

  // New method to check the policy status
  void _checkPolicyStatus(DateTime expiryDate) {
    final now = DateTime.now();
    final difference = expiryDate.difference(now).inDays;

    setState(() {
      if (difference < 0) {
        _urgencyFlag = 'Expired';
      } else if (difference <= 7) {
        _urgencyFlag = 'Expiring Soon';
      } else {
        _urgencyFlag = null;
      }
    });
  }

  Future<void> _selectDate(
    BuildContext context, {
    bool isRfqSendDate = false,
    bool isQuoteReceivedDate = false,
    bool isPolicyExpiryDate = false,
  }) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null) {
      setState(() {
        if (isRfqSendDate) {
          _rfqSendDate = pickedDate;
          _rfqSendDateController.text = DateFormat(
            'dd-MMM-yyyy',
          ).format(pickedDate);
        } else if (isQuoteReceivedDate) {
          _quoteReceivedDate = pickedDate;
          _quoteReceivedDateController.text = DateFormat(
            'dd-MMM-yyyy',
          ).format(pickedDate);
        } else if (isPolicyExpiryDate) {
          _policyExpiryDate = pickedDate;
          _policyExpiryDateController.text = DateFormat(
            'dd-MMM-yyyy',
          ).format(pickedDate);
          _checkPolicyStatus(pickedDate); // Check status on date selection
        }
      });
    }
  }

  Future<void> _saveRfq() async {
    final isValid = _formKey.currentState!.validate();
    if (!isValid) return;
    _formKey.currentState!.save();

    if (_rfqSendDate == null) {
      _showSnackBar('RFQ Send Date is required.', Colors.red);
      return;
    }
    if (_selectedLocation == null ||
        _selectedImd == null ||
        _selectedOccupancy == null ||
        _selectedLOB == null ||
        _selectedStatus == null ||
        _selectedPreferredReferred == null ||
        _selectedQuoteMode == null ||
        _selectedCsmRmName == null) {
      _showSnackBar('Please fill all required dropdown fields.', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final newRfq = Rfq(
        id: widget.rfq?.id,
        location: _selectedLocation!,
        rfqSendDate: _rfqSendDate!,
        quoteReceivedDate: _quoteReceivedDate,
        imdName: _selectedImd!.name,
        imdCode: _selectedImd!.code,
        proposerName: _proposerNameController.text.trim(),
        occupancy: _selectedOccupancy!,
        lob: _selectedLOB!,
        status: _selectedStatus!,
        // premium: double.parse(_premiumController.text.trim()),
        premium: double.parse(_grossPremiumController.text.trim()),
        remarks: _remarksController.text.trim().isEmpty
            ? null
            : _remarksController.text.trim(),
        coa: _coaController.text.trim(),
        preferredReferred: _selectedPreferredReferred!,
        quoteMode: _selectedQuoteMode!,
        interactionId: _interactionIdController.text.trim(),
        csmRmName: _selectedCsmRmName!,
        inwardTracker: _inwardTrackerController.text.trim().isEmpty
            ? null
            : _inwardTrackerController.text.trim(),
        policyNo: _policyNoController.text.trim().isEmpty
            ? null
            : _policyNoController.text.trim(),
        policyExpiryDate: _policyExpiryDate!,
        urgencyFlag: _urgencyFlag,
        coSharePercentage: double.parse(
          _coSharePercentageController.text.trim(),
        ),
        totalNetPremium: double.parse(_totalNetPremiumController.text.trim()),
        // totalPremiumWithGst: double.parse(
        //   _totalPremiumWithGstController.text.trim(),
        // ),
        totalPremiumWithGst: double.parse(_grossPremiumController.text.trim()),
      );

      if (widget.rfq == null) {
        await _firestore.collection('rfqs').add(newRfq.toFirestore());
        _showSnackBar('RFQ added successfully!', Colors.green);
      } else {
        await _firestore
            .collection('rfqs')
            .doc(newRfq.id)
            .update(newRfq.toFirestore());
        _showSnackBar('RFQ updated successfully!', Colors.green);
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showSnackBar('Failed to save RFQ: ${e.toString()}', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.rfq == null ? 'Add New RFQ' : 'Edit RFQ'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _buildDropdownSearch(
                      label: 'Location',
                      options: _locations,
                      selectedValue: _selectedLocation,
                      onChanged: (value) =>
                          setState(() => _selectedLocation = value),
                    ),
                    _buildDropdownSearchImd(
                      label: 'IMD Name',
                      options: _imdList,
                      selectedValue: _selectedImd,
                      onChanged: (value) {
                        setState(() {
                          _selectedImd = value;
                          _imdCodeController.text = value?.code ?? '';
                        });
                      },
                    ),
                    _buildTextField(
                      controller: _imdCodeController,
                      labelText: 'IMD Code (Auto-populated)',
                      readOnly: true,
                    ),
                    _buildTextField(
                      controller: _proposerNameController,
                      labelText: 'Proposer Name',
                      validator: (value) =>
                          _validateEmpty(value, 'Proposer Name'),
                    ),
                    _buildDropdownSearch(
                      label: 'Occupancy',
                      options: _occupancies,
                      selectedValue: _selectedOccupancy,
                      onChanged: (value) =>
                          setState(() => _selectedOccupancy = value),
                    ),
                    _buildDropdownSearch(
                      label: 'LOB',
                      options: _lobs,
                      selectedValue: _selectedLOB,
                      onChanged: (value) =>
                          setState(() => _selectedLOB = value),
                    ),
                    _buildDropdownSearch(
                      label: 'Status',
                      options: _statuses,
                      selectedValue: _selectedStatus,
                      onChanged: (value) =>
                          setState(() => _selectedStatus = value),
                    ),
                    _buildDatePickerField(
                      controller: _rfqSendDateController,
                      labelText: 'RFQ Send Date',
                      onTap: () => _selectDate(context, isRfqSendDate: true),
                      validator: (value) =>
                          _validateEmpty(value, 'RFQ Send Date'),
                    ),
                    _buildDatePickerField(
                      controller: _quoteReceivedDateController,
                      labelText: 'Quote Received Date (Optional)',
                      onTap: () => _selectDate(context, isRfqSendDate: false),
                    ),
                    _buildNumberField(
                      // controller: _premiumController,
                      controller: _grossPremiumController,
                      labelText: 'Premium',
                      validator: (value) => _validateNumber(value, 'Premium'),
                    ),
                    _buildTextField(
                      controller: _remarksController,
                      labelText: 'Remarks (Optional)',
                      maxLines: 3,
                    ),
                    _buildTextField(
                      controller: _coaController,
                      labelText: 'COA',
                      validator: (value) => _validateEmpty(value, 'COA'),
                    ),
                    _buildDropdownField(
                      value: _selectedPreferredReferred,
                      options: _preferredReferredOptions,
                      labelText: 'Preferred/Referred',
                      onChanged: (newValue) {
                        setState(() => _selectedPreferredReferred = newValue);
                      },
                      validator: (value) =>
                          _validateDropdown(value, 'Preferred/Referred'),
                    ),
                    _buildDropdownField(
                      value: _selectedQuoteMode,
                      options: _quoteModeOptions,
                      labelText: 'Quote Mode',
                      onChanged: (newValue) {
                        setState(() => _selectedQuoteMode = newValue);
                      },
                      validator: (value) =>
                          _validateDropdown(value, 'Quote Mode'),
                    ),
                    _buildTextField(
                      controller: _interactionIdController,
                      labelText: 'Interaction ID (GMC/GPA)',
                      validator: (value) =>
                          _validateEmpty(value, 'Interaction ID'),
                    ),
                    _buildDropdownSearch(
                      label: 'CSM/RM Name',
                      options: _csmRmNames,
                      selectedValue: _selectedCsmRmName,
                      onChanged: (value) =>
                          setState(() => _selectedCsmRmName = value),
                    ),
                    _buildTextField(
                      controller: _inwardTrackerController,
                      labelText: 'Inward Tracker (Optional)',
                    ),
                    _buildTextField(
                      controller: _policyNoController,
                      labelText: 'Policy No (Optional)',
                    ),
                    _buildDatePickerField(
                      controller: _policyExpiryDateController,
                      labelText: 'Policy Expiry Date (Optional)',
                      onTap: () =>
                          _selectDate(context, isPolicyExpiryDate: true),
                    ),
                    // New widget to display the urgency flag
                    if (_urgencyFlag != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            Icon(
                              _urgencyFlag == 'Expired'
                                  ? Icons.error
                                  : Icons.warning,
                              color: _urgencyFlag == 'Expired'
                                  ? Colors.red
                                  : Colors.amber,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _urgencyFlag!,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _urgencyFlag == 'Expired'
                                    ? Colors.red
                                    : Colors.amber,
                              ),
                            ),
                          ],
                        ),
                      ),
                    _buildNumberField(
                      controller: _coSharePercentageController,
                      labelText: 'Co-share %',
                      validator: (value) =>
                          _validateNumber(value, 'Co-share %'),
                    ),
                    _buildNumberField(
                      controller: _totalNetPremiumController,
                      labelText: 'Total Net Premium',
                      validator: (value) =>
                          _validateNumber(value, 'Total Net Premium'),
                    ),
                    // _buildTextField(
                    //   controller: _totalPremiumWithGstController,
                    //   labelText: 'Total Premium with GST (18%)',
                    //   readOnly: true,
                    //   enabled: false,
                    // ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveRfq,
                      child: Text(
                        widget.rfq == null ? 'Add RFQ' : 'Update RFQ',
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool readOnly = false,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          border: const OutlineInputBorder(),
        ),
        validator: validator,
        maxLines: maxLines,
        readOnly: readOnly,
        enabled: enabled,
        keyboardType: keyboardType,
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String labelText,
    String? Function(String?)? validator,
  }) {
    return _buildTextField(
      controller: controller,
      labelText: labelText,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: validator,
    );
  }

  Widget _buildDatePickerField({
    required TextEditingController controller,
    required String labelText,
    required VoidCallback onTap,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        readOnly: true,
        onTap: onTap,
        validator: validator,
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required List<String> options,
    required String labelText,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: labelText,
          border: const OutlineInputBorder(),
        ),
        items: options.map((String option) {
          return DropdownMenuItem<String>(value: option, child: Text(option));
        }).toList(),
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }

  Widget _buildDropdownSearch({
    required String label,
    required List<String> options,
    required String? selectedValue,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownSearch<String>(
        popupProps: const PopupProps.menu(showSearchBox: true),
        decoratorProps: DropDownDecoratorProps(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
        items: (String filter, dynamic props) {
          if (filter.isEmpty) return options;
          return options
              .where(
                (item) => item.toLowerCase().contains(filter.toLowerCase()),
              )
              .toList();
        },
        onChanged: onChanged,
        selectedItem: selectedValue,
        validator: (value) => _validateDropdown(value, label),
      ),
    );
  }

  Widget _buildDropdownSearchImd({
    required String label,
    required List<Imd> options,
    required Imd? selectedValue,
    required ValueChanged<Imd?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownSearch<Imd>(
        popupProps: const PopupProps.menu(showSearchBox: true),
        decoratorProps: DropDownDecoratorProps(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
        itemAsString: (Imd u) => u.name,
        items: (String filter, dynamic props) {
          if (filter.isEmpty) return options;
          return options
              .where(
                (item) =>
                    item.name.toLowerCase().contains(filter.toLowerCase()),
              )
              .toList();
        },
        onChanged: onChanged,
        selectedItem: selectedValue,
        // The fix is here: we provide a function to compare two Imd objects.
        compareFn: (Imd? item1, Imd? item2) {
          return item1?.name == item2?.name && item1?.code == item2?.code;
        },
        validator: (value) => _validateDropdown(value?.name, label),
      ),
    );
  }

  // --- Validation Helpers ---

  String? _validateEmpty(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required.';
    }
    return null;
  }

  String? _validateNumber(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required.';
    }
    if (double.tryParse(value.trim()) == null) {
      return 'Please enter a valid number for $fieldName.';
    }
    return null;
  }

  String? _validateDropdown(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Please select a $fieldName.';
    }
    return null;
  }
}
