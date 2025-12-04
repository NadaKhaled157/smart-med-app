import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart';

// Doctor Dashboard Page with REAL Firebase Firestore Data
class DoctorDashboard extends StatefulWidget {
  final String username;

  const DoctorDashboard({
    super.key,
    required this.username,
  });

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  final _patientNameController = TextEditingController();
  final _patientPhoneController = TextEditingController();
  final _medicationNameController = TextEditingController();
  final _partitionController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  List<TimeOfDay> _timesOfTaking = [];
  int _dosesPerDay = 1;
  bool _isTimesSectionExpanded = false;
  bool _isAddMedicationExpanded = false;
  bool _isPatientLoaded = false;
  bool _isLoading = false;

  String? _currentPatientName;
  String? _currentPatientDocId;

  Stream<List<PatientMedication>>? _medicationsStream;

  @override
  void dispose() {
    _patientNameController.dispose();
    _patientPhoneController.dispose();
    _medicationNameController.dispose();
    _partitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => _showDoctorProfile(context),
            tooltip: 'View Profile',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text('Dr. ${widget.username}', style: const TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPatientSearchCard(),
                const SizedBox(height: 24),
                if (_isPatientLoaded) ...[
                  _buildCurrentPatientHeader(),
                  const SizedBox(height: 16),
                  _buildAddMedicationCard(),
                  const SizedBox(height: 16),
                  Text('Patient Medications',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[800],
                          )),
                  const SizedBox(height: 12),
                  _buildMedicationsList(),
                ] else ...[
                  _buildEmptyState(),
                ],
                const SizedBox(height: 30),
                _buildLogoutButton(),
                const SizedBox(height: 20),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.green),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPatientSearchCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [Icon(Icons.search, color: Colors.green), SizedBox(width: 8), Text('Search Patient', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green))]),
          const SizedBox(height: 16),
          TextField(controller: _patientNameController, decoration: _inputDecoration('Patient Name', Icons.person)),
          const SizedBox(height: 12),
          TextField(controller: _patientPhoneController, keyboardType: TextInputType.phone, decoration: _inputDecoration('Patient Phone Number', Icons.phone)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _searchPatient,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('Search Patient', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPatientHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green[200]!)),
      child: Row(
        children: [
          Icon(Icons.person_outline, color: Colors.green[800]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Current Patient', style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.w500)),
              Text(_currentPatientName ?? 'Unknown', style: TextStyle(color: Colors.green[900], fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
          ),
          StreamBuilder<List<PatientMedication>>(
            stream: _medicationsStream,
            builder: (context, snapshot) {
              int count = snapshot.data?.length ?? 0;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(20)),
                child: Text('$count medications', style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.w600)),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAddMedicationCard() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isAddMedicationExpanded = !_isAddMedicationExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.add_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Add New Medication for $_currentPatientName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green))),
                  Icon(_isAddMedicationExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.green),
                ],
              ),
            ),
          ),
          if (_isAddMedicationExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                TextField(controller: _medicationNameController, decoration: _inputDecoration('Medication Name', Icons.medical_services)),
                const SizedBox(height: 12),
                TextField(controller: _partitionController, keyboardType: TextInputType.number, decoration: _inputDecoration('Partition Number', Icons.numbers)),
                const SizedBox(height: 16),
                _buildDosesPerDaySelector(),
                const SizedBox(height: 12),
                _buildTimeSelector(),
                const SizedBox(height: 12),
                _buildDateSelectors(),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _addMedicationForPatient,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('Add Medication for Patient', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDosesPerDaySelector() {
    return Row(
      children: [
        const Text('Doses per day:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const Spacer(),
        Container(
          decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(onPressed: _dosesPerDay > 1 ? () => _updateDosesPerDay(_dosesPerDay - 1) : null, icon: const Icon(Icons.remove)),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('$_dosesPerDay', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              IconButton(onPressed: _dosesPerDay < 6 ? () => _updateDosesPerDay(_dosesPerDay + 1) : null, icon: const Icon(Icons.add)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isTimesSectionExpanded = !_isTimesSectionExpanded),
            child: Row(
              children: [
                const Icon(Icons.access_time),
                const SizedBox(width: 12),
                Expanded(child: Text(_timesOfTaking.isEmpty ? 'Set times for taking medication' : '${_timesOfTaking.length} time(s) set')),
                Icon(_isTimesSectionExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
              ],
            ),
          ),
          if (_isTimesSectionExpanded) ...[
            const Divider(),
            ...List.generate(_dosesPerDay, (i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text('Dose ${i + 1}:', style: const TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectTimeForDose(context, i),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.green[50], border: Border.all(color: Colors.green), borderRadius: BorderRadius.circular(8)),
                            child: Text(_timesOfTaking.length > i ? _timesOfTaking[i].format(context) : 'Select time', style: TextStyle(color: _timesOfTaking.length > i ? Colors.black : Colors.grey[600])),
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildDateSelectors() {
    return Row(
      children: [
        Expanded(child: _dateTile('Start Date', _startDate, () => _selectStartDate(context))),
        const SizedBox(width: 12),
        Expanded(child: _dateTile('End Date', _endDate, () => _selectEndDate(context))),
      ],
    );
  }

  Widget _dateTile(String label, DateTime? date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8), color: Colors.grey[50]),
        child: Row(children: [const Icon(Icons.calendar_today, size: 20), const SizedBox(width: 8), Text(date != null ? '$label: ${date.day}/${date.month}/${date.year}' : label, style: TextStyle(color: date != null ? Colors.black : Colors.grey[600]))]),
      ),
    );
  }

  Widget _buildMedicationsList() {
    return StreamBuilder<List<PatientMedication>>(
      stream: _medicationsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('❌ Medications stream error: ${snapshot.error}');
          return const Text('Error loading medications', style: TextStyle(color: Colors.red));
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final meds = snapshot.data!;
        if (meds.isEmpty) {
          return const Card(child: Padding(padding: EdgeInsets.all(32), child: Text('No medications prescribed yet', textAlign: TextAlign.center)));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: meds.length,
          itemBuilder: (context, index) {
            final med = meds[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    CircleAvatar(backgroundColor: Colors.green, child: const Icon(Icons.medication, color: Colors.white)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(med.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                    Chip(backgroundColor: Colors.green[100], label: Text('${med.partitionNumber}', style: TextStyle(color: Colors.green[800]))),
                  ]),
                  const SizedBox(height: 12),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.access_time, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        children: med.timesOfTaking
                            .map((t) => Chip(
                                  backgroundColor: Colors.green[50],
                                  side: BorderSide(color: Colors.green[200]!),
                                  label: Text(t.format(context), style: TextStyle(color: Colors.green[800], fontSize: 11)),
                                ))
                            .toList(),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text('${med.startDate.day}/${med.startDate.month}/${med.startDate.year} – ${med.endDate.day}/${med.endDate.month}/${med.endDate.year}', style: const TextStyle(color: Colors.grey)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _deleteMedication(med.documentId),
                      icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                      label: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ]),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(children: [
        const SizedBox(height: 60),
        Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
        const SizedBox(height: 16),
        Text('Search for a patient to view and manage their medications', style: TextStyle(fontSize: 16, color: Colors.grey[600]), textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginSignupPage())),
        icon: const Icon(Icons.logout),
        label: const Text('Logout', style: TextStyle(fontSize: 16)),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 16)),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(labelText: label, prefixIcon: Icon(icon), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: Colors.grey[50]);
  }

  void _searchPatient() async {
    final phone = _patientPhoneController.text.trim();
    if (phone.isEmpty) return _showError('Please enter phone number');

    setState(() => _isLoading = true);

    try {
      print('🔍 Searching for patient with phone: $phone');
      
      final query = await FirebaseFirestore.instance
          .collection('patients')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      print('📊 Query returned ${query.docs.length} documents');

      if (query.docs.isEmpty) {
        _showError('Patient not found');
        setState(() => _isPatientLoaded = false);
        return;
      }

      final doc = query.docs.first;
      final data = doc.data();
      
      print('✅ Patient found: ${doc.id}');
      print('📄 Patient data: $data');

      setState(() {
        _currentPatientDocId = doc.id;
        _currentPatientName = data['name'] ?? _patientNameController.text;
        _isPatientLoaded = true;
      });

      _medicationsStream = doc.reference
          .collection('medications')
          .orderBy('startDate', descending: true)
          .snapshots()
          .map((snapshot) {
            print('📦 Loaded ${snapshot.docs.length} medications');
            return snapshot.docs
                .map((d) => PatientMedication.fromMap(d.data(), d.id))
                .toList();
          });

      _showSuccess('Patient loaded: $_currentPatientName');
    } catch (e) {
      print('❌ Search error: $e');
      _showError('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _updateDosesPerDay(int value) {
    setState(() {
      _dosesPerDay = value;
      if (_timesOfTaking.length > value) _timesOfTaking = _timesOfTaking.sublist(0, value);
      _isTimesSectionExpanded = true;
    });
  }

  Future<void> _selectTimeForDose(BuildContext context, int index) async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) {
      setState(() {
        while (_timesOfTaking.length <= index) _timesOfTaking.add(const TimeOfDay(hour: 8, minute: 0));
        _timesOfTaking[index] = picked;
      });
    }
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final picked = await showDatePicker(context: context, initialDate: _startDate ?? DateTime.now(), firstDate: _startDate ?? DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (picked != null) setState(() => _endDate = picked);
  }

  void _addMedicationForPatient() async {
    if (_currentPatientDocId == null) return _showError('No patient selected');
    if (_medicationNameController.text.isEmpty) return _showError('Enter medication name');
    if (_partitionController.text.isEmpty) return _showError('Enter partition number');
    if (_timesOfTaking.length != _dosesPerDay) return _showError('Set all $_dosesPerDay times');
    if (_startDate == null || _endDate == null) return _showError('Select start & end date');

    setState(() => _isLoading = true);

    try {
      print('💊 Adding medication for patient: $_currentPatientDocId');
      
      final medicationData = {
        'name': _medicationNameController.text.trim(),
        'partitionNumber': int.tryParse(_partitionController.text) ?? 1,
        'timesOfTaking': _timesOfTaking.map((t) => {'hour': t.hour, 'minute': t.minute}).toList(),
        'startDate': Timestamp.fromDate(_startDate!),
        'endDate': Timestamp.fromDate(_endDate!),
        'prescribedBy': widget.username,
        'prescribedAt': FieldValue.serverTimestamp(),
      };
      
      print('📝 Medication data: $medicationData');

      await FirebaseFirestore.instance
          .collection('patients')
          .doc(_currentPatientDocId)
          .collection('medications')
          .add(medicationData);

      print('✅ Medication added successfully!');

      _medicationNameController.clear();
      _partitionController.clear();
      _timesOfTaking.clear();
      _dosesPerDay = 1;
      _startDate = null;
      _endDate = null;
      _isTimesSectionExpanded = false;
      _isAddMedicationExpanded = false;

      _showSuccess('Medication added successfully!');
    } catch (e) {
      print('❌ Failed to add medication: $e');
      _showError('Failed to add medication: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _deleteMedication(String medicationDocId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Medication'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              try {
                print('🗑️ Deleting medication: $medicationDocId');
                await FirebaseFirestore.instance
                    .collection('patients')
                    .doc(_currentPatientDocId)
                    .collection('medications')
                    .doc(medicationDocId)
                    .delete();
                Navigator.pop(context);
                _showSuccess('Medication deleted');
                print('✅ Medication deleted successfully');
              } catch (e) {
                Navigator.pop(context);
                print('❌ Failed to delete: $e');
                _showError('Failed to delete');
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red, duration: const Duration(seconds: 3))
      );
    }
  }
  
  void _showSuccess(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.green, duration: const Duration(seconds: 2))
      );
    }
  }

  void _showDoctorProfile(BuildContext context) async {
    print('👨‍⚕️ Opening doctor profile');
    
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get();

      if (!userDoc.exists) {
        _showError('User data not found');
        return;
      }

      final userData = userDoc.data()!;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.green,
                radius: 30,
                child: Text(
                  widget.username[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dr. ${userData['name'] ?? 'Unknown'}',
                      style: const TextStyle(fontSize: 20),
                    ),
                    Text(
                      'Doctor',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                _buildDoctorProfileRow(Icons.email, 'Email', userData['email'] ?? 'N/A'),
                const SizedBox(height: 12),
                _buildDoctorProfileRow(Icons.phone, 'Phone', userData['phone'] ?? 'N/A'),
                const SizedBox(height: 12),
                _buildDoctorProfileRow(Icons.badge, 'Doctor ID', FirebaseAuth.instance.currentUser!.uid),
                const SizedBox(height: 12),
                if (userData['createdAt'] != null) ...[
                  _buildDoctorProfileRow(
                    Icons.calendar_today,
                    'Member Since',
                    _formatTimestamp(userData['createdAt'] as Timestamp),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginSignupPage()),
                );
              },
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      print('❌ Error loading doctor profile: $e');
      _showError('Failed to load profile');
    }
  }

  Widget _buildDoctorProfileRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.green),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class PatientMedication {
  final String name;
  final int partitionNumber;
  final List<TimeOfDay> timesOfTaking;
  final DateTime startDate;
  final DateTime endDate;
  final String documentId;

  PatientMedication({
    required this.name,
    required this.partitionNumber,
    required this.timesOfTaking,
    required this.startDate,
    required this.endDate,
    required this.documentId,
  });

  factory PatientMedication.fromMap(Map<String, dynamic> map, String docId) {
    var list = map['timesOfTaking'] as List<dynamic>? ?? [];
    List<TimeOfDay> times = list.map((t) => TimeOfDay(hour: t['hour'], minute: t['minute'])).toList();

    return PatientMedication(
      name: map['name'] ?? '',
      partitionNumber: map['partitionNumber'] ?? 1,
      timesOfTaking: times,
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      documentId: docId,
    );
  }
}