import 'package:flutter/material.dart';

import '../data/employee_store.dart';
import '../domain/models/department.dart';
import '../domain/models/employee_model.dart';
import '../domain/recommendation_service.dart';

class DepartmentFilterScreen extends StatefulWidget {
  const DepartmentFilterScreen({super.key, required this.store});

  final EmployeeStore store;

  @override
  State<DepartmentFilterScreen> createState() => _DepartmentFilterScreenState();
}

class _DepartmentFilterScreenState extends State<DepartmentFilterScreen> {
  static const _recommendationService = RecommendationService();

  Department? _selected;

  List<Employee> get _visibleEmployees {
    final employees = widget.store.employees;
    if (_selected == null) return employees;
    return employees
        .where((employee) => employee.department == _selected)
        .toList();
  }

  String get _recommendation {
    return _recommendationService.getRecommendationText(
      _selected ?? Department.other,
    );
  }

  void _printReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('พิมพ์รายงาน: ${_visibleEmployees.length} คน (${_selected?.label ?? 'ทั้งหมด'})'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final employees = _visibleEmployees;
    return Scaffold(
      appBar: AppBar(title: const Text('คัดกรองแผนก & พัฒนาบุคลากร')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) => Column(
            children: [
              _DepartmentFilterBar(
                selected: _selected,
                onChanged: (department) =>
                    setState(() => _selected = department),
              ),
              _RecommendationCard(text: _recommendation),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'จำนวนพนักงานที่พบ: ${employees.length} คน',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
              Expanded(
                child: employees.isEmpty
                    ? const Center(child: Text('ไม่มีพนักงานในแผนกนี้'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: employees.length,
                        itemBuilder: (context, index) =>
                            _EmployeeCard(employee: employees[index]),
                      ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _StickyPrintBar(onPressed: _printReport),
    );
  }
}

class _DepartmentFilterBar extends StatelessWidget {
  const _DepartmentFilterBar({required this.selected, required this.onChanged});

  final Department? selected;
  final ValueChanged<Department?> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = <String, Department?>{
      'ทั้งหมด': null,
      'แผนก IT': Department.it,
      'แผนก HR': Department.hr,
      'แผนก Design': Department.design,
      'อื่นๆ': Department.other,
    };
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          for (final entry in options.entries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(entry.key),
                selected: selected == entry.value,
                onSelected: (_) => onChanged(entry.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.lightbulb_rounded,
              color: Theme.of(context).colorScheme.onTertiaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'คำแนะนำการพัฒนา: $text',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
          child: Text(
            employee.firstName.characters.first,
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ),
        title: Text('${employee.fullName} (${employee.department.label})'),
        subtitle: Text('Skills: ${employee.skills.join(', ')}'),
        isThreeLine: false,
      ),
    );
  }
}

class _StickyPrintBar extends StatelessWidget {
  const _StickyPrintBar({required this.onPressed});

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
          icon: const Icon(Icons.print_rounded),
          label: const Text('พิมพ์รายงานส่งต่อหัวหน้างาน'),
        ),
      ),
    );
  }
}