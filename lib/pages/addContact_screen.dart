import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/db.dart';

class AddContactPage extends StatefulWidget {
  final Map<String, dynamic>? contact; 
  final int userId; 

  const AddContactPage({
    Key? key,
    this.contact,
    required this.userId,
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
        const SnackBar(content: Text('First, Last name, and Phone are required')),
      );
      return;
    }

    if (widget.contact == null) {
      await dbHelper.insertContact(
        userId: widget.userId,
        firstname: firstname,
        lastname: lastname,
        phone: phone,
        photo: photoPath,
        categId: _selectedCategId,
      );
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Contact added')));
    } else {
      await dbHelper.updateContact(
        contactId: widget.contact!['contact_id'],
        userId: widget.userId,
        firstname: firstname,
        lastname: lastname,
        phone: phone,
        photo: photoPath,
        categId: _selectedCategId,
      );
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Contact updated')));
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
      body: SafeArea(
        child: Column(
          children: [
            // Custom Top Bar
            Container(
              margin: const EdgeInsets.all(12.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 2,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.contact == null ? 'Add Contact' : 'Edit Contact',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Body content scrollable
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Profile Picture
                    GestureDetector(
                      onTap: _pickImage,
                      child: Center(
                        child: Stack(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(60),
                                border: Border.all(
                                  color: Theme.of(context).primaryColor,
                                  width: 2,
                                ),
                              ),
                              child: _imageFile == null
                                  ? Icon(Icons.person,
                                      size: 60,
                                      color: Theme.of(context).primaryColor)
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(60),
                                      child: Image.file(
                                        _imageFile!,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    _buildTextField(
                      label: 'First Name',
                      controller: _firstnameController,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Last Name',
                      controller: _lastnameController,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Phone',
                      controller: _phoneController,
                      type: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),

                    if (_categories.isNotEmpty) ...[
                      DropdownButtonFormField<int>(
                        value: _selectedCategId,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: _categories.map((category) {
                          return DropdownMenuItem<int>(
                            value: category['categ_id'],
                            child: Text(category['categ_name']),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedCategId = value);
                        },
                      ),
                      const SizedBox(height: 24),
                    ],

                    ElevatedButton(
                      onPressed: _saveContact,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        widget.contact == null ? 'Save Contact' : 'Update Contact',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}