import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:grad02/firebase/auth_services.dart';
import 'package:grad02/pages/change_password_page.dart';
import 'package:grad02/pages/delete_account_page.dart';
import 'package:grad02/pages/update_username_page.dart';
import 'package:grad02/pages/welcome_page.dart';

class SideMenu extends StatefulWidget {
  final Function()? onHomeLocationTap; // Callback for home location
  final Function()? onNavigateToHomeTap; // Callback for navigate to home

  const SideMenu({super.key, this.onHomeLocationTap, this.onNavigateToHomeTap});

  @override
  State<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> {
  void logout() async {
    try {
      await authService.value.signOut();
      snackBarSuccess();
      popPage();
    } on FirebaseAuthException {
      snackBarFailed();
    }
  }

  void snackBarSuccess() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Logout Successful"),
        backgroundColor: Colors.greenAccent.shade700,
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
      ),
    );
  }

  void snackBarFailed() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Logout Failed"),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
      ),
    );
  }

  void popPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => WelcomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: 288,
        height: double.infinity,
        color: Color(0xFF1F1F1F),
        child: SafeArea(
          child: Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.greenAccent.shade700,
                  child: Icon(Icons.person, color: Color(0xFF1F1F1F)),
                ),
                title: Text(
                  FirebaseAuth.instance.currentUser?.displayName ?? "Guest",
                  style: TextStyle(color: Colors.greenAccent.shade700),
                ),
                subtitle: Text(
                  FirebaseAuth.instance.currentUser?.email ?? "No email found",
                  style: TextStyle(color: Colors.greenAccent.shade700),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 24, top: 32, bottom: 16),
                child: Text(
                  "Account Management",
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    color: Colors.greenAccent.shade700,
                  ),
                ),
              ),
              ListTile(
                leading: SizedBox(
                  height: 34,
                  width: 34,
                  child: Icon(Icons.person, color: Colors.greenAccent.shade700),
                ),
                title: Text(
                  "Change Username",
                  style: TextStyle(color: Colors.greenAccent.shade700),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UpdateUsernamePage(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: SizedBox(
                  width: 34,
                  height: 34,
                  child: Icon(
                    Icons.password,
                    color: Colors.greenAccent.shade700,
                  ),
                ),
                title: Text(
                  "Change Password",
                  style: TextStyle(color: Colors.greenAccent.shade700),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChangePasswordPage(),
                    ),
                  );
                },
              ),
              // NEW HOME LOCATION BUTTON
              ListTile(
                leading: SizedBox(
                  height: 34,
                  width: 34,
                  child: Icon(
                    Icons.home_outlined,
                    color: Colors.greenAccent.shade700,
                  ),
                ),
                title: Text(
                  "Update/Add Home Location",
                  style: TextStyle(color: Colors.greenAccent.shade700),
                ),
                onTap: () {
                  // Call the callback function to trigger home location mode
                  if (widget.onHomeLocationTap != null) {
                    widget.onHomeLocationTap!();
                  }
                },
              ),
              // NEW NAVIGATE TO HOME BUTTON
              ListTile(
                leading: SizedBox(
                  height: 34,
                  width: 34,
                  child: Icon(
                    Icons.navigation,
                    color: Colors.greenAccent.shade700,
                  ),
                ),
                title: Text(
                  "Navigate to Home",
                  style: TextStyle(color: Colors.greenAccent.shade700),
                ),
                onTap: () {
                  // Call the callback function to navigate to home
                  if (widget.onNavigateToHomeTap != null) {
                    widget.onNavigateToHomeTap!();
                  }
                },
              ),
              ListTile(
                leading: SizedBox(
                  height: 34,
                  width: 34,
                  child: Icon(Icons.delete, color: Colors.redAccent),
                ),
                title: Text(
                  "Delete Account",
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DeleteAccountPage(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: SizedBox(
                  height: 34,
                  width: 34,
                  child: Icon(Icons.logout, color: Colors.redAccent),
                ),
                title: Text(
                  "Logout",
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  logout();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
