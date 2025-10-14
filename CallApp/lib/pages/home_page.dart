import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import '../services/db.dart';
import '../services/auth_service.dart';
import 'addContact_screen.dart';
import 'categories_screen.dart';
import 'login_screen.dart';

class HomePage extends StatefulWidget {
  final String username;
  final int userId;

  const HomePage({
    Key? key,
    required this.username,
    required this.userId,
  }) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final dbHelper = DbHelper();
  String get username => widget.username;
  int get userId => widget.userId;

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allContacts = [];
  List<Map<String, dynamic>> _filteredContacts = [];
  List<Map<String, dynamic>> _categories = [];
  int? _selectedCategId;
  File? _userPhoto;
  bool _isUserPhotoLoading = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _loadCategories();
    _loadUserPhoto();
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterItems);
    _searchController.dispose();
    super.dispose();
  }

  // -------------------- Logout --------------------
  void _logout() async {
    final authService = AuthService();
    await authService.logout(); // Clear stored user info

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
      (route) => false,
    );
  }

  // -------------------- Load Data --------------------
  Future<void> _loadContacts() async {
    final data = await dbHelper.getContacts(userId);
    if (mounted) {
      setState(() {
        _allContacts = data;
        _filteredContacts = data;
      });
    }
  }

  Future<void> _loadCategories() async {
    final data = await dbHelper.getCategs(userId);
    if (mounted) setState(() => _categories = data);
  }

  Future<void> _loadUserPhoto() async {
    if (!mounted) return;
    setState(() => _isUserPhotoLoading = true);
    try {
      final user = await dbHelper.getUserById(userId);
      if (user != null && user.photoPath != null && user.photoPath!.isNotEmpty) {
        final file = File(user.photoPath!);
        if (await file.exists()) {
          setState(() => _userPhoto = file);
        }
      }
    } catch (_) {
      setState(() => _userPhoto = null);
    } finally {
      if (mounted) setState(() => _isUserPhotoLoading = false);
    }
  }

  Future<void> _deleteContact(int contactId) async {
    await dbHelper.deleteContact(contactId, userId);
    _loadContacts();
    _filterItems();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Contact deleted')));
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredContacts = _allContacts.where((contact) {
        final fname = contact['firstname']?.toLowerCase() ?? '';
        final lname = contact['lastname']?.toLowerCase() ?? '';
        final phone = contact['phone']?.toLowerCase() ?? '';
        final categ = contact['categ_name']?.toLowerCase() ?? '';
        final matchesSearch = fname.contains(query) || lname.contains(query) || phone.contains(query) || categ.contains(query);
        final matchesCategory = _selectedCategId == null || contact['categ_id'] == _selectedCategId;
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d\+]'), '');
    if (cleanNumber.isEmpty) return;
    if (Platform.isAndroid) {
      await FlutterPhoneDirectCaller.callNumber(phoneNumber);
    } else {
      await launchUrl(Uri(scheme: 'tel', path: cleanNumber));
    }
  }

  // -------------------- Widgets --------------------
  Widget _buildCategoryChips() {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ChoiceChip(
            label: const Text("All"),
            selected: _selectedCategId == null,
            selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
            labelStyle: TextStyle(
                color: _selectedCategId == null ? Theme.of(context).primaryColor : Colors.black),
            onSelected: (_) {
              setState(() => _selectedCategId = null);
              _filterItems();
            },
          ),
          ..._categories.map((c) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ChoiceChip(
                  label: Text(c['categ_name']),
                  selected: _selectedCategId == c['categ_id'],
                  selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                  labelStyle: TextStyle(
                      color: _selectedCategId == c['categ_id'] ? Theme.of(context).primaryColor : Colors.black),
                  onSelected: (_) {
                    setState(() => _selectedCategId = c['categ_id']);
                    _filterItems();
                  },
                ),
              ))
        ],
      ),
    );
  }

  void _showContactDetails(Map<String, dynamic> contact) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: contact['photo'] != null && contact['photo'].isNotEmpty
                      ? FileImage(File(contact['photo']))
                      : null,
                  child: contact['photo'] == null || contact['photo'].isEmpty
                      ? Icon(Icons.person, size: 40, color: Colors.grey[600])
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  "${contact['firstname']} ${contact['lastname']}",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                if (contact['categ_name'] != null) Text(
                  contact['categ_name'],
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (contact['phone'] != null) ...[
                  const Divider(),
                  const Text('Contact Information', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(Icons.phone, color: Colors.green),
                    title: Text(contact['phone']),
                    onTap: () => _makePhoneCall(contact['phone']),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      label: const Text('Edit'),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddContactPage(contact: contact, userId: userId),
                          ),
                        ).then((_) => _loadContacts());
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('Delete'),
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteContact(contact['contact_id']);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContactCard(Map<String, dynamic> contact) {
    return GestureDetector(
      onLongPress: () {
        showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
            builder: (ctx) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.edit, color: Colors.blue),
                      title: const Text("Edit"),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  AddContactPage(contact: contact, userId: userId)),
                        ).then((_) => _loadContacts());
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete, color: Colors.red),
                      title: const Text("Delete"),
                      onTap: () {
                        Navigator.pop(ctx);
                        _deleteContact(contact['contact_id']);
                      },
                    ),
                  ],
                ));
      },
      child: Card(
        elevation: 3,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          onTap: () => _showContactDetails(contact),
          leading: GestureDetector(
            onTap: () => _showContactDetails(contact),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey[200],
              backgroundImage: contact['photo'] != null && contact['photo'].isNotEmpty
                  ? FileImage(File(contact['photo']))
                  : null,
              child: contact['photo'] == null || contact['photo'].isEmpty
                  ? Icon(Icons.person, size: 28, color: Colors.grey[600])
                  : null,
            ),
          ),
          title: Text("${contact['firstname']} ${contact['lastname']}",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (contact['phone'] != null)
                Text("📞 ${contact['phone']}", style: TextStyle(color: Colors.black87)),
              Text("👤 ${contact['categ_name'] ?? 'No Category'}",
                  style: TextStyle(color: Colors.grey[700])),
            ],
          ),
          trailing: contact['phone'] != null
              ? IconButton(
                  icon: const Icon(Icons.call, color: Colors.green),
                  onPressed: () => _makePhoneCall(contact['phone']),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildContactList() {
    if (_filteredContacts.isEmpty) return const Center(child: Text("No contacts found"));
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredContacts.length,
      itemBuilder: (context, index) => _buildContactCard(_filteredContacts[index]),
    );
  }

  // -------------------- Build Scaffold --------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // -------------------- Custom Top Bar --------------------
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 2, blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  _isUserPhotoLoading
                      ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                      : CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          backgroundImage: _userPhoto != null ? FileImage(_userPhoto!) : null,
                          child: _userPhoto == null
                              ? const Icon(Icons.person, size: 28, color: Colors.white)
                              : null,
                        ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hello, $username',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 4),
                        const Text('Welcome back!',
                            style: TextStyle(fontSize: 14, color: Colors.white70)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    onPressed: _logout,
                    tooltip: 'Logout',
                  ),
                ],
              ),
            ),

            // -------------------- Body --------------------
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: "Search contacts...",
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.grey[200],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildCategoryChips(),
                    const SizedBox(height: 8),
                    _buildContactList(),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // -------------------- Floating Buttons --------------------
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: "manageCategories",
            backgroundColor: Theme.of(context).primaryColor,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CategoriesScreen(userId: userId)),
              ).then((_) => _loadCategories());
            },
            child: const Icon(Icons.category, color: Colors.white),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: "addContact",
            backgroundColor: Theme.of(context).primaryColor,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AddContactPage(userId: userId)),
              ).then((_) {
                _loadContacts();
                _filterItems();
              });
            },
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
