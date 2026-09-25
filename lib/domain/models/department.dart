enum Department {
  it('IT'),
  hr('HR'),
  design('Design'),
  other('อื่นๆ');

  const Department(this.label);

  final String label;
}