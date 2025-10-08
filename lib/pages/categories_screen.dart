import 'package:flutter/material.dart';
import '../services/db.dart';

class CategoriesScreen extends StatefulWidget {
  final int userId; 

  const CategoriesScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  _CategoriesScreenState createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final dbHelper = DbHelper();
  final _categNameController = TextEditingController();
  List<Map<String, dynamic>> _categories = [];

  // Using theme's primary color

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
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
            ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
            ),
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
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            color: Theme.of(context).primaryColor,
          ),
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
                    'Categories',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Add Category Row
            _buildAddCategoryRow(),

            // Category List
            Expanded(child: _buildCategoryList()),
          ],
        ),
      ),
    );
  }

}
