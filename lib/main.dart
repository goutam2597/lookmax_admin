import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/admin_auth_provider.dart';
import 'screens/activity_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/purchases_screen.dart';
import 'screens/users_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    ChangeNotifierProvider(
      create: (_) => AdminAuthProvider(),
      child: const LookAdminApp(),
    ),
  );
}

class LookAdminApp extends StatelessWidget {
  const LookAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LookMaxing Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0E0E0E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFD4AF37),
          surface: Color(0xFF1A1A1A),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF141414),
          elevation: 0,
        ),
      ),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AdminAuthProvider>();

    if (auth.loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0E0E0E),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFFD4AF37)),
              SizedBox(height: 16),
              Text(
                'LookMaxing Admin',
                style: TextStyle(color: Color(0xFFD4AF37), fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    if (auth.user == null || !auth.isAdmin) {
      return const LoginScreen();
    }

    return const _MainShell();
  }
}

class _MainShell extends StatefulWidget {
  const _MainShell();
  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _index = 0;

  static const _screens = [
    DashboardScreen(),
    UsersScreen(),
    PurchasesScreen(),
    ActivityScreen(),
    NotificationsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AdminAuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '✦ LookMaxing Admin',
          style: TextStyle(
            color: Color(0xFFD4AF37),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white54),
            tooltip: 'Logout',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: const Color(0xFF181818),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: Color(0xFF2C2C2C)),
                  ),
                  title: const Text(
                    'Logout',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  content: const Text(
                    'Are you sure you want to logout from the admin panel?',
                    style: TextStyle(color: Colors.white60, fontSize: 14),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white38),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'Logout',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              );
              if (confirmed == true) auth.signOut();
            },
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: _BottomNav(
        selectedIndex: _index,
        onTap: (i) {
          HapticFeedback.selectionClick();
          setState(() => _index = i);
        },
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.selectedIndex, required this.onTap});

  static const _items = [
    (
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      label: 'Stats',
    ),
    (
      icon: Icons.people_outline,
      activeIcon: Icons.people_rounded,
      label: 'Users',
    ),
    (
      icon: Icons.payments_outlined,
      activeIcon: Icons.payments_rounded,
      label: 'Purchases',
    ),
    (
      icon: Icons.timeline_outlined,
      activeIcon: Icons.timeline_rounded,
      label: 'Activity',
    ),
    (
      icon: Icons.notifications_outlined,
      activeIcon: Icons.notifications_rounded,
      label: 'Push',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 20),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: List.generate(_items.length, (i) {
            final item = _items[i];
            return Expanded(
              child: _NavTile(
                icon: item.icon,
                activeIcon: item.activeIcon,
                label: item.label,
                selected: selectedIndex == i,
                onTap: () => onTap(i),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const _gold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    final inactiveColor = Colors.white.withValues(alpha: 0.35);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? _gold.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                selected ? activeIcon : icon,
                key: ValueKey(selected),
                color: selected ? _gold : inactiveColor,
                size: 22,
              ),
            ),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected ? _gold : inactiveColor,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
