import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart';
import 'dart:async';  // For Timer
import 'package:firebase_database/firebase_database.dart';

// Medication model (same structure as doctor side)
class Medication {
  final String name;
  final int partitionNumber;
  final List<TimeOfDay> timesOfTaking;
  final DateTime startDate;
  final DateTime endDate;
  final String documentId;
  final String? prescribedBy;
  final bool reminderFlag; // NEW
  final bool pillTaken;    // NEW

  Medication({
    required this.name,
    required this.partitionNumber,
    required this.timesOfTaking,
    required this.startDate,
    required this.endDate,
    required this.documentId,
    this.prescribedBy,
    this.reminderFlag = false, // default false
    this.pillTaken = false,    // default false
  });

  factory Medication.fromMap(Map<String, dynamic> map, String docId) {
    var timesList = map['timesOfTaking'] as List<dynamic>? ?? [];
    List<TimeOfDay> times = timesList
        .map((t) => TimeOfDay(hour: t['hour'] as int, minute: t['minute'] as int))
        .toList();

    return Medication(
      name: map['name'] ?? 'Unknown Medication',
      partitionNumber: map['partitionNumber'] ?? 1,
      timesOfTaking: times,
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      documentId: docId,
      prescribedBy: map['prescribedBy'],
      reminderFlag: map['reminderFlag'] ?? false, // NEW
      pillTaken: map['pillTaken'] ?? false,       // NEW
    );
  }

  List<DateTime> getTodaySchedules() {
    final now = DateTime.now();
    if (now.isBefore(startDate) || now.isAfter(endDate)) return [];

    return timesOfTaking.map((time) {
      return DateTime(now.year, now.month, now.day, time.hour, time.minute);
    }).where((scheduled) => scheduled.isAfter(now)).toList(); // Only future times today
  }
}


// Patient Medication Dashboard (Real-time + Firebase)
class MedicationDashboard extends StatefulWidget {
  final String username;
  final UserType userType;

  const MedicationDashboard({
    super.key,
    required this.username,
    required this.userType,
  });

  @override
  State<MedicationDashboard> createState() => _MedicationDashboardState();
}

class _MedicationDashboardState extends State<MedicationDashboard> {
  final user = FirebaseAuth.instance.currentUser;
  List<Timer> _reminderTimers = [];  // List to manage active timers

