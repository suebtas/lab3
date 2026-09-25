import 'package:flutter/material.dart';

import '../core/money.dart';
import '../data/employee_store.dart';
import '../domain/models/department.dart';
import '../domain/payroll_summary_entity.dart';

class ExecutiveOverviewScreen extends StatefulWidget {
  const ExecutiveOverviewScreen({super.key, required this.store});

  final EmployeeStore store;

  @override
  State<ExecutiveOverviewScreen> createState() => _ExecutiveOverviewScreenState();
}

class _ExecutiveOverviewScreenState extends State<ExecutiveOverviewScreen> {
  bool _approved = false;

  Future<void> _approve(PayrollSummaryEntity summary) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการอนุมัติ'),
        content: Text(
            'จะอนุมัติการจ่ายเงิน ${formatBaht(summary.grandTotalExpenses)} ประจำเดือนนี้ ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยันอนุมัติ'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _approved = true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('อนุมัติการจ่ายเงินเรียบร้อย')),
      );
    }
  }

  void _reject() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ส่งกลับแก้ไข: รอการปรับปรุงข้อมูลก่อนอนุมัติ')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ภาพรวมรายจ่ายสำหรับผู้บริหาร')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final summary = widget.store.summary;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _StatusBadge(approved: _approved),
                  const SizedBox(height: 12),
                  _HeroExpenseCard(summary: summary),
                  const SizedBox(height: 12),
                  _HeadcountCard(summary: summary),
                  const SizedBox(height: 12),
                  _DepartmentSpendingCard(summary: summary),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: _ApprovalActionBar(
        onApprove: () async {
          final summary = widget.store.summary;
          if (!_approved) await _approve(summary);
        },
        onReject: _reject,
        approved: _approved,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.approved});

  final bool approved;

  @override
  Widget build(BuildContext context) {
    final background = approved
        ? const Color(0xFFE8F5E9)
        : const Color(0xFFFFF3E0);
    final foreground = approved
        ? const Color(0xFF2E7D32)
        : const Color(0xFFE65100);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(approved ? Icons.check_circle_rounded : Icons.pending_rounded,
              size: 18, color: foreground),
          const SizedBox(width: 8),
          Text(
            approved ? 'รอบบัญชี: อนุมัติแล้ว' : 'สถานะรอบบัญชี: รอการอนุมัติ',
            style: TextStyle(fontWeight: FontWeight.bold, color: foreground),
          ),
        ],
      ),
    );
  }
}

class _HeroExpenseCard extends StatelessWidget {
  const _HeroExpenseCard({required this.summary});

  final PayrollSummaryEntity summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      color: const Color(0xFF1A237E),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'ยอดค่าใช้จ่ายรวมทั้งสิ้นประจำเดือน',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              formatBaht(summary.grandTotalExpenses),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Divider(height: 24, color: Colors.white24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _sub('เงินเดือน', summary.totalSalaryExpenses),
                _sub('โบนัส', summary.totalBonusExpenses),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sub(String label, int value) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text(formatBaht(value),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _HeadcountCard extends StatelessWidget {
  const _HeadcountCard({required this.summary});

  final PayrollSummaryEntity summary;

  @override
  Widget build(BuildContext context) {
    final permanent = summary.countByType('พนักงานประจำ');
    final intern = summary.countByType('เด็กฝึกงาน');
    final manager = summary.countByType('ผู้จัดการ');
    return Card(
      child: ListTile(
        leading: const Icon(Icons.people_rounded),
        title: Text('พนักงานทั้งหมด: ${summary.totalActiveEmployees} คน'),
        subtitle: Text('ประจำ: $permanent | ฝึกงาน: $intern | ผู้จัดการ: $manager'),
      ),
    );
  }
}

class _DepartmentSpendingCard extends StatelessWidget {
  const _DepartmentSpendingCard({required this.summary});

  final PayrollSummaryEntity summary;

  @override
  Widget build(BuildContext context) {
    final departments = [Department.it, Department.design, Department.hr];
    final expenses = {
      for (final department in departments)
        department: summary.departmentExpense(department),
    };
    final maxExpense =
        expenses.values.fold<int>(0, (acc, value) => value > acc ? value : acc);
    final grandTotal = summary.grandTotalExpenses;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('สัดส่วนการชำระเงินแยกตามแผนก',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            for (final department in departments)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DepartmentBar(
                  department: department,
                  amount: expenses[department]!,
                  ratio: maxExpense == 0 ? 0 : expenses[department]! / maxExpense,
                  shareOfTotal: grandTotal == 0 ? 0 : expenses[department]! / grandTotal,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DepartmentBar extends StatelessWidget {
  const _DepartmentBar({
    required this.department,
    required this.amount,
    required this.ratio,
    required this.shareOfTotal,
  });

  final Department department;
  final int amount;
  final double ratio;
  final double shareOfTotal;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 64, child: Text('${department.label}:')),
        Expanded(
          child: LinearProgressIndicator(
            value: ratio,
            borderRadius: BorderRadius.circular(6),
            minHeight: 10,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${formatBaht(amount)} (${(shareOfTotal * 100).toStringAsFixed(1)}%)',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

class _ApprovalActionBar extends StatelessWidget {
  const _ApprovalActionBar({
    required this.onApprove,
    required this.onReject,
    required this.approved,
  });

  final VoidCallback onApprove;
  final VoidCallback onReject;
  final bool approved;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, -2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: onReject,
                icon: const Icon(Icons.undo_rounded),
                label: const Text('ส่งกลับแก้ไข'),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 7,
            child: SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: approved ? null : onApprove,
                icon: Icon(approved ? Icons.check_circle_rounded : Icons.verified_user_rounded),
                label: Text(approved ? 'อนุมัติแล้ว' : 'อนุมัติจ่ายเงินเดือน'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}