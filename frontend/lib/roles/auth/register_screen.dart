import 'package:flutter/material.dart';
import 'package:agripulse/shared/services/auth_service.dart';
import 'package:agripulse/shared/services/api_service.dart';

/// Account creation for any of the four roles. The chosen `role` decides which
/// dashboard the user lands on after the auto-login that follows registration.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _role = "farmer";
  int? _regionId;
  List<dynamic> _regions = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    try {
      final regions = await ApiService.instance.get("/regions");
      setState(() {
        _regions = regions;
        _regionId = regions.isNotEmpty ? regions.first["id"] : null;
      });
    } catch (_) {}
  }

  Future<void> _register() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.register(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        role: _role,
        regionId: _regionId,
      );
      if (!mounted) return;
      // Account created — go back to the login screen so the user signs in.
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account created — please log in.")),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create account")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: "Full name")),
            const SizedBox(height: 16),
            TextField(controller: _email, decoration: const InputDecoration(labelText: "Email")),
            const SizedBox(height: 16),
            TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: "Password")),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: "Role"),
              // Only farmer and seller can self-register. The analyst is a
              // system-created, admin-seeded account and is never registerable.
              items: const [
                DropdownMenuItem(value: "farmer", child: Text("Farmer")),
                DropdownMenuItem(value: "seller", child: Text("Seller")),
              ],
              onChanged: (v) => setState(() => _role = v!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _regionId,
              decoration: const InputDecoration(labelText: "Region"),
              items: _regions
                  .map((r) => DropdownMenuItem<int>(value: r["id"], child: Text(r["region_name"])))
                  .toList(),
              onChanged: (v) => setState(() => _regionId = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _register,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("Register"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
