class Contact {
  int? id;
  String name;
  String phone;
  String? email;

  Contact({this.id, required this.name, required this.phone, this.email});

  // Convert Contact to Map for DB
  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'phone': phone, 'email': email};
  }

  // Create Contact from Map
  factory Contact.fromMap(Map<String, dynamic> map) {
    return Contact(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      email: map['email'],
    );
  }
}
