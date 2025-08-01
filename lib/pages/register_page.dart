import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:grad02/firebase/auth_services.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
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

  void register() async {
    try {
      await authService.value.createAccount(
        email: controllerEmail.text,
        password: controllerPassword.text,
      );
      showSnackBarSuccess();
      popPage();
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message ?? 'An exception orrured.';
      });
      showSnackbarFailed();
    }
  }

  void showSnackBarSuccess() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Email created successfully"),
        backgroundColor: Colors.greenAccent.shade700,
        showCloseIcon: true,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void showSnackbarFailed() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Registraion Failed"),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.redAccent,
        showCloseIcon: true,
      ),
    );
  }

  void popPage() {
    Navigator.pop(context);
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
                "Register",
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
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              register();
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
                            "Register",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
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
      ),
    );
  }
}
