import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dashboard_screen.dart';
import 'attendance_screen.dart';
import 'leave_screen.dart';
import 'profile_screen.dart';
import '../services/auth_service.dart';
import '../models/user.dart';
import '../providers/app_provider.dart';

class SwitchTabNotification extends Notification {
  final int index;
  const SwitchTabNotification(this.index);
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  User? _user;
  bool _isAdmin = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    _user = await AuthService().getUser();
    _isAdmin = _user?.role == 'system_admin' || _user?.role == 'company_admin';
    setState(() {
      _isLoading = false;
    });
    if (mounted) {
      Provider.of<AppProvider>(context, listen: false).syncFcmToken();
    }
  }

  void _onBackPressed() {
    if (_selectedIndex != 0) {
      // If not on Home tab, go to Home tab
      setState(() {
        _selectedIndex = 0;
      });
    } else {
      // On Home tab, close app directly without dialog
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final List<Widget> screens = [
      const DashboardScreen(),
      const AttendanceScreen(),
      if (!_isAdmin) const LeaveScreen(),
      const ProfileScreen(),
    ];

    final List<BottomNavigationBarItem> items = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        activeIcon: Icon(Icons.home),
        label: 'Home',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.calendar_month_outlined),
        activeIcon: Icon(Icons.calendar_month),
        label: 'Attendance',
      ),
      if (!_isAdmin)
        const BottomNavigationBarItem(
          icon: Icon(Icons.work_off_outlined),
          activeIcon: Icon(Icons.work_off),
          label: 'Leaves',
        ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        activeIcon: Icon(Icons.person),
        label: 'Profile',
      ),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _onBackPressed();
        }
      },
      child: NotificationListener<SwitchTabNotification>(
        onNotification: (notification) {
          setState(() {
            _selectedIndex = notification.index;
          });
          return true;
        },
        child: Scaffold(
          body: IndexedStack(index: _selectedIndex, children: screens),
          bottomNavigationBar: SafeArea(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BottomNavigationBar(
                  currentIndex: _selectedIndex,
                  onTap: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: Colors.white,
                  selectedItemColor: Theme.of(context).primaryColor,
                  unselectedItemColor: const Color(0xFF64748B), // Slate 500
                  selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  unselectedLabelStyle: const TextStyle(fontSize: 11),
                  elevation: 0,
                  items: items,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
