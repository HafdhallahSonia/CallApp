// pages/categories_screen.dart
import 'package:flutter/material.dart';
import '../db/db.dart';

class CategoriesScreen extends StatefulWidget {
  final int userId; // ← Ajouté : obligatoire

  const CategoriesScreen({
    Key? key,
    required this.userId, // ← requis
  }) : super(key: key);

  @override
  _CategoriesScreenState createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final dbHelper = DbHelper();
  final _categNameController = TextEditingController();
  List<Map<String, dynamic>> _categories = [];

  final Color primaryColor = Color(0xFF263A96);

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _categNameController.dispose();
    super.dispose();
  }

  // ------------------ DB Methods ------------------
  void _loadCategories() async {
    // ✅ Charger uniquement les catégories de l'utilisateur connecté
    final data = await dbHelper.getCategs(widget.userId);
    setState(() {
      _categories = data;
    });
  }

  void _addCategory() async {
    String name = _categNameController.text.trim();
    if (name.isNotEmpty) {
      // ✅ Associer la catégorie à l'utilisateur
      await dbHelper.insertCateg(widget.userId, name);
      _categNameController.clear();
      _loadCategories();
    }
  }

  void _deleteCategory(int id) async {
    // ✅ Supprimer seulement si la catégorie appartient à l'utilisateur
    await dbHelper.deleteCateg(id, widget.userId);
    _loadCategories();
  }

  void _editCategory(int id, String oldName) {
    final editController = TextEditingController(text: oldName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Edit Category"),
        content: TextField(
          controller: editController,
          decoration: InputDecoration(labelText: "New Category Name"),
        ),
        actions: [
          TextButton(
            child: Text("Cancel"),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            child: Text("Save", style: TextStyle(color: Colors.white)),
            onPressed: () async {
              String newName = editController.text.trim();
              if (newName.isNotEmpty) {
                // ✅ Mettre à jour avec userId pour sécurité
                await dbHelper.updateCateg(id, widget.userId, newName);
                _loadCategories();
              }
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  // ------------------ Widgets ------------------
  Widget _buildAddCategoryRow() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _categNameController,
              decoration: InputDecoration(
                labelText: 'Category Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            onPressed: _addCategory,
            child: Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> item) {
    return Card(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.grey.withOpacity(0.3),
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(
          item['categ_name'],
          style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit, color: Colors.blue),
              onPressed: () =>
                  _editCategory(item['categ_id'], item['categ_name']),
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteCategory(item['categ_id']),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryList() {
    if (_categories.isEmpty) return Center(child: Text("No categories found"));
    return ListView.builder(
      itemCount: _categories.length,
      itemBuilder: (context, index) => _buildCategoryCard(_categories[index]),
    );
  }

  // ------------------ Build Scaffold ------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Categories',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        backgroundColor: primaryColor,
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildAddCategoryRow(),
          Expanded(child: _buildCategoryList()),
        ],
      ),
    );
  }
}
