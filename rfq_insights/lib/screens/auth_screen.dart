import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rfq_insights/screens/rfq_list_screen.dart'; // To navigate after successful login

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = FirebaseAuth.instance; // Firebase Auth instance
  final _formKey = GlobalKey<FormState>(); // Key for form validation

  String _email = '';
  String _password = '';
  bool _isLogin = true; // To toggle between login and signup
  bool _isLoading = false; // To show loading indicator

  // Function to handle user authentication (login or signup)
  Future<void> _submitAuthForm() async {
    final isValid = _formKey.currentState?.validate();
    FocusScope.of(context).unfocus(); // Close keyboard

    if (isValid != null && isValid) {
      _formKey.currentState?.save(); // Save form fields

      setState(() {
        _isLoading = true; // Show loading indicator
      });

      UserCredential userCredential;
      try {
        if (_isLogin) {
          // Log in existing user
          userCredential = await _auth.signInWithEmailAndPassword(
            email: _email,
            password: _password,
          );
        } else {
          // Register new user
          userCredential = await _auth.createUserWithEmailAndPassword(
            email: _email,
            password: _password,
          );
        }

        // If authentication is successful, navigate to RFQListScreen
        if (mounted && userCredential.user != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const RfqListScreen()),
          );
        }
      } on FirebaseAuthException catch (e) {
        String message = 'An error occurred, please check your credentials!';
        if (e.message != null) {
          message = e.message!;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false; // Hide loading indicator
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Login' : 'Sign Up')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            margin: const EdgeInsets.all(20),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Takes minimum space
                  children: <Widget>[
                    TextFormField(
                      key: const ValueKey('email'),
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                      ),
                      validator: (value) {
                        if (value == null || !value.contains('@')) {
                          return 'Please enter a valid email address.';
                        }
                        return null;
                      },
                      onSaved: (value) {
                        _email = value!.trim();
                      },
                    ),
                    TextFormField(
                      key: const ValueKey('password'),
                      obscureText: true, // Hide password input
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Password must be at least 6 characters long.';
                        }
                        return null;
                      },
                      onSaved: (value) {
                        _password = value!.trim();
                      },
                    ),
                    const SizedBox(height: 20),
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else
                      ElevatedButton(
                        onPressed: _submitAuthForm,
                        child: Text(_isLogin ? 'Login' : 'Sign Up'),
                      ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLogin = !_isLogin; // Toggle login/signup mode
                        });
                      },
                      child: Text(
                        _isLogin
                            ? 'Create new account'
                            : 'I already have an account',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
