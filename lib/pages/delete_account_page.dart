import 'package:flutter/material.dart';
import 'package:grad02/firebase/auth_services.dart';
import 'package:grad02/pages/welcome_page.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  TextEditingController controllerEmail = TextEditingController();
  TextEditingController controllerPassword = TextEditingController();
  final formKey = GlobalKey<FormState>();
  String errorMessage = "";

  void popPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WelcomePage(),
      ),
    );
  }

  void deleteAccount() async {
    try {
      await authService.value.deleteAccount(
          email: controllerEmail.text, password: controllerPassword.text);
      showSnackBarSuccess();
      popPage();
    } catch (e) {
      showSnackBarFailure();
    }
  }

  void showSnackBarSuccess() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.greenAccent.shade700,
        behavior: SnackBarBehavior.floating,
        content: Text("Email Deleted Successfully"),
        showCloseIcon: true,
      ),
    );
  }

  void showSnackBarFailure() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        content: Text("An exception has occurred"),
        showCloseIcon: true,
      ),
    );
  }

  @override
  void dispose() {
    controllerEmail.dispose();
    controllerPassword.dispose();
    super.dispose();
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
                "Delete Account",
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
                              deleteAccount();
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
                            "Delete Account",
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
