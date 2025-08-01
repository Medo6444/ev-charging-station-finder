import 'package:flutter/material.dart';
import '../firebase/auth_services.dart';

class UpdateUsernamePage extends StatefulWidget {
  const UpdateUsernamePage({super.key});

  @override
  State<UpdateUsernamePage> createState() => _UpdateUsernamePageState();
}

class _UpdateUsernamePageState extends State<UpdateUsernamePage> {
  TextEditingController controllerUsername = TextEditingController();
  final formKey = GlobalKey<FormState>();
  String errorMessage = "";

  @override
  void dispose() {
    controllerUsername.dispose();
    super.dispose();
  }

  void changeUsername() async {
    try {
      await authService.value.updateUsername(username: controllerUsername.text);
      showSnackBarSuccess();
      popPage();
    } catch (e) {
      showSnackBarFailure();
    }
  }

  void popPage() {
    Navigator.pop(context);
  }

  void showSnackBarSuccess() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        content: Text("Username changed successfully"),
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
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            children: [
              const SizedBox(height: 60),
              const Text(
                "Change Username",
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
                        controller: controllerUsername,
                        decoration: const InputDecoration(
                          labelText: "Username",
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
                              changeUsername();
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
                            "Update Username",
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
