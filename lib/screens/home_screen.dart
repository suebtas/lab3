import 'package:flutter/material.dart';

import '../data/employee_store.dart';
import '../domain/payroll_summary_entity.dart';
import '../core/money.dart';
import 'department_filter_screen.dart';
import 'executive_overview_screen.dart';
import 'onboarding_screen.dart';
import 'payroll_evaluation_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.store});

  final EmployeeStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Startup HR')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final summary = store.summary;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SummaryCard(summary: summary),
                const SizedBox(height: 16),
                _FeatureCard(
                  icon: Icons.person_add_alt_1_rounded,
                  title: 'เพิ่มพนักงานใหม่',
                  subtitle: 'Employee Onboarding',
                  color: Colors.indigo,
                  onTap: () => _push(context, OnboardingScreen(store: store)),
                ),
                _FeatureCard(
                  icon: Icons.calculate_rounded,
                  title: 'ประเมินผลสิ้นเดือน',
                  subtitle: 'End-of-Month Payroll Evaluation',
                  color: Colors.teal,
                  onTap: () =>
                      _push(context, PayrollEvaluationScreen(store: store)),
                ),
                _FeatureCard(
                  icon: Icons.groups_rounded,
                  title: 'คัดกรองแผนก & พัฒนาบุคลากร',
                  subtitle: 'Department Filters & Recommendations',
                  color: Colors.deepOrange,
                  onTap: () => _push(context, DepartmentFilterScreen(store: store)),
                ),
                _FeatureCard(
                  icon: Icons.assessment_rounded,
                  title: 'ภาพรวมรายจ่ายสำหรับผู้บริหาร',
                  subtitle: 'Executive Financial Overview',
                  color: Colors.purple,
                  onTap: () =>
                      _push(context, ExecutiveOverviewScreen(store: store)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final PayrollSummaryEntity summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ภาพรวม ณ ปัจจุบัน',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('พนักงานทั้งหมด'),
                Text('${summary.totalActiveEmployees} คน'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('ค่าใช้จ่ายรวมรายเดือน'),
                Text(formatBaht(summary.grandTotalExpenses),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}