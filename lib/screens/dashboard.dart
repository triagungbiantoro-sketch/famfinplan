import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'kendaraan_screen.dart';
import 'income_screen.dart';
import 'expense_screen.dart';
import 'budgeting_screen.dart';
import 'settings_screen.dart';
import 'summary_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final List<_DashboardMenu> menuItems = [
      _DashboardMenu(
        icon: Icons.account_balance_wallet,
        label: tr("income"),
        color: Colors.green,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const IncomeScreen()),
          );
        },
      ),
      _DashboardMenu(
        icon: Icons.shopping_cart,
        label: tr("expense"),
        color: Colors.red,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ExpenseScreen()),
          );
        },
      ),
      _DashboardMenu(
        icon: Icons.bar_chart,
        label: tr("budget"),
        color: Colors.blue,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BudgetingScreen()),
          );
        },
      ),
      _DashboardMenu(
        icon: Icons.tune,
        label: tr("settings"),
        color: Colors.orange,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          );
        },
      ),
      _DashboardMenu(
        icon: Icons.directions_car,
        label: tr("vehicle"),
        color: Colors.purple,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => VehicleScreen()),
          );
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 15,
        title: Image.asset(
          "assets/images/logo.png",
          height: 80,
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Container(
        color: Colors.green.withOpacity(0.05), // ultra tipis hijau
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Judul Ringkasan
              Padding(
                padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
                child: Row(
                  children: [
                    const Icon(Icons.insights, color: Colors.blueAccent),
                    const SizedBox(width: 8),
                    Text(
                      tr("monthly_summary"),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                    ),
                  ],
                ),
              ),

              // Ringkasan
              SummaryCard(
                selectedMonth: _selectedMonth,
                selectedYear: _selectedYear,
                onMonthChanged: (val) => setState(() => _selectedMonth = val),
                onYearChanged: (val) => setState(() => _selectedYear = val),
              ),

              const SizedBox(height: 28),

              // Menu Navigasi
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: menuItems.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 20,
                    childAspectRatio: 0.8,
                  ),
                  itemBuilder: (context, index) {
                    final menu = menuItems[index];
                    return _buildMenuItem(
                      context,
                      icon: menu.icon,
                      label: menu.label,
                      color: menu.color,
                      onTap: menu.onTap,
                    );
                  },
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isPressed = false;
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: color.withOpacity(0.2),
          onTap: onTap,
          onTapDown: (_) => setState(() => isPressed = true),
          onTapUp: (_) => setState(() => isPressed = false),
          onTapCancel: () => setState(() => isPressed = false),
          child: AnimatedScale(
            scale: isPressed ? 0.9 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.15),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.transparent,
                    child: Icon(icon, size: 28, color: color),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DashboardMenu {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  _DashboardMenu({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}
