/// Demo accounts for the GLD login screen.
///
/// DEMO ONLY: these usernames and passwords are built into the app, so anyone
/// who has the APK can read them. Don't reuse a real password here.
class DummyUser {
  const DummyUser({
    required this.name,
    required this.username,
    required this.password,
    required this.role,
  });

  final String name;
  final String username;
  final String password;
  final String role;
}

const dummyUsers = [
  DummyUser(name: 'Student 1', username: 'student1', password: '123', role: 'Student'),
  DummyUser(name: 'Student 2', username: 'student2', password: '123', role: 'Student'),
];
