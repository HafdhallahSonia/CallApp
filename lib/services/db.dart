// db/db.dart
import 'package:contact_list/models/user.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DbHelper {
  static final DbHelper _instance = DbHelper._internal();
  factory DbHelper() => _instance;
  static Database? _database;

  DbHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // -------------------------
  // DATABASE INIT & MIGRATION
  // -------------------------
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'contacts.db'); // Une seule base
    print("📂 Base contacts mise à jour : $path");

    // ⚠️ Passez à version: 3 pour forcer la recréation ou gérer la migration
    return openDatabase(
      path,
      version: 3, // ← incrémenté (de 2 à 3)
      onCreate: _createDb,
      onUpgrade: (db, oldVersion, newVersion) async {
        // Optionnel : gérer la migration si vous ne voulez pas désinstaller
        if (oldVersion < 3) {
          // Créer la table users si elle n'existe pas
          await db.execute('''
            CREATE TABLE IF NOT EXISTS users(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              username TEXT UNIQUE NOT NULL,
              passwordHash TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 2) {
          // Ajouter user_id aux tables existantes (si version < 2)
          try {
            await db.execute('ALTER TABLE category ADD COLUMN user_id INTEGER');
          } catch (e) {
            // Colonne déjà ajoutée
          }
          try {
            await db.execute('ALTER TABLE contact ADD COLUMN user_id INTEGER');
          } catch (e) {
            // Colonne déjà ajoutée
          }
        }
      },
    );
  }

  Future<void> _createDb(Database db, int version) async {
    // 🔹 Table users
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        passwordHash TEXT NOT NULL,
        photo TEXT
      )
    ''');

    // 🔹 Table category avec user_id
    await db.execute('''
      CREATE TABLE category (
        categ_id INTEGER PRIMARY KEY AUTOINCREMENT,
        categ_name TEXT NOT NULL,
        user_id INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');

    // 🔹 Table contact avec user_id + FK vers category
    await db.execute('''
      CREATE TABLE contact (
        contact_id INTEGER PRIMARY KEY AUTOINCREMENT,
        firstname TEXT NOT NULL,
        lastname TEXT NOT NULL,
        photo TEXT,
        phone TEXT,
        categ_id INTEGER,
        user_id INTEGER NOT NULL,
        FOREIGN KEY (categ_id) REFERENCES category(categ_id),
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');
  }

  // -------------------------
  // USER METHODS
  // -------------------------

  Future<int> insertUser(User user) async {
    final db = await database;
    return await db.insert('users', user.toMap());
  }

  Future<User?> getUserByUsername(String username) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<User?> getUserById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  // -------------------------
  // CATEGORY METHODS (avec user_id)
  // -------------------------

  Future<void> insertCateg(int userId, String categName) async {
    final db = await database;
    await db.insert('category', {
      'categ_name': categName,
      'user_id': userId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getCategs(int userId) async {
    final db = await database;
    return db.query('category', where: 'user_id = ?', whereArgs: [userId]);
  }

  Future<void> updateCateg(int id, int userId, String newName) async {
    final db = await database;
    await db.update(
      'category',
      {'categ_name': newName},
      where: 'categ_id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
  }

  Future<void> deleteCateg(int id, int userId) async {
    final db = await database;
    await db.delete(
      'category',
      where: 'categ_id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
  }

  // -------------------------
  // CONTACT METHODS (avec user_id)
  // -------------------------

  Future<void> insertContact({
    required int userId,
    required String firstname,
    required String lastname,
    required String phone,
    String? photo,
    int? categId,
  }) async {
    final db = await database;
    await db.insert('contact', {
      'user_id': userId,
      'firstname': firstname,
      'lastname': lastname,
      'phone': phone,
      'photo': photo,
      'categ_id': categId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getContacts(int userId) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT 
        contact.contact_id,
        contact.firstname,
        contact.lastname,
        contact.phone,
        contact.photo,
        contact.categ_id,
        contact.user_id,
        category.categ_name
      FROM contact
      LEFT JOIN category ON contact.categ_id = category.categ_id
      WHERE contact.user_id = ?
    ''',
      [userId],
    );
  }

  Future<void> updateContact({
    required int contactId,
    required int userId,
    required String firstname,
    required String lastname,
    required String phone,
    String? photo,
    int? categId,
  }) async {
    final db = await database;
    await db.update(
      'contact',
      {
        'firstname': firstname,
        'lastname': lastname,
        'phone': phone,
        'photo': photo,
        'categ_id': categId,
      },
      where: 'contact_id = ? AND user_id = ?',
      whereArgs: [contactId, userId],
    );
  }

  Future<void> deleteContact(int contactId, int userId) async {
    final db = await database;
    await db.delete(
      'contact',
      where: 'contact_id = ? AND user_id = ?',
      whereArgs: [contactId, userId],
    );
  }
}
