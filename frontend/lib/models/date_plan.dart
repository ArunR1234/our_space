class DatePlan {
  final int id;
  final int relationshipId;
  final int creatorId;
  final String title;
  final DateTime date;
  final String? location;
  final String status; // 'pending', 'accepted', 'declined'

  DatePlan({
    required this.id,
    required this.relationshipId,
    required this.creatorId,
    required this.title,
    required this.date,
    this.location,
    required this.status,
  });

  factory DatePlan.fromJson(Map<String, dynamic> json) {
    return DatePlan(
      id: json['id'],
      relationshipId: json['relationship_id'],
      creatorId: json['creator_id'],
      title: json['title'],
      date: json['date'] != null 
          ? DateTime.parse(json['date']) 
          : DateTime.now(),
      location: json['location'],
      status: json['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'relationship_id': relationshipId,
      'creator_id': creatorId,
      'title': title,
      'date': date.toIso8601String(),
      'location': location,
      'status': status,
    };
  }
}
