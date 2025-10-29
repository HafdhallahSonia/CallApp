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
import 'package:another_telephony/telephony.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'map_screen.dart';
import 'SavedPositionsScreen.dart';


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

  final Telephony telephony = Telephony.instance;
  final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _loadCategories();
    _loadUserPhoto();
    _searchController.addListener(_filterItems);
    _initPermissions();
    _initNotifications();
    _listenForSms();
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
  // -------------------- Load Categories --------------------
  Future<void> _loadCategories() async {
    final data = await dbHelper.getCategs(userId);
    if (mounted) setState(() => _categories = data);
  }
  // -------------------- Load User Photo --------------------
  Future<void> _loadUserPhoto() async {
    if (!mounted) return;
    
    if (mounted) {
      setState(() => _isUserPhotoLoading = true);
    }
    
    try {
      final user = await dbHelper.getUserById(userId);
      if (user?.photoPath?.isNotEmpty == true) {
        try {
          final file = File(user!.photoPath!);
          final fileExists = await file.exists();
          if (fileExists && mounted) {
            setState(() => _userPhoto = file);
          } else if (mounted) {
            setState(() => _userPhoto = null);
          }
        } catch (e) {
          if (mounted) {
            setState(() => _userPhoto = null);
          }
        }
      } else if (mounted) {
        setState(() => _userPhoto = null);
      }
    } catch (e) {
      print('Error loading user photo: $e');
      if (mounted) {
        setState(() => _userPhoto = null);
      }
    } finally {
      if (mounted) {
        setState(() => _isUserPhotoLoading = false);
      }
    }
  }

