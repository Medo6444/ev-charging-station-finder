import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:grad02/firebase/auth_services.dart';
import 'main_map_page.dart';
import 'reset_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  TextEditingController controllerEmail = TextEditingController();
  TextEditingController controllerPassword = TextEditingController();
  final formKey = GlobalKey<FormState>();
  String errorMessage = '';

  @override
  void dispose() {
    controllerEmail.dispose();
    controllerPassword.dispose();
    super.dispose();
  }

  void signIn() async {
    try {
      await authService.value.signIn(
        email: controllerEmail.text,
        password: controllerPassword.text,
      );
      snackBarSuccess();
      popPage();
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message ?? 'An exception has occured';
      });
      snackBarFail();
    }
  }

  void snackBarSuccess() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Login Successful"),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.greenAccent.shade700,
        showCloseIcon: true,
      )
    );
  }

  void snackBarFail() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Login Failed"),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
      )
    );
  }

  void popPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1F1F1F),
      appBar: AppBar(
        title: Text('EV Charging Station Finder'),
        centerTitle: true,
        backgroundColor: Colors.greenAccent.shade700,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            children: [
              const SizedBox(height: 60),
              const Text(
                "Sign In",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 50),
              Form(
                key: formKey,
                child: Center(
                  child: Column(
                    children: [
                      TextFormField(
                        style: TextStyle(color: Colors.white),
                        controller: controllerEmail,
                        decoration: const InputDecoration(labelText: "Email"),
                        validator: (String? value) {
                          if (value == null) {
                            return "This field cannot be empty";
                          }
                          if (value.trim().isEmpty) {
                            return "This field cannot be empty";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        style: TextStyle(color: Colors.white),
                        obscureText: true,
                        controller: controllerPassword,
                        decoration: const InputDecoration(
                          labelText: "Password",
                        ),
                        validator: (String? value) {
                          if (value == null) {
                            return "This field cannot be empty";
                          }
                          if (value.trim().isEmpty) {
                            return "This field cannot be empty";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      Text(
                        errorMessage,
                        style: TextStyle(color: Colors.redAccent),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) {
                                  return ResetPasswordPage(
                                    email: controllerEmail.text,
                                  );
                                },
                              ),
                            );
                          },
                          child: const Text("Reset Password"),
                        ),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              signIn();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Sign in",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
