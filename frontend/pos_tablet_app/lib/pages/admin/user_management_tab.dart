import 'package:flutter/material.dart';
import '../../state/pos_store.dart';

class UserManagementTab extends StatefulWidget {
  const UserManagementTab({required this.store, required this.surfaceColor});

  final PosStore store;
  final Color surfaceColor;

  @override
  State<UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends State<UserManagementTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.store.loadUsers();
    });
  }

  void _showAddUserDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String? selectedRole;
    String? selectedOutlet;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: widget.surfaceColor,
            title: const Text('Tambah User Baru', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama Lengkap')),
                  const SizedBox(height: 12),
                  TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email Address')),
                  const SizedBox(height: 12),
                  TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Role Akses'),
                    value: selectedRole,
                    items: widget.store.rolesList.map((r) => DropdownMenuItem(value: r['id'].toString(), child: Text(r['role_name']))).toList(),
                    onChanged: (v) => setDialogState(() => selectedRole = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Outlet Penempatan'),
                    value: selectedOutlet,
                    items: widget.store.outletsList.map((o) => DropdownMenuItem(value: o['id'].toString(), child: Text(o['outlet_name']))).toList(),
                    onChanged: (v) => setDialogState(() => selectedOutlet = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty || passCtrl.text.isEmpty || selectedRole == null || selectedOutlet == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Semua field harus diisi')));
                    return;
                  }
                  Navigator.pop(ctx);
                  await widget.store.createUser({
                    'name': nameCtrl.text,
                    'email': emailCtrl.text,
                    'password': passCtrl.text,
                    'role_id': int.parse(selectedRole!),
                    'outlet_id': int.parse(selectedOutlet!),
                  });
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.store.status)));
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        }
      ),
    );
  }

  void _showResetPasswordDialog(Map<String, dynamic> user) {
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.surfaceColor,
        title: Text('Reset Password ${user['name']}'),
        content: TextField(
          controller: passCtrl,
          decoration: const InputDecoration(labelText: 'Password Baru'),
          obscureText: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (passCtrl.text.isEmpty || passCtrl.text.length < 6) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password minimal 6 karakter')));
                 return;
              }
              Navigator.pop(ctx);
              await widget.store.resetUserPassword(user['id'], passCtrl.text);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.store.status)));
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _deleteUser(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.surfaceColor,
        title: const Text('Hapus User?'),
        content: Text('Anda yakin ingin menghapus ${user['name']}? Aksi ini tidak bisa dibatalkan.'),
        actions: [
           TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
           ElevatedButton(
             style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
             onPressed: () async {
               Navigator.pop(ctx);
               await widget.store.deleteUser(user['id']);
               if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.store.status)));
             },
             child: const Text('Hapus', style: TextStyle(color: Colors.white)),
           ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Manajemen User', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1f2d2e))),
              Row(
                children: [
                  IconButton(
                    onPressed: () => widget.store.loadUsers(),
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _showAddUserDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('User Baru'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (widget.store.usersLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (widget.store.usersList.isEmpty)
          const Expanded(child: Center(child: Text('Tidak ada data user', style: TextStyle(color: Colors.grey))))
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: widget.store.usersList.length,
              itemBuilder: (context, index) {
                final user = widget.store.usersList[index];
                final isActive = user['is_active'] == 1 || user['is_active'] == true;
                
                return Card(
                  color: widget.surfaceColor,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                           backgroundColor: const Color(0xFF1E6F62).withOpacity(0.1),
                           child: Text(user['name'].substring(0, 1).toUpperCase(), style: const TextStyle(color: Color(0xFF1E6F62), fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('${user['email']} • ${user['role_display']}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isActive ? 'Aktif' : 'Nonaktif',
                            style: TextStyle(color: isActive ? Colors.green.shade800 : Colors.red.shade800, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 16),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.grey),
                          onSelected: (val) async {
                            if (val == 'toggle') {
                              await widget.store.toggleUserActive(user['id']);
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.store.status)));
                            } else if (val == 'reset') {
                              _showResetPasswordDialog(user);
                            } else if (val == 'delete') {
                              _deleteUser(user);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(value: 'toggle', child: Text(isActive ? 'Nonaktifkan User' : 'Aktifkan User')),
                            const PopupMenuItem(value: 'reset', child: Text('Reset Password')),
                            const PopupMenuItem(value: 'delete', child: Text('Hapus User', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
