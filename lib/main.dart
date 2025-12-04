import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'medication_dashboard.dart';
import 'doctor_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase initialization error: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Pill Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.hasData ? const RoleBasedHome() : const LoginSignupPage();
      },
    );
  }
}

class RoleBasedHome extends StatelessWidget {
  const RoleBasedHome({super.key});
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          FirebaseAuth.instance.signOut();
          return const LoginSignupPage();
        }
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final role = data['role'] as String;
        final name = data['name'] as String? ?? 'User';

        if (role == 'doctor') {
          print("DOCTOR DASHBOARD");
          return DoctorDashboard(username: name);
        } else {
          print("PATIENT DASHBOARD");
          return MedicationDashboard(username: name, userType: UserType.patient);
        }
      },
    );
  }
}

enum UserType { patient, doctor }

class LoginSignupPage extends StatefulWidget {
  const LoginSignupPage({super.key});
  @override
  State<LoginSignupPage> createState() => _LoginSignupPageState();
}

class _LoginSignupPageState extends State<LoginSignupPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  UserType? _selectedUserType;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    // Validation
    if (email.isEmpty || password.isEmpty) {
      _showError('Email and password required');
      return;
    }
    if (!_isLogin && (name.isEmpty || phone.isEmpty || _selectedUserType == null)) {
      _showError('All fields required for signup');
      return;
    }
    if (password.length < 6) {
      _showError('Password must be 6+ characters');
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential;

      if (_isLogin) {
        print('🔄 Attempting login...');
        userCredential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: password);
        print('✅ Login successful: ${userCredential.user?.email}');
      } else {
        print('🔄 Attempting signup...');
        
        // Create auth account
        userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);
        print('✅ Auth account created: ${userCredential.user?.uid}');

        final role = _selectedUserType == UserType.doctor ? 'doctor' : 'patient';

        // Create patient document if patient
        if (role == 'patient') {
          print('🔄 Creating patient document...');
          await FirebaseFirestore.instance
              .collection('patients')
              .doc(userCredential.user!.uid)
              .set({
            'name': name,
            'phone': phone,
            'email': email,
            'createdAt': FieldValue.serverTimestamp(),
          });
          print('✅ Patient document created');
        }

        // Create user document
        print('🔄 Creating user document...');
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'name': name,
          'email': email,
          'phone': phone,
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('✅ User document created');
      }

      if (mounted) {
        _showSuccess(_isLogin ? 'Welcome back!' : 'Account created!');
        // Navigation happens automatically via AuthWrapper
      }
      
    } on FirebaseAuthException catch (e) {
      print('❌ FirebaseAuthException: ${e.code} - ${e.message}');
      
      // More specific error messages
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No account found with this email';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password';
          break;
        case 'email-already-in-use':
          errorMessage = 'Email already registered';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email format';
          break;
        case 'weak-password':
          errorMessage = 'Password is too weak';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error - check your internet';
          break;
        default:
          errorMessage = e.message ?? 'Authentication failed: ${e.code}';
      }
      _showError(errorMessage);
      
    } on FirebaseException catch (e) {
      print('❌ FirebaseException: ${e.code} - ${e.message}');
      _showError('Database error: ${e.message}');
      
    } catch (e, stackTrace) {
      print('❌ Unknown error: $e');
      print('Stack trace: $stackTrace');
      _showError('Unexpected error: $e');
      
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.medical_services, size: 80, color: Colors.blue),
                const SizedBox(height: 16),
                Text('Smart Pill Tracker', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.blue[800])),
                const SizedBox(height: 8),
                const Text('Manage your health with ease', style: TextStyle(color: Colors.grey)),

                const SizedBox(height: 40),

                // Toggle
                Container(
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(30)),
                  child: Row(children: [
                    _tab('Login', _isLogin, () => setState(() => _isLogin = true)),
                    _tab('Sign Up', !_isLogin, () => setState(() => _isLogin = false)),
                  ]),
                ),

                const SizedBox(height: 32),
                TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: _inputDec('Email', Icons.email)),
                const SizedBox(height: 16),
                TextField(controller: _passwordController, obscureText: true, decoration: _inputDec('Password', Icons.lock)),

                if (!_isLogin) ...[
                  const SizedBox(height: 16),
                  TextField(controller: _nameController, decoration: _inputDec('Name', Icons.person)),
                  const SizedBox(height: 16),
                  TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: _inputDec('Phone', Icons.phone)),
                  const SizedBox(height: 24),
                  const Text('I am a:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(children: [
                    _roleTile(UserType.patient, 'Patient', Icons.person),
                    const SizedBox(width: 16),
                    _roleTile(UserType.doctor, 'Doctor', Icons.local_hospital),
                  ]),
                ],

                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleAuth,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        )
                      : Text(
                          _isLogin ? 'Login' : 'Create Account',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(String text, bool active, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: active ? Colors.blue : Colors.transparent, borderRadius: BorderRadius.circular(30)),
            child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: active ? Colors.white : Colors.grey[700], fontWeight: FontWeight.w600)),
          ),
        ),
      );

  Widget _roleTile(UserType type, String label, IconData icon) {
    final selected = _selectedUserType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedUserType = type),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: selected ? Colors.blue : Colors.white, 
            border: Border.all(color: selected ? Colors.blue : Colors.grey[300]!), 
            borderRadius: BorderRadius.circular(16)
          ),
          child: Column(children: [
            Icon(icon, size: 36, color: selected ? Colors.white : Colors.blue), 
            const SizedBox(height: 8), 
            Text(label, style: TextStyle(color: selected ? Colors.white : Colors.grey[800], fontWeight: FontWeight.bold))
          ]),
        ),
      ),
    );
  }

  InputDecoration _inputDec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blue),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
      );

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red, duration: const Duration(seconds: 4))
      );
    }
  }
  
  void _showSuccess(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.green)
      );
    }
  }
}