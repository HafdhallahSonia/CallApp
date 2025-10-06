// pages/add_contact_page.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../db/db.dart';

class AddContactPage extends StatefulWidget {
  final Map<String, dynamic>? contact; // null = new, not null = edit
  final int userId; // ← Ajouté : obligatoire

  const AddContactPage({
    Key? key,
    this.contact,
    required this.userId, // ← requis
  }) : super(key: key);

  @override
  _AddContactPageState createState() => _AddContactPageState();
}

class _AddContactPageState extends State<AddContactPage> {
  final _firstnameController = TextEditingController();
  final _lastnameController = TextEditingController();
  final _phoneController = TextEditingController();
  File? _imageFile;
  int? _selectedCategId;

  final dbHelper = DbHelper();
  List<Map<String, dynamic>> _categories = [];
  final Color primaryColor = Color(0xFF263A96);

  @override
  void initState() {
    super.initState();
    _loadCategories();

    if (widget.contact != null) {
      _firstnameController.text = widget.contact!['firstname'] ?? '';
      _lastnameController.text = widget.contact!['lastname'] ?? '';
      _phoneController.text = widget.contact!['phone'] ?? '';
      if (widget.contact!['photo'] != null &&
          widget.contact!['photo'].toString().isNotEmpty) {
        _imageFile = File(widget.contact!['photo']);
      }
      _selectedCategId = widget.contact!['categ_id'];
    }
  }

  @override
  void dispose() {
    _firstnameController.dispose();
    _lastnameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _loadCategories() async {
    // ✅ Charger uniquement les catégories de l'utilisateur
    final data = await dbHelper.getCategs(widget.userId);
    setState(() {
      _categories = data;
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  void _saveContact() async {
    String firstname = _firstnameController.text.trim();
    String lastname = _lastnameController.text.trim();
    String phone = _phoneController.text.trim();
    String? photoPath = _imageFile?.path;

    if (firstname.isEmpty || lastname.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('First, Last name, and Phone are required')),
      );
      return;
    }

    if (widget.contact == null) {
      // ✅ Ajout d'un NOUVEAU contact avec userId
      await dbHelper.insertContact(
        userId: widget.userId, // ← crucial
        firstname: firstname,
        lastname: lastname,
        phone: phone,
        photo: photoPath,
        categId: _selectedCategId,
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Contact added')));
    } else {
      // ✅ Mise à jour d'un contact EXISTANT avec userId (pour sécurité)
      await dbHelper.updateContact(
        contactId: widget.contact!['contact_id'],
        userId: widget.userId, // ← ajouté
        firstname: firstname,
        lastname: lastname,
        phone: phone,
        photo: photoPath,
        categId: _selectedCategId,
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Contact updated')));
    }

    Navigator.pop(context, true);
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType? type,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type ?? TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.contact == null ? 'Add Contact' : 'Edit Contact',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primaryColor,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildTextField(
                label: 'First Name',
                controller: _firstnameController,
              ),
              SizedBox(height: 12),
              _buildTextField(
                label: 'Last Name',
                controller: _lastnameController,
              ),
              SizedBox(height: 12),
              _buildTextField(
                label: 'Phone Number',
                controller: _phoneController,
                type: TextInputType.phone,
              ),
              SizedBox(height: 20),

              // Image Picker
              GestureDetector(
                onTap: _pickImage,
                child: _imageFile == null
                    ? Container(
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          size: 40,
                          color: Colors.grey[600],
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _imageFile!,
                          height: 120,
                          width: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
              SizedBox(height: 12),
              TextButton.icon(
                onPressed: _pickImage,
                icon: Icon(Icons.photo, color: primaryColor),
                label: Text(
                  'Pick Photo',
                  style: TextStyle(color: primaryColor),
                ),
              ),
              SizedBox(height: 20),

              // Category Dropdown
              DropdownButtonFormField<int>(
                isExpanded: true,
                value: _selectedCategId,
                hint: Text("Select Category"),
                items: _categories.map((categ) {
                  return DropdownMenuItem<int>(
                    value: categ['categ_id'],
                    child: Text(categ['categ_name']),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedCategId = value),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _saveContact,
                  child: Text(
                    widget.contact == null ? 'Save Contact' : 'Update Contact',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
