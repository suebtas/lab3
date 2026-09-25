import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/employee_store.dart';
import '../domain/models/department.dart';
import '../domain/models/employee_model.dart';
import '../domain/models/employee_type.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.store});

  final EmployeeStore store;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();

  EmployeeType _type = EmployeeType.permanent;
  Department _department = Department.it;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _salaryController = TextEditingController();
  final _skillInputController = TextEditingController();
  final _primaryPhoneController = TextEditingController();
  final _backupPhoneController = TextEditingController();

  final List<String> _skills = [];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    _nicknameController.dispose();
    _salaryController.dispose();
    _skillInputController.dispose();
    _primaryPhoneController.dispose();
    _backupPhoneController.dispose();
    super.dispose();
  }

  double get _completionRate {
    var filled = 0.0;
    const required = 7.0;
    if (_firstNameController.text.trim().isNotEmpty) filled++;
    if (_lastNameController.text.trim().isNotEmpty) filled++;
    if (_ageController.text.trim().isNotEmpty) filled++;
    if (_salaryController.text.trim().isNotEmpty) filled++;
    if (_primaryPhoneController.text.trim().isNotEmpty) filled++;
    if (_skills.isNotEmpty) filled++;
    filled++;
    return (filled / required).clamp(0.0, 1.0);
  }

  void _addSkill() {
    final value = _skillInputController.text.trim();
    if (value.isEmpty || _skills.contains(value)) return;
    setState(() => _skills.add(value));
    _skillInputController.clear();
  }

  Future<bool> _confirmExit() async {
    final hasData =
        _firstNameController.text.isNotEmpty ||
            _lastNameController.text.isNotEmpty ||
            _ageController.text.isNotEmpty ||
            _salaryController.text.isNotEmpty ||
            _primaryPhoneController.text.isNotEmpty ||
            _skills.isNotEmpty;
    if (!hasData) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยกเลิกการกรอกข้อมูล?'),
        content: const Text('ข้อมูลที่กรอกไว้จะไม่ถูกบันทึก'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('อยู่ต่อ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ออกจากหน้า'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกข้อมูลให้ครบถ้วน')),
      );
      return;
    }
    final number = widget.store.employees.length + 1;
    final id = 'EMP-${number.toString().padLeft(3, '0')}';
    final employee = Employee.fromType(
      _type,
      id: id,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      age: int.parse(_ageController.text.trim()),
      department: _department,
      salary: int.parse(_salaryController.text.trim()),
      nickname: _nicknameController.text.trim().isEmpty
          ? null
          : _nicknameController.text.trim(),
      backupPhoneNumber: _backupPhoneController.text.trim().isEmpty
          ? null
          : _backupPhoneController.text.trim(),
      phoneNumber: _primaryPhoneController.text.trim(),
      skills: _skills,
    );
    widget.store.addEmployee(employee);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('บันทึกข้อมูล ${employee.fullName} แล้ว')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmExit() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () async {
            if (await _confirmExit() && context.mounted) {
              Navigator.of(context).pop();
            }
          }),
          title: const Text('เพิ่มพนักงานใหม่'),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: _completionRate,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${(_completionRate * 100).round()}%',
                        style: Theme.of(context).textTheme.labelMedium),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _Card(
                          title: 'ประเภทพนักงาน',
                          child: SegmentedButton<EmployeeType>(
                            segments: EmployeeType.values
                                .map((type) => ButtonSegment(
                                      value: type,
                                      label: Text(type.label),
                                    ))
                                .toList(),
                            selected: {_type},
                            onSelectionChanged: (selection) =>
                                setState(() => _type = selection.first),
                          ),
                        ),
                        _Card(
                          title: 'ข้อมูลพื้นฐาน',
                          child: Column(
                            children: [
                              _buildTextFormField(
                                controller: _firstNameController,
                                label: 'ชื่อจริง *',
                              ),
                              _buildTextFormField(
                                controller: _lastNameController,
                                label: 'นามสกุล *',
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTextFormField(
                                      controller: _ageController,
                                      label: 'อายุ *',
                                      keyboardType: TextInputType.number,
                                      formatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildTextFormField(
                                      controller: _nicknameController,
                                      label: 'ชื่อเล่น (Optional)',
                                      optional: true,
                                    ),
                                  ),
                                ],
                              ),
                              DropdownButtonFormField<Department>(
                                initialValue: _department,
                                decoration: const InputDecoration(
                                  labelText: 'แผนก *',
                                  border: OutlineInputBorder(),
                                ),
                                items: Department.values
                                    .map((department) =>
                                        DropdownMenuItem(
                                          value: department,
                                          child: Text(department.label),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _department = value);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        _Card(
                          title: 'ข้อมูลเพิ่มเติม',
                          child: Column(
                            children: [
                              _buildTextFormField(
                                controller: _salaryController,
                                label: 'เงินเดือนเริ่มต้น *',
                                prefixText: '฿',
                                keyboardType: TextInputType.number,
                                formatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text('ทักษะ',
                                    style: Theme.of(context).textTheme.bodyMedium),
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _skillInputController,
                                      decoration: const InputDecoration(
                                        hintText: 'พิมพ์เพิ่มทักษะแล้วกด +',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      onSubmitted: (_) => _addSkill(),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.filled(
                                    onPressed: _addSkill,
                                    icon: const Icon(Icons.add_rounded),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (_skills.isNotEmpty)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _skills
                                        .map((skill) => InputChip(
                                              label: Text(skill),
                                              onDeleted: () => setState(
                                                  () => _skills.remove(skill)),
                                            ))
                                        .toList(),
                                  ),
                                ),
                              const SizedBox(height: 12),
                              _buildTextFormField(
                                controller: _primaryPhoneController,
                                label: 'เบอร์โทรหลัก *',
                                keyboardType: TextInputType.phone,
                              ),
                              _buildTextFormField(
                                controller: _backupPhoneController,
                                label: 'เบอร์โทรสำรอง (Optional)',
                                optional: true,
                                keyboardType: TextInputType.phone,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _StickySaveBar(
                completionRate: _completionRate,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    bool optional = false,
    String? prefixText,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      decoration: InputDecoration(
        labelText: label,
        prefixText: optional ? null : prefixText,
        border: const OutlineInputBorder(),
      ),
      validator: optional
          ? null
          : (value) {
              if (value == null || value.trim().isEmpty) {
                return 'กรุณากรอกข้อมูล';
              }
              if (label.startsWith('อายุ') || label.startsWith('เงินเดือน')) {
                final number = int.tryParse(value.trim());
                if (number == null || number <= 0) {
                  return 'กรุณากรอกตัวเลขที่มากกว่า 0';
                }
              }
              return null;
            },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _StickySaveBar extends StatelessWidget {
  const _StickySaveBar({required this.completionRate, required this.onPressed});

  final double completionRate;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.save_rounded),
          label: const Text('บันทึกข้อมูลพนักงาน'),
        ),
      ),
    );
  }
}