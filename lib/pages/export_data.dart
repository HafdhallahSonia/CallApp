import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class ExportDbPage extends StatelessWidget {
  const ExportDbPage({super.key});

  Future<void> exportDb(BuildContext context) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'contacts.db');
    final dbFile = File(path);

    if (await dbFile.exists()) {
      final dir = await getApplicationDocumentsDirectory();
      final newPath = join(dir.path, 'contacts_copy.db');
      await dbFile.copy(newPath);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Database exported to: $newPath")));
      print("Database copied to: $newPath");
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Database not found. Add some data first.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Exporter la base SQLite")),
      body: Center(
        child: ElevatedButton(
          onPressed: () => exportDb(context),
          child: Text("Exporter la base"),
        ),
      ),
    );
  }
}