// -------------------- Delete Contact --------------------
  Future<void> _deleteContact(int contactId) async {
    await dbHelper.deleteContact(contactId, userId);
    _loadContacts();
    _filterItems();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Contact deleted')));
  }

  //---------Filter Items-----------
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

  //---------Make Phone Call-----------
  Future<void> _makePhoneCall(String phoneNumber) async {
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d\+]'), '');
    if (cleanNumber.isEmpty) return;
    if (Platform.isAndroid) {
      await FlutterPhoneDirectCaller.callNumber(phoneNumber);
    } else {
      await launchUrl(Uri(scheme: 'tel', path: cleanNumber));
    }
  }

  Future<void> _initPermissions() async {
    await telephony.requestPhoneAndSmsPermissions;
    await Permission.location.request();
  }
 
  //---------Initialize Notifications-----------
  /*Future<void> _initNotifications() async {
    // 1️⃣ Initialize plugin settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final payload = response.payload;
        if (payload != null) {
          final uri = Uri.tryParse(payload);
          if (uri != null) {
            if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
              print('Could not launch: $uri');
            }
          }
        }
      },
    );


    // 2️⃣ Request notification permission (Android 13+ and iOS)
    if (Platform.isAndroid) {
      final granted = await Permission.notification.request();
      print('Notification permission granted: $granted');
    } else if (Platform.isIOS) {
      final iosPlugin = notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        await iosPlugin.requestPermissions(alert: true, badge: true, sound: true);
      }
    }
  }*/
  Future<void> _initNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final payload = response.payload;
        if (payload != null) {
          final parts = payload.split(',');
          if (parts.length == 2) {
            final lat = double.tryParse(parts[0]);
            final lon = double.tryParse(parts[1]);
            if (lat != null && lon != null) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MapScreen(latitude: lat, longitude: lon),
                ),
              );
            }
          }
        }
      },
    );
  }


  // Ensure notification permission on Android 13+
  Future<bool> _ensureNotificationPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        final granted = await Permission.notification.request();
        return granted.isGranted;
      }
      return true;
    } else if (Platform.isIOS) {
      final iosPlugin = notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        final granted = await iosPlugin.requestPermissions(alert: true, badge: true, sound: true);
        return granted ?? false;
      }
      return false;
    }
    return true; // default for other platforms
  }

  //---------Listen for SMS-----------
  void _listenForSms() {
    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) async {
        try {
          final body = message.body?.toLowerCase() ?? '';
          final sender = message.address ?? '';

          // ----------- Handle Location Request -----------
          if (body.contains("send your location")) {
            var status = await Permission.location.status;
            if (!status.isGranted) {
              status = await Permission.location.request();
            }

            if (status.isGranted) {
              try {
                Position pos = await Geolocator.getCurrentPosition(
                  desiredAccuracy: LocationAccuracy.high,
                ).timeout(const Duration(seconds: 10));

                String reply = "My location: ${pos.latitude},${pos.longitude}";
                await telephony.sendSms(to: sender, message: reply);
              } catch (e) {
                print('Error getting location: $e');
                await telephony.sendSms(
                  to: sender,
                  message: "Error: Could not determine location. Please check location services.",
                );
              }
            } else {
              await telephony.sendSms(
                to: sender,
                message: "Error: Location permission not granted.",
              );
            }
          }

          // ----------- Handle Location Response -----------
          else if (body.contains("my location:")) {
            await _showLocationNotification(body); // Use helper
          }

        } catch (e) {
          print('Error in SMS listener: $e');
        }
      },
      listenInBackground: false, // set false to prevent background crash
    );
  }

  //---------Show Location Notification-----------
  /*Future<void> _showLocationNotification(String message) async {
    final regex = RegExp(r'(-?\d{1,3}\.\d+),\s*(-?\d{1,3}\.\d+)');
    final match = regex.firstMatch(message);

    if (match != null) {
      final lat = match.group(1);
      final lon = match.group(2);

      if (lat != null && lon != null) {
        final androidUri = Uri.parse('geo:$lat,$lon?q=$lat,$lon(Label)');
        final webUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon'); // fallback web

        final androidDetails = AndroidNotificationDetails(
          'location_channel',
          'Location Notifications',
          channelDescription: 'Notifications for received locations',
          importance: Importance.max,
          priority: Priority.high,
        );

        const iosDetails = DarwinNotificationDetails();

        await notificationsPlugin.show(
          0,
          'Location Received',
          'Tap to open in Google Maps',
          NotificationDetails(android: androidDetails, iOS: iosDetails),
          payload: Platform.isAndroid ? androidUri.toString() : webUri.toString(),
        );
      }
    }
  }*/
  Future<void> _showLocationNotification(String message) async {
    final regex = RegExp(r'(-?\d+\.\d+),(-?\d+\.\d+)');
    final match = regex.firstMatch(message);

    if (match != null) {
      final lat = match.group(1);
      final lon = match.group(2);

      const androidDetails = AndroidNotificationDetails(
        'location_channel',
        'Location Notifications',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
      );

      await notificationsPlugin.show(
        0,
        'Location Received',
        'Tap to view on map',
        const NotificationDetails(android: androidDetails),
        payload: '$lat,$lon', // send coordinates to payload
      );
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
                    // ---------------- Edit Button ----------------
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
                    // ---------------- Delete Button ----------------
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
          title: Text(
            "${contact['firstname'] ?? ''} ${contact['lastname'] ?? ''}".trim().isNotEmpty
                ? "${contact['firstname'] ?? ''} ${contact['lastname'] ?? ''}".trim()
                : 'Unnamed Contact',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (contact['phone'] != null)
                Text("📞 ${contact['phone']}", style: TextStyle(color: Colors.black87)),
              Text("👤 ${contact['categ_name'] ?? 'No Category'}",
                  style: TextStyle(color: Colors.grey[700])),
            ],
          ),
          trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Phone Call Button
            if (contact['phone'] != null)
              IconButton(
                icon: const Icon(Icons.call, color: Colors.green),
                onPressed: () => _makePhoneCall(contact['phone']),
              ),
              // Request Location Button
              if (contact['phone'] != null)
                IconButton(
                  icon: const Icon(Icons.location_on, color: Colors.orange),
                  onPressed: () async {
                    await telephony.sendSms(
                      to: contact['phone'],
                      message: "send your location",
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Location request sent")),
                    );
                  },
                ),
          ],
        ),
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
            heroTag: "savedPositions",
            backgroundColor: Theme.of(context).primaryColor,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SavedPositionsScreen(userId: userId),
                ),
              );
            },
            child: const Icon(Icons.list, color: Colors.white),
          ),
          const SizedBox(height: 12),

          // ----------- Map Button -----------
          FloatingActionButton(
            heroTag: "openMap",
            backgroundColor: Theme.of(context).primaryColor,
            onPressed: () async {
              // Check location permission
              var status = await Permission.location.status;
              if (!status.isGranted) {
                status = await Permission.location.request();
              }

              if (status.isGranted) {
                try {
                  Position pos = await Geolocator.getCurrentPosition(
                    desiredAccuracy: LocationAccuracy.high,
                  );

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MapScreen(
                        latitude: pos.latitude,
                        longitude: pos.longitude,
                      ),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error getting location: $e")),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Location permission not granted")),
                );
              }
            },
            child: const Icon(Icons.map, color: Colors.white),
            tooltip: "Open Map",
          ),
          const SizedBox(height: 12),
          // ----------- Categories Button -----------
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
          // ----------- Add Contact Button -----------
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
