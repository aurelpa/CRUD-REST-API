
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String apiKey = 'free_user_3L8mf1KbHR6bfKma2bh7ZV8E98M';

void main() {
  runApp(const MyApp());
}

class UserModel {
  final int id;
  final String email;
  final String first_name;
  final String last_name;
  final String avatar;

  const UserModel({
    required this.id,
    required this.email,
    required this.first_name,
    required this.last_name,
    required this.avatar,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: int.tryParse('${json['id']}') ?? 0,
      email: json['email']?.toString() ?? '',
      first_name: json['first_name']?.toString() ?? '',
      last_name: json['last_name']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '',
    );
  }
}

class UserService {
  static const String baseUrl = 'https://reqres.in/api';

  Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
      };

  void checkResponse(
    http.Response response,
    List<int> successCodes,
  ) {
    if (!successCodes.contains(response.statusCode)) {
      String detail = response.body;

      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['message'] != null) {
          detail = decoded['message'].toString();
        } else if (decoded is Map && decoded['error'] != null) {
          detail = decoded['error'].toString();
        }
      } catch (_) {}

      throw Exception(
        'HTTP ${response.statusCode}: $detail',
      );
    }
  }

  String errorMessage(Object e) {
    final message = e.toString();

    if (e is http.ClientException ||
        message.contains('SocketException') ||
        message.contains('Failed host lookup') ||
        message.contains('XMLHttpRequest') ||
        message.contains('NetworkError')) {
      return 'Koneksi gagal. Periksa internet atau akses API.';
    }

    return message.replaceFirst('Exception: ', '');
  }

  Future<List<UserModel>> getUsers() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users?page=1'),
        headers: headers,
      );

      checkResponse(response, [200]);

      final decoded = jsonDecode(response.body);
      final List data = decoded['data'];

      return data
          .map((item) => UserModel.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception(errorMessage(e));
    }
  }

  Future<Map<String, dynamic>> createUser(
    String name,
    String job,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users'),
        headers: headers,
        body: jsonEncode({
          'name': name,
          'job': job,
        }),
      );

      checkResponse(response, [200, 201]);
      return Map<String, dynamic>.from(
        jsonDecode(response.body),
      );
    } catch (e) {
      throw Exception(errorMessage(e));
    }
  }

  Future<Map<String, dynamic>> updateUser(
    int id,
    String name,
    String job,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/users/$id'),
        headers: headers,
        body: jsonEncode({
          'name': name,
          'job': job,
        }),
      );

      checkResponse(response, [200]);
      return Map<String, dynamic>.from(
        jsonDecode(response.body),
      );
    } catch (e) {
      throw Exception(errorMessage(e));
    }
  }

  Future<void> deleteUser(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/users/$id'),
        headers: headers,
      );

      checkResponse(response, [200, 204]);
    } catch (e) {
      throw Exception(errorMessage(e));
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CRUD User API',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
        ),
        useMaterial3: true,
      ),
      home: const UserPage(),
    );
  }
}

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  final UserService service = UserService();

  late Future<List<UserModel>> futureUsers;

  final List<UserModel> addedUsers = [];
  final Map<int, UserModel> editedUsers = {};
  final Set<int> deletedIds = {};

  @override
  void initState() {
    super.initState();
    futureUsers = service.getUsers();
  }

  void refreshUsers() {
    setState(() {
      futureUsers = service.getUsers();
    });
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  List<UserModel> combineUsers(List<UserModel> serverUsers) {
    final result = <UserModel>[];

    for (final user in serverUsers) {
      if (deletedIds.contains(user.id)) continue;
      result.add(editedUsers[user.id] ?? user);
    }

    for (final user in addedUsers) {
      if (!deletedIds.contains(user.id)) {
        result.insert(0, user);
      }
    }

    return result;
  }

  void showUserForm({UserModel? user}) {
    final nameController = TextEditingController(
      text: user == null
          ? ''
          : '${user.first_name} ${user.last_name}'.trim(),
    );

    final jobController = TextEditingController(
      text: user == null ? '' : 'Mahasiswa',
    );

    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                user == null ? 'Tambah User' : 'Edit User',
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Lengkap',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.trim().isEmpty) {
                          return 'Nama wajib diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: jobController,
                      decoration: const InputDecoration(
                        labelText: 'Pekerjaan',
                        prefixIcon: Icon(Icons.work),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.trim().isEmpty) {
                          return 'Pekerjaan wajib diisi';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Batal'),
                ),
                FilledButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!
                              .validate()) {
                            return;
                          }

                          setDialogState(() {
                            saving = true;
                          });

                          try {
                            final name =
                                nameController.text.trim();
                            final job =
                                jobController.text.trim();

                            if (user == null) {
                              // POST
                              final response =
                                  await service.createUser(
                                name,
                                job,
                              );

                              final parts = name.split(' ');
                              final id = int.tryParse(
                                    '${response['id']}',
                                  ) ??
                                  DateTime.now()
                                      .millisecondsSinceEpoch;

                              final newUser = UserModel(
                                id: id,
                                email: '',
                                first_name: parts.first,
                                last_name: parts.length > 1
                                    ? parts.sublist(1).join(' ')
                                    : '',
                                avatar: '',
                              );

                              if (!mounted) return;

                              setState(() {
                                addedUsers.insert(0, newUser);
                                deletedIds.remove(id);
                              });

                              Navigator.pop(dialogContext);
                              showMessage(
                                'POST berhasil! User ditambahkan.',
                              );
                            } else {
                              // PUT
                              await service.updateUser(
                                user.id,
                                name,
                                job,
                              );

                              final parts = name.split(' ');

                              final updated = UserModel(
                                id: user.id,
                                email: user.email,
                                first_name: parts.first,
                                last_name: parts.length > 1
                                    ? parts.sublist(1).join(' ')
                                    : '',
                                avatar: user.avatar,
                              );

                              if (!mounted) return;

                              setState(() {
                                final localIndex =
                                    addedUsers.indexWhere(
                                  (item) => item.id == user.id,
                                );

                                if (localIndex >= 0) {
                                  addedUsers[localIndex] = updated;
                                } else {
                                  editedUsers[user.id] = updated;
                                }
                              });

                              Navigator.pop(dialogContext);
                              showMessage(
                                'PUT berhasil! User diperbarui.',
                              );
                            }
                          } catch (e) {
                            if (!mounted) return;

                            setDialogState(() {
                              saving = false;
                            });

                            showMessage('Gagal: $e');
                          }
                        },
                  icon: const Icon(Icons.save),
                  label: Text(saving ? 'Menyimpan...' : 'Simpan'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      nameController.dispose();
      jobController.dispose();
    });
  }

  Future<void> confirmDelete(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus User'),
        content: Text(
          'Yakin ingin menghapus '
          '${user.first_name} ${user.last_name}?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await service.deleteUser(user.id);

      if (!mounted) return;

      setState(() {
        deletedIds.add(user.id);
        addedUsers.removeWhere((item) => item.id == user.id);
        editedUsers.remove(user.id);
      });

      showMessage('DELETE berhasil! User dihapus.');
    } catch (e) {
      if (!mounted) return;
      showMessage('Gagal menghapus user: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manajemen User',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: refreshUsers,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang data',
          ),
        ],
      ),
      body: FutureBuilder<List<UserModel>>(
        future: futureUsers,
        builder: (context, snapshot) {
        
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Memuat data user...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 52,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Gagal Memuat Data',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: refreshUsers,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          final users = combineUsers(snapshot.data ?? []);

          if (users.isEmpty) {
            return const Center(
              child: Text('Belum ada data user.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),
                 
leading: CircleAvatar(
  radius: 26,
  backgroundColor: Colors.indigo.shade100,

  backgroundImage: user.avatar.isNotEmpty
      ? NetworkImage(user.avatar)
      : null,

  onBackgroundImageError: user.avatar.isNotEmpty
      ? (exception, stackTrace) {}
      : null,

  child: user.avatar.isEmpty
      ? const Icon(
          Icons.person,
          color: Colors.indigo,
        )
      : null,
),

                  title: Text(
                    '${user.first_name} ${user.last_name}'.trim(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${user.email.isEmpty ? 'Email belum tersedia' : user.email}'
                    '\nID: ${user.id}',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        showUserForm(user: user);
                      } else if (value == 'delete') {
                        confirmDelete(user);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit),
                            SizedBox(width: 8),
                            Text('Edit User'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Hapus User'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showUserForm(),
        icon: const Icon(Icons.person_add),
        label: const Text('Tambah User'),
      ),
    );
  }
}