  @override
  void initState() {
    super.initState();
    print('💊 MedicationDashboard: initState called');
    print('💊 Current user: ${user?.uid}');
    print('💊 Username: ${widget.username}');
    
    if (user == null) {
      print('❌ MedicationDashboard: No user logged in!');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const LoginSignupPage()));
      });
    } else {
      print('✅ MedicationDashboard: User is logged in: ${user!.uid}');
      _checkPatientDocument();
    }
  }

  @override
  void dispose() {
    _cancelAllTimers();  // This prevents memory leaks!
    super.dispose();
  }

  void _cancelAllTimers() {
    for (var timer in _reminderTimers) {
      timer.cancel();
    }
    _reminderTimers.clear();
  }

  Future<void> _checkPatientDocument() async {
    try {
      final patientDoc = await FirebaseFirestore.instance
          .collection('patients')
          .doc(user!.uid)
          .get();
      
      if (patientDoc.exists) {
        print('✅ Patient document exists: ${patientDoc.data()}');
      } else {
        print('❌ WARNING: Patient document does NOT exist for ${user!.uid}');
        print('🔧 Creating patient document now...');
        
        // Try to get user data from users collection
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          await FirebaseFirestore.instance
              .collection('patients')
              .doc(user!.uid)
              .set({
            'name': userData['name'],
            'phone': userData['phone'],
            'email': userData['email'],
            'createdAt': FieldValue.serverTimestamp(),
          });
          print('✅ Patient document created successfully!');
        }
      }
    } catch (e) {
      print('❌ Error checking patient document: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('💊 MedicationDashboard: Building widget');
    
    if (user == null) {
      print('❌ MedicationDashboard build: No user!');
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Medications', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => _showProfileDialog(context),
            tooltip: 'View Profile',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text('Hi, ${widget.username}', style: const TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('patients')
            .doc(user!.uid)
            .snapshots(),
        builder: (context, patientSnapshot) {
          print('💊 Patient stream state: ${patientSnapshot.connectionState}');
          
          if (patientSnapshot.connectionState == ConnectionState.waiting) {
            print('⏳ Waiting for patient document...');
            return const Center(child: CircularProgressIndicator(color: Colors.blue));
          }
          
          if (patientSnapshot.hasError) {
            print('❌ Patient stream error: ${patientSnapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 60),
                  const SizedBox(height: 16),
                  Text('Error loading profile: ${patientSnapshot.error}', 
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          
          if (!patientSnapshot.hasData || !patientSnapshot.data!.exists) {
            print('❌ Patient document not found!');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning, color: Colors.orange, size: 60),
                  const SizedBox(height: 16),
                  const Text(
                    'Patient profile not found',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'User ID: ${user!.uid}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _checkPatientDocument,
                    child: const Text('Try to Fix'),
                  ),
                ],
              ),
            );
          }

          print('✅ Patient document loaded successfully');
          final patientData = patientSnapshot.data!.data() as Map<String, dynamic>;
          print('📄 Patient data: $patientData');

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('patients')
                .doc(user!.uid)
                .collection('medications')
                .orderBy('startDate', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              print('💊 Medications stream state: ${snapshot.connectionState}');
              
              if (snapshot.hasError) {
                print('❌ Medications stream error: ${snapshot.error}');
                return Center(
                  child: Text(
                    'Error loading medications: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }
              
              if (!snapshot.hasData) {
                print('⏳ Waiting for medications...');
                return const Center(child: CircularProgressIndicator(color: Colors.blue));
              }

              final meds = snapshot.data!.docs
                  .map((doc) => Medication.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                  .toList();

              print('📦 Loaded ${meds.length} medications');
              _scheduleReminders(meds);

              if (meds.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: meds.length,
                itemBuilder: (context, index) {
                  final med = meds[index];
                  final isActive = DateTime.now().isBefore(med.endDate);

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: isActive ? Colors.blue : Colors.grey,
                                child: const Icon(Icons.medication, color: Colors.white),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  med.name,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Chip(
                                backgroundColor: isActive ? Colors.blue[100] : Colors.grey[300],
                                label: Text(
                                  '${med.partitionNumber}',
                                  style: TextStyle(color: isActive ? Colors.blue[900] : Colors.grey[700]),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Times
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.access_time, size: 18, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: med.timesOfTaking.map((time) {
                                    return Chip(
                                      backgroundColor: Colors.blue[50],
                                      side: BorderSide(color: Colors.blue[200]!),
                                      label: Text(time.format(context), style: TextStyle(color: Colors.blue[800])),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Dates
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(
                                '${_formatDate(med.startDate)} – ${_formatDate(med.endDate)}',
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isActive ? Colors.green[100] : Colors.red[100],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  isActive ? 'Active' : 'Expired',
                                  style: TextStyle(
                                    color: isActive ? Colors.green[800] : Colors.red[800],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          if (med.prescribedBy != null) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  'Prescribed by Dr. ${med.prescribedBy}',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        child: const Icon(Icons.medication_liquid),
        onPressed: () => _showTodaySchedule(context),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: () {
            print('🚪 Logging out...');
            FirebaseAuth.instance.signOut();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginSignupPage()),
            );
          },
          icon: const Icon(Icons.logout, color: Colors.white),
          label: const Text('Logout', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medication_outlined, size: 100, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'No medications yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            Text(
              'Your doctor will prescribe medications here.\nThey will appear automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  void _showTodaySchedule(BuildContext context) {
    final now = DateTime.now();

    FirebaseFirestore.instance
        .collection('patients')
        .doc(user!.uid)
        .collection('medications')
        .get()
        .then((snapshot) {
      final meds = snapshot.docs
          .map((doc) => Medication.fromMap(doc.data(), doc.id))
          .where((med) => now.isAfter(med.startDate) && now.isBefore(med.endDate.add(const Duration(days: 1))))
          .toList();

      final todayTimes = <TimeOfDay>[];
      for (var med in meds) {
        todayTimes.addAll(med.timesOfTaking);
      }
      todayTimes.sort((a, b) => a.hour * 60 + a.minute - (b.hour * 60 + b.minute));

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Today's Schedule"),
          content: todayTimes.isEmpty
              ? const Text('No doses scheduled for today')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: todayTimes
                      .map((t) => ListTile(
                      leading: const Icon(Icons.alarm, color: Colors.blue),
                      title: Text(t.format(context)),
                      trailing: Icon(
                        meds.firstWhere((m) => m.timesOfTaking.contains(t)).pillTaken
                            ? Icons.check_circle
                            : Icons.notifications_active,
                        color: meds.firstWhere((m) => m.timesOfTaking.contains(t)).pillTaken
                            ? Colors.green
                            : Colors.blue,
                      ),
                    ))
                .toList(),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showProfileDialog(BuildContext context) async {
    print('👤 Opening profile dialog');
    
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      
      final patientDoc = await FirebaseFirestore.instance
          .collection('patients')
          .doc(user!.uid)
          .get();

      if (!userDoc.exists) {
        _showError('User data not found');
        return;
      }

      final userData = userDoc.data()!;
      final patientData = patientDoc.exists ? patientDoc.data()! : null;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue,
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
                      userData['name'] ?? 'Unknown',
                      style: const TextStyle(fontSize: 20),
                    ),
                    Text(
                      'Patient',
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
                _buildProfileRow(Icons.email, 'Email', userData['email'] ?? 'N/A'),
                const SizedBox(height: 12),
                _buildProfileRow(Icons.phone, 'Phone', userData['phone'] ?? patientData?['phone'] ?? 'N/A'),
                const SizedBox(height: 12),
                _buildProfileRow(Icons.badge, 'User ID', user!.uid),
                const SizedBox(height: 12),
                if (userData['createdAt'] != null) ...[
                  _buildProfileRow(
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
                FirebaseAuth.instance.signOut();
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
      print('❌ Error loading profile: $e');
      _showError('Failed to load profile');
    }
  }

  Widget _buildProfileRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.blue),
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

void _scheduleReminders(List<Medication> meds) {
  _cancelAllTimers(); // cancel previous timers

  final now = DateTime.now();

  for (var med in meds) {
    final schedules = med.getTodaySchedules(); // future times today
    for (var scheduledTime in schedules) {
      final durationUntil = scheduledTime.difference(now);
      if (durationUntil.isNegative) continue; // skip past times

      final timer = Timer(durationUntil, () async {
        // 1️⃣ Show in-app dialog
        _showReminderDialog(med.name, scheduledTime);

        // 2️⃣ Trigger ESP reminder via Firebase
        await sendToHardware(true);

        // Optional: reset flag after 1 second so ESP can detect next reminder
        Future.delayed(const Duration(seconds: 1), () async {
          await sendToHardware(false);
        });
      });

      _reminderTimers.add(timer);
    }
  }

  print('🔔 Scheduled ${_reminderTimers.length} reminders for today');
}

void _showReminderDialog(String medName, DateTime time) {
  if (!mounted) return;  // Avoid showing if widget is disposed

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Medication Reminder!'),
      content: Text('It\'s time to take $medName at ${time.hour}:${time.minute.toString().padLeft(2, '0')}.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );

}


Future<void> sendToHardware(bool value) async {
  try {
    final dbRef = FirebaseDatabase.instance.ref('/pillbox/trigger/reminderFlag');
    await dbRef.set(value);
    print('✅ Reminder flag sent to ESP: $value');
  } catch (e) {
    print('❌ Failed to send reminder to ESP: $e');
  }
}

}