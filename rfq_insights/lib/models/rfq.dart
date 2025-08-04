import 'package:cloud_firestore/cloud_firestore.dart';

class Rfq {
  String? id; // Firestore document ID
  String location;
  DateTime rfqSendDate;
  DateTime? quoteReceivedDate; // Nullable
  String imdName;
  String imdCode;
  String proposerName;
  String occupancy;
  String lob; // Line of Business
  String status;
  double premium;
  String? remarks; // Nullable
  String coa; // Code of Conduct / Class of Accident (assuming based on context)
  String preferredReferred; // "Preferred" or "Referred"
  String quoteMode;
  String interactionId; // GMC/GPA
  String csmRmName;
  String? inwardTracker; // Nullable, if closed and Inwarded
  String? policyNo; // Nullable, if generated
  double coSharePercentage;
  double totalNetPremium;
  double totalPremiumWithGst; // Auto computed

  Rfq({
    this.id,
    required this.location,
    required this.rfqSendDate,
    this.quoteReceivedDate,
    required this.imdName,
    required this.imdCode,
    required this.proposerName,
    required this.occupancy,
    required this.lob,
    required this.status,
    required this.premium,
    this.remarks,
    required this.coa,
    required this.preferredReferred,
    required this.quoteMode,
    required this.interactionId,
    required this.csmRmName,
    this.inwardTracker,
    this.policyNo,
    required this.coSharePercentage,
    required this.totalNetPremium,
    required this.totalPremiumWithGst,
  });

  // Factory constructor to create an Rfq object from a Firestore document
  factory Rfq.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot, [
    SnapshotOptions? options,
  ]) {
    final data = snapshot.data();
    return Rfq(
      id: snapshot.id,
      location: data?['location'] ?? '',
      rfqSendDate: (data?['rfqSendDate'] as Timestamp).toDate(),
      quoteReceivedDate: (data?['quoteReceivedDate'] as Timestamp?)?.toDate(),
      imdName: data?['imdName'] ?? '',
      imdCode: data?['imdCode'] ?? '',
      proposerName: data?['proposerName'] ?? '',
      occupancy: data?['occupancy'] ?? '',
      lob: data?['lob'] ?? '',
      status: data?['status'] ?? '',
      premium: (data?['premium'] ?? 0.0).toDouble(),
      remarks: data?['remarks'],
      coa: data?['coa'] ?? '',
      preferredReferred: data?['preferredReferred'] ?? '',
      quoteMode: data?['quoteMode'] ?? '',
      interactionId: data?['interactionId'] ?? '',
      csmRmName: data?['csmRmName'] ?? '',
      inwardTracker: data?['inwardTracker'],
      policyNo: data?['policyNo'],
      coSharePercentage: (data?['coSharePercentage'] ?? 0.0).toDouble(),
      totalNetPremium: (data?['totalNetPremium'] ?? 0.0).toDouble(),
      totalPremiumWithGst: (data?['totalPremiumWithGst'] ?? 0.0).toDouble(),
    );
  }

  // Method to convert an Rfq object to a Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'location': location,
      'rfqSendDate': Timestamp.fromDate(rfqSendDate),
      'quoteReceivedDate': quoteReceivedDate != null
          ? Timestamp.fromDate(quoteReceivedDate!)
          : null,
      'imdName': imdName,
      'imdCode': imdCode,
      'proposerName': proposerName,
      'occupancy': occupancy,
      'lob': lob,
      'status': status,
      'premium': premium,
      'remarks': remarks,
      'coa': coa,
      'preferredReferred': preferredReferred,
      'quoteMode': quoteMode,
      'interactionId': interactionId,
      'csmRmName': csmRmName,
      'inwardTracker': inwardTracker,
      'policyNo': policyNo,
      'coSharePercentage': coSharePercentage,
      'totalNetPremium': totalNetPremium,
      'totalPremiumWithGst': totalPremiumWithGst,
      // We will add 'createdAt' and 'updatedAt' fields in FirestoreService for better tracking
    };
  }

  // Helper method for GST calculation
  static const double GST_RATE = 0.18; // 18%

  // Method to compute Total Premium with GST
  static double computeTotalPremiumWithGst(double netPremium) {
    return netPremium * (1 + GST_RATE);
  }
}
