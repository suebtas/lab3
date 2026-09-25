import 'package:flutter/material.dart';

import '../core/money.dart';
import '../data/employee_store.dart';
import '../domain/models/employee_type.dart';
import '../domain/payroll_engine.dart';
import '../domain/payroll_summary_entity.dart';

class PayrollEvaluationScreen extends StatefulWidget {
  const PayrollEvaluationScreen({super.key, required this.store});

  final EmployeeStore store;

  @override
  State<PayrollEvaluationScreen> createState() =>
      _PayrollEvaluationScreenState();
}

class _PayrollEvaluationScreenState extends State<PayrollEvaluationScreen> {
  static const _engine = PayrollEngine();
  static const _all = 'ทั้งหมด';

  final _searchController = TextEditingController();
  String _filter = _all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PayrollRecord> _visibleRecords() {
    final records = _engine.evaluateAll(widget.store.employees);
    final query = _searchController.text.trim().toLowerCase();
    return records.where((record) {
      final matchesType = _filter == _all || record.employee.type.label == _filter;
      final matchesQuery = query.isEmpty ||
          record.employee.fullName.toLowerCase().contains(query) ||
          record.employee.id.toLowerCase().contains(query);
      return matchesType && matchesQuery;
    }).toList();
  }

  void _exportReport(List<PayrollRecord> records) {
    final totalNet =
        records.fold(0, (sum, record) => sum + record.netPay);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('บันทึกผลลัพธ์เรียบร้อย: ${records.length} ราย ยอดสุทธิ ${formatBaht(totalNet)}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final records = _visibleRecords();
    final summary = widget.store.summary;
    return Scaffold(
      appBar: AppBar(title: const Text('ประเมินผลสิ้นเดือน')),
      body: SafeArea(
        child: Column(
          children: [
            _SummaryDashboardRow(summary: summary),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'ค้นหารายชื่อพนักงาน...',
                        prefixIcon: Icon(Icons.search_rounded),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _filter,
                    onChanged: (value) =>
                        setState(() => _filter = value ?? _all),
                    items: [
                      _all,
                      ...EmployeeType.values.map((type) => type.label),
                    ]
                        .map((label) =>
                            DropdownMenuItem(value: label, child: Text(label)))
                        .toList(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: records.isEmpty
                  ? const Center(child: Text('ไม่พบรายชื่อพนักงาน'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: records.length,
                      itemBuilder: (context, index) =>
                          _PayrollCard(record: records[index]),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _StickyActionBar(
        onPressed: () => _exportReport(records),
      ),
    );
  }
}

class _SummaryDashboardRow extends StatelessWidget {
  const _SummaryDashboardRow({required this.summary});

  final PayrollSummaryEntity summary;

  @override
  Widget build(BuildContext context) {
    final records = summary.records;
    final totalNet = records.fold(0, (sum, record) => sum + record.netPay);
    final totalBonus =
        records.fold(0, (sum, record) => sum + record.bonus);
    final totalTax = records.fold(0, (sum, record) => sum + record.tax);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.monetization_on_rounded),
                SizedBox(width: 8),
                Text('รายงานสรุปการจ่ายเงิน (Payroll Summary)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            _labelValue('พนักงานรวม', '${summary.totalActiveEmployees} คน'),
            _labelValue('ยอดชำระสุทธิทั้งหมด', formatBaht(totalNet)),
            _labelValue('โบนัสรวม', formatBaht(totalBonus)),
            _labelValue('ภาษีหัก ณ ที่จ่ายรวม', formatBaht(totalTax)),
          ],
        ),
      ),
    );
  }

  Widget _labelValue(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _PayrollCard extends StatelessWidget {
  const _PayrollCard({required this.record});

  final PayrollRecord record;

  String get _bonusPercentage {
    final rate = (record.bonus * 100 / record.employee.salary).round();
    return '$rate%';
  }

  @override
  Widget build(BuildContext context) {
    final employee = record.employee;
    final isIntern = employee.type == EmployeeType.intern;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.badge_rounded),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${employee.fullName} (${employee.type.label})',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _row('เงินเดือนพื้นฐาน', formatBaht(employee.salary)),
            _row('โบนัส ($_bonusPercentage)', formatBaht(record.bonus)),
            _row(
              isIntern ? 'ภาษีพิเศษ (1%)' : 'ภาษีหัก ณ ที่จ่าย (3%)',
              formatBaht(record.tax),
            ),
            const Divider(height: 16),
            _row('ยอดรับสุทธิ', formatBaht(record.netPay),
                emphasized: true),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool emphasized = false}) {
    final style = emphasized
        ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)
        : const TextStyle(fontSize: 13);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}

class _StickyActionBar extends StatelessWidget {
  const _StickyActionBar({required this.onPressed});

  final VoidCallback onPressed;

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
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.description_rounded),
          label: const Text('บันทึกผลลัพธ์และออกรายงาน'),
        ),
      ),
    );
  }
}