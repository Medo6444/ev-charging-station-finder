import 'package:flutter/material.dart';
import '../firebase/auth_services.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  TextEditingController controllerEmail = TextEditingController();
  TextEditingController controllerCurrentPassword = TextEditingController();
  TextEditingController controllerNewPassword = TextEditingController();
  final formKey = GlobalKey<FormState>();
  String errorMessage = "";

  @override
  void dispose() {
    controllerEmail.dispose();
    controllerCurrentPassword.dispose();
    controllerNewPassword.dispose();
    super.dispose();
  }

  void changePassword() async {
    try {
      await authService.value.resetPasswordFromCurrentPassword(
        currentPassword: controllerCurrentPassword.text,
        newPassword: controllerNewPassword.text,
        email: controllerEmail.text,
      );
      showSnackBarSuccess();
    } catch (e) {
      showSnackBarFailure();
    }
  }

  void showSnackBarSuccess() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        content: Text("Password changed successfully"),
        showCloseIcon: true,
      ),
    );
  }

  void showSnackBarFailure() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        content: Text("An exception has occurred"),
        showCloseIcon: true,
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
                "Change Password",
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
                        controller: controllerCurrentPassword,
                        decoration: const InputDecoration(
                          labelText: "Current Password",
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
                      TextFormField(
                        style: TextStyle(color: Colors.white),
                        obscureText: true,
                        controller: controllerNewPassword,
                        decoration: const InputDecoration(
                          labelText: "New Password",
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
                              changePassword();
                              Navigator.pop(context);
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
                            "Change Password",
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
